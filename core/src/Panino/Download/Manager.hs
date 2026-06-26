{-# LANGUAGE OverloadedStrings #-}

module Panino.Download.Manager
  ( DownloadException(..)
  , DownloadHostTelemetry(..)
  , DownloadJob(..)
  , DownloadMultipartTelemetry(..)
  , DownloadOptions(..)
  , DownloadProgress(..)
  , DownloadResult(..)
  , DownloadSummary(..)
  , defaultDownloadOptions
  , downloadSingle
  , downloadOptionsWithConcurrency
  , downloadOptionsWithOverrides
  , runDownloadJobs
  , runDownloadJobsWithProgress
  , runDownloadJobsWithOptionsAndProgressAndCancel
  , runDownloadJobsWithProgressAndCancel
  , sha1HexFile
  , withDownloadConcurrency
  ) where

import Control.Concurrent.Async
  ( mapConcurrently
  )
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , newMVar
  , readMVar
  )
import Control.Exception
  ( bracket_
  , finally
  )
import Control.Monad
  ( unless
  , when
  )
import Data.Int (Int64)
import qualified Data.Map.Strict as Map
import Data.Time.Clock
  ( UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Network.HTTP.Client (Manager)
import Panino.Download.Hash
  ( sha1HexFile
  )
import Panino.Download.HostGate
  ( buildHostGates
  , recordHostGateOutcome
  , withHostGate
  )
import Panino.Download.Manager.HostStats
  ( recordHostOutcome
  , reportHostStats
  )
import Panino.Download.Manager.Preverified
  ( partitionPreverifiedJobs
  )
import Panino.Download.Manager.Progress
  ( reportByteProgress
  , reportChunkProgress
  )
import Panino.Download.Scheduler
  ( SchedulerJob(..)
  , plannedWorkerCount
  )
import Panino.Download.Transfer
  ( DownloadOutcome(..)
  , downloadWithRetry
  , throwIfCancelled
  )
import Panino.Download.Types
  ( DownloadException(..)
  , DownloadHostTelemetry(..)
  , DownloadJob(..)
  , DownloadMultipartTelemetry(..)
  , DownloadOptions(..)
  , DownloadProgress(..)
  , DownloadResult(..)
  , DownloadSummary(..)
  )
import Panino.Perf.Metrics
  ( recordCoreResourceSnapshot
  )
import Panino.Download.VerificationIndex
  ( flushVerificationIndex
  )
import Panino.Download.WorkerLimit (fileDescriptorWorkerLimit)

defaultDownloadOptions :: DownloadOptions
defaultDownloadOptions =
  DownloadOptions
    { downloadOptionConcurrency = 32
    , downloadOptionRetryCount = 3
    }

downloadOptionsWithConcurrency :: Int -> DownloadOptions
downloadOptionsWithConcurrency concurrency =
  defaultDownloadOptions
    { downloadOptionConcurrency = clampDownloadConcurrency concurrency
    }

downloadOptionsWithOverrides :: Maybe Int -> Maybe Int -> DownloadOptions
downloadOptionsWithOverrides concurrency retryCount =
  DownloadOptions
    { downloadOptionConcurrency =
        maybe (downloadOptionConcurrency defaultDownloadOptions) clampDownloadConcurrency concurrency
    , downloadOptionRetryCount =
        maybe (downloadOptionRetryCount defaultDownloadOptions) clampDownloadRetryCount retryCount
    }

withDownloadConcurrency :: Int -> DownloadOptions -> DownloadOptions
withDownloadConcurrency concurrency options =
  options { downloadOptionConcurrency = clampDownloadConcurrency concurrency }

downloadOptionMaxAttempts :: DownloadOptions -> Int
downloadOptionMaxAttempts options =
  clampDownloadRetryCount (downloadOptionRetryCount options) + 1

clampDownloadConcurrency :: Int -> Int
clampDownloadConcurrency value =
  min 64 (max 1 value)

clampDownloadRetryCount :: Int -> Int
clampDownloadRetryCount value =
  min 10 (max 0 value)

downloadSingle :: Manager -> DownloadJob -> IO DownloadResult
downloadSingle manager job = do
  multipartProgress <- newMVar Nothing
  ( outcomeResult
      <$> downloadWithRetry
        manager
        (downloadOptionMaxAttempts defaultDownloadOptions)
        (downloadOptionConcurrency defaultDownloadOptions)
        multipartProgress
        (pure False)
        (\_ -> pure ())
        job
    )
    `finally` flushVerificationIndex

runDownloadJobs :: Manager -> Int -> [DownloadJob] -> IO DownloadSummary
runDownloadJobs manager concurrency jobs =
  runDownloadJobsWithProgress manager concurrency jobs (\_ -> pure ())

runDownloadJobsWithProgress :: Manager -> Int -> [DownloadJob] -> (DownloadProgress -> IO ()) -> IO DownloadSummary
runDownloadJobsWithProgress manager concurrency jobs onProgress =
  runDownloadJobsWithProgressAndCancel manager concurrency (pure False) jobs onProgress

runDownloadJobsWithProgressAndCancel :: Manager -> Int -> IO Bool -> [DownloadJob] -> (DownloadProgress -> IO ()) -> IO DownloadSummary
runDownloadJobsWithProgressAndCancel manager concurrency =
  runDownloadJobsWithOptionsAndProgressAndCancel manager (downloadOptionsWithConcurrency concurrency)

runDownloadJobsWithOptionsAndProgressAndCancel :: Manager -> DownloadOptions -> IO Bool -> [DownloadJob] -> (DownloadProgress -> IO ()) -> IO DownloadSummary
runDownloadJobsWithOptionsAndProgressAndCancel _ _ _ [] _ = do
  putStrLn "download plan is empty"
  pure DownloadSummary
    { downloadedCount = 0
    , skippedCount = 0
    , totalCount = 0
    }
runDownloadJobsWithOptionsAndProgressAndCancel manager options isCancelled jobs onProgress = do
  throwIfCancelled isCancelled
  (preverifiedJobs, pendingJobs) <- partitionPreverifiedJobs jobs
  unless (null preverifiedJobs) $
    putStrLn ("download_preverified skipped=" <> show (length preverifiedJobs) <> " pending=" <> show (length pendingJobs))
  when (null pendingJobs) $ do
    onProgress DownloadProgress
      { progressCompletedJobs = 1
      , progressTotalJobs = 1
      , progressCompletedBytes = 0
      , progressTotalBytes = 0
      , progressSpeedBytesPerSecond = 0
      , progressMovingAverageSpeedBytesPerSecond = 0
      , progressEtaSeconds = Just 0
      , progressPercent = Just 100
      , progressLabel = "download plan already verified"
      , progressHost = Nothing
      , progressLane = Nothing
      , progressActiveWorkers = 0
      , progressRetryCount = 0
      , progressSource = Nothing
      , progressHostTelemetry = []
      , progressThrottleReason = Nothing
      , progressMultipartTelemetry = Nothing
      }
  if null pendingJobs
    then
      pure DownloadSummary
        { downloadedCount = 0
        , skippedCount = length preverifiedJobs
        , totalCount = length jobs
        }
    else runPendingDownloads preverifiedJobs pendingJobs
  where
    runPendingDownloads preverifiedJobs pendingJobs = do
      counter <- newMVar (0 :: Int)
      byteCounter <- newMVar (0 :: Int64)
      activeCounter <- newMVar (0 :: Int)
      progressClock <- newMVar Nothing
      hostStats <- newMVar Map.empty
      multipartProgress <- newMVar Nothing
      startedAt <- getCurrentTime
      let schedulerJobs = map schedulerJob pendingJobs
          concurrency = downloadOptionConcurrency options
      plannedWorkers <- plannedWorkerCount concurrency schedulerJobs
      fdWorkerLimit <- fileDescriptorWorkerLimit
      let workerCount = max 1 (min plannedWorkers fdWorkerLimit)
      hostGates <- buildHostGates concurrency schedulerJobs
      queue <- newMVar pendingJobs
      putStrLn
        ( "download_scheduler"
            <> " requested="
            <> show concurrency
            <> " workers="
            <> show workerCount
            <> " planned="
            <> show plannedWorkers
            <> " fd_limit_workers="
            <> show fdWorkerLimit
            <> " jobs="
            <> show total
            <> " retries="
            <> show (downloadOptionRetryCount options)
        )
      recordCoreResourceSnapshot 0 workerCount total 4
      throwIfCancelled isCancelled
      onProgress DownloadProgress
        { progressCompletedJobs = 0
        , progressTotalJobs = total
        , progressCompletedBytes = 0
        , progressTotalBytes = totalBytes
        , progressSpeedBytesPerSecond = 0
        , progressMovingAverageSpeedBytesPerSecond = 0
        , progressEtaSeconds = Nothing
        , progressPercent = Just 0
        , progressLabel = "download plan"
        , progressHost = Nothing
        , progressLane = Nothing
        , progressActiveWorkers = 0
        , progressRetryCount = 0
        , progressSource = Nothing
        , progressHostTelemetry = []
        , progressThrottleReason = Nothing
        , progressMultipartTelemetry = Nothing
        }
      throwIfCancelled isCancelled
      results <-
        (concat <$> mapConcurrently (const (worker queue counter byteCounter activeCounter progressClock hostGates hostStats multipartProgress startedAt)) [1 .. workerCount])
          `finally` flushVerificationIndex
      activeAtFinish <- readMVar activeCounter
      recordCoreResourceSnapshot activeAtFinish workerCount 0 4
      reportHostStats hostStats startedAt
      let downloaded = length [() | Downloaded _ <- results]
          skipped = length preverifiedJobs + length [() | Skipped _ <- results]
      pure DownloadSummary
        { downloadedCount = downloaded
        , skippedCount = skipped
        , totalCount = length jobs
        }
      where
        total = length pendingJobs
        totalBytes = sum [size | Just size <- map jobSize pendingJobs]
        worker queue counter byteCounter activeCounter progressClock hostGates hostStats multipartProgress startedAt = do
          throwIfCancelled isCancelled
          next <- popDownloadJob queue
          throwIfCancelled isCancelled
          case next of
            Nothing -> pure []
            Just job -> do
              result <- downloadAndReport counter byteCounter activeCounter progressClock hostGates hostStats multipartProgress startedAt job
              (result :) <$> worker queue counter byteCounter activeCounter progressClock hostGates hostStats multipartProgress startedAt
        downloadAndReport counter byteCounter activeCounter progressClock hostGates hostStats multipartProgress startedAt job = do
          (outcome, elapsedMs) <-
            withHostGate hostGates job $
              withActiveWorker activeCounter $ do
                startedJob <- getCurrentTime
                throwIfCancelled isCancelled
                outcome <-
                  downloadWithRetry
                    manager
                    (downloadOptionMaxAttempts options)
                    (downloadOptionConcurrency options)
                    multipartProgress
                    isCancelled
                    (reportChunkProgress isCancelled counter byteCounter activeCounter progressClock hostGates multipartProgress startedAt totalBytes total onProgress job)
                    job
                finishedJob <- getCurrentTime
                pure (outcome, max 1 (elapsedMillis startedJob finishedJob))
          throwIfCancelled isCancelled
          throttleReason <-
            recordHostGateOutcome
              hostGates
              job
              (outcomeHost outcome)
              (outcomeBytes outcome)
              (outcomeRetries outcome)
              elapsedMs
          recordHostOutcome hostStats outcome
          let result = outcomeResult outcome
          done <- modifyMVar counter (\count -> let next = count + 1 in pure (next, next))
          putStrLn ("[" <> show done <> "/" <> show total <> "] " <> renderResult result)
          progress <- reportByteProgress byteCounter activeCounter hostGates multipartProgress startedAt totalBytes done total throttleReason outcome
          emitProgress progressClock done total progress
          pure result
        emitProgress progressClock done totalJobs progress = do
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

popDownloadJob :: MVar [DownloadJob] -> IO (Maybe DownloadJob)
popDownloadJob queue =
  modifyMVar queue $ \jobs ->
    case jobs of
      [] -> pure ([], Nothing)
      next:rest -> pure (rest, Just next)

elapsedMillis :: UTCTime -> UTCTime -> Int
elapsedMillis start end =
  floor (realToFrac (diffUTCTime end start) * (1000 :: Double))

withActiveWorker :: MVar Int -> IO value -> IO value
withActiveWorker activeCounter =
  bracket_
    (modifyMVar activeCounter (\count -> let next = count + 1 in pure (next, next)))
    (modifyMVar activeCounter (\count -> let next = max 0 (count - 1) in pure (next, next)))

renderResult :: DownloadResult -> String
renderResult (Downloaded job) = "downloaded " <> jobLabel job
renderResult (Skipped job) = "skipped " <> jobLabel job
