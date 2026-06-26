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
import Data.List (nub)
import Data.Maybe
  ( catMaybes
  , listToMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Http
  ( coreRequest
  , fetchJson
  , recover
  )
import Panino.Content.Online.Errors (requireCurseForgeApiKey)
import Panino.Content.Online.Normalize
  ( jsonText
  , queryString
  )
import Panino.Content.Online.CurseForge.Types
  ( CurseCategory(..)
  , CurseDependency(..)
  , CurseEnvelope(..)
  , CurseFileResponse(..)
  , CurseModResponse(..)
  , CursePagination(..)
  , curseFileToOnline
  , curseProjectToOnline
  )
import Panino.Content.Online.Types
  ( ContentProjectRequest(..)
  , ContentProjectResponse(..)
  , ContentSearchRequest(..)
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
