{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Network
  ( effectiveNetworkConfigValue
  , effectiveNetworkConfigResponse
  , speedTestResponse
  , speedTestValue
  , sourceTestValue
  , sourceTestResponse
  ) where

import Data.Aeson
  ( object
  , (.=)
  )
import Data.Text (Text)
import Network.HTTP.Types
  ( status200
  , status400
  )
import Network.Wai
  ( Request
  , Response
  , strictRequestBody
  )
import Panino.Api.Response (jsonResponse)
import Panino.Api.Routes.Network.Config (effectiveNetworkConfigValue)
import Panino.Api.Routes.Network.Probe (sourceTestValue)
import Panino.Api.Routes.Network.SpeedTest
  ( decodeSpeedTestRequest
  , speedTestValue
  )
import Panino.Api.Server.State (ServerState)

effectiveNetworkConfigResponse :: IO Response
effectiveNetworkConfigResponse =
  jsonResponse status200 <$> effectiveNetworkConfigValue

sourceTestResponse :: ServerState -> IO Response
sourceTestResponse state =
  jsonResponse status200 <$> sourceTestValue state

speedTestResponse :: ServerState -> Request -> IO Response
speedTestResponse state request = do
  body <- strictRequestBody request
  case decodeSpeedTestRequest body of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right speedRequest ->
      jsonResponse status200 <$> speedTestValue state speedRequest
