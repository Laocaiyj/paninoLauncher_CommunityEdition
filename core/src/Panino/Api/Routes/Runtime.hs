{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Runtime
  ( javaRuntimeCatalogResponse
  , javaRuntimeCleanupResponse
  , javaRuntimeDeleteResponse
  , javaRuntimeImportResponse
  , javaRuntimeInstallResponse
  , javaRuntimeManagedResponse
  , javaRuntimeResolveResponse
  , javaRuntimeSelectResponse
  , javaRuntimeVerifyResponse
  ) where

import Data.Aeson
  ( Value
  , object
  , (.=)
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Types
  ( status200
  , status202
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
import Panino.Api.Routes.Tasks
  ( emitTaskProgress
  , startTaskWithGameDirContext
  , taskIsCancelled
  )
import Panino.Api.Server.State
  ( ServerState(..)
  , stateDefaultGameDirPath
  )
import Panino.Api.Types
  ( TaskAccepted(..)
  , TaskPhaseId
  , TaskProgress(..)
  , TaskSnapshot(..)
  )
import Panino.Core.Types (gameDirPath)
import Panino.Download.Manager (DownloadProgress(..))
import Panino.Minecraft.Layout
  ( MinecraftLayout
  , minecraftRoot
  , mkLayout
  )
import Panino.Runtime.Java.Catalog
  ( catalogForRuntimeWithProvider
  , defaultRuntimeArch
  , defaultRuntimeOs
  )
import Panino.Runtime.Java.Install
  ( importJavaRuntime
  , installJavaRuntime
  )
import Panino.Runtime.Java.Resolve (resolveJavaRuntime)
import Panino.Runtime.Java.Store
  ( cleanupUnusedJavaRuntimes
  , deleteManagedRuntime
  , managedJavaRoot
  , readManagedRuntimes
  , selectJavaRuntimePolicy
  , verifyManagedRuntime
  )
import Panino.Runtime.Java.Types
  ( JavaManagedResponse(..)
  , JavaManagedRuntime(..)
  , JavaRuntimeInstallRequest(..)
  , JavaRuntimeResolveRequest(..)
  , JavaRuntimeSelectRequest(..)
  , JavaRuntimeVerifyRequest(..)
  )
import System.FilePath
  ( takeDirectory
  , (</>)
  )

javaRuntimeManagedResponse :: ServerState -> IO Response
javaRuntimeManagedResponse state = do
  appRoot <- appSupportRoot state
  runtimes <- readManagedRuntimes appRoot
  pure (jsonResponse status200 JavaManagedResponse { javaManagedRuntimes = runtimes, javaManagedRoot = managedJavaRoot appRoot })

javaRuntimeResolveResponse :: ServerState -> Request -> IO Response
javaRuntimeResolveResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (errorObject "invalid_json" (Text.pack err)))
    Right resolveRequest -> do
      appRoot <- appSupportRoot state
      layout <- javaRuntimeResolveLayout appRoot resolveRequest
      response <- resolveJavaRuntime (stateHttpManager state) appRoot (Just layout) resolveRequest
      pure (jsonResponse status200 response)

javaRuntimeResolveLayout :: FilePath -> JavaRuntimeResolveRequest -> IO MinecraftLayout
javaRuntimeResolveLayout appRoot resolveRequest =
  case resolveGameDir resolveRequest of
    Just gameDir | not (null (gameDirPath gameDir)) -> mkLayout (Just (gameDirPath gameDir))
    _ -> mkLayout (Just (appRoot </> ".panino" </> "runtime-resolve-cache"))

javaRuntimeCatalogResponse :: ServerState -> Request -> IO Response
javaRuntimeCatalogResponse state request = do
  let query = queryString request
      featureVersion = queryInt "featureVersion" 21 query
      runtimeOs = fromMaybe defaultRuntimeOs (queryText "os" query)
      runtimeArch = fromMaybe defaultRuntimeArch (queryText "arch" query)
      imageType = fromMaybe "jre" (queryText "imageType" query)
      provider = queryText "provider" query
  appRoot <- appSupportRoot state
  catalog <- catalogForRuntimeWithProvider (stateHttpManager state) appRoot provider featureVersion runtimeOs runtimeArch imageType
  pure (jsonResponse status200 catalog)

javaRuntimeSelectResponse :: ServerState -> Request -> IO Response
javaRuntimeSelectResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (errorObject "invalid_json" (Text.pack err)))
    Right selectRequest
      | selectRuntimeScope selectRequest == "instance" && selectRuntimeInstanceId selectRequest == Nothing ->
          pure (jsonResponse status400 (errorObject "invalid_runtime_policy" "instance policy requires instanceId"))
      | selectRuntimePolicy selectRequest == "managed" && selectRuntimePreferredRuntimeId selectRequest == Nothing ->
          pure (jsonResponse status400 (errorObject "invalid_runtime_policy" "managed policy requires preferredRuntimeId"))
      | selectRuntimePolicy selectRequest == "custom" && selectRuntimeCustomPath selectRequest == Nothing ->
          pure (jsonResponse status400 (errorObject "invalid_runtime_policy" "custom policy requires customPath"))
      | otherwise -> do
          appRoot <- appSupportRoot state
          response <- selectJavaRuntimePolicy appRoot selectRequest
          pure (jsonResponse status200 response)

javaRuntimeInstallResponse :: ServerState -> Request -> IO Response
javaRuntimeInstallResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (errorObject "invalid_json" (Text.pack err)))
    Right installRequest -> do
      appRoot <- appSupportRoot state
      task <-
        startTaskWithGameDirContext state "runtime.install" ("Java " <> Text.pack (show (installRuntimeFeatureVersion installRequest))) Nothing $ \snapshot -> do
          emitRuntimePhase state snapshot "resolve" "Resolve Java runtime" 1 5 0 "resolving Java runtime"
          runtime <-
            installJavaRuntime
              (stateHttpManager state)
              appRoot
              installRequest
              (taskIsCancelled state snapshot)
              (emitRuntimeDownloadProgress state snapshot)
          emitRuntimePhase state snapshot "check" "Check Java runtime" 5 5 95 "checking Java runtime"
          pure ("Java " <> Text.pack (show (installRuntimeFeatureVersion installRequest)) <> " installed: " <> managedRuntimeId runtime)
      pure (jsonResponse status202 (TaskAccepted task))

