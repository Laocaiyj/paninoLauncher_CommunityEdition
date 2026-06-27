{-# LANGUAGE OverloadedStrings #-}

module Integration.Modpack
  ( assertModpackImportStaging
  , assertModpackTypedPlan
  ) where

import Control.Monad (when)
import Data.Aeson (toJSON)
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List (isInfixOf)
import qualified Data.Text as Text
import Panino.Content.Configuration.Preflight
  ( modpackImport
  , modpackPreflight
  )
import Panino.Content.Configuration.Types
  ( ModpackImportRequest(..)
  , ModpackImportResponse(..)
  , ModpackPreflightRequest(..)
  , ModpackPreflightResponse(..)
  )
import Panino.CoreLogic.Determinism (canonicalJson)
import Panino.Install.Plan.Types
  ( InstallPlanNode(..)
  , InstallPlanRollbackAction(..)
  , TypedInstallPlan(..)
  , installNodeActionText
  )
import Panino.Lockfile.Solver
  ( solveLockfileWithServices
  )
import Panino.Lockfile.Types
  ( LockfileSolveRequest(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , SolverResult(..)
  )
import Panino.Net.Http (makeHttpManager)
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getTemporaryDirectory
  , removeDirectoryRecursive
  )
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
import System.Process
  ( CreateProcess(..)
  , proc
  , readCreateProcessWithExitCode
  )
import TestFixtures (testLockfileSolveRequest)
import TestSupport (assertEqual)

assertModpackTypedPlan :: IO ()
assertModpackTypedPlan = do
  manager <- makeHttpManager
  tempDir <- getTemporaryDirectory
  let sourceRoot = tempDir </> "panino-modpack-plan-test"
      mrpackPath = sourceRoot </> "pack.mrpack"
      mrpackShuffledPath = sourceRoot </> "pack-shuffled.mrpack"
      serverPackPath = sourceRoot </> "server-pack.mrpack"
      cursePath = sourceRoot </> "curse.zip"
      targetPackDir = sourceRoot </> "target-pack"
  exists <- doesDirectoryExist sourceRoot
  when exists (removeDirectoryRecursive sourceRoot)
  createDirectoryIfMissing True (sourceRoot </> "overrides")
  createDirectoryIfMissing True targetPackDir
  BL8.writeFile
    (sourceRoot </> "modrinth.index.json")
    "{\"name\":\"Typed Pack\",\"dependencies\":{\"minecraft\":\"1.20.1\",\"fabric-loader\":\"0.15.0\"},\"files\":[{\"path\":\"mods/sodium.jar\",\"downloads\":[\"https://example.com/sodium.jar\"],\"hashes\":{\"sha1\":\"abc\"},\"fileSize\":123}]}"
  BL8.writeFile (sourceRoot </> "overrides" </> "options.txt") "renderDistance:12\n"
  BL8.writeFile (targetPackDir </> "options.txt") "renderDistance:8\n"
  (zipExit, _, zipErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", mrpackPath, "modrinth.index.json", "overrides/options.txt"]) { cwd = Just sourceRoot }
      ""
  assertEqual "mrpack test zip succeeds" ExitSuccess zipExit
  assertEqual "mrpack test zip stderr" "" zipErr
  (zipShuffledExit, _, zipShuffledErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", mrpackShuffledPath, "overrides/options.txt", "modrinth.index.json"]) { cwd = Just sourceRoot }
      ""
  assertEqual "mrpack shuffled test zip succeeds" ExitSuccess zipShuffledExit
  assertEqual "mrpack shuffled test zip stderr" "" zipShuffledErr

  mrpackResponse <-
    modpackPreflight
      ModpackPreflightRequest
        { modpackPreflightSourceType = "local"
        , modpackPreflightSourcePath = Just mrpackPath
        , modpackPreflightTargetGameDir = Just targetPackDir
        }
  mrpackShuffledResponse <-
    modpackPreflight
      ModpackPreflightRequest
        { modpackPreflightSourceType = "local"
        , modpackPreflightSourcePath = Just mrpackShuffledPath
        , modpackPreflightTargetGameDir = Just targetPackDir
        }
  let mrpackPlan = modpackPreflightTypedPlan mrpackResponse
      mrpackShuffledPlan = modpackPreflightTypedPlan mrpackShuffledResponse
      mrpackKinds = map installNodeKind (typedPlanNodes mrpackPlan)
      mrpackOverrideActions =
        [ (installNodeLabel node, installNodeActionText (installNodeAction node), installRollbackAction (installNodeRollback node))
        | node <- typedPlanNodes mrpackPlan
        , installNodeKind node == "overrideFile"
        ]
  assertEqual "mrpack preflight stays valid" True (modpackPreflightValid mrpackResponse)
  assertEqual "mrpack typed plan ready" "ready" (typedPlanStatus mrpackPlan)
  assertEqual "mrpack typed plan includes minecraft dependency" True ("minecraftVersion" `elem` mrpackKinds)
  assertEqual "mrpack typed plan includes loader dependency" True ("loaderProfile" `elem` mrpackKinds)
  assertEqual "mrpack typed plan includes mod node" True ("mod" `elem` mrpackKinds)
  assertEqual "mrpack typed plan includes override node" True ("overrideFile" `elem` mrpackKinds)
  assertEqual "mrpack override conflict uses replace plan" True (("overrides/options.txt", "replace", "restoreBackup") `elem` mrpackOverrideActions)
  assertEqual "mrpack typed plan includes lockfile node" True ("rollbackMarker" `elem` mrpackKinds)
  assertEqual "mrpack entry order does not change typed plan fingerprint" (typedPlanFingerprint mrpackPlan) (typedPlanFingerprint mrpackShuffledPlan)
  assertEqual "mrpack entry order does not change canonical typed plan" (canonicalJson (toJSON mrpackPlan)) (canonicalJson (toJSON mrpackShuffledPlan))
  mrpackLockResult <-
    solveLockfileWithServices
      manager
      ( (testLockfileSolveRequest targetPackDir [] Nothing)
          { solveRequestMinecraftVersion = Nothing
          , solveRequestLoader = Nothing
          , solveRequestShaderLoader = Nothing
          , solveRequestSourceType = Just "modrinth"
          , solveRequestSourcePath = Just mrpackPath
          }
      )
  assertEqual "mrpack import maps to lockfile root packages" "ready" (solverResultStatus mrpackLockResult)
  assertEqual
    "mrpack lockfile includes mod and override packages"
    True
    ( maybe
        False
        (\lockfile -> "mod" `elem` map (coordinateKind . resolvedPackageCoordinate) (lockfilePackages lockfile) && "overrideFile" `elem` map (coordinateKind . resolvedPackageCoordinate) (lockfilePackages lockfile))
        (solverResultLockfile mrpackLockResult)
    )

  BL8.writeFile (sourceRoot </> "overrides" </> "server.properties") "motd=server-only\n"
  (serverZipExit, _, serverZipErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", serverPackPath, "modrinth.index.json", "overrides/server.properties"]) { cwd = Just sourceRoot }
      ""
  assertEqual "server mrpack test zip succeeds" ExitSuccess serverZipExit
  assertEqual "server mrpack test zip stderr" "" serverZipErr
  serverResponse <-
    modpackPreflight
      ModpackPreflightRequest
        { modpackPreflightSourceType = "local"
        , modpackPreflightSourcePath = Just serverPackPath
        , modpackPreflightTargetGameDir = Just targetPackDir
        }
  assertEqual "server pack preflight blocks client import" True ("server_pack_not_supported" `elem` modpackPreflightBlockingReasons serverResponse)

  BL8.writeFile
    (sourceRoot </> "manifest.json")
    "{\"name\":\"Curse Pack\",\"minecraft\":{\"version\":\"1.20.1\",\"modLoaders\":[{\"id\":\"fabric-0.15.0\",\"primary\":true}]},\"files\":[{\"projectID\":1,\"fileID\":2}],\"overrides\":\"overrides\"}"
  (curseZipExit, _, curseZipErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", cursePath, "manifest.json", "overrides/options.txt"]) { cwd = Just sourceRoot }
      ""
  assertEqual "curse modpack test zip succeeds" ExitSuccess curseZipExit
  assertEqual "curse modpack test zip stderr" "" curseZipErr
  curseResponse <-
    modpackPreflight
      ModpackPreflightRequest
        { modpackPreflightSourceType = "local"
        , modpackPreflightSourcePath = Just cursePath
        , modpackPreflightTargetGameDir = Just "/tmp/mc-pack"
        }
  assertEqual "curse modpack requires api key" True (modpackPreflightRequiresApiKey curseResponse)
  assertEqual "curse modpack blocks without api key" True ("curseforge_api_key_required" `elem` modpackPreflightBlockingReasons curseResponse)
  assertEqual "curse typed plan blocked" "blocked" (typedPlanStatus (modpackPreflightTypedPlan curseResponse))
  curseLockResult <-
    solveLockfileWithServices
      manager
      ( (testLockfileSolveRequest "/tmp/mc-pack" [] Nothing)
          { solveRequestMinecraftVersion = Nothing
          , solveRequestLoader = Nothing
          , solveRequestShaderLoader = Nothing
          , solveRequestSourceType = Just "local"
          , solveRequestSourcePath = Just cursePath
          }
      )
  assertEqual "curse zip import maps to blocked lockfile solve" "blocked" (solverResultStatus curseLockResult)
  assertEqual
    "curse zip lockfile keeps manifest file package"
    True
    ( maybe
        False
        (any (("curseforge-1-2.jar" `Text.isInfixOf`) . resolvedPackageDisplayName) . lockfilePackages)
        (solverResultLockfile curseLockResult)
    )

assertModpackImportStaging :: IO ()
assertModpackImportStaging = do
  tempDir <- getTemporaryDirectory
  let sourceRoot = tempDir </> "panino-modpack-import-test"
      sourcePack = sourceRoot </> "pack.mrpack"
      badPack = sourceRoot </> "bad-pack.mrpack"
      targetDir = sourceRoot </> "instances" </> "typed-pack"
      badTargetDir = sourceRoot </> "instances" </> "bad-pack"
      stagingDir = targetDir <> ".panino-modpack-staging"
      badStagingDir = badTargetDir <> ".panino-modpack-staging"
  exists <- doesDirectoryExist sourceRoot
  when exists (removeDirectoryRecursive sourceRoot)
  createDirectoryIfMissing True (sourceRoot </> "success" </> "overrides")
  BL8.writeFile
    (sourceRoot </> "success" </> "modrinth.index.json")
    "{\"name\":\"Import Pack\",\"dependencies\":{\"minecraft\":\"1.20.1\",\"fabric-loader\":\"0.15.0\"},\"files\":[]}"
  BL8.writeFile (sourceRoot </> "success" </> "overrides" </> "options.txt") "renderDistance:12\n"
  (zipExit, _, zipErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", sourcePack, "modrinth.index.json", "overrides/options.txt"]) { cwd = Just (sourceRoot </> "success") }
      ""
  assertEqual "modpack import test zip succeeds" ExitSuccess zipExit
  assertEqual "modpack import test zip stderr" "" zipErr

  manager <- makeHttpManager
  importResponse <-
    modpackImport
      manager
      ModpackImportRequest
        { modpackImportSourceType = "local"
        , modpackImportSourcePath = sourcePack
        , modpackImportTargetGameDir = targetDir
        }
  targetExists <- doesDirectoryExist targetDir
  stagingExists <- doesDirectoryExist stagingDir
  optionsExists <- doesFileExist (targetDir </> "options.txt")
  lockExists <- doesFileExist (targetDir </> "modpack-install-lock.json")
  lockText <- if lockExists then BL8.readFile (targetDir </> "modpack-install-lock.json") else pure ""
  assertEqual "modpack import succeeds" True (modpackImportImported importResponse)
  assertEqual "modpack import atomically creates target" True targetExists
  assertEqual "modpack import removes staging" False stagingExists
  assertEqual "modpack import writes override" True optionsExists
  assertEqual "modpack import writes lockfile" True lockExists
  assertEqual "modpack lockfile records override" True ("options.txt" `isInfixOf` BL8.unpack lockText)

  createDirectoryIfMissing True (sourceRoot </> "failure")
  BL8.writeFile
    (sourceRoot </> "failure" </> "modrinth.index.json")
    "{\"name\":\"Bad Import Pack\",\"dependencies\":{\"minecraft\":\"1.20.1\",\"fabric-loader\":\"0.15.0\"},\"files\":[{\"path\":\"mods/missing.jar\",\"downloads\":[\"http://127.0.0.1:1/missing.jar\"],\"hashes\":{\"sha1\":\"0123456789012345678901234567890123456789\"},\"fileSize\":12}]}"
  (badZipExit, _, badZipErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", badPack, "modrinth.index.json"]) { cwd = Just (sourceRoot </> "failure") }
      ""
  assertEqual "bad modpack import test zip succeeds" ExitSuccess badZipExit
  assertEqual "bad modpack import test zip stderr" "" badZipErr

  failedResponse <-
    modpackImport
      manager
      ModpackImportRequest
        { modpackImportSourceType = "local"
        , modpackImportSourcePath = badPack
        , modpackImportTargetGameDir = badTargetDir
        }
  badTargetExists <- doesDirectoryExist badTargetDir
  badStagingExists <- doesDirectoryExist badStagingDir
  assertEqual "failed modpack import reports failure" False (modpackImportImported failedResponse)
  assertEqual "failed modpack import reports reason" True (any ("modpack_import_failed:" `Text.isPrefixOf`) (modpackImportBlockingReasons failedResponse))
  assertEqual "failed modpack import does not leave target" False badTargetExists
  assertEqual "failed modpack import removes staging" False badStagingExists
