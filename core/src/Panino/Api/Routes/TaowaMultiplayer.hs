{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.TaowaMultiplayer
  ( taowaFrpProfileCreateResponse
  , taowaFrpProfileDeleteResponse
  , taowaFrpProfileTestResponse
  , taowaFrpProfileUpdateResponse
  , taowaFrpProfilesResponse
  , testTaowaFrpProfile
  , taowaLanDetectResponse
  , taowaLanValidatePortResponse
  , taowaRecommendationsResponse
  , taowaSessionHealthResponse
  , taowaSessionHistoryClearResponse
  , taowaSessionResponse
  , taowaSessionStartResponse
  , taowaSessionLogResponse
  , taowaSessionStopResponse
  , taowaSessionsResponse
  ) where

import Control.Exception
  ( SomeException
  , bracket
  , try
  )
import Control.Concurrent.STM
  ( readTVarIO
  )
import Control.Applicative ((<|>))
import Data.Aeson
  ( Value
  , object
  , (.=)
  )
import Data.List
  ( find
  , sortOn
  )
import qualified Data.Map.Strict as Map
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (getCurrentTime)
import Network.HTTP.Types
  ( Status
  , status200
  , status400
  , status404
  )
import Network.Socket
  ( AddrInfo(..)
  , SocketType(Stream)
  , close
  , connect
  , defaultHints
  , getAddrInfo
  , socket
  , withSocketsDo
  )
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Params (decodeBody)
import Panino.Api.MinecraftStatus
  ( MinecraftInstalledInstance(..)
  , MinecraftInstallStatusRequest(..)
  , fetchInstalledMinecraftInstances
  )
import Panino.Api.Response (jsonResponse)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( ApiEvent(..)
  , TaskSnapshot(..)
  )
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  )
import Panino.Events.Bus (publishEvent)
import Panino.Minecraft.Layout
  ( minecraftRoot
  , mkLayout
  )
import Panino.Multiplayer.Taowa.ConfigStore
  ( buildTaowaFrpProfile
  , deleteTaowaFrpProfile
  , findTaowaFrpProfile
  , readTaowaFrpProfiles
  , upsertTaowaFrpProfile
  )
import Panino.Multiplayer.Taowa.Diagnostics
  ( readRedactedTaowaLogTail
  , taowaDiagnosticForCode
  , taowaSessionNotFoundDiagnostic
  )
import Panino.Multiplayer.Taowa.FrpcProcess
  ( validateFrpcExecutable
  )
import Panino.Multiplayer.Taowa.LanDetect
  ( validateLocalPort
  , validateManualLanPort
  , watchLanPort
  )
import Panino.Multiplayer.Taowa.Session
  ( clearTaowaSessionHistory
  , listTaowaSessions
  , listTaowaSessionsIncludingStored
  , startTaowaSession
  , stopTaowaSession
  )
import Panino.Multiplayer.Taowa.Types
  ( TaowaFrpProfile(..)
  , TaowaFrpProfileRequest(..)
  , TaowaFrpProfileTestCheck(..)
  , TaowaFrpProfileTestResponse(..)
  , TaowaLanDetectRequest
  , TaowaLanDetectStatus(..)
  , TaowaLanPortDetection(..)
  , TaowaLanValidatePortRequest
  , TaowaProfilesResponse(..)
  , TaowaSession(..)
  , TaowaSessionHistoryClearRequest
  , TaowaSessionStartRequest(..)
  , TaowaSessionStatus(..)
  , TaowaSessionsResponse(..)
  , publicProfile
  )
import System.FilePath
  ( takeDirectory
  )
import System.Exit
  ( ExitCode(..)
  )
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )
import System.Timeout
  ( timeout
  )

taowaFrpProfilesResponse :: ServerState -> IO Response
taowaFrpProfilesResponse state =
  taowaJson state $ \appRoot -> do
    profiles <- readTaowaFrpProfiles appRoot
    pure (jsonResponse status200 TaowaProfilesResponse { taowaProfiles = map publicProfile profiles })

taowaFrpProfileCreateResponse :: ServerState -> Request -> IO Response
taowaFrpProfileCreateResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right profileRequest ->
      taowaJson state $ \appRoot -> do
        profile <- buildTaowaFrpProfile Nothing profileRequest
        saved <- upsertTaowaFrpProfile appRoot profile
        pure (jsonResponse status200 (publicProfile saved))

