{-# LANGUAGE OverloadedStrings #-}

module Integration.JavaRuntime.Local
  ( assertJavaRuntimeCheckSummary
  , assertJavaRuntimeLocalDeleteSafety
  ) where

import qualified Data.ByteString.Char8 as BS8
import Data.Time.Clock (getCurrentTime)
import Panino.Content.Local.Java
  ( checkJavaRuntime
  , deleteJavaRuntimeCandidate
  )
import Panino.Content.Local.Types
  ( JavaCheckRequest(..)
  , JavaCheckResponse(..)
  , JavaRuntimeLocalDeleteRequest(..)
  , JavaRuntimeLocalDeleteResponse(..)
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , removeDirectoryRecursive
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  )
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )
import TestFixtures (fakeJavaSettingsScript)
import TestSupport
  ( assertEqual
  , catchAny
  , safePathSuffix
  )

assertJavaRuntimeCheckSummary :: FilePath -> IO ()
assertJavaRuntimeCheckSummary tempDir = do
  now <- getCurrentTime
  let appRoot = tempDir </> ("panino-java-check-summary-test-" <> safePathSuffix (show now))
      javaExecutable = appRoot </> "bin" </> "java"
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
  createDirectoryIfMissing True (takeDirectory javaExecutable)
  BS8.writeFile javaExecutable (BS8.pack fakeJavaSettingsScript)
  _ <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", javaExecutable]) ""
  response <- checkJavaRuntime (JavaCheckRequest (Just javaExecutable))
  assertEqual
    "java check summary uses parsed runtime details"
    "Java 21.0.0 · Panino Test · aarch64"
    (javaResponseSummary response)
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()

assertJavaRuntimeLocalDeleteSafety :: FilePath -> IO ()
assertJavaRuntimeLocalDeleteSafety tempDir = do
  now <- getCurrentTime
  let appRoot = tempDir </> ("panino-java-local-delete-test-" <> safePathSuffix (show now))
      bundleRoot = appRoot </> "Library" </> "Java" </> "JavaVirtualMachines" </> "test-21.jdk"
      javaExecutable = bundleRoot </> "Contents" </> "Home" </> "bin" </> "java"
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
  blocked <- deleteJavaRuntimeCandidate (JavaRuntimeLocalDeleteRequest "/usr/bin/java")
  assertEqual "system Java delete is blocked" False (javaLocalDeleteDeleted blocked)
  createDirectoryIfMissing True (takeDirectory javaExecutable)
  writeFile javaExecutable "#!/bin/sh\n"
  deleted <- deleteJavaRuntimeCandidate (JavaRuntimeLocalDeleteRequest javaExecutable)
  assertEqual "self-contained jdk bundle can be deleted" True (javaLocalDeleteDeleted deleted)
  exists <- doesDirectoryExist bundleRoot
  assertEqual "deleted jdk bundle directory is gone" False exists
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
