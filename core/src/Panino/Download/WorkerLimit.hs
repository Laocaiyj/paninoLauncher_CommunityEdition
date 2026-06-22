{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Download.WorkerLimit
  ( fileDescriptorWorkerLimit
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import System.Exit (ExitCode(..))
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )

fileDescriptorWorkerLimit :: IO Int
fileDescriptorWorkerLimit = do
  result <- try (readCreateProcessWithExitCode (proc "/bin/zsh" ["-lc", "ulimit -n"]) "") :: IO (Either SomeException (ExitCode, String, String))
  pure $ case result of
    Right (ExitSuccess, stdoutText, _) ->
      safeLimit (parseInt stdoutText)
    _ -> 32
  where
    safeLimit Nothing = 32
    safeLimit (Just value) =
      max 1 (min 64 ((value - 64) `div` 4))

parseInt :: String -> Maybe Int
parseInt value =
  case reads value of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing
