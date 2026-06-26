{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Online.Types.Minecraft
  ( LoaderMetadata(..)
  , MinecraftAssetIndex(..)
  , MinecraftDownload(..)
  , MinecraftRemoteVersion(..)
  , MinecraftVersionPackage(..)
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.Int (Int64)
import Data.Map.Strict (Map)
import Data.Text (Text)
import Data.Time (UTCTime)

data MinecraftRemoteVersion = MinecraftRemoteVersion
  { remoteVersionId :: Text
  , remoteVersionType :: Text
  , remoteVersionUrl :: Text
  , remoteVersionReleaseTime :: Maybe UTCTime
  } deriving (Eq, Show)

instance ToJSON MinecraftRemoteVersion where
  toJSON version =
    object
      [ "id" .= remoteVersionId version
      , "type" .= remoteVersionType version
      , "url" .= remoteVersionUrl version
      , "releasedAt" .= remoteVersionReleaseTime version
      ]

data MinecraftVersionPackage = MinecraftVersionPackage
  { packageId :: Text
  , packageType :: Text
  , packageJavaMajorVersion :: Maybe Int
  , packageAssetIndex :: Maybe MinecraftAssetIndex
  , packageDownloads :: Map Text MinecraftDownload
  , packageLibraryCount :: Maybe Int
  , packageNativeLibraryCount :: Int
  } deriving (Eq, Show)

instance ToJSON MinecraftVersionPackage where
  toJSON package =
    object
      [ "id" .= packageId package
      , "type" .= packageType package
      , "javaMajorVersion" .= packageJavaMajorVersion package
      , "assetIndex" .= packageAssetIndex package
      , "downloads" .= packageDownloads package
      , "libraryCount" .= packageLibraryCount package
      , "nativeLibraryCount" .= packageNativeLibraryCount package
      ]

data MinecraftAssetIndex = MinecraftAssetIndex
  { assetIndexId :: Text
  , assetIndexUrl :: Text
  , assetIndexSha1 :: Maybe Text
  , assetIndexSizeBytes :: Maybe Int64
  , assetIndexTotalSizeBytes :: Maybe Int64
  } deriving (Eq, Show)

instance ToJSON MinecraftAssetIndex where
  toJSON asset =
    object
      [ "id" .= assetIndexId asset
      , "url" .= assetIndexUrl asset
      , "sha1" .= assetIndexSha1 asset
      , "sizeBytes" .= assetIndexSizeBytes asset
      , "totalSizeBytes" .= assetIndexTotalSizeBytes asset
      ]

data MinecraftDownload = MinecraftDownload
  { downloadUrl :: Text
  , downloadSha1 :: Maybe Text
  , downloadSizeBytes :: Maybe Int64
  } deriving (Eq, Show)

instance ToJSON MinecraftDownload where
  toJSON download =
    object
      [ "url" .= downloadUrl download
      , "sha1" .= downloadSha1 download
      , "sizeBytes" .= downloadSizeBytes download
      ]

data LoaderMetadata = LoaderMetadata
  { loaderMetadataId :: Text
  , loaderMetadataSource :: Text
  , loaderMetadataMinecraftVersion :: Text
  , loaderMetadataLoaderVersion :: Text
  , loaderMetadataInstallerVersion :: Maybe Text
  , loaderMetadataStable :: Bool
  , loaderMetadataDownloadUrl :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON LoaderMetadata where
  toJSON loader =
    object
      [ "id" .= loaderMetadataId loader
      , "source" .= loaderMetadataSource loader
      , "minecraftVersion" .= loaderMetadataMinecraftVersion loader
      , "loaderVersion" .= loaderMetadataLoaderVersion loader
      , "installerVersion" .= loaderMetadataInstallerVersion loader
      , "stable" .= loaderMetadataStable loader
      , "downloadURL" .= loaderMetadataDownloadUrl loader
      ]
