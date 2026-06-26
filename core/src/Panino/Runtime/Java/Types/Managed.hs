{-# LANGUAGE OverloadedStrings #-}

module Panino.Runtime.Java.Types.Managed
  ( JavaManagedResponse(..)
  , JavaManagedRuntime(..)
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
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (UTCTime)

data JavaManagedRuntime = JavaManagedRuntime
  { managedRuntimeId :: Text
  , managedRuntimeVendor :: Text
  , managedRuntimeProvider :: Text
  , managedRuntimeFeatureVersion :: Int
  , managedRuntimeVersion :: Text
  , managedRuntimeOs :: Text
  , managedRuntimeArch :: Text
  , managedRuntimeImageType :: Text
  , managedRuntimeJavaHome :: FilePath
  , managedRuntimeJavaExecutable :: FilePath
  , managedRuntimeSourceUrl :: Text
  , managedRuntimeSha256 :: Maybe Text
  , managedRuntimeInstalledAt :: UTCTime
  , managedRuntimeLastVerifiedAt :: Maybe UTCTime
  , managedRuntimeDiskUsageBytes :: Maybe Int64
  , managedRuntimeUsedByInstanceCount :: Int
  } deriving (Eq, Show)

instance ToJSON JavaManagedRuntime where
  toJSON runtime =
    object
      [ "id" .= managedRuntimeId runtime
      , "vendor" .= managedRuntimeVendor runtime
      , "provider" .= managedRuntimeProvider runtime
      , "featureVersion" .= managedRuntimeFeatureVersion runtime
      , "version" .= managedRuntimeVersion runtime
      , "os" .= managedRuntimeOs runtime
      , "arch" .= managedRuntimeArch runtime
      , "imageType" .= managedRuntimeImageType runtime
      , "javaHome" .= managedRuntimeJavaHome runtime
      , "javaExecutable" .= managedRuntimeJavaExecutable runtime
      , "sourceUrl" .= managedRuntimeSourceUrl runtime
      , "sha256" .= managedRuntimeSha256 runtime
      , "installedAt" .= managedRuntimeInstalledAt runtime
      , "lastVerifiedAt" .= managedRuntimeLastVerifiedAt runtime
      , "diskUsageBytes" .= managedRuntimeDiskUsageBytes runtime
      , "usedByInstanceCount" .= managedRuntimeUsedByInstanceCount runtime
      ]

instance FromJSON JavaManagedRuntime where
  parseJSON =
    withObject "JavaManagedRuntime" $ \obj ->
      JavaManagedRuntime
        <$> obj .: "id"
        <*> obj .:? "vendor" .!= "temurin"
        <*> obj .:? "provider" .!= "adoptium"
        <*> obj .: "featureVersion"
        <*> obj .:? "version" .!= ""
        <*> obj .:? "os" .!= "mac"
        <*> obj .:? "arch" .!= "aarch64"
        <*> obj .:? "imageType" .!= "jre"
        <*> obj .: "javaHome"
        <*> obj .: "javaExecutable"
        <*> obj .:? "sourceUrl" .!= ""
        <*> obj .:? "sha256"
        <*> obj .: "installedAt"
        <*> obj .:? "lastVerifiedAt"
        <*> obj .:? "diskUsageBytes"
        <*> obj .:? "usedByInstanceCount" .!= 0

data JavaManagedResponse = JavaManagedResponse
  { javaManagedRuntimes :: [JavaManagedRuntime]
  , javaManagedRoot :: FilePath
  } deriving (Eq, Show)

instance ToJSON JavaManagedResponse where
  toJSON response =
    object
      [ "runtimes" .= javaManagedRuntimes response
      , "root" .= javaManagedRoot response
      ]
