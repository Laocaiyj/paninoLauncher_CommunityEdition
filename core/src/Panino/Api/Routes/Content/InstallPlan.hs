{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Content.InstallPlan
  ( ContentInstallPlanBundle(..)
  , buildContentInstallPlan
  , buildContentInstallPlanBundle
  , contentTypedInstallPlan
  ) where

import Control.Applicative ((<|>))
import Control.Exception (SomeException, try)
import Data.List (find, foldl')
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, listToMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Routes.Content.Common
import Panino.Api.Routes.Content.InstallPlan.Typed (contentTypedInstallPlan)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
import Panino.Content.Online.Modrinth (modrinthRequiredDependencyReleases)
import Panino.Content.Online.Types (ContentSearchRequest(..), OnlineDependency(..), OnlineFile(..), OnlineRelease(..))
import Panino.Download.Manager (sha1HexFile)
import qualified Panino.Install.Plan.Types as Plan
import System.Directory (doesDirectoryExist, doesFileExist)
import System.FilePath (takeExtension, (</>))

data ContentInstallPlanBundle = ContentInstallPlanBundle
  { contentPlanBundleResponse :: ContentInstallPlanResponse
  , contentPlanBundleFiles :: [ContentInstallFile]
  } deriving (Eq, Show)

data ContentDependencyExpansion = ContentDependencyExpansion
  { dependencyExpansionFiles :: [ContentInstallFile]
  , dependencyExpansionDependencies :: [ContentInstallDependency]
  , dependencyExpansionWarnings :: [Text]
  , dependencyExpansionBlockedReasons :: [Text]
  } deriving (Eq, Show)

buildContentInstallPlan :: ServerState -> ContentInstallRequest -> IO ContentInstallPlanResponse
buildContentInstallPlan state request =
  contentPlanBundleResponse <$> buildContentInstallPlanBundle state request

buildContentInstallPlanBundle :: ServerState -> ContentInstallRequest -> IO ContentInstallPlanBundle
buildContentInstallPlanBundle state request = do
  directoryPreflight <- contentInstallDirectoryPreflight request
  let targetSubdir = Text.unpack (contentInstallTargetSubdir request)
      targetDir = maybe "" (</> targetSubdir) (contentInstallGameDir request)
  initiallyResolvedDependencies <- resolveInstallDependencies targetDir (contentInstallDependencies request)
  dependencyExpansion <- expandContentInstallDependencies state request targetDir initiallyResolvedDependencies
  let files = dedupeContentFiles (contentInstallFiles request <> dependencyExpansionFiles dependencyExpansion)
  plannedFiles <- traverse (planContentFile targetDir) files
  resolvedDependencies <- resolveInstallDependencies targetDir (dependencyExpansionDependencies dependencyExpansion)
  let replacingFiles = filter ((== "replace") . contentPlanFileAction) plannedFiles
      keepingFiles = filter ((== "keep") . contentPlanFileAction) plannedFiles
      rawBlockedReasons =
        concat
          [ directoryPreflightBlocked directoryPreflight
          , dependencyExpansionBlockedReasons dependencyExpansion
          , ["target_subdir_not_allowed" | targetSubdir `notElem` allowedContentSubdirs]
          , ["no_files_to_install" | null files]
          , ["file_url_not_http" | any (not . isAllowedContentUrl . contentFileUrl) files]
          , ["missing_required_dependencies" | any missingRequiredDependency resolvedDependencies]
          , ["curseforge_required_dependency_unresolved" | isCurseForgeRequest request && any unresolvedRequiredDependency resolvedDependencies]
          ]
      warnings =
        concat
          [ directoryPreflightWarnings directoryPreflight
          , dependencyExpansionWarnings dependencyExpansion
          , ["file_without_sha1" | any ((== Nothing) . contentFileSha1) files]
          , ["file_without_size" | any ((== Nothing) . contentFileSize) files]
          , ["same_name_file_will_be_replaced" | not (null replacingFiles)]
          , ["matching_file_already_present" | not (null keepingFiles)]
          , ["required_dependencies_need_review" | any unresolvedRequiredDependency resolvedDependencies]
          , ["optional_dependencies_not_found" | any unresolvedOptionalDependency resolvedDependencies]
          ]
      totalSize = sumMaybe (map contentFileSize files)
      typedPlan =
        contentTypedInstallPlan
          request
          targetDir
          files
          plannedFiles
          resolvedDependencies
          warnings
          rawBlockedReasons
      blockedReasons = Plan.typedPlanBlockedReasons typedPlan
      response =
        ContentInstallPlanResponse
          { contentPlanAction = if null blockedReasons then "install" else "blocked"
          , contentPlanSource = contentInstallSource request
          , contentPlanProjectId = contentInstallProjectId request
          , contentPlanProjectTitle = contentInstallProjectTitle request
          , contentPlanReleaseId = contentInstallReleaseId request
          , contentPlanTargetDir = targetDir
          , contentPlanFiles = plannedFiles
          , contentPlanDependencies = resolvedDependencies
          , contentPlanWarnings = warnings
          , contentPlanBlockedReasons = blockedReasons
          , contentPlanTotalSize = totalSize
          , contentPlanTypedPlan = typedPlan
          }
  pure
    ContentInstallPlanBundle
      { contentPlanBundleResponse = response
      , contentPlanBundleFiles = files
      }

expandContentInstallDependencies :: ServerState -> ContentInstallRequest -> FilePath -> [ContentInstallDependency] -> IO ContentDependencyExpansion
expandContentInstallDependencies state request targetDir dependencies
  | normalizeLoader (contentInstallSource request) /= "modrinth" =
      pure (baseDependencyExpansion dependencies)
  | otherwise = do
      resolvedCompanionDependencies <- resolveInstallDependencies targetDir (fabricApiCompanionDependencies request)
      let installDependencies =
            dedupeContentDependencies (dependencies <> resolvedCompanionDependencies)
          dependenciesToResolve =
            filter shouldDownloadDependency installDependencies
      if null dependenciesToResolve
        then pure (baseDependencyExpansion installDependencies)
        else resolveModrinthDependencies installDependencies dependenciesToResolve
  where
    resolveModrinthDependencies installDependencies dependenciesToResolve = do
      result <-
        try
          ( modrinthRequiredDependencyReleases
              (stateHttpManager state)
              (contentInstallDependencyQuery request)
              (map (contentDependencyToOnlineDependency request) dependenciesToResolve)
          )
      case result of
        Right releases -> do
          let files = mapMaybe contentInstallFileFromRelease releases
              resolvedDependencies =
                markResolvedContentDependencies releases installDependencies
              releaseDependencyEntries =
                mapMaybe contentInstallDependencyFromRelease releases
              blockedReasons =
                ["required_dependency_download_missing" | any releaseMissingDownload releases]
          pure
            ContentDependencyExpansion
              { dependencyExpansionFiles = files
              , dependencyExpansionDependencies = dedupeContentDependencies (resolvedDependencies <> releaseDependencyEntries)
              , dependencyExpansionWarnings = []
              , dependencyExpansionBlockedReasons = blockedReasons
              }
        Left (_ :: SomeException) ->
          pure
            ContentDependencyExpansion
              { dependencyExpansionFiles = []
              , dependencyExpansionDependencies = installDependencies
              , dependencyExpansionWarnings = ["required_dependency_resolution_failed"]
              , dependencyExpansionBlockedReasons = ["required_dependency_resolution_failed"]
              }

    shouldDownloadDependency dependency =
      contentDependencyRequired dependency
        && contentDependencyInstalled dependency /= Just True
        && normalizeLoader (fromMaybe (contentInstallSource request) (contentDependencySource dependency)) == "modrinth"

fabricApiCompanionDependencies :: ContentInstallRequest -> [ContentInstallDependency]
fabricApiCompanionDependencies request
  | shouldInstallFabricApiCompanion request =
      [ ContentInstallDependency
          { contentDependencyProjectId = Just "fabric-api"
          , contentDependencyVersionId = Nothing
          , contentDependencySource = Just "modrinth"
          , contentDependencyName = "Fabric API"
          , contentDependencyRequired = True
          , contentDependencyInstalled = Nothing
          , contentDependencySha1 = Nothing
          }
      ]
  | otherwise = []

shouldInstallFabricApiCompanion :: ContentInstallRequest -> Bool
shouldInstallFabricApiCompanion request =
  Text.unpack (contentInstallTargetSubdir request) == "mods"
    && any ((== "fabric") . normalizeLoader) (contentInstallLoaders request)
    && not (isFabricApiContentRequest request)

isFabricApiContentRequest :: ContentInstallRequest -> Bool
isFabricApiContentRequest request =
  any
    ((== "fabricapi") . normalizeLookupText)
    [ contentInstallProjectTitle request
    , fromMaybe "" (contentInstallProjectId request)
    ]

baseDependencyExpansion :: [ContentInstallDependency] -> ContentDependencyExpansion
baseDependencyExpansion dependencies =
  ContentDependencyExpansion
    { dependencyExpansionFiles = []
    , dependencyExpansionDependencies = dependencies
    , dependencyExpansionWarnings = []
    , dependencyExpansionBlockedReasons = []
    }

contentInstallDependencyQuery :: ContentInstallRequest -> ContentSearchRequest
contentInstallDependencyQuery request =
  ContentSearchRequest
    { contentSearchSource = "modrinth"
    , contentSearchText = ""
    , contentSearchProjectTypes = [fromMaybe "mod" (contentInstallProjectType request)]
    , contentSearchCategories = []
    , contentSearchGameVersion = listToMaybe (contentInstallGameVersions request)
    , contentSearchLoaders = contentInstallLoaders request
    , contentSearchSort = "downloads"
    , contentSearchOffset = 0
    , contentSearchLimit = 20
    , contentSearchCurseForgeApiKey = Nothing
    , contentSearchPrefetch = False
    }

contentDependencyToOnlineDependency :: ContentInstallRequest -> ContentInstallDependency -> OnlineDependency
contentDependencyToOnlineDependency request dependency =
  OnlineDependency
    { dependencyId =
        Text.intercalate
          ":"
          [ fromMaybe "" (contentDependencyProjectId dependency)
          , fromMaybe "" (contentDependencyVersionId dependency)
          , contentDependencyName dependency
          ]
    , dependencyProjectId = contentDependencyProjectId dependency
    , dependencyVersionId = contentDependencyVersionId dependency
    , dependencySource = fromMaybe (contentInstallSource request) (contentDependencySource dependency)
    , dependencyRelation = if contentDependencyRequired dependency then "required" else "optional"
    }

contentInstallFileFromRelease :: OnlineRelease -> Maybe ContentInstallFile
contentInstallFileFromRelease release =
  onlineFileToContentInstallFile <$> preferredOnlineFile (releaseFiles release)

onlineFileToContentInstallFile :: OnlineFile -> ContentInstallFile
onlineFileToContentInstallFile file =
  ContentInstallFile
    { contentFileName = fileName file
    , contentFileUrl = fromMaybe "" (fileDownloadUrl file)
    , contentFileSha1 = Map.lookup "sha1" (fileHashes file)
    , contentFileSize = Just (fileSizeBytes file)
    , contentFilePrimary = Just (filePrimary file)
    }

contentInstallDependencyFromRelease :: OnlineRelease -> Maybe ContentInstallDependency
contentInstallDependencyFromRelease release = do
  file <- preferredOnlineFile (releaseFiles release)
  pure
    ContentInstallDependency
      { contentDependencyProjectId = Just (releaseProjectId release)
      , contentDependencyVersionId = Just (releaseId release)
      , contentDependencySource = Just (releaseSource release)
      , contentDependencyName = releaseVersionName release
      , contentDependencyRequired = True
      , contentDependencyInstalled = Just True
      , contentDependencySha1 = Map.lookup "sha1" (fileHashes file)
      }

preferredOnlineFile :: [OnlineFile] -> Maybe OnlineFile
preferredOnlineFile files =
  find filePrimary files <|> listToMaybe files

releaseMissingDownload :: OnlineRelease -> Bool
releaseMissingDownload release =
  case preferredOnlineFile (releaseFiles release) of
    Nothing -> True
    Just file -> maybe True Text.null (fileDownloadUrl file)

markResolvedContentDependencies :: [OnlineRelease] -> [ContentInstallDependency] -> [ContentInstallDependency]
markResolvedContentDependencies releases =
  map markResolved
  where
    markResolved dependency =
      case find (dependencyMatchesRelease dependency) releases of
        Nothing -> dependency
        Just release ->
          dependency
            { contentDependencyInstalled = Just True
            , contentDependencyVersionId = contentDependencyVersionId dependency <|> Just (releaseId release)
            , contentDependencySource = contentDependencySource dependency <|> Just (releaseSource release)
            , contentDependencySha1 = contentDependencySha1 dependency <|> releaseSha1 release
            }

releaseSha1 :: OnlineRelease -> Maybe Text
releaseSha1 release =
  preferredOnlineFile (releaseFiles release) >>= Map.lookup "sha1" . fileHashes

dependencyMatchesRelease :: ContentInstallDependency -> OnlineRelease -> Bool
dependencyMatchesRelease dependency release =
  maybe False (== releaseId release) (contentDependencyVersionId dependency)
    || maybe False (== releaseProjectId release) (contentDependencyProjectId dependency)

dedupeContentFiles :: [ContentInstallFile] -> [ContentInstallFile]
dedupeContentFiles =
  foldl' insertFile []
  where
    insertFile files file
      | any ((== contentFileKey file) . contentFileKey) files = files
      | otherwise = files <> [file]

dedupeContentDependencies :: [ContentInstallDependency] -> [ContentInstallDependency]
dedupeContentDependencies =
  foldl' insertDependency []
  where
    insertDependency dependencies dependency
      | any ((== contentDependencyKey dependency) . contentDependencyKey) dependencies = dependencies
      | otherwise = dependencies <> [dependency]

data ContentInstallDirectoryPreflight = ContentInstallDirectoryPreflight
  { directoryPreflightBlocked :: [Text]
  , directoryPreflightWarnings :: [Text]
  } deriving (Eq, Show)

contentInstallDirectoryPreflight :: ContentInstallRequest -> IO ContentInstallDirectoryPreflight
contentInstallDirectoryPreflight request =
  case contentInstallGameDir request of
    Nothing ->
      pure (ContentInstallDirectoryPreflight ["game_dir_required"] [])
    Just gameDir
      | null gameDir ->
          pure (ContentInstallDirectoryPreflight ["game_dir_required"] [])
      | otherwise -> do
          directoryExists <- doesDirectoryExist gameDir
          versionIds <- if directoryExists then installedVersionIdsInGameDir gameDir else pure []
          let targetSubdir = Text.unpack (contentInstallTargetSubdir request)
              knownInstance = find (samePath gameDir . contentTargetInstanceGameDir) (contentInstallInstances request)
              targetVersion =
                case knownInstance of
                  Just instanceValue -> Just (contentTargetInstanceMinecraftVersion instanceValue)
                  Nothing -> case versionIds of
                    versionId:_ -> Just versionId
                    [] -> Nothing
              targetLoader =
                case knownInstance of
                  Just instanceValue -> contentTargetInstanceLoader instanceValue
                  Nothing -> inferLoaderFromVersionIds versionIds
              versionCompatible =
                null (contentInstallGameVersions request)
                  || maybe False (matchesAnyMinecraftVersion (contentInstallGameVersions request)) targetVersion
              loaderCompatible =
                contentTargetLoaderCompatible targetSubdir (contentInstallLoaders request) targetLoader
              blockedReasons =
                concat
                  [ ["game_dir_not_found" | not directoryExists]
                  , ["not_panino_isolated_instance_dir" | directoryExists && not (isPaninoIsolatedInstanceDir gameDir)]
                  , ["version_files_missing" | directoryExists && null versionIds]
                  , ["minecraft_version_mismatch" | directoryExists && not (null versionIds) && not versionCompatible]
                  , ["loader_required_for_mod" | directoryExists && targetSubdir == "mods" && null (contentInstallLoaders request)]
                  , ["loader_mismatch" | directoryExists && targetSubdir == "mods" && not loaderCompatible && not (null (contentInstallLoaders request))]
                  , ["shader_loader_mismatch" | directoryExists && targetSubdir == "shaderpacks" && not loaderCompatible]
                  ]
              warnings =
                concat
                  [ ["manual_directory_not_in_local_instance_list" | directoryExists && knownInstance == Nothing]
                  , ["shader_support_not_verified" | directoryExists && targetSubdir == "shaderpacks" && null (contentInstallLoaders request)]
                  ]
          pure (ContentInstallDirectoryPreflight blockedReasons warnings)

resolveInstallDependencies :: FilePath -> [ContentInstallDependency] -> IO [ContentInstallDependency]
resolveInstallDependencies targetDir dependencies = do
  entries <- safeListDirectory targetDir
  let normalizedEntries = map (normalizeLookupText . Text.pack) entries
      dependencyHashes = [Text.toLower hashValue | Just hashValue <- map contentDependencySha1 dependencies]
  entryHashes <-
    if null dependencyHashes
      then pure []
      else traverse entrySha1 entries
  pure (map (resolveDependency normalizedEntries entryHashes) dependencies)
  where
    entrySha1 entry = do
      let target = targetDir </> entry
      exists <- doesFileExist target
      if exists && takeExtension entry == ".jar"
        then Just <$> sha1HexFile target
        else pure Nothing

resolveDependency :: [Text] -> [Maybe Text] -> ContentInstallDependency -> ContentInstallDependency
resolveDependency normalizedEntries entryHashes dependency =
  case contentDependencyInstalled dependency of
    Just _ -> dependency
    Nothing ->
      dependency
        { contentDependencyInstalled =
            if hasDependencyFile || hasDependencySha1
              then Just True
              else Nothing
        }
  where
    keys =
      filter
        ((>= 4) . Text.length)
        (map normalizeLookupText (contentDependencyName dependency : maybe [] (: []) (contentDependencyProjectId dependency)))
    hasDependencyFile =
      any (\key -> any (Text.isInfixOf key) normalizedEntries) keys
    hasDependencySha1 =
      case Text.toLower <$> contentDependencySha1 dependency of
        Nothing -> False
        Just expected -> Just expected `elem` entryHashes

planContentFile :: FilePath -> ContentInstallFile -> IO ContentInstallPlanFile
planContentFile targetDir file = do
  let targetPath = targetDir </> safeContentFileName (contentFileName file)
  exists <- doesFileExist targetPath
  matchingHash <-
    case (exists, contentFileSha1 file) of
      (True, Just expected) -> (== Text.toLower expected) <$> sha1HexFile targetPath
      _ -> pure False
  pure
    ContentInstallPlanFile
      { contentPlanFileName = contentFileName file
      , contentPlanTargetPath = targetPath
      , contentPlanFileSize = contentFileSize file
      , contentPlanFileSha1 = contentFileSha1 file
      , contentPlanFileAction =
          if matchingHash
            then "keep"
            else if exists
              then "replace"
              else "download"
      , contentPlanFilePrimary = fromMaybe False (contentFilePrimary file)
      }