taowaFrpProfileUpdateResponse :: ServerState -> [Text] -> Request -> IO Response
taowaFrpProfileUpdateResponse state [profileId] request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right profileRequest ->
      taowaJson state $ \appRoot -> do
        existing <- findTaowaFrpProfile appRoot profileId
        case existing of
          Nothing -> pure (notFoundResponse "taowa_profile_not_found" "FRP profile was not found.")
          Just oldProfile -> do
            profile <- buildTaowaFrpProfile (Just oldProfile) (forceProfileId profileId profileRequest)
            saved <- upsertTaowaFrpProfile appRoot profile
            pure (jsonResponse status200 (publicProfile saved))
taowaFrpProfileUpdateResponse _ _ _ =
  pure (notFoundResponse "not_found" "FRP profile was not found.")

taowaFrpProfileDeleteResponse :: ServerState -> [Text] -> IO Response
taowaFrpProfileDeleteResponse state [profileId] =
  taowaJson state $ \appRoot -> do
    activeSessions <- listTaowaSessions (stateTaowaSessions state)
    if any (activeSessionForProfile profileId) activeSessions
      then
        pure $
          taowaDiagnosticErrorResponse status400 $
            taowaDiagnosticForCode
              "taowa_profile_in_use"
              "profile"
              "Stop the running Taowa tunnel before deleting this FRP profile."
              [("profileId", profileId)]
              Nothing
      else do
        deleted <- deleteTaowaFrpProfile appRoot profileId
        pure $
          jsonResponse status200 $
            object
              [ "profileId" .= profileId
              , "deleted" .= deleted
              ]
taowaFrpProfileDeleteResponse _ _ =
  pure (notFoundResponse "not_found" "FRP profile was not found.")

taowaFrpProfileTestResponse :: ServerState -> [Text] -> IO Response
taowaFrpProfileTestResponse state [profileId, "test"] =
  taowaJson state $ \appRoot -> do
    profile <- findTaowaFrpProfile appRoot profileId
    case profile of
      Nothing ->
        pure $
          taowaDiagnosticErrorResponse status404 $
            taowaDiagnosticForCode
              "taowa_profile_invalid"
              "profile"
              "FRP profile was not found."
              [("profileId", profileId)]
              Nothing
      Just found -> do
        testResult <- testTaowaFrpProfile found
        pure (jsonResponse status200 testResult)
taowaFrpProfileTestResponse _ _ =
  pure (notFoundResponse "not_found" "FRP profile was not found.")

taowaLanDetectResponse :: Request -> IO Response
taowaLanDetectResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right (detectRequest :: TaowaLanDetectRequest) -> do
      detection <- watchLanPort detectRequest
      pure (jsonResponse status200 detection)

taowaLanValidatePortResponse :: Request -> IO Response
taowaLanValidatePortResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right (validateRequest :: TaowaLanValidatePortRequest) -> do
      detection <- validateManualLanPort validateRequest
      if taowaLanStatus detection == TaowaLanDetected
        then pure (jsonResponse status200 detection)
        else
          pure $
            jsonResponse status400 $
              errorObjectWithDetection
                "taowa_local_port_unreachable"
                "The selected LAN port is not reachable on 127.0.0.1."
                detection

taowaRecommendationsResponse :: ServerState -> IO Response
taowaRecommendationsResponse state =
  taowaJson state $ \_appRoot -> do
    taskMap <- readTVarIO (stateTasks state)
    installed <-
      fetchInstalledMinecraftInstances
        (stateDefaultGameDir state)
        MinecraftInstallStatusRequest
          { installStatusVersionIds = []
          , installStatusGameDirs = []
          }
    let recentLaunches =
          take 5 $
            sortOn (Down . taskSnapshotUpdatedAt) $
              [ task
              | task <- Map.elems taskMap
              , taskSnapshotKind task == "launch"
              , Just gameDir <- [taskSnapshotGameDir task]
              , not (null gameDir)
              ]
        installedCandidates = take 5 installed
        recommendedFromTask = case recentLaunches of
          task:_ -> taskSnapshotGameDir task
          [] -> Nothing
        recommendedFromInstalled = case installedCandidates of
          instanceValue:_ -> Just (installedInstanceGameDir instanceValue)
          [] -> Nothing
        recommendedGameDir = recommendedFromTask <|> recommendedFromInstalled
        source =
          case recommendedFromTask of
            Just _ -> "taskHistory" :: Text
            Nothing ->
              case recommendedFromInstalled of
                Just _ -> "installedInstances"
                Nothing -> "none"
    pure $
      jsonResponse status200 $
        object
          [ "recommendedGameDir" .= recommendedGameDir
          , "source" .= source
          , "recentLaunches" .= map taskCandidate recentLaunches
          , "installedInstances" .= map installedCandidate installedCandidates
          ]

