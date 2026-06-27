{-# LANGUAGE OverloadedStrings #-}

module Integration.ModrinthDependencyResolver.JavaPolicy
  ( assertLockfileJavaPolicySolves
  ) where

import Data.Aeson
  ( encode
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List (isInfixOf)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (getCurrentTime)
import Panino.Install.Plan.Types (TypedInstallPlan(..))
import Panino.Lockfile.Types
  ( LockfileSolveRequest(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , solveRequestTargetGameDirPath
  , SolverResult
  , solverResultBlockedReasons
  , solverResultLockfile
  , solverResultStatus
  , solverResultTypedPlan
  )
import Panino.Runtime.Java.Catalog (defaultRuntimeArch)
import Panino.Runtime.Java.Store (upsertManagedRuntime)
import Panino.Runtime.Java.Types (JavaManagedRuntime(..))
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , removeDirectoryRecursive
  )
import System.Exit (ExitCode(..))
import System.FilePath
  ( (</>)
  , takeDirectory
  )
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )
import TestFixtures (testLockfileSolveRequest)
import TestSupport (assertEqual)

type LockfileSolve = LockfileSolveRequest -> IO SolverResult

assertLockfileJavaPolicySolves :: LockfileSolve -> FilePath -> IO ()
assertLockfileJavaPolicySolves solveLockfile tempDir = do
  let managedJavaRequest =
        (testLockfileSolveRequest (tempDir </> "panino-lockfile-managed-java" </> "game") [] Nothing)
          { solveRequestMinecraftVersion = Just "26.1.2"
          , solveRequestLoader = Nothing
          , solveRequestShaderLoader = Nothing
          , solveRequestJavaPolicy = Just (object ["policy" .= ("managed" :: Text)])
          }
      managedJavaTargetGameDir = solveRequestTargetGameDirPath managedJavaRequest
  managedJavaTargetExistsBefore <- doesDirectoryExist managedJavaTargetGameDir
  whenDirectoryExists managedJavaTargetExistsBefore managedJavaTargetGameDir
  managedJavaResult <- solveLockfile managedJavaRequest
  managedJavaTargetExists <- doesDirectoryExist managedJavaTargetGameDir
  assertEqual "lockfile solver blocks unavailable managed Java" "blocked" (solverResultStatus managedJavaResult)
  assertEqual "lockfile solver still locks required Java package when managed runtime is unavailable" True (maybe False (("java:21" `elem`) . map resolvedPackageId . lockfilePackages) (solverResultLockfile managedJavaResult))
  assertEqual "blocked Java runtime plan is not executable" "blocked" (typedPlanStatus (solverResultTypedPlan managedJavaResult))
  assertEqual "lockfile service solve does not create target game directory" False managedJavaTargetExists
  assertManagedJavaRuntimeSolve solveLockfile tempDir
  assertCustomJavaRuntimeSolve solveLockfile tempDir

assertManagedJavaRuntimeSolve :: LockfileSolve -> FilePath -> IO ()
assertManagedJavaRuntimeSolve solveLockfile tempDir = do
  now <- getCurrentTime
  let managedAppRoot = tempDir </> "panino-lockfile-managed-java-ready"
      managedJavaExecutable = managedAppRoot </> "runtimes" </> "java" </> "managed" </> "temurin-21-test" </> "Contents" </> "Home" </> "bin" </> "java"
      managedRuntime =
        JavaManagedRuntime
          { managedRuntimeId = "temurin-21-test"
          , managedRuntimeVendor = "temurin"
          , managedRuntimeProvider = "adoptium"
          , managedRuntimeFeatureVersion = 21
          , managedRuntimeVersion = "21.0.0"
          , managedRuntimeOs = "mac"
          , managedRuntimeArch = "aarch64"
          , managedRuntimeImageType = "jre"
          , managedRuntimeJavaHome = takeDirectory (takeDirectory managedJavaExecutable)
          , managedRuntimeJavaExecutable = managedJavaExecutable
          , managedRuntimeSourceUrl = "https://example.invalid/java-21.tar.gz"
          , managedRuntimeSha256 = Just "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
          , managedRuntimeInstalledAt = now
          , managedRuntimeLastVerifiedAt = Just now
          , managedRuntimeDiskUsageBytes = Just 0
          , managedRuntimeUsedByInstanceCount = 0
          }
  createDirectoryIfMissing True (takeDirectory managedJavaExecutable)
  _ <- upsertManagedRuntime managedAppRoot managedRuntime
  let managedX64JavaExecutable = managedAppRoot </> "runtimes" </> "java" </> "managed" </> "temurin-21-x64-test" </> "Contents" </> "Home" </> "bin" </> "java"
      managedX64Runtime =
        managedRuntime
          { managedRuntimeId = "temurin-21-x64-test"
          , managedRuntimeArch = "x64"
          , managedRuntimeJavaHome = takeDirectory (takeDirectory managedX64JavaExecutable)
          , managedRuntimeJavaExecutable = managedX64JavaExecutable
          }
  createDirectoryIfMissing True (takeDirectory managedX64JavaExecutable)
  _ <- upsertManagedRuntime managedAppRoot managedX64Runtime
  let managedReadyRequest =
        (testLockfileSolveRequest (managedAppRoot </> "game") [] Nothing)
          { solveRequestMinecraftVersion = Just "26.1.2"
          , solveRequestLoader = Nothing
          , solveRequestShaderLoader = Nothing
          , solveRequestJavaPolicy =
              Just
                ( object
                    [ "policy" .= ("managed" :: Text)
                    , "preferredRuntimeId" .= ("temurin-21-test" :: Text)
                    ]
                )
          }
  managedReadyResult <- solveLockfile managedReadyRequest
  assertEqual "lockfile solver accepts matching managed Java" "ready" (solverResultStatus managedReadyResult)
  assertEqual
    "managed Java runtime is written into lockfile and matches host architecture"
    [Just (if defaultRuntimeArch == "x64" then "temurin-21-x64-test" else "temurin-21-test")]
    [ coordinateVersionId (resolvedPackageCoordinate package)
    | package <- maybe [] lockfilePackages (solverResultLockfile managedReadyResult)
    , resolvedPackageId package == "java:21"
    ]

assertCustomJavaRuntimeSolve :: LockfileSolve -> FilePath -> IO ()
assertCustomJavaRuntimeSolve solveLockfile tempDir = do
  let customAppRoot = tempDir </> "panino-lockfile-custom-java"
      customJavaExecutable = customAppRoot </> "fake-java"
  customAppRootExists <- doesDirectoryExist customAppRoot
  whenDirectoryExists customAppRootExists customAppRoot
  createDirectoryIfMissing True (takeDirectory customJavaExecutable)
  writeFile customJavaExecutable $
    "#!/bin/sh\n"
      <> "echo 'openjdk version \"21.0.1\" 2026-01-01' >&2\n"
      <> "echo 'OpenJDK Runtime Environment Panino Test' >&2\n"
      <> "echo 'OpenJDK 64-Bit Server VM Panino Test' >&2\n"
      <> "echo 'java.version = 21.0.1' >&2\n"
      <> "echo 'java.vendor = Panino Test' >&2\n"
      <> "echo 'os.arch = "
      <> Text.unpack defaultRuntimeArch
      <> "' >&2\n"
      <> "exit 0\n"
  (chmodExit, _, chmodErr) <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", customJavaExecutable]) ""
  assertEqual "custom Java chmod succeeds" ExitSuccess chmodExit
  assertEqual "custom Java chmod stderr" "" chmodErr
  let customJavaRequest =
        (testLockfileSolveRequest (customAppRoot </> "game") [] Nothing)
          { solveRequestMinecraftVersion = Just "26.1.2"
          , solveRequestLoader = Nothing
          , solveRequestShaderLoader = Nothing
          , solveRequestJavaPolicy =
              Just
                ( object
                    [ "policy" .= ("custom" :: Text)
                    , "customPath" .= customJavaExecutable
                    ]
                )
          }
  customJavaResult <- solveLockfile customJavaRequest
  let customJavaLockJson =
        maybe
          ""
          (maybe "" (BL8.unpack . encode) . lockfileJava)
          (solverResultLockfile customJavaResult)
  assertEqual ("lockfile solver accepts custom Java: " <> show (solverResultBlockedReasons customJavaResult)) "ready" (solverResultStatus customJavaResult)
  assertEqual "custom Java lockfile records executable checksum" True ("executableSha1" `isInfixOf` customJavaLockJson)
  assertEqual
    "custom Java runtime does not force a download URL"
    [[]]
    [ resolvedPackageDownloadUrls package
    | package <- maybe [] lockfilePackages (solverResultLockfile customJavaResult)
    , resolvedPackageId package == "java:21"
    ]

whenDirectoryExists :: Bool -> FilePath -> IO ()
whenDirectoryExists exists path =
  if exists then removeDirectoryRecursive path else pure ()
