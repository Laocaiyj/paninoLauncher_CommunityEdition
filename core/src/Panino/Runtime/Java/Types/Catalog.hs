{-# LANGUAGE OverloadedStrings #-}

module Panino.Runtime.Java.Types.Catalog
  ( JavaRuntimeCatalogItem(..)
  , JavaRuntimeDownloadSpec(..)
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Text (Text)
import Data.Time (UTCTime)

data JavaRuntimeDownloadSpec = JavaRuntimeDownloadSpec
  { runtimeDownloadProvider :: Text
  , runtimeDownloadVendor :: Text
  , runtimeDownloadFeatureVersion :: Int
  , runtimeDownloadOs :: Text
  , runtimeDownloadArch :: Text
  , runtimeDownloadImageType :: Text
  , runtimeDownloadUrl :: Text
  , runtimeDownloadChecksumUrl :: Maybe Text
  , runtimeDownloadSha256 :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeDownloadSpec where
  parseJSON =
    withObject "JavaRuntimeDownloadSpec" $ \obj ->
      JavaRuntimeDownloadSpec
        <$> obj .:? "provider" .!= "adoptium"
        <*> obj .:? "vendor" .!= "temurin"
        <*> obj .: "featureVersion"
        <*> obj .:? "os" .!= "mac"
        <*> obj .:? "arch" .!= "aarch64"
        <*> obj .:? "imageType" .!= "jre"
        <*> obj .: "url"
        <*> obj .:? "checksumUrl"
        <*> obj .:? "sha256"

instance ToJSON JavaRuntimeDownloadSpec where
  toJSON spec =
    object
      [ "provider" .= runtimeDownloadProvider spec
      , "vendor" .= runtimeDownloadVendor spec
      , "featureVersion" .= runtimeDownloadFeatureVersion spec
      , "os" .= runtimeDownloadOs spec
      , "arch" .= runtimeDownloadArch spec
      , "imageType" .= runtimeDownloadImageType spec
      , "url" .= runtimeDownloadUrl spec
      , "checksumUrl" .= runtimeDownloadChecksumUrl spec
      , "sha256" .= runtimeDownloadSha256 spec
      ]

data JavaRuntimeCatalogItem = JavaRuntimeCatalogItem
  { catalogRuntimeId :: Text
  , catalogRuntimeName :: Text
  , catalogRuntimeProvider :: Text
  , catalogRuntimeVendor :: Text
  , catalogRuntimeFeatureVersion :: Int
  , catalogRuntimeOs :: Text
  , catalogRuntimeArch :: Text
  , catalogRuntimeImageType :: Text
  , catalogRuntimeDownload :: JavaRuntimeDownloadSpec
  , catalogRuntimeStale :: Bool
  , catalogRuntimeCachedAt :: Maybe UTCTime
  , catalogRuntimeWarnings :: [Text]
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeCatalogItem where
  parseJSON =
    withObject "JavaRuntimeCatalogItem" $ \obj ->
      JavaRuntimeCatalogItem
        <$> obj .: "id"
        <*> obj .: "name"
        <*> obj .:? "provider" .!= "adoptium"
        <*> obj .:? "vendor" .!= "temurin"
        <*> obj .: "featureVersion"
        <*> obj .:? "os" .!= "mac"
        <*> obj .:? "arch" .!= "aarch64"
        <*> obj .:? "imageType" .!= "jre"
        <*> obj .: "download"
        <*> obj .:? "stale" .!= False
        <*> obj .:? "cachedAt"
        <*> obj .:? "warnings" .!= []

instance ToJSON JavaRuntimeCatalogItem where
  toJSON item =
    object
      [ "id" .= catalogRuntimeId item
      , "name" .= catalogRuntimeName item
      , "provider" .= catalogRuntimeProvider item
      , "vendor" .= catalogRuntimeVendor item
      , "featureVersion" .= catalogRuntimeFeatureVersion item
      , "os" .= catalogRuntimeOs item
      , "arch" .= catalogRuntimeArch item
      , "imageType" .= catalogRuntimeImageType item
      , "download" .= catalogRuntimeDownload item
      , "stale" .= catalogRuntimeStale item
      , "cachedAt" .= catalogRuntimeCachedAt item
      , "warnings" .= catalogRuntimeWarnings item
      ]
