{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Online.Types.Project
  ( ContentProjectDependencySummary(..)
  , ContentProjectInstallability(..)
  , ContentProjectResponse(..)
  , OnlineDependency(..)
  , OnlineFile(..)
  , OnlineProject(..)
  , OnlineRelease(..)
  , OnlineSearchPage(..)
  , mkContentProjectResponse
  , onlineDependencyProjectIdText
  , onlineDependencyVersionIdText
  , onlineFileDownloadUrlText
  , onlineProjectIdText
  , onlineReleaseIdText
  , onlineReleaseProjectIdText
  ) where

import Control.Applicative ((<|>))
import Data.Aeson
  ( ToJSON(..)
  , Value
  , object
  , (.=)
  )
import Data.Int (Int64)
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Panino.Core.Types
  ( ProjectId
  , Url
  , VersionId
  , projectIdText
  , urlFromText
  , urlText
  , versionIdText
  )

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
  { projectId :: ProjectId
  , projectSource :: Text
  , projectSlug :: Maybe Text
  , projectTitle :: Text
  , projectSummary :: Text
  , projectDescription :: Maybe Text
  , projectIconUrl :: Maybe Url
  , projectGalleryUrls :: [Url]
  , projectAuthors :: [Text]
  , projectUrl :: Maybe Url
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
      , "iconURL" .= cleanOptionalUrl (projectIconUrl project)
      , "galleryURLs" .= cleanUrlList (projectGalleryUrls project)
      , "authors" .= projectAuthors project
      , "projectURL" .= cleanOptionalUrl (projectUrl project)
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
  { releaseId :: VersionId
  , releaseProjectId :: ProjectId
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
  , fileDownloadUrl :: Maybe Url
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
      , "downloadURL" .= cleanOptionalUrl (fileDownloadUrl file)
      , "hashes" .= fileHashes file
      , "isPrimary" .= filePrimary file
      , "downloadCount" .= fileDownloadCount file
      ]

onlineProjectIdText :: OnlineProject -> Text
onlineProjectIdText =
  projectIdText . projectId

onlineReleaseIdText :: OnlineRelease -> Text
onlineReleaseIdText =
  versionIdText . releaseId

onlineReleaseProjectIdText :: OnlineRelease -> Text
onlineReleaseProjectIdText =
  projectIdText . releaseProjectId

onlineFileDownloadUrlText :: OnlineFile -> Maybe Text
onlineFileDownloadUrlText =
  fmap urlText . fileDownloadUrl

cleanOptionalUrl :: Maybe Url -> Maybe Url
cleanOptionalUrl =
  (>>= \value -> let trimmed = Text.strip (urlText value) in if Text.null trimmed then Nothing else Just (urlFromText trimmed))

cleanUrlList :: [Url] -> [Url]
cleanUrlList =
  mapMaybeClean
  where
    mapMaybeClean [] = []
    mapMaybeClean (value:values) =
      let trimmed = Text.strip (urlText value)
       in if Text.null trimmed
            then mapMaybeClean values
            else urlFromText trimmed : mapMaybeClean values

data OnlineDependency = OnlineDependency
  { dependencyId :: Text
  , dependencyProjectId :: Maybe ProjectId
  , dependencyVersionId :: Maybe VersionId
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

onlineDependencyProjectIdText :: OnlineDependency -> Maybe Text
onlineDependencyProjectIdText =
  fmap projectIdText . dependencyProjectId

onlineDependencyVersionIdText :: OnlineDependency -> Maybe Text
onlineDependencyVersionIdText =
  fmap versionIdText . dependencyVersionId
