{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Online.CurseForge.Types
  ( CurseCategory(..)
  , CurseDependency(..)
  , CurseEnvelope(..)
  , CurseFileResponse(..)
  , CurseModResponse(..)
  , CursePagination(..)
  , curseFileToOnline
  , curseProjectToOnline
  ) where

import Data.Aeson
  ( FromJSON(..)
  , Value(..)
  , withObject
  , (.:)
  , (.:?)
  )
import Data.Aeson.Types
  ( Parser
  , (.!=)
  )
import Data.Int (Int64)
import Data.List (nub)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Panino.Content.Online.Normalize
  ( loaderFamilies
  , normalizedCategories
  )
import Panino.Content.Online.Types
  ( OnlineDependency(..)
  , OnlineFile(..)
  , OnlineProject(..)
  , OnlineRelease(..)
  )

data CurseEnvelope value = CurseEnvelope
  { curseData :: value
  , cursePagination :: Maybe CursePagination
  } deriving (Eq, Show)

instance FromJSON value => FromJSON (CurseEnvelope value) where
  parseJSON =
    withObject "CurseEnvelope" $ \obj ->
      CurseEnvelope
        <$> obj .: "data"
        <*> obj .:? "pagination"

data CursePagination = CursePagination
  { curseIndex :: Int
  , cursePageSize :: Int
  , curseTotalCount :: Int
  } deriving (Eq, Show)

instance FromJSON CursePagination where
  parseJSON =
    withObject "CursePagination" $ \obj ->
      CursePagination
        <$> obj .:? "index" .!= 0
        <*> obj .:? "pageSize" .!= 0
        <*> obj .:? "totalCount" .!= 0

data CurseModResponse = CurseModResponse
  { curseModId :: Int
  , curseName :: Text
  , curseSlug :: Maybe Text
  , curseSummary :: Maybe Text
  , curseDownloadCount :: Maybe Int
  , curseDateModified :: Maybe UTCTime
  , curseClassId :: Maybe Int
  , curseAuthors :: [CurseAuthor]
  , curseLogo :: Maybe CurseAsset
  , curseScreenshots :: [CurseAsset]
  , curseCategories :: [CurseCategory]
  , curseLatestFilesIndexes :: [CurseFileIndex]
  , curseLinks :: Maybe CurseLinks
  , curseStatus :: Maybe Int
  } deriving (Eq, Show)

instance FromJSON CurseModResponse where
  parseJSON =
    withObject "CurseModResponse" $ \obj ->
      CurseModResponse
        <$> obj .: "id"
        <*> obj .: "name"
        <*> obj .:? "slug"
        <*> obj .:? "summary"
        <*> obj .:? "downloadCount"
        <*> obj .:? "dateModified"
        <*> obj .:? "classId"
        <*> obj .:? "authors" .!= []
        <*> obj .:? "logo"
        <*> obj .:? "screenshots" .!= []
        <*> obj .:? "categories" .!= []
        <*> obj .:? "latestFilesIndexes" .!= []
        <*> obj .:? "links"
        <*> obj .:? "status"

curseProjectToOnline :: CurseModResponse -> OnlineProject
curseProjectToOnline project =
  OnlineProject
    { projectId = Text.pack (show (curseModId project))
    , projectSource = "curseForge"
    , projectSlug = curseSlug project
    , projectTitle = curseName project
    , projectSummary = fromMaybe "" (curseSummary project)
    , projectDescription = Nothing
    , projectIconUrl = curseLogo project >>= curseAssetUrl
    , projectGalleryUrls = mapMaybe curseAssetUrl (curseScreenshots project)
    , projectAuthors = map curseAuthorName (curseAuthors project)
    , projectUrl = curseLinks project >>= curseWebsiteUrl
    , projectType = curseProjectType (curseClassId project)
    , projectDownloads = fromMaybe 0 (curseDownloadCount project)
    , projectFollows = Nothing
    , projectUpdatedAt = curseDateModified project
    , projectPublishedAt = Nothing
    , projectGameVersions = nub (map curseFileGameVersion (curseLatestFilesIndexes project))
    , projectLoaders = loaderFamilies (map curseFileModLoader (curseLatestFilesIndexes project))
    , projectClientSide = "unknown"
    , projectServerSide = "unknown"
    , projectLicense = Nothing
    , projectArchived = curseStatus project == Just 4
    , projectDeprecated = curseStatus project == Just 4
    , projectCategories =
        normalizedCategories
          (curseProjectType (curseClassId project))
          (map curseCategoryName (curseCategories project) <> [curseName project, fromMaybe "" (curseSummary project)])
    }

newtype CurseAuthor = CurseAuthor { curseAuthorName :: Text }
  deriving (Eq, Show)

instance FromJSON CurseAuthor where
  parseJSON =
    withObject "CurseAuthor" $ \obj ->
      CurseAuthor <$> obj .: "name"

data CurseCategory = CurseCategory
  { curseCategoryId :: Int
  , curseCategoryName :: Text
  , curseCategorySlug :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON CurseCategory where
  parseJSON =
    withObject "CurseCategory" $ \obj ->
      CurseCategory
        <$> obj .:? "id" .!= 0
        <*> obj .:? "name" .!= ""
        <*> obj .:? "slug"

newtype CurseAsset = CurseAsset { curseAssetUrl :: Maybe Text }
  deriving (Eq, Show)

instance FromJSON CurseAsset where
  parseJSON =
    withObject "CurseAsset" $ \obj ->
      CurseAsset <$> obj .:? "url"

newtype CurseLinks = CurseLinks { curseWebsiteUrl :: Maybe Text }
  deriving (Eq, Show)

instance FromJSON CurseLinks where
  parseJSON =
    withObject "CurseLinks" $ \obj ->
      CurseLinks <$> obj .:? "websiteUrl"

data CurseFileIndex = CurseFileIndex
  { curseFileGameVersion :: Text
  , curseFileModLoader :: Text
  } deriving (Eq, Show)

instance FromJSON CurseFileIndex where
  parseJSON =
    withObject "CurseFileIndex" $ \obj ->
      CurseFileIndex
        <$> obj .:? "gameVersion" .!= ""
        <*> (curseLoaderText =<< obj .:? "modLoader")

curseLoaderText :: Maybe Value -> Parser Text
curseLoaderText Nothing = pure ""
curseLoaderText (Just (String value)) = pure value
curseLoaderText (Just (Number value)) =
  pure
    ( case value of
        1 -> "forge"
        4 -> "fabric"
        5 -> "quilt"
        6 -> "neoForge"
        other -> Text.pack (show other)
    )
curseLoaderText (Just _) = pure ""

data CurseFileResponse = CurseFileResponse
  { curseFileId :: Int
  , curseFileDisplayName :: Maybe Text
  , curseFileName :: Text
  , curseFileDate :: Maybe UTCTime
  , curseFileLength :: Maybe Int64
  , curseFileDownloadUrl :: Maybe Text
  , curseFileGameVersions :: [Text]
  , curseFileReleaseType :: Maybe Int
  , curseFileHashes :: [CurseHash]
  , curseFileDependencies :: [CurseDependency]
  , curseFileDownloadCount :: Maybe Int
  } deriving (Eq, Show)

instance FromJSON CurseFileResponse where
  parseJSON =
    withObject "CurseFileResponse" $ \obj ->
      CurseFileResponse
        <$> obj .: "id"
        <*> obj .:? "displayName"
        <*> obj .: "fileName"
        <*> obj .:? "fileDate"
        <*> obj .:? "fileLength"
        <*> obj .:? "downloadUrl"
        <*> obj .:? "gameVersions" .!= []
        <*> obj .:? "releaseType"
        <*> obj .:? "hashes" .!= []
        <*> obj .:? "dependencies" .!= []
        <*> obj .:? "downloadCount"

curseFileToOnline :: Text -> CurseFileResponse -> OnlineRelease
curseFileToOnline projectIdValue file =
  OnlineRelease
    { releaseId = Text.pack (show (curseFileId file))
    , releaseProjectId = projectIdValue
    , releaseSource = "curseForge"
    , releaseVersionName = fromMaybe (curseFileName file) (curseFileDisplayName file)
    , releaseVersionNumber = fromMaybe (Text.pack (show (curseFileId file))) (curseFileDisplayName file)
    , releaseGameVersions = curseFileGameVersions file
    , releaseLoaders = loaderFamilies (curseFileGameVersions file)
    , releaseType = curseReleaseType (curseFileReleaseType file)
    , releasePublishedAt = curseFileDate file
    , releaseFiles =
        [ OnlineFile
            { fileId = Text.pack (show (curseFileId file))
            , fileName = curseFileName file
            , fileSizeBytes = fromMaybe 0 (curseFileLength file)
            , fileDownloadUrl = curseFileDownloadUrl file
            , fileHashes = Map.fromList (map curseHashPair (curseFileHashes file))
            , filePrimary = True
            , fileDownloadCount = curseFileDownloadCount file
            }
        ]
    , releaseDependencies = map curseDependencyToOnline (curseFileDependencies file)
    , releaseChangelog = Nothing
    , releaseRecommended = curseFileReleaseType file == Just 1
    }

data CurseHash = CurseHash
  { curseHashValue :: Text
  , curseHashAlgo :: Int
  } deriving (Eq, Show)

instance FromJSON CurseHash where
  parseJSON =
    withObject "CurseHash" $ \obj ->
      CurseHash
        <$> obj .: "value"
        <*> obj .:? "algo" .!= 0

curseHashPair :: CurseHash -> (Text, Text)
curseHashPair hashValue =
  ( case curseHashAlgo hashValue of
      1 -> "sha1"
      2 -> "md5"
      other -> "algo-" <> Text.pack (show other)
  , curseHashValue hashValue
  )

data CurseDependency = CurseDependency
  { curseDependencyModId :: Int
  , curseDependencyRelationType :: Int
  } deriving (Eq, Show)

instance FromJSON CurseDependency where
  parseJSON =
    withObject "CurseDependency" $ \obj ->
      CurseDependency
        <$> obj .: "modId"
        <*> obj .:? "relationType" .!= 0

curseDependencyToOnline :: CurseDependency -> OnlineDependency
curseDependencyToOnline dependency =
  OnlineDependency
    { dependencyId = Text.pack (show (curseDependencyModId dependency) <> ":" <> show (curseDependencyRelationType dependency))
    , dependencyProjectId = Just (Text.pack (show (curseDependencyModId dependency)))
    , dependencyVersionId = Nothing
    , dependencySource = "curseForge"
    , dependencyRelation = curseRelation (curseDependencyRelationType dependency)
    }

curseProjectType :: Maybe Int -> Text
curseProjectType (Just 4471) = "modpack"
curseProjectType (Just 12) = "resourcePack"
curseProjectType (Just 6552) = "shaderPack"
curseProjectType _ = "mod"

curseReleaseType :: Maybe Int -> Text
curseReleaseType (Just 1) = "release"
curseReleaseType (Just 2) = "beta"
curseReleaseType (Just 3) = "alpha"
curseReleaseType _ = "unknown"

curseRelation :: Int -> Text
curseRelation 3 = "required"
curseRelation 2 = "optional"
curseRelation 4 = "incompatible"
curseRelation 1 = "embedded"
curseRelation _ = "unknown"
