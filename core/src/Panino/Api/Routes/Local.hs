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
  ( object
  , (.=)
  )
import Data.Text (Text)
import Network.HTTP.Types (status400)
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Params (decodeBody)
import Panino.Api.Response
  ( jsonResponse
  , localJsonResponse
  )
import qualified Panino.Content.Local as Local

javaCheckResponse :: Request -> IO Response
javaCheckResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right javaRequest ->
      localJsonResponse (Local.checkJavaRuntime javaRequest)

javaScanResponse :: IO Response
javaScanResponse =
  localJsonResponse Local.scanJavaRuntimes

javaDeleteLocalResponse :: Request -> IO Response
javaDeleteLocalResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right deleteRequest ->
      localJsonResponse (Local.deleteJavaRuntimeCandidate deleteRequest)

localResourceScanResponse :: Request -> IO Response
localResourceScanResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right scanRequest ->
      localJsonResponse (Local.scanLocalResources scanRequest)

localResourceToggleResponse :: Request -> IO Response
localResourceToggleResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right mutationRequest ->
      localJsonResponse (Local.toggleLocalResource mutationRequest)

localResourceDeleteResponse :: Request -> IO Response
localResourceDeleteResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right mutationRequest ->
      localJsonResponse (Local.deleteLocalResource mutationRequest)

localResourceImportResponse :: Request -> IO Response
localResourceImportResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right importRequest ->
      localJsonResponse (Local.importLocalResource importRequest)

localArchiveResponse :: Request -> IO Response
localArchiveResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right archiveRequest ->
      localJsonResponse (Local.archiveLocalDirectory archiveRequest)

localArchiveImportResponse :: Request -> IO Response
localArchiveImportResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right importRequest ->
      localJsonResponse (Local.importLocalArchive importRequest)

minecraftCleanVersionResponse :: Request -> IO Response
minecraftCleanVersionResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right cleanRequest ->
      localJsonResponse (Local.cleanMinecraftVersion cleanRequest)

minecraftVersionStorageResponse :: Request -> IO Response
minecraftVersionStorageResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right storageRequest ->
      localJsonResponse (Local.mutateMinecraftVersionStorage storageRequest)
