{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Performance
  ( performanceEvidenceResponse
  , performanceExperimentsResponse
  , performanceProfileApplyResponse
  , performanceProfileCandidateResponse
  , performanceProfileResolveResponse
  , performanceProfileRollbackResponse
  , performanceSessionEndResponse
  , performanceSessionSampleResponse
  , performanceSessionStartResponse
  ) where

import Data.Aeson
  ( FromJSON(..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Int (Int64)
import Data.List (find)
import Data.Maybe
  ( isJust
  , isNothing
  )
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Time.Format
  ( FormatTime
  , defaultTimeLocale
  , formatTime
  )
import Network.HTTP.Types
  ( status200
  , status400
  , status404
  )
import Network.Wai
  ( Request
  , Response
  , queryString
  )
import Panino.Api.Params (decodeBody)
import Panino.Api.Response (jsonResponse)
import Panino.Api.Server.State (ServerState(..))
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Diagnostics.Types (Diagnostic)
import Panino.Performance.Candidate
  ( CandidateBudget(..)
  , generateCandidate
  )
import Panino.Performance.CompanionProtocol
  ( CompanionEnvelope(..)
  , mergeCompanionFrameSample
  )
import Panino.Performance.Experiment (completeExperiment)
import Panino.Performance.Explain (recommendationFromProfiles)
import Panino.Performance.Objective
  ( defaultPerformanceObjective
  , scoreSession
  , PerformanceScore(..)
  )
import Panino.Performance.Profile.Store
  ( applyProfile
  , baselineProfile
  , listRecentSessions
  , readProfile
  , readProfileCooldown
  , recordProfileCooldown
  , rollbackProfile
  , storeProfile
  )
import Panino.Performance.Profile.Types
  ( InstanceFingerprint(..)
  , PerformanceEvidence(..)
  , PerformanceKnobs
  , PerformanceProfile(..)
  , defaultInstanceFingerprint
  , defaultPerformanceKnobs
  , estimatedEvidence
  )
import Panino.Performance.SafetyGate
  ( SafetyGateDecision(..)
  , checkSafetyGate
  )
import Panino.Performance.Telemetry.Collect
  ( beginPerformanceSession
  , completePerformanceSession
  , readPerformanceSession
  , writePerformanceSession
  )
import Panino.Performance.Telemetry.Types
  ( CompanionFrameSample
  , MemorySample
  , PerformanceSession(..)
  )
import System.Exit (ExitCode(..))

data PerformanceProfileRequest = PerformanceProfileRequest
  { profileRequestGameDir :: FilePath
  , profileRequestFingerprint :: InstanceFingerprint
  , profileRequestKnobs :: PerformanceKnobs
  , profileRequestEvidence :: [PerformanceEvidence]
  } deriving (Eq, Show)

instance FromJSON PerformanceProfileRequest where
  parseJSON =
    withObject "PerformanceProfileRequest" $ \obj ->
      PerformanceProfileRequest
        <$> obj .: "gameDir"
        <*> obj .:? "instanceFingerprint" .!= defaultInstanceFingerprint
        <*> obj .:? "knobs" .!= defaultPerformanceKnobs
        <*> obj .:? "evidence" .!= []

data PerformanceCandidateRequest = PerformanceCandidateRequest
  { candidateRequestGameDir :: FilePath
  , candidateRequestBaselineProfileId :: Maybe Text
  , candidateRequestBudget :: CandidateBudget
  } deriving (Eq, Show)

instance FromJSON PerformanceCandidateRequest where
  parseJSON =
    withObject "PerformanceCandidateRequest" $ \obj ->
      PerformanceCandidateRequest
        <$> obj .: "gameDir"
        <*> obj .:? "baselineProfileId"
        <*> ( CandidateBudget
                <$> obj .:? "budgetLaunches" .!= 1
                <*> obj .:? "budgetChangedKnobs" .!= 1
            )

data PerformanceApplyRequest = PerformanceApplyRequest
  { applyRequestGameDir :: FilePath
  , applyRequestProfile :: PerformanceProfile
  } deriving (Eq, Show)

instance FromJSON PerformanceApplyRequest where
  parseJSON =
    withObject "PerformanceApplyRequest" $ \obj ->
      PerformanceApplyRequest
        <$> obj .: "gameDir"
        <*> obj .: "profile"

data PerformanceRollbackRequest = PerformanceRollbackRequest
  { rollbackRequestGameDir :: FilePath
  , rollbackRequestRef :: Text
  } deriving (Eq, Show)

instance FromJSON PerformanceRollbackRequest where
  parseJSON =
    withObject "PerformanceRollbackRequest" $ \obj ->
      PerformanceRollbackRequest
        <$> obj .: "gameDir"
        <*> obj .:? "rollbackRef" .!= "rollback-applied"

data PerformanceSessionStartRequest = PerformanceSessionStartRequest
  { sessionStartGameDir :: FilePath
  , sessionStartFingerprint :: InstanceFingerprint
  , sessionStartBaselineProfileId :: Maybe Text
  , sessionStartCandidateProfileId :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON PerformanceSessionStartRequest where
  parseJSON =
    withObject "PerformanceSessionStartRequest" $ \obj ->
      PerformanceSessionStartRequest
        <$> obj .: "gameDir"
        <*> obj .:? "instanceFingerprint" .!= defaultInstanceFingerprint
        <*> obj .:? "baselineProfileId"
        <*> obj .:? "candidateProfileId"

data PerformanceSessionEndRequest = PerformanceSessionEndRequest
  { sessionEndGameDir :: FilePath
  , sessionEndLaunchSessionId :: Text
  , sessionEndExitCode :: Int
  , sessionEndSamples :: [MemorySample]
  , sessionEndSystemMemoryBytes :: Maybe Int64
  } deriving (Eq, Show)

instance FromJSON PerformanceSessionEndRequest where
  parseJSON =
    withObject "PerformanceSessionEndRequest" $ \obj ->
      PerformanceSessionEndRequest
        <$> obj .: "gameDir"
        <*> obj .: "launchSessionId"
        <*> obj .:? "exitCode" .!= 0
        <*> obj .:? "memorySamples" .!= []
        <*> obj .:? "systemMemoryBytes"

data PerformanceSessionSampleRequest = PerformanceSessionSampleRequest
  { sessionSampleGameDir :: FilePath
  , sessionSampleLaunchSessionId :: Text
  , sessionSampleFrame :: Maybe CompanionFrameSample
  } deriving (Eq, Show)

instance FromJSON PerformanceSessionSampleRequest where
  parseJSON =
    withObject "PerformanceSessionSampleRequest" $ \obj ->
      PerformanceSessionSampleRequest
        <$> obj .: "gameDir"
        <*> obj .: "launchSessionId"
        <*> obj .:? "frame"

performanceProfileResolveResponse :: Request -> IO Response
performanceProfileResolveResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> invalidJson (Text.pack err)
    Right profileRequest -> do
      let baseline =
            baselineProfile
              (profileRequestGameDir profileRequest)
              (profileRequestFingerprint profileRequest)
              (profileRequestKnobs profileRequest)
              (profileRequestEvidence profileRequest)
      storeProfile (profileRequestGameDir profileRequest) baseline
      pure (jsonResponse status200 (recommendationFromProfiles (profileRequestGameDir profileRequest) baseline Nothing))

performanceProfileCandidateResponse :: Request -> IO Response
performanceProfileCandidateResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> invalidJson (Text.pack err)
    Right candidateRequest -> do
      baseline <-
        case candidateRequestBaselineProfileId candidateRequest of
          Just ident -> readProfile (candidateRequestGameDir candidateRequest) ident
          Nothing -> pure Nothing
      case baseline of
        Nothing ->
          pure (jsonResponse status404 (object ["error" .= ("profile_not_found" :: Text)]))
        Just profile -> do
          let rawCandidate = generateCandidate (candidateRequestBudget candidateRequest) profile
          cooldown <- readProfileCooldown (candidateRequestGameDir candidateRequest) (profileId rawCandidate)
          let candidate =
                rawCandidate
                  { profileCooldownUntil = formatCooldownUntil <$> cooldown
                  }
          recent <- listRecentSessions (candidateRequestGameDir candidateRequest) 1
          let decision = checkSafetyGate defaultPerformanceObjective (case recent of item:_ -> Just item; [] -> Nothing) candidate
          storeProfile (candidateRequestGameDir candidateRequest) candidate
          let diagnostics = performanceSafetyDiagnostics (safetyReasons decision)
          pure $
            jsonResponse status200 $
              object
                [ "candidate" .= candidate
                , "safetyGate" .= decision
                , "recommendation" .= recommendationFromProfiles (candidateRequestGameDir candidateRequest) profile (Just candidate)
                , "diagnostic" .= case diagnostics of item:_ -> Just item; [] -> Nothing
                , "diagnostics" .= diagnostics
                ]

performanceProfileApplyResponse :: Request -> IO Response
performanceProfileApplyResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> invalidJson (Text.pack err)
    Right applyRequest -> do
      applied <- applyProfile (applyRequestGameDir applyRequest) (applyRequestProfile applyRequest)
      pure (jsonResponse status200 (object ["applied" .= True, "profile" .= applied, "rollbackRef" .= profileRollbackRefValue applied]))

performanceProfileRollbackResponse :: Request -> IO Response
performanceProfileRollbackResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> invalidJson (Text.pack err)
    Right rollbackRequest -> do
      restored <- rollbackProfile (rollbackRequestGameDir rollbackRequest) (rollbackRequestRef rollbackRequest)
      pure $
        jsonResponse status200 $
          object
            [ "rolledBack" .= maybe False (const True) restored
            , "profile" .= restored
            ]

performanceSessionStartResponse :: Request -> IO Response
performanceSessionStartResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> invalidJson (Text.pack err)
    Right startRequest -> do
      session <-
        beginPerformanceSession
          (sessionStartGameDir startRequest)
          (sessionStartFingerprint startRequest)
          (sessionStartBaselineProfileId startRequest)
          (sessionStartCandidateProfileId startRequest)
          Nothing
          Nothing
      pure (jsonResponse status200 session)

performanceSessionSampleResponse :: Request -> IO Response
performanceSessionSampleResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> invalidJson (Text.pack err)
    Right sampleRequest -> do
      loaded <- readPerformanceSession (sessionSampleGameDir sampleRequest) (sessionSampleLaunchSessionId sampleRequest)
      case loaded of
        Left err -> pure (jsonResponse status404 (object ["error" .= ("session_not_found" :: Text), "message" .= Text.pack err]))
        Right session -> do
          let updated =
                case sessionSampleFrame sampleRequest of
                  Nothing -> session
                  Just frame ->
                    mergeCompanionFrameSample
                      CompanionEnvelope
                        { companionVersion = "panino-companion-v1"
                        , companionLaunchSessionId = sessionSampleLaunchSessionId sampleRequest
                        , companionToken = Nothing
                        , companionFrameSample = frame
                        }
                      session
          writePerformanceSession updated
          pure (jsonResponse status200 updated)

performanceSessionEndResponse :: Request -> IO Response
performanceSessionEndResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> invalidJson (Text.pack err)
    Right endRequest -> do
      loaded <- readPerformanceSession (sessionEndGameDir endRequest) (sessionEndLaunchSessionId endRequest)
      case loaded of
        Left err -> pure (jsonResponse status404 (object ["error" .= ("session_not_found" :: Text), "message" .= Text.pack err]))
        Right session -> do
          completed <-
            completePerformanceSession
              session
              (exitCodeFromInt (sessionEndExitCode endRequest))
              (sessionEndSystemMemoryBytes endRequest)
              (sessionEndSamples endRequest)
              Nothing
          recordFailedCandidateCooldown (sessionEndGameDir endRequest) completed
          let diagnostics = performanceSessionEndDiagnostics endRequest
          if null diagnostics
            then pure (jsonResponse status200 completed)
            else
              pure $
                jsonResponse
                  status200
                  ( object
                      [ "session" .= completed
                      , "diagnostic" .= case diagnostics of item:_ -> Just item; [] -> Nothing
                      , "diagnostics" .= diagnostics
                      ]
                  )

performanceExperimentsResponse :: ServerState -> Request -> IO Response
performanceExperimentsResponse _ request =
  withGameDirQuery request $ \gameDir -> do
    sessions <- listRecentSessions gameDir 20
    let latestBaseline = find (isNothing . sessionCandidateProfileId) sessions
        latestCandidate = find (isJust . sessionCandidateProfileId) sessions
        latestResult = completeExperiment defaultPerformanceObjective <$> latestBaseline <*> latestCandidate
    pure (jsonResponse status200 (object ["sessions" .= sessions, "latestResult" .= latestResult]))

performanceEvidenceResponse :: ServerState -> Request -> [Text] -> IO Response
performanceEvidenceResponse _ request _ =
  withGameDirQuery request $ \gameDir -> do
    sessions <- listRecentSessions gameDir 5
    pure $
      jsonResponse status200 $
        object
          [ "gameDir" .= gameDir
          , "sessions" .= sessions
          , "diagnosticPaths" .= [gameDir <> "/.panino/performance/sessions", gameDir <> "/.panino/performance/profiles"]
          ]

invalidJson :: Text -> IO Response
invalidJson err =
  pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))

withGameDirQuery :: Request -> (FilePath -> IO Response) -> IO Response
withGameDirQuery request action =
  case lookup "gameDir" (queryPairs request) of
    Just (Just value) -> action (Text.unpack value)
    _ -> pure (jsonResponse status400 (object ["error" .= ("missing_game_dir" :: Text)]))

queryPairs :: Request -> [(Text, Maybe Text)]
queryPairs request =
  [ (TextEncoding.decodeUtf8 key, TextEncoding.decodeUtf8 <$> value)
  | (key, value) <- queryString request
  ]

profileRollbackRefValue :: PerformanceProfile -> Maybe Text
profileRollbackRefValue =
  profileRollbackRef

exitCodeFromInt :: Int -> ExitCode
exitCodeFromInt 0 = ExitSuccess
exitCodeFromInt value = ExitFailure value

formatCooldownUntil :: FormatTime time => time -> Text
formatCooldownUntil =
  Text.pack . formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%SZ"

recordFailedCandidateCooldown :: FilePath -> PerformanceSession -> IO ()
recordFailedCandidateCooldown gameDir session =
  case sessionCandidateProfileId session of
    Nothing -> pure ()
    Just candidateId -> do
      let score = scoreSession defaultPerformanceObjective session
      if scoreRejected score
        then do
          _ <- recordProfileCooldown gameDir candidateId
          pure ()
        else pure ()

performanceSafetyDiagnostics :: [Text] -> [Diagnostic]
performanceSafetyDiagnostics reasons =
  [ diagnosticFromBlockedReason "performance" "performance candidate" ("performance_safety_gate_blocked:" <> reason)
  | reason <- reasons
  ]

performanceSessionEndDiagnostics :: PerformanceSessionEndRequest -> [Diagnostic]
performanceSessionEndDiagnostics request =
  [ diagnosticFromBlockedReason
      "performance"
      "performance session end"
      ("performance_safety_gate_blocked:exit_code_" <> Text.pack (show (sessionEndExitCode request)))
  | sessionEndExitCode request /= 0
  ]
