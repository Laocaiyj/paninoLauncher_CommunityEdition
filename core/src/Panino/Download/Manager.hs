{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}

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

import Control.Applicative ((<|>))
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
  ( SomeException
  , bracket_
  , finally
  , try
  )
import Control.Monad
  ( foldM
  , unless
  , when
  )
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
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
  ( HostGate
  , buildHostGates
  , recordHostGateOutcome
  , snapshotHostTelemetry
  , withHostGate
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
  , recordDownloadHostSummary
  )
import Panino.Download.Scheduler
  ( SchedulerJob(..)
  , laneForJob
  , plannedWorkerCount
  , renderLane
  , schedulerJobHost
  )
import Panino.Download.Transfer
  ( DownloadOutcome(..)
  , downloadWithRetry
  , throwIfCancelled
  )
import Panino.Download.VerificationIndex
  ( flushVerificationIndex
  , lookupVerifiedFile
  )
import Panino.Download.WorkerLimit (fileDescriptorWorkerLimit)
import System.Directory
  ( doesFileExist
  , getFileSize
  )

data HostDownloadStats = HostDownloadStats
  { hostStatsBytes :: Int64
  , hostStatsDownloaded :: Int
  , hostStatsRetries :: Int
  , hostStatsResumed :: Int
  } deriving (Eq, Show)

defaultDownloadOptions :: DownloadOptions
defaultDownloadOptions =
  DownloadOptions
    { downloadOptionConcurrency = 32
    , downloadOptionRetryCount = 3
    }

incompleteProgressPercentCap :: Double
incompleteProgressPercentCap = 99.0

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

partitionPreverifiedJobs :: [DownloadJob] -> IO ([DownloadJob], [DownloadJob])
partitionPreverifiedJobs jobs = do
  (verified, pending) <- foldM step ([], []) jobs
  pure (reverse verified, reverse pending)
  where
    step (verified, pending) job = do
      valid <- fastPreverifiedFileIsValid job
      if valid
        then pure (job : verified, pending)
        else pure (verified, job : pending)

fastPreverifiedFileIsValid :: DownloadJob -> IO Bool
fastPreverifiedFileIsValid job = do
  result <- try $ do
    exists <- doesFileExist (jobTargetPath job)
    if not exists
      then pure False
      else do
        sizeOk <-
          case jobSize job of
            Nothing -> pure True
            Just expected -> (== expected) . fromIntegral <$> getFileSize (jobTargetPath job)
        if not sizeOk
          then pure False
          else
            case jobSha1 job of
              Nothing -> pure True
              Just expected -> lookupVerifiedFile (jobTargetPath job) (Just expected)
  case result of
    Right valid -> pure valid
    Left (_ :: SomeException) -> pure False

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
    , contextSource = Just (Text.pack (jobUrl job))
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

recordHostOutcome :: MVar (Map Text HostDownloadStats) -> DownloadOutcome -> IO ()
recordHostOutcome hostStats outcome =
  case outcomeHost outcome of
    Nothing -> pure ()
    Just host ->
      modifyMVar hostStats $ \stats ->
        pure (Map.insertWith mergeHostStats host (hostStatsFor outcome) stats, ())

hostStatsFor :: DownloadOutcome -> HostDownloadStats
hostStatsFor outcome =
  HostDownloadStats
    { hostStatsBytes = outcomeBytes outcome
    , hostStatsDownloaded =
        case outcomeResult outcome of
          Downloaded _ -> 1
          Skipped _ -> 0
    , hostStatsRetries = outcomeRetries outcome
    , hostStatsResumed = if outcomeResumed outcome then 1 else 0
    }

mergeHostStats :: HostDownloadStats -> HostDownloadStats -> HostDownloadStats
mergeHostStats new old =
  HostDownloadStats
    { hostStatsBytes = hostStatsBytes new + hostStatsBytes old
    , hostStatsDownloaded = hostStatsDownloaded new + hostStatsDownloaded old
    , hostStatsRetries = hostStatsRetries new + hostStatsRetries old
    , hostStatsResumed = hostStatsResumed new + hostStatsResumed old
    }

reportHostStats :: MVar (Map Text HostDownloadStats) -> UTCTime -> IO ()
reportHostStats hostStats startedAt = do
  stats <- readMVar hostStats
  finished <- getCurrentTime
  let elapsed = max 0.001 (realToFrac (diffUTCTime finished startedAt) :: Double)
      report (host, item) =
        recordDownloadHostSummary
          host
          (hostStatsBytes item)
          (round (fromIntegral (hostStatsBytes item) / elapsed :: Double))
          (hostStatsDownloaded item)
          (hostStatsRetries item)
          (hostStatsResumed item)
  mapM_ report (Map.toList stats)

renderResult :: DownloadResult -> String
renderResult (Downloaded job) = "downloaded " <> jobLabel job
renderResult (Skipped job) = "skipped " <> jobLabel job

resultJob :: DownloadResult -> DownloadJob
resultJob (Downloaded job) = job
resultJob (Skipped job) = job
