{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Online.Types.Request
  ( ContentLoaderRequest(..)
  , ContentProjectRequest(..)
  , ContentSearchRequest(..)
  , MinecraftPackageRequest(..)
  ) where

import Data.Aeson
  ( FromJSON(..)
  , withObject
  , (.:)
  , (.:?)
  )
import Data.Aeson.Types ((.!=))
import Data.Text (Text)
import Panino.Core.Types
  ( ProjectId
  , Url
  )

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
  , contentProjectId :: ProjectId
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
  , minecraftPackageUrl :: Url
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
