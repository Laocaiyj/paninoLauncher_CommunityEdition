{-# LANGUAGE OverloadedStrings #-}

module Panino.Download.Manager.Progress
  ( reportByteProgress
  , reportChunkProgress
  ) where

import Control.Applicative ((<|>))
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , readMVar
  )
import Control.Monad (when)
import Data.Int (Int64)
import Data.Map.Strict (Map)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Data.Time.Clock
  ( UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Panino.Download.HostGate
  ( HostGate
  , snapshotHostTelemetry
  )
import Panino.Download.Scheduler
  ( SchedulerJob(..)
  , laneForJob
  , renderLane
  , schedulerJobHost
  )
import Panino.Download.Transfer
  ( DownloadOutcome(..)
  , throwIfCancelled
  )
import Panino.Download.Types
  ( DownloadHostTelemetry(..)
  , DownloadJob(..)
  , DownloadMultipartTelemetry
  , DownloadProgress(..)
  , DownloadResult(..)
  )
import Panino.Core.Types
  ( urlText
  )

incompleteProgressPercentCap :: Double
incompleteProgressPercentCap = 99.0

reportChunkProgress :: IO Bool -> MVar Int -> MVar Int64 -> MVar Int -> MVar (Maybe UTCTime) -> Map Text HostGate -> MVar (Maybe DownloadMultipartTelemetry) -> UTCTime -> Int64 -> Int -> (DownloadProgress -> IO ()) -> DownloadJob -> Int64 -> IO ()
reportChunkProgress isCancelled counter byteCounter activeCounter progressClock hostGates multipartProgress startedAt totalBytes total onProgress job chunkBytes = do
  throwIfCancelled isCancelled
  completedBytes <- modifyMVar byteCounter $ \current -> do
    let next = current + max 0 chunkBytes
    pure (next, next)
  done <- readMVar counter
  activeWorkers <- readMVar activeCounter
  hostTelemetry <- snapshotHostTelemetry hostGates
  multipartTelemetry <- readMVar multipartProgress
  progress <- progressSnapshot startedAt totalBytes done total completedBytes (progressContext job activeWorkers 0 Nothing hostTelemetry Nothing multipartTelemetry)
  emitLiveProgress progressClock done total progress onProgress
  throwIfCancelled isCancelled

reportByteProgress :: MVar Int64 -> MVar Int -> Map Text HostGate -> MVar (Maybe DownloadMultipartTelemetry) -> UTCTime -> Int64 -> Int -> Int -> Maybe Text -> DownloadOutcome -> IO DownloadProgress
reportByteProgress byteCounter activeCounter hostGates multipartProgress startedAt totalBytes done total throttleReason outcome = do
  completedBytes <- modifyMVar byteCounter $ \current -> do
    let completionBytes =
          case outcomeResult outcome of
            Skipped job -> fromMaybe 0 (jobSize job)
            Downloaded _ -> 0
        next = current + completionBytes
    pure (next, next)
  activeWorkers <- readMVar activeCounter
  hostTelemetry <- snapshotHostTelemetry hostGates
  multipartTelemetry <- readMVar multipartProgress
  let result = outcomeResult outcome
  progress <-
    progressSnapshot
      startedAt
      totalBytes
      done
      total
      completedBytes
      (progressContext (resultJob result) activeWorkers (outcomeRetries outcome) (outcomeHost outcome) hostTelemetry throttleReason multipartTelemetry)
  putStrLn
    ( "progress bytes="
        <> show (progressCompletedBytes progress)
        <> "/"
        <> show totalBytes
        <> " speed="
        <> show (progressSpeedBytesPerSecond progress)
        <> "Bps"
        <> maybe "" (\value -> " eta=" <> show value <> "s") (progressEtaSeconds progress)
        <> maybe "" (\value -> " percent=" <> show (round value :: Int) <> "%") (progressPercent progress)
    )
  pure progress

data ProgressContext = ProgressContext
  { contextLabel :: String
  , contextHost :: Maybe Text
  , contextLane :: Maybe Text
  , contextActiveWorkers :: Int
  , contextRetryCount :: Int
  , contextSource :: Maybe Text
  , contextHostTelemetry :: [DownloadHostTelemetry]
  , contextThrottleReason :: Maybe Text
  , contextMultipartTelemetry :: Maybe DownloadMultipartTelemetry
  } deriving (Eq, Show)

progressContext :: DownloadJob -> Int -> Int -> Maybe Text -> [DownloadHostTelemetry] -> Maybe Text -> Maybe DownloadMultipartTelemetry -> ProgressContext
progressContext job activeWorkers retryCount selectedHost hostTelemetry throttleReason multipartTelemetry =
  ProgressContext
    { contextLabel = jobLabel job
    , contextHost = selectedHost <|> Just (schedulerJobHost (schedulerJob job))
    , contextLane = Just (renderLane (laneForJob (schedulerJob job)))
    , contextActiveWorkers = activeWorkers
    , contextRetryCount = retryCount
    , contextSource = Just (urlText (jobUrl job))
    , contextHostTelemetry = hostTelemetry
    , contextThrottleReason = throttleReason
    , contextMultipartTelemetry = multipartTelemetry
    }

progressSnapshot :: UTCTime -> Int64 -> Int -> Int -> Int64 -> ProgressContext -> IO DownloadProgress
progressSnapshot startedAt totalBytes done total completedBytes context = do
  now <- getCurrentTime
  let visibleCompleted =
        if totalBytes <= 0
          then completedBytes
          else min completedBytes totalBytes
      allJobsDone = total <= 0 || done >= total
      elapsed = max 0.001 (realToFrac (diffUTCTime now startedAt) :: Double)
      speed = round (fromIntegral completedBytes / elapsed :: Double) :: Int64
      movingAverageSpeed = max speed (maximum (0 : map hostTelemetryBytesPerSecond (contextHostTelemetry context)))
      remaining = max 0 (totalBytes - visibleCompleted)
      eta =
        if speed <= 0 || (remaining <= 0 && not allJobsDone)
          then Nothing
          else Just (remaining `div` speed)
      jobPercent =
        if total > 0
          then Just (fromIntegral done * 100.0 / fromIntegral total :: Double)
          else Nothing
      capUntilComplete value =
        if allJobsDone
          then value
          else min incompleteProgressPercentCap value
      percent =
        if totalBytes > 0
          then Just (capUntilComplete (fromIntegral visibleCompleted * 100.0 / fromIntegral totalBytes :: Double))
          else capUntilComplete <$> jobPercent
  pure DownloadProgress
    { progressCompletedJobs = done
    , progressTotalJobs = total
    , progressCompletedBytes = visibleCompleted
    , progressTotalBytes = totalBytes
    , progressSpeedBytesPerSecond = speed
    , progressMovingAverageSpeedBytesPerSecond = movingAverageSpeed
    , progressEtaSeconds = eta
    , progressPercent = percent
    , progressLabel = contextLabel context
    , progressHost = contextHost context
    , progressLane = contextLane context
    , progressActiveWorkers = contextActiveWorkers context
    , progressRetryCount = contextRetryCount context
    , progressSource = contextSource context
    , progressHostTelemetry = contextHostTelemetry context
    , progressThrottleReason = contextThrottleReason context
    , progressMultipartTelemetry = contextMultipartTelemetry context
    }

emitLiveProgress :: MVar (Maybe UTCTime) -> Int -> Int -> DownloadProgress -> (DownloadProgress -> IO ()) -> IO ()
emitLiveProgress progressClock done totalJobs progress onProgress = do
  now <- getCurrentTime
  shouldEmit <-
    modifyMVar progressClock $ \lastEmitted ->
      let due =
            case lastEmitted of
              Nothing -> True
              Just emittedAt -> diffUTCTime now emittedAt >= 0.25
          terminal = done >= totalJobs
       in if due || terminal
            then pure (Just now, True)
            else pure (lastEmitted, False)
  when shouldEmit (onProgress progress)

schedulerJob :: DownloadJob -> SchedulerJob
schedulerJob job =
  SchedulerJob
    { schedulerJobUrl = jobUrl job
    , schedulerJobSize = jobSize job
    }

resultJob :: DownloadResult -> DownloadJob
resultJob (Downloaded job) = job
resultJob (Skipped job) = job
