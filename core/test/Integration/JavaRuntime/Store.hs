{-# LANGUAGE OverloadedStrings #-}

module Integration.JavaRuntime.Store
  ( assertJavaRuntimeManagerStore
  ) where

import Control.Monad (when)
import Data.Aeson (encode)
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import qualified Data.Text as Text
import Data.Time.Clock (getCurrentTime)
import Panino.Runtime.Java.Resolve (resolveJavaRuntimeForRequirement)
import Panino.Runtime.Java.Store
  ( deleteManagedRuntime
  , readManagedRuntimes
  , selectJavaRuntimePolicy
  , upsertManagedRuntime
  )
import Panino.Runtime.Java.Types
  ( JavaManagedRuntime(..)
  , JavaRuntimeDeleteResponse(..)
  , JavaRuntimeDownloadSpec(..)
  , JavaRuntimeRequirement(..)
  , JavaRuntimeResolveRequest(..)
  , JavaRuntimeResolveResponse(..)
  , JavaRuntimeSelectRequest(..)
  )
import System.Directory
  ( createDirectoryIfMissing
  , removeDirectoryRecursive
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  )
import TestSupport
  ( assertEqual
  , catchAny
  , safePathSuffix
  )

assertJavaRuntimeManagerStore :: FilePath -> IO ()
assertJavaRuntimeManagerStore tempDir = do
  now <- getCurrentTime
  let appRoot = tempDir </> ("panino-java-runtime-manager-test-" <> safePathSuffix (show now))
      javaExecutable = appRoot </> "runtimes" </> "java" </> "managed" </> "temurin-21-test" </> "Contents" </> "Home" </> "bin" </> "java"
      java25Executable = appRoot </> "runtimes" </> "java" </> "managed" </> "temurin-25-test" </> "Contents" </> "Home" </> "bin" </> "java"
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
  createDirectoryIfMissing True (takeDirectory javaExecutable)
  writeFile javaExecutable "#!/bin/sh\n"
  runtime <-
    upsertManagedRuntime appRoot JavaManagedRuntime
      { managedRuntimeId = "temurin-21-test"
      , managedRuntimeVendor = "temurin"
      , managedRuntimeProvider = "adoptium"
      , managedRuntimeFeatureVersion = 21
      , managedRuntimeVersion = "21.0.0"
      , managedRuntimeOs = "mac"
      , managedRuntimeArch = "aarch64"
      , managedRuntimeImageType = "jre"
      , managedRuntimeJavaHome = takeDirectory (takeDirectory javaExecutable)
      , managedRuntimeJavaExecutable = javaExecutable
      , managedRuntimeSourceUrl = "https://example.invalid/java.tar.gz"
      , managedRuntimeSha256 = Just "abc"
      , managedRuntimeInstalledAt = now
      , managedRuntimeLastVerifiedAt = Just now
      , managedRuntimeDiskUsageBytes = Nothing
      , managedRuntimeUsedByInstanceCount = 0
      }
  assertEqual "managed runtime index writes runtime" "temurin-21-test" (managedRuntimeId runtime)
  _ <-
    upsertManagedRuntime appRoot runtime
      { managedRuntimeId = "temurin-25-test"
      , managedRuntimeFeatureVersion = 25
      , managedRuntimeVersion = "25.0.0"
      , managedRuntimeJavaHome = takeDirectory (takeDirectory java25Executable)
      , managedRuntimeJavaExecutable = java25Executable
      }
  resolved <-
    resolveJavaRuntimeForRequirement
      appRoot
      (JavaRuntimeResolveRequest "1.21.5" Nothing Nothing (Just "auto") Nothing Nothing)
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = "1.21.5"
        , javaRequirementMajorVersion = 21
        , javaRequirementComponent = Just "java-runtime-delta"
        , javaRequirementSource = "manifest"
        }
  assertEqual "managed runtime is selected before local Java" (Just "temurin-21-test") (resolveResponseSelectedRuntimeId resolved)
  resolvedExactMajor <-
    resolveJavaRuntimeForRequirement
      appRoot
      (JavaRuntimeResolveRequest "1.21.5" Nothing Nothing (Just "auto") Nothing Nothing)
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = "1.21.5"
        , javaRequirementMajorVersion = 21
        , javaRequirementComponent = Just "java-runtime-delta"
        , javaRequirementSource = "manifest"
        }
  assertEqual "auto Java prefers exact managed major over newer compatible runtime" (Just "temurin-21-test") (resolveResponseSelectedRuntimeId resolvedExactMajor)
  resolvedNewestMajor <-
    resolveJavaRuntimeForRequirement
      appRoot
      (JavaRuntimeResolveRequest "java-25" Nothing Nothing (Just "auto") Nothing Nothing)
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = "java-25"
        , javaRequirementMajorVersion = 25
        , javaRequirementComponent = Nothing
        , javaRequirementSource = "test"
        }
  assertEqual "auto Java still selects newer runtime when it is the exact requirement" (Just "temurin-25-test") (resolveResponseSelectedRuntimeId resolvedNewestMajor)
  _ <-
    selectJavaRuntimePolicy appRoot JavaRuntimeSelectRequest
      { selectRuntimeScope = "instance"
      , selectRuntimeInstanceId = Just "instance-a"
      , selectRuntimePolicy = "managed"
      , selectRuntimePreferredRuntimeId = Just "temurin-21-test"
      , selectRuntimeCustomPath = Nothing
      , selectRuntimeLockPatchVersion = True
      }
  runtimes <- readManagedRuntimes appRoot
  assertEqual
    "managed runtime usage count includes instance policy"
    [1]
    [managedRuntimeUsedByInstanceCount item | item <- runtimes, managedRuntimeId item == "temurin-21-test"]
  deleteResponse <- deleteManagedRuntime appRoot "temurin-21-test"
  assertEqual "referenced managed runtime delete is blocked" False (deleteRuntimeDeleted deleteResponse)
  assertEqual "referenced managed runtime delete lists instance" ["instance:instance-a"] (deleteRuntimeReferences deleteResponse)
  customResult <-
    resolveJavaRuntimeForRequirement
      appRoot
      (JavaRuntimeResolveRequest "1.16.5" Nothing Nothing (Just "custom") Nothing (Just (appRoot </> "missing-java")))
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = "1.16.5"
        , javaRequirementMajorVersion = 8
        , javaRequirementComponent = Nothing
        , javaRequirementSource = "fallback"
        }
  assertEqual "custom policy only trusts custom path when valid" "incompatible" (resolveResponseStatus customResult)
  modernFallback <-
    resolveJavaRuntimeForRequirement
      appRoot
      (JavaRuntimeResolveRequest "1.16.5" Nothing Nothing (Just "auto") Nothing Nothing)
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = "1.16.5"
        , javaRequirementMajorVersion = 8
        , javaRequirementComponent = Nothing
        , javaRequirementSource = "fallback"
        }
  assertEqual "legacy fallback does not select modern managed Java" Nothing (resolveResponseSelectedRuntimeId modernFallback)
  assertJavaRuntimeResolutionMatrix appRoot
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
  assertManagedIndexRebuild tempDir runtime

