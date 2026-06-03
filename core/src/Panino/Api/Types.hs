{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Types
  ( ApiEvent(..)
  , ContentResolveTargetsRequest(..)
  , ContentResolveTargetsResponse(..)
  , ContentInstallDependency(..)
  , ContentInstallFile(..)
  , ContentInstallPlanFile(..)
  , ContentInstallPlanResponse(..)
  , ContentInstallRequest(..)
  , ContentUpdateLockEntry(..)
  , ContentUpdatePlanRequest(..)
  , ContentUpdatePlanResource(..)
  , ContentUpdatePlanResponse(..)
  , ContentTargetCandidate(..)
  , ContentTargetInstance(..)
  , DownloadRuntimeOptions(..)
  , HealthResponse(..)
  , InstallRequest(..)
  , LaunchRequest(..)
  , TaskAccepted(..)
  , TaskProgressHost(..)
  , TaskProgressMultipart(..)
  , TaskProgress(..)
  , TaskSnapshot(..)
  , TaskState(..)
  , emptyDownloadRuntimeOptions
  , mergeDownloadRuntimeOptions
  , taskStateText
  ) where

import Control.Applicative ((<|>))
import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , Value(..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Time (UTCTime)
import Panino.Diagnostics.Types (Diagnostic)
import Panino.Install.Plan.Types (TypedInstallPlan)
import Panino.Launch.Tuning.Types
  ( JvmTuningPolicy
  , MemoryPolicy
  )

data HealthResponse = HealthResponse
  { healthStatus :: Text
  , healthService :: Text
  , healthTime :: UTCTime
  } deriving (Eq, Show)

instance ToJSON HealthResponse where
  toJSON response =
    object
      [ "status" .= healthStatus response
      , "service" .= healthService response
      , "time" .= healthTime response
      ]

data DownloadRuntimeOptions = DownloadRuntimeOptions
  { downloadRuntimeConcurrency :: Maybe Int
  , downloadRuntimeRetryCount :: Maybe Int
  , downloadRuntimeStrategy :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON DownloadRuntimeOptions where
  parseJSON =
    withObject "DownloadRuntimeOptions" $ \objectValue ->
      DownloadRuntimeOptions
        <$> objectValue .:? "concurrency"
        <*> objectValue .:? "retryCount"
        <*> objectValue .:? "strategy"

instance ToJSON DownloadRuntimeOptions where
  toJSON options =
    object
      [ "concurrency" .= downloadRuntimeConcurrency options
      , "retryCount" .= downloadRuntimeRetryCount options
      , "strategy" .= downloadRuntimeStrategy options
      ]

emptyDownloadRuntimeOptions :: DownloadRuntimeOptions
emptyDownloadRuntimeOptions =
  DownloadRuntimeOptions
    { downloadRuntimeConcurrency = Nothing
    , downloadRuntimeRetryCount = Nothing
    , downloadRuntimeStrategy = Nothing
    }

mergeDownloadRuntimeOptions :: Maybe Int -> Maybe Int -> Maybe Text -> Maybe DownloadRuntimeOptions -> DownloadRuntimeOptions
mergeDownloadRuntimeOptions legacyConcurrency legacyRetryCount legacyStrategy nested =
  DownloadRuntimeOptions
    { downloadRuntimeConcurrency =
        (nested >>= downloadRuntimeConcurrency) <|> legacyConcurrency
    , downloadRuntimeRetryCount =
        (nested >>= downloadRuntimeRetryCount) <|> legacyRetryCount
    , downloadRuntimeStrategy =
        (nested >>= downloadRuntimeStrategy) <|> legacyStrategy
    }

data InstallRequest = InstallRequest
  { installRequestVersion :: Text
  , installRequestGameDir :: Maybe FilePath
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
        <*> objectValue .:? "gameDir"
        <*> objectValue .:? "loader"
        <*> objectValue .:? "loaderVersion"
        <*> objectValue .:? "shaderLoader"
        <*> objectValue .:? "shaderVersion"
        <*> objectValue .:? "instanceName"
        <*> pure (mergeDownloadRuntimeOptions legacyConcurrency legacyRetryCount legacyStrategy nestedDownload)

data LaunchRequest = LaunchRequest
  { launchRequestVersion :: Text
  , launchRequestGameDir :: Maybe FilePath
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
        <*> objectValue .:? "gameDir"
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

data ContentInstallFile = ContentInstallFile
  { contentFileName :: Text
  , contentFileUrl :: Text
  , contentFileSha1 :: Maybe Text
  , contentFileSize :: Maybe Int64
  , contentFilePrimary :: Maybe Bool
  } deriving (Eq, Show)

instance FromJSON ContentInstallFile where
  parseJSON =
    withObject "ContentInstallFile" $ \objectValue ->
      ContentInstallFile
        <$> objectValue .: "fileName"
        <*> objectValue .: "url"
        <*> objectValue .:? "sha1"
        <*> objectValue .:? "size"
        <*> objectValue .:? "primary"

instance ToJSON ContentInstallFile where
  toJSON file =
    object
      [ "fileName" .= contentFileName file
      , "url" .= contentFileUrl file
      , "sha1" .= contentFileSha1 file
      , "size" .= contentFileSize file
      , "primary" .= contentFilePrimary file
      ]

data ContentInstallDependency = ContentInstallDependency
  { contentDependencyProjectId :: Maybe Text
  , contentDependencyVersionId :: Maybe Text
  , contentDependencySource :: Maybe Text
  , contentDependencyName :: Text
  , contentDependencyRequired :: Bool
  , contentDependencyInstalled :: Maybe Bool
  , contentDependencySha1 :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON ContentInstallDependency where
  parseJSON =
    withObject "ContentInstallDependency" $ \objectValue ->
      ContentInstallDependency
        <$> objectValue .:? "projectId"
        <*> (objectValue .:? "versionId" >>= maybe (objectValue .:? "versionID") (pure . Just))
        <*> objectValue .:? "source"
        <*> objectValue .: "name"
        <*> (fromMaybe True <$> objectValue .:? "required")
        <*> objectValue .:? "installed"
        <*> objectValue .:? "sha1"

instance ToJSON ContentInstallDependency where
  toJSON dependency =
    object
      [ "projectId" .= contentDependencyProjectId dependency
      , "versionId" .= contentDependencyVersionId dependency
      , "source" .= contentDependencySource dependency
      , "name" .= contentDependencyName dependency
      , "required" .= contentDependencyRequired dependency
      , "installed" .= contentDependencyInstalled dependency
      , "sha1" .= contentDependencySha1 dependency
      ]

data ContentInstallRequest = ContentInstallRequest
  { contentInstallSource :: Text
  , contentInstallProjectId :: Maybe Text
  , contentInstallProjectTitle :: Text
  , contentInstallProjectType :: Maybe Text
  , contentInstallReleaseId :: Text
  , contentInstallGameDir :: Maybe FilePath
  , contentInstallTargetSubdir :: Text
  , contentInstallFiles :: [ContentInstallFile]
  , contentInstallDependencies :: [ContentInstallDependency]
  , contentInstallGameVersions :: [Text]
  , contentInstallLoaders :: [Text]
  , contentInstallInstances :: [ContentTargetInstance]
  , contentInstallDownload :: DownloadRuntimeOptions
  } deriving (Eq, Show)

instance FromJSON ContentInstallRequest where
  parseJSON =
    withObject "ContentInstallRequest" $ \objectValue -> do
      legacyConcurrency <- objectValue .:? "concurrency"
      legacyRetryCount <- objectValue .:? "retryCount"
      legacyStrategy <- objectValue .:? "strategy"
      nestedDownload <- objectValue .:? "download"
      ContentInstallRequest
        <$> objectValue .: "source"
        <*> objectValue .:? "projectId"
        <*> objectValue .: "projectTitle"
        <*> objectValue .:? "projectType"
        <*> objectValue .: "releaseId"
        <*> objectValue .:? "gameDir"
        <*> objectValue .: "targetSubdir"
        <*> objectValue .: "files"
        <*> (fromMaybe [] <$> objectValue .:? "dependencies")
        <*> (fromMaybe [] <$> objectValue .:? "gameVersions")
        <*> (fromMaybe [] <$> objectValue .:? "loaders")
        <*> (fromMaybe [] <$> objectValue .:? "instances")
        <*> pure (mergeDownloadRuntimeOptions legacyConcurrency legacyRetryCount legacyStrategy nestedDownload)

data ContentInstallPlanFile = ContentInstallPlanFile
  { contentPlanFileName :: Text
  , contentPlanTargetPath :: FilePath
  , contentPlanFileSize :: Maybe Int64
  , contentPlanFileSha1 :: Maybe Text
  , contentPlanFileAction :: Text
  , contentPlanFilePrimary :: Bool
  } deriving (Eq, Show)

instance ToJSON ContentInstallPlanFile where
  toJSON file =
    object
      [ "fileName" .= contentPlanFileName file
      , "targetPath" .= contentPlanTargetPath file
      , "size" .= contentPlanFileSize file
      , "sha1" .= contentPlanFileSha1 file
      , "action" .= contentPlanFileAction file
      , "primary" .= contentPlanFilePrimary file
      ]

data ContentInstallPlanResponse = ContentInstallPlanResponse
  { contentPlanAction :: Text
  , contentPlanSource :: Text
  , contentPlanProjectId :: Maybe Text
  , contentPlanProjectTitle :: Text
  , contentPlanReleaseId :: Text
  , contentPlanTargetDir :: FilePath
  , contentPlanFiles :: [ContentInstallPlanFile]
  , contentPlanDependencies :: [ContentInstallDependency]
  , contentPlanWarnings :: [Text]
  , contentPlanBlockedReasons :: [Text]
  , contentPlanTotalSize :: Maybe Int64
  , contentPlanTypedPlan :: TypedInstallPlan
  } deriving (Eq, Show)

instance ToJSON ContentInstallPlanResponse where
  toJSON plan =
    object
      [ "action" .= contentPlanAction plan
      , "source" .= contentPlanSource plan
      , "projectId" .= contentPlanProjectId plan
      , "projectTitle" .= contentPlanProjectTitle plan
      , "releaseId" .= contentPlanReleaseId plan
      , "targetDir" .= contentPlanTargetDir plan
      , "files" .= contentPlanFiles plan
      , "dependencies" .= contentPlanDependencies plan
      , "warnings" .= contentPlanWarnings plan
      , "blockedReasons" .= contentPlanBlockedReasons plan
      , "totalSize" .= contentPlanTotalSize plan
      , "typedPlan" .= contentPlanTypedPlan plan
      ]

data ContentUpdatePlanResource = ContentUpdatePlanResource
  { updateResourceProjectId :: Maybe Text
  , updateResourceProjectTitle :: Text
  , updateResourceCurrentReleaseId :: Maybe Text
  , updateResourceCurrentFileName :: Text
  , updateResourceCurrentSha1 :: Maybe Text
  , updateResourceCurrentTargetPath :: FilePath
  , updateResourceRemoteReleaseId :: Maybe Text
  , updateResourceRemoteFileName :: Maybe Text
  , updateResourceRemoteUrl :: Maybe Text
  , updateResourceRemoteSha1 :: Maybe Text
  , updateResourceRemoteSize :: Maybe Int64
  , updateResourceSelected :: Maybe Bool
  , updateResourceDependencies :: [ContentInstallDependency]
  } deriving (Eq, Show)

instance FromJSON ContentUpdatePlanResource where
  parseJSON =
    withObject "ContentUpdatePlanResource" $ \value ->
      ContentUpdatePlanResource
        <$> value .:? "projectId"
        <*> value .: "projectTitle"
        <*> value .:? "currentReleaseId"
        <*> value .: "currentFileName"
        <*> value .:? "currentSha1"
        <*> value .: "currentTargetPath"
        <*> value .:? "remoteReleaseId"
        <*> value .:? "remoteFileName"
        <*> value .:? "remoteUrl"
        <*> value .:? "remoteSha1"
        <*> value .:? "remoteSize"
        <*> value .:? "selected"
        <*> (fromMaybe [] <$> value .:? "dependencies")

instance ToJSON ContentUpdatePlanResource where
  toJSON resource =
    object
      [ "projectId" .= updateResourceProjectId resource
      , "projectTitle" .= updateResourceProjectTitle resource
      , "currentReleaseId" .= updateResourceCurrentReleaseId resource
      , "currentFileName" .= updateResourceCurrentFileName resource
      , "currentSha1" .= updateResourceCurrentSha1 resource
      , "currentTargetPath" .= updateResourceCurrentTargetPath resource
      , "remoteReleaseId" .= updateResourceRemoteReleaseId resource
      , "remoteFileName" .= updateResourceRemoteFileName resource
      , "remoteUrl" .= updateResourceRemoteUrl resource
      , "remoteSha1" .= updateResourceRemoteSha1 resource
      , "remoteSize" .= updateResourceRemoteSize resource
      , "selected" .= updateResourceSelected resource
      , "dependencies" .= updateResourceDependencies resource
      ]

data ContentUpdatePlanRequest = ContentUpdatePlanRequest
  { updatePlanMode :: Text
  , updatePlanGameDir :: FilePath
  , updatePlanSource :: Text
  , updatePlanResources :: [ContentUpdatePlanResource]
  } deriving (Eq, Show)

instance FromJSON ContentUpdatePlanRequest where
  parseJSON =
    withObject "ContentUpdatePlanRequest" $ \value ->
      ContentUpdatePlanRequest
        <$> value .:? "mode" .!= "updateAllSafe"
        <*> value .: "gameDir"
        <*> value .:? "source" .!= "modrinth"
        <*> value .:? "resources" .!= []

instance ToJSON ContentUpdatePlanRequest where
  toJSON request =
    object
      [ "mode" .= updatePlanMode request
      , "gameDir" .= updatePlanGameDir request
      , "source" .= updatePlanSource request
      , "resources" .= updatePlanResources request
      ]

data ContentUpdateLockEntry = ContentUpdateLockEntry
  { updateLockProjectId :: Maybe Text
  , updateLockProjectTitle :: Text
  , updateLockOldReleaseId :: Maybe Text
  , updateLockNewReleaseId :: Maybe Text
  , updateLockOldSha1 :: Maybe Text
  , updateLockNewSha1 :: Maybe Text
  , updateLockTargetPath :: FilePath
  , updateLockBackupPath :: Maybe FilePath
  } deriving (Eq, Show)

instance ToJSON ContentUpdateLockEntry where
  toJSON entry =
    object
      [ "projectId" .= updateLockProjectId entry
      , "projectTitle" .= updateLockProjectTitle entry
      , "oldReleaseId" .= updateLockOldReleaseId entry
      , "newReleaseId" .= updateLockNewReleaseId entry
      , "oldSha1" .= updateLockOldSha1 entry
      , "newSha1" .= updateLockNewSha1 entry
      , "targetPath" .= updateLockTargetPath entry
      , "backupPath" .= updateLockBackupPath entry
      ]

data ContentUpdatePlanResponse = ContentUpdatePlanResponse
  { contentUpdateAction :: Text
  , contentUpdateMode :: Text
  , contentUpdateLockfilePath :: FilePath
  , contentUpdateLockEntries :: [ContentUpdateLockEntry]
  , contentUpdateWarnings :: [Text]
  , contentUpdateBlockedReasons :: [Text]
  , contentUpdateTypedPlan :: TypedInstallPlan
  } deriving (Eq, Show)

instance ToJSON ContentUpdatePlanResponse where
  toJSON response =
    object
      [ "action" .= contentUpdateAction response
      , "mode" .= contentUpdateMode response
      , "lockfilePath" .= contentUpdateLockfilePath response
      , "lockEntries" .= contentUpdateLockEntries response
      , "warnings" .= contentUpdateWarnings response
      , "blockedReasons" .= contentUpdateBlockedReasons response
      , "typedPlan" .= contentUpdateTypedPlan response
      ]

data ContentTargetInstance = ContentTargetInstance
  { contentTargetInstanceId :: Maybe Text
  , contentTargetInstanceName :: Text
  , contentTargetInstanceGameDir :: FilePath
  , contentTargetInstanceMinecraftVersion :: Text
  , contentTargetInstanceLoader :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON ContentTargetInstance where
  parseJSON =
    withObject "ContentTargetInstance" $ \objectValue ->
      ContentTargetInstance
        <$> objectValue .:? "instanceId"
        <*> objectValue .: "name"
        <*> objectValue .: "gameDir"
        <*> objectValue .: "minecraftVersion"
        <*> objectValue .:? "loader"

data ContentResolveTargetsRequest = ContentResolveTargetsRequest
  { contentResolveProjectType :: Text
  , contentResolveProjectTitle :: Text
  , contentResolveReleaseId :: Maybe Text
  , contentResolveTargetSubdir :: Text
  , contentResolveGameVersions :: [Text]
  , contentResolveLoaders :: [Text]
  , contentResolveInstances :: [ContentTargetInstance]
  } deriving (Eq, Show)

instance FromJSON ContentResolveTargetsRequest where
  parseJSON =
    withObject "ContentResolveTargetsRequest" $ \objectValue ->
      ContentResolveTargetsRequest
        <$> objectValue .: "projectType"
        <*> objectValue .: "projectTitle"
        <*> objectValue .:? "releaseId"
        <*> (fromMaybe "" <$> objectValue .:? "targetSubdir")
        <*> (fromMaybe [] <$> objectValue .:? "gameVersions")
        <*> (fromMaybe [] <$> objectValue .:? "loaders")
        <*> (fromMaybe [] <$> objectValue .:? "instances")

data ContentTargetCandidate = ContentTargetCandidate
  { contentCandidateInstanceId :: Maybe Text
  , contentCandidateName :: Text
  , contentCandidateGameDir :: FilePath
  , contentCandidateMinecraftVersion :: Text
  , contentCandidateLoader :: Maybe Text
  , contentCandidateScore :: Int
  , contentCandidateReasons :: [Text]
  , contentCandidateBlockedReasons :: [Text]
  , contentCandidateRecommended :: Bool
  } deriving (Eq, Show)

instance ToJSON ContentTargetCandidate where
  toJSON candidate =
    object
      [ "instanceId" .= contentCandidateInstanceId candidate
      , "name" .= contentCandidateName candidate
      , "gameDir" .= contentCandidateGameDir candidate
      , "minecraftVersion" .= contentCandidateMinecraftVersion candidate
      , "loader" .= contentCandidateLoader candidate
      , "score" .= contentCandidateScore candidate
      , "reasons" .= contentCandidateReasons candidate
      , "blockedReasons" .= contentCandidateBlockedReasons candidate
      , "recommended" .= contentCandidateRecommended candidate
      ]

data ContentResolveTargetsResponse = ContentResolveTargetsResponse
  { contentResolveCandidates :: [ContentTargetCandidate]
  , contentResolveRecommended :: Maybe ContentTargetCandidate
  , contentResolveBlockedReasons :: [Text]
  } deriving (Eq, Show)

instance ToJSON ContentResolveTargetsResponse where
  toJSON response =
    object
      [ "candidates" .= contentResolveCandidates response
      , "recommended" .= contentResolveRecommended response
      , "blockedReasons" .= contentResolveBlockedReasons response
      ]

data TaskState
  = TaskQueued
  | TaskRunning
  | TaskSucceeded
  | TaskFailed
  | TaskCancelled
  deriving (Eq, Show)

taskStateText :: TaskState -> Text
taskStateText TaskQueued = "queued"
taskStateText TaskRunning = "running"
taskStateText TaskSucceeded = "succeeded"
taskStateText TaskFailed = "failed"
taskStateText TaskCancelled = "cancelled"

instance ToJSON TaskState where
  toJSON = String . taskStateText

instance FromJSON TaskState where
  parseJSON (String value) =
    case value of
      "queued" -> pure TaskQueued
      "running" -> pure TaskRunning
      "succeeded" -> pure TaskSucceeded
      "failed" -> pure TaskFailed
      "cancelled" -> pure TaskCancelled
      _ -> fail ("unknown task state: " <> show value)
  parseJSON _ =
    fail "TaskState must be a string"

data TaskProgressHost = TaskProgressHost
  { taskProgressHostHost :: Text
  , taskProgressHostLane :: Text
  , taskProgressHostActiveConnections :: Int
  , taskProgressHostGate :: Int
  , taskProgressHostMaxGate :: Int
  , taskProgressHostBytesPerSecond :: Int64
  , taskProgressHostCompletedBytes :: Int64
  , taskProgressHostCompletedJobs :: Int
  , taskProgressHostRetryCount :: Int
  } deriving (Eq, Show)

instance ToJSON TaskProgressHost where
  toJSON host =
    object
      [ "host" .= taskProgressHostHost host
      , "lane" .= taskProgressHostLane host
      , "activeConnections" .= taskProgressHostActiveConnections host
      , "gate" .= taskProgressHostGate host
      , "maxGate" .= taskProgressHostMaxGate host
      , "bytesPerSecond" .= taskProgressHostBytesPerSecond host
      , "completedBytes" .= taskProgressHostCompletedBytes host
      , "completedJobs" .= taskProgressHostCompletedJobs host
      , "retryCount" .= taskProgressHostRetryCount host
      ]

instance FromJSON TaskProgressHost where
  parseJSON =
    withObject "TaskProgressHost" $ \value ->
      TaskProgressHost
        <$> value .: "host"
        <*> value .:? "lane" .!= ""
        <*> value .:? "activeConnections" .!= 0
        <*> value .:? "gate" .!= 0
        <*> value .:? "maxGate" .!= 0
        <*> value .:? "bytesPerSecond" .!= 0
        <*> value .:? "completedBytes" .!= 0
        <*> value .:? "completedJobs" .!= 0
        <*> value .:? "retryCount" .!= 0

data TaskProgressMultipart = TaskProgressMultipart
  { taskProgressMultipartLabel :: Text
  , taskProgressMultipartCompletedSegments :: Int
  , taskProgressMultipartTotalSegments :: Int
  , taskProgressMultipartActiveSegments :: Int
  , taskProgressMultipartSegmentBytes :: Int64
  , taskProgressMultipartTotalBytes :: Int64
  , taskProgressMultipartCurrentSegment :: Maybe Int
  } deriving (Eq, Show)

instance ToJSON TaskProgressMultipart where
  toJSON multipart =
    object
      [ "label" .= taskProgressMultipartLabel multipart
      , "completedSegments" .= taskProgressMultipartCompletedSegments multipart
      , "totalSegments" .= taskProgressMultipartTotalSegments multipart
      , "activeSegments" .= taskProgressMultipartActiveSegments multipart
      , "segmentBytes" .= taskProgressMultipartSegmentBytes multipart
      , "totalBytes" .= taskProgressMultipartTotalBytes multipart
      , "currentSegment" .= taskProgressMultipartCurrentSegment multipart
      ]

instance FromJSON TaskProgressMultipart where
  parseJSON =
    withObject "TaskProgressMultipart" $ \value ->
      TaskProgressMultipart
        <$> value .:? "label" .!= ""
        <*> value .:? "completedSegments" .!= 0
        <*> value .:? "totalSegments" .!= 0
        <*> value .:? "activeSegments" .!= 0
        <*> value .:? "segmentBytes" .!= 0
        <*> value .:? "totalBytes" .!= 0
        <*> value .:? "currentSegment"

data TaskProgress = TaskProgress
  { taskProgressTaskId :: Text
  , taskProgressPhaseId :: Text
  , taskProgressPhaseTitle :: Text
  , taskProgressPhaseIndex :: Int
  , taskProgressPhaseCount :: Int
  , taskProgressPhasePercent :: Maybe Double
  , taskProgressOverallPercent :: Maybe Double
  , taskProgressCompletedJobs :: Int
  , taskProgressTotalJobs :: Int
  , taskProgressCompletedBytes :: Int64
  , taskProgressTotalBytes :: Int64
  , taskProgressSpeedBytesPerSecond :: Int64
  , taskProgressMovingAverageSpeedBytesPerSecond :: Int64
  , taskProgressEtaSeconds :: Maybe Int64
  , taskProgressCurrentLabel :: Text
  , taskProgressActiveWorkers :: Int
  , taskProgressRetryCount :: Int
  , taskProgressSourceHost :: Maybe Text
  , taskProgressHosts :: [TaskProgressHost]
  , taskProgressThrottleReason :: Maybe Text
  , taskProgressMultipart :: Maybe TaskProgressMultipart
  } deriving (Eq, Show)

instance ToJSON TaskProgress where
  toJSON progress =
    object
      [ "taskId" .= taskProgressTaskId progress
      , "phaseId" .= taskProgressPhaseId progress
      , "phaseTitle" .= taskProgressPhaseTitle progress
      , "phaseIndex" .= taskProgressPhaseIndex progress
      , "phaseCount" .= taskProgressPhaseCount progress
      , "phasePercent" .= taskProgressPhasePercent progress
      , "overallPercent" .= taskProgressOverallPercent progress
      , "completedJobs" .= taskProgressCompletedJobs progress
      , "totalJobs" .= taskProgressTotalJobs progress
      , "completedBytes" .= taskProgressCompletedBytes progress
      , "totalBytes" .= taskProgressTotalBytes progress
      , "speedBytesPerSecond" .= taskProgressSpeedBytesPerSecond progress
      , "movingAverageSpeedBytesPerSecond" .= taskProgressMovingAverageSpeedBytesPerSecond progress
      , "etaSeconds" .= taskProgressEtaSeconds progress
      , "currentLabel" .= taskProgressCurrentLabel progress
      , "activeWorkers" .= taskProgressActiveWorkers progress
      , "retryCount" .= taskProgressRetryCount progress
      , "sourceHost" .= taskProgressSourceHost progress
      , "hosts" .= taskProgressHosts progress
      , "throttleReason" .= taskProgressThrottleReason progress
      , "multipart" .= taskProgressMultipart progress
      ]

instance FromJSON TaskProgress where
  parseJSON =
    withObject "TaskProgress" $ \value ->
      TaskProgress
        <$> value .: "taskId"
        <*> value .: "phaseId"
        <*> value .: "phaseTitle"
        <*> value .: "phaseIndex"
        <*> value .: "phaseCount"
        <*> value .:? "phasePercent"
        <*> value .:? "overallPercent"
        <*> value .:? "completedJobs" .!= 0
        <*> value .:? "totalJobs" .!= 0
        <*> value .:? "completedBytes" .!= 0
        <*> value .:? "totalBytes" .!= 0
        <*> value .:? "speedBytesPerSecond" .!= 0
        <*> value .:? "movingAverageSpeedBytesPerSecond" .!= 0
        <*> value .:? "etaSeconds"
        <*> value .:? "currentLabel" .!= ""
        <*> value .:? "activeWorkers" .!= 0
        <*> value .:? "retryCount" .!= 0
        <*> value .:? "sourceHost"
        <*> value .:? "hosts" .!= []
        <*> value .:? "throttleReason"
        <*> value .:? "multipart"

data TaskSnapshot = TaskSnapshot
  { taskSnapshotId :: Text
  , taskSnapshotKind :: Text
  , taskSnapshotVersion :: Text
  , taskSnapshotGameDir :: Maybe FilePath
  , taskSnapshotRequestedLoader :: Maybe Text
  , taskSnapshotRequestedShaderLoader :: Maybe Text
  , taskSnapshotState :: TaskState
  , taskSnapshotMessage :: Maybe Text
  , taskSnapshotErrorCode :: Maybe Text
  , taskSnapshotErrorDetail :: Maybe Text
  , taskSnapshotDiagnostic :: Maybe Diagnostic
  , taskSnapshotDiagnostics :: [Diagnostic]
  , taskSnapshotCreatedAt :: UTCTime
  , taskSnapshotUpdatedAt :: UTCTime
  , taskSnapshotFinishedAt :: Maybe UTCTime
  , taskSnapshotProgress :: Maybe TaskProgress
  } deriving (Eq, Show)

instance ToJSON TaskSnapshot where
  toJSON task =
    object
      [ "taskId" .= taskSnapshotId task
      , "kind" .= taskSnapshotKind task
      , "version" .= taskSnapshotVersion task
      , "gameDir" .= taskSnapshotGameDir task
      , "requestedLoader" .= taskSnapshotRequestedLoader task
      , "requestedShaderLoader" .= taskSnapshotRequestedShaderLoader task
      , "state" .= taskSnapshotState task
      , "message" .= taskSnapshotMessage task
      , "errorCode" .= taskSnapshotErrorCode task
      , "errorDetail" .= taskSnapshotErrorDetail task
      , "diagnostic" .= taskSnapshotDiagnostic task
      , "diagnostics" .= taskSnapshotDiagnostics task
      , "createdAt" .= taskSnapshotCreatedAt task
      , "updatedAt" .= taskSnapshotUpdatedAt task
      , "finishedAt" .= taskSnapshotFinishedAt task
      , "progress" .= taskSnapshotProgress task
      ]

instance FromJSON TaskSnapshot where
  parseJSON =
    withObject "TaskSnapshot" $ \value -> do
      diagnostic <- value .:? "diagnostic"
      diagnostics <- value .:? "diagnostics" .!= maybe [] pure diagnostic
      TaskSnapshot
        <$> value .: "taskId"
        <*> value .: "kind"
        <*> value .: "version"
        <*> value .:? "gameDir"
        <*> value .:? "requestedLoader"
        <*> value .:? "requestedShaderLoader"
        <*> value .: "state"
        <*> value .:? "message"
        <*> value .:? "errorCode"
        <*> value .:? "errorDetail"
        <*> pure diagnostic
        <*> pure diagnostics
        <*> value .: "createdAt"
        <*> value .: "updatedAt"
        <*> value .:? "finishedAt"
        <*> value .:? "progress"

newtype TaskAccepted = TaskAccepted
  { acceptedTask :: TaskSnapshot
  } deriving (Eq, Show)

instance ToJSON TaskAccepted where
  toJSON response =
    object
      [ "taskId" .= taskSnapshotId task
      , "state" .= taskSnapshotState task
      , "task" .= task
      ]
    where
      task = acceptedTask response

data ApiEvent = ApiEvent
  { apiEventType :: Text
  , apiEventTaskId :: Maybe Text
  , apiEventVersion :: Maybe Text
  , apiEventMessage :: Text
  , apiEventAt :: UTCTime
  , apiEventPayload :: Value
  } deriving (Eq, Show)

instance ToJSON ApiEvent where
  toJSON event =
    object
      [ "type" .= apiEventType event
      , "taskId" .= apiEventTaskId event
      , "version" .= apiEventVersion event
      , "message" .= apiEventMessage event
      , "time" .= apiEventAt event
      , "payload" .= apiEventPayload event
      ]
