{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Health
  ( healthResponse
  ) where

import Network.HTTP.Types (status200)
import Network.Wai (Response)
import Panino.Api.Response (jsonResponse)
import Panino.Api.Types (HealthResponse(..))
import Data.Time (getCurrentTime)

healthResponse :: IO Response
healthResponse = do
  now <- getCurrentTime
  pure
    ( jsonResponse status200
        HealthResponse
          { healthStatus = "ok"
          , healthService = "panino-core"
          , healthTime = now
          }
    )
