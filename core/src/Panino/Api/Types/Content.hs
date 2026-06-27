{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Types.Content
  ( ContentResolveTargetsRequest(..)
  , ContentResolveTargetsResponse(..)
  , ContentInstallDependency(..)
  , ContentInstallFile(..)
  , ContentInstallPlanFile(..)
  , ContentInstallPlanResponse(..)
  , ContentInstallRequest(..)
  , ContentPlanAction(..)
  , ContentUpdateLockEntry(..)
  , ContentUpdateMode(..)
  , ContentUpdatePlanRequest(..)
  , ContentUpdatePlanResource(..)
  , ContentUpdatePlanResponse(..)
  , ContentTargetCandidate(..)
  , ContentTargetInstance(..)
  , contentPlanActionFromText
  , contentPlanActionText
  , contentUpdateModeFromText
  , contentUpdateModeText
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withText
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.String (IsString(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Types.Download
  ( DownloadRuntimeOptions
  , mergeDownloadRuntimeOptions
  )
import Panino.Core.Types
  ( ProjectId
  , Sha1
  , Url
  , VersionId
  )
import Panino.Core.WireText
  ( WireText(..)
  , toWireTextJSON
  )
import Panino.Install.Plan.Types (TypedInstallPlan)

data ContentPlanAction
  = ContentPlanInstall
  | ContentPlanUpdate
  | ContentPlanBlocked
  | ContentPlanActionOther Text
  deriving (Eq, Show)

contentPlanActionFromText :: Text -> ContentPlanAction
contentPlanActionFromText value =
  case Text.toLower value of
    "install" -> ContentPlanInstall
    "update" -> ContentPlanUpdate
    "blocked" -> ContentPlanBlocked
    _ -> ContentPlanActionOther value

contentPlanActionText :: ContentPlanAction -> Text
contentPlanActionText action =
  case action of
    ContentPlanInstall -> "install"
    ContentPlanUpdate -> "update"
    ContentPlanBlocked -> "blocked"
    ContentPlanActionOther value -> value

instance IsString ContentPlanAction where
  fromString = contentPlanActionFromText . Text.pack

instance WireText ContentPlanAction where
  wireText = contentPlanActionText
  parseWireText = contentPlanActionFromText

instance ToJSON ContentPlanAction where
  toJSON = toWireTextJSON

instance FromJSON ContentPlanAction where
  parseJSON =
    withText "ContentPlanAction" (pure . contentPlanActionFromText)

data ContentUpdateMode
  = ContentUpdateKeepLocked
  | ContentUpdateSelected
  | ContentUpdateAllSafe
  | ContentRelock
  | ContentUpdateModeOther Text
  deriving (Eq, Show)

contentUpdateModeFromText :: Text -> ContentUpdateMode
contentUpdateModeFromText value =
  case normalizeContentMode value of
    "keeplocked" -> ContentUpdateKeepLocked
    "updateselected" -> ContentUpdateSelected
    "updateallsafe" -> ContentUpdateAllSafe
    "relock" -> ContentRelock
    _ -> ContentUpdateModeOther value

contentUpdateModeText :: ContentUpdateMode -> Text
contentUpdateModeText mode =
  case mode of
    ContentUpdateKeepLocked -> "keepLocked"
    ContentUpdateSelected -> "updateSelected"
    ContentUpdateAllSafe -> "updateAllSafe"
    ContentRelock -> "relock"
    ContentUpdateModeOther value -> value

instance IsString ContentUpdateMode where
  fromString = contentUpdateModeFromText . Text.pack

instance WireText ContentUpdateMode where
  wireText = contentUpdateModeText
  parseWireText = contentUpdateModeFromText

instance ToJSON ContentUpdateMode where
  toJSON = toWireTextJSON

instance FromJSON ContentUpdateMode where
  parseJSON =
    withText "ContentUpdateMode" (pure . contentUpdateModeFromText)

normalizeContentMode :: Text -> Text
normalizeContentMode =
  Text.toLower . Text.replace "-" "" . Text.replace "_" ""

data ContentInstallFile = ContentInstallFile
  { contentFileName :: Text
  , contentFileUrl :: Url
  , contentFileSha1 :: Maybe Sha1
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
  { contentDependencyProjectId :: Maybe ProjectId
  , contentDependencyVersionId :: Maybe VersionId
  , contentDependencySource :: Maybe Text
  , contentDependencyName :: Text
  , contentDependencyRequired :: Bool
  , contentDependencyInstalled :: Maybe Bool
  , contentDependencySha1 :: Maybe Sha1
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
  , contentInstallProjectId :: Maybe ProjectId
  , contentInstallProjectTitle :: Text
  , contentInstallProjectType :: Maybe Text
  , contentInstallReleaseId :: VersionId
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
  , contentPlanFileSha1 :: Maybe Sha1
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
  { contentPlanAction :: ContentPlanAction
  , contentPlanSource :: Text
  , contentPlanProjectId :: Maybe ProjectId
  , contentPlanProjectTitle :: Text
  , contentPlanReleaseId :: VersionId
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
  { updateResourceProjectId :: Maybe ProjectId
  , updateResourceProjectTitle :: Text
  , updateResourceCurrentReleaseId :: Maybe VersionId
  , updateResourceCurrentFileName :: Text
  , updateResourceCurrentSha1 :: Maybe Sha1
  , updateResourceCurrentTargetPath :: FilePath
  , updateResourceRemoteReleaseId :: Maybe VersionId
  , updateResourceRemoteFileName :: Maybe Text
  , updateResourceRemoteUrl :: Maybe Url
  , updateResourceRemoteSha1 :: Maybe Sha1
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
  { updatePlanMode :: ContentUpdateMode
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
  { updateLockProjectId :: Maybe ProjectId
  , updateLockProjectTitle :: Text
  , updateLockOldReleaseId :: Maybe VersionId
  , updateLockNewReleaseId :: Maybe VersionId
  , updateLockOldSha1 :: Maybe Sha1
  , updateLockNewSha1 :: Maybe Sha1
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
  { contentUpdateAction :: ContentPlanAction
  , contentUpdateMode :: ContentUpdateMode
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
