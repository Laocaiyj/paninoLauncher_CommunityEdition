{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Lockfile.Services.Online
  ( curseForgeDependencyServiceEvidence
  , modrinthDependencyServiceEvidence
  , onlineRootServiceEvidence
  ) where

import Control.Applicative ((<|>))
import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import Data.List (find)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( catMaybes
  , fromMaybe
  , isJust
  , listToMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
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
  , onlineDependencyProjectIdText
  , onlineDependencyVersionIdText
  , onlineFileDownloadUrlText
  , onlineReleaseIdText
  , onlineReleaseProjectIdText
  )
import Panino.CoreLogic.Determinism
  ( stableSortPackages
  , stableTextSet
  )
import Panino.Core.Types
  ( RelativePath
  , projectIdFromText
  , projectIdText
  , relativePathFromFilePath
  )
import Panino.Lockfile.Normalize
  ( dedupePackages
  , normalizeKind
  , normalizeLoader
  , normalizeRelation
  , normalizeSource
  , packageSource
  )
import Panino.Lockfile.Services.Evidence
  ( ServiceEvidence(..)
  , emptyServiceEvidence
  , mergeServiceEvidence
  , serviceBlocked
  )
import Panino.Lockfile.Types
  ( LockfileSolveRequest(..)
  , PackageConstraint(..)
  , PackageCoordinate(..)
  , PackageSource(..)
  , ResolvedPackage(..)
  , coordinateProjectIdText
  , normalizePackageSource
  , packageSourceFromText
  , packageSourceIsOnline
  , resolvedPackageKey
  , solveRequestMinecraftVersionText
  )
import System.FilePath ((</>))

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
  packageSourceIsOnline (packageSource package)
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
        case normalizePackageSource (packageSource package) of
          PackageSourceModrinth -> modrinthProject manager (projectRequest "modrinth" projectIdValue)
          PackageSourceCurseForge -> curseForgeProject manager (projectRequest "curseForge" projectIdValue)
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
  coordinateProjectIdText coordinate
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
              let projectIdTextValue = projectIdText projectIdValue
              response <-
                curseForgeProject
                  manager
                  ContentProjectRequest
                    { contentProjectSource = "curseForge"
                    , contentProjectId = projectIdTextValue
                    , contentProjectQuery = onlineContentQuery "curseForge" "mod" request
                    , contentProjectCurseForgeApiKey = solveRequestCurseForgeApiKey request
                    }
              release <-
                case preferredContentRelease response of
                  Just value -> pure value
                  Nothing -> fail ("no compatible CurseForge dependency release found for " <> Text.unpack projectIdTextValue)
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
          >>= projectIdFromText
      , dependencyVersionId = Nothing
      , dependencySource = "curseForge"
      , dependencyRelation = "required"
      }
  | normalizePackageSource (packageSource package) == PackageSourceCurseForge
  , constraint <- resolvedPackageDependencies package
  , normalizeRelation (constraintRelation constraint) == "requires"
  , constraintRequired constraint
  , isJust (constraintTargetPackageId constraint)
  ]

dependencyVisitKeysLocal :: OnlineDependency -> [Text]
dependencyVisitKeysLocal dependency =
  catMaybes
    [ Just (dependencyId dependency)
    , onlineDependencyProjectIdText dependency
    , onlineDependencyVersionIdText dependency
    ]

