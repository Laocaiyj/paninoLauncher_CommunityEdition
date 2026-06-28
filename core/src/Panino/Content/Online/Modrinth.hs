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

import Control.Concurrent (forkIO)
import Control.Concurrent.Async
  ( concurrently
  , mapConcurrently
  )
import Control.Monad (void)
import Data.Aeson (Value)
import Data.List (foldl')
import Data.Maybe
  ( catMaybes
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Http
  ( coreRequest
  , fetchJson
  , recover
  )
import Panino.Content.Online.Modrinth.Types
  ( ModrinthDependency(..)
  , ModrinthFile(..)
  , ModrinthProjectResponse(..)
  , ModrinthSearchResponse(..)
  , ModrinthVersionResponse(..)
  , modrinthProjectToOnline
  , modrinthProjectType
  , modrinthVersionToOnline
  )
import Panino.Content.Online.Normalize
  ( jsonText
  , queryString
  )
import Panino.Content.Online.Types
  ( ContentProjectRequest(..)
  , ContentProjectResponse(..)
  , ContentSearchRequest(..)
  , OnlineDependency(..)
  , OnlineRelease(..)
  , OnlineSearchPage(..)
  , mkContentProjectResponse
  , onlineDependencyProjectIdText
  , onlineDependencyVersionIdText
  , onlineReleaseIdText
  , onlineReleaseProjectIdText
  )
import Panino.Core.Types
  ( ProjectId
  , VersionId
  , projectIdText
  , versionIdText
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
                  <> [onlineReleaseIdText release, onlineReleaseProjectIdText release]
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
                        <> Text.unpack (projectIdText project)
                    )
            Nothing ->
              fail "Modrinth required dependency is missing projectId and versionId"

modrinthProjectVersions :: Manager -> ContentSearchRequest -> ProjectId -> IO [ModrinthVersionResponse]
modrinthProjectVersions manager request projectIdValue =
  fetchJson manager
    =<< coreRequest
      ("https://api.modrinth.com/v2/project/" <> Text.unpack (projectIdText projectIdValue) <> "/version" <> modrinthVersionQuery request)
      []

modrinthVersionById :: Manager -> VersionId -> IO ModrinthVersionResponse
modrinthVersionById manager versionId =
  fetchJson manager
    =<< coreRequest
      ("https://api.modrinth.com/v2/version/" <> Text.unpack (versionIdText versionId))
      []

isRequiredModrinthDependency :: OnlineDependency -> Bool
isRequiredModrinthDependency dependency =
  Text.toLower (dependencySource dependency) == "modrinth"
    && Text.toLower (dependencyRelation dependency) == "required"

dependencyVisitKeys :: OnlineDependency -> [Text]
dependencyVisitKeys dependency =
  catMaybes
    [ Just (dependencyId dependency)
    , onlineDependencyProjectIdText dependency
    , onlineDependencyVersionIdText dependency
    ]

dedupeOnlineReleases :: [OnlineRelease] -> [OnlineRelease]
dedupeOnlineReleases =
  foldl' insertRelease []
  where
    insertRelease releases release
      | any ((== onlineReleaseIdText release) . onlineReleaseIdText) releases = releases
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
        [ (\versionId -> "https://api.modrinth.com/v2/version/" <> Text.unpack (versionIdText versionId)) <$> modrinthDependencyVersionId dependency
        , (\depProject -> "https://api.modrinth.com/v2/project/" <> Text.unpack (projectIdText depProject)) <$> modrinthDependencyProjectId dependency
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

modrinthSort :: Text -> Text
modrinthSort "downloads" = "downloads"
modrinthSort "updated" = "updated"
modrinthSort "newest" = "newest"
modrinthSort "follows" = "follows"
modrinthSort _ = "relevance"

modrinthLoader :: Text -> Text
modrinthLoader "neoForge" = "neoforge"
modrinthLoader other = Text.toLower other
