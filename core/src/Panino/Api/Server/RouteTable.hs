{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Server.RouteTable
  ( routeTable
  ) where

import Data.Text (Text)
import Network.HTTP.Types
  ( methodDelete
  , methodGet
  , methodPost
  , methodPut
  )
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Routes.Compatibility
  ( compatibilityEvaluateResponse
  , compatibilityExplainResponse
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
import Panino.Api.Routes.Diagnostics
  ( diagnosticsProbeResponse
  , diagnosticsStatusResponse
  , environmentReportResponse
  )
import Panino.Api.Routes.GraphicsTuning
  ( graphicsTuningApplyResponse
  , graphicsTuningResolveResponse
  , graphicsTuningRollbackResponse
  )
import Panino.Api.Routes.Health (healthResponse)
import Panino.Api.Routes.InstallPlan (installPlanResolveResponse)
import Panino.Api.Routes.LaunchTuning
  ( launchTuningApplyResponse
  , launchTuningResolveResponse
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
import Panino.Api.Routes.Lockfile
  ( lockfileApplyResponse
  , lockfileCurrentResponse
  , lockfileDiffResponse
  , lockfileExplainResponse
  , lockfileSolveResponse
  , lockfileVerifyResponse
  )
import Panino.Api.Routes.Minecraft
  ( installPreflightResponse
  , installResponse
  , launchResponse
  )
import Panino.Api.Routes.Network
  ( effectiveNetworkConfigResponse
  , sourceTestResponse
  , speedTestResponse
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
import Panino.Api.Routes.PerformancePack
  ( performancePackInstallResponse
  , performancePackPlanResponse
  , performancePackRollbackResponse
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
import Panino.Api.Routes.TaowaMultiplayer
  ( taowaFrpProfileCreateResponse
  , taowaFrpProfileDeleteResponse
  , taowaFrpProfileTestResponse
  , taowaFrpProfileUpdateResponse
  , taowaFrpProfilesResponse
  , taowaLanDetectResponse
  , taowaLanValidatePortResponse
  , taowaRecommendationsResponse
  , taowaSessionHealthResponse
  , taowaSessionHistoryClearResponse
  , taowaSessionLogResponse
  , taowaSessionResponse
  , taowaSessionStartResponse
  , taowaSessionStopResponse
  , taowaSessionsResponse
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
import Panino.Api.Server.Router
  ( Captures
  , PathSegment(..)
  , RouteSpec
  , capture
  , capturesToList
  , dynamic
  , exact
  , rest
  )
import Panino.Api.Server.State (ServerState)

routeTable :: [RouteSpec]
routeTable =
  coreRoutes
    <> lockfileRoutes
    <> compatibilityRoutes
    <> tuningRoutes
    <> performanceRoutes
    <> contentRoutes
    <> configurationRoutes
    <> taowaRoutes
    <> networkRoutes
    <> diagnosticsRoutes
    <> runtimeRoutes
    <> localRoutes
    <> taskRoutes

coreRoutes :: [RouteSpec]
coreRoutes =
  [ exact methodGet ["health"] (noContext healthResponse)
  , exact methodPost ["install"] installResponse
  , exact methodPost ["install", "preflight"] installPreflightResponse
  , exact methodPost ["launch"] launchResponse
  , exact methodPost ["install-plan", "resolve"] installPlanResolveResponse
  ]

lockfileRoutes :: [RouteSpec]
lockfileRoutes =
  [ exact methodPost ["lockfile", "solve"] lockfileSolveResponse
  , exact methodPost ["lockfile", "apply"] lockfileApplyResponse
  , exact methodGet ["lockfile", "current"] lockfileCurrentResponse
  , exact methodPost ["lockfile", "diff"] lockfileDiffResponse
  , exact methodPost ["lockfile", "explain"] lockfileExplainResponse
  , exact methodPost ["lockfile", "verify"] lockfileVerifyResponse
  ]

compatibilityRoutes :: [RouteSpec]
compatibilityRoutes =
  [ exact methodPost ["compatibility", "evaluate"] compatibilityEvaluateResponse
  , exact methodPost ["compatibility", "explain"] compatibilityExplainResponse
  ]

tuningRoutes :: [RouteSpec]
tuningRoutes =
  [ exact methodPost ["launch", "tuning", "resolve"] (requestContext launchTuningResolveResponse)
  , exact methodPost ["launch", "tuning", "apply"] (requestContext launchTuningApplyResponse)
  , exact methodPost ["graphics", "tuning", "resolve"] (requestContext graphicsTuningResolveResponse)
  , exact methodPost ["graphics", "tuning", "apply"] (requestContext graphicsTuningApplyResponse)
  , exact methodPost ["graphics", "tuning", "rollback"] (requestContext graphicsTuningRollbackResponse)
  ]

performanceRoutes :: [RouteSpec]
performanceRoutes =
  [ exact methodPost ["performance", "pack", "plan"] performancePackPlanResponse
  , exact methodPost ["performance", "pack", "install"] performancePackInstallResponse
  , exact methodPost ["performance", "pack", "rollback"] (requestContext performancePackRollbackResponse)
  , exact methodPost ["performance", "session", "start"] (requestContext performanceSessionStartResponse)
  , exact methodPost ["performance", "session", "sample"] (requestContext performanceSessionSampleResponse)
  , exact methodPost ["performance", "session", "end"] (requestContext performanceSessionEndResponse)
  , exact methodPost ["performance", "profile", "resolve"] (requestContext performanceProfileResolveResponse)
  , exact methodPost ["performance", "profile", "candidate"] (requestContext performanceProfileCandidateResponse)
  , exact methodPost ["performance", "profile", "apply"] (requestContext performanceProfileApplyResponse)
  , exact methodPost ["performance", "profile", "rollback"] (requestContext performanceProfileRollbackResponse)
  , exact methodGet ["performance", "experiments"] performanceExperimentsResponse
  , dynamic methodGet [s "performance", s "evidence", rest] performanceEvidenceRoute
  ]

contentRoutes :: [RouteSpec]
contentRoutes =
  [ exact methodPost ["content", "install-plan"] contentInstallPlanResponse
  , exact methodPost ["content", "update-plan"] contentUpdatePlanResponse
  , exact methodPost ["content", "install"] contentInstallResponse
  , exact methodPost ["content", "resolve-targets"] contentResolveTargetsResponse
  , exact methodPost ["content", "search"] contentSearchResponse
  , exact methodPost ["content", "project"] contentProjectResponse
  , exact methodGet ["content", "minecraft", "versions"] (stateContext contentMinecraftVersionsResponse)
  , exact methodPost ["content", "minecraft", "install-status"] contentMinecraftInstallStatusResponse
  , exact methodPost ["content", "minecraft", "installed-instances"] contentMinecraftInstalledInstancesResponse
  , exact methodPost ["content", "minecraft", "package"] contentMinecraftPackageResponse
  , exact methodPost ["content", "loaders"] contentLoadersResponse
  , exact methodPost ["content", "loader-compatibility"] loaderCompatibilityResponse
  , exact methodPost ["content", "modpack", "preflight"] (requestContext modpackPreflightResponse)
  , exact methodPost ["content", "modpack", "import"] modpackImportResponse
  ]

configurationRoutes :: [RouteSpec]
configurationRoutes =
  [ exact methodPost ["config", "capabilities"] (requestContext configurationCapabilitiesResponse)
  , exact methodPost ["config", "version-switch-preflight"] (requestContext versionSwitchPreflightResponse)
  , exact methodPost ["config", "export-preflight"] (requestContext exportBackupPreflightResponse)
  , exact methodPost ["config", "launch-library"] (requestContext launchLibraryResponse)
  ]

taowaRoutes :: [RouteSpec]
taowaRoutes =
  [ exact methodPost ["taowa", "lan", "detect"] (requestContext taowaLanDetectResponse)
  , exact methodPost ["taowa", "lan", "validate-port"] (requestContext taowaLanValidatePortResponse)
  , exact methodGet ["taowa", "recommendations"] (stateContext taowaRecommendationsResponse)
  , exact methodGet ["taowa", "frp", "profiles"] (stateContext taowaFrpProfilesResponse)
  , exact methodPost ["taowa", "frp", "profiles"] taowaFrpProfileCreateResponse
  , dynamic methodPost [s "taowa", s "frp", s "profiles", capture, s "test"] taowaProfileTestRoute
  , dynamic methodPut [s "taowa", s "frp", s "profiles", rest] taowaProfileUpdateRoute
  , dynamic methodDelete [s "taowa", s "frp", s "profiles", rest] taowaProfileDeleteRoute
  , exact methodPost ["taowa", "sessions", "start"] taowaSessionStartResponse
  , exact methodPost ["taowa", "sessions", "clear-history"] taowaSessionHistoryClearResponse
  , exact methodGet ["taowa", "sessions"] (stateContext taowaSessionsResponse)
  , dynamic methodGet [s "taowa", s "sessions", capture, s "health"] taowaSessionHealthRoute
  , dynamic methodGet [s "taowa", s "sessions", capture, capture] taowaSessionLogRoute
  , dynamic methodGet [s "taowa", s "sessions", capture] taowaSessionRoute
  , dynamic methodPost [s "taowa", s "sessions", rest] taowaSessionPostRoute
  ]

networkRoutes :: [RouteSpec]
networkRoutes =
  [ exact methodGet ["network", "effective-config"] (noContext effectiveNetworkConfigResponse)
  , exact methodGet ["network", "source-test"] (stateContext sourceTestResponse)
  , exact methodPost ["network", "speed-test"] speedTestResponse
  ]

diagnosticsRoutes :: [RouteSpec]
diagnosticsRoutes =
  [ exact methodGet ["diagnostics", "status"] (stateContext diagnosticsStatusResponse)
  , exact methodPost ["diagnostics", "probe"] diagnosticsProbeResponse
  , exact methodGet ["environment", "report"] environmentReportResponse
  ]

runtimeRoutes :: [RouteSpec]
runtimeRoutes =
  [ exact methodPost ["runtime", "java", "check"] (requestContext javaCheckResponse)
  , exact methodGet ["runtime", "java", "scan"] (noContext javaScanResponse)
  , exact methodGet ["runtime", "java", "managed"] (stateContext javaRuntimeManagedResponse)
  , exact methodPost ["runtime", "java", "resolve"] javaRuntimeResolveResponse
  , exact methodGet ["runtime", "java", "catalog"] javaRuntimeCatalogResponse
  , exact methodPost ["runtime", "java", "select"] javaRuntimeSelectResponse
  , exact methodPost ["runtime", "java", "install"] javaRuntimeInstallResponse
  , exact methodPost ["runtime", "java", "verify"] javaRuntimeVerifyResponse
  , exact methodPost ["runtime", "java", "import"] javaRuntimeImportResponse
  , exact methodPost ["runtime", "java", "cleanup"] (stateContext javaRuntimeCleanupResponse)
  , exact methodPost ["runtime", "java", "local", "delete"] (requestContext javaDeleteLocalResponse)
  , dynamic methodDelete [s "runtime", s "java", s "managed", rest] javaRuntimeDeleteRoute
  ]

localRoutes :: [RouteSpec]
localRoutes =
  [ exact methodPost ["content", "local", "scan"] (requestContext localResourceScanResponse)
  , exact methodPost ["content", "local", "toggle"] (requestContext localResourceToggleResponse)
  , exact methodPost ["content", "local", "delete"] (requestContext localResourceDeleteResponse)
  , exact methodPost ["content", "local", "import"] (requestContext localResourceImportResponse)
  , exact methodPost ["content", "local", "archive"] (requestContext localArchiveResponse)
  , exact methodPost ["content", "local", "import-archive"] (requestContext localArchiveImportResponse)
  , exact methodPost ["content", "minecraft", "clean-version"] (requestContext minecraftCleanVersionResponse)
  , exact methodPost ["content", "minecraft", "version-storage"] (requestContext minecraftVersionStorageResponse)
  ]

taskRoutes :: [RouteSpec]
taskRoutes =
  [ exact methodGet ["events"] (\state _ -> pure (eventsResponse state))
  , exact methodPost ["shutdown"] (stateContext shutdownResponse)
  , exact methodGet ["tasks"] (stateContext tasksResponse)
  , exact methodGet ["tasks", "history"] taskHistoryResponse
  , exact methodPost ["tasks", "history", "clear"] clearTaskHistoryResponse
  , dynamic methodGet [s "tasks", rest] taskRoute
  , dynamic methodPost [s "tasks", rest] cancelRoute
  ]

s :: Text -> PathSegment
s = Static

noContext :: IO Response -> ServerState -> Request -> IO Response
noContext response _ _ = response

stateContext :: (ServerState -> IO Response) -> ServerState -> Request -> IO Response
stateContext action state _ = action state

requestContext :: (Request -> IO Response) -> ServerState -> Request -> IO Response
requestContext action _ request = action request

performanceEvidenceRoute :: Captures -> ServerState -> Request -> IO Response
performanceEvidenceRoute captures state request =
  performanceEvidenceResponse state request (capturesToList captures)

taowaProfileTestRoute :: Captures -> ServerState -> Request -> IO Response
taowaProfileTestRoute captures state _ =
  taowaFrpProfileTestResponse state (capturesToList captures <> ["test"])

taowaProfileUpdateRoute :: Captures -> ServerState -> Request -> IO Response
taowaProfileUpdateRoute captures state request =
  taowaFrpProfileUpdateResponse state (capturesToList captures) request

taowaProfileDeleteRoute :: Captures -> ServerState -> Request -> IO Response
taowaProfileDeleteRoute captures state _ =
  taowaFrpProfileDeleteResponse state (capturesToList captures)

taowaSessionHealthRoute :: Captures -> ServerState -> Request -> IO Response
taowaSessionHealthRoute captures state _ =
  taowaSessionHealthResponse state (capturesToList captures <> ["health"])

taowaSessionLogRoute :: Captures -> ServerState -> Request -> IO Response
taowaSessionLogRoute captures state _ =
  taowaSessionLogResponse state (capturesToList captures)

taowaSessionRoute :: Captures -> ServerState -> Request -> IO Response
taowaSessionRoute captures state _ =
  taowaSessionResponse state (capturesToList captures)

taowaSessionPostRoute :: Captures -> ServerState -> Request -> IO Response
taowaSessionPostRoute captures state _
  = taowaSessionStopResponse state (capturesToList captures)

javaRuntimeDeleteRoute :: Captures -> ServerState -> Request -> IO Response
javaRuntimeDeleteRoute captures state _ =
  javaRuntimeDeleteResponse state (capturesToList captures)

taskRoute :: Captures -> ServerState -> Request -> IO Response
taskRoute captures state _ =
  taskResponse state (capturesToList captures)

cancelRoute :: Captures -> ServerState -> Request -> IO Response
cancelRoute captures state _ =
  cancelTaskResponse state (capturesToList captures)