javaRuntimeVerifyResponse :: ServerState -> Request -> IO Response
javaRuntimeVerifyResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (errorObject "invalid_json" (Text.pack err)))
    Right verifyRequest -> do
      appRoot <- appSupportRoot state
      runtime <- verifyManagedRuntime appRoot (verifyRuntimeId verifyRequest)
      pure (jsonResponse status200 runtime)

javaRuntimeImportResponse :: ServerState -> Request -> IO Response
javaRuntimeImportResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (errorObject "invalid_json" (Text.pack err)))
    Right importRequest -> do
      appRoot <- appSupportRoot state
      runtime <- importJavaRuntime appRoot importRequest
      pure (jsonResponse status200 runtime)

javaRuntimeCleanupResponse :: ServerState -> IO Response
javaRuntimeCleanupResponse state = do
  appRoot <- appSupportRoot state
  response <- cleanupUnusedJavaRuntimes appRoot
  pure (jsonResponse status200 response)

javaRuntimeDeleteResponse :: ServerState -> [Text] -> IO Response
javaRuntimeDeleteResponse state [runtimeId] = do
  appRoot <- appSupportRoot state
  response <- deleteManagedRuntime appRoot runtimeId
  pure (jsonResponse status200 response)
javaRuntimeDeleteResponse _ _ =
  pure (jsonResponse status404 (errorObject "not_found" "runtime not found"))

