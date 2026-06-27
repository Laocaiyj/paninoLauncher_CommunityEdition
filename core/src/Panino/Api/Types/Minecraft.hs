{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Types.Minecraft
  ( InstallRequest(..)
  , LaunchRequest(..)
  , installRequestGameDirPath
  , installRequestVersionText
  , launchRequestGameDirPath
  , launchRequestVersionText
  ) where

import Data.Aeson
  ( FromJSON(..)
  , Object
  , withObject
  , (.:)
  , (.:?)
  )
import qualified Data.Aeson.Key as Key
import Data.Aeson.Types (Parser)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Types.Download
  ( DownloadRuntimeOptions
  , mergeDownloadRuntimeOptions
  )
import Panino.Core.Types
  ( GameDir
  , VersionId
  , gameDirFromPath
  , gameDirPath
  , versionIdText
  )
import Panino.Launch.Tuning.Types
  ( JvmTuningPolicy
  , MemoryPolicy
  )

data InstallRequest = InstallRequest
  { installRequestVersion :: VersionId
  , installRequestGameDir :: Maybe GameDir
  , installRequestLoader :: Maybe Text
  , installRequestLoaderVersion :: Maybe Text
  , installRequestShaderLoader :: Maybe Text
  , installRequestShaderVersion :: Maybe Text
  , installRequestInstanceName :: Maybe Text
  , installRequestDownload :: DownloadRuntimeOptions
  } deriving (Eq, Show)

instance FromJSON InstallRequest where
  parseJSON =
    withObject "InstallRequest" $ \objectValue -> do
      legacyConcurrency <- objectValue .:? "concurrency"
      legacyRetryCount <- objectValue .:? "retryCount"
      legacyStrategy <- objectValue .:? "strategy"
      nestedDownload <- objectValue .:? "download"
      InstallRequest
        <$> objectValue .: "version"
        <*> parseOptionalGameDir objectValue "gameDir"
        <*> objectValue .:? "loader"
        <*> objectValue .:? "loaderVersion"
        <*> objectValue .:? "shaderLoader"
        <*> objectValue .:? "shaderVersion"
        <*> objectValue .:? "instanceName"
        <*> pure (mergeDownloadRuntimeOptions legacyConcurrency legacyRetryCount legacyStrategy nestedDownload)

data LaunchRequest = LaunchRequest
  { launchRequestVersion :: VersionId
  , launchRequestGameDir :: Maybe GameDir
  , launchRequestMemoryMb :: Maybe Int
  , launchRequestJavaPath :: Maybe FilePath
  , launchRequestInstanceId :: Maybe Text
  , launchRequestLoader :: Maybe Text
  , launchRequestMemoryPolicy :: Maybe MemoryPolicy
  , launchRequestJvmProfile :: Maybe JvmTuningPolicy
  , launchRequestCustomMemoryMb :: Maybe Int
  , launchRequestUsername :: Maybe Text
  , launchRequestUuid :: Maybe Text
  , launchRequestAccessToken :: Maybe Text
  , launchRequestJvmArgs :: [Text]
  , launchRequestCustomJvmArgs :: [Text]
  , launchRequestModCount :: Maybe Int
  , launchRequestResourcePackCount :: Maybe Int
  , launchRequestShaderPackCount :: Maybe Int
  , launchRequestWindowWidth :: Maybe Int
  , launchRequestWindowHeight :: Maybe Int
  , launchRequestDownload :: DownloadRuntimeOptions
  , launchRequestInstallBefore :: Maybe Bool
  } deriving (Eq, Show)

instance FromJSON LaunchRequest where
  parseJSON =
    withObject "LaunchRequest" $ \objectValue -> do
      legacyConcurrency <- objectValue .:? "concurrency"
      legacyRetryCount <- objectValue .:? "retryCount"
      legacyStrategy <- objectValue .:? "strategy"
      nestedDownload <- objectValue .:? "download"
      jvmArgs <- fromMaybe [] <$> objectValue .:? "jvmArgs"
      customJvmArgs <- fromMaybe [] <$> objectValue .:? "customJvmArgs"
      LaunchRequest
        <$> objectValue .: "version"
        <*> parseOptionalGameDir objectValue "gameDir"
        <*> objectValue .:? "memoryMb"
        <*> objectValue .:? "java"
        <*> objectValue .:? "instanceId"
        <*> objectValue .:? "loader"
        <*> objectValue .:? "memoryPolicy"
        <*> objectValue .:? "jvmProfile"
        <*> objectValue .:? "customMemoryMb"
        <*> objectValue .:? "username"
        <*> objectValue .:? "uuid"
        <*> objectValue .:? "accessToken"
        <*> pure jvmArgs
        <*> pure customJvmArgs
        <*> objectValue .:? "modCount"
        <*> objectValue .:? "resourcePackCount"
        <*> objectValue .:? "shaderPackCount"
        <*> objectValue .:? "windowWidth"
        <*> objectValue .:? "windowHeight"
        <*> pure (mergeDownloadRuntimeOptions legacyConcurrency legacyRetryCount legacyStrategy nestedDownload)
        <*> objectValue .:? "install"

installRequestVersionText :: InstallRequest -> Text
installRequestVersionText =
  versionIdText . installRequestVersion

installRequestGameDirPath :: InstallRequest -> Maybe FilePath
installRequestGameDirPath =
  fmap gameDirPath . installRequestGameDir

launchRequestVersionText :: LaunchRequest -> Text
launchRequestVersionText =
  versionIdText . launchRequestVersion

launchRequestGameDirPath :: LaunchRequest -> Maybe FilePath
launchRequestGameDirPath =
  fmap gameDirPath . launchRequestGameDir

parseOptionalGameDir :: Object -> Text -> Parser (Maybe GameDir)
parseOptionalGameDir objectValue key = do
  raw <- objectValue .:? Key.fromText key
  pure (raw >>= gameDirFromPath . Text.unpack)
