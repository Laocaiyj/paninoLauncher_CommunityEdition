{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Changeset
  ( buildChangeset
  , diffLockfiles
  , packageChange
  , sortChangeset
  ) where

import Data.List (foldl')
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.CoreLogic.Determinism
  ( stableFingerprint
  , stableSortPackages
  , stableTextSet
  )
import Panino.Lockfile.Types
  ( LockfileChange(..)
  , LockfileChangeAction(..)
  , LockfileChangeset(..)
  , LockfileSolveRequest(..)
  , LockfileUpdatePolicy(..)
  , PackageCoordinate(..)
  , PackageSource
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , coordinateVersionIdText
  , lockfileChangeActionText
  , packageSourceIsManualLike
  , emptyChangeset
  , resolvedPackageKey
  , resolvedPackageTargetPathFilePath
  )

diffLockfiles :: PaninoLockfile -> PaninoLockfile -> LockfileChangeset
diffLockfiles base target =
  changesetForPackages
    (Map.fromList [(resolvedPackageId package, package) | package <- basePackages])
    (stableSortPackages resolvedPackageKey (lockfilePackages target))
    []
    removeChanges
  where
    basePackages = stableSortPackages resolvedPackageKey (lockfilePackages base)
    targetIds = stableTextSet (map resolvedPackageId (lockfilePackages target))
    removeChanges =
      [ packageChange LockfileActionRemove package Nothing "Package is not present in the target lockfile."
      | package <- basePackages
      , resolvedPackageId package `notElem` targetIds
      ]

buildChangeset :: LockfileSolveRequest -> [ResolvedPackage] -> [Text] -> LockfileChangeset
buildChangeset request packages blockedReasons =
  changesetForPackages existingMap packages blockedReasons removeChanges
  where
    existingPackages = maybe [] lockfilePackages (solveRequestExistingLockfile request)
    existingMap = Map.fromList [(resolvedPackageId package, package) | package <- existingPackages]
    selectedIds = map resolvedPackageId packages
    removeChanges =
      [ packageChange LockfileActionRemove package Nothing "Package is no longer selected by relock."
      | solveRequestUpdatePolicy request == LockfileRelock
      , package <- existingPackages
      , resolvedPackageId package `notElem` selectedIds
      ]

changesetForPackages :: Map Text ResolvedPackage -> [ResolvedPackage] -> [Text] -> [LockfileChange] -> LockfileChangeset
changesetForPackages existingMap packages blockedReasons removeChanges =
  sortChangeset $
    foldl'
      insertChange
      emptyChangeset { changesetRemove = stableSortPackages lockfileChangeKey removeChanges }
      (stableSortPackages resolvedPackageKey packages)
  where
    insertChange changeset package
      | any (Text.isSuffixOf (resolvedPackageId package)) blockedReasons =
          changeset { changesetBlocked = packageChange LockfileActionBlocked package Nothing "Solver blocked this package." : changesetBlocked changeset }
      | packageSourceIsManualLike (packageSource package) =
          changeset { changesetManual = packageChange LockfileActionManual package Nothing "Manual or local file is tracked without automatic download." : changesetManual changeset }
      | otherwise =
          case Map.lookup (resolvedPackageId package) existingMap of
            Nothing ->
              changeset { changesetAdd = packageChange LockfileActionAdd package Nothing "Package is newly selected." : changesetAdd changeset }
            Just existing
              | packageChangesetFingerprint existing == packageChangesetFingerprint package ->
                  changeset { changesetKeep = packageChange LockfileActionKeep package (Just existing) "Existing lockfile package is kept." : changesetKeep changeset }
              | otherwise ->
                  changeset { changesetReplace = packageChange LockfileActionReplace package (Just existing) "Selected package differs from existing lockfile." : changesetReplace changeset }

packageChangesetFingerprint :: ResolvedPackage -> Text
packageChangesetFingerprint package =
  stableFingerprint
    package
      { resolvedPackageSelectedBecause = []
      , resolvedPackageLocked = False
      , resolvedPackagePinReason = Nothing
      }

packageChange :: LockfileChangeAction -> ResolvedPackage -> Maybe ResolvedPackage -> Text -> LockfileChange
packageChange action package existing reason =
  LockfileChange
    { lockfileChangeAction = action
    , lockfileChangePackageId = resolvedPackageId package
    , lockfileChangeDisplayName = resolvedPackageDisplayName package
    , lockfileChangeFromVersionId = existing >>= coordinateVersionIdText . resolvedPackageCoordinate
    , lockfileChangeToVersionId = coordinateVersionIdText (resolvedPackageCoordinate package)
    , lockfileChangeTargetPath = resolvedPackageTargetPathFilePath package
    , lockfileChangeReason = reason
    }

sortChangeset :: LockfileChangeset -> LockfileChangeset
sortChangeset changeset =
  changeset
    { changesetKeep = sortChanges (changesetKeep changeset)
    , changesetAdd = sortChanges (changesetAdd changeset)
    , changesetReplace = sortChanges (changesetReplace changeset)
    , changesetRemove = sortChanges (changesetRemove changeset)
    , changesetRepair = sortChanges (changesetRepair changeset)
    , changesetManual = sortChanges (changesetManual changeset)
    , changesetBlocked = sortChanges (changesetBlocked changeset)
    }
  where
    sortChanges = stableSortPackages lockfileChangeKey

lockfileChangeKey :: LockfileChange -> Text
lockfileChangeKey change =
  Text.intercalate
    "|"
    [ lockfileChangeActionText (lockfileChangeAction change)
    , lockfileChangePackageId change
    , lockfileChangeDisplayName change
    , fromMaybe "" (lockfileChangeFromVersionId change)
    , fromMaybe "" (lockfileChangeToVersionId change)
    , Text.pack (fromMaybe "" (lockfileChangeTargetPath change))
    ]

packageSource :: ResolvedPackage -> PackageSource
packageSource =
  coordinateSource . resolvedPackageCoordinate
