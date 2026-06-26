{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Online.Modrinth.Types
  ( ModrinthDependency(..)
  , ModrinthFile(..)
  , ModrinthProjectResponse(..)
  , ModrinthSearchResponse(..)
  , ModrinthVersionResponse(..)
  , modrinthProjectToOnline
  , modrinthProjectType
  , modrinthVersionToOnline
  ) where

import Control.Applicative ((<|>))
import Data.Aeson
  ( FromJSON(..)
  , Value(..)
  , withObject
  , (.:)
  , (.:?)
  )
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Aeson.Types ((.!=))
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( catMaybes
  , fromMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Panino.Content.Online.Normalize
  ( loaderFamilies
  , normalizedCategories
  , onlineProjectType
  , relationText
  , releaseTypeText
  , sideSupport
  )
import Panino.Content.Online.Types
  ( OnlineDependency(..)
  , OnlineFile(..)
  , OnlineProject(..)
  , OnlineRelease(..)
  )

data ModrinthSearchResponse = ModrinthSearchResponse
  { modrinthHits :: [ModrinthProjectResponse]
  , modrinthOffset :: Int
  , modrinthLimit :: Int
  , modrinthTotalHits :: Int
  } deriving (Eq, Show)

instance FromJSON ModrinthSearchResponse where
  parseJSON =
    withObject "ModrinthSearchResponse" $ \obj ->
      ModrinthSearchResponse
        <$> obj .: "hits"
        <*> obj .:? "offset" .!= 0
        <*> obj .:? "limit" .!= 0
        <*> obj .:? "total_hits" .!= 0

data ModrinthProjectResponse = ModrinthProjectResponse
  { modrinthProjectId :: Text
  , modrinthSlug :: Maybe Text
  , modrinthTitle :: Text
  , modrinthDescription :: Maybe Text
  , modrinthBody :: Maybe Text
  , modrinthProjectKind :: Maybe Text
  , modrinthDownloads :: Maybe Int
  , modrinthFollowers :: Maybe Int
  , modrinthFollows :: Maybe Int
  , modrinthIconUrl :: Maybe Text
  , modrinthAuthor :: Maybe Text
  , modrinthCategories :: [Text]
  , modrinthVersions :: [Text]
  , modrinthLoaders :: [Text]
  , modrinthClientSide :: Maybe Text
  , modrinthServerSide :: Maybe Text
  , modrinthDateModified :: Maybe UTCTime
  , modrinthUpdated :: Maybe UTCTime
  , modrinthLicense :: Maybe Value
  , modrinthGallery :: [Value]
  , modrinthStatus :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON ModrinthProjectResponse where
  parseJSON =
    withObject "ModrinthProjectResponse" $ \obj -> do
      projectIdValue <- obj .:? "project_id" >>= maybe (obj .: "id") pure
      ModrinthProjectResponse
        <$> pure projectIdValue
        <*> obj .:? "slug"
        <*> obj .: "title"
        <*> obj .:? "description"
        <*> obj .:? "body"
        <*> obj .:? "project_type"
        <*> obj .:? "downloads"
        <*> obj .:? "followers"
        <*> obj .:? "follows"
        <*> obj .:? "icon_url"
        <*> obj .:? "author"
        <*> obj .:? "categories" .!= []
        <*> obj .:? "versions" .!= []
        <*> obj .:? "loaders" .!= []
        <*> obj .:? "client_side"
        <*> obj .:? "server_side"
        <*> obj .:? "date_modified"
        <*> obj .:? "updated"
        <*> obj .:? "license"
        <*> obj .:? "gallery" .!= []
        <*> obj .:? "status"

modrinthProjectToOnline :: ModrinthProjectResponse -> OnlineProject
modrinthProjectToOnline project =
  OnlineProject
    { projectId = modrinthProjectId project
    , projectSource = "modrinth"
    , projectSlug = modrinthSlug project
    , projectTitle = modrinthTitle project
    , projectSummary = fromMaybe "" (modrinthDescription project)
    , projectDescription = modrinthBody project
    , projectIconUrl = modrinthIconUrl project
    , projectGalleryUrls = mapMaybe galleryUrl (modrinthGallery project)
    , projectAuthors = maybe [] (: []) (modrinthAuthor project)
    , projectUrl = modrinthProjectUrl project
    , projectType = onlineProjectType (fromMaybe "mod" (modrinthProjectKind project))
    , projectDownloads = fromMaybe 0 (modrinthDownloads project)
    , projectFollows = modrinthFollowers project <|> modrinthFollows project
    , projectUpdatedAt = modrinthUpdated project <|> modrinthDateModified project
    , projectPublishedAt = Nothing
    , projectGameVersions = modrinthVersions project
    , projectLoaders = loaderFamilies (modrinthLoaders project <> modrinthCategories project)
    , projectClientSide = sideSupport (modrinthClientSide project)
    , projectServerSide = sideSupport (modrinthServerSide project)
    , projectLicense = modrinthLicenseId (modrinthLicense project)
    , projectArchived = modrinthStatus project == Just "archived"
    , projectDeprecated = modrinthStatus project == Just "archived"
    , projectCategories =
        normalizedCategories
          (onlineProjectType (fromMaybe "mod" (modrinthProjectKind project)))
          (modrinthCategories project <> modrinthLoaders project <> [modrinthTitle project, fromMaybe "" (modrinthDescription project)])
    }

modrinthProjectUrl :: ModrinthProjectResponse -> Maybe Text
modrinthProjectUrl project =
  (\slug -> "https://modrinth.com/" <> modrinthProjectType (onlineProjectType (fromMaybe "mod" (modrinthProjectKind project))) <> "/" <> slug)
    <$> modrinthSlug project

modrinthLicenseId :: Maybe Value -> Maybe Text
modrinthLicenseId Nothing = Nothing
modrinthLicenseId (Just (String value)) = Just value
modrinthLicenseId (Just (Object obj)) =
  case KeyMap.lookup "id" obj of
    Just (String value) -> Just value
    _ -> Nothing
modrinthLicenseId _ = Nothing

galleryUrl :: Value -> Maybe Text
galleryUrl (String value) = Just value
galleryUrl (Object obj) =
  case KeyMap.lookup "url" obj of
    Just (String value) -> Just value
    _ -> Nothing
galleryUrl _ = Nothing

data ModrinthVersionResponse = ModrinthVersionResponse
  { modrinthVersionId :: Text
  , modrinthVersionProjectId :: Text
  , modrinthVersionName :: Text
  , modrinthVersionNumber :: Text
  , modrinthChangelog :: Maybe Text
  , modrinthDependencies :: [ModrinthDependency]
  , modrinthGameVersions :: [Text]
  , modrinthVersionType :: Text
  , modrinthVersionLoaders :: [Text]
  , modrinthFeatured :: Bool
  , modrinthDatePublished :: Maybe UTCTime
  , modrinthVersionDownloads :: Maybe Int
  , modrinthFiles :: [ModrinthFile]
  } deriving (Eq, Show)

instance FromJSON ModrinthVersionResponse where
  parseJSON =
    withObject "ModrinthVersionResponse" $ \obj ->
      ModrinthVersionResponse
        <$> obj .: "id"
        <*> obj .: "project_id"
        <*> obj .: "name"
        <*> obj .: "version_number"
        <*> obj .:? "changelog"
        <*> obj .:? "dependencies" .!= []
        <*> obj .:? "game_versions" .!= []
        <*> obj .:? "version_type" .!= "release"
        <*> obj .:? "loaders" .!= []
        <*> obj .:? "featured" .!= False
        <*> obj .:? "date_published"
        <*> obj .:? "downloads"
        <*> obj .:? "files" .!= []

modrinthVersionToOnline :: ModrinthVersionResponse -> OnlineRelease
modrinthVersionToOnline version =
  OnlineRelease
    { releaseId = modrinthVersionId version
    , releaseProjectId = modrinthVersionProjectId version
    , releaseSource = "modrinth"
    , releaseVersionName = modrinthVersionName version
    , releaseVersionNumber = modrinthVersionNumber version
    , releaseGameVersions = modrinthGameVersions version
    , releaseLoaders = loaderFamilies (modrinthVersionLoaders version)
    , releaseType = releaseTypeText (modrinthVersionType version)
    , releasePublishedAt = modrinthDatePublished version
    , releaseFiles = map (modrinthFileToOnline (modrinthVersionDownloads version)) (modrinthFiles version)
    , releaseDependencies = map modrinthDependencyToOnline (modrinthDependencies version)
    , releaseChangelog = modrinthChangelog version
    , releaseRecommended = modrinthFeatured version
    }

data ModrinthFile = ModrinthFile
  { modrinthFileHashes :: Map Text Text
  , modrinthFileUrl :: Maybe Text
  , modrinthFileName :: Text
  , modrinthFilePrimary :: Bool
  , modrinthFileSize :: Maybe Int64
  } deriving (Eq, Show)

instance FromJSON ModrinthFile where
  parseJSON =
    withObject "ModrinthFile" $ \obj ->
      ModrinthFile
        <$> obj .:? "hashes" .!= Map.empty
        <*> obj .:? "url"
        <*> obj .: "filename"
        <*> obj .:? "primary" .!= False
        <*> obj .:? "size"

modrinthFileToOnline :: Maybe Int -> ModrinthFile -> OnlineFile
modrinthFileToOnline downloads file =
  OnlineFile
    { fileId = fromMaybe (modrinthFileName file) (Map.lookup "sha1" (modrinthFileHashes file))
    , fileName = modrinthFileName file
    , fileSizeBytes = fromMaybe 0 (modrinthFileSize file)
    , fileDownloadUrl = modrinthFileUrl file
    , fileHashes = modrinthFileHashes file
    , filePrimary = modrinthFilePrimary file
    , fileDownloadCount = downloads
    }

data ModrinthDependency = ModrinthDependency
  { modrinthDependencyVersionId :: Maybe Text
  , modrinthDependencyProjectId :: Maybe Text
  , modrinthDependencyType :: Text
  } deriving (Eq, Show)

instance FromJSON ModrinthDependency where
  parseJSON =
    withObject "ModrinthDependency" $ \obj ->
      ModrinthDependency
        <$> obj .:? "version_id"
        <*> obj .:? "project_id"
        <*> obj .:? "dependency_type" .!= "unknown"

modrinthDependencyToOnline :: ModrinthDependency -> OnlineDependency
modrinthDependencyToOnline dependency =
  OnlineDependency
    { dependencyId = Text.intercalate ":" (catMaybes [modrinthDependencyProjectId dependency, modrinthDependencyVersionId dependency, Just (modrinthDependencyType dependency)])
    , dependencyProjectId = modrinthDependencyProjectId dependency
    , dependencyVersionId = modrinthDependencyVersionId dependency
    , dependencySource = "modrinth"
    , dependencyRelation = relationText (modrinthDependencyType dependency)
    }

modrinthProjectType :: Text -> Text
modrinthProjectType "resourcePack" = "resourcepack"
modrinthProjectType "shaderPack" = "shader"
modrinthProjectType "modpack" = "modpack"
modrinthProjectType _ = "mod"
