{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Multiplayer.Taowa.FrpcProcess
  ( TaowaFrpcProcess(..)
  , startFrpcProcess
  , stopFrpcProcess
  , validateFrpcExecutable
  ) where

import Control.Concurrent
  ( threadDelay
  )
import Control.Concurrent.Async
  ( Async
  , async
  , cancel
  , waitCatch
  )
import Control.Concurrent.MVar
  ( MVar
  , newMVar
  , withMVar
  )
import Control.Exception
  ( SomeException
  , catch
  , try
  )
import Control.Monad
  ( unless
  , void
  )
import qualified Data.ByteString as BS
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , executable
  , getPermissions
  )
import System.Exit (ExitCode)
import System.FilePath
  ( takeDirectory
  )
import System.IO
  ( Handle
  , IOMode(..)
  , hClose
  , hFlush
  , hSetBinaryMode
  , openBinaryFile
  )
import System.Timeout
  ( timeout
  )
import System.Process
  ( CreateProcess(..)
  , ProcessHandle
  , createProcess
  , getProcessExitCode
  , proc
  , std_err
  , std_out
  , terminateProcess
  , waitForProcess
  , StdStream(..)
  )

data TaowaFrpcProcess = TaowaFrpcProcess
  { taowaFrpcProcessHandle :: ProcessHandle
  , taowaFrpcStdoutPump :: Async ()
  , taowaFrpcStderrPump :: Async ()
  , taowaFrpcLogHandle :: Handle
  , taowaFrpcLogLock :: MVar ()
  , taowaFrpcLogPath :: FilePath
  }

validateFrpcExecutable :: FilePath -> IO (Either Text ())
validateFrpcExecutable frpcPath = do
  exists <- doesFileExist frpcPath
  if not exists
    then pure (Left "frpc executable was not found")
    else do
      permissions <- getPermissions frpcPath
      if executable permissions
        then pure (Right ())
        else pure (Left "frpc path is not executable")

startFrpcProcess :: FilePath -> FilePath -> FilePath -> IO (Either Text TaowaFrpcProcess)
startFrpcProcess frpcPath configPath logPath = do
  validation <- validateFrpcExecutable frpcPath
  case validation of
    Left err -> pure (Left err)
    Right () -> do
      createDirectoryIfMissing True (takeDirectory logPath)
      result <- try (startProcessUnchecked frpcPath configPath logPath)
      case result of
        Left (err :: SomeException) ->
          pure (Left ("failed to start frpc: " <> Text.pack (show err)))
        Right started -> do
          threadDelay 150000
          maybeExit <- getProcessExitCode (taowaFrpcProcessHandle started)
          case maybeExit of
            Nothing -> pure (Right started)
            Just exitCode -> do
              cleanupStartedProcess started
              pure (Left ("frpc exited during startup: " <> Text.pack (show exitCode)))

startProcessUnchecked :: FilePath -> FilePath -> FilePath -> IO TaowaFrpcProcess
startProcessUnchecked frpcPath configPath logPath = do
  logHandle <- openBinaryFile logPath AppendMode
  hSetBinaryMode logHandle True
  (_, maybeStdout, maybeStderr, processHandle) <-
    createProcess
      (proc frpcPath ["-c", configPath])
        { std_out = CreatePipe
        , std_err = CreatePipe
        }
  case (maybeStdout, maybeStderr) of
    (Just stdoutHandle, Just stderrHandle) -> do
      hSetBinaryMode stdoutHandle True
      hSetBinaryMode stderrHandle True
      logLock <- newMVar ()
      stdoutPump <- async (pumpHandle stdoutHandle logHandle logLock)
      stderrPump <- async (pumpHandle stderrHandle logHandle logLock)
      pure TaowaFrpcProcess
        { taowaFrpcProcessHandle = processHandle
        , taowaFrpcStdoutPump = stdoutPump
        , taowaFrpcStderrPump = stderrPump
        , taowaFrpcLogHandle = logHandle
        , taowaFrpcLogLock = logLock
        , taowaFrpcLogPath = logPath
        }
    _ -> do
      hClose logHandle
      fail "frpc stdout/stderr pipes were not created"

pumpHandle :: Handle -> Handle -> MVar () -> IO ()
pumpHandle source logHandle logLock =
  loop `catch` \(_ :: SomeException) -> pure ()
  where
    loop = do
      chunk <- BS.hGetSome source 4096
      unless (BS.null chunk) $ do
        withMVar logLock $ \() -> do
          BS.hPut logHandle chunk
          hFlush logHandle
        loop

stopFrpcProcess :: TaowaFrpcProcess -> IO ()
stopFrpcProcess process = do
  maybeExit <- getProcessExitCode (taowaFrpcProcessHandle process)
  case maybeExit of
    Nothing -> do
      terminateProcess (taowaFrpcProcessHandle process)
      void (try (waitForProcess (taowaFrpcProcessHandle process)) :: IO (Either SomeException ExitCode))
    Just _ -> pure ()
  cleanupStartedProcess process

cleanupStartedProcess :: TaowaFrpcProcess -> IO ()
cleanupStartedProcess process = do
  waitForPump (taowaFrpcStdoutPump process)
  waitForPump (taowaFrpcStderrPump process)
  withMVar (taowaFrpcLogLock process) $ \() -> do
    void (try (hFlush (taowaFrpcLogHandle process)) :: IO (Either SomeException ()))
    closeLogHandleWithRetry 5 (taowaFrpcLogHandle process)

waitForPump :: Async () -> IO ()
waitForPump pump = do
  finished <- timeout 500000 (waitCatch pump)
  case finished of
    Just _ -> pure ()
    Nothing -> do
      cancel pump
      void (timeout 500000 (waitCatch pump))

closeLogHandleWithRetry :: Int -> Handle -> IO ()
closeLogHandleWithRetry retries handle = do
  result <- try (hClose handle) :: IO (Either SomeException ())
  case result of
    Right () -> pure ()
    Left _
      | retries > 0 -> do
          threadDelay 50000
          closeLogHandleWithRetry (retries - 1) handle
      | otherwise -> pure ()
