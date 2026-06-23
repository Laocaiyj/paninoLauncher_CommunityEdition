{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Solver.Build
  ( buildLockfile
  , constraintRequiredForRoom
  , explainEntryKey
  , optifineWarnings
  , packageRequiredForRoom
  , updateLockfileFingerprint
  ) where

import Data.Aeson
  ( Value(String)
  , object
  , (.=)
  )
import Data.Maybe
  ( fromMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.CoreLogic.Determinism
  ( stableFingerprint
  , stableSortOnText
  , stableSortPackages
  , stableTextSet
  )
import Panino.Lockfile.Normalize
  ( constraintKey
  , packageSource
  )
import Panino.Lockfile.Plan
  ( lockfileFingerprintFor
  , packageToLockfileFile
  )
import Panino.Lockfile.Types
  ( LockfileExplainEntry(..)
  , LockfileSolveRequest(..)
  , PackageConstraint(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , lockfileFileKey
  , resolvedPackageKey
  )

updateLockfileFingerprint :: PaninoLockfile -> PaninoLockfile
updateLockfileFingerprint lockfile =
  let staged = lockfile { lockfileFingerprint = "" }
   in staged { lockfileFingerprint = lockfileFingerprintFor staged }

buildLockfile :: LockfileSolveRequest -> [ResolvedPackage] -> [PackageConstraint] -> [Text] -> PaninoLockfile
buildLockfile request packages constraints warnings =
  PaninoLockfile
    { lockfileVersion = 1
    , lockfileSolverVersion = "lockfile-solver-v1"
    , lockfileFingerprint = ""
    , lockfileCreatedAt = Nothing
    , lockfileUpdatedAt = Nothing
    , lockfileTargetGameDir = Just (solveRequestTargetGameDir request)
    , lockfileMinecraft = solveRequestMinecraftVersion request
    , lockfileJava = solveRequestJavaPolicy request
    , lockfileLoader = loaderValue
    , lockfileShaderLoader = shaderValue
    , lockfileRoots = stableTextSet (map resolvedPackageId (solveRequestRoots request))
    , lockfilePackages = sortedPackages
    , lockfileFiles = stableSortPackages lockfileFileKey (mapMaybe packageToLockfileFile sortedPackages)
    , lockfileConstraints = stableSortPackages constraintKey constraints
    , lockfileOverrides = []
    , lockfileSourceSnapshots = stableSortOnText jsonValueKey (mapMaybe packageSourceSnapshotValue sortedPackages)
    , lockfileManualEntries = stableSortPackages resolvedPackageKey (filter ((`elem` ["manual", "local"]) . packageSource) sortedPackages)
    , lockfileWarnings = warnings
    }
  where
    sortedPackages = stableSortPackages resolvedPackageKey packages
    loaderValue =
      Just $
        object
        [ "family" .= solveRequestLoader request
        , "version" .= solveRequestLoaderVersion request
        ]
    shaderValue =
      Just $
        object
        [ "family" .= solveRequestShaderLoader request
        ]

packageSourceSnapshotValue :: ResolvedPackage -> Maybe Value
packageSourceSnapshotValue package =
  String <$> resolvedPackageSourceSnapshot package

jsonValueKey :: Value -> Text
jsonValueKey =
  stableFingerprint

explainEntryKey :: LockfileExplainEntry -> Text
explainEntryKey entry =
  Text.intercalate
    "|"
    [ explainEntryKind entry
    , fromMaybe "" (explainEntryPackageId entry)
    , fromMaybe "" (explainEntryConstraintId entry)
    , if explainEntryRequired entry then "required" else "optional"
    , explainEntryReason entry
    ]

optifineWarnings :: LockfileSolveRequest -> [ResolvedPackage] -> [Text]
optifineWarnings request packages =
  [ "optifine_modern_loader_risk"
  | solveRequestShaderLoader request == Just "optifine"
      || any ((== "optifine") . Text.toLower . resolvedPackageDisplayName) packages
  ]

packageRequiredForRoom :: ResolvedPackage -> Bool
packageRequiredForRoom package =
  packageSource package `notElem` ["manual", "local"]
    && coordinateKind (resolvedPackageCoordinate package)
      `elem`
        [ "minecraft"
        , "javaRuntime"
        , "loader"
        , "loaderInstaller"
        , "mod"
        , "resourcePack"
        , "shaderPack"
        , "shaderLoader"
        , "performancePack"
        ]

constraintRequiredForRoom :: PackageConstraint -> Bool
constraintRequiredForRoom constraint =
  constraintRequired constraint
    || constraintRelation constraint `elem` ["requires", "pins", "incompatible", "conflicts"]