assertJavaRuntimeResolutionMatrix :: FilePath -> IO ()
assertJavaRuntimeResolutionMatrix appRoot =
  mapM_ assertRequirement [8, 16, 17, 21, 25]
  where
    assertRequirement major = do
      response <-
        resolveJavaRuntimeForRequirement
          appRoot
          (JavaRuntimeResolveRequest (Text.pack ("java-" <> show major)) Nothing Nothing (Just "auto") Nothing Nothing)
          JavaRuntimeRequirement
            { javaRequirementMinecraftVersion = Text.pack ("java-" <> show major)
            , javaRequirementMajorVersion = major
            , javaRequirementComponent = Nothing
            , javaRequirementSource = "test"
            }
      assertEqual ("resolution keeps required Java " <> show major) major (resolveResponseRequiredMajorVersion response)
      when (resolveResponseStatus response == "downloadable") $
        assertEqual
          ("downloadable resolution points at Java " <> show major)
          (Just major)
          (runtimeDownloadFeatureVersion <$> resolveResponseDownload response)

assertManagedIndexRebuild :: FilePath -> JavaManagedRuntime -> IO ()
assertManagedIndexRebuild tempDir runtime = do
  now <- getCurrentTime
  let appRoot = tempDir </> ("panino-java-runtime-rebuild-test-" <> safePathSuffix (show now))
      runtimeId = managedRuntimeId runtime
      runtimeDir = appRoot </> "runtimes" </> "java" </> "managed" </> Text.unpack runtimeId
      runtimeJson = runtimeDir </> "runtime.json"
      indexJson = appRoot </> "runtimes" </> "java" </> "managed-index.json"
      javaExecutable = runtimeDir </> "Contents" </> "Home" </> "bin" </> "java"
      rebuildRuntime =
        runtime
          { managedRuntimeJavaHome = takeDirectory (takeDirectory javaExecutable)
          , managedRuntimeJavaExecutable = javaExecutable
          }
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
  createDirectoryIfMissing True (takeDirectory runtimeJson)
  BL.writeFile runtimeJson (encode rebuildRuntime)
  createDirectoryIfMissing True (takeDirectory indexJson)
  BS8.writeFile indexJson "{not json"
  rebuilt <- readManagedRuntimes appRoot
  assertEqual "managed index rebuilds from runtime json" [runtimeId] (map managedRuntimeId rebuilt)
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
