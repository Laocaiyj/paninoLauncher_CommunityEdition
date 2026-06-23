module Panino.Lockfile.Solver.Room
  ( roomLockRepairPlan
  , roomRequiredLockSubset
  ) where

import qualified Data.Map.Strict as Map
import Data.Maybe (mapMaybe)
import qualified Panino.Install.Plan.Types as Plan
import Panino.CoreLogic.Determinism
  ( stableSortPackages
  , stableTextSet
  )
import Panino.Lockfile.Changeset (diffLockfiles)
import Panino.Lockfile.Normalize (constraintKey)
import Panino.Lockfile.Plan (buildLockfileTypedPlan)
import Panino.Lockfile.Solver.Build
  ( constraintRequiredForRoom
  , packageRequiredForRoom
  , updateLockfileFingerprint
  )
import Panino.Lockfile.Types
  ( LockfileChange(..)
  , LockfileChangeset(..)
  , LockfileFile(..)
  , PackageConstraint(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , lockfileFileKey
  , resolvedPackageKey
  )

roomRequiredLockSubset :: PaninoLockfile -> PaninoLockfile
roomRequiredLockSubset lockfile =
  updateLockfileFingerprint
    lockfile
      { lockfilePackages = roomPackages
      , lockfileFiles =
          stableSortPackages
            lockfileFileKey
            [ file
            | file <- lockfileFiles lockfile
            , lockfileFilePackageId file `elem` roomPackageIds
            ]
      , lockfileConstraints =
          stableSortPackages
            constraintKey
            [ constraint
            | constraint <- lockfileConstraints lockfile
            , constraintRequiredForRoom constraint
            , maybe True (`elem` roomPackageIds) (constraintSourcePackage constraint)
            , maybe True (`elem` roomPackageIds) (constraintTargetPackageId constraint)
            ]
      , lockfileRoots = stableTextSet [root | root <- lockfileRoots lockfile, root `elem` roomPackageIds]
      , lockfileManualEntries = []
      , lockfileSourceSnapshots = []
      }
  where
    roomPackages =
      stableSortPackages resolvedPackageKey $
        filter packageRequiredForRoom (lockfilePackages lockfile)
    roomPackageIds = map resolvedPackageId roomPackages

roomLockRepairPlan :: FilePath -> PaninoLockfile -> PaninoLockfile -> Plan.TypedInstallPlan
roomLockRepairPlan gameDir localLockfile roomLockfile =
  buildLockfileTypedPlan
    gameDir
    planPackages
    (lockfileConstraints roomSubset)
    changeset
    (lockfileWarnings roomSubset)
    []
    []
  where
    roomSubset = roomRequiredLockSubset roomLockfile
    changeset = diffLockfiles localLockfile roomSubset
    targetMap = Map.fromList [(resolvedPackageId package, package) | package <- lockfilePackages roomSubset]
    localMap = Map.fromList [(resolvedPackageId package, package) | package <- lockfilePackages localLockfile]
    targetChangeIds =
      map lockfileChangePackageId (changesetAdd changeset <> changesetReplace changeset <> changesetRepair changeset)
    removeChangeIds =
      map lockfileChangePackageId (changesetRemove changeset)
    planPackages =
      stableSortPackages resolvedPackageKey $
        mapMaybe (`Map.lookup` targetMap) targetChangeIds
          <> mapMaybe (`Map.lookup` localMap) removeChangeIds
