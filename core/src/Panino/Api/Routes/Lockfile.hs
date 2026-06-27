{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Lockfile
  ( lockfileApplyResponse
  , lockfileCurrentResponse
  , lockfileDiffResponse
  , lockfileExplainResponse
  , lockfileSolveResponse
  , lockfileVerifyResponse
  ) where

import Data.Aeson
  ( FromJSON(..)
  , object
  , withObject
  , (.:?)
  , (.=)
  )
import Control.Applicative ((<|>))
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Network.HTTP.Types
  ( status200
  , status400
  , status409
  )
import Network.Wai
  ( Request
  , Response
  , queryString
  )
import Network.HTTP.Client
  ( Manager
  )
import Panino.Api.Params (decodeBody)
import Panino.Api.Response (jsonResponse)
import Panino.Api.Server.State
  ( ServerState(..)
  )
import Panino.Core.Types
  ( GameDir
  , gameDirFromPath
  , gameDirPath
  )
import Panino.Install.Plan.Executor
  ( blockedInstallPlanExecutionResult
  , executeExecutableInstallPlan
  , installExecutionStatus
  )
import qualified Panino.Install.Plan.State as PlanState
import Panino.Lockfile.Apply
  ( rollbackLockfilePlanNode
  , runLockfilePlanNode
  )
import Panino.Lockfile.Solver
  ( diffLockfiles
  , lockfileApplyReadyLockfile
  , solveLockfileWithServices
  , verifyLockfile
  )
import Panino.Lockfile.Store
  ( currentLockfilePath
  , readCurrentLockfile
  , writeCurrentLockfile
  , writeLastSolverArtifacts
  )
import Panino.Lockfile.Types
  ( LockfileApplyRequest(..)
  , LockfileDiffRequest(..)
  , PaninoLockfile(..)
  , SolverResult(..)
  , applyRequestTargetGameDirPath
  )

lockfileSolveResponse :: ServerState -> Request -> IO Response
lockfileSolveResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= Text.pack err]))
    Right solveRequest ->
      jsonResponse status200 <$> solveLockfileWithServices (stateHttpManager state) solveRequest

lockfileApplyResponse :: ServerState -> Request -> IO Response
lockfileApplyResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= Text.pack err]))
    Right applyRequest ->
      applyLockfileResult (stateHttpManager state) applyRequest

lockfileCurrentResponse :: ServerState -> Request -> IO Response
lockfileCurrentResponse state request = do
  case queryGameDir "gameDir" request <|> (stateDefaultGameDir state >>= gameDirFromPath) of
    Nothing ->
      pure (jsonResponse status400 (object ["error" .= ("game_dir_required" :: Text)]))
    Just gameDir -> do
      let targetGameDir = gameDirPath gameDir
      loaded <- readCurrentLockfile targetGameDir
      case loaded of
        Left err ->
          pure (jsonResponse status400 (object ["error" .= ("lockfile_parse_failed" :: Text), "message" .= Text.pack err]))
        Right maybeLockfile ->
          pure $
            jsonResponse
              status200
              ( object
                  [ "path" .= currentLockfilePath targetGameDir
                  , "lockfile" .= maybeLockfile
                  ]
              )

lockfileDiffResponse :: ServerState -> Request -> IO Response
lockfileDiffResponse _ request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= Text.pack err]))
    Right diffRequest ->
      pure (jsonResponse status200 (diffLockfiles (diffRequestBase diffRequest) (diffRequestTarget diffRequest)))

lockfileExplainResponse :: ServerState -> Request -> IO Response
lockfileExplainResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= Text.pack err]))
    Right solveRequest -> do
      result <- solveLockfileWithServices (stateHttpManager state) solveRequest
      pure (jsonResponse status200 (solverResultExplain result))