taowaSessionHealthResponse :: ServerState -> [Text] -> IO Response
taowaSessionHealthResponse state [sessionId, "health"] =
  taowaJson state $ \appRoot -> do
    sessions <- listTaowaSessionsIncludingStored appRoot (stateTaowaSessions state)
    activeMap <- readTVarIO (stateTaowaSessions state)
    case find ((== sessionId) . taowaSessionId) sessions of
      Nothing ->
        pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic sessionId))
      Just session -> do
        reachable <- validateLocalPort (taowaSessionLocalPort session)
        let processManaged = Map.member sessionId activeMap
            stale =
              not processManaged
                && taowaSessionStatus session `elem` [TaowaSessionPrepared, TaowaSessionStartingFrpc, TaowaSessionRunning]
        pure $
          jsonResponse status200 $
            object
              [ "session" .= session
              , "localPortReachable" .= reachable
              , "processManaged" .= processManaged
              , "stale" .= stale
              ]
taowaSessionHealthResponse _ _ =
  pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic "unknown"))

taowaSessionHistoryClearResponse :: ServerState -> Request -> IO Response
taowaSessionHistoryClearResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right (clearRequest :: TaowaSessionHistoryClearRequest) ->
      taowaJson state $ \appRoot -> do
        response <- clearTaowaSessionHistory appRoot (stateTaowaSessions state) clearRequest
        pure (jsonResponse status200 response)

taowaSessionResponse :: ServerState -> [Text] -> IO Response
taowaSessionResponse state [sessionId] =
  taowaJson state $ \appRoot -> do
    sessions <- listTaowaSessionsIncludingStored appRoot (stateTaowaSessions state)
    case find ((== sessionId) . taowaSessionId) sessions of
      Nothing ->
        pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic sessionId))
      Just session ->
        pure (jsonResponse status200 session)
taowaSessionResponse _ _ =
  pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic "unknown"))

taowaSessionStartResponse :: ServerState -> Request -> IO Response
taowaSessionStartResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right startRequest ->
      taowaJson state $ \appRoot -> do
        profile <- findTaowaFrpProfile appRoot (taowaStartProfileId startRequest)
        case profile of
          Nothing -> pure (notFoundResponse "taowa_profile_not_found" "FRP profile was not found.")
          Just found -> do
            started <- startTaowaSession appRoot (stateTaowaSessions state) found startRequest
            case started of
              Left diagnostic -> do
                emitTaowaSessionFailureEvent state startRequest diagnostic
                pure (taowaDiagnosticErrorResponse status400 diagnostic)
              Right session -> do
                emitTaowaSessionEvent state "taowa.session.started" session "Taowa session started"
                pure (jsonResponse status200 session)

taowaSessionLogResponse :: ServerState -> [Text] -> IO Response
taowaSessionLogResponse state [sessionId, "log"] =
  taowaJson state $ \appRoot -> do
    sessions <- listTaowaSessionsIncludingStored appRoot (stateTaowaSessions state)
    case find ((== sessionId) . taowaSessionId) sessions of
      Nothing ->
        pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic sessionId))
      Just session -> do
        logTail <- readRedactedTaowaLogTail (taowaSessionFrpcLogPath session)
        pure $
          jsonResponse status200 $
            object
              [ "sessionId" .= sessionId
              , "logPath" .= taowaSessionFrpcLogPath session
              , "tail" .= logTail
              ]
taowaSessionLogResponse _ _ =
  pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic "unknown"))

taowaSessionStopResponse :: ServerState -> [Text] -> IO Response
taowaSessionStopResponse state [sessionId, "stop"] =
  taowaJson state $ \appRoot -> do
    stopped <- stopTaowaSession appRoot (stateTaowaSessions state) sessionId
    case stopped of
      Left diagnostic -> pure (taowaDiagnosticErrorResponse status404 diagnostic)
      Right session -> do
        emitTaowaSessionEvent
          state
          (if taowaSessionStatus session == TaowaSessionStopped then "taowa.session.stopped" else "taowa.session.failed")
          session
          (if taowaSessionStatus session == TaowaSessionStopped then "Taowa session stopped" else "Taowa session failed")
        pure (jsonResponse status200 session)
taowaSessionStopResponse _ _ =
  pure (notFoundResponse "not_found" "Taowa session was not found.")

taowaSessionsResponse :: ServerState -> IO Response
taowaSessionsResponse state =
  taowaJson state $ \appRoot -> do
    sessions <- listTaowaSessionsIncludingStored appRoot (stateTaowaSessions state)
    pure (jsonResponse status200 TaowaSessionsResponse { taowaSessions = sessions })

