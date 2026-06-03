module Panino.Launch.Java
  ( JavaRunResult(..)
  , JavaProcessLaunch(..)
  , runJavaProcess
  , runJavaProcessWithTelemetry
  , startJavaProcessWithTelemetry
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async
  ( async
  , wait
  )
import Data.Time.Clock
  ( UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Panino.Performance.Telemetry.Collect (sampleProcessMemory)
import Panino.Performance.Telemetry.Types (MemorySample)
import System.Exit (ExitCode)
import System.Directory (findExecutable)
import System.IO
  ( hGetContents
  , hPutStr
  )
import System.Process
  ( cwd
  , createProcess
  , getPid
  , getProcessExitCode
  , ProcessHandle
  , proc
  , readCreateProcessWithExitCode
  , std_err
  , std_out
  , StdStream(..)
  , waitForProcess
  )
import qualified System.IO as IO

data JavaRunResult = JavaRunResult
  { javaExitCode :: ExitCode
  , javaStdout :: String
  , javaStderr :: String
  , javaMemorySamples :: [MemorySample]
  } deriving (Eq, Show)

data JavaProcessLaunch = JavaProcessLaunch
  { javaLaunchProcessId :: Maybe Int
  , pollJavaProcessExitCode :: IO (Maybe ExitCode)
  , waitJavaProcess :: IO JavaRunResult
  }

runJavaProcess :: FilePath -> FilePath -> [String] -> IO JavaRunResult
runJavaProcess javaPath gameDirectory args = do
  executable <- resolveJavaExecutable javaPath
  (exitCode, stdoutText, stderrText) <-
    readCreateProcessWithExitCode (proc executable args) { cwd = Just gameDirectory } ""
  hPutStr IO.stdout stdoutText
  hPutStr IO.stderr stderrText
  pure JavaRunResult
    { javaExitCode = exitCode
    , javaStdout = stdoutText
    , javaStderr = stderrText
    , javaMemorySamples = []
    }

runJavaProcessWithTelemetry :: FilePath -> FilePath -> [String] -> IO JavaRunResult
runJavaProcessWithTelemetry javaPath gameDirectory args = do
  launch <- startJavaProcessWithTelemetry javaPath gameDirectory args
  waitJavaProcess launch

startJavaProcessWithTelemetry :: FilePath -> FilePath -> [String] -> IO JavaProcessLaunch
startJavaProcessWithTelemetry javaPath gameDirectory args = do
  executable <- resolveJavaExecutable javaPath
  startedAt <- getCurrentTime
  (_, Just stdoutHandle, Just stderrHandle, processHandle) <-
    createProcess
      (proc executable args)
        { cwd = Just gameDirectory
        , std_out = CreatePipe
        , std_err = CreatePipe
        }
  stdoutReader <- async (hGetContents stdoutHandle)
  stderrReader <- async (hGetContents stderrHandle)
  maybePid <- getPid processHandle
  samplesReader <-
    async $
      case maybePid of
        Nothing -> pure []
        Just pid -> sampleLoop startedAt (fromIntegral pid) processHandle []
  pure
    JavaProcessLaunch
      { javaLaunchProcessId = fromIntegral <$> maybePid
      , pollJavaProcessExitCode = getProcessExitCode processHandle
      , waitJavaProcess = do
          exitCode <- waitForProcess processHandle
          stdoutText <- wait stdoutReader
          stderrText <- wait stderrReader
          samples <- wait samplesReader
          hPutStr IO.stdout stdoutText
          hPutStr IO.stderr stderrText
          pure
            JavaRunResult
              { javaExitCode = exitCode
              , javaStdout = stdoutText
              , javaStderr = stderrText
              , javaMemorySamples = samples
              }
      }

sampleLoop :: UTCTime -> Int -> ProcessHandle -> [MemorySample] -> IO [MemorySample]
sampleLoop startedAt pid processHandle samples = do
  status <- getProcessExitCode processHandle
  now <- getCurrentTime
  let elapsedMs = round (realToFrac (diffUTCTime now startedAt) * 1000 :: Double)
  sample <- sampleProcessMemory pid elapsedMs
  let nextSamples = maybe samples (: samples) sample
  case status of
    Just _ -> pure (reverse nextSamples)
    Nothing -> do
      threadDelay 500000
      sampleLoop startedAt pid processHandle nextSamples

resolveJavaExecutable :: FilePath -> IO FilePath
resolveJavaExecutable javaPath = do
  found <- findExecutable javaPath
  case found of
    Just executable -> pure executable
    Nothing ->
      fail
        ( "Java executable not found: "
            <> javaPath
            <> ". Install Java 17+ or pass --java <path>."
        )
