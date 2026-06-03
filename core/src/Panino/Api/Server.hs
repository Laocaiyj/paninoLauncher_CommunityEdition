{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Server
  ( ApiServerOptions(..)
  , runApiServer
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar
  ( MVar
  , newEmptyMVar
  , putMVar
  , readMVar
  )
import Control.Concurrent.STM
  ( newTVarIO
  )
import Control.Monad (when)
import Data.Aeson
  ( eitherDecode
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Data.Time.Clock (getCurrentTime)
import Network.HTTP.Types
  ( hAuthorization
  , methodDelete
  , methodGet
  , methodPost
  , status401
  , status404
  , status405
  )
import Network.Wai
  ( Application
  , Request
  , Response
  , pathInfo
  , requestHeaders
  , requestMethod
  )
import Network.Wai.Handler.Warp
  ( defaultSettings
  , runSettings
  , setInstallShutdownHandler
  , setHost
  , setPort
  )
import Panino.Api.Response (jsonResponse)
import Panino.Api.Routes.Content
  ( contentInstallPlanResponse
  , contentInstallResponse
  , contentLoadersResponse
  , contentMinecraftInstallStatusResponse
  , contentMinecraftInstalledInstancesResponse
  , contentMinecraftPackageResponse
  , contentMinecraftVersionsResponse
  , contentProjectResponse
  , contentResolveTargetsResponse
  , contentSearchResponse
  , contentUpdatePlanResponse
  )
import Panino.Api.Routes.Configuration
  ( configurationCapabilitiesResponse
  , exportBackupPreflightResponse
  , launchLibraryResponse
  , loaderCompatibilityResponse
  , modpackImportResponse
  , modpackPreflightResponse
  , versionSwitchPreflightResponse
  )
import Panino.Api.Routes.Compatibility
  ( compatibilityEvaluateResponse
  , compatibilityExplainResponse
  )
import Panino.Api.Routes.Health (healthResponse)
import Panino.Api.Routes.InstallPlan
  ( installPlanResolveResponse
  )
import Panino.Api.Routes.Lockfile
  ( lockfileApplyResponse
  , lockfileCurrentResponse
  , lockfileDiffResponse
  , lockfileExplainResponse
  , lockfileSolveResponse
  , lockfileVerifyResponse
  )
import Panino.Api.Routes.GraphicsTuning
  ( graphicsTuningApplyResponse
  , graphicsTuningResolveResponse
  , graphicsTuningRollbackResponse
  )
import Panino.Api.Routes.LaunchTuning
  ( launchTuningApplyResponse
  , launchTuningResolveResponse
  )
import Panino.Api.Routes.Diagnostics
  ( diagnosticsProbeResponse
  , diagnosticsStatusResponse
  , environmentReportResponse
  )
import Panino.Api.Routes.Local
  ( javaCheckResponse
  , javaDeleteLocalResponse
  , javaScanResponse
  , localArchiveImportResponse
  , localArchiveResponse
  , localResourceDeleteResponse
  , localResourceImportResponse
  , localResourceScanResponse
  , localResourceToggleResponse
  , minecraftCleanVersionResponse
  , minecraftVersionStorageResponse
  )
import Panino.Api.Routes.Minecraft
  ( installResponse
  , installPreflightResponse
  , launchResponse
  )
import Panino.Api.Routes.Network
  ( effectiveNetworkConfigResponse
  , speedTestResponse
  , sourceTestResponse
  )
import Panino.Api.Routes.PerformancePack
  ( performancePackInstallResponse
  , performancePackPlanResponse
  , performancePackRollbackResponse
  )
import Panino.Api.Routes.Performance
  ( performanceEvidenceResponse
  , performanceExperimentsResponse
  , performanceProfileApplyResponse
  , performanceProfileCandidateResponse
  , performanceProfileResolveResponse
  , performanceProfileRollbackResponse
  , performanceSessionEndResponse
  , performanceSessionSampleResponse
  , performanceSessionStartResponse
  )
import Panino.Api.Routes.Runtime
  ( javaRuntimeCatalogResponse
  , javaRuntimeCleanupResponse
  , javaRuntimeDeleteResponse
  , javaRuntimeImportResponse
  , javaRuntimeInstallResponse
  , javaRuntimeManagedResponse
  , javaRuntimeResolveResponse
  , javaRuntimeSelectResponse
  , javaRuntimeVerifyResponse
  )
import Panino.Api.Routes.Tasks
  ( cancelTaskResponse
  , clearTaskHistoryResponse
  , eventsResponse
  , shutdownResponse
  , taskHistoryResponse
  , taskResponse
  , tasksResponse
  )
import Panino.Api.Server.State
  ( ApiServerOptions(..)
  , ServerState(..)
  )
import Panino.Api.Types
  ( TaskSnapshot
  , taskSnapshotId
  )
import Panino.Events.Bus (newEventBus)
import Panino.Minecraft.Manifest (makeHttpManager)
import Panino.Minecraft.Layout
  ( minecraftRoot
  , mkLayout
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  )

runApiServer :: ApiServerOptions -> IO ()
runApiServer options = do
  when (Text.null (apiServerSessionToken options)) $
    fail "serve requires a non-empty session token"
  eventBus <- newEventBus
  defaultLayout <- mkLayout (apiServerGameDir options)
  let taskHistoryPath = takeDirectory (minecraftRoot defaultLayout) </> "task-history.json"
  createDirectoryIfMissing True (takeDirectory taskHistoryPath)
  initialTasks <- loadTaskHistory taskHistoryPath
  tasks <- newTVarIO initialTasks
  taskHandles <- newTVarIO Map.empty
  nextTaskCounter <- newTVarIO (nextTaskCounterFrom initialTasks)
  shutdownHandler <- newEmptyMVar
  manager <- makeHttpManager
  startedAt <- getCurrentTime
  let state =
        ServerState
          { stateSessionToken = apiServerSessionToken options
          , stateStartedAt = startedAt
          , stateDefaultGameDir = apiServerGameDir options
          , stateTasks = tasks
          , stateTaskHistoryPath = taskHistoryPath
          , stateTaskHandles = taskHandles
          , stateNextTaskId = nextTaskCounter
          , stateEvents = eventBus
          , stateHttpManager = manager
          , stateShutdown = runShutdownHandler shutdownHandler
          }
      settings =
        setInstallShutdownHandler (putMVar shutdownHandler)
          ( setHost (fromString (apiServerHost options))
              (setPort (apiServerPort options) defaultSettings)
          )
  putStrLn
    ( "panino-core serving on http://"
        <> apiServerHost options
        <> ":"
        <> show (apiServerPort options)
    )
  runSettings settings (application state)

application :: ServerState -> Application
application state request respond =
  respond =<< route state request

route :: ServerState -> Request -> IO Response
route state request
  | not (isAuthorized state request) =
      pure (jsonResponse status401 (object ["error" .= ("unauthorized" :: Text)]))
  | requestMethod request == methodGet && routePath == ["api", "v1", "health"] =
      healthResponse
  | requestMethod request == methodPost && routePath == ["api", "v1", "install"] =
      installResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "install", "preflight"] =
      installPreflightResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "launch"] =
      launchResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "install-plan", "resolve"] =
      installPlanResolveResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "lockfile", "solve"] =
      lockfileSolveResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "lockfile", "apply"] =
      lockfileApplyResponse state request
  | requestMethod request == methodGet && routePath == ["api", "v1", "lockfile", "current"] =
      lockfileCurrentResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "lockfile", "diff"] =
      lockfileDiffResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "lockfile", "explain"] =
      lockfileExplainResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "lockfile", "verify"] =
      lockfileVerifyResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "compatibility", "evaluate"] =
      compatibilityEvaluateResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "compatibility", "explain"] =
      compatibilityExplainResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "launch", "tuning", "resolve"] =
      launchTuningResolveResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "launch", "tuning", "apply"] =
      launchTuningApplyResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "graphics", "tuning", "resolve"] =
      graphicsTuningResolveResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "graphics", "tuning", "apply"] =
      graphicsTuningApplyResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "graphics", "tuning", "rollback"] =
      graphicsTuningRollbackResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "performance", "pack", "plan"] =
      performancePackPlanResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "performance", "pack", "install"] =
      performancePackInstallResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "performance", "pack", "rollback"] =
      performancePackRollbackResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "performance", "session", "start"] =
      performanceSessionStartResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "performance", "session", "sample"] =
      performanceSessionSampleResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "performance", "session", "end"] =
      performanceSessionEndResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "performance", "profile", "resolve"] =
      performanceProfileResolveResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "performance", "profile", "candidate"] =
      performanceProfileCandidateResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "performance", "profile", "apply"] =
      performanceProfileApplyResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "performance", "profile", "rollback"] =
      performanceProfileRollbackResponse request
  | requestMethod request == methodGet && routePath == ["api", "v1", "performance", "experiments"] =
      performanceExperimentsResponse state request
  | requestMethod request == methodGet && take 4 routePath == ["api", "v1", "performance", "evidence"] =
      performanceEvidenceResponse state request (drop 4 routePath)
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "install-plan"] =
      contentInstallPlanResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "update-plan"] =
      contentUpdatePlanResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "install"] =
      contentInstallResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "resolve-targets"] =
      contentResolveTargetsResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "search"] =
      contentSearchResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "project"] =
      contentProjectResponse state request
  | requestMethod request == methodGet && routePath == ["api", "v1", "content", "minecraft", "versions"] =
      contentMinecraftVersionsResponse state
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "minecraft", "install-status"] =
      contentMinecraftInstallStatusResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "minecraft", "installed-instances"] =
      contentMinecraftInstalledInstancesResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "minecraft", "package"] =
      contentMinecraftPackageResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "loaders"] =
      contentLoadersResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "loader-compatibility"] =
      loaderCompatibilityResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "modpack", "preflight"] =
      modpackPreflightResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "modpack", "import"] =
      modpackImportResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "config", "capabilities"] =
      configurationCapabilitiesResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "config", "version-switch-preflight"] =
      versionSwitchPreflightResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "config", "export-preflight"] =
      exportBackupPreflightResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "config", "launch-library"] =
      launchLibraryResponse request
  | requestMethod request == methodGet && routePath == ["api", "v1", "network", "effective-config"] =
      effectiveNetworkConfigResponse
  | requestMethod request == methodGet && routePath == ["api", "v1", "network", "source-test"] =
      sourceTestResponse state
  | requestMethod request == methodPost && routePath == ["api", "v1", "network", "speed-test"] =
      speedTestResponse state request
  | requestMethod request == methodGet && routePath == ["api", "v1", "diagnostics", "status"] =
      diagnosticsStatusResponse state
  | requestMethod request == methodPost && routePath == ["api", "v1", "diagnostics", "probe"] =
      diagnosticsProbeResponse state request
  | requestMethod request == methodGet && routePath == ["api", "v1", "environment", "report"] =
      environmentReportResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "runtime", "java", "check"] =
      javaCheckResponse request
  | requestMethod request == methodGet && routePath == ["api", "v1", "runtime", "java", "scan"] =
      javaScanResponse
  | requestMethod request == methodGet && routePath == ["api", "v1", "runtime", "java", "managed"] =
      javaRuntimeManagedResponse state
  | requestMethod request == methodPost && routePath == ["api", "v1", "runtime", "java", "resolve"] =
      javaRuntimeResolveResponse state request
  | requestMethod request == methodGet && routePath == ["api", "v1", "runtime", "java", "catalog"] =
      javaRuntimeCatalogResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "runtime", "java", "select"] =
      javaRuntimeSelectResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "runtime", "java", "install"] =
      javaRuntimeInstallResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "runtime", "java", "verify"] =
      javaRuntimeVerifyResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "runtime", "java", "import"] =
      javaRuntimeImportResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "runtime", "java", "cleanup"] =
      javaRuntimeCleanupResponse state
  | requestMethod request == methodPost && routePath == ["api", "v1", "runtime", "java", "local", "delete"] =
      javaDeleteLocalResponse request
  | requestMethod request == methodDelete && take 5 routePath == ["api", "v1", "runtime", "java", "managed"] =
      javaRuntimeDeleteResponse state (drop 5 routePath)
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "local", "scan"] =
      localResourceScanResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "local", "toggle"] =
      localResourceToggleResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "local", "delete"] =
      localResourceDeleteResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "local", "import"] =
      localResourceImportResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "local", "archive"] =
      localArchiveResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "local", "import-archive"] =
      localArchiveImportResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "minecraft", "clean-version"] =
      minecraftCleanVersionResponse request
  | requestMethod request == methodPost && routePath == ["api", "v1", "content", "minecraft", "version-storage"] =
      minecraftVersionStorageResponse request
  | requestMethod request == methodGet && routePath == ["api", "v1", "events"] =
      pure (eventsResponse state)
  | requestMethod request == methodPost && routePath == ["api", "v1", "shutdown"] =
      shutdownResponse state
  | requestMethod request == methodGet && routePath == ["api", "v1", "tasks"] =
      tasksResponse state
  | requestMethod request == methodGet && routePath == ["api", "v1", "tasks", "history"] =
      taskHistoryResponse state request
  | requestMethod request == methodPost && routePath == ["api", "v1", "tasks", "history", "clear"] =
      clearTaskHistoryResponse state request
  | requestMethod request == methodGet && take 3 routePath == ["api", "v1", "tasks"] =
      taskResponse state (drop 3 routePath)
  | requestMethod request == methodPost && take 3 routePath == ["api", "v1", "tasks"] =
      cancelTaskResponse state (drop 3 routePath)
  | take 2 routePath == ["api", "v1"] =
      pure (jsonResponse status405 (object ["error" .= ("method_not_allowed" :: Text)]))
  | otherwise =
      pure (jsonResponse status404 (object ["error" .= ("not_found" :: Text)]))
  where
    routePath = pathInfo request

