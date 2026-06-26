{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Net.Http
  ( RequestTimeoutClass(..)
  , applyRequestTimeout
  , applyRequestTimeoutMicros
  , coreRequest
  , coreRequestWithTimeout
  , cacheRoot
  , fetchJson
  , fetchJsonUrl
  , fetchText
  , makeHttpManager
  , metadataRetryCount
  ) where

import Data.Aeson
  ( FromJSON
  , eitherDecode
  )
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Network.HTTP.Client
  ( Manager
  , Request
  )
import Panino.Net.Http.Fetch
  ( cacheRoot
  , fetchBytes
  , responseBodyPreview
  )
import Panino.Net.Http.Request
  ( RequestTimeoutClass(..)
  , applyRequestTimeout
  , applyRequestTimeoutMicros
  , coreRequest
  , coreRequestWithTimeout
  , makeHttpManager
  )
import Panino.Net.Http.Retry
  ( metadataRetryCount
  )

fetchJsonUrl :: FromJSON value => Manager -> String -> IO value
fetchJsonUrl manager url =
  fetchJson manager =<< coreRequest url []

fetchJson :: FromJSON value => Manager -> Request -> IO value
fetchJson manager request = do
  (status, body) <- fetchBytes manager request
  if status >= 200 && status < 300
    then
      case eitherDecode body of
        Right value -> pure value
        Left err -> fail ("content source JSON parse failed: " <> err)
    else fail ("content source returned HTTP " <> show status <> ": " <> Text.unpack (responseBodyPreview body))

fetchText :: Manager -> Request -> IO Text
fetchText manager request = do
  (status, body) <- fetchBytes manager request
  if status >= 200 && status < 300
    then pure (Text.decodeUtf8 (BL.toStrict body))
    else fail ("content source returned HTTP " <> show status <> ": " <> Text.unpack (responseBodyPreview body))
