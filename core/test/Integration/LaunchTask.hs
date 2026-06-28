{-# LANGUAGE OverloadedStrings #-}

module Integration.LaunchTask
  ( assertLaunchHooksAreBestEffort
  , assertLaunchTaskCompletesAfterProcessStart
  , assertLaunchTaskFailsOnEarlyProcessExit
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar
  ( newEmptyMVar
  , putMVar
  , readMVar
  )
import Control.Concurrent.STM
  ( newTVarIO
  , readTVarIO
  )
import Control.Monad (when)
import qualified Data.ByteString.Lazy.Char8 as BL8
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.List (isInfixOf)
import Data.Time.Clock (getCurrentTime)
import Panino.Api.Routes.Minecraft.LaunchHooks
  ( LaunchHookSession(..)
  , beginLaunchHooks
  , runBestEffortLaunchChecks
  )
import Panino.Api.Routes.Minecraft.LaunchTask
  ( launchTaskOutcomeText
  , observeStartedLaunchWithDelay
  )
import Panino.Api.Routes.Tasks (startTaskWithGameDirContext)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( DownloadRuntimeOptions(..)
  , LaunchRequest(..)
  , TaskSnapshot(..)
  , TaskState(..)
  , taskProgressOverallPercent
  )
import Panino.Events.Bus (newEventBus)
import Panino.Launch.Java
  ( JavaProcessLaunch(..)
  , JavaRunResult(..)
  )
import Panino.Launch.Tuning.Recommend (recommendJvmTuning)
import Panino.Launch.Tuning.Types (defaultJvmTuningRequest)
import Panino.Minecraft.Layout
  ( mkLayout
  , minecraftRoot
  )
import Panino.Net.Http (makeHttpManager)
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , removeDirectoryRecursive
  )
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
import TestFixtures (testVersionJson)
import TestSupport
  ( assertEqual
  , waitForMVar
  )

assertLaunchTaskCompletesAfterProcessStart :: FilePath -> IO ()
assertLaunchTaskCompletesAfterProcessStart tempRoot = do
  let gameDir = tempRoot </> "panino-launch-task-terminal"
      historyPath = gameDir </> "task-history.json"
  exists <- doesDirectoryExist gameDir
  when exists (removeDirectoryRecursive gameDir)
  createDirectoryIfMissing True gameDir
  now <- getCurrentTime
  tasks <- newTVarIO Map.empty
  taskHandles <- newTVarIO Map.empty
  nextTaskId <- newTVarIO 1
  taowaSessions <- newTVarIO Map.empty
  events <- newEventBus
  manager <- makeHttpManager
  processFinished <- newEmptyMVar
  hookCompleted <- newEmptyMVar
  let state =
        ServerState
          { stateSessionToken = "test-token"
          , stateStartedAt = now
          , stateDefaultGameDir = Just gameDir
          , stateTasks = tasks
          , stateTaskHistoryPath = historyPath
          , stateTaskHandles = taskHandles
          , stateNextTaskId = nextTaskId
          , stateTaowaSessions = taowaSessions
          , stateEvents = events
          , stateHttpManager = manager
          , stateShutdown = pure ()
          }
  task <-
    startTaskWithGameDirContext state "launch" "test-version" (Just gameDir) $ \snapshot -> do
      layout <- mkLayout (Just gameDir)
      let hooks =
            LaunchHookSession
              { launchHookJvmArgs = []
              , completeLaunchHookSession = const (putMVar hookCompleted ())
              }
          launch =
            JavaProcessLaunch
              { javaLaunchProcessId = Just 123
              , pollJavaProcessExitCode = pure Nothing
              , waitJavaProcess = readMVar processFinished
              }
      launchTaskOutcomeText <$> observeStartedLaunchWithDelay 1000 state snapshot layout hooks launch
  taskState <- waitForTaskState state (taskSnapshotId task) TaskSucceeded 100
  latest <- Map.lookup (taskSnapshotId task) <$> readTVarIO (stateTasks state)
  assertEqual "launch task succeeds after Java process starts" (Just TaskSucceeded) taskState
  assertEqual
    "launch task terminal progress reaches 100"
    (Just 100)
    (maybe Nothing taskProgressOverallPercent (taskSnapshotProgress =<< latest))
  putMVar processFinished JavaRunResult { javaExitCode = ExitSuccess, javaStdout = "", javaStderr = "", javaMemorySamples = [] }
  assertEqual "launch background monitor completes hooks" True =<< waitForMVar hookCompleted 100

assertLaunchTaskFailsOnEarlyProcessExit :: FilePath -> IO ()
assertLaunchTaskFailsOnEarlyProcessExit tempRoot = do
  let gameDir = tempRoot </> "panino-launch-task-early-exit"
      historyPath = gameDir </> "task-history.json"
  exists <- doesDirectoryExist gameDir
  when exists (removeDirectoryRecursive gameDir)
  createDirectoryIfMissing True gameDir
  now <- getCurrentTime
  tasks <- newTVarIO Map.empty
  taskHandles <- newTVarIO Map.empty
  nextTaskId <- newTVarIO 1
  taowaSessions <- newTVarIO Map.empty
  events <- newEventBus
  manager <- makeHttpManager
  hookCompleted <- newEmptyMVar
  let state =
        ServerState
          { stateSessionToken = "test-token"
          , stateStartedAt = now
          , stateDefaultGameDir = Just gameDir
          , stateTasks = tasks
          , stateTaskHistoryPath = historyPath
          , stateTaskHandles = taskHandles
          , stateNextTaskId = nextTaskId
          , stateTaowaSessions = taowaSessions
          , stateEvents = events
          , stateHttpManager = manager
          , stateShutdown = pure ()
          }
  task <-
    startTaskWithGameDirContext state "launch" "test-version" (Just gameDir) $ \snapshot -> do
      layout <- mkLayout (Just gameDir)
      let hooks =
            LaunchHookSession
              { launchHookJvmArgs = []
              , completeLaunchHookSession = const (putMVar hookCompleted ())
              }
          launch =
            JavaProcessLaunch
              { javaLaunchProcessId = Just 456
              , pollJavaProcessExitCode = pure (Just (ExitFailure 1))
              , waitJavaProcess =
                  pure JavaRunResult
                    { javaExitCode = ExitFailure 1
                    , javaStdout = ""
                    , javaStderr = "quilt loader failed"
                    , javaMemorySamples = []
                    }
              }
      launchTaskOutcomeText <$> observeStartedLaunchWithDelay 1000 state snapshot layout hooks launch
  taskState <- waitForTaskState state (taskSnapshotId task) TaskFailed 100
  latest <- Map.lookup (taskSnapshotId task) <$> readTVarIO (stateTasks state)
  assertEqual "launch task fails when Java exits inside startup grace period" (Just TaskFailed) taskState
  assertEqual "early launch failure completes hooks" True =<< waitForMVar hookCompleted 100
  assertEqual
    "early launch failure records diagnostic"
    True
    (maybe False (not . null . taskSnapshotDiagnostics) latest)

waitForTaskState :: ServerState -> Text -> TaskState -> Int -> IO (Maybe TaskState)
waitForTaskState state taskId desired attempts
  | attempts <= 0 = pure Nothing
  | otherwise = do
      taskMap <- readTVarIO (stateTasks state)
      let current = taskSnapshotState <$> Map.lookup taskId taskMap
      case current of
        Just value | value == desired -> pure current
        Just TaskFailed -> pure current
        Just TaskCancelled -> pure current
        _ -> do
          threadDelay 20000
          waitForTaskState state taskId desired (attempts - 1)

assertLaunchHooksAreBestEffort :: FilePath -> IO ()
assertLaunchHooksAreBestEffort tempRoot = do
  let lockfileRoot = tempRoot </> "panino-launch-hook-lockfile"
  lockfileExists <- doesDirectoryExist lockfileRoot
  when lockfileExists (removeDirectoryRecursive lockfileRoot)
  lockfileLayout <- mkLayout (Just lockfileRoot)
  createDirectoryIfMissing True (minecraftRoot lockfileLayout </> ".panino")
  BL8.writeFile (minecraftRoot lockfileLayout </> ".panino" </> "panino-lock.json") "{bad-lockfile-json"
  runBestEffortLaunchChecks lockfileLayout testVersionJson
  lockfileHookLog <- BL8.readFile (minecraftRoot lockfileLayout </> "downloads" </> "launch-hooks.log")
  assertEqual "lockfile hook failure is logged but non-blocking" True ("lockfile_verify" `isInfixOf` BL8.unpack lockfileHookLog)

  let blockedRoot = tempRoot </> "panino-launch-hook-blocked-root"
  blockedRootIsDir <- doesDirectoryExist blockedRoot
  when blockedRootIsDir (removeDirectoryRecursive blockedRoot)
  BL8.writeFile blockedRoot "not a directory"
  blockedLayout <- mkLayout (Just blockedRoot)
  hooks <- beginLaunchHooks blockedLayout testVersionJson minimalLaunchRequest (recommendJvmTuning defaultJvmTuningRequest)
  assertEqual "performance hook failure falls back to no JVM args" [] (launchHookJvmArgs hooks)
  completeLaunchHookSession hooks JavaRunResult { javaExitCode = ExitSuccess, javaStdout = "", javaStderr = "", javaMemorySamples = [] }

minimalLaunchRequest :: LaunchRequest
minimalLaunchRequest =
  LaunchRequest
    { launchRequestVersion = "test-version"
    , launchRequestGameDir = Just "/tmp/panino-test"
    , launchRequestMemoryMb = Nothing
    , launchRequestJavaPath = Nothing
    , launchRequestInstanceId = Nothing
    , launchRequestLoader = Nothing
    , launchRequestMemoryPolicy = Nothing
    , launchRequestJvmProfile = Nothing
    , launchRequestCustomMemoryMb = Nothing
    , launchRequestUsername = Nothing
    , launchRequestUuid = Nothing
    , launchRequestAccessToken = Nothing
    , launchRequestJvmArgs = []
    , launchRequestCustomJvmArgs = []
    , launchRequestModCount = Nothing
    , launchRequestResourcePackCount = Nothing
    , launchRequestShaderPackCount = Nothing
    , launchRequestWindowWidth = Nothing
    , launchRequestWindowHeight = Nothing
    , launchRequestDownload = DownloadRuntimeOptions Nothing Nothing Nothing
    , launchRequestInstallBefore = Nothing
    }
