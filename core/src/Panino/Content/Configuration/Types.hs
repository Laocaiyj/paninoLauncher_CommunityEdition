{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Configuration.Types
  ( ConfigurationCapabilities(..)
  , ExportBackupPreflightRequest(..)
  , ExportBackupPreflightResponse(..)
  , GameConfigurationRequest(..)
  , LaunchContentSummary(..)
  , LaunchInstanceSummary(..)
  , LaunchLibraryRequest(..)
  , LaunchLibraryResponse(..)
  , LoaderCompatibilityEntry(..)
  , LoaderCompatibilityRequest(..)
  , LoaderCompatibilityResponse(..)
  , ModpackPreflightRequest(..)
  , ModpackPreflightResponse(..)
  , ModpackImportLockEntry(..)
  , ModpackImportRequest(..)
  , ModpackImportResponse(..)
  , VersionSwitchPreflightRequest(..)
  , VersionSwitchPreflightResponse(..)
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
import Panino.Install.Plan.Types (TypedInstallPlan)
import Panino.Launch.Tuning.Types
  ( JvmTuningPolicy(..)
  , MemoryPolicy(..)
  )

data GameConfigurationRequest = GameConfigurationRequest
  { configRequestId :: Maybe Text
  , configRequestName :: Text
  , configRequestMinecraftVersion :: Text
  , configRequestLoader :: Maybe Text
  , configRequestLoaderVersion :: Maybe Text
  , configRequestGameDir :: FilePath
  , configRequestJavaPath :: Maybe FilePath
  , configRequestMemoryMb :: Int
  , configRequestMemoryPolicy :: MemoryPolicy
  , configRequestJvmProfile :: JvmTuningPolicy
  , configRequestCustomMemoryMb :: Maybe Int
  , configRequestCustomJvmArgs :: [Text]
  , configRequestStatus :: Maybe Text
  , configRequestIsFavorite :: Bool
  , configRequestLastLaunchedAt :: Maybe Text
  , configRequestLastLaunchState :: Maybe Text
  , configRequestLaunchCount :: Int
  , configRequestHiddenFromRecent :: Bool
  } deriving (Eq, Show)

instance FromJSON GameConfigurationRequest where
  parseJSON =
    withObject "GameConfigurationRequest" $ \obj ->
      GameConfigurationRequest
        <$> obj .:? "id"
        <*> obj .: "name"
        <*> obj .: "minecraftVersion"
        <*> obj .:? "loader"
        <*> obj .:? "loaderVersion"
        <*> obj .: "gameDir"
        <*> obj .:? "javaPath"
        <*> obj .:? "memoryMb" .!= 4096
        <*> obj .:? "memoryPolicy" .!= MemoryPolicyCustom
        <*> obj .:? "jvmProfile" .!= JvmTuningCustom
        <*> obj .:? "customMemoryMb"
        <*> obj .:? "customJvmArgs" .!= []
        <*> obj .:? "status"
        <*> obj .:? "isFavorite" .!= False
        <*> obj .:? "lastLaunchedAt"
        <*> obj .:? "lastLaunchState"
        <*> obj .:? "launchCount" .!= 0
        <*> obj .:? "isHiddenFromRecent" .!= False

newtype LaunchLibraryRequest = LaunchLibraryRequest
  { launchLibraryConfigurations :: [GameConfigurationRequest]
  } deriving (Eq, Show)

instance FromJSON LaunchLibraryRequest where
  parseJSON =
    withObject "LaunchLibraryRequest" $ \obj ->
      LaunchLibraryRequest <$> obj .:? "configurations" .!= []

data LaunchContentSummary = LaunchContentSummary
  { launchContentModCount :: Int
  , launchContentResourcePackCount :: Int
  , launchContentShaderPackCount :: Int
  , launchContentSaveCount :: Int
  , launchContentLogCount :: Int
  , launchContentConflictCount :: Int
  , launchContentWarningCount :: Int
  } deriving (Eq, Show)

instance ToJSON LaunchContentSummary where
  toJSON summary =
    object
      [ "modCount" .= launchContentModCount summary
      , "resourcePackCount" .= launchContentResourcePackCount summary
      , "shaderPackCount" .= launchContentShaderPackCount summary
      , "saveCount" .= launchContentSaveCount summary
      , "logCount" .= launchContentLogCount summary
      , "conflictCount" .= launchContentConflictCount summary
      , "warningCount" .= launchContentWarningCount summary
      ]

data LaunchInstanceSummary = LaunchInstanceSummary
  { launchInstanceId :: Maybe Text
  , launchInstanceName :: Text
  , launchInstanceMinecraftVersion :: Text
  , launchInstanceLoader :: Maybe Text
  , launchInstanceGameDir :: FilePath
  , launchInstanceStatus :: Text
  , launchInstanceCanLaunch :: Bool
  , launchInstanceNeedsAttention :: Bool
  , launchInstanceAttentionReasons :: [Text]
  , launchInstanceIsFavorite :: Bool
  , launchInstanceLastLaunchedAt :: Maybe Text
  , launchInstanceLastLaunchState :: Maybe Text
  , launchInstanceLaunchCount :: Int
  , launchInstanceHiddenFromRecent :: Bool
  , launchInstanceInstalledAt :: Maybe UTCTime
  , launchInstanceContent :: LaunchContentSummary
  , launchInstanceDiskUsageBytes :: Maybe Int64
  } deriving (Eq, Show)

instance ToJSON LaunchInstanceSummary where
  toJSON summary =
    object
      [ "id" .= launchInstanceId summary
      , "name" .= launchInstanceName summary
      , "minecraftVersion" .= launchInstanceMinecraftVersion summary
      , "loader" .= launchInstanceLoader summary
      , "gameDir" .= launchInstanceGameDir summary
      , "status" .= launchInstanceStatus summary
      , "canLaunch" .= launchInstanceCanLaunch summary
      , "needsAttention" .= launchInstanceNeedsAttention summary
      , "attentionReasons" .= launchInstanceAttentionReasons summary
      , "isFavorite" .= launchInstanceIsFavorite summary
      , "lastLaunchedAt" .= launchInstanceLastLaunchedAt summary
      , "lastLaunchState" .= launchInstanceLastLaunchState summary
      , "launchCount" .= launchInstanceLaunchCount summary
      , "isHiddenFromRecent" .= launchInstanceHiddenFromRecent summary
      , "installedAt" .= launchInstanceInstalledAt summary
      , "content" .= launchInstanceContent summary
      , "diskUsageBytes" .= launchInstanceDiskUsageBytes summary
      ]

data LaunchLibraryResponse = LaunchLibraryResponse
  { launchLibraryInstances :: [LaunchInstanceSummary]
  , launchLibraryTotalCount :: Int
  , launchLibraryReadyCount :: Int
  , launchLibraryAttentionCount :: Int
  , launchLibraryRecentIds :: [Text]
  , launchLibraryRecentInstallIds :: [Text]
  , launchLibraryFavoriteIds :: [Text]
  , launchLibraryAttentionIds :: [Text]
  } deriving (Eq, Show)

instance ToJSON LaunchLibraryResponse where
  toJSON response =
    object
      [ "instances" .= launchLibraryInstances response
      , "totalCount" .= launchLibraryTotalCount response
      , "readyCount" .= launchLibraryReadyCount response
      , "attentionCount" .= launchLibraryAttentionCount response
      , "recentIds" .= launchLibraryRecentIds response
      , "recentInstallIds" .= launchLibraryRecentInstallIds response
      , "favoriteIds" .= launchLibraryFavoriteIds response
      , "attentionIds" .= launchLibraryAttentionIds response
      ]

data ConfigurationCapabilities = ConfigurationCapabilities
  { capabilityCanLaunch :: Bool
  , capabilityCanManageMods :: Bool
  , capabilityCanManageResourcePacks :: Bool
  , capabilityCanManageShaderPacks :: Bool
  , capabilityCanInstallLoader :: Bool
  , capabilityCanExportModpack :: Bool
  , capabilityCanBackupSaves :: Bool
  , capabilityCanRepair :: Bool
  , capabilityReasons :: [Text]
  } deriving (Eq, Show)

instance ToJSON ConfigurationCapabilities where
  toJSON capabilities =
    object
      [ "canLaunch" .= capabilityCanLaunch capabilities
      , "canManageMods" .= capabilityCanManageMods capabilities
      , "canManageResourcePacks" .= capabilityCanManageResourcePacks capabilities
      , "canManageShaderPacks" .= capabilityCanManageShaderPacks capabilities
      , "canInstallLoader" .= capabilityCanInstallLoader capabilities
      , "canExportModpack" .= capabilityCanExportModpack capabilities
      , "canBackupSaves" .= capabilityCanBackupSaves capabilities
      , "canRepair" .= capabilityCanRepair capabilities
      , "reasons" .= capabilityReasons capabilities
      ]

newtype LoaderCompatibilityRequest = LoaderCompatibilityRequest
  { loaderCompatibilityMinecraftVersion :: Text
  } deriving (Eq, Show)

instance FromJSON LoaderCompatibilityRequest where
  parseJSON =
    withObject "LoaderCompatibilityRequest" $ \obj ->
      LoaderCompatibilityRequest <$> obj .: "minecraftVersion"

data LoaderCompatibilityEntry = LoaderCompatibilityEntry
  { loaderEntryLoader :: Text
  , loaderEntryAvailable :: Bool
  , loaderEntryRecommendedVersion :: Maybe Text
  , loaderEntryVersions :: [Text]
  , loaderEntryReason :: Maybe Text
  , loaderEntryExperimental :: Bool
  } deriving (Eq, Show)

instance ToJSON LoaderCompatibilityEntry where
  toJSON entry =
    object
      [ "loader" .= loaderEntryLoader entry
      , "available" .= loaderEntryAvailable entry
      , "recommendedVersion" .= loaderEntryRecommendedVersion entry
      , "versions" .= loaderEntryVersions entry
      , "reason" .= loaderEntryReason entry
      , "experimental" .= loaderEntryExperimental entry
      ]

data LoaderCompatibilityResponse = LoaderCompatibilityResponse
  { loaderResponseMinecraftVersion :: Text
  , loaderResponseOptions :: [LoaderCompatibilityEntry]
  } deriving (Eq, Show)

instance ToJSON LoaderCompatibilityResponse where
  toJSON response =
    object
      [ "minecraftVersion" .= loaderResponseMinecraftVersion response
      , "options" .= loaderResponseOptions response
      ]

data VersionSwitchPreflightRequest = VersionSwitchPreflightRequest
  { switchPreflightConfiguration :: GameConfigurationRequest
  , switchPreflightTargetMinecraftVersion :: Text
  } deriving (Eq, Show)

instance FromJSON VersionSwitchPreflightRequest where
  parseJSON =
    withObject "VersionSwitchPreflightRequest" $ \obj ->
      VersionSwitchPreflightRequest
        <$> obj .: "configuration"
        <*> obj .: "targetMinecraftVersion"

data VersionSwitchPreflightResponse = VersionSwitchPreflightResponse
  { switchPreflightAllowed :: Bool
  , switchPreflightRecommendedAction :: Text
  , switchPreflightWarnings :: [Text]
  , switchPreflightBlockingReasons :: [Text]
  , switchPreflightCapabilities :: ConfigurationCapabilities
  } deriving (Eq, Show)

instance ToJSON VersionSwitchPreflightResponse where
  toJSON response =
    object
      [ "allowed" .= switchPreflightAllowed response
      , "recommendedAction" .= switchPreflightRecommendedAction response
      , "warnings" .= switchPreflightWarnings response
      , "blockingReasons" .= switchPreflightBlockingReasons response
      , "capabilities" .= switchPreflightCapabilities response
      ]

data ModpackPreflightRequest = ModpackPreflightRequest
  { modpackPreflightSourceType :: Text
  , modpackPreflightSourcePath :: Maybe FilePath
  , modpackPreflightTargetGameDir :: Maybe FilePath
  } deriving (Eq, Show)

instance FromJSON ModpackPreflightRequest where
  parseJSON =
    withObject "ModpackPreflightRequest" $ \obj ->
      ModpackPreflightRequest
        <$> obj .:? "sourceType" .!= "local"
        <*> obj .:? "sourcePath"
        <*> obj .:? "targetGameDir"

data ModpackPreflightResponse = ModpackPreflightResponse
  { modpackPreflightValid :: Bool
  , modpackPreflightName :: Maybe Text
  , modpackPreflightMinecraftVersion :: Maybe Text
  , modpackPreflightLoader :: Maybe Text
  , modpackPreflightLoaderVersion :: Maybe Text
  , modpackPreflightModCount :: Int
  , modpackPreflightResourcePackCount :: Int
  , modpackPreflightShaderPackCount :: Int
  , modpackPreflightOverridesCount :: Int
  , modpackPreflightEstimatedDownloadBytes :: Maybe Int64
  , modpackPreflightRequiresApiKey :: Bool
  , modpackPreflightWarnings :: [Text]
  , modpackPreflightBlockingReasons :: [Text]
  , modpackPreflightTypedPlan :: TypedInstallPlan
  } deriving (Eq, Show)

instance ToJSON ModpackPreflightResponse where
  toJSON response =
    object
      [ "valid" .= modpackPreflightValid response
      , "name" .= modpackPreflightName response
      , "minecraftVersion" .= modpackPreflightMinecraftVersion response
      , "loader" .= modpackPreflightLoader response
      , "loaderVersion" .= modpackPreflightLoaderVersion response
      , "modCount" .= modpackPreflightModCount response
      , "resourcePackCount" .= modpackPreflightResourcePackCount response
      , "shaderPackCount" .= modpackPreflightShaderPackCount response
      , "overridesCount" .= modpackPreflightOverridesCount response
      , "estimatedDownloadBytes" .= modpackPreflightEstimatedDownloadBytes response
      , "requiresApiKey" .= modpackPreflightRequiresApiKey response
      , "warnings" .= modpackPreflightWarnings response
      , "blockingReasons" .= modpackPreflightBlockingReasons response
      , "typedPlan" .= modpackPreflightTypedPlan response
      ]

data ModpackImportRequest = ModpackImportRequest
  { modpackImportSourceType :: Text
  , modpackImportSourcePath :: FilePath
  , modpackImportTargetGameDir :: FilePath
  } deriving (Eq, Show)

instance FromJSON ModpackImportRequest where
  parseJSON =
    withObject "ModpackImportRequest" $ \obj ->
      ModpackImportRequest
        <$> obj .:? "sourceType" .!= "local"
        <*> obj .: "sourcePath"
        <*> obj .: "targetGameDir"

data ModpackImportLockEntry = ModpackImportLockEntry
  { modpackLockEntryPath :: FilePath
  , modpackLockEntryKind :: Text
  , modpackLockEntrySha1 :: Maybe Text
  , modpackLockEntrySize :: Maybe Int64
  , modpackLockEntrySource :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON ModpackImportLockEntry where
  toJSON entry =
    object
      [ "path" .= modpackLockEntryPath entry
      , "kind" .= modpackLockEntryKind entry
      , "sha1" .= modpackLockEntrySha1 entry
      , "size" .= modpackLockEntrySize entry
      , "source" .= modpackLockEntrySource entry
      ]

data ModpackImportResponse = ModpackImportResponse
  { modpackImportImported :: Bool
  , modpackImportResponseTargetGameDir :: FilePath
  , modpackImportResponseStagingPath :: FilePath
  , modpackImportResponseLockfilePath :: FilePath
  , modpackImportResponseFilesWritten :: Int
  , modpackImportResponseWarnings :: [Text]
  , modpackImportBlockingReasons :: [Text]
  , modpackImportTypedPlan :: TypedInstallPlan
  } deriving (Eq, Show)

instance ToJSON ModpackImportResponse where
  toJSON response =
    object
      [ "imported" .= modpackImportImported response
      , "targetGameDir" .= modpackImportResponseTargetGameDir response
      , "stagingPath" .= modpackImportResponseStagingPath response
      , "lockfilePath" .= modpackImportResponseLockfilePath response
      , "filesWritten" .= modpackImportResponseFilesWritten response
      , "warnings" .= modpackImportResponseWarnings response
      , "blockingReasons" .= modpackImportBlockingReasons response
      , "typedPlan" .= modpackImportTypedPlan response
      ]

data ExportBackupPreflightRequest = ExportBackupPreflightRequest
  { exportPreflightConfiguration :: GameConfigurationRequest
  , exportPreflightKind :: Text
  , exportPreflightTargetPath :: Maybe FilePath
  } deriving (Eq, Show)

instance FromJSON ExportBackupPreflightRequest where
  parseJSON =
    withObject "ExportBackupPreflightRequest" $ \obj ->
      ExportBackupPreflightRequest
        <$> obj .: "configuration"
        <*> obj .: "kind"
        <*> obj .:? "targetPath"

data ExportBackupPreflightResponse = ExportBackupPreflightResponse
  { exportPreflightAllowed :: Bool
  , exportPreflightWarnings :: [Text]
  , exportPreflightBlockingReasons :: [Text]
  , exportPreflightEstimatedBytes :: Maybe Int64
  , exportPreflightCheckedPaths :: [FilePath]
  } deriving (Eq, Show)

instance ToJSON ExportBackupPreflightResponse where
  toJSON response =
    object
      [ "allowed" .= exportPreflightAllowed response
      , "warnings" .= exportPreflightWarnings response
      , "blockingReasons" .= exportPreflightBlockingReasons response
      , "estimatedBytes" .= exportPreflightEstimatedBytes response
      , "checkedPaths" .= exportPreflightCheckedPaths response
      ]
