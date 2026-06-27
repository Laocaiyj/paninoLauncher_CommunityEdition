{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Minecraft.Progress
  ( MinecraftTaskPhase(..)
  , ProgressPhase
  , emitPhaseMarker
  , installProgressPhases
  , launchRepairProgressPhases
  , newAggregatedProgressSink
  , newInstallProgressSink
  ) where

import Control.Applicative ((<|>))
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , newMVar
  )
import Control.Monad (when)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Routes.Tasks (emitTaskProgress)
import Panino.Api.Routes.Minecraft.Phase
  ( MinecraftTaskPhase(..)
  , ProgressPhase
  , fallbackProgressPhase
  , installProgressPhases
  , launchRepairProgressPhases
  , minecraftTaskPhaseId
  , progressPhaseId
  , progressPhaseTitle
  )
import Panino.Api.Server.State (ServerState)
import Panino.Api.Types
  ( InstallRequest(..)
  , TaskPhaseId
  , TaskProgress(..)
  , TaskProgressHost(..)
  , TaskProgressMultipart(..)
  , TaskSnapshot(..)
  )
import Panino.Download.Manager
  ( DownloadHostTelemetry(..)
  , DownloadMultipartTelemetry(..)
  , DownloadProgress(..)
  )
import Panino.Minecraft.LoaderInstall (normalizeLoaderName)

data AggregatedProgressState = AggregatedProgressState
  { aggregatedPhaseIndex :: Int
  , aggregatedPhaseMaxPercent :: Double
  , aggregatedOverallMaxPercent :: Double
  } deriving (Eq, Show)

newAggregatedProgressSink :: ServerState -> TaskSnapshot -> [ProgressPhase] -> IO (DownloadProgress -> IO ())
newAggregatedProgressSink state task phases =
  newAggregatedProgressSinkFrom state task phases 0

newInstallProgressSink :: ServerState -> TaskSnapshot -> InstallRequest -> IO (DownloadProgress -> IO ())
newInstallProgressSink state task request = do
  emitDownload <- newAggregatedProgressSinkFrom state task installProgressPhases 1
  completion <- newMVar (0 :: Int, False)
  let expectedBatches = expectedInstallDownloadBatches request
  pure $ \progress -> do
    emitDownload progress
    when (downloadProgressComplete progress) $ do
      shouldEmitVerify <-
        modifyMVar completion $ \(completedBatches, verifyEmitted) -> do
          let nextCompleted = completedBatches + 1
              shouldEmit = not verifyEmitted && nextCompleted >= expectedBatches
          pure ((nextCompleted, verifyEmitted || shouldEmit), shouldEmit)
      when shouldEmitVerify $
        emitPhaseMarker state task MinecraftPhaseVerify "Verify instance" 5 5 80 "verifying instance"

expectedInstallDownloadBatches :: InstallRequest -> Int
expectedInstallDownloadBatches request =
  1
    + loaderExtraBatchCount (installRequestLoader request)
    + shaderDownloadBatchCount (installRequestShaderLoader request)

loaderExtraBatchCount :: Maybe Text -> Int
loaderExtraBatchCount maybeLoader =
  case normalizeLoaderName <$> maybeLoader of
    Just "fabric" -> 1
    Just "quilt" -> 1
    Just "forge" -> 1
    Just "neoforge" -> 1
    _ -> 0

shaderDownloadBatchCount :: Maybe Text -> Int
shaderDownloadBatchCount maybeShaderLoader =
  case normalizeLoaderName <$> maybeShaderLoader of
    Just "iris" -> 1
    Just "oculus" -> 1
    _ -> 0

downloadProgressComplete :: DownloadProgress -> Bool
downloadProgressComplete progress =
  progressTotalJobs progress > 0 && progressCompletedJobs progress >= progressTotalJobs progress

newAggregatedProgressSinkFrom :: ServerState -> TaskSnapshot -> [ProgressPhase] -> Int -> IO (DownloadProgress -> IO ())
newAggregatedProgressSinkFrom state task phases startIndex = do
  let phaseCount = max 1 (length phases)
      clampedStart = min (phaseCount - 1) (max 0 startIndex)
      initialOverall = fromIntegral clampedStart * 100 / fromIntegral phaseCount
  tracker <- newMVar (AggregatedProgressState clampedStart 0 initialOverall)
  pure $ \progress -> do
    taskProgress <- nextAggregatedProgress tracker task phases progress
    emitTaskProgress state task taskProgress

nextAggregatedProgress :: MVar AggregatedProgressState -> TaskSnapshot -> [ProgressPhase] -> DownloadProgress -> IO TaskProgress
nextAggregatedProgress tracker task phases progress =
  modifyMVar tracker $ \current -> do
    let phaseCount = max 1 (length phases)
        rawPhasePercent = clampPercent <$> progressPercent progress
        currentPhasePercent = fromMaybe (aggregatedPhaseMaxPercent current) rawPhasePercent
        shouldAdvance =
          maybe False
            (\value -> value + 5 < aggregatedPhaseMaxPercent current && aggregatedPhaseMaxPercent current >= 50)
            rawPhasePercent
        nextPhaseIndex =
          if shouldAdvance
            then min (phaseCount - 1) (aggregatedPhaseIndex current + 1)
            else aggregatedPhaseIndex current
        nextPhaseMax =
          if nextPhaseIndex == aggregatedPhaseIndex current
            then max (aggregatedPhaseMaxPercent current) currentPhasePercent
            else currentPhasePercent
        overall =
          (fromIntegral nextPhaseIndex + (nextPhaseMax / 100)) * 100 / fromIntegral phaseCount
        nextOverall = max (aggregatedOverallMaxPercent current) (clampPercent overall)
        next =
          AggregatedProgressState
            { aggregatedPhaseIndex = nextPhaseIndex
            , aggregatedPhaseMaxPercent = nextPhaseMax
            , aggregatedOverallMaxPercent = nextOverall
            }
        phase = phaseAt phases nextPhaseIndex
        taskProgress =
          taskProgressFromDownloadWithOverall
            task
            (progressPhaseId phase)
            (progressPhaseTitle phase)
            (nextPhaseIndex + 1)
            phaseCount
            nextOverall
            progress
    pure (next, taskProgress)

