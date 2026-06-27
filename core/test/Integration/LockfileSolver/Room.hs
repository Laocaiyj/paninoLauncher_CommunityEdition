{-# LANGUAGE OverloadedStrings #-}

module Integration.LockfileSolver.Room
  ( assertRoomLockRepair
  ) where

import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import Panino.Core.Types (versionIdFromText)
import Panino.Install.Plan.Types
  ( InstallPlanNode(..)
  , TypedInstallPlan(..)
  )
import Panino.Lockfile.Solver
  ( diffLockfiles
  , roomLockRepairPlan
  , roomRequiredLockSubset
  )
import Panino.Lockfile.Types
  ( LockfileChangeset(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , lockfileChangePackageId
  )
import TestFixtures
  ( testLockfilePackage
  , testPaninoLockfile
  )
import TestSupport (assertEqual)

assertRoomLockRepair :: FilePath -> ResolvedPackage -> ResolvedPackage -> IO ()
assertRoomLockRepair gameDir fabricApi sodium = do
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
      baseManualJar =
        testLockfilePackage "local-manual" "Local Manual" "manual-version" "local-manual.jar" "mods/local-manual.jar" "7777777777777777777777777777777777777777" []
      localManualJar =
        baseManualJar
          { resolvedPackageCoordinate =
              (resolvedPackageCoordinate baseManualJar)
                { coordinateSource = "local"
                }
          , resolvedPackageDownloadUrls = []
          }
      roomSubset =
        roomRequiredLockSubset (testPaninoLockfile gameDir [fabricApi, sodium, localManualJar])
      roomLocalLockfile =
        testPaninoLockfile gameDir [fabricApi, lithium]
      roomTargetLockfile =
        testPaninoLockfile gameDir [fabricApiNew, sodium]
      roomDiff =
        diffLockfiles roomLocalLockfile (roomRequiredLockSubset roomTargetLockfile)
      roomRepairPlan =
        roomLockRepairPlan gameDir roomLocalLockfile roomTargetLockfile
      roomRepairActions =
        [ (installNodeLabel node, installNodeAction node)
        | node <- typedPlanNodes roomRepairPlan
        ]
  assertEqual
    "room required lock subset excludes local manual files"
    ["fabric-api", "sodium"]
    (map resolvedPackageId (lockfilePackages roomSubset))
  assertEqual "room lock diff reports missing room package" ["sodium"] (map lockfileChangePackageId (changesetAdd roomDiff))
  assertEqual "room lock diff reports version difference" ["fabric-api"] (map lockfileChangePackageId (changesetReplace roomDiff))
  assertEqual "room lock diff reports local extra package" ["lithium"] (map lockfileChangePackageId (changesetRemove roomDiff))
  assertEqual "room lock repair plan is executable" "ready" (typedPlanStatus roomRepairPlan)
  assertEqual
    "room lock repair plan downloads, replaces and deletes"
    True
    (("Sodium", "download") `elem` roomRepairActions && ("Fabric API", "replace") `elem` roomRepairActions && ("Lithium", "delete") `elem` roomRepairActions)

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
