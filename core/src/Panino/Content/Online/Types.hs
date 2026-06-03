{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Online.Types
  ( ContentLoaderRequest(..)
  , ContentProjectDependencySummary(..)
  , ContentProjectInstallability(..)
  , ContentProjectRequest(..)
  , ContentProjectResponse(..)
  , ContentSearchRequest(..)
  , LoaderMetadata(..)
  , MinecraftAssetIndex(..)
  , MinecraftDownload(..)
  , MinecraftPackageRequest(..)
  , MinecraftRemoteVersion(..)
  , MinecraftVersionPackage(..)
  , OnlineDependency(..)
  , OnlineFile(..)
  , OnlineProject(..)
  , OnlineRelease(..)
  , OnlineSearchPage(..)
  , mkContentProjectResponse
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , Value
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Aeson.Types ((.!=))
import Control.Applicative ((<|>))
import Data.Int (Int64)
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)

data ContentSearchRequest = ContentSearchRequest
  { contentSearchSource :: Text
  , contentSearchText :: Text
  , contentSearchProjectTypes :: [Text]
  , contentSearchCategories :: [Text]
  , contentSearchGameVersion :: Maybe Text
  , contentSearchLoaders :: [Text]
  , contentSearchSort :: Text
  , contentSearchOffset :: Int
  , contentSearchLimit :: Int
  , contentSearchCurseForgeApiKey :: Maybe Text
  , contentSearchPrefetch :: Bool
  } deriving (Eq, Show)

instance FromJSON ContentSearchRequest where
  parseJSON =
    withObject "ContentSearchRequest" $ \obj ->
      ContentSearchRequest
        <$> obj .: "source"
        <*> obj .:? "text" .!= ""
        <*> obj .:? "projectTypes" .!= ["mod"]
        <*> obj .:? "categories" .!= []
        <*> obj .:? "gameVersion"
        <*> obj .:? "loaders" .!= []
        <*> obj .:? "sort" .!= "relevance"
        <*> obj .:? "offset" .!= 0
        <*> obj .:? "limit" .!= 20
        <*> obj .:? "curseForgeAPIKey"
        <*> obj .:? "prefetch" .!= True

data ContentProjectRequest = ContentProjectRequest
  { contentProjectSource :: Text
  , contentProjectId :: Text
  , contentProjectQuery :: ContentSearchRequest
  , contentProjectCurseForgeApiKey :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON ContentProjectRequest where
  parseJSON =
    withObject "ContentProjectRequest" $ \obj ->
      ContentProjectRequest
        <$> obj .: "source"
        <*> obj .: "projectId"
        <*> obj .: "query"
        <*> obj .:? "curseForgeAPIKey"

data MinecraftPackageRequest = MinecraftPackageRequest
  { minecraftPackageId :: Text
  , minecraftPackageUrl :: Text
  } deriving (Eq, Show)

instance FromJSON MinecraftPackageRequest where
  parseJSON =
    withObject "MinecraftPackageRequest" $ \obj ->
      MinecraftPackageRequest
        <$> obj .: "id"
        <*> obj .: "url"

newtype ContentLoaderRequest = ContentLoaderRequest
  { contentLoaderMinecraftVersion :: Text
  } deriving (Eq, Show)

instance FromJSON ContentLoaderRequest where
  parseJSON =
    withObject "ContentLoaderRequest" $ \obj ->
      ContentLoaderRequest <$> obj .: "minecraftVersion"

data OnlineSearchPage = OnlineSearchPage
  { pageSource :: Text
  , pageProjects :: [OnlineProject]
  , pageTotal :: Int
  , pageOffset :: Int
  , pageLimit :: Int
  , pageCacheStatus :: Maybe Text
  , pageRequestId :: Maybe Text
  , pageNextPrefetchKey :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON OnlineSearchPage where
  toJSON page =
    object
      [ "source" .= pageSource page
      , "projects" .= pageProjects page
      , "total" .= pageTotal page
      , "offset" .= pageOffset page
      , "limit" .= pageLimit page
      , "rateLimit" .= (Nothing :: Maybe Value)
      , "cacheStatus" .= pageCacheStatus page
      , "requestId" .= pageRequestId page
      , "hasMore" .= (pageOffset page + pageLimit page < pageTotal page)
      , "nextPrefetchKey" .= pageNextPrefetchKey page
      ]

data ContentProjectResponse = ContentProjectResponse
  { contentProjectResponseProject :: OnlineProject
  , contentProjectResponseReleases :: [OnlineRelease]
  , contentProjectResponseRecommendedRelease :: Maybe OnlineRelease
  , contentProjectResponseInstallability :: ContentProjectInstallability
  , contentProjectResponseDependencySummary :: ContentProjectDependencySummary
  } deriving (Eq, Show)

instance ToJSON ContentProjectResponse where
  toJSON response =
    object
      [ "project" .= contentProjectResponseProject response
      , "releases" .= contentProjectResponseReleases response
      , "recommendedRelease" .= contentProjectResponseRecommendedRelease response
      , "installability" .= contentProjectResponseInstallability response
      , "dependencySummary" .= contentProjectResponseDependencySummary response
      ]

data ContentProjectInstallability = ContentProjectInstallability
  { installabilityTargetSubdir :: Maybe Text
  , installabilityPrimaryFile :: Maybe OnlineFile
  , installabilityFileCount :: Int
  , installabilityDownloadSizeBytes :: Int64
  , installabilityRequiredDependencyCount :: Int
  , installabilityOptionalDependencyCount :: Int
  , installabilityBlockingReasons :: [Text]
  } deriving (Eq, Show)

instance ToJSON ContentProjectInstallability where
  toJSON summary =
    object
      [ "targetSubdir" .= installabilityTargetSubdir summary
      , "primaryFile" .= installabilityPrimaryFile summary
      , "fileCount" .= installabilityFileCount summary
      , "downloadSizeBytes" .= installabilityDownloadSizeBytes summary
      , "requiredDependencyCount" .= installabilityRequiredDependencyCount summary
      , "optionalDependencyCount" .= installabilityOptionalDependencyCount summary
      , "blockingReasons" .= installabilityBlockingReasons summary
      ]

data ContentProjectDependencySummary = ContentProjectDependencySummary
  { dependencySummaryRequiredCount :: Int
  , dependencySummaryOptionalCount :: Int
  , dependencySummaryEmbeddedCount :: Int
  , dependencySummaryIncompatibleCount :: Int
  , dependencySummaryDependencies :: [OnlineDependency]
  } deriving (Eq, Show)

instance ToJSON ContentProjectDependencySummary where
  toJSON summary =
    object
      [ "requiredCount" .= dependencySummaryRequiredCount summary
      , "optionalCount" .= dependencySummaryOptionalCount summary
      , "embeddedCount" .= dependencySummaryEmbeddedCount summary
      , "incompatibleCount" .= dependencySummaryIncompatibleCount summary
      , "dependencies" .= dependencySummaryDependencies summary
      ]

mkContentProjectResponse :: OnlineProject -> [OnlineRelease] -> ContentProjectResponse
mkContentProjectResponse project releases =
  ContentProjectResponse
    { contentProjectResponseProject = project
    , contentProjectResponseReleases = releases
    , contentProjectResponseRecommendedRelease = recommended
    , contentProjectResponseInstallability = installability
    , contentProjectResponseDependencySummary = dependencySummary
    }
  where
    recommended = recommendedRelease releases
    files = maybe [] releaseFiles recommended
    dependencies = maybe [] releaseDependencies recommended
    primary = primaryOnlineFile files
    requiredCount = length (filter ((== "required") . dependencyRelation) dependencies)
    optionalCount = length (filter ((== "optional") . dependencyRelation) dependencies)
    installability =
      ContentProjectInstallability
        { installabilityTargetSubdir = targetSubdirForProjectType (projectType project)
        , installabilityPrimaryFile = primary
        , installabilityFileCount = length files
        , installabilityDownloadSizeBytes = sum (map fileSizeBytes files)
        , installabilityRequiredDependencyCount = requiredCount
        , installabilityOptionalDependencyCount = optionalCount
        , installabilityBlockingReasons = installabilityBlocks project recommended primary
        }
    dependencySummary =
      ContentProjectDependencySummary
        { dependencySummaryRequiredCount = requiredCount
        , dependencySummaryOptionalCount = optionalCount
        , dependencySummaryEmbeddedCount = length (filter ((== "embedded") . dependencyRelation) dependencies)
        , dependencySummaryIncompatibleCount = length (filter ((== "incompatible") . dependencyRelation) dependencies)
        , dependencySummaryDependencies = dependencies
        }

recommendedRelease :: [OnlineRelease] -> Maybe OnlineRelease
recommendedRelease releases =
  firstWhere releaseRecommended releases
    <|> firstWhere ((== "release") . releaseType) releases
    <|> firstWhere (const True) releases

primaryOnlineFile :: [OnlineFile] -> Maybe OnlineFile
primaryOnlineFile files =
  firstWhere filePrimary files
    <|> firstWhere (const True) files

firstWhere :: (value -> Bool) -> [value] -> Maybe value
firstWhere _ [] = Nothing
firstWhere predicate (value:values)
  | predicate value = Just value
  | otherwise = firstWhere predicate values

targetSubdirForProjectType :: Text -> Maybe Text
targetSubdirForProjectType "mod" = Just "mods"
targetSubdirForProjectType "resourcePack" = Just "resourcepacks"
targetSubdirForProjectType "shaderPack" = Just "shaderpacks"
targetSubdirForProjectType _ = Nothing

installabilityBlocks :: OnlineProject -> Maybe OnlineRelease -> Maybe OnlineFile -> [Text]
installabilityBlocks project maybeRelease maybeFile =
  concat
    [ ["project_archived" | projectArchived project || projectDeprecated project]
    , ["modpack_requires_import_flow" | projectType project == "modpack"]
    , ["unsupported_project_type" | targetSubdirForProjectType (projectType project) == Nothing && projectType project /= "modpack"]
    , ["no_releases" | maybeRelease == Nothing]
    , ["no_downloadable_files" | maybeRelease /= Nothing && maybeFile == Nothing]
    , ["download_url_missing" | maybe False ((== Nothing) . fileDownloadUrl) maybeFile]
    ]

data OnlineProject = OnlineProject
  { projectId :: Text
  , projectSource :: Text
  , projectSlug :: Maybe Text
  , projectTitle :: Text
  , projectSummary :: Text
  , projectDescription :: Maybe Text
  , projectIconUrl :: Maybe Text
  , projectGalleryUrls :: [Text]
  , projectAuthors :: [Text]
  , projectUrl :: Maybe Text
  , projectType :: Text
  , projectDownloads :: Int
  , projectFollows :: Maybe Int
  , projectUpdatedAt :: Maybe UTCTime
  , projectPublishedAt :: Maybe UTCTime
  , projectGameVersions :: [Text]
  , projectLoaders :: [Text]
  , projectClientSide :: Text
  , projectServerSide :: Text
  , projectLicense :: Maybe Text
  , projectArchived :: Bool
  , projectDeprecated :: Bool
  , projectCategories :: [Text]
  } deriving (Eq, Show)

instance ToJSON OnlineProject where
  toJSON project =
    object
      [ "id" .= projectId project
      , "source" .= projectSource project
      , "slug" .= projectSlug project
      , "title" .= projectTitle project
      , "summary" .= projectSummary project
      , "description" .= projectDescription project
      , "iconURL" .= cleanOptionalText (projectIconUrl project)
      , "galleryURLs" .= cleanTextList (projectGalleryUrls project)
      , "authors" .= projectAuthors project
      , "projectURL" .= cleanOptionalText (projectUrl project)
      , "projectType" .= projectType project
      , "downloads" .= projectDownloads project
      , "follows" .= projectFollows project
      , "updatedAt" .= projectUpdatedAt project
      , "publishedAt" .= projectPublishedAt project
      , "gameVersions" .= projectGameVersions project
      , "loaders" .= projectLoaders project
      , "clientSide" .= projectClientSide project
      , "serverSide" .= projectServerSide project
      , "license" .= projectLicense project
      , "isArchived" .= projectArchived project
      , "isDeprecated" .= projectDeprecated project
      , "categories" .= projectCategories project
      ]

data OnlineRelease = OnlineRelease
  { releaseId :: Text
  , releaseProjectId :: Text
  , releaseSource :: Text
  , releaseVersionName :: Text
  , releaseVersionNumber :: Text
  , releaseGameVersions :: [Text]
  , releaseLoaders :: [Text]
  , releaseType :: Text
  , releasePublishedAt :: Maybe UTCTime
  , releaseFiles :: [OnlineFile]
  , releaseDependencies :: [OnlineDependency]
  , releaseChangelog :: Maybe Text
  , releaseRecommended :: Bool
  } deriving (Eq, Show)

instance ToJSON OnlineRelease where
  toJSON release =
    object
      [ "id" .= releaseId release
      , "projectID" .= releaseProjectId release
      , "source" .= releaseSource release
      , "versionName" .= releaseVersionName release
      , "versionNumber" .= releaseVersionNumber release
      , "gameVersions" .= releaseGameVersions release
      , "loaders" .= releaseLoaders release
      , "releaseType" .= releaseType release
      , "publishedAt" .= releasePublishedAt release
      , "files" .= releaseFiles release
      , "dependencies" .= releaseDependencies release
      , "changelog" .= releaseChangelog release
      , "isRecommended" .= releaseRecommended release
      ]

data OnlineFile = OnlineFile
  { fileId :: Text
  , fileName :: Text
  , fileSizeBytes :: Int64
  , fileDownloadUrl :: Maybe Text
  , fileHashes :: Map Text Text
  , filePrimary :: Bool
  , fileDownloadCount :: Maybe Int
  } deriving (Eq, Show)

instance ToJSON OnlineFile where
  toJSON file =
    object
      [ "id" .= fileId file
      , "fileName" .= fileName file
      , "sizeBytes" .= fileSizeBytes file
      , "downloadURL" .= cleanOptionalText (fileDownloadUrl file)
      , "hashes" .= fileHashes file
      , "isPrimary" .= filePrimary file
      , "downloadCount" .= fileDownloadCount file
      ]

cleanOptionalText :: Maybe Text -> Maybe Text
cleanOptionalText =
  (>>= \value -> let trimmed = Text.strip value in if Text.null trimmed then Nothing else Just trimmed)

cleanTextList :: [Text] -> [Text]
cleanTextList =
  mapMaybeClean
  where
    mapMaybeClean [] = []
    mapMaybeClean (value:values) =
      let trimmed = Text.strip value
       in if Text.null trimmed
            then mapMaybeClean values
            else trimmed : mapMaybeClean values

data OnlineDependency = OnlineDependency
  { dependencyId :: Text
  , dependencyProjectId :: Maybe Text
  , dependencyVersionId :: Maybe Text
  , dependencySource :: Text
  , dependencyRelation :: Text
  } deriving (Eq, Show)

instance ToJSON OnlineDependency where
  toJSON dependency =
    object
      [ "id" .= dependencyId dependency
      , "projectID" .= dependencyProjectId dependency
      , "versionID" .= dependencyVersionId dependency
      , "source" .= dependencySource dependency
      , "relation" .= dependencyRelation dependency
      ]

data MinecraftRemoteVersion = MinecraftRemoteVersion
  { remoteVersionId :: Text
  , remoteVersionType :: Text
  , remoteVersionUrl :: Text
  , remoteVersionReleaseTime :: Maybe UTCTime
  } deriving (Eq, Show)

instance ToJSON MinecraftRemoteVersion where
  toJSON version =
    object
      [ "id" .= remoteVersionId version
      , "type" .= remoteVersionType version
      , "url" .= remoteVersionUrl version
      , "releasedAt" .= remoteVersionReleaseTime version
      ]

data MinecraftVersionPackage = MinecraftVersionPackage
  { packageId :: Text
  , packageType :: Text
  , packageJavaMajorVersion :: Maybe Int
  , packageAssetIndex :: Maybe MinecraftAssetIndex
  , packageDownloads :: Map Text MinecraftDownload
  , packageLibraryCount :: Maybe Int
  , packageNativeLibraryCount :: Int
  } deriving (Eq, Show)

instance ToJSON MinecraftVersionPackage where
  toJSON package =
    object
      [ "id" .= packageId package
      , "type" .= packageType package
      , "javaMajorVersion" .= packageJavaMajorVersion package
      , "assetIndex" .= packageAssetIndex package
      , "downloads" .= packageDownloads package
      , "libraryCount" .= packageLibraryCount package
      , "nativeLibraryCount" .= packageNativeLibraryCount package
      ]

data MinecraftAssetIndex = MinecraftAssetIndex
  { assetIndexId :: Text
  , assetIndexUrl :: Text
  , assetIndexSha1 :: Maybe Text
  , assetIndexSizeBytes :: Maybe Int64
  , assetIndexTotalSizeBytes :: Maybe Int64
  } deriving (Eq, Show)

instance ToJSON MinecraftAssetIndex where
  toJSON asset =
    object
      [ "id" .= assetIndexId asset
      , "url" .= assetIndexUrl asset
      , "sha1" .= assetIndexSha1 asset
      , "sizeBytes" .= assetIndexSizeBytes asset
      , "totalSizeBytes" .= assetIndexTotalSizeBytes asset
      ]

data MinecraftDownload = MinecraftDownload
  { downloadUrl :: Text
  , downloadSha1 :: Maybe Text
  , downloadSizeBytes :: Maybe Int64
  } deriving (Eq, Show)

instance ToJSON MinecraftDownload where
  toJSON download =
    object
      [ "url" .= downloadUrl download
      , "sha1" .= downloadSha1 download
      , "sizeBytes" .= downloadSizeBytes download
      ]

data LoaderMetadata = LoaderMetadata
  { loaderMetadataId :: Text
  , loaderMetadataSource :: Text
  , loaderMetadataMinecraftVersion :: Text
  , loaderMetadataLoaderVersion :: Text
  , loaderMetadataInstallerVersion :: Maybe Text
  , loaderMetadataStable :: Bool
  , loaderMetadataDownloadUrl :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON LoaderMetadata where
  toJSON loader =
    object
      [ "id" .= loaderMetadataId loader
      , "source" .= loaderMetadataSource loader
      , "minecraftVersion" .= loaderMetadataMinecraftVersion loader
      , "loaderVersion" .= loaderMetadataLoaderVersion loader
      , "installerVersion" .= loaderMetadataInstallerVersion loader
      , "stable" .= loaderMetadataStable loader
      , "downloadURL" .= loaderMetadataDownloadUrl loader
      ]
