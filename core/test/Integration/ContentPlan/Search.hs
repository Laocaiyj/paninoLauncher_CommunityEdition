{-# LANGUAGE OverloadedStrings #-}

module Integration.ContentPlan.Search
  ( assertContentSearchQueries
  ) where

import Data.Aeson (eitherDecode)
import Data.List (isInfixOf)
import Panino.Content.Online.CurseForge
  ( curseForgeSearchQueryWithCategoryIds
  )
import Panino.Content.Online.Modrinth
  ( modrinthFacets
  , modrinthSearchQuery
  )
import Panino.Content.Online.Types
  ( ContentSearchRequest(..)
  )
import TestSupport (assertEqual)

assertContentSearchQueries :: IO ()
assertContentSearchQueries = do
  assertEqual
    "content search request parses categories"
    (Right ["world-map"])
    (contentSearchCategories <$> eitherDecode "{\"source\":\"modrinth\",\"categories\":[\"world-map\"]}")
  assertEqual
    "modrinth category facet keeps type version loader filters"
    (Just "[[\"project_type:mod\"],[\"versions:26.1.2\"],[\"categories:fabric\"],[\"categories:worldgen\"]]")
    (modrinthFacets categorySearchQuery)
  assertEqual
    "modrinth category search query includes facets"
    True
    ("facets=" `isInfixOf` modrinthSearchQuery categorySearchQuery)
  assertEqual
    "curseforge category id query parameter"
    True
    ("categoryId=4321" `isInfixOf` curseForgeSearchQueryWithCategoryIds categorySearchQuery [4321])

categorySearchQuery :: ContentSearchRequest
categorySearchQuery =
  ContentSearchRequest
    { contentSearchSource = "modrinth"
    , contentSearchText = "world"
    , contentSearchProjectTypes = ["mod"]
    , contentSearchCategories = ["world-map"]
    , contentSearchGameVersion = Just "26.1.2"
    , contentSearchLoaders = ["fabric"]
    , contentSearchSort = "relevance"
    , contentSearchOffset = 30
    , contentSearchLimit = 30
    , contentSearchCurseForgeApiKey = Nothing
    , contentSearchPrefetch = False
    }