appSupportRoot :: ServerState -> IO FilePath
appSupportRoot state = do
  layout <- mkLayout (stateDefaultGameDirPath state)
  pure (takeDirectory (minecraftRoot layout))

emitRuntimeDownloadProgress :: ServerState -> TaskSnapshot -> DownloadProgress -> IO ()
emitRuntimeDownloadProgress state task progress =
  emitTaskProgress
    state
    task
    TaskProgress
      { taskProgressTaskId = taskSnapshotId task
      , taskProgressPhaseId = "download"
      , taskProgressPhaseTitle = "Download Java runtime"
      , taskProgressPhaseIndex = 2
      , taskProgressPhaseCount = 5
      , taskProgressPhasePercent = progressPercent progress
      , taskProgressOverallPercent = Just (20 + maybe 0 (* 0.55) (progressPercent progress))
      , taskProgressCompletedJobs = progressCompletedJobs progress
      , taskProgressTotalJobs = progressTotalJobs progress
      , taskProgressCompletedBytes = progressCompletedBytes progress
      , taskProgressTotalBytes = progressTotalBytes progress
      , taskProgressSpeedBytesPerSecond = progressSpeedBytesPerSecond progress
      , taskProgressMovingAverageSpeedBytesPerSecond = progressMovingAverageSpeedBytesPerSecond progress
      , taskProgressEtaSeconds = progressEtaSeconds progress
      , taskProgressCurrentLabel = Text.pack (progressLabel progress)
      , taskProgressActiveWorkers = progressActiveWorkers progress
      , taskProgressRetryCount = progressRetryCount progress
      , taskProgressSourceHost = progressHost progress
      , taskProgressHosts = []
      , taskProgressThrottleReason = progressThrottleReason progress
      , taskProgressMultipart = Nothing
      }

emitRuntimePhase :: ServerState -> TaskSnapshot -> TaskPhaseId -> Text -> Int -> Int -> Double -> Text -> IO ()
emitRuntimePhase state task phaseId phaseTitle phaseIndex phaseCount overall label =
  emitTaskProgress
    state
    task
    TaskProgress
      { taskProgressTaskId = taskSnapshotId task
      , taskProgressPhaseId = phaseId
      , taskProgressPhaseTitle = phaseTitle
      , taskProgressPhaseIndex = phaseIndex
      , taskProgressPhaseCount = phaseCount
      , taskProgressPhasePercent = Just 0
      , taskProgressOverallPercent = Just overall
      , taskProgressCompletedJobs = 0
      , taskProgressTotalJobs = 0
      , taskProgressCompletedBytes = 0
      , taskProgressTotalBytes = 0
      , taskProgressSpeedBytesPerSecond = 0
      , taskProgressMovingAverageSpeedBytesPerSecond = 0
      , taskProgressEtaSeconds = Nothing
      , taskProgressCurrentLabel = label
      , taskProgressActiveWorkers = 0
      , taskProgressRetryCount = 0
      , taskProgressSourceHost = Nothing
      , taskProgressHosts = []
      , taskProgressThrottleReason = Nothing
      , taskProgressMultipart = Nothing
      }

errorObject :: Text -> Text -> Value
errorObject code message =
  object ["error" .= code, "message" .= message]

queryText :: BS.ByteString -> [(BS.ByteString, Maybe BS.ByteString)] -> Maybe Text
queryText key query =
  case lookup key query of
    Just (Just value) -> Just (Text.pack (BS8.unpack value))
    _ -> Nothing

queryInt :: BS.ByteString -> Int -> [(BS.ByteString, Maybe BS.ByteString)] -> Int
queryInt key fallback query =
  case queryText key query >>= readIntText of
    Just value -> value
    Nothing -> fallback

readIntText :: Text -> Maybe Int
readIntText value =
  case reads (Text.unpack value) of
    (parsed, ""):_ -> Just parsed
    _ -> Nothing
