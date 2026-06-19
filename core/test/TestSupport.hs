module TestSupport
  ( assertEqual
  , createTarGz
  , catchAny
  , removeIfExists
  , safePathSuffix
  , sha256Hex
  , waitForMVar
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar (MVar, tryReadMVar)
import Control.Exception (SomeException, try)
import qualified Data.Text as Text
import System.Directory
  ( createDirectoryIfMissing
  , removeFile
  )
import System.Exit
  ( ExitCode(..)
  , exitFailure
  )
import System.FilePath (takeDirectory)
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual label expected actual =
  if actual == expected
    then pure ()
    else do
      putStrLn ("FAIL: " <> label)
      putStrLn ("  expected: " <> show expected)
      putStrLn ("  actual:   " <> show actual)
      exitFailure

catchAny :: IO a -> (SomeException -> IO a) -> IO a
catchAny action handler = do
  result <- try action
  either handler pure result

removeIfExists :: FilePath -> IO ()
removeIfExists path =
  removeFile path `catchAny` \_ -> pure ()

safePathSuffix :: String -> String
safePathSuffix =
  map (\char -> if char `elem` (['a'..'z'] <> ['A'..'Z'] <> ['0'..'9']) then char else '-')

createTarGz :: FilePath -> FilePath -> IO ()
createTarGz sourceRoot archivePath = do
  createDirectoryIfMissing True (takeDirectory archivePath)
  (_, _, _) <- readCreateProcessWithExitCode (proc "/usr/bin/tar" ["-czf", archivePath, "-C", sourceRoot, "."]) ""
  pure ()

sha256Hex :: FilePath -> IO Text.Text
sha256Hex path = do
  (exitCode, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc "/usr/bin/shasum" ["-a", "256", path]) ""
  case exitCode of
    ExitSuccess -> pure (Text.pack (takeWhile (/= ' ') stdoutText))
    ExitFailure _ -> fail stderrText

waitForMVar :: MVar a -> Int -> IO Bool
waitForMVar mvar attempts
  | attempts <= 0 = pure False
  | otherwise = do
      value <- tryReadMVar mvar
      case value of
        Just _ -> pure True
        Nothing -> do
          threadDelay 20000
          waitForMVar mvar (attempts - 1)
