{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Lockfile.Services.Preflight
  ( modpackSourceServiceEvidence
  , performancePackServiceEvidence
  , preflightServiceEvidence
  ) where

import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import Data.Aeson
  ( object
  , (.=)
  )
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Configuration.Preflight
  ( modpackPreflight
  )
import Panino.Content.Configuration.Types
  ( ModpackPreflightRequest(..)
  , ModpackPreflightResponse(..)
  )
import Panino.CoreLogic.Determinism
  ( stableFingerprint
  , stableSortPackages
  , stableTextSet
  )
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import qualified Panino.Install.Plan.Types as Plan
import Panino.Lockfile.Normalize
  ( normalizeKind
  , normalizeLoader
  , normalizeSource
  )
import Panino.Lockfile.Services.Evidence
  ( ServiceEvidence(..)
  , emptyServiceEvidence
  , serviceBlocked
  )
import Panino.Lockfile.Services.Java
  ( javaExecutableFromPolicy
  )
import Panino.Lockfile.Types
  ( LockfileSolveRequest(..)
  , PackageConstraint(..)
  , PackageCoordinate(..)
  , ResolvedPackage(..)
  , resolvedPackageKey
  )
import Panino.Minecraft.InstallPreflight
  ( LoaderInstallPreflightRequest(..)
  , LoaderInstallPreflightResponse(..)
  , loaderInstallPreflight
  )
import Panino.Performance.Pack
  ( PerformanceModEntry(..)
  , PerformancePackRecommendation(..)
  , performanceModFileNames
  , recommendPerformancePack
  )
import System.FilePath
  ( takeFileName
  )

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
