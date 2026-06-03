{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TupleSections #-}

module Panino.Content.Online.Modrinth
  ( ModrinthDependency(..)
  , ModrinthFile(..)
  , ModrinthProjectResponse(..)
  , ModrinthSearchResponse(..)
  , ModrinthVersionResponse(..)
  , modrinthFacets
  , modrinthRequiredDependencyReleases
  , modrinthProject
  , modrinthSearch
  , modrinthSearchQuery
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
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Aeson.Types ((.!=))
import Data.Int (Int64)
import Data.List (foldl')
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
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Http
  ( coreRequest
  , fetchJson
  , recover
  )
import Panino.Content.Online.Normalize
  ( jsonText
  , loaderFamilies
  , normalizedCategories
  , onlineProjectType
  , queryString
  , relationText
  , releaseTypeText
  , sideSupport
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

modrinthSearch :: Manager -> ContentSearchRequest -> IO OnlineSearchPage
modrinthSearch manager request = do
  response <-
    fetchJson manager
      =<< coreRequest
        ("https://api.modrinth.com/v2/search" <> modrinthSearchQuery request)
        []
  pure
    OnlineSearchPage
      { pageSource = "modrinth"
      , pageProjects = map modrinthProjectToOnline (modrinthHits response)
      , pageTotal = modrinthTotalHits response
      , pageOffset = modrinthOffset response
      , pageLimit = modrinthLimit response
      , pageCacheStatus = Nothing
      , pageRequestId = Nothing
      , pageNextPrefetchKey = Nothing
      }

modrinthProject :: Manager -> ContentProjectRequest -> IO ContentProjectResponse
modrinthProject manager request = do
  let projectIdValue = contentProjectId request
      query = contentProjectQuery request
  (projectResponse, versionResponse) <-
    concurrently
      (projectAction projectIdValue)
      (versionAction projectIdValue query)
  void (forkIO (recover () (prefetchModrinthDependencies manager versionResponse)))
  pure (mkContentProjectResponse (modrinthProjectToOnline projectResponse) (map modrinthVersionToOnline versionResponse))
  where
    projectAction projectIdValue =
      fetchJson manager
        =<< coreRequest
          ("https://api.modrinth.com/v2/project/" <> Text.unpack projectIdValue)
        []
    versionAction projectIdValue query =
      fetchJson manager
        =<< coreRequest
          ("https://api.modrinth.com/v2/project/" <> Text.unpack projectIdValue <> "/version" <> modrinthVersionQuery query)
          []

modrinthRequiredDependencyReleases :: Manager -> ContentSearchRequest -> [OnlineDependency] -> IO [OnlineRelease]
modrinthRequiredDependencyReleases manager request dependencies =
  dedupeOnlineReleases . concat
    <$> mapConcurrently (resolveDependencyRelease []) requiredDependenciesForInstall
  where
    requiredDependenciesForInstall =
      filter isRequiredModrinthDependency dependencies

    resolveDependencyRelease visited dependency
      | any (`elem` visited) (dependencyVisitKeys dependency) = pure []
      | otherwise = do
          version <- resolveDependencyVersion dependency
          let release = modrinthVersionToOnline version
              visited' =
                dependencyVisitKeys dependency
                  <> [releaseId release, releaseProjectId release]
                  <> visited
          nested <-
            concat
              <$> mapConcurrently
                (resolveDependencyRelease visited')
                (filter isRequiredModrinthDependency (releaseDependencies release))
          pure (nested <> [release])

    resolveDependencyVersion dependency =
      case dependencyVersionId dependency of
        Just versionId -> modrinthVersionById manager versionId
        Nothing ->
          case dependencyProjectId dependency of
            Just project -> do
              versions <- modrinthProjectVersions manager request project
              case versions of
                version:_ -> pure version
                [] ->
                  fail
                    ( "no compatible Modrinth dependency release found for "
                        <> Text.unpack project
                    )
            Nothing ->
              fail "Modrinth required dependency is missing projectId and versionId"

modrinthProjectVersions :: Manager -> ContentSearchRequest -> Text -> IO [ModrinthVersionResponse]
modrinthProjectVersions manager request projectIdValue =
  fetchJson manager
    =<< coreRequest
      ("https://api.modrinth.com/v2/project/" <> Text.unpack projectIdValue <> "/version" <> modrinthVersionQuery request)
      []

modrinthVersionById :: Manager -> Text -> IO ModrinthVersionResponse
modrinthVersionById manager versionId =
  fetchJson manager
    =<< coreRequest
      ("https://api.modrinth.com/v2/version/" <> Text.unpack versionId)
      []

isRequiredModrinthDependency :: OnlineDependency -> Bool
isRequiredModrinthDependency dependency =
  Text.toLower (dependencySource dependency) == "modrinth"
    && Text.toLower (dependencyRelation dependency) == "required"

dependencyVisitKeys :: OnlineDependency -> [Text]
dependencyVisitKeys dependency =
  catMaybes
    [ Just (dependencyId dependency)
    , dependencyProjectId dependency
    , dependencyVersionId dependency
    ]

dedupeOnlineReleases :: [OnlineRelease] -> [OnlineRelease]
dedupeOnlineReleases =
  foldl' insertRelease []
  where
    insertRelease releases release
      | any ((== releaseId release) . releaseId) releases = releases
      | otherwise = releases <> [release]

prefetchModrinthDependencies :: Manager -> [ModrinthVersionResponse] -> IO ()
prefetchModrinthDependencies manager versions =
  void (mapConcurrently prefetch (take 12 dependencyUrls))
  where
    dependencyUrls =
      concatMap dependencyRequestUrls $
        filter ((== "required") . Text.toLower . modrinthDependencyType) $
          concatMap modrinthDependencies versions
    dependencyRequestUrls dependency =
      catMaybes
        [ (\versionId -> "https://api.modrinth.com/v2/version/" <> Text.unpack versionId) <$> modrinthDependencyVersionId dependency
        , (\depProject -> "https://api.modrinth.com/v2/project/" <> Text.unpack depProject) <$> modrinthDependencyProjectId dependency
        ]
    prefetch url = do
      _ <- (fetchJson manager =<< coreRequest url [] :: IO Value)
      pure ()

modrinthSearchQuery :: ContentSearchRequest -> String
modrinthSearchQuery request =
  queryString
    ( [ ("query", Just (contentSearchText request))
      , ("offset", Just (Text.pack (show (contentSearchOffset request))))
      , ("limit", Just (Text.pack (show (contentSearchLimit request))))
      , ("index", Just (modrinthSort (contentSearchSort request)))
      ]
        <> maybe [] (\facets -> [("facets", Just facets)]) (modrinthFacets request)
    )

modrinthVersionQuery :: ContentSearchRequest -> String
modrinthVersionQuery request =
  queryString
    ( catMaybes
        [ if null (contentSearchLoaders request)
            then Nothing
            else Just ("loaders", Just (jsonText (map modrinthLoader (contentSearchLoaders request))))
        , ("game_versions",) . Just . jsonText . (: []) <$> contentSearchGameVersion request
        ]
    )

modrinthFacets :: ContentSearchRequest -> Maybe Text
modrinthFacets request =
  if null facets
    then Nothing
    else Just (jsonText facets)
  where
    facets =
      catMaybes
        [ if null (contentSearchProjectTypes request)
            then Nothing
            else Just (map (("project_type:" <>) . modrinthProjectType) (contentSearchProjectTypes request))
        , (\version -> ["versions:" <> version]) <$> contentSearchGameVersion request
        , if null (contentSearchLoaders request)
            then Nothing
            else Just (map (("categories:" <>) . modrinthLoader) (contentSearchLoaders request))
        , if null categorySlugs
            then Nothing
            else Just (map ("categories:" <>) categorySlugs)
        ]
    categorySlugs =
      concatMap modrinthCategorySlugs (contentSearchCategories request)

modrinthCategorySlugs :: Text -> [Text]
modrinthCategorySlugs "performance" = ["optimization"]
modrinthCategorySlugs "library" = ["library"]
modrinthCategorySlugs "utility" = ["utility"]
modrinthCategorySlugs "world-map" = ["worldgen"]
modrinthCategorySlugs "technology" = ["technology"]
modrinthCategorySlugs "magic" = ["magic"]
modrinthCategorySlugs "adventure" = ["adventure"]
modrinthCategorySlugs "storage" = ["storage"]
modrinthCategorySlugs "vanilla-plus" = ["vanilla-like"]
modrinthCategorySlugs "realistic" = ["realistic"]
modrinthCategorySlugs "ui-font" = ["font"]
modrinthCategorySlugs "16x" = ["16x"]
modrinthCategorySlugs "32x" = ["32x"]
modrinthCategorySlugs "64x-plus" = ["64x", "128x", "256x", "512x"]
modrinthCategorySlugs "pbr" = ["pbr"]
modrinthCategorySlugs "lightweight" = ["lightweight", "low"]
modrinthCategorySlugs "balanced" = ["medium"]
modrinthCategorySlugs "high-quality" = ["high"]
modrinthCategorySlugs "quests" = ["quests"]
modrinthCategorySlugs raw =
  let trimmed = Text.strip raw
   in [trimmed | not (Text.null trimmed)]

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

modrinthSort :: Text -> Text
modrinthSort "downloads" = "downloads"
modrinthSort "updated" = "updated"
modrinthSort "newest" = "newest"
modrinthSort "follows" = "follows"
modrinthSort _ = "relevance"

modrinthProjectType :: Text -> Text
modrinthProjectType "resourcePack" = "resourcepack"
modrinthProjectType "shaderPack" = "shader"
modrinthProjectType "modpack" = "modpack"
modrinthProjectType _ = "mod"

modrinthLoader :: Text -> Text
modrinthLoader "neoForge" = "neoforge"
modrinthLoader other = Text.toLower other