runShutdownHandler :: MVar (IO ()) -> IO ()
runShutdownHandler shutdownHandler = do
  shutdown <- readMVar shutdownHandler
  threadDelay 100000
  shutdown

isAuthorized :: ServerState -> Request -> Bool
isAuthorized state request =
  lookup hAuthorization (requestHeaders request)
    == Just ("Bearer " <> Text.encodeUtf8 (stateSessionToken state))

loadTaskHistory :: FilePath -> IO (Map.Map Text TaskSnapshot)
loadTaskHistory path = do
  exists <- doesFileExist path
  if not exists
    then pure Map.empty
    else do
      result <- eitherDecode <$> BL.readFile path
      case result of
        Left _ -> pure Map.empty
        Right tasks ->
          pure (Map.fromList [(taskSnapshotId task, task) | task <- tasks])

nextTaskCounterFrom :: Map.Map Text TaskSnapshot -> Int
nextTaskCounterFrom taskMap =
  case parsedSuffixes of
    [] -> 1
    suffixes -> maximum suffixes + 1
  where
    parsedSuffixes =
      mapMaybe (readMaybeText . lastTextSegment) (Map.keys taskMap)

lastTextSegment :: Text -> Text
lastTextSegment value =
  case Text.splitOn "-" value of
    [] -> value
    segments -> last segments

readMaybeText :: Text -> Maybe Int
readMaybeText value =
  case reads (Text.unpack value) of
    (parsed, ""):_ -> Just parsed
    _ -> Nothing