testTaowaFrpProfile :: TaowaFrpProfile -> IO TaowaFrpProfileTestResponse
testTaowaFrpProfile profile = do
  executableResult <- validateFrpcExecutable (taowaProfileFrpcPath profile)
  versionResult <-
    case executableResult of
      Left err -> pure (Left err)
      Right () -> runFrpcVersion (taowaProfileFrpcPath profile)
  serverReachable <- testTcpConnection (taowaProfileServerAddr profile) (taowaProfileServerPort profile)
  let executableCheck =
        case executableResult of
          Right () -> okCheck "frpcExecutable" "frpc executable is present and executable."
          Left err -> failedCheck "frpcExecutable" err
      versionCheck =
        case versionResult of
          Right versionText -> okCheck "frpcVersion" ("frpc --version succeeded: " <> versionText)
          Left err -> failedCheck "frpcVersion" err
      serverCheck =
        if serverReachable
          then okCheck "frpServerTcp" "FRP server TCP port is reachable."
          else failedCheck "frpServerTcp" "FRP server TCP port is not reachable."
      diagnostics =
        concat
          [ case executableResult of
              Right () -> []
              Left err ->
                [ taowaDiagnosticForCode
                    (if "not executable" `Text.isInfixOf` Text.toLower err then "taowa_frpc_not_executable" else "taowa_frpc_not_found")
                    "profile"
                    err
                    (profileContext profile)
                    (Just (taowaProfileFrpcPath profile))
                ]
          , case versionResult of
              Right _ -> []
              Left err
                | executableResult == Right () ->
                    [ taowaDiagnosticForCode
                        "taowa_profile_invalid"
                        "profile"
                        ("frpc --version failed: " <> err)
                        (profileContext profile)
                        (Just (taowaProfileFrpcPath profile))
                    ]
              _ -> []
          , if serverReachable
              then []
              else
                [ taowaDiagnosticForCode
                    "taowa_frp_server_unreachable"
                    "profile"
                    "Panino could not connect to the configured FRP server TCP port."
                    (profileContext profile)
                    Nothing
                ]
          ]
      checks = [executableCheck, versionCheck, serverCheck]
  pure
    TaowaFrpProfileTestResponse
      { taowaProfileTestProfileId = taowaProfileId profile
      , taowaProfileTestOk = all taowaProfileTestCheckOk checks
      , taowaProfileTestChecks = checks
      , taowaProfileTestDiagnostics = diagnostics
      }
  where
    okCheck name message =
      TaowaFrpProfileTestCheck name True message
    failedCheck name message =
      TaowaFrpProfileTestCheck name False message

runFrpcVersion :: FilePath -> IO (Either Text Text)
runFrpcVersion frpcPath = do
  result <-
    timeout 2000000 $
      try (readCreateProcessWithExitCode (proc frpcPath ["--version"]) "") ::
        IO (Maybe (Either SomeException (ExitCode, String, String)))
  case result of
    Just (Right (ExitSuccess, stdoutText, stderrText)) ->
      pure (Right (cleanProcessOutput stdoutText stderrText))
    Just (Right (exitCode, _stdoutText, stderrText)) ->
      pure (Left ("frpc --version exited with " <> Text.pack (show exitCode) <> ": " <> Text.pack stderrText))
    Just (Left err) ->
      pure (Left ("frpc --version failed: " <> Text.pack (show err)))
    Nothing ->
      pure (Left "frpc --version timed out")

testTcpConnection :: Text -> Int -> IO Bool
testTcpConnection host port = do
  result <-
    timeout 2000000 $
      try connectOnce :: IO (Maybe (Either SomeException ()))
  pure (maybe False (either (const False) (const True)) result)
  where
    connectOnce =
      withSocketsDo $ do
        addrs <- getAddrInfo (Just defaultHints { addrSocketType = Stream }) (Just (Text.unpack host)) (Just (show port))
        case addrs of
          [] -> fail "no address found"
          addr:_ ->
            bracket
              (socket (addrFamily addr) (addrSocketType addr) (addrProtocol addr))
              close
              (\sock -> connect sock (addrAddress addr))

cleanProcessOutput :: String -> String -> Text
cleanProcessOutput stdoutText stderrText =
  let value = Text.strip (Text.pack stdoutText <> "\n" <> Text.pack stderrText)
   in if Text.null value then "<no output>" else Text.take 240 value

profileContext :: TaowaFrpProfile -> [(Text, Text)]
profileContext profile =
  [ ("profileId", taowaProfileId profile)
  , ("serverAddr", taowaProfileServerAddr profile)
  , ("serverPort", Text.pack (show (taowaProfileServerPort profile)))
  , ("remotePort", Text.pack (show (taowaProfileRemotePort profile)))
  , ("frpcPath", Text.pack (taowaProfileFrpcPath profile))
  ]

