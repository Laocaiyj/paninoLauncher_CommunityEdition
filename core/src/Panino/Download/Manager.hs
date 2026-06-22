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
import Control.Concurrent (threadDelay)
import Control.Concurrent.Async
  ( AsyncCancelled
  , mapConcurrently
  )
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , newMVar
  , readMVar
  )
import Control.Exception
  ( IOException
  , SomeException
  , SomeAsyncException
  , bracket_
  , catch
  , finally
  , fromException
  , throwIO
  , try
  )
import Control.Monad
  ( foldM
  , unless
  , when
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Data.Int (Int64)
import Data.List (isInfixOf)
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
import Data.Time.Clock.POSIX (getPOSIXTime)
import Network.HTTP.Client
  ( BodyReader
  , Manager
  , Response
  , parseRequest
  , requestHeaders
  , responseBody
  , responseHeaders
  , responseStatus
  , withResponse
  )
import Network.HTTP.Types
  ( HeaderName
  , statusCode
  )
import Panino.Download.Hash
  ( FileDigest(..)
  , HashState
  , appendHashChunk
  , emptyHashState
  , finalizeHashState
  , hashFileState
  , sha1HexFile
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
import Panino.Net.Http
  ( RequestTimeoutClass(..)
  , applyRequestTimeout
  )
import Panino.Net.Probe
  ( preferFastestUrls
  , recordSourceFailure
  , recordSourceHashMismatch
  , recordSourceThroughput
  , sourceHostKey
  )
import Panino.Net.Sources (resolveSourceUrls)
import Panino.Perf.Metrics
  ( recordCoreResourceSnapshot
  , recordDownloadHostSummary
  )
import Panino.Download.Multipart
  ( MultipartException(..)
  , MultipartJob(..)
  , MultipartProgress(..)
  , MultipartResult(..)
  , multipartDownloadWithProgress
  , multipartMinBytes
  )
import Panino.Download.Scheduler
  ( SchedulerJob(..)
  , laneForJob
  , plannedWorkerCount
  , renderLane
  , schedulerJobHost
  )
import Panino.Download.VerificationIndex
  ( flushVerificationIndex
  , lookupVerifiedFile
  , recordVerifiedFile
  )
import Panino.Download.WorkerLimit (fileDescriptorWorkerLimit)
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , getFileSize
  , removeFile
  , renameFile
  )
import System.FilePath
  ( takeDirectory
  , (<.>)
  )
import System.IO
  ( IOMode(..)
  , hFlush
  , withBinaryFile
  )

data DownloadOutcome = DownloadOutcome
  { outcomeResult :: DownloadResult
  , outcomeHost :: Maybe Text
  , outcomeBytes :: Int64
  , outcomeRetries :: Int
  , outcomeResumed :: Bool
  } deriving (Eq, Show)

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

recordMultipartProgress :: MVar (Maybe DownloadMultipartTelemetry) -> MultipartProgress -> IO ()
recordMultipartProgress progressVar progress =
  modifyMVar progressVar $ \_ ->
    pure
      ( Just DownloadMultipartTelemetry
          { multipartTelemetryLabel = Text.pack (multipartProgressLabel progress)
          , multipartTelemetryCompletedSegments = multipartProgressCompletedSegments progress
          , multipartTelemetryTotalSegments = multipartProgressTotalSegments progress
          , multipartTelemetryActiveSegments = multipartProgressActiveSegments progress
          , multipartTelemetrySegmentBytes = multipartProgressSegmentBytes progress
          , multipartTelemetryTotalBytes = multipartProgressTotalBytes progress
          , multipartTelemetryCurrentSegment = multipartProgressCurrentSegment progress
          }
      , ()
      )

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

downloadWithRetry :: Manager -> Int -> Int -> MVar (Maybe DownloadMultipartTelemetry) -> IO Bool -> (Int64 -> IO ()) -> DownloadJob -> IO DownloadOutcome
downloadWithRetry manager maxAttempts multipartConcurrency multipartProgress isCancelled onChunk job = go (1 :: Int)
  where
    go attempt = do
      throwIfCancelled isCancelled
      result <- try (downloadOnce manager multipartConcurrency multipartProgress isCancelled onChunk job)
      case result of
        Right value -> pure value { outcomeRetries = attempt - 1 }
        Left err
          | isCancellationException (err :: SomeException) ->
              throwIO err
          | attempt < maxAttempts && retryableException (err :: SomeException) -> do
              delay <- retryDelayMicros attempt (err :: SomeException)
              putStrLn
                ( "retry "
                    <> show attempt
                    <> "/"
                    <> show maxAttempts
                    <> " for "
                    <> jobLabel job
                    <> ": "
                    <> show (err :: SomeException)
                )
              throwIfCancelled isCancelled
              threadDelay delay
              throwIfCancelled isCancelled
              go (attempt + 1)
          | otherwise ->
              throwIO err

retryableException :: SomeException -> Bool
retryableException err =
  if isCancellationException err
    then False
    else case fromException err of
      Just (DownloadHttpStatus status _ _) -> retryableStatus status
      Just DownloadCancelled -> False
      Nothing -> True

isCancellationException :: SomeException -> Bool
isCancellationException err =
  isDownloadCancelled || isAsyncCancelled || isSomeAsyncException
  where
    isDownloadCancelled =
      case fromException err of
        Just DownloadCancelled -> True
        Just _ -> False
        Nothing -> False
    isAsyncCancelled =
      case fromException err of
        Just (_ :: AsyncCancelled) -> True
        Nothing -> False
    isSomeAsyncException =
      case fromException err of
        Just (_ :: SomeAsyncException) -> True
        Nothing -> False

throwIfCancelled :: IO Bool -> IO ()
throwIfCancelled isCancelled = do
  cancelled <- isCancelled
  when cancelled (throwIO DownloadCancelled)

retryDelayMicros :: Int -> SomeException -> IO Int
retryDelayMicros attempt err =
  case retryAfterDelay of
    Just delay -> pure delay
    Nothing -> addJitter (min 30000000 (1000000 * (2 ^ max 0 (attempt - 1))))
  where
    retryAfterDelay = do
      DownloadHttpStatus status retryAfterSeconds _ <- fromException err
      if retryableStatus status
        then (* 1000000) <$> retryAfterSeconds
        else Nothing

retryableStatus :: Int -> Bool
retryableStatus status =
  status == 408 || status == 429 || status >= 500

addJitter :: Int -> IO Int
addJitter baseDelay = do
  now <- getPOSIXTime
  let window = max 1 (baseDelay `div` 4)
      jitter = floor (now * 1000000) `mod` window
  pure (baseDelay + jitter)

downloadOnce :: Manager -> Int -> MVar (Maybe DownloadMultipartTelemetry) -> IO Bool -> (Int64 -> IO ()) -> DownloadJob -> IO DownloadOutcome
downloadOnce manager multipartConcurrency multipartProgress isCancelled onChunk job = do
  throwIfCancelled isCancelled
  valid <- existingFileIsValid job
  if valid
    then
      pure DownloadOutcome
        { outcomeResult = Skipped job
        , outcomeHost = Nothing
        , outcomeBytes = 0
        , outcomeRetries = 0
        , outcomeResumed = False
        }
    else do
      throwIfCancelled isCancelled
      createDirectoryIfMissing True (takeDirectory (jobTargetPath job))
      resolvedUrls <- resolveSourceUrls (jobUrl job)
      throwIfCancelled isCancelled
      orderedUrls <- preferFastestUrls manager resolvedUrls
      throwIfCancelled isCancelled
      startedDownload <- getCurrentTime
      (digest, selectedUrl, resumed) <- downloadFromCandidates orderedUrls
      finishedDownload <- getCurrentTime
      let downloadedBytes = fromIntegral (fileDigestSize digest)
          elapsed = max 0.001 (realToFrac (diffUTCTime finishedDownload startedDownload) :: Double)
          bytesPerSecond = round (fromIntegral downloadedBytes / elapsed :: Double)
      recordSourceThroughput selectedUrl downloadedBytes bytesPerSecond
      throwIfCancelled isCancelled
      removeIfExists (jobTargetPath job)
      renameFile (partPath job) (jobTargetPath job)
      recordVerifiedFile (jobTargetPath job) (jobSha1 job)
      pure DownloadOutcome
        { outcomeResult = Downloaded job
        , outcomeHost = Just (Text.pack (sourceHostKey selectedUrl))
        , outcomeBytes = downloadedBytes
        , outcomeRetries = 0
        , outcomeResumed = resumed
        }
  where
    downloadFromCandidates [] =
      fail ("no download source available for " <> jobLabel job)
    downloadFromCandidates [url] =
      throwIfCancelled isCancelled >>
      downloadAndVerify url
    downloadFromCandidates (url:fallbacks) =
      throwIfCancelled isCancelled >>
      ( downloadAndVerify url `catch` \(err :: SomeException) ->
          if isCancellationException err
            then throwIO err
            else do
              recordCandidateFailure url (show err)
              removeIfExists (partPath job)
              putStrLn ("source_fallback " <> jobLabel job <> ": " <> show err)
              downloadFromCandidates fallbacks
      )

    downloadAndVerify resolvedUrl = do
      throwIfCancelled isCancelled
      (digest, resumed) <- downloadFromUrl resolvedUrl
      throwIfCancelled isCancelled
      verifyDownloadedFile job (partPath job) digest
      pure (digest, resolvedUrl, resumed)

    recordCandidateFailure url reason =
      if "verification" `isInfixOf` reason || "hash" `isInfixOf` reason || "checksum" `isInfixOf` reason
        then recordSourceHashMismatch url reason
        else recordSourceFailure url reason

    downloadFromUrl resolvedUrl = do
      throwIfCancelled isCancelled
      modifyMVar multipartProgress (\_ -> pure (Nothing, ()))
      partSize <- normalizePartSize job =<< existingPartSize job
      minMultipartBytes <- multipartMinBytes
      if partSize == 0 && maybe False (>= minMultipartBytes) (jobSize job)
        then do
          multipartResult <-
            try
              ( multipartDownloadWithProgress
                  manager
                  (min 16 multipartConcurrency)
                  (throwIfCancelled isCancelled)
                  MultipartJob
                    { multipartJobLabel = jobLabel job
                    , multipartJobUrl = resolvedUrl
                    , multipartJobTargetPartPath = partPath job
                    , multipartJobSize = fromMaybe 0 (jobSize job)
                  }
                  onChunk
                  (recordMultipartProgress multipartProgress)
              )
          case multipartResult of
            Right result -> do
              throwIfCancelled isCancelled
              digest <- finalizeHashState <$> hashFileState (partPath job)
              pure (digest, multipartResultResumed result)
            Left err ->
              case fromException (err :: SomeException) of
                Just (MultipartUnsupported reason) -> do
                  putStrLn ("multipart_fallback " <> jobLabel job <> ": " <> reason)
                  singleStreamDownload resolvedUrl partSize
                _ -> throwIO (err :: SomeException)
        else singleStreamDownload resolvedUrl partSize

    singleStreamDownload resolvedUrl partSize = do
      throwIfCancelled isCancelled
      baseRequest <- applyRequestTimeout DownloadTransfer <$> parseRequest resolvedUrl
      let request =
            if partSize > 0
              then baseRequest { requestHeaders = ("Range", BS8.pack ("bytes=" <> show partSize <> "-")) : requestHeaders baseRequest }
              else baseRequest
      withResponse request manager $ \response -> do
        let status = statusCode (responseStatus response)
            retryAfter = parseRetryAfter response
        if partSize > 0 && status == 416
          then do
            removeIfExists (partPath job)
            downloadFromUrl resolvedUrl
          else do
            if status >= 200 && status < 300
              then pure ()
              else throwIO (DownloadHttpStatus status retryAfter (jobLabel job))
            throwIfCancelled isCancelled
            case (partSize > 0, status) of
              (True, 206) -> do
                initialState <- hashFileState (partPath job)
                (, True) <$> streamResponseBody isCancelled AppendMode initialState onChunk (responseBody response) (partPath job)
              (True, 200) -> do
                removeIfExists (partPath job)
                (, False) <$> streamResponseBody isCancelled WriteMode emptyHashState onChunk (responseBody response) (partPath job)
              (True, _) -> do
                removeIfExists (partPath job)
                (, False) <$> streamResponseBody isCancelled WriteMode emptyHashState onChunk (responseBody response) (partPath job)
              (False, _) ->
                (, False) <$> streamResponseBody isCancelled WriteMode emptyHashState onChunk (responseBody response) (partPath job)

existingPartSize :: DownloadJob -> IO Integer
existingPartSize job = do
  exists <- doesFileExist (partPath job)
  if exists
    then getFileSize (partPath job)
    else pure 0

normalizePartSize :: DownloadJob -> Integer -> IO Integer
normalizePartSize job partSize
  | partSize <= 0 = pure 0
  | maybe False (\expected -> partSize >= toInteger expected) (jobSize job) = do
      removeIfExists (partPath job)
      pure 0
  | otherwise = pure partSize

streamResponseBody :: IO Bool -> IOMode -> HashState -> (Int64 -> IO ()) -> BodyReader -> FilePath -> IO FileDigest
streamResponseBody isCancelled mode initialState onChunk reader target =
  withBinaryFile target mode $ \handle ->
    let reportThreshold = 262144 :: Int64
        loop state pendingBytes = do
          throwIfCancelled isCancelled
          chunk <- reader
          throwIfCancelled isCancelled
          if BS.null chunk
            then do
              when (pendingBytes > 0) (onChunk pendingBytes >> throwIfCancelled isCancelled)
              hFlush handle
              pure (finalizeHashState state)
            else do
              BS.hPut handle chunk
              let chunkLength = fromIntegral (BS.length chunk)
                  nextPending = pendingBytes + chunkLength
              reportedPending <-
                if nextPending >= reportThreshold
                  then onChunk nextPending >> throwIfCancelled isCancelled >> pure 0
                  else pure nextPending
              loop (appendHashChunk state chunk) reportedPending
     in loop initialState 0

existingFileIsValid :: DownloadJob -> IO Bool
existingFileIsValid job = do
  exists <- doesFileExist (jobTargetPath job)
  if not exists
    then pure False
    else verifyFile job (jobTargetPath job)

verifyDownloadedFile :: DownloadJob -> FilePath -> FileDigest -> IO ()
verifyDownloadedFile job path digest = do
  let sizeOk =
        case jobSize job of
          Nothing -> True
          Just expected -> fileDigestSize digest == toInteger expected
      shaOk =
        case jobSha1 job of
          Nothing -> True
          Just expected -> fileDigestSha1 digest == Text.toLower expected
      valid = sizeOk && shaOk
  if valid
    then pure ()
    else do
      removeIfExists path
      fail ("downloaded file failed verification: " <> jobLabel job <> " -> " <> path)

verifyFile :: DownloadJob -> FilePath -> IO Bool
verifyFile job path = do
  indexed <- lookupVerifiedFile path (jobSha1 job)
  if indexed
    then pure True
    else do
      sizeOk <- case jobSize job of
        Nothing -> pure True
        Just expected -> (== expected) . fromIntegral <$> getFileSize path
      shaOk <- case jobSha1 job of
        Nothing -> pure True
        Just expected -> (== Text.toLower expected) <$> sha1HexFile path
      let valid = sizeOk && shaOk
      if valid
        then recordVerifiedFile path (jobSha1 job)
        else pure ()
      pure valid

parseRetryAfter :: Response body -> Maybe Int
parseRetryAfter response =
  lookup hRetryAfter (responseHeaders response) >>= readMaybeBytes

hRetryAfter :: HeaderName
hRetryAfter = "Retry-After"

readMaybeBytes :: BS.ByteString -> Maybe Int
readMaybeBytes value =
  case reads (BS8.unpack value) of
    (seconds, _) : _ -> Just seconds
    [] -> Nothing

partPath :: DownloadJob -> FilePath
partPath job = jobTargetPath job <.> "part"

removeIfExists :: FilePath -> IO ()
removeIfExists path =
  removeFile path `catch` \(_ :: IOException) -> pure ()

renderResult :: DownloadResult -> String
renderResult (Downloaded job) = "downloaded " <> jobLabel job
renderResult (Skipped job) = "skipped " <> jobLabel job

resultJob :: DownloadResult -> DownloadJob
resultJob (Downloaded job) = job
resultJob (Skipped job) = job
