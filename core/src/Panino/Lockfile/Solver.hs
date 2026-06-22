{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Lockfile.Solver
  ( diffLockfiles
  , lockfileApplyReadyLockfile
  , lockfileLaunchBlockedReasons
  , lockfileSolveCacheGameDir
  , roomLockRepairPlan
  , roomRequiredLockSubset
  , solveLockfile
  , solveLockfileWithServices
  , verifyLockfile
  ) where

import Control.Applicative ((<|>))
import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import Data.Aeson
  ( Result(..)
  , Value(Object, String)
  , fromJSON
  , object
  , (.=)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List
  ( find
  , foldl'
  , groupBy
  , sortOn
  )
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( catMaybes
  , fromMaybe
  , isJust
  , listToMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Text.Read (readMaybe)
import Network.HTTP.Client (Manager)
import Panino.Content.Online.CurseForge
  ( curseForgeProject
  )
import Panino.Content.Online.Modrinth
  ( modrinthProject
  , modrinthRequiredDependencyReleases
  )
import Panino.Content.Online.Types
  ( ContentProjectRequest(..)
  , ContentProjectResponse(..)
  , ContentSearchRequest(..)
  , OnlineDependency(..)
  , OnlineFile(..)
  , OnlineRelease(..)
  )
import Panino.Content.Configuration.Preflight
  ( modpackPreflight
  )
import Panino.Content.Configuration.Types
  ( ModpackPreflightRequest(..)
  , ModpackPreflightResponse(..)
  )
import Panino.Performance.Pack
  ( PerformanceModEntry(..)
  , PerformancePackRecommendation(..)
  , performanceModFileNames
  , recommendPerformancePack
  )
import Panino.CoreLogic.Determinism
  ( stableFingerprint
  , stableSortOnText
  , stableSortPackages
  , stableTextSet
  )
import Panino.CoreLogic.Hashing (sha1File)
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Diagnostics.Types (Diagnostic)
import qualified Panino.Install.Plan.Types as Plan
import Panino.Lockfile.Changeset
  ( buildChangeset
  , diffLockfiles
  , sortChangeset
  )
import Panino.Lockfile.Explain
  ( constraintExplainEntry
  , packageExplainEntry
  , rootExplainEntry
  )
import Panino.Lockfile.Plan
  ( buildLockfileTypedPlan
  , lockfileFingerprintFor
  , packageToLockfileFile
  )
import Panino.Lockfile.Types
  ( LockfileApplyRequest(..)
  , LockfileChange(..)
  , LockfileChangeset(..)
  , LockfileExplain(..)
  , LockfileExplainEntry(..)
  , LockfileFile(..)
  , LockfileSolveRequest(..)
  , LockfileVerifyResponse(..)
  , PackageConstraint(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , SolverConflict(..)
  , SolverResult(..)
  , lockfileFileKey
  , resolvedPackageKey
  )
import Panino.Lockfile.Verify
  ( verifyIssueBlockedReason
  , verifyLockfile
  )
import Panino.Minecraft.InstallPreflight
  ( LoaderInstallPreflightRequest(..)
  , LoaderInstallPreflightResponse(..)
  , loaderInstallPreflight
  )
import Panino.Minecraft.Layout
  ( mkLayout
  )
import Panino.Runtime.Java.Resolve
  ( resolveJavaRuntime
  )
import Panino.Runtime.Java.Types
  ( JavaRuntimeDownloadSpec(..)
  , JavaRuntimeResolveRequest(..)
  , JavaRuntimeResolveResponse(..)
  )
import System.Directory
  ( doesFileExist
  )
import System.FilePath
  ( isRelative
  , makeRelative
  , normalise
  , splitDirectories
  , takeFileName
  , takeDirectory
  , (</>)
  )

solveLockfile :: LockfileSolveRequest -> SolverResult
solveLockfile request =
  let normalizedRoots =
        stableSortPackages resolvedPackageKey $
          map (applyPins request . normalizePackage (solveRequestTargetGameDir request) "root request") (solveRequestRoots request)
      selectedUpdateIds = selectedUpdatePackageIds request normalizedRoots
      normalizedManual =
        stableSortPackages resolvedPackageKey $
          map (applyPins request . normalizePackage (solveRequestTargetGameDir request) "manual entry") (solveRequestManualPackages request)
      normalizedExisting =
        stableSortPackages resolvedPackageKey $
          maybe
            []
            ( map
                ( applyExistingLockPolicy request selectedUpdateIds
                    . applyPins request
                    . normalizePackage (solveRequestTargetGameDir request) "existing lockfile"
                )
                . lockfilePackages
            )
            (solveRequestExistingLockfile request)
      availablePackages = dedupePackages request (normalizedRoots <> normalizedManual <> normalizedExisting)
      availableMap = Map.fromList [(resolvedPackageId package, package) | package <- availablePackages]
      rootPackageIds = stableTextSet (map resolvedPackageId (normalizedRoots <> normalizedManual) <> existingRootPackageIds normalizedExisting)
      resolvedState = foldl' (resolvePackageId request availableMap) emptyResolveState rootPackageIds
      selectedPackages = stableSortPackages resolvedPackageKey (Map.elems (resolveSelected resolvedState))
      constraints = stableSortPackages constraintKey (concatMap packageAllConstraints selectedPackages)
      warnings = stableTextSet (resolveWarnings resolvedState <> optifineWarnings request selectedPackages)
      conflicts = detectConflicts request selectedPackages constraints
      conflictReasons = map conflictBlockedReason conflicts
      packageBlockedReasons = detectPackageBlockedReasons selectedPackages
      blockedReasons =
        stableTextSet
          ( resolveBlockedReasons resolvedState
              <> conflictReasons
              <> packageBlockedReasons
          )
      diagnostics = map (diagnosticFromBlockedReason "solve" "lockfile solver") blockedReasons
      changeset = sortChangeset (buildChangeset request selectedPackages blockedReasons)
      stagedLockfile = buildLockfile request selectedPackages constraints warnings
      fingerprint = lockfileFingerprintFor stagedLockfile
      lockfile = stagedLockfile { lockfileFingerprint = fingerprint }
      explain =
        LockfileExplain
          { explainRootRequests = stableSortPackages explainEntryKey (map rootExplainEntry normalizedRoots)
          , explainConstraints = stableSortPackages explainEntryKey (map constraintExplainEntry constraints)
          , explainSelectedCandidates = stableSortPackages explainEntryKey (map packageExplainEntry selectedPackages)
          , explainRejectedCandidates = stableSortPackages explainEntryKey (resolveRejected resolvedState)
          , explainFingerprint = Just fingerprint
          }
      typedPlan =
        buildLockfileTypedPlan
          (solveRequestTargetGameDir request)
          selectedPackages
          constraints
          changeset
          warnings
          blockedReasons
          diagnostics
      status = if null blockedReasons then "ready" else "blocked"
   in SolverResult
        { solverResultStatus = status
        , solverResultLockfile = Just lockfile
        , solverResultTypedPlan = typedPlan
        , solverResultChangeset = changeset
        , solverResultWarnings = warnings
        , solverResultBlockedReasons = blockedReasons
        , solverResultConflicts = conflicts
        , solverResultExplain = explain
        , solverResultDiagnostics = diagnostics
        }
  where
    existingRootPackageIds packages
      | solveRequestUpdatePolicy request == "relock" = []
      | otherwise = map resolvedPackageId packages

solveLockfileWithServices :: Manager -> LockfileSolveRequest -> IO SolverResult
solveLockfileWithServices manager request = do
  preflight <- preflightServiceEvidence manager request
  modpack <- modpackSourceServiceEvidence request
  performancePack <- performancePackServiceEvidence request
  onlineRoots <- onlineRootServiceEvidence manager (requestWithServiceEvidence request (mergeServiceEvidence [preflight, modpack, performancePack]))
  let dependencyRequest = requestWithServiceEvidence request (mergeServiceEvidence [preflight, modpack, performancePack, onlineRoots])
  modrinthDependencies <- modrinthDependencyServiceEvidence manager dependencyRequest
  curseForgeDependencies <- curseForgeDependencyServiceEvidence manager dependencyRequest
  javaRuntime <- javaRuntimeServiceEvidence manager request
  let evidence = mergeServiceEvidence [preflight, modpack, performancePack, onlineRoots, modrinthDependencies, curseForgeDependencies, javaRuntime]
      augmentedRequest =
        request
          { solveRequestLoaderVersion = solveRequestLoaderVersion request <|> serviceLoaderVersion evidence
          , solveRequestJavaPolicy = serviceJavaPolicy evidence <|> solveRequestJavaPolicy request
          , solveRequestRoots =
              solveRequestRoots request
                <> stableSortPackages resolvedPackageKey (servicePackages evidence)
          }
  pure (applyServiceEvidence evidence (solveLockfile augmentedRequest))

requestWithServiceEvidence :: LockfileSolveRequest -> ServiceEvidence -> LockfileSolveRequest
requestWithServiceEvidence request evidence =
  request
    { solveRequestRoots =
        solveRequestRoots request
          <> stableSortPackages resolvedPackageKey (servicePackages evidence)
    }

data ServiceEvidence = ServiceEvidence
  { servicePackages :: [ResolvedPackage]
  , serviceWarnings :: [Text]
  , serviceBlockedReasons :: [Text]
  , serviceDiagnostics :: [Diagnostic]
  , serviceLoaderVersion :: Maybe Text
  , serviceJavaPolicy :: Maybe Value
  } deriving (Eq, Show)

emptyServiceEvidence :: ServiceEvidence
emptyServiceEvidence =
  ServiceEvidence [] [] [] [] Nothing Nothing

mergeServiceEvidence :: [ServiceEvidence] -> ServiceEvidence
mergeServiceEvidence evidence =
  ServiceEvidence
    { servicePackages = stableSortPackages resolvedPackageKey (concatMap servicePackages evidence)
    , serviceWarnings = stableTextSet (concatMap serviceWarnings evidence)
    , serviceBlockedReasons = stableTextSet (concatMap serviceBlockedReasons evidence)
    , serviceDiagnostics = concatMap serviceDiagnostics evidence
    , serviceLoaderVersion = firstJust (map serviceLoaderVersion evidence)
    , serviceJavaPolicy = firstJust (map serviceJavaPolicy evidence)
    }

applyServiceEvidence :: ServiceEvidence -> SolverResult -> SolverResult
applyServiceEvidence evidence result =
  let warnings = stableTextSet (solverResultWarnings result <> serviceWarnings evidence)
      blockedReasons = stableTextSet (solverResultBlockedReasons result <> serviceBlockedReasons evidence)
      diagnostics =
        serviceDiagnostics evidence
          <> map (diagnosticFromBlockedReason "solve" "lockfile solver") blockedReasons
      typedPlan =
        Plan.finalizeTypedInstallPlan
          (solverResultTypedPlan result)
            { Plan.typedPlanWarnings = warnings
            , Plan.typedPlanBlockedReasons = blockedReasons
            , Plan.typedPlanDiagnostics = diagnostics
            }
      lockfile =
        updateLockfileFingerprint
          . (\value -> value { lockfileWarnings = warnings })
          <$> solverResultLockfile result
      fingerprint = lockfileFingerprint <$> lockfile
      explain = (solverResultExplain result) { explainFingerprint = fingerprint }
   in result
        { solverResultStatus = if null blockedReasons then solverResultStatus result else "blocked"
        , solverResultLockfile = lockfile
        , solverResultTypedPlan = typedPlan
        , solverResultWarnings = warnings
        , solverResultBlockedReasons = blockedReasons
        , solverResultExplain = explain
        , solverResultDiagnostics = diagnostics
        }

preflightServiceEvidence :: Manager -> LockfileSolveRequest -> IO ServiceEvidence
preflightServiceEvidence manager request =
  case solveRequestMinecraftVersion request of
    Nothing -> pure emptyServiceEvidence
    Just minecraftVersion
      | solveRequestLoader request == Nothing && solveRequestShaderLoader request == Nothing ->
          pure emptyServiceEvidence
      | otherwise -> do
          outcome <-
            try
              ( loaderInstallPreflight
                  manager
                  LoaderInstallPreflightRequest
                    { preflightMinecraftVersion = minecraftVersion
                    , preflightLoader = solveRequestLoader request
                    , preflightLoaderVersion = Nothing
                    , preflightShaderLoader = solveRequestShaderLoader request
                    , preflightShaderVersion = Nothing
                    , preflightGameDir = Just (solveRequestTargetGameDir request)
                    , preflightJavaExecutable = javaExecutableFromPolicy (solveRequestJavaPolicy request)
                    , preflightSourceProfile = Nothing
                    }
              )
          case outcome of
            Left (err :: SomeException) ->
              pure (serviceBlocked ("install_preflight_failed:" <> Text.pack (displayException err)))
            Right response ->
              pure
                ServiceEvidence
                  { servicePackages = preflightResolvedPackages response
                  , serviceWarnings = preflightResponseWarnings response
                  , serviceBlockedReasons = preflightResponseBlockedReasons response
                  , serviceDiagnostics = preflightResponseStructuredDiagnostics response
                  , serviceLoaderVersion = preflightResponseLoaderVersion response
                  , serviceJavaPolicy = Nothing
                  }

javaRuntimeServiceEvidence :: Manager -> LockfileSolveRequest -> IO ServiceEvidence
javaRuntimeServiceEvidence manager request =
  case solveRequestMinecraftVersion request of
    Nothing -> pure emptyServiceEvidence
    Just minecraftVersion -> do
      let appRoot = takeDirectory (solveRequestTargetGameDir request)
      cacheLayout <- mkLayout (Just (lockfileSolveCacheGameDir (solveRequestTargetGameDir request)))
      outcome <-
        try
          ( resolveJavaRuntime
              manager
              appRoot
              (Just cacheLayout)
              (javaResolveRequest request minecraftVersion)
          )
      case outcome of
        Left (err :: SomeException) ->
          pure (serviceBlocked ("java_runtime_resolve_failed:" <> Text.pack (displayException err)))
        Right response -> do
          javaPolicyValue <- javaRuntimePolicyValue response
          pure
            emptyServiceEvidence
              { servicePackages = [javaRuntimePackage response]
              , serviceWarnings = resolveResponseWarnings response
              , serviceBlockedReasons = javaRuntimeBlockedReasons response
              , serviceDiagnostics =
                  map (diagnosticFromBlockedReason "solve" "java runtime") (javaRuntimeBlockedReasons response)
              , serviceJavaPolicy = Just javaPolicyValue
              }

lockfileSolveCacheGameDir :: FilePath -> FilePath
lockfileSolveCacheGameDir targetGameDir =
  takeDirectory targetGameDir </> ".panino" </> "lockfile-solve-cache"

modpackSourceServiceEvidence :: LockfileSolveRequest -> IO ServiceEvidence
modpackSourceServiceEvidence request =
  case solveRequestSourcePath request of
    Nothing -> pure emptyServiceEvidence
    Just sourcePath -> do
      response <-
        modpackPreflight
          ModpackPreflightRequest
            { modpackPreflightSourceType = fromMaybe "local" (solveRequestSourceType request)
            , modpackPreflightSourcePath = Just sourcePath
            , modpackPreflightTargetGameDir = Just (solveRequestTargetGameDir request)
            }
      pure
        emptyServiceEvidence
          { servicePackages = modpackPreflightPackages request response
          , serviceWarnings = modpackPreflightWarnings response
          , serviceBlockedReasons = modpackPreflightBlockingReasons response
          , serviceDiagnostics =
              map (diagnosticFromBlockedReason "solve" "modpack preflight") (modpackPreflightBlockingReasons response)
          , serviceLoaderVersion = modpackPreflightLoaderVersion response
          }

modpackPreflightPackages :: LockfileSolveRequest -> ModpackPreflightResponse -> [ResolvedPackage]
modpackPreflightPackages request response =
  stableSortPackages resolvedPackageKey $
    mapMaybe (modpackNodePackage source) (Plan.typedPlanNodes (modpackPreflightTypedPlan response))
  where
    source = normalizeSource (fromMaybe "modrinth" (solveRequestSourceType request))

modpackNodePackage :: Text -> Plan.InstallPlanNode -> Maybe ResolvedPackage
modpackNodePackage source node
  | Plan.installNodeKind node `elem` ["mod", "resourcePack", "shaderPack", "overrideFile"] =
      Just
        ResolvedPackage
          { resolvedPackageId =
              "modpack:" <> Text.take 16 (stableFingerprint (object ["targetPath" .= Plan.installNodeTargetPath node, "label" .= Plan.installNodeLabel node]))
          , resolvedPackageCoordinate =
              PackageCoordinate
                { coordinateSource = nodeSource
                , coordinateProjectId = Nothing
                , coordinateVersionId = Nothing
                , coordinateFileId = Just (Plan.installNodeId node)
                , coordinateSlug = Just (Plan.installNodeLabel node)
                , coordinateName = Just (Plan.installNodeLabel node)
                , coordinateKind = normalizeKind (Plan.installNodeKind node)
                }
          , resolvedPackageDisplayName = Plan.installNodeLabel node
          , resolvedPackageVersionName = Nothing
          , resolvedPackageFileName = Text.pack . takeFileName <$> Plan.installNodeTargetPath node
          , resolvedPackageTargetPath = Plan.installNodeTargetPath node
          , resolvedPackageHashes = maybe Map.empty (Map.singleton "sha1") (Plan.installNodeSha1 node)
          , resolvedPackageSize = Plan.installNodeSize node
          , resolvedPackageDownloadUrls = stableTextSet (Plan.installNodeSourceUrls node)
          , resolvedPackageGameVersions = []
          , resolvedPackageLoaders = []
          , resolvedPackageJavaMajor = Nothing
          , resolvedPackageSide = Just "client"
          , resolvedPackageSelectedBecause = ["modpack preflight"]
          , resolvedPackageLocked = False
          , resolvedPackagePinReason = Nothing
          , resolvedPackageDependencies = []
          , resolvedPackageConflicts = []
          , resolvedPackageSourceSnapshot = Just "modpack-preflight"
          }
  | otherwise = Nothing
  where
    nodeSource
      | null (Plan.installNodeSourceUrls node) = "local"
      | otherwise = source

performancePackServiceEvidence :: LockfileSolveRequest -> IO ServiceEvidence
performancePackServiceEvidence request
  | not (solveRequestIncludePerformancePack request) = pure emptyServiceEvidence
  | otherwise = do
      modFiles <- performanceModFileNames (Just (solveRequestTargetGameDir request))
      let recommendation =
            recommendPerformancePack
              (solveRequestLoader request)
              (solveRequestMinecraftVersion request)
              Nothing
              modFiles
      pure
        emptyServiceEvidence
          { servicePackages = [performancePackPackage recommendation]
          , serviceWarnings = performanceRecommendationSkippedReasons recommendation
          }

performancePackPackage :: PerformancePackRecommendation -> ResolvedPackage
performancePackPackage recommendation =
  ResolvedPackage
    { resolvedPackageId = "performance-pack:" <> fromMaybe "unknown" (performanceRecommendationLoader recommendation)
    , resolvedPackageCoordinate =
        PackageCoordinate
          { coordinateSource = "panino"
          , coordinateProjectId = Just "performance-pack"
          , coordinateVersionId = performanceRecommendationMinecraftVersion recommendation
          , coordinateFileId = Nothing
          , coordinateSlug = Just "performance-pack"
          , coordinateName = Just (performanceRecommendationTitle recommendation)
          , coordinateKind = "performancePack"
          }
    , resolvedPackageDisplayName = performanceRecommendationTitle recommendation
    , resolvedPackageVersionName = performanceRecommendationMinecraftVersion recommendation
    , resolvedPackageFileName = Nothing
    , resolvedPackageTargetPath = Nothing
    , resolvedPackageHashes = Map.empty
    , resolvedPackageSize = Nothing
    , resolvedPackageDownloadUrls = []
    , resolvedPackageGameVersions = maybe [] (: []) (performanceRecommendationMinecraftVersion recommendation)
    , resolvedPackageLoaders = maybe [] ((: []) . normalizeLoader) (performanceRecommendationLoader recommendation)
    , resolvedPackageJavaMajor = Nothing
    , resolvedPackageSide = Just "client"
    , resolvedPackageSelectedBecause = ["performance pack recommendation"]
    , resolvedPackageLocked = False
    , resolvedPackagePinReason = Nothing
    , resolvedPackageDependencies = map performanceOptionalConstraint (performanceRecommendationInstallable recommendation)
    , resolvedPackageConflicts = map performanceConflictConstraint (performanceRecommendationConflicts recommendation)
    , resolvedPackageSourceSnapshot = Just ("performance-pack:" <> performanceRecommendationStatus recommendation)
    }

performanceOptionalConstraint :: PerformanceModEntry -> PackageConstraint
performanceOptionalConstraint entry =
  PackageConstraint
    { constraintId = "performance-pack:optional:" <> performanceModId entry
    , constraintSourcePackage = Nothing
    , constraintTargetPackageId = Just (performanceModId entry)
    , constraintTargetKind = "mod"
    , constraintRelation = "optional"
    , constraintMinecraftVersions = []
    , constraintLoaders = []
    , constraintJavaMajor = Nothing
    , constraintSide = Just "client"
    , constraintRequired = False
    , constraintReason = performanceModTitle entry <> " is recommended by the Panino performance pack but requires explicit selection."
    }

performanceConflictConstraint :: PerformanceModEntry -> PackageConstraint
performanceConflictConstraint entry =
  PackageConstraint
    { constraintId = "performance-pack:conflict:" <> performanceModId entry
    , constraintSourcePackage = Nothing
    , constraintTargetPackageId = Just (performanceModId entry)
    , constraintTargetKind = "mod"
    , constraintRelation = "conflicts"
    , constraintMinecraftVersions = []
    , constraintLoaders = []
    , constraintJavaMajor = Nothing
    , constraintSide = Just "client"
    , constraintRequired = True
    , constraintReason = performanceModReason entry
    }

modrinthDependencyServiceEvidence :: Manager -> LockfileSolveRequest -> IO ServiceEvidence
modrinthDependencyServiceEvidence manager request =
  case requiredModrinthDependencies request of
    [] -> pure emptyServiceEvidence
    dependencies -> do
      outcome <- try (modrinthRequiredDependencyReleases manager (modrinthDependencyQuery request) dependencies)
      case outcome of
        Left (err :: SomeException) ->
          pure (serviceBlocked ("modrinth_dependency_resolver_failed:" <> Text.pack (displayException err)))
        Right releases ->
          pure
            emptyServiceEvidence
              { servicePackages =
                  stableSortPackages resolvedPackageKey (map onlineReleaseToPackage releases)
              }

onlineRootServiceEvidence :: Manager -> LockfileSolveRequest -> IO ServiceEvidence
onlineRootServiceEvidence manager request =
  mergeServiceEvidence <$> mapM resolveRoot (stableSortPackages resolvedPackageKey (solveRequestRoots request))
  where
    resolveRoot package
      | not (onlineRootNeedsResolution package) = pure emptyServiceEvidence
      | otherwise = do
          outcome <- try (onlineRootPackage manager request package)
          case outcome of
            Left (err :: SomeException) ->
              pure (serviceBlocked ("online_root_resolve_failed:" <> resolvedPackageId package <> ":" <> Text.pack (displayException err)))
            Right Nothing ->
              pure (serviceBlocked ("online_root_missing_project_id:" <> resolvedPackageId package))
            Right (Just resolved) ->
              pure emptyServiceEvidence { servicePackages = [resolved] }

onlineRootNeedsResolution :: ResolvedPackage -> Bool
onlineRootNeedsResolution package =
  normalizeSource (packageSource package) `elem` ["modrinth", "curseforge"]
    && resolvedPackageSourceSnapshot package `notElem` [Just "install-preflight", Just "modpack-preflight"]
    && ( coordinateVersionId (resolvedPackageCoordinate package) == Nothing
           || resolvedPackageTargetPath package == Nothing
           || null (resolvedPackageDownloadUrls package)
           || not (Map.member "sha1" (resolvedPackageHashes package))
       )

onlineRootPackage :: Manager -> LockfileSolveRequest -> ResolvedPackage -> IO (Maybe ResolvedPackage)
onlineRootPackage manager request package =
  case onlineRootProjectId package of
    Nothing -> pure Nothing
    Just projectIdValue -> do
      response <-
        case normalizeSource (packageSource package) of
          "modrinth" -> modrinthProject manager (projectRequest "modrinth" projectIdValue)
          "curseforge" -> curseForgeProject manager (projectRequest "curseForge" projectIdValue)
          _ -> fail "unsupported online source"
      case preferredContentRelease response of
        Nothing -> fail ("no compatible online release found for " <> Text.unpack projectIdValue)
        Just release -> pure (Just (onlineReleaseToPackageForRoot package release))
  where
    projectRequest source projectIdValue =
      ContentProjectRequest
        { contentProjectSource = source
        , contentProjectId = projectIdValue
        , contentProjectQuery = onlineContentQuery source (coordinateKind (resolvedPackageCoordinate package)) request
        , contentProjectCurseForgeApiKey = solveRequestCurseForgeApiKey request
        }

onlineRootProjectId :: ResolvedPackage -> Maybe Text
onlineRootProjectId package =
  coordinateProjectId coordinate
    <|> coordinateSlug coordinate
    <|> nonEmptyText (resolvedPackageId package)
  where
    coordinate = resolvedPackageCoordinate package

nonEmptyText :: Text -> Maybe Text
nonEmptyText value
  | Text.null value = Nothing
  | otherwise = Just value

preferredContentRelease :: ContentProjectResponse -> Maybe OnlineRelease
preferredContentRelease response =
  contentProjectResponseRecommendedRelease response
    <|> listToMaybe (contentProjectResponseReleases response)

curseForgeDependencyServiceEvidence :: Manager -> LockfileSolveRequest -> IO ServiceEvidence
curseForgeDependencyServiceEvidence manager request =
  case requiredCurseForgeDependencies request of
    [] -> pure emptyServiceEvidence
    dependencies -> do
      outcome <- try (curseForgeRequiredDependencyPackages manager request dependencies)
      case outcome of
        Left (err :: SomeException) ->
          pure (serviceBlocked ("curseforge_dependency_resolver_failed:" <> Text.pack (displayException err)))
        Right packages ->
          pure emptyServiceEvidence { servicePackages = stableSortPackages resolvedPackageKey packages }

curseForgeRequiredDependencyPackages :: Manager -> LockfileSolveRequest -> [OnlineDependency] -> IO [ResolvedPackage]
curseForgeRequiredDependencyPackages manager request =
  fmap (dedupePackages request) . fmap concat . mapM (resolveDependency [])
  where
    resolveDependency visited dependency
      | any (`elem` visited) (dependencyVisitKeysLocal dependency) = pure []
      | otherwise =
          case dependencyProjectId dependency of
            Nothing -> fail "CurseForge required dependency is missing projectId"
            Just projectIdValue -> do
              response <-
                curseForgeProject
                  manager
                  ContentProjectRequest
                    { contentProjectSource = "curseForge"
                    , contentProjectId = projectIdValue
                    , contentProjectQuery = onlineContentQuery "curseForge" "mod" request
                    , contentProjectCurseForgeApiKey = solveRequestCurseForgeApiKey request
                    }
              release <-
                case preferredContentRelease response of
                  Just value -> pure value
                  Nothing -> fail ("no compatible CurseForge dependency release found for " <> Text.unpack projectIdValue)
              let package = onlineReleaseToPackage release
                  visited' = dependencyVisitKeysLocal dependency <> [resolvedPackageId package] <> visited
              nested <- concat <$> mapM (resolveDependency visited') (requiredCurseForgeDependenciesForPackage package)
              pure (nested <> [package])

requiredCurseForgeDependencies :: LockfileSolveRequest -> [OnlineDependency]
requiredCurseForgeDependencies request =
  stableSortPackages onlineDependencyKey $
    concatMap requiredCurseForgeDependenciesForPackage (solveRequestRoots request <> solveRequestManualPackages request)

requiredCurseForgeDependenciesForPackage :: ResolvedPackage -> [OnlineDependency]
requiredCurseForgeDependenciesForPackage package =
  [ OnlineDependency
      { dependencyId =
          Text.intercalate
            ":"
            [ fromMaybe (constraintId constraint) (constraintTargetPackageId constraint)
            , "required"
            ]
      , dependencyProjectId = constraintTargetPackageId constraint
      , dependencyVersionId = Nothing
      , dependencySource = "curseForge"
      , dependencyRelation = "required"
      }
  | normalizeSource (packageSource package) == "curseforge"
  , constraint <- resolvedPackageDependencies package
  , normalizeRelation (constraintRelation constraint) == "requires"
  , constraintRequired constraint
  , isJust (constraintTargetPackageId constraint)
  ]

dependencyVisitKeysLocal :: OnlineDependency -> [Text]
dependencyVisitKeysLocal dependency =
  catMaybes
    [ Just (dependencyId dependency)
    , dependencyProjectId dependency
    , dependencyVersionId dependency
    ]

onlineContentQuery :: Text -> Text -> LockfileSolveRequest -> ContentSearchRequest
onlineContentQuery source kind request =
  ContentSearchRequest
    { contentSearchSource = source
    , contentSearchText = ""
    , contentSearchProjectTypes = [projectTypeForKind kind]
    , contentSearchCategories = []
    , contentSearchGameVersion = solveRequestMinecraftVersion request
    , contentSearchLoaders = maybe [] ((: []) . normalizeLoader) (solveRequestLoader request)
    , contentSearchSort = "downloads"
    , contentSearchOffset = 0
    , contentSearchLimit = 20
    , contentSearchCurseForgeApiKey = solveRequestCurseForgeApiKey request
    , contentSearchPrefetch = False
    }

projectTypeForKind :: Text -> Text
projectTypeForKind kind =
  case normalizeKind kind of
    "resourcePack" -> "resourcePack"
    "shaderPack" -> "shaderPack"
    "performancePack" -> "mod"
    "modpack" -> "modpack"
    _ -> "mod"

serviceBlocked :: Text -> ServiceEvidence
serviceBlocked reason =
  emptyServiceEvidence
    { serviceBlockedReasons = [reason]
    , serviceDiagnostics = [diagnosticFromBlockedReason "solve" "lockfile services" reason]
    }

preflightResolvedPackages :: LoaderInstallPreflightResponse -> [ResolvedPackage]
preflightResolvedPackages response =
  stableSortPackages resolvedPackageKey (loaderPackage <> shaderPackages)
  where
    minecraftVersion = preflightResponseMinecraftVersion response
    loaderPackage =
      [ ResolvedPackage
          { resolvedPackageId = "loader:" <> loader
          , resolvedPackageCoordinate =
              PackageCoordinate
                { coordinateSource = "loaderMeta"
                , coordinateProjectId = Just loader
                , coordinateVersionId = preflightResponseLoaderVersion response
                , coordinateFileId = preflightResponseLoaderProfileId response
                , coordinateSlug = Just loader
                , coordinateName = Just (loader <> " loader")
                , coordinateKind = "loader"
                }
          , resolvedPackageDisplayName = loader <> " loader"
          , resolvedPackageVersionName = preflightResponseLoaderVersion response
          , resolvedPackageFileName = Nothing
          , resolvedPackageTargetPath = Nothing
          , resolvedPackageHashes = Map.empty
          , resolvedPackageSize = Nothing
          , resolvedPackageDownloadUrls = []
          , resolvedPackageGameVersions = [minecraftVersion]
          , resolvedPackageLoaders = [loader]
          , resolvedPackageJavaMajor = Nothing
          , resolvedPackageSide = Just "client"
          , resolvedPackageSelectedBecause = ["install preflight"]
          , resolvedPackageLocked = False
          , resolvedPackagePinReason = Nothing
          , resolvedPackageDependencies = []
          , resolvedPackageConflicts = []
          , resolvedPackageSourceSnapshot = Just "install-preflight"
          }
      | Just loader <- [preflightResponseLoader response]
      ]
    shaderPackages =
      [ preflightShaderPackage minecraftVersion shader project
      | Just shader <- [preflightResponseShaderLoader response]
      , project <- stableTextSet (preflightResponseShaderProjects response)
      ]

preflightShaderPackage :: Text -> Text -> Text -> ResolvedPackage
preflightShaderPackage minecraftVersion shader project =
  ResolvedPackage
    { resolvedPackageId = project
    , resolvedPackageCoordinate =
        PackageCoordinate
          { coordinateSource = "modrinth"
          , coordinateProjectId = Just project
          , coordinateVersionId = Nothing
          , coordinateFileId = Nothing
          , coordinateSlug = Just project
          , coordinateName = Just project
          , coordinateKind = if project == shader then "shaderLoader" else "mod"
          }
    , resolvedPackageDisplayName = project
    , resolvedPackageVersionName = Nothing
    , resolvedPackageFileName = Nothing
    , resolvedPackageTargetPath = Nothing
    , resolvedPackageHashes = Map.empty
    , resolvedPackageSize = Nothing
    , resolvedPackageDownloadUrls = []
    , resolvedPackageGameVersions = [minecraftVersion]
    , resolvedPackageLoaders = []
    , resolvedPackageJavaMajor = Nothing
    , resolvedPackageSide = Just "client"
    , resolvedPackageSelectedBecause = ["install preflight"]
    , resolvedPackageLocked = False
    , resolvedPackagePinReason = Nothing
    , resolvedPackageDependencies =
        [ PackageConstraint
            { constraintId = shader <> "-requires-" <> project
            , constraintSourcePackage = Just shader
            , constraintTargetPackageId = Just project
            , constraintTargetKind = "mod"
            , constraintRelation = "requires"
            , constraintMinecraftVersions = [minecraftVersion]
            , constraintLoaders = []
            , constraintJavaMajor = Nothing
            , constraintSide = Just "client"
            , constraintRequired = True
            , constraintReason = shader <> " requires " <> project <> " according to install preflight."
            }
        | project /= shader
        ]
    , resolvedPackageConflicts = []
    , resolvedPackageSourceSnapshot = Just "install-preflight"
    }

requiredModrinthDependencies :: LockfileSolveRequest -> [OnlineDependency]
requiredModrinthDependencies request =
  stableSortPackages onlineDependencyKey $
    [ OnlineDependency
        { dependencyId =
            Text.intercalate
              ":"
              [ fromMaybe (constraintId constraint) (constraintTargetPackageId constraint)
              , "required"
              ]
        , dependencyProjectId = constraintTargetPackageId constraint
        , dependencyVersionId = Nothing
        , dependencySource = "modrinth"
        , dependencyRelation = "required"
        }
    | package <- solveRequestRoots request <> solveRequestManualPackages request
    , packageSource package == "modrinth"
    , resolvedPackageSourceSnapshot package /= Just "install-preflight"
    , constraint <- resolvedPackageDependencies package
    , normalizeRelation (constraintRelation constraint) == "requires"
    , constraintRequired constraint
    , isJust (constraintTargetPackageId constraint)
    ]

modrinthDependencyQuery :: LockfileSolveRequest -> ContentSearchRequest
modrinthDependencyQuery request =
  ContentSearchRequest
    { contentSearchSource = "modrinth"
    , contentSearchText = ""
    , contentSearchProjectTypes = ["mod"]
    , contentSearchCategories = []
    , contentSearchGameVersion = solveRequestMinecraftVersion request
    , contentSearchLoaders = maybe [] ((: []) . normalizeLoader) (solveRequestLoader request)
    , contentSearchSort = "downloads"
    , contentSearchOffset = 0
    , contentSearchLimit = 20
    , contentSearchCurseForgeApiKey = Nothing
    , contentSearchPrefetch = False
    }

onlineReleaseToPackage :: OnlineRelease -> ResolvedPackage
onlineReleaseToPackage release =
  ResolvedPackage
    { resolvedPackageId = releaseProjectId release
    , resolvedPackageCoordinate =
        PackageCoordinate
          { coordinateSource = normalizeSource (releaseSource release)
          , coordinateProjectId = Just (releaseProjectId release)
          , coordinateVersionId = Just (releaseId release)
          , coordinateFileId = fileId <$> selectedFile
          , coordinateSlug = Just (releaseProjectId release)
          , coordinateName = Just (releaseProjectId release)
          , coordinateKind = "mod"
          }
    , resolvedPackageDisplayName = releaseProjectId release
    , resolvedPackageVersionName = Just (releaseVersionName release)
    , resolvedPackageFileName = fileName <$> selectedFile
    , resolvedPackageTargetPath = (("mods" </>) . Text.unpack . fileName) <$> selectedFile
    , resolvedPackageHashes = maybe Map.empty fileHashes selectedFile
    , resolvedPackageSize = fileSizeBytes <$> selectedFile
    , resolvedPackageDownloadUrls = maybe [] (maybe [] (: []) . fileDownloadUrl) selectedFile
    , resolvedPackageGameVersions = stableTextSet (releaseGameVersions release)
    , resolvedPackageLoaders = stableTextSet (map normalizeLoader (releaseLoaders release))
    , resolvedPackageJavaMajor = Nothing
    , resolvedPackageSide = Just "client"
    , resolvedPackageSelectedBecause = [normalizeSource (releaseSource release) <> " release resolver"]
    , resolvedPackageLocked = False
    , resolvedPackagePinReason = Nothing
    , resolvedPackageDependencies = map (onlineDependencyToConstraint (releaseProjectId release)) (releaseDependencies release)
    , resolvedPackageConflicts = []
    , resolvedPackageSourceSnapshot = Just (normalizeSource (releaseSource release) <> ":" <> releaseId release)
    }
  where
    selectedFile = preferredOnlineFile (releaseFiles release)

onlineReleaseToPackageForRoot :: ResolvedPackage -> OnlineRelease -> ResolvedPackage
onlineReleaseToPackageForRoot root release =
  let package = onlineReleaseToPackage release
      coordinate = resolvedPackageCoordinate package
      rootCoordinate = resolvedPackageCoordinate root
      kind = normalizeKind (coordinateKind rootCoordinate)
      selectedFile = preferredOnlineFile (releaseFiles release)
   in package
        { resolvedPackageCoordinate =
            coordinate
              { coordinateSource = normalizeSource (coordinateSource rootCoordinate)
              , coordinateProjectId = coordinateProjectId rootCoordinate <|> coordinateProjectId coordinate
              , coordinateSlug = coordinateSlug rootCoordinate <|> coordinateSlug coordinate
              , coordinateName = coordinateName rootCoordinate <|> coordinateName coordinate
              , coordinateKind = kind
              }
        , resolvedPackageDisplayName =
            if Text.null (resolvedPackageDisplayName root)
              then resolvedPackageDisplayName package
              else resolvedPackageDisplayName root
        , resolvedPackageTargetPath = targetPathForOnlineFile kind <$> selectedFile
        , resolvedPackageSelectedBecause =
            stableTextSet (resolvedPackageSelectedBecause root <> ["online project resolver"])
        , resolvedPackageLocked = resolvedPackageLocked root
        , resolvedPackagePinReason = resolvedPackagePinReason root
        }

targetPathForOnlineFile :: Text -> OnlineFile -> FilePath
targetPathForOnlineFile kind file =
  targetDirectoryForKind kind </> Text.unpack (fileName file)

targetDirectoryForKind :: Text -> FilePath
targetDirectoryForKind kind =
  case normalizeKind kind of
    "resourcePack" -> "resourcepacks"
    "shaderPack" -> "shaderpacks"
    _ -> "mods"

onlineDependencyToConstraint :: Text -> OnlineDependency -> PackageConstraint
onlineDependencyToConstraint sourcePackage dependency =
  PackageConstraint
    { constraintId =
        Text.intercalate
          ":"
          [ sourcePackage
          , normalizeRelation (dependencyRelation dependency)
          , fromMaybe (dependencyId dependency) (dependencyProjectId dependency <|> dependencyVersionId dependency)
          ]
    , constraintSourcePackage = Just sourcePackage
    , constraintTargetPackageId = dependencyProjectId dependency <|> dependencyVersionId dependency
    , constraintTargetKind = "mod"
    , constraintRelation = normalizeRelation (dependencyRelation dependency)
    , constraintMinecraftVersions = []
    , constraintLoaders = []
    , constraintJavaMajor = Nothing
    , constraintSide = Just "client"
    , constraintRequired = Text.toLower (dependencyRelation dependency) == "required"
    , constraintReason = sourcePackage <> " " <> dependencyRelation dependency <> " " <> fromMaybe (dependencyId dependency) (dependencyProjectId dependency <|> dependencyVersionId dependency) <> " from " <> dependencySource dependency <> " metadata."
    }

preferredOnlineFile :: [OnlineFile] -> Maybe OnlineFile
preferredOnlineFile files =
  find filePrimary sortedFiles <|> listToMaybe sortedFiles
  where
    sortedFiles = stableSortPackages onlineFileKey files

onlineDependencyKey :: OnlineDependency -> Text
onlineDependencyKey dependency =
  Text.intercalate
    "|"
    [ dependencyId dependency
    , fromMaybe "" (dependencyProjectId dependency)
    , fromMaybe "" (dependencyVersionId dependency)
    , dependencySource dependency
    , dependencyRelation dependency
    ]

onlineFileKey :: OnlineFile -> Text
onlineFileKey file =
  Text.intercalate
    "|"
    [ fileId file
    , fileName file
    , fromMaybe "" (fileDownloadUrl file)
    ]

javaExecutableFromPolicy :: Maybe Value -> Maybe FilePath
javaExecutableFromPolicy (Just (Object obj)) =
  case lookupJavaValue "javaExecutable" obj <|> lookupJavaValue "customPath" obj <|> lookupJavaValue "java" obj <|> lookupJavaValue "path" obj of
    Just (String value) | not (Text.null value) -> Just (Text.unpack value)
    _ -> Nothing
javaExecutableFromPolicy _ =
  Nothing

javaResolveRequest :: LockfileSolveRequest -> Text -> JavaRuntimeResolveRequest
javaResolveRequest request minecraftVersion =
  JavaRuntimeResolveRequest
    { resolveMinecraftVersion = minecraftVersion
    , resolveGameDir = Just (solveRequestTargetGameDir request)
    , resolveInstanceId = javaPolicyText "instanceId" request
    , resolvePolicy = javaPolicyText "policy" request
    , resolvePreferredRuntimeId = javaPolicyText "preferredRuntimeId" request
    , resolveCustomPath =
        javaPolicyPath "customPath" request
          <|> javaPolicyPath "java" request
          <|> javaExecutableFromPolicy (solveRequestJavaPolicy request)
    }

javaPolicyText :: Text -> LockfileSolveRequest -> Maybe Text
javaPolicyText key request =
  case solveRequestJavaPolicy request of
    Just (Object obj) ->
      case lookupJavaValue key obj of
        Just (String value) | not (Text.null value) -> Just value
        _ -> Nothing
    _ -> Nothing

javaPolicyPath :: Text -> LockfileSolveRequest -> Maybe FilePath
javaPolicyPath key request =
  Text.unpack <$> javaPolicyText key request

javaRuntimeBlockedReasons :: JavaRuntimeResolveResponse -> [Text]
javaRuntimeBlockedReasons response
  | resolveResponseStatus response `elem` ["blocked", "missing", "incompatible"] =
      if null (resolveResponseBlockingReasons response)
        then ["java_runtime_unavailable:" <> Text.pack (show (resolveResponseRequiredMajorVersion response))]
        else resolveResponseBlockingReasons response
  | otherwise = []

javaRuntimePackage :: JavaRuntimeResolveResponse -> ResolvedPackage
javaRuntimePackage response =
  ResolvedPackage
    { resolvedPackageId = "java:" <> Text.pack (show (resolveResponseRequiredMajorVersion response))
    , resolvedPackageCoordinate =
        PackageCoordinate
          { coordinateSource = "javaRuntime"
          , coordinateProjectId = Just ("java-" <> Text.pack (show (resolveResponseRequiredMajorVersion response)))
          , coordinateVersionId = resolveResponseSelectedRuntimeId response <|> (Text.pack . show . runtimeDownloadFeatureVersion <$> resolveResponseDownload response)
          , coordinateFileId = runtimeDownloadArch <$> resolveResponseDownload response
          , coordinateSlug = Just ("java-" <> Text.pack (show (resolveResponseRequiredMajorVersion response)))
          , coordinateName = Just ("Java " <> Text.pack (show (resolveResponseRequiredMajorVersion response)))
          , coordinateKind = "javaRuntime"
          }
    , resolvedPackageDisplayName = "Java " <> Text.pack (show (resolveResponseRequiredMajorVersion response)) <> " runtime"
    , resolvedPackageVersionName = resolveResponseSelectedRuntimeId response
    , resolvedPackageFileName = Nothing
    , resolvedPackageTargetPath = Nothing
    , resolvedPackageHashes =
        maybe Map.empty
          (\download -> maybe Map.empty (\sha -> Map.singleton "sha256" sha) (runtimeDownloadSha256 download))
          (resolveResponseDownload response)
    , resolvedPackageSize = Nothing
    , resolvedPackageDownloadUrls = maybe [] ((: []) . runtimeDownloadUrl) (resolveResponseDownload response)
    , resolvedPackageGameVersions = [resolveResponseMinecraftVersion response]
    , resolvedPackageLoaders = []
    , resolvedPackageJavaMajor = Just (resolveResponseRequiredMajorVersion response)
    , resolvedPackageSide = Just "client"
    , resolvedPackageSelectedBecause = ["java runtime resolve:" <> resolveResponseStatus response]
    , resolvedPackageLocked = False
    , resolvedPackagePinReason = Nothing
    , resolvedPackageDependencies = []
    , resolvedPackageConflicts = []
    , resolvedPackageSourceSnapshot = Just ("java-runtime:" <> resolveResponseStatus response)
    }

javaRuntimePolicyValue :: JavaRuntimeResolveResponse -> IO Value
javaRuntimePolicyValue response = do
  executableSha1 <-
    case resolveResponseJavaExecutable response of
      Nothing -> pure Nothing
      Just path -> do
        exists <- doesFileExist path
        if exists
          then Just <$> sha1File path
          else pure Nothing
  pure $
    object
      [ "resolve" .= response
      , "path" .= resolveResponseJavaExecutable response
      , "executableSha1" .= executableSha1
      ]

lookupJavaValue :: Text -> KeyMap.KeyMap Value -> Maybe Value
lookupJavaValue key obj =
  KeyMap.lookup (Key.fromText key) obj
    <|> ( case KeyMap.lookup (Key.fromString "resolve") obj of
            Just (Object nested) -> KeyMap.lookup (Key.fromText key) nested
            _ -> Nothing
        )

javaMajorFromPolicy :: Maybe Value -> Maybe Int
javaMajorFromPolicy (Just (Object obj)) =
  valueToInt
    =<< ( lookupJavaValue "javaMajor" obj
            <|> lookupJavaValue "major" obj
            <|> lookupJavaValue "requiredMajorVersion" obj
        )
javaMajorFromPolicy _ =
  Nothing

valueToInt :: Value -> Maybe Int
valueToInt value =
  case fromJSON value :: Result Int of
    Success parsed -> Just parsed
    Error _ ->
      case value of
        String textValue -> readMaybe (Text.unpack textValue)
        _ -> Nothing

updateLockfileFingerprint :: PaninoLockfile -> PaninoLockfile
updateLockfileFingerprint lockfile =
  let staged = lockfile { lockfileFingerprint = "" }
   in staged { lockfileFingerprint = lockfileFingerprintFor staged }

firstJust :: [Maybe value] -> Maybe value
firstJust [] = Nothing
firstJust (Nothing:rest) = firstJust rest
firstJust (Just value:_) = Just value

lockfileApplyReadyLockfile :: LockfileApplyRequest -> Either Text PaninoLockfile
lockfileApplyReadyLockfile request =
  case solverResultLockfile (applyRequestResult request) of
    Nothing -> Left "lockfile_missing"
    Just lockfile
      | solverResultStatus (applyRequestResult request) /= "ready" -> Left "solver_blocked"
      | lockfileFingerprint lockfile /= applyRequestSolverFingerprint request -> Left "solver_fingerprint_mismatch"
      | otherwise -> Right lockfile

lockfileLaunchBlockedReasons :: LockfileVerifyResponse -> [Text]
lockfileLaunchBlockedReasons response =
  stableTextSet $
    map (verifyIssueBlockedReason "lockfile_missing_file") (verifyResponseMissingFiles response)
      <> map (verifyIssueBlockedReason "lockfile_hash_mismatch") (verifyResponseHashMismatches response)
      <> map (verifyIssueBlockedReason "lockfile_java_mismatch") (verifyResponseJavaMismatch response)
      <> map (verifyIssueBlockedReason "lockfile_loader_mismatch") (verifyResponseLoaderMismatch response)

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

data ResolveState = ResolveState
  { resolveSelected :: Map Text ResolvedPackage
  , resolveWarnings :: [Text]
  , resolveBlockedReasons :: [Text]
  , resolveRejected :: [LockfileExplainEntry]
  } deriving (Eq, Show)

emptyResolveState :: ResolveState
emptyResolveState =
  ResolveState Map.empty [] [] []

resolvePackageId :: LockfileSolveRequest -> Map Text ResolvedPackage -> ResolveState -> Text -> ResolveState
resolvePackageId request available state packageId =
  resolvePackageIdWithStack request available [] state packageId

resolvePackageIdWithStack :: LockfileSolveRequest -> Map Text ResolvedPackage -> [Text] -> ResolveState -> Text -> ResolveState
resolvePackageIdWithStack request available stack state packageId
  | packageId `elem` stack =
      state { resolveWarnings = ("solver_cycle_detected:" <> packageId) : resolveWarnings state }
  | Map.member packageId (resolveSelected state) = state
  | otherwise =
      case Map.lookup packageId available of
        Nothing ->
          state { resolveBlockedReasons = ("solver_no_candidate:" <> packageId) : resolveBlockedReasons state }
        Just package ->
          foldl'
            (resolveConstraint request available (packageId : stack))
            state { resolveSelected = Map.insert packageId package (resolveSelected state) }
            (packageAllConstraints package)

resolveConstraint :: LockfileSolveRequest -> Map Text ResolvedPackage -> [Text] -> ResolveState -> PackageConstraint -> ResolveState
resolveConstraint request available stack state constraint =
  case Text.toLower (constraintRelation constraint) of
    "requires" -> requireTarget
    "pins" -> requireTarget
    "optional"
      | optionalSelected constraint -> requireTarget
      | otherwise ->
          state { resolveRejected = constraintExplainEntry constraint : resolveRejected state }
    "incompatible" -> state
    "conflicts" -> state
    "embeds" -> state
    _ -> state
  where
    requireTarget =
      case constraintTargetPackageId constraint of
        Just targetId -> resolvePackageIdWithStack request available stack state targetId
        Nothing
          | constraintRequired constraint ->
              state { resolveBlockedReasons = ("required_dependency_unresolved:" <> constraintId constraint) : resolveBlockedReasons state }
          | otherwise -> state
    optionalSelected constraintValue =
      let targetId = fromMaybe "" (constraintTargetPackageId constraintValue)
          selected =
            solveRequestIncludeOptionalDependencies request
              || constraintId constraintValue `elem` selectedOptionalIds
              || targetId `elem` selectedOptionalIds
       in selected
            && constraintId constraintValue `notElem` ignoredDependencyIds
            && targetId `notElem` ignoredDependencyIds
    selectedOptionalIds =
      solveRequestSelectedOptionalDependencies request
    ignoredDependencyIds =
      solveRequestIgnoredDependencies request

normalizePackage :: FilePath -> Text -> ResolvedPackage -> ResolvedPackage
normalizePackage gameDir reason package =
  package
    { resolvedPackageCoordinate =
        coordinate
          { coordinateSource = normalizeSource (coordinateSource coordinate)
          , coordinateKind = normalizeKind (coordinateKind coordinate)
          }
    , resolvedPackageTargetPath = normalizeTargetPath gameDir <$> resolvedPackageTargetPath package
    , resolvedPackageDownloadUrls = stableTextSet (resolvedPackageDownloadUrls package)
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
    "keepLocked" -> True
    "repair" -> True
    "launchVerify" -> True
    "syncRoom" -> True
    "updateSelected" -> resolvedPackageId package `notElem` selectedUpdateIds
    _ -> False

selectedUpdatePackageIds :: LockfileSolveRequest -> [ResolvedPackage] -> [Text]
selectedUpdatePackageIds request roots
  | solveRequestUpdatePolicy request == "updateSelected" =
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
normalizeSource source =
  case Text.toLower source of
    "modrinth" -> "modrinth"
    "curseforge" -> "curseforge"
    "curse-forge" -> "curseforge"
    "loader_meta" -> "loaderMeta"
    "loadermeta" -> "loaderMeta"
    "java_runtime" -> "javaRuntime"
    "javaruntime" -> "javaRuntime"
    "local" -> "local"
    "manual" -> "manual"
    "mojang" -> "mojang"
    "panino" -> "panino"
    other -> other

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

normalizeTargetPath :: FilePath -> FilePath -> FilePath
normalizeTargetPath gameDir targetPath
  | isRelative normalized = normalized
  | otherwise = normalise (makeRelative gameDir normalized)
  where
    normalized = normalise targetPath

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
      sum [ 100 | solveRequestUpdatePolicy request == "updateAllSafe" && packageCompatibleWithRequest request value ]

packageResolutionScore :: ResolvedPackage -> Int
packageResolutionScore package =
  sum
    [ 4 | isJust (coordinateVersionId (resolvedPackageCoordinate package)) ]
    + sum [ 4 | isJust (resolvedPackageTargetPath package) ]
    + sum [ 3 | Map.member "sha1" (resolvedPackageHashes package) ]
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
        (solveRequestMinecraftVersion request)
    loaderCompatible =
      maybe
        True
        (\loader -> null (resolvedPackageLoaders package) || normalizeLoader loader `elem` resolvedPackageLoaders package)
        (solveRequestLoader request)
    javaCompatible =
      case (javaMajorFromPolicy (solveRequestJavaPolicy request), resolvedPackageJavaMajor package) of
        (Just selectedMajor, Just requiredMajor) -> selectedMajor >= requiredMajor
        _ -> True

detectConflicts :: LockfileSolveRequest -> [ResolvedPackage] -> [PackageConstraint] -> [SolverConflict]
detectConflicts request packages constraints =
  stableSortPackages solverConflictId $
    pathHashConflicts packages
      <> projectReleaseConflicts packages
      <> duplicateModConflicts packages
      <> compatibilityConflicts request packages
      <> dependencyConflicts packages constraints
      <> targetDirectoryConflicts packages

detectPackageBlockedReasons :: [ResolvedPackage] -> [Text]
detectPackageBlockedReasons packages =
  concatMap packageBlocked packages
  where
    packageBlocked package =
      let source = coordinateSource (resolvedPackageCoordinate package)
          hasTarget = isJust (resolvedPackageTargetPath package)
          hasSha1 = Map.member "sha1" (resolvedPackageHashes package)
          hasUrl = not (null (resolvedPackageDownloadUrls package))
          manualSource = source `elem` ["manual", "local"]
       in [ "unsafe_target_path:" <> resolvedPackageId package
          | maybe False (not . targetPathSafe) (resolvedPackageTargetPath package)
          ]
            <> [ "solver_source_unavailable:" <> resolvedPackageId package
               | hasTarget && not manualSource && not hasUrl
               ]
            <> [ "solver_hash_missing:" <> resolvedPackageId package
               | hasTarget && hasUrl && not hasSha1
               ]

pathHashConflicts :: [ResolvedPackage] -> [SolverConflict]
pathHashConflicts packages =
  [ solverConflict
      "solver_conflict"
      ("path-hash-" <> Text.pack (show index))
      "Target path conflict"
      ("Different hashes are locked for " <> Text.pack targetPath)
      (map resolvedPackageId grouped)
      [targetPath]
  | (index, grouped) <- zip [(1 :: Int)..] (groupOn (fromMaybe "" . resolvedPackageTargetPath) packages)
  , let targetPath = fromMaybe "" (resolvedPackageTargetPath (head grouped))
  , not (null targetPath)
  , distinctSha1 grouped > 1
  ]

projectReleaseConflicts :: [ResolvedPackage] -> [SolverConflict]
projectReleaseConflicts packages =
  [ solverConflict
      "solver_conflict"
      ("project-release-" <> Text.pack (show index))
      "Project version conflict"
      ("Multiple releases are selected for project " <> projectKey)
      (map resolvedPackageId grouped)
      (mapMaybe resolvedPackageTargetPath grouped)
  | (index, grouped) <- zip [(1 :: Int)..] (groupOn projectKeyFor packages)
  , let projectKey = projectKeyFor (head grouped)
  , not (Text.null projectKey)
  , length (stableTextSet (mapMaybe (coordinateVersionId . resolvedPackageCoordinate) grouped)) > 1
  ]

duplicateModConflicts :: [ResolvedPackage] -> [SolverConflict]
duplicateModConflicts packages =
  [ solverConflict
      "solver_duplicate_mod_id"
      ("duplicate-mod-" <> Text.pack (show index))
      "Duplicate mod"
      ("Multiple jars appear to provide " <> modKey)
      (map resolvedPackageId grouped)
      (mapMaybe resolvedPackageTargetPath grouped)
  | (index, grouped) <- zip [(1 :: Int)..] (groupOn modKeyFor (filter ((== "mod") . coordinateKind . resolvedPackageCoordinate) packages))
  , let modKey = modKeyFor (head grouped)
  , not (Text.null modKey)
  , length grouped > 1
  ]

compatibilityConflicts :: LockfileSolveRequest -> [ResolvedPackage] -> [SolverConflict]
compatibilityConflicts request packages =
  concatMap packageCompatibility packages
  where
    packageCompatibility package =
      [ solverConflict
          "solver_no_candidate"
          ("minecraft-version-" <> resolvedPackageId package)
          "Minecraft version mismatch"
          (resolvedPackageDisplayName package <> " does not support Minecraft " <> minecraftVersion)
          [resolvedPackageId package]
          (maybe [] (: []) (resolvedPackageTargetPath package))
      | Just minecraftVersion <- [solveRequestMinecraftVersion request]
      , not (null (resolvedPackageGameVersions package))
      , minecraftVersion `notElem` resolvedPackageGameVersions package
      ]
        <> [ solverConflict
              "solver_no_candidate"
              ("loader-" <> resolvedPackageId package)
              "Loader mismatch"
              (resolvedPackageDisplayName package <> " does not support loader " <> loader)
              [resolvedPackageId package]
              (maybe [] (: []) (resolvedPackageTargetPath package))
           | Just loader <- [normalizeLoader <$> solveRequestLoader request]
           , not (null (resolvedPackageLoaders package))
           , loader `notElem` resolvedPackageLoaders package
           ]
        <> [ solverConflict
              "solver_no_candidate"
              ("java-major-" <> resolvedPackageId package)
              "Java version mismatch"
              (resolvedPackageDisplayName package <> " requires Java " <> Text.pack (show requiredMajor) <> ", but the solve request is fixed to Java " <> Text.pack (show selectedMajor))
              [resolvedPackageId package]
              (maybe [] (: []) (resolvedPackageTargetPath package))
           | Just selectedMajor <- [javaMajorFromPolicy (solveRequestJavaPolicy request)]
           , Just requiredMajor <- [resolvedPackageJavaMajor package]
           , selectedMajor < requiredMajor
           ]

dependencyConflicts :: [ResolvedPackage] -> [PackageConstraint] -> [SolverConflict]
dependencyConflicts packages constraints =
  [ solverConflict
      "solver_conflict"
      ("incompatible-" <> constraintId constraint)
      "Incompatible dependency"
      (constraintReason constraint)
      (catMaybes [constraintSourcePackage constraint, constraintTargetPackageId constraint])
      []
  | constraint <- constraints
  , constraintRelation constraint `elem` ["incompatible", "conflicts"]
  , maybe False (`elem` selectedIds) (constraintSourcePackage constraint)
  , maybe False (`elem` selectedIds) (constraintTargetPackageId constraint)
  ]
  where
    selectedIds = map resolvedPackageId packages

targetDirectoryConflicts :: [ResolvedPackage] -> [SolverConflict]
targetDirectoryConflicts packages =
  concatMap checkPackage packages
  where
    checkPackage package =
      case resolvedPackageTargetPath package of
        Nothing -> []
        Just targetPath
          | coordinateKind (resolvedPackageCoordinate package) == "resourcePack" && not ("resourcepacks/" `isPrefixPath` targetPath) ->
              [wrongDir package "resourcepacks"]
          | coordinateKind (resolvedPackageCoordinate package) == "shaderPack" && not ("shaderpacks/" `isPrefixPath` targetPath) ->
              [wrongDir package "shaderpacks"]
          | coordinateKind (resolvedPackageCoordinate package) == "mod" && not ("mods/" `isPrefixPath` targetPath) ->
              [wrongDir package "mods"]
          | otherwise -> []
    wrongDir package expected =
      solverConflict
        "solver_conflict"
        ("target-dir-" <> resolvedPackageId package)
        "Target directory mismatch"
        (resolvedPackageDisplayName package <> " must be installed under " <> expected)
        [resolvedPackageId package]
        (maybe [] (: []) (resolvedPackageTargetPath package))

solverConflict :: Text -> Text -> Text -> Text -> [Text] -> [FilePath] -> SolverConflict
solverConflict code conflictId title message packageIds filePaths =
  SolverConflict
    { solverConflictId = conflictId
    , solverConflictCode = code
    , solverConflictTitle = title
    , solverConflictMessage = message
    , solverConflictPackageIds = stableTextSet packageIds
    , solverConflictFilePaths = map Text.unpack (stableTextSet (map Text.pack filePaths))
    , solverConflictDiagnostic = Just (diagnosticFromBlockedReason "solve" "lockfile solver" (code <> ":" <> message))
    }

conflictBlockedReason :: SolverConflict -> Text
conflictBlockedReason conflict =
  solverConflictCode conflict <> ":" <> solverConflictId conflict

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

packageSource :: ResolvedPackage -> Text
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

distinctSha1 :: [ResolvedPackage] -> Int
distinctSha1 =
  length . stableTextSet . mapMaybe (Map.lookup "sha1" . resolvedPackageHashes)

projectKeyFor :: ResolvedPackage -> Text
projectKeyFor package =
  Text.intercalate
    ":"
    [ coordinateSource (resolvedPackageCoordinate package)
    , fromMaybe "" (coordinateProjectId (resolvedPackageCoordinate package))
    ]

modKeyFor :: ResolvedPackage -> Text
modKeyFor package =
  Text.toLower $
    fromMaybe
      (resolvedPackageDisplayName package)
      (coordinateSlug (resolvedPackageCoordinate package))

groupOn :: Ord key => (value -> key) -> [value] -> [[value]]
groupOn selector =
  filter (not . null) . groupBy (\left right -> selector left == selector right) . sortOn selector

isPrefixPath :: FilePath -> FilePath -> Bool
isPrefixPath prefix path =
  Text.pack prefix `Text.isPrefixOf` Text.pack (normalise path)
