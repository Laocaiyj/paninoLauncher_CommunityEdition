{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Local
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
  ) where

import Data.Aeson
  ( FromJSON
  , ToJSON
  )
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Response
  ( decodeJsonBodyResponse
  , localJsonResponse
  )
import qualified Panino.Content.Local as Local

javaCheckResponse :: Request -> IO Response
javaCheckResponse request =
  decodeLocalJsonResponse request Local.checkJavaRuntime

javaScanResponse :: IO Response
javaScanResponse =
  localJsonResponse Local.scanJavaRuntimes

javaDeleteLocalResponse :: Request -> IO Response
javaDeleteLocalResponse request =
  decodeLocalJsonResponse request Local.deleteJavaRuntimeCandidate

localResourceScanResponse :: Request -> IO Response
localResourceScanResponse request =
  decodeLocalJsonResponse request Local.scanLocalResources

localResourceToggleResponse :: Request -> IO Response
localResourceToggleResponse request =
  decodeLocalJsonResponse request Local.toggleLocalResource

localResourceDeleteResponse :: Request -> IO Response
localResourceDeleteResponse request =
  decodeLocalJsonResponse request Local.deleteLocalResource

localResourceImportResponse :: Request -> IO Response
localResourceImportResponse request =
  decodeLocalJsonResponse request Local.importLocalResource

localArchiveResponse :: Request -> IO Response
localArchiveResponse request =
  decodeLocalJsonResponse request Local.archiveLocalDirectory

localArchiveImportResponse :: Request -> IO Response
localArchiveImportResponse request =
  decodeLocalJsonResponse request Local.importLocalArchive

minecraftCleanVersionResponse :: Request -> IO Response
minecraftCleanVersionResponse request =
  decodeLocalJsonResponse request Local.cleanMinecraftVersion

minecraftVersionStorageResponse :: Request -> IO Response
minecraftVersionStorageResponse request =
  decodeLocalJsonResponse request Local.mutateMinecraftVersionStorage

decodeLocalJsonResponse :: (FromJSON requestBody, ToJSON responseBody) => Request -> (requestBody -> IO responseBody) -> IO Response
decodeLocalJsonResponse request handler =
  decodeJsonBodyResponse request (localJsonResponse . handler)
