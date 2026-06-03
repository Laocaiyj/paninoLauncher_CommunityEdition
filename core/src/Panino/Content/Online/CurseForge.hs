{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections #-}

module Panino.Content.Online.CurseForge
  ( CurseDependency(..)
  , CurseEnvelope(..)
  , CurseFileResponse(..)
  , CurseModResponse(..)
  , CursePagination(..)
  , curseForgeProject
  , curseForgeSearch
  , curseForgeSearchQuery
  , curseForgeSearchQueryWithCategoryIds
  ) where

import Control.Applicative ((<|>))
import Control.Concurrent (forkIO)
import Control.Concurrent.Async
  ( concurrently
  , mapConcurrently
  )
import Control.Monad (void)
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
  ( catMaybes
  , fromMaybe
  , listToMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Http
  ( coreRequest
  , fetchJson
  , recover
  )
import Panino.Content.Online.Errors (requireCurseForgeApiKey)
import Panino.Content.Online.Normalize
  ( jsonText
  , loaderFamilies
  , normalizedCategories
  , queryString
  )
import Panino.Content.Online.Types
  ( ContentProjectRequest(..)
  , ContentProjectResponse(..)
  , ContentSearchRequest(..)
  , OnlineDependency(..)
  , OnlineFile(..)
  , OnlineProject(..)
  , OnlineRelease(..)
  , OnlineSearchPage(..)
  , mkContentProjectResponse
  )

curseForgeSearch :: Manager -> ContentSearchRequest -> IO OnlineSearchPage
curseForgeSearch manager request = do
  apiKey <- requireCurseForgeApiKey (contentSearchCurseForgeApiKey request)
  categoryIds <- curseForgeCategoryIds manager apiKey request
  response <-
    fetchJson manager
      =<< coreRequest
        ("https://api.curseforge.com/v1/mods/search" <> curseForgeSearchQueryWithCategoryIds request categoryIds)
        [("x-api-key", apiKey)]
  pure
    OnlineSearchPage
      { pageSource = "curseForge"
      , pageProjects = map curseProjectToOnline (curseData response)
      , pageTotal = maybe (length (curseData response)) curseTotalCount (cursePagination response)
      , pageOffset = maybe (contentSearchOffset request) curseIndex (cursePagination response)
      , pageLimit = maybe (contentSearchLimit request) cursePageSize (cursePagination response)
      , pageCacheStatus = Nothing
      , pageRequestId = Nothing
      , pageNextPrefetchKey = Nothing
      }

curseForgeProject :: Manager -> ContentProjectRequest -> IO ContentProjectResponse
curseForgeProject manager request = do
  let apiKey = contentSearchCurseForgeApiKey (contentProjectQuery request) <|> contentProjectCurseForgeApiKey request
  key <- requireCurseForgeApiKey apiKey
  (projectResponse, fileResponse) <-
    concurrently
      (projectAction key)
      (filesAction key)
  void (forkIO (recover () (prefetchCurseForgeDependencies manager key (curseData fileResponse))))
  pure (mkContentProjectResponse (curseProjectToOnline (curseData projectResponse)) (map (curseFileToOnline (contentProjectId request)) (curseData fileResponse)))
  where
    projectAction key =
      fetchJson manager
        =<< coreRequest
          ("https://api.curseforge.com/v1/mods/" <> Text.unpack (contentProjectId request))
          [("x-api-key", key)]
    filesAction key =
      fetchJson manager
        =<< coreRequest
          ("https://api.curseforge.com/v1/mods/" <> Text.unpack (contentProjectId request) <> "/files" <> curseForgeFilesQuery (contentProjectQuery request))
          [("x-api-key", key)]

prefetchCurseForgeDependencies :: Manager -> Text -> [CurseFileResponse] -> IO ()
prefetchCurseForgeDependencies manager key files =
  void (mapConcurrently prefetch (take 12 dependencyIds))
  where
    dependencyIds =
      nub
        [ curseDependencyModId dependency
        | dependency <- concatMap curseFileDependencies files
        , curseDependencyRelationType dependency == 3
        ]
    prefetch modId = do
      request <- coreRequest ("https://api.curseforge.com/v1/mods/" <> show modId) [("x-api-key", key)]
      _ <- (fetchJson manager request :: IO (CurseEnvelope CurseModResponse))
      pure ()

curseForgeCategoryIds :: Manager -> Text -> ContentSearchRequest -> IO [Int]
curseForgeCategoryIds manager apiKey request
  | null (contentSearchCategories request) = pure []
  | null wantedSlugs =
      fail ("curseforge_category_unmapped: " <> Text.unpack (Text.intercalate "," (contentSearchCategories request)))
  | otherwise =
      case curseForgeClassId (contentSearchProjectTypes request) of
        Nothing -> pure []
        Just classId -> do
          response <-
            fetchJson manager
              =<< coreRequest
                ( "https://api.curseforge.com/v1/categories"
                    <> queryString
                      [ ("gameId", Just "432")
                      , ("classId", Just (Text.pack (show classId)))
                      ]
                )
                [("x-api-key", apiKey)]
          let matchedIds =
                nub
                  [ curseCategoryId category
                  | category <- curseData (response :: CurseEnvelope [CurseCategory])
                  , maybe False ((`elem` wantedSlugs) . Text.toLower) (curseCategorySlug category)
                  ]
          if null matchedIds
            then fail ("curseforge_category_unmapped: " <> Text.unpack (Text.intercalate "," wantedSlugs))
            else pure (take 10 matchedIds)
  where
    wantedSlugs =
      map Text.toLower (concatMap curseForgeCategorySlugs (contentSearchCategories request))

curseForgeSearchQuery :: ContentSearchRequest -> String
curseForgeSearchQuery request =
  curseForgeSearchQueryWithCategoryIds request []

curseForgeSearchQueryWithCategoryIds :: ContentSearchRequest -> [Int] -> String
curseForgeSearchQueryWithCategoryIds request categoryIds =
  queryString
    ( catMaybes
        [ Just ("gameId", Just "432")
        , Just ("searchFilter", Just (contentSearchText request))
        , Just ("index", Just (Text.pack (show (contentSearchOffset request))))
        , Just ("pageSize", Just (Text.pack (show (contentSearchLimit request))))
        , Just ("sortField", Just (curseForgeSort (contentSearchSort request)))
        , Just ("sortOrder", Just "desc")
        , ("classId",) . Just . Text.pack . show <$> curseForgeClassId (contentSearchProjectTypes request)
        , curseForgeCategoryParam categoryIds
        , ("gameVersion",) . Just <$> contentSearchGameVersion request
        , ("modLoaderType",) . Just . Text.pack . show . curseForgeLoader <$> listToMaybe (contentSearchLoaders request)
        ]
    )

curseForgeCategoryParam :: [Int] -> Maybe (Text, Maybe Text)
curseForgeCategoryParam [] = Nothing
curseForgeCategoryParam [categoryId] = Just ("categoryId", Just (Text.pack (show categoryId)))
curseForgeCategoryParam categoryIds =
  Just ("categoryIds", Just (jsonText (take 10 categoryIds)))

curseForgeFilesQuery :: ContentSearchRequest -> String
curseForgeFilesQuery request =
  queryString
    ( catMaybes
        [ Just ("index", Just (Text.pack (show (contentSearchOffset request))))
        , Just ("pageSize", Just (Text.pack (show (contentSearchLimit request))))
        , ("gameVersion",) . Just <$> contentSearchGameVersion request
        , ("modLoaderType",) . Just . Text.pack . show . curseForgeLoader <$> listToMaybe (contentSearchLoaders request)
        ]
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

curseForgeSort :: Text -> Text
curseForgeSort "downloads" = "6"
curseForgeSort "updated" = "3"
curseForgeSort "newest" = "11"
curseForgeSort "follows" = "2"
curseForgeSort _ = "1"

curseForgeClassId :: [Text] -> Maybe Int
curseForgeClassId types
  | "modpack" `elem` types = Just 4471
  | "resourcePack" `elem` types = Just 12
  | "shaderPack" `elem` types = Just 6552
  | "mod" `elem` types = Just 6
  | otherwise = Nothing

curseForgeCategorySlugs :: Text -> [Text]
curseForgeCategorySlugs "performance" = ["performance"]
curseForgeCategorySlugs "library" = ["api-and-library"]
curseForgeCategorySlugs "utility" = ["utility-qol", "server-utility"]
curseForgeCategorySlugs "world-map" = ["world-gen", "map-and-information"]
curseForgeCategorySlugs "technology" = ["technology", "tech"]
curseForgeCategorySlugs "magic" = ["magic"]
curseForgeCategorySlugs "adventure" = ["adventure-and-rpg", "exploration"]
curseForgeCategorySlugs "storage" = ["storage"]
curseForgeCategorySlugs "vanilla-plus" = ["vanilla", "vanilla-plus"]
curseForgeCategorySlugs "realistic" = ["photo-realistic", "realistic"]
curseForgeCategorySlugs "16x" = ["16x"]
curseForgeCategorySlugs "32x" = ["32x"]
curseForgeCategorySlugs "64x-plus" = ["64x", "128x", "256x", "512x-and-higher"]
curseForgeCategorySlugs "lightweight" = ["small-light", "lightweight"]
curseForgeCategorySlugs "quests" = ["quests"]
curseForgeCategorySlugs raw =
  let trimmed = Text.strip raw
   in [trimmed | not (Text.null trimmed)]

curseForgeLoader :: Text -> Int
curseForgeLoader "forge" = 1
curseForgeLoader "fabric" = 4
curseForgeLoader "quilt" = 5
curseForgeLoader "neoForge" = 6
curseForgeLoader _ = 0

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
