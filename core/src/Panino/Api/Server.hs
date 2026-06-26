{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Server
  ( ApiServerOptions(..)
  , runApiServer
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar
  ( MVar
  , newEmptyMVar
  , putMVar
  , readMVar
  )
import Control.Concurrent.STM
  ( newTVarIO
  )
import Control.Monad (when)
import Data.Aeson (eitherDecode)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import Data.String (fromString)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (getCurrentTime)
import Network.Wai.Handler.Warp
  ( defaultSettings
  , runSettings
  , setInstallShutdownHandler
  , setHost
  , setPort
  )
import Panino.Api.Server.Routing (application)
import Panino.Api.Server.State
  ( ApiServerOptions(..)
  , ServerState(..)
  )
import Panino.Api.Types
  ( TaskSnapshot
  , taskSnapshotId
  )
import Panino.Events.Bus (newEventBus)
import Panino.Minecraft.Manifest (makeHttpManager)
import Panino.Minecraft.Layout
  ( minecraftRoot
  , mkLayout
  )
import Panino.Multiplayer.Taowa.Session (markStaleTaowaSessions)
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  )

runApiServer :: ApiServerOptions -> IO ()
runApiServer options = do
  when (Text.null (apiServerSessionToken options)) $
    fail "serve requires a non-empty session token"
  eventBus <- newEventBus
  defaultLayout <- mkLayout (apiServerGameDir options)
  let taskHistoryPath = takeDirectory (minecraftRoot defaultLayout) </> "task-history.json"
      appRoot = takeDirectory (minecraftRoot defaultLayout)
  createDirectoryIfMissing True (takeDirectory taskHistoryPath)
  _ <- markStaleTaowaSessions appRoot
  initialTasks <- loadTaskHistory taskHistoryPath
  tasks <- newTVarIO initialTasks
  taskHandles <- newTVarIO Map.empty
  taowaSessions <- newTVarIO Map.empty
  nextTaskCounter <- newTVarIO (nextTaskCounterFrom initialTasks)
  shutdownHandler <- newEmptyMVar
  manager <- makeHttpManager
  startedAt <- getCurrentTime
  let state =
        ServerState
          { stateSessionToken = apiServerSessionToken options
          , stateStartedAt = startedAt
          , stateDefaultGameDir = apiServerGameDir options
          , stateTasks = tasks
          , stateTaskHistoryPath = taskHistoryPath
          , stateTaskHandles = taskHandles
          , stateTaowaSessions = taowaSessions
          , stateNextTaskId = nextTaskCounter
          , stateEvents = eventBus
          , stateHttpManager = manager
          , stateShutdown = runShutdownHandler shutdownHandler
          }
      settings =
        setInstallShutdownHandler (putMVar shutdownHandler)
          ( setHost (fromString (apiServerHost options))
              (setPort (apiServerPort options) defaultSettings)
          )
  putStrLn
    ( "panino-core serving on http://"
        <> apiServerHost options
        <> ":"
        <> show (apiServerPort options)
    )
  runSettings settings (application state)

runShutdownHandler :: MVar (IO ()) -> IO ()
runShutdownHandler shutdownHandler = do
  shutdown <- readMVar shutdownHandler
  threadDelay 100000
  shutdown

loadTaskHistory :: FilePath -> IO (Map.Map Text TaskSnapshot)
loadTaskHistory path = do
  exists <- doesFileExist path
  if not exists
    then pure Map.empty
    else do
      result <- eitherDecode <$> BL.readFile path
      case result of
        Left _ -> pure Map.empty
        Right tasks ->
          pure (Map.fromList [(taskSnapshotId task, task) | task <- tasks])

nextTaskCounterFrom :: Map.Map Text TaskSnapshot -> Int
nextTaskCounterFrom taskMap =
  case parsedSuffixes of
    [] -> 1
    suffixes -> maximum suffixes + 1
  where
    parsedSuffixes =
      mapMaybe (readMaybeText . lastTextSegment) (Map.keys taskMap)

lastTextSegment :: Text -> Text
lastTextSegment value =
  case Text.splitOn "-" value of
    [] -> value
    segments -> last segments

readMaybeText :: Text -> Maybe Int
readMaybeText value =
  case reads (Text.unpack value) of
    (parsed, ""):_ -> Just parsed
    _ -> Nothing