phaseAt :: [ProgressPhase] -> Int -> ProgressPhase
phaseAt phases index =
  case drop index phases of
    phase:_ -> phase
    [] -> fallbackProgressPhase

emitPhaseMarker :: ServerState -> TaskSnapshot -> MinecraftTaskPhase -> Text -> Int -> Int -> Double -> Text -> IO ()
emitPhaseMarker state task phase phaseTitle phaseIndex phaseCount overall label =
  emitTaskProgress
    state
    task
    TaskProgress
      { taskProgressTaskId = taskSnapshotId task
      , taskProgressPhaseId = minecraftTaskPhaseId phase
      , taskProgressPhaseTitle = phaseTitle
      , taskProgressPhaseIndex = phaseIndex
      , taskProgressPhaseCount = phaseCount
      , taskProgressPhasePercent = Just 0
      , taskProgressOverallPercent = Just (clampPercent overall)
      , taskProgressCompletedJobs = 0
      , taskProgressTotalJobs = 0
      , taskProgressCompletedBytes = 0
      , taskProgressTotalBytes = 0
      , taskProgressSpeedBytesPerSecond = 0
      , taskProgressMovingAverageSpeedBytesPerSecond = 0
      , taskProgressEtaSeconds = Nothing
      , taskProgressCurrentLabel = label
      , taskProgressActiveWorkers = 0
      , taskProgressRetryCount = 0
      , taskProgressSourceHost = Nothing
      , taskProgressHosts = []
      , taskProgressThrottleReason = Nothing
      , taskProgressMultipart = Nothing
      }

clampPercent :: Double -> Double
clampPercent =
  min 100 . max 0

taskProgressFromDownloadWithOverall :: TaskSnapshot -> TaskPhaseId -> Text -> Int -> Int -> Double -> DownloadProgress -> TaskProgress
taskProgressFromDownloadWithOverall task phaseId phaseTitle phaseIndex phaseCount overallPercent progress =
  TaskProgress
    { taskProgressTaskId = taskSnapshotId task
    , taskProgressPhaseId = phaseId
    , taskProgressPhaseTitle = phaseTitle
    , taskProgressPhaseIndex = phaseIndex
    , taskProgressPhaseCount = phaseCount
    , taskProgressPhasePercent = progressPercent progress
    , taskProgressOverallPercent = Just (clampPercent overallPercent)
    , taskProgressCompletedJobs = progressCompletedJobs progress
    , taskProgressTotalJobs = progressTotalJobs progress
    , taskProgressCompletedBytes = progressCompletedBytes progress
    , taskProgressTotalBytes = progressTotalBytes progress
    , taskProgressSpeedBytesPerSecond = progressSpeedBytesPerSecond progress
    , taskProgressMovingAverageSpeedBytesPerSecond = progressMovingAverageSpeedBytesPerSecond progress
    , taskProgressEtaSeconds = progressEtaSeconds progress
    , taskProgressCurrentLabel = Text.pack (progressLabel progress)
    , taskProgressActiveWorkers = progressActiveWorkers progress
    , taskProgressRetryCount = progressRetryCount progress
    , taskProgressSourceHost = progressHost progress <|> progressSource progress
    , taskProgressHosts = map taskProgressHostFromDownload (progressHostTelemetry progress)
    , taskProgressThrottleReason = progressThrottleReason progress
    , taskProgressMultipart = taskProgressMultipartFromDownload <$> progressMultipartTelemetry progress
    }

taskProgressHostFromDownload :: DownloadHostTelemetry -> TaskProgressHost
taskProgressHostFromDownload host =
  TaskProgressHost
    { taskProgressHostHost = hostTelemetryHost host
    , taskProgressHostLane = hostTelemetryLane host
    , taskProgressHostActiveConnections = hostTelemetryActiveConnections host
    , taskProgressHostGate = hostTelemetryGate host
    , taskProgressHostMaxGate = hostTelemetryMaxGate host
    , taskProgressHostBytesPerSecond = hostTelemetryBytesPerSecond host
    , taskProgressHostCompletedBytes = hostTelemetryCompletedBytes host
    , taskProgressHostCompletedJobs = hostTelemetryCompletedJobs host
    , taskProgressHostRetryCount = hostTelemetryRetryCount host
    }

taskProgressMultipartFromDownload :: DownloadMultipartTelemetry -> TaskProgressMultipart
taskProgressMultipartFromDownload multipart =
  TaskProgressMultipart
    { taskProgressMultipartLabel = multipartTelemetryLabel multipart
    , taskProgressMultipartCompletedSegments = multipartTelemetryCompletedSegments multipart
    , taskProgressMultipartTotalSegments = multipartTelemetryTotalSegments multipart
    , taskProgressMultipartActiveSegments = multipartTelemetryActiveSegments multipart
    , taskProgressMultipartSegmentBytes = multipartTelemetrySegmentBytes multipart
    , taskProgressMultipartTotalBytes = multipartTelemetryTotalBytes multipart
    , taskProgressMultipartCurrentSegment = multipartTelemetryCurrentSegment multipart
    }
