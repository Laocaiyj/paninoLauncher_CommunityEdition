{-# LANGUAGE OverloadedStrings #-}

module Panino.Runtime.Java.Types.Requests
  ( JavaRuntimeCleanupResponse(..)
  , JavaRuntimeDeleteResponse(..)
  , JavaRuntimeImportRequest(..)
  , JavaRuntimeInstallRequest(..)
  , JavaRuntimePolicyRecord(..)
  , JavaRuntimeSelectRequest(..)
  , JavaRuntimeSelectResponse(..)
  , JavaRuntimeVerifyRequest(..)
  ) where

import Control.Applicative ((<|>))
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
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)
import Panino.Api.Types (DownloadRuntimeOptions(..), mergeDownloadRuntimeOptions)

data JavaRuntimeInstallRequest = JavaRuntimeInstallRequest
  { installRuntimeFeatureVersion :: Int
  , installRuntimeProvider :: Text
  , installRuntimeVendor :: Text
  , installRuntimeOs :: Maybe Text
  , installRuntimeArch :: Maybe Text
  , installRuntimeImageType :: Text
  , installRuntimeSetDefault :: Bool
  , installRuntimeDownload :: DownloadRuntimeOptions
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeInstallRequest where
  parseJSON =
    withObject "JavaRuntimeInstallRequest" $ \obj -> do
      legacyConcurrency <- obj .:? "concurrency"
      legacyRetryCount <- obj .:? "retryCount"
      legacyStrategy <- obj .:? "strategy"
      nestedDownload <- obj .:? "download"
      JavaRuntimeInstallRequest
        <$> (obj .: "featureVersion" <|> obj .: "version")
        <*> obj .:? "provider" .!= "adoptium"
        <*> obj .:? "vendor" .!= "temurin"
        <*> obj .:? "os"
        <*> obj .:? "arch"
        <*> obj .:? "imageType" .!= "jre"
        <*> obj .:? "setDefault" .!= False
        <*> pure (mergeDownloadRuntimeOptions legacyConcurrency legacyRetryCount legacyStrategy nestedDownload)

data JavaRuntimePolicyRecord = JavaRuntimePolicyRecord
  { policyRecordScope :: Text
  , policyRecordInstanceId :: Maybe Text
  , policyRecordPolicy :: Text
  , policyRecordPreferredRuntimeId :: Maybe Text
  , policyRecordCustomPath :: Maybe FilePath
  , policyRecordLockPatchVersion :: Bool
  , policyRecordUpdatedAt :: UTCTime
  } deriving (Eq, Show)

instance FromJSON JavaRuntimePolicyRecord where
  parseJSON =
    withObject "JavaRuntimePolicyRecord" $ \obj ->
      JavaRuntimePolicyRecord
        <$> obj .:? "scope" .!= "global"
        <*> obj .:? "instanceId"
        <*> obj .:? "policy" .!= "auto"
        <*> obj .:? "preferredRuntimeId"
        <*> obj .:? "customPath"
        <*> obj .:? "lockPatchVersion" .!= False
        <*> obj .: "updatedAt"

instance ToJSON JavaRuntimePolicyRecord where
  toJSON record =
    object
      [ "scope" .= policyRecordScope record
      , "instanceId" .= policyRecordInstanceId record
      , "policy" .= policyRecordPolicy record
      , "preferredRuntimeId" .= policyRecordPreferredRuntimeId record
      , "customPath" .= policyRecordCustomPath record
      , "lockPatchVersion" .= policyRecordLockPatchVersion record
      , "updatedAt" .= policyRecordUpdatedAt record
      ]

data JavaRuntimeSelectRequest = JavaRuntimeSelectRequest
  { selectRuntimeScope :: Text
  , selectRuntimeInstanceId :: Maybe Text
  , selectRuntimePolicy :: Text
  , selectRuntimePreferredRuntimeId :: Maybe Text
  , selectRuntimeCustomPath :: Maybe FilePath
  , selectRuntimeLockPatchVersion :: Bool
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeSelectRequest where
  parseJSON =
    withObject "JavaRuntimeSelectRequest" $ \obj ->
      JavaRuntimeSelectRequest
        <$> obj .:? "scope" .!= "global"
        <*> obj .:? "instanceId"
        <*> obj .:? "policy" .!= "auto"
        <*> obj .:? "preferredRuntimeId"
        <*> obj .:? "customPath"
        <*> obj .:? "lockPatchVersion" .!= False

data JavaRuntimeSelectResponse = JavaRuntimeSelectResponse
  { selectResponsePolicy :: JavaRuntimePolicyRecord
  , selectResponseMessage :: Text
  } deriving (Eq, Show)

instance ToJSON JavaRuntimeSelectResponse where
  toJSON response =
    object
      [ "policy" .= selectResponsePolicy response
      , "message" .= selectResponseMessage response
      ]

data JavaRuntimeImportRequest = JavaRuntimeImportRequest
  { importRuntimeSourcePath :: FilePath
  , importRuntimeProvider :: Text
  , importRuntimeVendor :: Text
  , importRuntimeFeatureVersion :: Maybe Int
  , importRuntimeOs :: Maybe Text
  , importRuntimeArch :: Maybe Text
  , importRuntimeImageType :: Text
  , importRuntimeSetDefault :: Bool
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeImportRequest where
  parseJSON =
    withObject "JavaRuntimeImportRequest" $ \obj ->
      JavaRuntimeImportRequest
        <$> (obj .: "sourcePath" <|> obj .: "path")
        <*> obj .:? "provider" .!= "local"
        <*> obj .:? "vendor" .!= "local"
        <*> obj .:? "featureVersion"
        <*> obj .:? "os"
        <*> obj .:? "arch"
        <*> obj .:? "imageType" .!= "jre"
        <*> obj .:? "setDefault" .!= False

data JavaRuntimeVerifyRequest = JavaRuntimeVerifyRequest
  { verifyRuntimeId :: Text
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeVerifyRequest where
  parseJSON =
    withObject "JavaRuntimeVerifyRequest" $ \obj ->
      JavaRuntimeVerifyRequest <$> obj .: "id"

data JavaRuntimeDeleteResponse = JavaRuntimeDeleteResponse
  { deleteRuntimeDeleted :: Bool
  , deleteRuntimeId :: Text
  , deleteRuntimeMessage :: Text
  , deleteRuntimeReferences :: [Text]
  } deriving (Eq, Show)

instance ToJSON JavaRuntimeDeleteResponse where
  toJSON response =
    object
      [ "deleted" .= deleteRuntimeDeleted response
      , "id" .= deleteRuntimeId response
      , "message" .= deleteRuntimeMessage response
      , "references" .= deleteRuntimeReferences response
      ]

data JavaRuntimeCleanupResponse = JavaRuntimeCleanupResponse
  { cleanupRuntimeDeletedRuntimeIds :: [Text]
  , cleanupRuntimeDeletedDownloadFiles :: [FilePath]
  , cleanupRuntimeDeletedStagingDirs :: [FilePath]
  , cleanupRuntimeFreedBytes :: Int64
  , cleanupRuntimeKeptRuntimeIds :: [Text]
  , cleanupRuntimeMessage :: Text
  } deriving (Eq, Show)

instance ToJSON JavaRuntimeCleanupResponse where
  toJSON response =
    object
      [ "deletedRuntimeIds" .= cleanupRuntimeDeletedRuntimeIds response
      , "deletedDownloadFiles" .= cleanupRuntimeDeletedDownloadFiles response
      , "deletedStagingDirs" .= cleanupRuntimeDeletedStagingDirs response
      , "freedBytes" .= cleanupRuntimeFreedBytes response
      , "keptRuntimeIds" .= cleanupRuntimeKeptRuntimeIds response
      , "message" .= cleanupRuntimeMessage response
      ]
