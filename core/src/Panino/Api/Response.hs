{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Response
  ( ApiError(..)
  , apiError
  , apiErrorMessage
  , apiErrorResponse
  , contentJsonResponse
  , contentSourceErrorResponse
  , decodeJsonBodyResponse
  , diagnosticErrorResponse
  , invalidJsonResponse
  , jsonResponse
  , localJsonResponse
  ) where

import Control.Exception
  ( SomeException
  , catch
  )
import Data.Aeson
  ( FromJSON
  , ToJSON(..)
  , Value(..)
  , encode
  , object
  , (.=)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Types
  ( Status
  , hContentType
  , mkStatus
  , statusCode
  , status200
  , status400
  , status401
  )
import Network.Wai
  ( Request
  , Response
  , responseLBS
  )
import Panino.Api.Params (decodeBody)
import Panino.Diagnostics.Classify (diagnosticForApiError)
import Panino.Diagnostics.Types (Diagnostic(..))

data ApiError = ApiError
  { apiErrorCode :: Text
  , apiErrorMessageText :: Maybe Text
  , apiErrorDetailsText :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON ApiError where
  toJSON err =
    object $
      [ "error" .= apiErrorCode err
      ]
        <> maybe [] (\message -> ["message" .= message]) (apiErrorMessageText err)
        <> maybe [] (\details -> ["details" .= details]) (apiErrorDetailsText err)

apiError :: Text -> ApiError
apiError code =
  ApiError
    { apiErrorCode = code
    , apiErrorMessageText = Nothing
    , apiErrorDetailsText = Nothing
    }

apiErrorMessage :: Text -> Text -> ApiError
apiErrorMessage code message =
  ApiError
    { apiErrorCode = code
    , apiErrorMessageText = Just message
    , apiErrorDetailsText = Nothing
    }

apiErrorResponse :: Status -> ApiError -> Response
apiErrorResponse =
  jsonResponse

invalidJsonResponse :: Text -> Response
invalidJsonResponse message =
  apiErrorResponse status400 (apiErrorMessage "invalid_json" message)

decodeJsonBodyResponse :: FromJSON value => Request -> (value -> IO Response) -> IO Response
decodeJsonBodyResponse request handleDecoded = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse (Text.pack err))
    Right value -> handleDecoded value

jsonResponse :: ToJSON value => Status -> value -> Response
jsonResponse status value =
  responseLBS status [(hContentType, "application/json")] (encode (diagnosticErrorObject status (toJSON value)))

diagnosticErrorResponse :: Status -> Text -> Diagnostic -> Response
diagnosticErrorResponse status code diagnostic =
  jsonResponse status $
    object
      [ "error" .= code
      , "message" .= diagnosticMessage diagnostic
      , "diagnostic" .= diagnostic
      ]

diagnosticErrorObject :: Status -> Value -> Value
diagnosticErrorObject status (Object obj)
  | statusCode status >= 400
  , KeyMap.member (Key.fromText "error") obj
  , not (KeyMap.member (Key.fromText "diagnostic") obj) =
      Object $
        KeyMap.insert
          (Key.fromText "diagnostic")
          (toJSON (diagnosticForApiError errorCode "diagnostic" detail))
          obj
  where
    errorCode =
      case KeyMap.lookup (Key.fromText "error") obj of
        Just (String code) -> code
        _ -> "core_operation_failed"
    detail =
      case KeyMap.lookup (Key.fromText "message") obj of
        Just (String message) -> message
        _ ->
          case KeyMap.lookup (Key.fromText "details") obj of
            Just (String details) -> details
            _ -> errorCode
diagnosticErrorObject _ value =
  value

contentJsonResponse :: ToJSON value => IO value -> IO Response
contentJsonResponse action =
  (jsonResponse status200 <$> action)
    `catch` \(err :: SomeException) -> pure (contentSourceErrorResponse err)

localJsonResponse :: ToJSON value => IO value -> IO Response
localJsonResponse action =
  (jsonResponse status200 <$> action)
    `catch` \(err :: SomeException) ->
      pure
        ( jsonResponse
            (mkStatus 500 "Core Error")
            ( object
                [ "error" .= ("core_operation_failed" :: Text)
                , "message" .= Text.pack (show err)
                ]
            )
        )

contentSourceErrorResponse :: SomeException -> Response
contentSourceErrorResponse err =
  jsonResponse statusValue $
    object
      [ "error" .= code
      , "message" .= message
      , "details" .= details
      ]
  where
    details = Text.pack (show err)
    lowered = Text.toLower details
    contains value = value `Text.isInfixOf` lowered
    (statusValue, code, message)
      | contains "curseforge_api_key_required" =
          ( status401
          , "curseforge_api_key_required" :: Text
          , "CurseForge requires an API key. Add it in Settings or the Discover page." :: Text
          )
      | contains "unsupported content source" =
          ( status400
          , "unsupported_content_source"
          , "The selected content source is not supported."
          )
      | contains "content source returned http 401" || contains "content source returned http 403" =
          ( mkStatus 401 "Unauthorized"
          , "content_source_auth_failed"
          , "CurseForge rejected the API key. Check the key in Settings and try again."
          )
      | contains "content source returned http 429" =
          ( mkStatus 429 "Too Many Requests"
          , "content_source_rate_limited"
          , "The content source is rate limited. Wait a moment and retry."
          )
      | contains "content source returned http 5" || contains "something went wrong" =
          ( mkStatus 502 "Bad Gateway"
          , "content_source_unavailable"
          , "CurseForge returned an upstream error. Retry later or switch to Modrinth."
          )
      | contains "content source json parse failed" =
          ( mkStatus 502 "Bad Gateway"
          , "content_source_parse_failed"
          , "The content source returned data Panino could not parse."
          )
      | contains "httpexception" || contains "failed to resolve" || contains "connection" || contains "timeout" =
          ( mkStatus 502 "Bad Gateway"
          , "content_source_network_error"
          , "The content source request failed. Check your connection or proxy settings."
          )
      | otherwise =
          ( mkStatus 502 "Bad Gateway"
          , "content_source_failed"
          , "The content source request failed. Retry or switch content source."
          )