onlineContentQuery :: Text -> Text -> LockfileSolveRequest -> ContentSearchRequest
onlineContentQuery source kind request =
  ContentSearchRequest
    { contentSearchSource = source
    , contentSearchText = ""
    , contentSearchProjectTypes = [projectTypeForKind kind]
    , contentSearchCategories = []
    , contentSearchGameVersion = solveRequestMinecraftVersionText request
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
            >>= projectIdFromText
        , dependencyVersionId = Nothing
        , dependencySource = "modrinth"
        , dependencyRelation = "required"
        }
    | package <- solveRequestRoots request <> solveRequestManualPackages request
    , normalizePackageSource (packageSource package) == PackageSourceModrinth
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
    , contentSearchGameVersion = solveRequestMinecraftVersionText request
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
    { resolvedPackageId = releaseProjectIdValue
    , resolvedPackageCoordinate =
        PackageCoordinate
          { coordinateSource = packageSourceFromText (releaseSource release)
          , coordinateProjectId = Just (releaseProjectId release)
          , coordinateVersionId = Just (releaseId release)
          , coordinateFileId = fileId <$> selectedFile
          , coordinateSlug = Just releaseProjectIdValue
          , coordinateName = Just releaseProjectIdValue
          , coordinateKind = "mod"
          }
    , resolvedPackageDisplayName = releaseProjectIdValue
    , resolvedPackageVersionName = Just (releaseVersionName release)
    , resolvedPackageFileName = fileName <$> selectedFile
    , resolvedPackageTargetPath = selectedFile >>= targetPathForOnlineFile "mod"
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
    , resolvedPackageDependencies = map (onlineDependencyToConstraint releaseProjectIdValue) (releaseDependencies release)
    , resolvedPackageConflicts = []
    , resolvedPackageSourceSnapshot = Just (normalizeSource (releaseSource release) <> ":" <> releaseIdValue)
    }
  where
    selectedFile = preferredOnlineFile (releaseFiles release)
    releaseProjectIdValue = onlineReleaseProjectIdText release
    releaseIdValue = onlineReleaseIdText release

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
              { coordinateSource = normalizePackageSource (coordinateSource rootCoordinate)
              , coordinateProjectId = coordinateProjectId rootCoordinate <|> coordinateProjectId coordinate
              , coordinateSlug = coordinateSlug rootCoordinate <|> coordinateSlug coordinate
              , coordinateName = coordinateName rootCoordinate <|> coordinateName coordinate
              , coordinateKind = kind
              }
        , resolvedPackageDisplayName =
            if Text.null (resolvedPackageDisplayName root)
              then resolvedPackageDisplayName package
              else resolvedPackageDisplayName root
        , resolvedPackageTargetPath = selectedFile >>= targetPathForOnlineFile kind
        , resolvedPackageSelectedBecause =
            stableTextSet (resolvedPackageSelectedBecause root <> ["online project resolver"])
        , resolvedPackageLocked = resolvedPackageLocked root
        , resolvedPackagePinReason = resolvedPackagePinReason root
        }

targetPathForOnlineFile :: Text -> OnlineFile -> Maybe RelativePath
targetPathForOnlineFile kind file =
  relativePathFromFilePath (targetDirectoryForKind kind </> Text.unpack (fileName file))

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
          , fromMaybe (dependencyId dependency) (dependencyTargetIdText dependency)
          ]
    , constraintSourcePackage = Just sourcePackage
    , constraintTargetPackageId = dependencyTargetIdText dependency
    , constraintTargetKind = "mod"
    , constraintRelation = normalizeRelation (dependencyRelation dependency)
    , constraintMinecraftVersions = []
    , constraintLoaders = []
    , constraintJavaMajor = Nothing
    , constraintSide = Just "client"
    , constraintRequired = Text.toLower (dependencyRelation dependency) == "required"
    , constraintReason = sourcePackage <> " " <> dependencyRelation dependency <> " " <> fromMaybe (dependencyId dependency) (dependencyTargetIdText dependency) <> " from " <> dependencySource dependency <> " metadata."
    }

dependencyTargetIdText :: OnlineDependency -> Maybe Text
dependencyTargetIdText dependency =
  onlineDependencyProjectIdText dependency <|> onlineDependencyVersionIdText dependency

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
    , fromMaybe "" (onlineDependencyProjectIdText dependency)
    , fromMaybe "" (onlineDependencyVersionIdText dependency)
    , dependencySource dependency
    , dependencyRelation dependency
    ]

onlineFileKey :: OnlineFile -> Text
onlineFileKey file =
  Text.intercalate
    "|"
    [ fileId file
    , fileName file
    , fromMaybe "" (onlineFileDownloadUrlText file)
    ]
