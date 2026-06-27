{-# LANGUAGE OverloadedStrings #-}

module Integration.LockfileSolver.Update
  ( assertLockfileUpdatePolicies
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import Panino.Core.Types (versionIdFromText)
import Panino.Lockfile.Solver (solveLockfile)
import Panino.Lockfile.Types
  ( LockfileChangeset(..)
  , LockfileSolveRequest(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , SolverResult(..)
  , lockfileChangePackageId
  )
import TestFixtures
  ( testLockfilePackage
  , testLockfileSolveRequest
  , testPackageConstraint
  , testPaninoLockfile
  )
import TestSupport (assertEqual)

assertLockfileUpdatePolicies :: FilePath -> ResolvedPackage -> ResolvedPackage -> IO ()
assertLockfileUpdatePolicies gameDir fabricApi sodium = do
  let lithium =
        testLockfilePackage
          "lithium"
          "Lithium"
          "lithium-version"
          "lithium.jar"
          "mods/lithium.jar"
          "7777777777777777777777777777777777777777"
          []
      fabricApiNew =
        updatePackage fabricApi "fabric-api-new-version" "2222222222222222222222222222222222222222"
      sodiumNew =
        (updatePackage sodium "sodium-new-version" "3333333333333333333333333333333333333333")
          { resolvedPackageDependencies = [testPackageConstraint "sodium" "fabric-api" "requires" True]
          }
      selectedUpdateResult =
        solveLockfile
          ( (testLockfileSolveRequest gameDir [sodiumNew, fabricApiNew] (Just (testPaninoLockfile gameDir [fabricApi, sodium, lithium])))
              { solveRequestUpdatePolicy = "updateSelected"
              }
          )
      selectedUpdateVersions =
        [ (resolvedPackageId package, coordinateVersionId (resolvedPackageCoordinate package))
        | package <- maybe [] lockfilePackages (solverResultLockfile selectedUpdateResult)
        ]
  assertEqual
    "lockfile updateSelected updates selected package and required dependency only"
    [("fabric-api", Just "fabric-api-new-version"), ("lithium", Just "lithium-version"), ("sodium", Just "sodium-new-version")]
    selectedUpdateVersions
  assertEqual
    "lockfile updateSelected changeset replaces selected package and dependency"
    ["fabric-api", "sodium"]
    (map lockfileChangePackageId (changesetReplace (solverResultChangeset selectedUpdateResult)))
  assertEqual
    "lockfile updateSelected keeps unselected packages locked"
    ["lithium"]
    (map lockfileChangePackageId (changesetKeep (solverResultChangeset selectedUpdateResult)))
  assertUpdateAllSafe gameDir sodium
  assertLocalManualJar gameDir

assertUpdateAllSafe :: FilePath -> ResolvedPackage -> IO ()
assertUpdateAllSafe gameDir sodium = do
  let sodiumSafeNew =
        (updatePackage sodium "sodium-safe-new-version" "4444444444444444444444444444444444444444")
          { resolvedPackageDependencies = []
          }
      sodiumUnsafeNew =
        sodiumSafeNew
          { resolvedPackageCoordinate =
              (resolvedPackageCoordinate sodiumSafeNew)
                { coordinateVersionId = Just "sodium-unsafe-new-version"
                }
          , resolvedPackageVersionName = Just "sodium-unsafe-new-version"
          , resolvedPackageGameVersions = ["1.20.1"]
          }
      updateAllSafeResult =
        solveLockfile
          ( (testLockfileSolveRequest gameDir [sodiumSafeNew] (Just (testPaninoLockfile gameDir [sodium])))
              { solveRequestUpdatePolicy = "updateAllSafe"
              }
          )
      unsafeUpdateAllSafeResult =
        solveLockfile
          ( (testLockfileSolveRequest gameDir [sodiumUnsafeNew] (Just (testPaninoLockfile gameDir [sodium])))
              { solveRequestUpdatePolicy = "updateAllSafe"
              }
          )
  assertEqual
    "lockfile updateAllSafe updates compatible candidates"
    [("sodium", Just "sodium-safe-new-version")]
    [ (resolvedPackageId package, coordinateVersionId (resolvedPackageCoordinate package))
    | package <- maybe [] lockfilePackages (solverResultLockfile updateAllSafeResult)
    ]
  assertEqual
    "lockfile updateAllSafe keeps existing package when update breaks Minecraft compatibility"
    [("sodium", Just "sodium-version")]
    [ (resolvedPackageId package, coordinateVersionId (resolvedPackageCoordinate package))
    | package <- maybe [] lockfilePackages (solverResultLockfile unsafeUpdateAllSafeResult)
    ]

assertLocalManualJar :: FilePath -> IO ()
assertLocalManualJar gameDir = do
  let baseManualJar =
        testLockfilePackage "local-manual" "Local Manual" "manual-version" "local-manual.jar" "mods/local-manual.jar" "7777777777777777777777777777777777777777" []
      localManualJar =
        baseManualJar
          { resolvedPackageCoordinate =
              (resolvedPackageCoordinate baseManualJar)
                { coordinateSource = "local"
                }
          , resolvedPackageDownloadUrls = []
          }
      localManualResult =
        solveLockfile
          ( (testLockfileSolveRequest gameDir [] Nothing)
              { solveRequestManualPackages = [localManualJar]
              }
          )
  assertEqual
    "lockfile local manual jar enters manual entries"
    ["local-manual"]
    (maybe [] (map resolvedPackageId . lockfileManualEntries) (solverResultLockfile localManualResult))
  assertEqual
    "lockfile local manual jar uses manual changeset"
    ["local-manual"]
    (map lockfileChangePackageId (changesetManual (solverResultChangeset localManualResult)))

updatePackage :: ResolvedPackage -> Text.Text -> Text.Text -> ResolvedPackage
updatePackage package version sha1 =
  package
    { resolvedPackageCoordinate =
        (resolvedPackageCoordinate package)
          { coordinateVersionId = versionIdFromText version
          }
    , resolvedPackageVersionName = Just version
    , resolvedPackageHashes = Map.fromList [("sha1", sha1)]
    }
