{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Server.State
  ( ApiServerOptions(..)
  , ServerState(..)
  , apiServerGameDirPath
  , stateDefaultGameDirPath
  ) where

import Control.Concurrent.Async (Async)
import Control.Concurrent.STM (TVar)
import Data.Map.Strict (Map)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import Network.HTTP.Client (Manager)
import Panino.Api.Types (TaskSnapshot)
import Panino.Core.Types
  ( GameDir
  , gameDirPath
  )
import Panino.Events.Bus (EventBus)
import Panino.Multiplayer.Taowa.Session (TaowaRuntimeSession)

data ApiServerOptions = ApiServerOptions
  { apiServerHost :: String
  , apiServerPort :: Int
  , apiServerSessionToken :: Text
  , apiServerGameDir :: Maybe GameDir
  } deriving (Eq, Show)

data ServerState = ServerState
  { stateSessionToken :: Text
  , stateStartedAt :: UTCTime
  , stateDefaultGameDir :: Maybe GameDir
  , stateTasks :: TVar (Map Text TaskSnapshot)
  , stateTaskHistoryPath :: FilePath
  , stateTaskHandles :: TVar (Map Text (Async ()))
  , stateTaowaSessions :: TVar (Map Text TaowaRuntimeSession)
  , stateNextTaskId :: TVar Int
  , stateEvents :: EventBus
  , stateHttpManager :: Manager
  , stateShutdown :: IO ()
  }

apiServerGameDirPath :: ApiServerOptions -> Maybe FilePath
apiServerGameDirPath =
  fmap gameDirPath . apiServerGameDir

stateDefaultGameDirPath :: ServerState -> Maybe FilePath
stateDefaultGameDirPath =
  fmap gameDirPath . stateDefaultGameDir
