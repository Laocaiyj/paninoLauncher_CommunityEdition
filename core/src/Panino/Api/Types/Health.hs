{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Types.Health
  ( HealthResponse(..)
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.Text (Text)
import Data.Time (UTCTime)

data HealthResponse = HealthResponse
  { healthStatus :: Text
  , healthService :: Text
  , healthTime :: UTCTime
  } deriving (Eq, Show)

instance ToJSON HealthResponse where
  toJSON response =
    object
      [ "status" .= healthStatus response
      , "service" .= healthService response
      , "time" .= healthTime response
      ]