activeSessionForProfile :: Text -> TaowaSession -> Bool
activeSessionForProfile profileId session =
  taowaSessionProfileId session == profileId
    && taowaSessionStatus session `elem` [TaowaSessionPrepared, TaowaSessionStartingFrpc, TaowaSessionRunning]

taowaJson :: ServerState -> (FilePath -> IO Response) -> IO Response
taowaJson state action = do
  appRoot <- appSupportRoot state
  result <- try (action appRoot)
  case result of
    Right response -> pure response
    Left (err :: SomeException) ->
      pure (jsonResponse status400 (errorObject "taowa_operation_failed" (Text.pack (show err))))

appSupportRoot :: ServerState -> IO FilePath
appSupportRoot state = do
  layout <- mkLayout (stateDefaultGameDir state)
  pure (takeDirectory (minecraftRoot layout))

invalidJsonResponse :: String -> Response
invalidJsonResponse err =
  jsonResponse status400 (errorObject "invalid_json" (Text.pack err))

notFoundResponse :: Text -> Text -> Response
notFoundResponse code message =
  jsonResponse status404 (errorObject code message)

errorObject :: Text -> Text -> Value
errorObject code message =
  object
    [ "error" .= code
    , "message" .= message
    ]

errorObjectWithDetection :: Text -> Text -> TaowaLanPortDetection -> Value
errorObjectWithDetection code message detection =
  object $
    [ "error" .= code
    , "message" .= message
    , "detection" .= detection
    ]
      <> case taowaLanDiagnostics detection of
        diagnostic:_ ->
          [ "diagnostic" .= diagnostic
          , "diagnostics" .= taowaLanDiagnostics detection
          ]
        [] -> []

forceProfileId :: Text -> TaowaFrpProfileRequest -> TaowaFrpProfileRequest
forceProfileId profileId request =
  request { taowaRequestProfileId = Just profileId }

taskCandidate :: TaskSnapshot -> Value
taskCandidate task =
  object
    [ "taskId" .= taskSnapshotId task
    , "gameDir" .= taskSnapshotGameDir task
    , "version" .= taskSnapshotVersion task
    , "state" .= taskSnapshotState task
    , "updatedAt" .= taskSnapshotUpdatedAt task
    ]

installedCandidate :: MinecraftInstalledInstance -> Value
installedCandidate instanceValue =
  object
    [ "versionId" .= installedInstanceVersionId instanceValue
    , "name" .= installedInstanceName instanceValue
    , "gameDir" .= installedInstanceGameDir instanceValue
    ]

taowaDiagnosticErrorResponse :: Status -> Diagnostic -> Response
taowaDiagnosticErrorResponse status diagnostic =
  jsonResponse status $
    object
      [ "error" .= diagnosticCode diagnostic
      , "message" .= diagnosticMessage diagnostic
      , "diagnostic" .= diagnostic
      , "diagnostics" .= [diagnostic]
      ]

emitTaowaSessionEvent :: ServerState -> Text -> TaowaSession -> Text -> IO ()
emitTaowaSessionEvent state eventType session message = do
  now <- getCurrentTime
  publishEvent
    (stateEvents state)
    ApiEvent
      { apiEventType = eventType
      , apiEventTaskId = Nothing
      , apiEventVersion = Just (taowaSessionId session)
      , apiEventMessage = message
      , apiEventAt = now
      , apiEventPayload =
          object $
            [ "session" .= session
            ]
              <> case taowaSessionDiagnostics session of
                diagnostic:_ ->
                  [ "diagnostic" .= diagnostic
                  , "diagnostics" .= taowaSessionDiagnostics session
                  ]
                [] -> []
      }

emitTaowaSessionFailureEvent :: ServerState -> TaowaSessionStartRequest -> Diagnostic -> IO ()
emitTaowaSessionFailureEvent state request diagnostic = do
  now <- getCurrentTime
  publishEvent
    (stateEvents state)
    ApiEvent
      { apiEventType = "taowa.session.failed"
      , apiEventTaskId = Nothing
      , apiEventVersion = taowaStartInstanceId request
      , apiEventMessage = diagnosticMessage diagnostic
      , apiEventAt = now
      , apiEventPayload =
          object
            [ "profileId" .= taowaStartProfileId request
            , "instanceId" .= taowaStartInstanceId request
            , "gameDir" .= taowaStartGameDir request
            , "localPort" .= taowaStartLocalPort request
            , "diagnostic" .= diagnostic
            , "diagnostics" .= [diagnostic]
            ]
      }
