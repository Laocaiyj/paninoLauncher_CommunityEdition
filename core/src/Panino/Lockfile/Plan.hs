{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Plan
  ( buildLockfileTypedPlan
  , lockfileFingerprintFor
  , packageNodeId
  , packageToLockfileFile
  ) where

import Data.Aeson
  ( Value
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy.Char8 as BL8
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  , isJust
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.CoreLogic.Determinism
  ( canonicalJson
  , stableFingerprint
  , stableSortOnText
  , stableSortPackages
  , stableTextSet
  )
import Panino.Core.Types
  ( Url
  , relativePathFilePath
  , urlFromText
  , urlText
  )
import Panino.Diagnostics.Types (Diagnostic)
import qualified Panino.Install.Plan.Types as Plan
import Panino.Lockfile.Types
  ( LockfileChange(..)
  , LockfileChangeset(..)
  , LockfileFile(..)
  , lockfileFileKey
  , PackageCoordinate(..)
  , PackageConstraint(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , resolvedPackageDownloadUrlTexts
  , resolvedPackageKey
  , resolvedPackageTargetPathFilePath
  )
import System.FilePath
  ( isRelative
  , (</>)
  )

lockfileFingerprintFor :: PaninoLockfile -> Text
lockfileFingerprintFor lockfile =
  stableFingerprint $
    object
      [ "fingerprintVersion" .= ("panino-lock-v1" :: Text)
      , "lockfileVersion" .= lockfileVersion lockfile
      , "solverVersion" .= lockfileSolverVersion lockfile
      , "minecraft" .= lockfileMinecraft lockfile
      , "java" .= lockfileJava lockfile
      , "loader" .= lockfileLoader lockfile
      , "shaderLoader" .= lockfileShaderLoader lockfile
      , "roots" .= stableTextSet (lockfileRoots lockfile)
      , "packages" .= stableSortPackages resolvedPackageKey (lockfilePackages lockfile)
      , "files" .= stableSortPackages lockfileFileKey (lockfileFiles lockfile)
      , "constraints" .= stableSortPackages constraintKey (lockfileConstraints lockfile)
      , "overrides" .= stableSortOnText jsonValueKey (lockfileOverrides lockfile)
      , "sourceSnapshots" .= stableSortOnText jsonValueKey (lockfileSourceSnapshots lockfile)
      , "manualEntries" .= stableSortPackages resolvedPackageKey (lockfileManualEntries lockfile)
      , "warnings" .= stableTextSet (lockfileWarnings lockfile)
      ]

packageToLockfileFile :: ResolvedPackage -> Maybe LockfileFile
packageToLockfileFile package = do
  targetPath <- resolvedPackageTargetPath package
  let targetPathFilePath = relativePathFilePath targetPath
  let fileName =
        fromMaybe
          (Text.pack (lastPathSegment targetPathFilePath))
          (resolvedPackageFileName package)
  pure
    LockfileFile
      { lockfileFilePackageId = resolvedPackageId package
      , lockfileFileName = fileName
      , lockfileFileTargetPath = targetPath
      , lockfileFileHashes = resolvedPackageHashes package
      , lockfileFileSize = resolvedPackageSize package
      , lockfileFileDownloadUrls = stableUrlSet (resolvedPackageDownloadUrls package)
      , lockfileFileKind = coordinateKind (resolvedPackageCoordinate package)
      }

buildLockfileTypedPlan :: FilePath -> [ResolvedPackage] -> [PackageConstraint] -> LockfileChangeset -> [Text] -> [Text] -> [Diagnostic] -> Plan.TypedInstallPlan
buildLockfileTypedPlan gameDir packages constraints changeset warnings blockedReasons diagnostics =
  Plan.finalizeTypedInstallPlan
    Plan.TypedInstallPlan
      { Plan.typedPlanId = ""
      , Plan.typedPlanFingerprint = ""
      , Plan.typedPlanKind = "lockfile"
      , Plan.typedPlanTitle = "Lockfile solve"
      , Plan.typedPlanTargetGameDir = Plan.typedPlanTargetGameDirFromPath (Just gameDir)
      , Plan.typedPlanSource = Just "lockfile-solver"
      , Plan.typedPlanStatus =
          Plan.installPlanStatusText $
            if null blockedReasons
              then Plan.InstallStatusReady
              else Plan.InstallStatusBlocked
      , Plan.typedPlanSummary = Plan.InstallPlanSummary 0 0 0 0 0 Nothing
      , Plan.typedPlanNodes = map packageNode sortedPackages
      , Plan.typedPlanEdges = packageEdges sortedPackages sortedConstraints
      , Plan.typedPlanWarnings = warnings
      , Plan.typedPlanBlockedReasons = blockedReasons
      , Plan.typedPlanDiagnostics = diagnostics
      , Plan.typedPlanRollbackPolicy = "automatic"
      }
  where
    sortedPackages = stableSortPackages resolvedPackageKey packages
    sortedConstraints = stableSortPackages constraintKey constraints
    changeActionMap =
      [ (lockfileChangePackageId change, lockfileChangeAction change)
      | change <-
          changesetKeep changeset
            <> changesetAdd changeset
            <> changesetReplace changeset
            <> changesetRemove changeset
            <> changesetRepair changeset
            <> changesetManual changeset
            <> changesetBlocked changeset
      ]
    selectedPackageIds = map resolvedPackageId sortedPackages
    dependsFor package =
      [ packageNodeId targetId
      | constraint <- constraints <> resolvedPackageDependencies package
      , constraintSourcePackage constraint == Just (resolvedPackageId package)
      , constraintRelation constraint `elem` ["requires", "optional", "pins"]
      , Just targetId <- [constraintTargetPackageId constraint]
      , targetId `elem` selectedPackageIds
      ]
    packageNode package =
      Plan.InstallPlanNode
        { Plan.installNodeId = packageNodeId (resolvedPackageId package)
        , Plan.installNodeKind = coordinateKind (resolvedPackageCoordinate package)
        , Plan.installNodeAction = packageAction package
        , Plan.installNodePhase = packagePhase package
        , Plan.installNodeLabel = resolvedPackageDisplayName package
        , Plan.installNodeTargetPath = absoluteTarget <$> resolvedPackageTargetPathFilePath package
        , Plan.installNodeSourceUrls = Plan.installNodeSourceUrlsFromTexts (stableTextSet (resolvedPackageDownloadUrlTexts package))
        , Plan.installNodeSha1 = Plan.installNodeSha1FromText (Map.lookup "sha1" (resolvedPackageHashes package))
        , Plan.installNodeSize = resolvedPackageSize package
        , Plan.installNodeRequired = True
        , Plan.installNodeDependsOn = dependsFor package
        , Plan.installNodeVerifications = packageVerifications package
        , Plan.installNodeRollback = rollbackFor package
        , Plan.installNodeBlockedReason = packageBlockedReason package
        , Plan.installNodeDiagnostics = []
        }
    packageAction :: ResolvedPackage -> Text
    packageAction package =
      case lookup (resolvedPackageId package) changeActionMap of
        Just "keep" -> "keep"
        Just "manual" -> "keep"
        Just "replace" -> "replace"
        Just "repair" -> "replace"
        Just "blocked" -> "verify"
        Just "remove" -> "delete"
        Just "add" -> if isJust (resolvedPackageTargetPath package) then "download" else "keep"
        _ | null (resolvedPackageDownloadUrls package) -> "keep"
          | otherwise -> "download"
    packagePhase :: ResolvedPackage -> Text
    packagePhase package =
      case coordinateKind (resolvedPackageCoordinate package) of
        "minecraft" -> "metadata"
        "javaRuntime" -> "java"
        "loader" -> "loader"
        "loaderInstaller" -> "loader"
        "shaderLoader" -> "content"
        "resourcePack" -> "content"
        "shaderPack" -> "content"
        _ -> "content"
    packageVerifications :: ResolvedPackage -> [Plan.InstallVerification]
    packageVerifications package =
      [ Plan.InstallVerification "targetPathSafe" "ok" Nothing
      | isJust (resolvedPackageTargetPath package)
      ]
        <> [ Plan.InstallVerification "hashKnown" "ok" Nothing
           | Map.member "sha1" (resolvedPackageHashes package)
           ]
        <> [ Plan.InstallVerification "sourceAvailable" "ok" Nothing
           | not (null (resolvedPackageDownloadUrls package))
           ]
    rollbackFor :: ResolvedPackage -> Plan.InstallPlanRollbackAction
    rollbackFor package =
      Plan.InstallPlanRollbackAction
        { Plan.installRollbackAction =
            case packageAction package of
              "replace" -> "restoreBackup"
              "download" -> "removeCreatedFile"
              "delete" -> "restoreBackup"
              _ -> "noneWithReason"
        , Plan.installRollbackTargetPath = absoluteTarget <$> resolvedPackageTargetPathFilePath package
        , Plan.installRollbackBackupPath = Nothing
        , Plan.installRollbackReason = Just "Lockfile apply owns final lockfile write; node rollback only covers file action."
        }
    packageBlockedReason :: ResolvedPackage -> Maybe Text
    packageBlockedReason package =
      case lookup (resolvedPackageId package) [(lockfileChangePackageId change, lockfileChangeReason change) | change <- changesetBlocked changeset] of
        Just reason -> Just reason
        Nothing -> Nothing
    absoluteTarget targetPath
      | isRelative targetPath = gameDir </> targetPath
      | otherwise = targetPath

packageNodeId :: Text -> Text
packageNodeId packageId =
  "lockfile-package-" <> packageId

packageEdges :: [ResolvedPackage] -> [PackageConstraint] -> [Plan.InstallPlanEdge]
packageEdges packages constraints =
  [ Plan.InstallPlanEdge
      { Plan.installEdgeFrom = packageNodeId targetId
      , Plan.installEdgeTo = packageNodeId sourceId
      , Plan.installEdgeKind = constraintRelation constraint
      , Plan.installEdgeRequired = constraintRequired constraint
      }
  | constraint <- constraints
  , constraintRelation constraint `elem` ["requires", "optional", "pins"]
  , Just sourceId <- [constraintSourcePackage constraint]
  , Just targetId <- [constraintTargetPackageId constraint]
  , sourceId `elem` packageIds
  , targetId `elem` packageIds
  ]
  where
    packageIds = map resolvedPackageId packages

lastPathSegment :: FilePath -> FilePath
lastPathSegment path =
  case reverse (splitPathSegments path) of
    segment:_ -> segment
    [] -> path

splitPathSegments :: FilePath -> [FilePath]
splitPathSegments =
  filter (not . null) . splitOnSlash

splitOnSlash :: FilePath -> [FilePath]
splitOnSlash value =
  case break (== '/') value of
    (segment, []) -> [segment]
    (segment, _:rest) -> segment : splitOnSlash rest

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

jsonValueKey :: Value -> Text
jsonValueKey =
  Text.pack . BL8.unpack . canonicalJson

stableUrlSet :: [Url] -> [Url]
stableUrlSet =
  map urlFromText . stableTextSet . map urlText
