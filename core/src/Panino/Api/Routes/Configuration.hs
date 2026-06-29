{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Configuration
  ( configurationCapabilitiesResponse
  , exportBackupPreflightResponse
  , launchLibraryResponse
  , loaderCompatibilityResponse
  , modpackImportResponse
  , modpackPreflightResponse
  , versionSwitchPreflightResponse
  ) where

import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Response
  ( contentJsonResponse
  , decodeJsonBodyResponse
  , localJsonResponse
  )
import Panino.Api.Server.State (ServerState(..))
import Panino.Content.Configuration.Preflight
  ( configurationCapabilities
  , exportBackupPreflight
  , launchLibrarySummary
  , loaderCompatibility
  , modpackImport
  , modpackPreflight
  , versionSwitchPreflight
  )

configurationCapabilitiesResponse :: Request -> IO Response
configurationCapabilitiesResponse request =
  decodeJsonBodyResponse request (localJsonResponse . configurationCapabilities)

versionSwitchPreflightResponse :: Request -> IO Response
versionSwitchPreflightResponse request =
  decodeJsonBodyResponse request (localJsonResponse . versionSwitchPreflight)

loaderCompatibilityResponse :: ServerState -> Request -> IO Response
loaderCompatibilityResponse state request =
  decodeJsonBodyResponse request (contentJsonResponse . loaderCompatibility (stateHttpManager state))

modpackPreflightResponse :: Request -> IO Response
modpackPreflightResponse request =
  decodeJsonBodyResponse request (localJsonResponse . modpackPreflight)

modpackImportResponse :: ServerState -> Request -> IO Response
modpackImportResponse state request =
  decodeJsonBodyResponse request (localJsonResponse . modpackImport (stateHttpManager state))

exportBackupPreflightResponse :: Request -> IO Response
exportBackupPreflightResponse request =
  decodeJsonBodyResponse request (localJsonResponse . exportBackupPreflight)

launchLibraryResponse :: Request -> IO Response
launchLibraryResponse request =
  decodeJsonBodyResponse request (localJsonResponse . launchLibrarySummary)
