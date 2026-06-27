{-# LANGUAGE OverloadedStrings #-}

module Property.Generators
  ( genCompatibilityPackage
  , genCompatibilityRequest
  , genDiagnostic
  , genSafeText
  , genTarget
  , simpleLockfile
  , simplePackage
  , simplePerformanceSession
  , simpleTypedPlan
  ) where

import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import Panino.Core.Types
  ( projectIdFromText
  , relativePathFromFilePath
  , urlFromText
  )
import Panino.Compatibility.Types
  ( CompatibilityEvaluateRequest(..)
  , CompatibilityPackageInput(..)
  , CompatibilityTarget(..)
  )
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  )
import Panino.Install.Plan.Types
  ( InstallPlanEdge(..)
  , InstallPlanNode(..)
  , InstallPlanSummary(..)
  , TypedInstallPlan(..)
  , finalizeTypedInstallPlan
  )
import Panino.Lockfile.Types
  ( LockfileFile(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  )
import Panino.Performance.Profile.Types (defaultInstanceFingerprint)
import Panino.Performance.Telemetry.Types
  ( LaunchMetrics(..)
  , PerformanceSession(..)
  , PerformanceSessionStatus(..)
  , emptyGcMetrics
  , emptyMemoryMetrics
  )
import Test.QuickCheck
  ( Gen
  , chooseInt
  , elements
  , listOf
  , listOf1
  )

genSafeText :: Gen Text
genSafeText =
  Text.pack <$> listOf1 (elements (['a' .. 'z'] <> ['0' .. '9'] <> ['-', '_']))

genTarget :: Gen CompatibilityTarget
genTarget = do
  version <- elements ["1.20.1", "1.21.1", "1.21.7", "26.1.2"]
  loader <- elements [Nothing, Just "fabric", Just "quilt", Just "forge", Just "neoforge"]
  javaMajor <- chooseInt (8, 25)
  requiredJavaMajor <- chooseInt (8, 25)
  pure
    CompatibilityTarget
      { compatibilityTargetMinecraftVersion = Just version
      , compatibilityTargetLoader = loader
      , compatibilityTargetLoaderVersion = Nothing
      , compatibilityTargetShaderLoader = Nothing
      , compatibilityTargetGameDir = Just "/tmp/panino-test"
      , compatibilityTargetJavaMajor = Just javaMajor
      , compatibilityTargetRequiredJavaMajor = Just requiredJavaMajor
      , compatibilityTargetJavaArch = Just "aarch64"
      , compatibilityTargetSystemArch = Just "aarch64"
      }

genCompatibilityPackage :: Gen CompatibilityPackageInput
genCompatibilityPackage = do
  ident <- genSafeText
  versions <- listOf (elements ["1.20.1", "1.21.1", "1.21.7", "26.1.2"])
  loaders <- listOf (elements ["fabric", "quilt", "forge", "neoforge"])
  required <- listOf genSafeText
  optional <- listOf genSafeText
  metadataComplete <- elements [True, True, True, False]
  pure
    CompatibilityPackageInput
      { compatibilityPackageId = ident
      , compatibilityPackageName = ident
      , compatibilityPackageSource = Just "property"
      , compatibilityPackageKind = "mod"
      , compatibilityPackageMinecraftVersions = versions
      , compatibilityPackageLoaders = loaders
      , compatibilityPackageRequiredDependencies = required
      , compatibilityPackageOptionalDependencies = optional
      , compatibilityPackagePresent = True
      , compatibilityPackageMetadataComplete = metadataComplete
      , compatibilityPackageJavaMajor = Nothing
      }

genCompatibilityRequest :: Gen CompatibilityEvaluateRequest
genCompatibilityRequest = do
  target <- genTarget
  packages <- listOf genCompatibilityPackage
  pure
    CompatibilityEvaluateRequest
      { compatibilityRequestTarget = target
      , compatibilityRequestPackages = packages
      , compatibilityRequestInstalledPackageIds = map compatibilityPackageId packages
      , compatibilityRequestMissingRequiredDependencies = []
      , compatibilityRequestMissingOptionalDependencies = []
      , compatibilityRequestBlockedReasons = []
      , compatibilityRequestWarnings = []
      }

genDiagnostic :: Gen Diagnostic
genDiagnostic = do
  code <- elements ["compat_loader_family_mismatch", "compat_java_major_mismatch", "network_error", "hash_mismatch"]
  pure (diagnosticFromBlockedReason "property" "property" (code <> ":generated"))

simpleTypedPlan :: [InstallPlanNode] -> TypedInstallPlan
simpleTypedPlan nodes =
  finalizeTypedInstallPlan
    TypedInstallPlan
      { typedPlanId = ""
      , typedPlanFingerprint = ""
      , typedPlanKind = "property"
      , typedPlanTitle = "Property plan"
      , typedPlanTargetGameDir = Just "/tmp/panino-test"
      , typedPlanSource = Just "property"
      , typedPlanStatus = ""
      , typedPlanSummary = InstallPlanSummary 0 0 0 0 0 Nothing
      , typedPlanNodes = nodes
      , typedPlanEdges = [InstallPlanEdge "a" "b" "requires" True | length nodes > 1]
      , typedPlanWarnings = []
      , typedPlanBlockedReasons = []
      , typedPlanDiagnostics = []
      , typedPlanRollbackPolicy = "none"
      }

simplePackage :: Text -> ResolvedPackage
simplePackage ident =
  ResolvedPackage
    { resolvedPackageId = ident
    , resolvedPackageCoordinate =
        PackageCoordinate
          { coordinateSource = "property"
          , coordinateProjectId = projectIdFromText ident
          , coordinateVersionId = Just "1"
          , coordinateFileId = Just (ident <> "-file")
          , coordinateSlug = Just ident
          , coordinateName = Just ident
          , coordinateKind = "mod"
          }
    , resolvedPackageDisplayName = ident
    , resolvedPackageVersionName = Just "1.0.0"
    , resolvedPackageFileName = Just (ident <> ".jar")
    , resolvedPackageTargetPath = relativePathFromFilePath ("mods/" <> Text.unpack ident <> ".jar")
    , resolvedPackageHashes = Map.fromList [("sha1", ident <> "-sha1")]
    , resolvedPackageSize = Just 1
    , resolvedPackageDownloadUrls = [urlFromText ("https://example.invalid/" <> ident <> ".jar")]
    , resolvedPackageGameVersions = ["1.21.1"]
    , resolvedPackageLoaders = ["fabric"]
    , resolvedPackageJavaMajor = Nothing
    , resolvedPackageSide = Just "client"
    , resolvedPackageSelectedBecause = ["property"]
    , resolvedPackageLocked = False
    , resolvedPackagePinReason = Nothing
    , resolvedPackageDependencies = []
    , resolvedPackageConflicts = []
    , resolvedPackageSourceSnapshot = Nothing
    }

simpleLockfile :: [ResolvedPackage] -> PaninoLockfile
simpleLockfile packages =
  PaninoLockfile
    { lockfileVersion = 1
    , lockfileSolverVersion = "lockfile-solver-v1"
    , lockfileFingerprint = ""
    , lockfileCreatedAt = Nothing
    , lockfileUpdatedAt = Nothing
    , lockfileTargetGameDir = Just "/tmp/panino-test"
    , lockfileMinecraft = Just "1.21.1"
    , lockfileJava = Nothing
    , lockfileLoader = Nothing
    , lockfileShaderLoader = Nothing
    , lockfileRoots = map resolvedPackageId packages
    , lockfilePackages = packages
    , lockfileFiles = map packageFile packages
    , lockfileConstraints = []
    , lockfileOverrides = []
    , lockfileSourceSnapshots = []
    , lockfileManualEntries = []
    , lockfileWarnings = []
    }

packageFile :: ResolvedPackage -> LockfileFile
packageFile package =
  LockfileFile
    { lockfileFilePackageId = resolvedPackageId package
    , lockfileFileName = resolvedPackageId package <> ".jar"
    , lockfileFileTargetPath =
        fromMaybe "mods/generated.jar" $
          relativePathFromFilePath ("mods/" <> Text.unpack (resolvedPackageId package) <> ".jar")
    , lockfileFileHashes = resolvedPackageHashes package
    , lockfileFileSize = resolvedPackageSize package
    , lockfileFileDownloadUrls = resolvedPackageDownloadUrls package
    , lockfileFileKind = "mod"
    }

simplePerformanceSession :: PerformanceSession
simplePerformanceSession =
  PerformanceSession
    { sessionLaunchSessionId = "property-session"
    , sessionGameDir = "/tmp/panino-test"
    , sessionInstanceFingerprint = defaultInstanceFingerprint
    , sessionBaselineProfileId = Just "baseline"
    , sessionCandidateProfileId = Nothing
    , sessionStatus = SessionEnded
    , sessionStartedAt = posixSecondsToUTCTime 0
    , sessionEndedAt = Just (posixSecondsToUTCTime 10)
    , sessionLaunchMetrics = LaunchMetrics (Just 1000) Nothing Nothing (Just 0) False []
    , sessionMemoryMetrics = emptyMemoryMetrics
    , sessionGcMetrics = emptyGcMetrics
    , sessionCompanionFrameMetrics = Nothing
    , sessionAppliedProfile = Nothing
    , sessionRollbackRef = Nothing
    }
