{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Types.Events
  ( ApiEvent(..)
  ) where

import Data.Aeson
  ( ToJSON(..)
  , Value
  , object
  , (.=)
  )
import Data.Text (Text)
import Data.Time (UTCTime)

data ApiEvent = ApiEvent
  { apiEventType :: Text
  , apiEventTaskId :: Maybe Text
  , apiEventVersion :: Maybe Text
  , apiEventMessage :: Text
  , apiEventAt :: UTCTime
  , apiEventPayload :: Value
  } deriving (Eq, Show)

instance ToJSON ApiEvent where
  toJSON event =
    object
      [ "type" .= apiEventType event
      , "taskId" .= apiEventTaskId event
      , "version" .= apiEventVersion event
      , "message" .= apiEventMessage event
      , "time" .= apiEventAt event
      , "payload" .= apiEventPayload event
      ]