lockfileVerifyResponse :: ServerState -> Request -> IO Response
lockfileVerifyResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= Text.pack err]))
    Right verifyRequest -> do
      case verifyRequestTargetGameDir verifyRequest <|> (stateDefaultGameDir state >>= gameDirFromPath) of
        Nothing ->
          pure (jsonResponse status400 (object ["error" .= ("game_dir_required" :: Text)]))
        Just gameDir -> do
          let targetGameDir = gameDirPath gameDir
          maybeLockfile <- resolveVerifyLockfile targetGameDir verifyRequest
          case maybeLockfile of
            Left err ->
              pure (jsonResponse status400 (object ["error" .= ("lockfile_unavailable" :: Text), "message" .= err]))
            Right lockfile -> do
              response <- verifyLockfile targetGameDir lockfile
              pure (jsonResponse status200 response)

applyLockfileResult :: Manager -> LockfileApplyRequest -> IO Response
applyLockfileResult manager request =
  case lockfileApplyReadyLockfile request of
    Left "lockfile_missing" ->
      pure (jsonResponse status400 (object ["error" .= ("lockfile_missing" :: Text)]))
    Left "solver_blocked" ->
      pure (jsonResponse status409 (object ["error" .= ("solver_blocked" :: Text), "blockedReasons" .= solverResultBlockedReasons (applyRequestResult request)]))
    Left "solver_fingerprint_mismatch" ->
      case solverResultLockfile (applyRequestResult request) of
        Nothing ->
          pure (jsonResponse status400 (object ["error" .= ("lockfile_missing" :: Text)]))
        Just lockfile ->
          pure
            ( jsonResponse
                status409
                ( object
                    [ "error" .= ("solver_fingerprint_mismatch" :: Text)
                    , "expected" .= lockfileFingerprint lockfile
                    , "actual" .= applyRequestSolverFingerprint request
                    ]
                )
            )
    Left code ->
      pure (jsonResponse status409 (object ["error" .= code]))
    Right lockfile -> do
          let typedPlan = solverResultTypedPlan (applyRequestResult request)
          execution <-
            case PlanState.requireExecutableInstallPlan typedPlan of
              Left blocked ->
                blockedInstallPlanExecutionResult blocked (\_ -> pure ())
              Right executablePlan ->
                executeExecutableInstallPlan
                  executablePlan
                  (runLockfilePlanNode manager)
                  rollbackLockfilePlanNode
                  (\_ -> pure ())
          if installExecutionStatus execution /= "succeeded"
            then
              pure
                ( jsonResponse
                    status409
                    ( object
                        [ "error" .= ("install_plan_execution_failed" :: Text)
                        , "execution" .= execution
                        ]
                    )
                )
            else do
              let targetGameDir = applyRequestTargetGameDirPath request
              path <- writeCurrentLockfile targetGameDir lockfile
              (resultPath, explainPath) <- writeLastSolverArtifacts targetGameDir (applyRequestResult request)
              pure
                ( jsonResponse
                    status200
                    ( object
                        [ "status" .= ("applied" :: Text)
                        , "lockfilePath" .= path
                        , "resultPath" .= resultPath
                        , "explainPath" .= explainPath
                        , "execution" .= execution
                        ]
                    )
                )

data LockfileVerifyRequest = LockfileVerifyRequest
  { verifyRequestTargetGameDir :: Maybe GameDir
  , verifyRequestLockfile :: Maybe PaninoLockfile
  } deriving (Eq, Show)

instance FromJSON LockfileVerifyRequest where
  parseJSON =
    withObject "LockfileVerifyRequest" $ \obj ->
      LockfileVerifyRequest
        <$> obj .:? "targetGameDir"
        <*> obj .:? "lockfile"

resolveVerifyLockfile :: FilePath -> LockfileVerifyRequest -> IO (Either Text PaninoLockfile)
resolveVerifyLockfile gameDir verifyRequest =
  case verifyRequestLockfile verifyRequest of
    Just lockfile -> pure (Right lockfile)
    Nothing -> do
      loaded <- readCurrentLockfile gameDir
      case loaded of
        Left err -> pure (Left (Text.pack err))
        Right Nothing -> pure (Left "No panino-lock.json exists for this game directory.")
        Right (Just lockfile) -> pure (Right lockfile)

queryGameDir :: Text -> Request -> Maybe GameDir
queryGameDir key request =
  lookup (Text.encodeUtf8 key) (queryString request)
    >>= id
    >>= gameDirFromPath . Text.unpack . Text.decodeUtf8
