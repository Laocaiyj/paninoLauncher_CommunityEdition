{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.Telemetry.Types
  ( CompanionFrameSample(..)
  , GcMetrics(..)
  , LaunchMetrics(..)
  , MemoryMetrics(..)
  , MemorySample(..)
  , PerformanceSession(..)
  , PerformanceSessionStatus(..)
  , emptyGcMetrics
  , emptyMemoryMetrics
  , performanceSessionPath
  , performanceSessionsRoot
  , sessionStatusText
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , withText
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (UTCTime)
import Panino.Performance.Profile.Types
  ( InstanceFingerprint
  , PerformanceProfile
  , performanceRoot
  )
import System.FilePath ((</>))

data PerformanceSessionStatus
  = SessionStarted
  | SessionEnded
  | SessionCrashed
  | SessionKilled
  deriving (Eq, Show)

sessionStatusText :: PerformanceSessionStatus -> Text
sessionStatusText status =
  case status of
    SessionStarted -> "started"
    SessionEnded -> "ended"
    SessionCrashed -> "crashed"
    SessionKilled -> "killed"

instance ToJSON PerformanceSessionStatus where
  toJSON =
    toJSON . sessionStatusText

instance FromJSON PerformanceSessionStatus where
  parseJSON =
    withText "PerformanceSessionStatus" $ \raw ->
      pure $
        case Text.toLower raw of
          "ended" -> SessionEnded
          "crashed" -> SessionCrashed
          "killed" -> SessionKilled
          _ -> SessionStarted

data LaunchMetrics = LaunchMetrics
  { launchTimeToProcessStartMs :: Maybe Int
  , launchTimeToGameLogReadyMs :: Maybe Int
  , launchTimeToMainWindowHintMs :: Maybe Int
  , launchProcessExitCode :: Maybe Int
  , launchCrashReportCreated :: Bool
  , launchLatestLogErrors :: [Text]
  } deriving (Eq, Show)

instance ToJSON LaunchMetrics where
  toJSON metrics =
    object
      [ "timeToProcessStartMs" .= launchTimeToProcessStartMs metrics
      , "timeToGameLogReadyMs" .= launchTimeToGameLogReadyMs metrics
      , "timeToMainWindowHintMs" .= launchTimeToMainWindowHintMs metrics
      , "processExitCode" .= launchProcessExitCode metrics
      , "crashReportCreated" .= launchCrashReportCreated metrics
      , "latestLogErrors" .= launchLatestLogErrors metrics
      ]

instance FromJSON LaunchMetrics where
  parseJSON =
    withObject "LaunchMetrics" $ \obj ->
      LaunchMetrics
        <$> obj .:? "timeToProcessStartMs"
        <*> obj .:? "timeToGameLogReadyMs"
        <*> obj .:? "timeToMainWindowHintMs"
        <*> obj .:? "processExitCode"
        <*> obj .:? "crashReportCreated" .!= False
        <*> obj .:? "latestLogErrors" .!= []

data MemorySample = MemorySample
  { memorySampleAtMs :: Int
  , memorySampleResidentBytes :: Int64
  , memorySampleVirtualBytes :: Int64
  } deriving (Eq, Show)

instance ToJSON MemorySample where
  toJSON sample =
    object
      [ "atMs" .= memorySampleAtMs sample
      , "residentBytes" .= memorySampleResidentBytes sample
      , "virtualBytes" .= memorySampleVirtualBytes sample
      ]

instance FromJSON MemorySample where
  parseJSON =
    withObject "MemorySample" $ \obj ->
      MemorySample
        <$> obj .:? "atMs" .!= 0
        <*> obj .:? "residentBytes" .!= 0
        <*> obj .:? "virtualBytes" .!= 0

data MemoryMetrics = MemoryMetrics
  { memoryPeakResidentBytes :: Int64
  , memorySampledResidentBytes :: [Int64]
  , memorySampledVirtualBytes :: [Int64]
  , memorySystemMemoryBytes :: Maybe Int64
  , memoryPressureHint :: Maybe Text
  , memorySamples :: [MemorySample]
  } deriving (Eq, Show)

instance ToJSON MemoryMetrics where
  toJSON metrics =
    object
      [ "peakResidentBytes" .= memoryPeakResidentBytes metrics
      , "sampledResidentBytes" .= memorySampledResidentBytes metrics
      , "sampledVirtualBytes" .= memorySampledVirtualBytes metrics
      , "systemMemoryBytes" .= memorySystemMemoryBytes metrics
      , "memoryPressureHint" .= memoryPressureHint metrics
      , "samples" .= memorySamples metrics
      ]

instance FromJSON MemoryMetrics where
  parseJSON =
    withObject "MemoryMetrics" $ \obj ->
      MemoryMetrics
        <$> obj .:? "peakResidentBytes" .!= 0
        <*> obj .:? "sampledResidentBytes" .!= []
        <*> obj .:? "sampledVirtualBytes" .!= []
        <*> obj .:? "systemMemoryBytes"
        <*> obj .:? "memoryPressureHint"
        <*> obj .:? "samples" .!= []

emptyMemoryMetrics :: MemoryMetrics
emptyMemoryMetrics =
  MemoryMetrics
    { memoryPeakResidentBytes = 0
    , memorySampledResidentBytes = []
    , memorySampledVirtualBytes = []
    , memorySystemMemoryBytes = Nothing
    , memoryPressureHint = Nothing
    , memorySamples = []
    }

data GcMetrics = GcMetrics
  { gcLogEnabled :: Bool
  , gcLogPath :: Maybe FilePath
  , gcPauseCount :: Int
  , gcPauseP50Ms :: Maybe Double
  , gcPauseP95Ms :: Maybe Double
  , gcPauseP99Ms :: Maybe Double
  , gcPauseMaxMs :: Maybe Double
  , gcHeapUsedAfterGcBytes :: Maybe Int64
  } deriving (Eq, Show)

instance ToJSON GcMetrics where
  toJSON metrics =
    object
      [ "gcLogEnabled" .= gcLogEnabled metrics
      , "gcLogPath" .= gcLogPath metrics
      , "gcPauseCount" .= gcPauseCount metrics
      , "gcPauseP50Ms" .= gcPauseP50Ms metrics
      , "gcPauseP95Ms" .= gcPauseP95Ms metrics
      , "gcPauseP99Ms" .= gcPauseP99Ms metrics
      , "gcPauseMaxMs" .= gcPauseMaxMs metrics
      , "heapUsedAfterGcBytes" .= gcHeapUsedAfterGcBytes metrics
      ]

instance FromJSON GcMetrics where
  parseJSON =
    withObject "GcMetrics" $ \obj ->
      GcMetrics
        <$> obj .:? "gcLogEnabled" .!= False
        <*> obj .:? "gcLogPath"
        <*> obj .:? "gcPauseCount" .!= 0
        <*> obj .:? "gcPauseP50Ms"
        <*> obj .:? "gcPauseP95Ms"
        <*> obj .:? "gcPauseP99Ms"
        <*> obj .:? "gcPauseMaxMs"
        <*> obj .:? "heapUsedAfterGcBytes"

emptyGcMetrics :: GcMetrics
emptyGcMetrics =
  GcMetrics
    { gcLogEnabled = False
    , gcLogPath = Nothing
    , gcPauseCount = 0
    , gcPauseP50Ms = Nothing
    , gcPauseP95Ms = Nothing
    , gcPauseP99Ms = Nothing
    , gcPauseMaxMs = Nothing
    , gcHeapUsedAfterGcBytes = Nothing
    }

data CompanionFrameSample = CompanionFrameSample
  { companionFrameTimeP50Ms :: Maybe Double
  , companionFrameTimeP95Ms :: Maybe Double
  , companionFrameTimeP99Ms :: Maybe Double
  , companionFpsAverage :: Maybe Double
  , companionStutterCount :: Maybe Int
  , companionDimension :: Maybe Text
  , companionShaderActive :: Maybe Bool
  , companionWorldLoaded :: Maybe Bool
  } deriving (Eq, Show)

instance ToJSON CompanionFrameSample where
  toJSON sample =
    object
      [ "frameTimeP50Ms" .= companionFrameTimeP50Ms sample
      , "frameTimeP95Ms" .= companionFrameTimeP95Ms sample
      , "frameTimeP99Ms" .= companionFrameTimeP99Ms sample
      , "fpsAverage" .= companionFpsAverage sample
      , "stutterCount" .= companionStutterCount sample
      , "dimension" .= companionDimension sample
      , "shaderActive" .= companionShaderActive sample
      , "worldLoaded" .= companionWorldLoaded sample
      ]

instance FromJSON CompanionFrameSample where
  parseJSON =
    withObject "CompanionFrameSample" $ \obj ->
      CompanionFrameSample
        <$> obj .:? "frameTimeP50Ms"
        <*> obj .:? "frameTimeP95Ms"
        <*> obj .:? "frameTimeP99Ms"
        <*> obj .:? "fpsAverage"
        <*> obj .:? "stutterCount"
        <*> obj .:? "dimension"
        <*> obj .:? "shaderActive"
        <*> obj .:? "worldLoaded"

data PerformanceSession = PerformanceSession
  { sessionLaunchSessionId :: Text
  , sessionGameDir :: FilePath
  , sessionInstanceFingerprint :: InstanceFingerprint
  , sessionBaselineProfileId :: Maybe Text
  , sessionCandidateProfileId :: Maybe Text
  , sessionStatus :: PerformanceSessionStatus
  , sessionStartedAt :: UTCTime
  , sessionEndedAt :: Maybe UTCTime
  , sessionLaunchMetrics :: LaunchMetrics
  , sessionMemoryMetrics :: MemoryMetrics
  , sessionGcMetrics :: GcMetrics
  , sessionCompanionFrameMetrics :: Maybe CompanionFrameSample
  , sessionAppliedProfile :: Maybe PerformanceProfile
  , sessionRollbackRef :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON PerformanceSession where
  toJSON session =
    object
      [ "launchSessionId" .= sessionLaunchSessionId session
      , "gameDir" .= sessionGameDir session
      , "instanceFingerprint" .= sessionInstanceFingerprint session
      , "baselineProfileId" .= sessionBaselineProfileId session
      , "candidateProfileId" .= sessionCandidateProfileId session
      , "status" .= sessionStatus session
      , "startedAt" .= sessionStartedAt session
      , "endedAt" .= sessionEndedAt session
      , "launchMetrics" .= sessionLaunchMetrics session
      , "memoryMetrics" .= sessionMemoryMetrics session
      , "gcMetrics" .= sessionGcMetrics session
      , "frameMetrics" .= sessionCompanionFrameMetrics session
      , "appliedProfile" .= sessionAppliedProfile session
      , "rollbackRef" .= sessionRollbackRef session
      ]

instance FromJSON PerformanceSession where
  parseJSON =
    withObject "PerformanceSession" $ \obj ->
      PerformanceSession
        <$> obj .: "launchSessionId"
        <*> obj .: "gameDir"
        <*> obj .: "instanceFingerprint"
        <*> obj .:? "baselineProfileId"
        <*> obj .:? "candidateProfileId"
        <*> obj .:? "status" .!= SessionStarted
        <*> obj .: "startedAt"
        <*> obj .:? "endedAt"
        <*> obj .:? "launchMetrics" .!= LaunchMetrics Nothing Nothing Nothing Nothing False []
        <*> obj .:? "memoryMetrics" .!= emptyMemoryMetrics
        <*> obj .:? "gcMetrics" .!= emptyGcMetrics
        <*> obj .:? "frameMetrics"
        <*> obj .:? "appliedProfile"
        <*> obj .:? "rollbackRef"

performanceSessionsRoot :: FilePath -> FilePath
performanceSessionsRoot gameDir =
  performanceRoot gameDir </> "sessions"

performanceSessionPath :: FilePath -> Text -> FilePath
performanceSessionPath gameDir launchSessionId =
  performanceSessionsRoot gameDir </> Text.unpack launchSessionId </> "performance-session.json"
