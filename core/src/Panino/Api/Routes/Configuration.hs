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

import Data.Aeson
  ( FromJSON
  , object
  , (.=)
  )
import Data.Text (Text)
import Network.HTTP.Types
  ( status400
  )
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Params (decodeBody)
import Panino.Api.Response
  ( contentJsonResponse
  , jsonResponse
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
configurationCapabilitiesResponse =
  decodeAndRespond (localJsonResponse . configurationCapabilities)

versionSwitchPreflightResponse :: Request -> IO Response
versionSwitchPreflightResponse =
  decodeAndRespond (localJsonResponse . versionSwitchPreflight)

loaderCompatibilityResponse :: ServerState -> Request -> IO Response
loaderCompatibilityResponse state =
  decodeAndRespond (contentJsonResponse . loaderCompatibility (stateHttpManager state))

modpackPreflightResponse :: Request -> IO Response
modpackPreflightResponse =
  decodeAndRespond (localJsonResponse . modpackPreflight)

modpackImportResponse :: ServerState -> Request -> IO Response
modpackImportResponse state =
  decodeAndRespond (localJsonResponse . modpackImport (stateHttpManager state))

exportBackupPreflightResponse :: Request -> IO Response
exportBackupPreflightResponse =
  decodeAndRespond (localJsonResponse . exportBackupPreflight)

launchLibraryResponse :: Request -> IO Response
launchLibraryResponse =
  decodeAndRespond (localJsonResponse . launchLibrarySummary)

decodeAndRespond :: FromJSON body => (body -> IO Response) -> Request -> IO Response
decodeAndRespond handler request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right value ->
      handler value
