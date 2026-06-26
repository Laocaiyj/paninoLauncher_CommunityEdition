{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.MinecraftStatus.Types
  ( MinecraftInstallStatusRequest(..)
  , MinecraftInstalledInstance(..)
  , MinecraftVersionInstallStatus(..)
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Maybe (fromMaybe)
import Data.Text (Text)

data MinecraftInstallStatusRequest = MinecraftInstallStatusRequest
  { installStatusVersionIds :: [Text]
  , installStatusGameDirs :: [FilePath]
  } deriving (Eq, Show)

instance FromJSON MinecraftInstallStatusRequest where
  parseJSON =
    withObject "MinecraftInstallStatusRequest" $ \objectValue ->
      MinecraftInstallStatusRequest
        <$> objectValue .: "versionIds"
        <*> (fromMaybe [] <$> objectValue .:? "gameDirs")

data MinecraftVersionInstallStatus = MinecraftVersionInstallStatus
  { minecraftStatusVersionId :: Text
  , minecraftStatusInstalled :: Bool
  , minecraftStatusVersionJson :: Bool
  , minecraftStatusClientJar :: Bool
  , minecraftStatusDiskUsageBytes :: Maybe Integer
  , minecraftStatusInstallRoot :: Maybe FilePath
  , minecraftStatusArchived :: Bool
  , minecraftStatusArchivePath :: Maybe FilePath
  } deriving (Eq, Show)

instance ToJSON MinecraftVersionInstallStatus where
  toJSON status =
    object
      [ "versionId" .= minecraftStatusVersionId status
      , "installed" .= minecraftStatusInstalled status
      , "versionJson" .= minecraftStatusVersionJson status
      , "clientJar" .= minecraftStatusClientJar status
      , "diskUsageBytes" .= minecraftStatusDiskUsageBytes status
      , "installRoot" .= minecraftStatusInstallRoot status
      , "archived" .= minecraftStatusArchived status
      , "archivePath" .= minecraftStatusArchivePath status
      ]

data MinecraftInstalledInstance = MinecraftInstalledInstance
  { installedInstanceVersionId :: Text
  , installedInstanceMinecraftVersion :: Text
  , installedInstanceLoader :: Maybe Text
  , installedInstanceLoaderVersion :: Maybe Text
  , installedInstanceName :: Maybe Text
  , installedInstanceGameDir :: FilePath
  , installedInstanceVersionJson :: Bool
  , installedInstanceClientJar :: Bool
  , installedInstanceDiskUsageBytes :: Maybe Integer
  , installedInstanceArchived :: Bool
  , installedInstanceArchivePath :: Maybe FilePath
  , installedInstanceInstallState :: Maybe Text
  , installedInstanceIncompleteReason :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON MinecraftInstalledInstance where
  toJSON instanceValue =
    object
      [ "versionId" .= installedInstanceVersionId instanceValue
      , "minecraftVersion" .= installedInstanceMinecraftVersion instanceValue
      , "loader" .= installedInstanceLoader instanceValue
      , "loaderVersion" .= installedInstanceLoaderVersion instanceValue
      , "name" .= installedInstanceName instanceValue
      , "gameDir" .= installedInstanceGameDir instanceValue
      , "versionJson" .= installedInstanceVersionJson instanceValue
      , "clientJar" .= installedInstanceClientJar instanceValue
      , "diskUsageBytes" .= installedInstanceDiskUsageBytes instanceValue
      , "archived" .= installedInstanceArchived instanceValue
      , "archivePath" .= installedInstanceArchivePath instanceValue
      , "installState" .= installedInstanceInstallState instanceValue
      , "incompleteReason" .= installedInstanceIncompleteReason instanceValue
      ]
