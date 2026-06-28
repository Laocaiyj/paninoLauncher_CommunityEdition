{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Normalize
  ( applyExistingLockPolicy
  , applyPins
  , constraintKey
  , dedupePackages
  , javaMajorFromPolicy
  , normalizeConstraint
  , normalizeKind
  , normalizeLoader
  , normalizePackage
  , normalizeRelation
  , normalizeSource
  , normalizeTargetPath
  , packageAllConstraints
  , packageCompatibleWithRequest
  , packageResolutionScore
  , packageSource
  , selectedUpdatePackageIds
  , targetPathSafe
  ) where

import Control.Applicative ((<|>))
import Data.Aeson
  ( Result(..)
  , Value(Object, String)
  , fromJSON
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (foldl')
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  , isJust
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.CoreLogic.Determinism
  ( stableSortPackages
  , stableTextSet
  )
import Panino.Core.Types
  ( RelativePath
  , Url
  , relativePathFilePath
  , relativePathFromFilePath
  , urlFromText
  , urlText
  )
import Panino.Lockfile.Types
  ( LockfileSolveRequest(..)
  , LockfileUpdatePolicy(..)
  , PackageConstraint(..)
  , PackageCoordinate(..)
  , PackageSource
  , ResolvedPackage(..)
  , normalizePackageSource
  , packageSourceFromText
  , packageSourceText
  , resolvedPackageKey
  , resolvedPackageSha1
  , solveRequestMinecraftVersionText
  )
import System.FilePath
  ( isRelative
  , makeRelative
  , normalise
  , splitDirectories
  )
import Text.Read (readMaybe)

normalizePackage :: FilePath -> Text -> ResolvedPackage -> ResolvedPackage
normalizePackage gameDir reason package =
  package
    { resolvedPackageCoordinate =
        coordinate
          { coordinateSource = normalizePackageSource (coordinateSource coordinate)
          , coordinateKind = normalizeKind (coordinateKind coordinate)
          }
    , resolvedPackageTargetPath = normalizeTargetPath gameDir <$> resolvedPackageTargetPath package
    , resolvedPackageDownloadUrls = stableUrlSet (resolvedPackageDownloadUrls package)
    , resolvedPackageGameVersions = stableTextSet (resolvedPackageGameVersions package)
    , resolvedPackageLoaders = stableTextSet (map normalizeLoader (resolvedPackageLoaders package))
    , resolvedPackageSelectedBecause =
        stableTextSet (resolvedPackageSelectedBecause package <> [reason])
    , resolvedPackageDependencies = stableSortPackages constraintKey (map normalizeConstraint (resolvedPackageDependencies package))
    , resolvedPackageConflicts = stableSortPackages constraintKey (map normalizeConstraint (resolvedPackageConflicts package))
    }
  where
    coordinate = resolvedPackageCoordinate package

applyPins :: LockfileSolveRequest -> ResolvedPackage -> ResolvedPackage
applyPins request package
  | resolvedPackageId package `elem` solveRequestPinnedPackages request =
      package
        { resolvedPackageLocked = True
        , resolvedPackagePinReason = resolvedPackagePinReason package <|> Just "Pinned by solve request."
        }
  | otherwise = package

applyExistingLockPolicy :: LockfileSolveRequest -> [Text] -> ResolvedPackage -> ResolvedPackage
applyExistingLockPolicy request selectedUpdateIds package
  | shouldLockExisting request selectedUpdateIds package =
      package
        { resolvedPackageLocked = True
        , resolvedPackagePinReason = resolvedPackagePinReason package <|> Just "Kept from existing lockfile by update policy."
        }
  | otherwise = package

shouldLockExisting :: LockfileSolveRequest -> [Text] -> ResolvedPackage -> Bool
shouldLockExisting request selectedUpdateIds package =
  case solveRequestUpdatePolicy request of
    LockfileKeepLocked -> True
    LockfileRepair -> True
    LockfileLaunchVerify -> True
    LockfileSyncRoom -> True
    LockfileUpdateSelected -> resolvedPackageId package `notElem` selectedUpdateIds
    _ -> False

selectedUpdatePackageIds :: LockfileSolveRequest -> [ResolvedPackage] -> [Text]
selectedUpdatePackageIds request roots
  | solveRequestUpdatePolicy request == LockfileUpdateSelected =
      stableTextSet (map resolvedPackageId roots <> concatMap directRequiredTargets roots)
  | otherwise = []
  where
    directRequiredTargets package =
      [ targetId
      | constraint <- resolvedPackageDependencies package
      , constraintRelation constraint `elem` ["requires", "pins"]
      , Just targetId <- [constraintTargetPackageId constraint]
      ]

normalizeConstraint :: PackageConstraint -> PackageConstraint
normalizeConstraint constraint =
  constraint
    { constraintRelation = normalizeRelation (constraintRelation constraint)
    , constraintTargetKind = normalizeKind (constraintTargetKind constraint)
    , constraintLoaders = map normalizeLoader (constraintLoaders constraint)
    }

normalizeSource :: Text -> Text
normalizeSource =
  packageSourceText . packageSourceFromText

normalizeKind :: Text -> Text
normalizeKind kind =
  case Text.toLower kind of
    "resourcepack" -> "resourcePack"
    "resource-pack" -> "resourcePack"
    "shaderpack" -> "shaderPack"
    "shader-pack" -> "shaderPack"
    "shaderloader" -> "shaderLoader"
    "shader-loader" -> "shaderLoader"
    "performacepack" -> "performancePack"
    "performancepack" -> "performancePack"
    "performance-pack" -> "performancePack"
    "javaruntime" -> "javaRuntime"
    "java-runtime" -> "javaRuntime"
    "loaderinstaller" -> "loaderInstaller"
    "loader-installer" -> "loaderInstaller"
    "overridefile" -> "overrideFile"
    "override-file" -> "overrideFile"
    other -> other

normalizeLoader :: Text -> Text
normalizeLoader loader =
  case Text.toLower loader of
    "neo-forge" -> "neoforge"
    "neo_forge" -> "neoforge"
    "neoforge" -> "neoforge"
    other -> other

normalizeRelation :: Text -> Text
normalizeRelation relation =
  case Text.toLower relation of
    "required" -> "requires"
    "require" -> "requires"
    "incompatible" -> "incompatible"
    "conflict" -> "conflicts"
    "dependency" -> "requires"
    other -> other

normalizeTargetPath :: FilePath -> RelativePath -> RelativePath
normalizeTargetPath gameDir targetPath
  | isRelative normalized = fromMaybe targetPath (relativePathFromFilePath normalized)
  | otherwise = fromMaybe targetPath (relativePathFromFilePath (normalise (makeRelative gameDir normalized)))
  where
    normalized = normalise (relativePathFilePath targetPath)

packageAllConstraints :: ResolvedPackage -> [PackageConstraint]
packageAllConstraints package =
  stableSortPackages constraintKey (map withSource (resolvedPackageDependencies package <> resolvedPackageConflicts package))
  where
    withSource constraint =
      constraint
        { constraintSourcePackage = constraintSourcePackage constraint <|> Just (resolvedPackageId package)
        , constraintId =
            if Text.null (constraintId constraint)
              then resolvedPackageId package <> ":" <> fromMaybe "" (constraintTargetPackageId constraint) <> ":" <> constraintRelation constraint
              else constraintId constraint
        }

dedupePackages :: LockfileSolveRequest -> [ResolvedPackage] -> [ResolvedPackage]
dedupePackages request =
  Map.elems . foldl' insertPackage Map.empty . stableSortPackages resolvedPackageKey
  where
    insertPackage packages package =
      Map.insertWith keepPreferred (resolvedPackageId package) package packages
    keepPreferred new old
      | resolvedPackageLocked old = old
      | resolvedPackageLocked new = new
      | packageSelectionScore request new > packageSelectionScore request old = new
      | packageSelectionScore request old > packageSelectionScore request new = old
      | otherwise = old

packageSelectionScore :: LockfileSolveRequest -> ResolvedPackage -> Int
packageSelectionScore request package =
  packageResolutionScore package
    + rootRequestBonus package
    + safeUpdateBonus package
  where
    rootRequestBonus value =
      sum [ 8 | "root request" `elem` resolvedPackageSelectedBecause value ]
    safeUpdateBonus value =
      sum [ 100 | solveRequestUpdatePolicy request == LockfileUpdateAllSafe && packageCompatibleWithRequest request value ]

packageResolutionScore :: ResolvedPackage -> Int
packageResolutionScore package =
  sum
    [ 4 | isJust (coordinateVersionId (resolvedPackageCoordinate package)) ]
    + sum [ 4 | isJust (resolvedPackageTargetPath package) ]
    + sum [ 3 | isJust (resolvedPackageSha1 package) ]
    + sum [ 2 | not (null (resolvedPackageDownloadUrls package)) ]
    + sum [ 1 | isJust (resolvedPackageSourceSnapshot package) ]
    + length (resolvedPackageDependencies package)

packageCompatibleWithRequest :: LockfileSolveRequest -> ResolvedPackage -> Bool
packageCompatibleWithRequest request package =
  minecraftCompatible && loaderCompatible && javaCompatible
  where
    minecraftCompatible =
      maybe
        True
        (\minecraftVersion -> null (resolvedPackageGameVersions package) || minecraftVersion `elem` resolvedPackageGameVersions package)
        (solveRequestMinecraftVersionText request)
    loaderCompatible =
      maybe
        True
        (\loader -> null (resolvedPackageLoaders package) || normalizeLoader loader `elem` resolvedPackageLoaders package)
        (solveRequestLoader request)
    javaCompatible =
      case (javaMajorFromPolicy (solveRequestJavaPolicy request), resolvedPackageJavaMajor package) of
        (Just selectedMajor, Just requiredMajor) -> selectedMajor >= requiredMajor
        _ -> True

javaMajorFromPolicy :: Maybe Value -> Maybe Int
javaMajorFromPolicy (Just (Object obj)) =
  valueToInt
    =<< ( lookupPolicyValue "javaMajor" obj
            <|> lookupPolicyValue "major" obj
            <|> lookupPolicyValue "requiredMajorVersion" obj
        )
javaMajorFromPolicy _ =
  Nothing

lookupPolicyValue :: Text -> KeyMap.KeyMap Value -> Maybe Value
lookupPolicyValue key obj =
  KeyMap.lookup (Key.fromText key) obj
    <|> ( case KeyMap.lookup (Key.fromString "resolve") obj of
            Just (Object nested) -> KeyMap.lookup (Key.fromText key) nested
            _ -> Nothing
        )

valueToInt :: Value -> Maybe Int
valueToInt value =
  case fromJSON value :: Result Int of
    Success parsed -> Just parsed
    Error _ ->
      case value of
        String textValue -> readMaybeText textValue
        _ -> Nothing

readMaybeText :: Text -> Maybe Int
readMaybeText =
  readMaybe . Text.unpack

packageSource :: ResolvedPackage -> PackageSource
packageSource =
  coordinateSource . resolvedPackageCoordinate

constraintKey :: PackageConstraint -> Text
constraintKey constraint =
  Text.intercalate
    "|"
    [ constraintId constraint
    , fromMaybe "" (constraintSourcePackage constraint)
    , fromMaybe "" (constraintTargetPackageId constraint)
    , constraintRelation constraint
    , constraintTargetKind constraint
    ]

targetPathSafe :: FilePath -> Bool
targetPathSafe path =
  isRelative path
    && not (null path)
    && ".." `notElem` splitDirectories path

stableUrlSet :: [Url] -> [Url]
stableUrlSet =
  map urlFromText . stableTextSet . map urlText
