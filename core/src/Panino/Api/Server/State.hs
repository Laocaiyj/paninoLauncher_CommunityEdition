{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Server.State
  ( ApiServerOptions(..)
  , ServerState(..)
  ) where

import Control.Concurrent.Async (Async)
import Control.Concurrent.STM (TVar)
import Data.Map.Strict (Map)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Network.HTTP.Client (Manager)
import Panino.Api.Types (TaskSnapshot)
import Panino.Events.Bus (EventBus)
import Panino.Multiplayer.Taowa.Session (TaowaRuntimeSession)

data ApiServerOptions = ApiServerOptions
  { apiServerHost :: String
  , apiServerPort :: Int
  , apiServerSessionToken :: Text
  , apiServerGameDir :: Maybe FilePath
  } deriving (Eq, Show)

data ServerState = ServerState
  { stateSessionToken :: Text
  , stateStartedAt :: UTCTime
  , stateDefaultGameDir :: Maybe FilePath
  , stateTasks :: TVar (Map Text TaskSnapshot)
  , stateTaskHistoryPath :: FilePath
  , stateTaskHandles :: TVar (Map Text (Async ()))
  , stateTaowaSessions :: TVar (Map Text TaowaRuntimeSession)
  , stateNextTaskId :: TVar Int
  , stateEvents :: EventBus
  , stateHttpManager :: Manager
  , stateShutdown :: IO ()
  }
