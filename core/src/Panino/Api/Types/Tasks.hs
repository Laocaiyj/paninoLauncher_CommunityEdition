{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Types.Tasks
  ( TaskAccepted(..)
  , TaskKind(..)
  , TaskPhaseId
  , TaskProgressHost(..)
  , TaskProgressMultipart(..)
  , TaskProgress(..)
  , TaskSnapshot(..)
  , TaskState(..)
  , taskKindFromText
  , taskKindText
  , taskPhaseIdFromText
  , taskPhaseIdText
  , taskStateFromText
  , taskStateText
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
import Data.String (IsString(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Panino.Core.WireText
  ( WireText(..)
  , parseWireTextJSON
  , toWireTextJSON
  )
import Panino.Diagnostics.Types (Diagnostic)

data TaskState
  = TaskQueued
  | TaskRunning
  | TaskSucceeded
  | TaskFailed
  | TaskCancelled
  | TaskStateOther Text
  deriving (Eq, Show)

instance IsString TaskState where
  fromString =
    taskStateFromText . Text.pack

taskStateFromText :: Text -> TaskState
taskStateFromText =
  parseWireText

taskStateText :: TaskState -> Text
taskStateText =
  wireText

instance WireText TaskState where
  parseWireText value =
    case value of
      "queued" -> TaskQueued
      "running" -> TaskRunning
      "succeeded" -> TaskSucceeded
      "failed" -> TaskFailed
      "cancelled" -> TaskCancelled
      _ -> TaskStateOther value

  wireText taskState =
    case taskState of
      TaskQueued -> "queued"
      TaskRunning -> "running"
      TaskSucceeded -> "succeeded"
      TaskFailed -> "failed"
      TaskCancelled -> "cancelled"
      TaskStateOther rawState -> rawState

instance ToJSON TaskState where
  toJSON =
    toWireTextJSON

instance FromJSON TaskState where
  parseJSON =
    parseWireTextJSON

data TaskKind
  = TaskKindInstall
  | TaskKindLaunch
  | TaskKindContentInstall
  | TaskKindRuntimeInstall
  | TaskKindPerformancePackInstall
  | TaskKindOther Text
  deriving (Eq, Show)

instance IsString TaskKind where
  fromString =
    taskKindFromText . Text.pack

taskKindFromText :: Text -> TaskKind
taskKindFromText =
  parseWireText

taskKindText :: TaskKind -> Text
taskKindText =
  wireText

instance WireText TaskKind where
  parseWireText value =
    case value of
      "install" -> TaskKindInstall
      "launch" -> TaskKindLaunch
      "content-install" -> TaskKindContentInstall
      "runtime.install" -> TaskKindRuntimeInstall
      "performance-pack-install" -> TaskKindPerformancePackInstall
      _ -> TaskKindOther value

  wireText taskKind =
    case taskKind of
      TaskKindInstall -> "install"
      TaskKindLaunch -> "launch"
      TaskKindContentInstall -> "content-install"
      TaskKindRuntimeInstall -> "runtime.install"
      TaskKindPerformancePackInstall -> "performance-pack-install"
      TaskKindOther rawKind -> rawKind

instance ToJSON TaskKind where
  toJSON =
    toWireTextJSON

instance FromJSON TaskKind where
  parseJSON =
    parseWireTextJSON

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

newtype TaskPhaseId =
  TaskPhaseId Text
  deriving (Eq, Ord, Show)

instance IsString TaskPhaseId where
  fromString =
    taskPhaseIdFromText . Text.pack

taskPhaseIdFromText :: Text -> TaskPhaseId
taskPhaseIdFromText =
  parseWireText

taskPhaseIdText :: TaskPhaseId -> Text
taskPhaseIdText =
  wireText

instance WireText TaskPhaseId where
  parseWireText =
    TaskPhaseId . Text.strip

  wireText (TaskPhaseId value) =
    value

instance ToJSON TaskPhaseId where
  toJSON =
    toWireTextJSON

instance FromJSON TaskPhaseId where
  parseJSON =
    parseWireTextJSON

data TaskProgress = TaskProgress
  { taskProgressTaskId :: Text
  , taskProgressPhaseId :: TaskPhaseId
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
  , taskSnapshotKind :: TaskKind
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
