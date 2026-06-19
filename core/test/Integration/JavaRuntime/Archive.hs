{-# LANGUAGE OverloadedStrings #-}

module Integration.JavaRuntime.Archive
  ( assertJavaRuntimeArchiveSafety
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Time.Clock (getCurrentTime)
import Panino.Runtime.Java.Install (importJavaRuntime)
import Panino.Runtime.Java.Types
  ( JavaManagedRuntime
  , JavaRuntimeImportRequest(..)
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , removeDirectoryRecursive
  )
import System.Exit
  ( ExitCode(..)
  , exitFailure
  )
import System.FilePath ((</>))
import System.Posix.Files (createSymbolicLink)
import System.Process
  ( CreateProcess(..)
  , proc
  , readCreateProcessWithExitCode
  )
import TestSupport
  ( assertEqual
  , catchAny
  , safePathSuffix
  )

assertJavaRuntimeArchiveSafety :: FilePath -> IO ()
assertJavaRuntimeArchiveSafety tempDir = do
  now <- getCurrentTime
  let root = tempDir </> ("panino-java-archive-safety-" <> safePathSuffix (show now))
      traversalRoot = root </> "traversal"
      traversalArchive = traversalRoot </> "bad.zip"
      traversalOutside = root </> "outside.txt"
      symlinkRoot = root </> "symlink"
      symlinkArchive = symlinkRoot </> "bad-symlink.zip"
      appRoot = root </> "app"
  removeDirectoryRecursive root `catchAny` \_ -> pure ()
  createUnsafeTraversalZip traversalRoot traversalArchive
  traversalResult <- try (importRuntimeArchive appRoot traversalArchive)
  case (traversalResult :: Either SomeException JavaManagedRuntime) of
    Left _ -> pure ()
    Right _ -> do
      putStrLn "FAIL: unsafe zip traversal import"
      putStrLn "  expected: exception"
      putStrLn "  actual:   success"
      exitFailure
  escaped <- doesFileExist traversalOutside
  assertEqual "unsafe zip traversal does not create outside file" False escaped
  createUnsafeSymlinkZip symlinkRoot symlinkArchive
  symlinkResult <- try (importRuntimeArchive appRoot symlinkArchive)
  case (symlinkResult :: Either SomeException JavaManagedRuntime) of
    Left _ -> pure ()
    Right _ -> do
      putStrLn "FAIL: unsafe symlink zip import"
      putStrLn "  expected: exception"
      putStrLn "  actual:   success"
      exitFailure
  removeDirectoryRecursive root `catchAny` \_ -> pure ()

importRuntimeArchive :: FilePath -> FilePath -> IO JavaManagedRuntime
importRuntimeArchive appRoot archivePath =
  importJavaRuntime
    appRoot
    JavaRuntimeImportRequest
      { importRuntimeSourcePath = archivePath
      , importRuntimeProvider = "local"
      , importRuntimeVendor = "local"
      , importRuntimeFeatureVersion = Just 21
      , importRuntimeOs = Just "mac"
      , importRuntimeArch = Just "aarch64"
      , importRuntimeImageType = "jre"
      , importRuntimeSetDefault = False
      }

createUnsafeTraversalZip :: FilePath -> FilePath -> IO ()
createUnsafeTraversalZip sourceRoot archivePath = do
  createDirectoryIfMissing True (sourceRoot </> "inside")
  writeFile (sourceRoot </> "evil.txt") "escape"
  let process = (proc "/usr/bin/zip" ["-q", archivePath, "../evil.txt"]) { cwd = Just (sourceRoot </> "inside") }
  (exitCode, _, stderrText) <- readCreateProcessWithExitCode process ""
  assertEqual ("create unsafe traversal zip: " <> stderrText) ExitSuccess exitCode

createUnsafeSymlinkZip :: FilePath -> FilePath -> IO ()
createUnsafeSymlinkZip sourceRoot archivePath = do
  let runtimeRoot = sourceRoot </> "runtime"
      linkPath = runtimeRoot </> "escape-link"
  createDirectoryIfMissing True runtimeRoot
  createSymbolicLink "../outside" linkPath
  let process = (proc "/usr/bin/zip" ["-q", "-y", "-r", archivePath, "."]) { cwd = Just runtimeRoot }
  (exitCode, _, stderrText) <- readCreateProcessWithExitCode process ""
  assertEqual ("create unsafe symlink zip: " <> stderrText) ExitSuccess exitCode
