{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveDataTypeable #-}
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
  ( Exception
  , IOException
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
import qualified Crypto.Hash.SHA1 as SHA1
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Data.Int (Int64)
import Data.List (isInfixOf, sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Typeable (Typeable)
import Data.Word (Word8)
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
import Numeric (showHex)
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
  ( DownloadLane(..)
  , SchedulerJob(..)
  , hostConcurrencyLimit
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
  , Handle
  , hFlush
  , withBinaryFile
  )
import System.Exit (ExitCode(..))
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )

data DownloadJob = DownloadJob
  { jobLabel :: String
  , jobUrl :: String
  , jobTargetPath :: FilePath
  , jobSha1 :: Maybe Text
  , jobSize :: Maybe Int64
  } deriving (Eq, Show)

data DownloadResult
  = Downloaded DownloadJob
  | Skipped DownloadJob
  deriving (Eq, Show)

data DownloadOptions = DownloadOptions
  { downloadOptionConcurrency :: Int
  , downloadOptionRetryCount :: Int
  } deriving (Eq, Show)

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

data HostGate = HostGate
  { hostGateHost :: Text
  , hostGateState :: MVar HostGateState
  }

data HostGateState = HostGateState
  { gateLane :: DownloadLane
  , gateActive :: Int
  , gateLimit :: Int
  , gateMaxLimit :: Int
  , gateCompletedBytes :: Int64
  , gateCompletedJobs :: Int
  , gateRetryCount :: Int
  , gateLastBytesPerSecond :: Int64
  } deriving (Eq, Show)

data DownloadSummary = DownloadSummary
  { downloadedCount :: Int
  , skippedCount :: Int
  , totalCount :: Int
  } deriving (Eq, Show)

data DownloadHostTelemetry = DownloadHostTelemetry
  { hostTelemetryHost :: Text
  , hostTelemetryLane :: Text
  , hostTelemetryActiveConnections :: Int
  , hostTelemetryGate :: Int
  , hostTelemetryMaxGate :: Int
  , hostTelemetryBytesPerSecond :: Int64
  , hostTelemetryCompletedBytes :: Int64
  , hostTelemetryCompletedJobs :: Int
  , hostTelemetryRetryCount :: Int
  } deriving (Eq, Show)

data DownloadMultipartTelemetry = DownloadMultipartTelemetry
  { multipartTelemetryLabel :: Text
  , multipartTelemetryCompletedSegments :: Int
  , multipartTelemetryTotalSegments :: Int
  , multipartTelemetryActiveSegments :: Int
  , multipartTelemetrySegmentBytes :: Int64
  , multipartTelemetryTotalBytes :: Int64
  , multipartTelemetryCurrentSegment :: Maybe Int
  } deriving (Eq, Show)

data DownloadProgress = DownloadProgress
  { progressCompletedJobs :: Int
  , progressTotalJobs :: Int
  , progressCompletedBytes :: Int64
  , progressTotalBytes :: Int64
  , progressSpeedBytesPerSecond :: Int64
  , progressMovingAverageSpeedBytesPerSecond :: Int64
  , progressEtaSeconds :: Maybe Int64
  , progressPercent :: Maybe Double
  , progressLabel :: String
  , progressHost :: Maybe Text
  , progressLane :: Maybe Text
  , progressActiveWorkers :: Int
  , progressRetryCount :: Int
  , progressSource :: Maybe Text
  , progressHostTelemetry :: [DownloadHostTelemetry]
  , progressThrottleReason :: Maybe Text
  , progressMultipartTelemetry :: Maybe DownloadMultipartTelemetry
  } deriving (Eq, Show)

data DownloadException
  = DownloadHttpStatus Int (Maybe Int) String
  | DownloadCancelled
  deriving (Eq, Show, Typeable)

instance Exception DownloadException

data FileDigest = FileDigest
  { fileDigestSize :: Integer
  , fileDigestSha1 :: Text
  } deriving (Eq, Show)

data HashState = HashState
  { hashStateSize :: Integer
  , hashStateContext :: SHA1.Ctx
  }

defaultDownloadOptions :: DownloadOptions
defaultDownloadOptions =
  DownloadOptions
    { downloadOptionConcurrency = 32
    , downloadOptionRetryCount = 3
    }

maxProgressHostTelemetry :: Int
maxProgressHostTelemetry = 12

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
          throttleReason <- recordHostGateOutcome hostGates job outcome elapsedMs
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

fileDescriptorWorkerLimit :: IO Int
fileDescriptorWorkerLimit = do
  result <- try (readCreateProcessWithExitCode (proc "/bin/zsh" ["-lc", "ulimit -n"]) "") :: IO (Either SomeException (ExitCode, String, String))
  pure $ case result of
    Right (ExitSuccess, stdoutText, _) ->
      safeLimit (parseInt stdoutText)
    _ -> 32
  where
    safeLimit Nothing = 32
    safeLimit (Just value) =
      max 1 (min 64 ((value - 64) `div` 4))

parseInt :: String -> Maybe Int
parseInt value =
  case reads value of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing

buildHostGates :: Int -> [SchedulerJob] -> IO (Map Text HostGate)
buildHostGates requested jobs =
  Map.traverseWithKey (newHostGate requestedLimit) gatePlans
  where
    requestedLimit = clampDownloadConcurrency requested
    gatePlans =
      Map.fromListWith
        preferGatePlan
        [ let lane = laneForJob job
           in (schedulerJobHost job, (min requestedLimit (hostConcurrencyLimit lane), lane))
        | job <- jobs
        ]
    preferGatePlan lhs@(lhsLimit, _) rhs@(rhsLimit, _)
      | lhsLimit >= rhsLimit = lhs
      | otherwise = rhs

newHostGate :: Int -> Text -> (Int, DownloadLane) -> IO HostGate
newHostGate requested host (initial, lane) = do
  state <-
    newMVar
      HostGateState
        { gateLane = lane
        , gateActive = 0
        , gateLimit = initialLimit
        , gateMaxLimit = max initialLimit (min requested (hostGateCeiling lane))
        , gateCompletedBytes = 0
        , gateCompletedJobs = 0
        , gateRetryCount = 0
        , gateLastBytesPerSecond = 0
        }
  pure HostGate
    { hostGateHost = host
    , hostGateState = state
    }
  where
    initialLimit = max 1 initial

withHostGate :: Map Text HostGate -> DownloadJob -> IO value -> IO value
withHostGate hostGates job action =
  case Map.lookup (schedulerJobHost (schedulerJob job)) hostGates of
    Nothing -> action
    Just gate -> bracket_ (acquireHostGate gate) (releaseHostGate gate) action

snapshotHostTelemetry :: Map Text HostGate -> IO [DownloadHostTelemetry]
snapshotHostTelemetry hostGates = do
  telemetry <- traverse hostTelemetryFor (Map.elems hostGates)
  pure (take maxProgressHostTelemetry (sortOn hostTelemetryRank telemetry))
  where
    hostTelemetryRank host =
      ( Down (hostTelemetryActiveConnections host)
      , Down (hostTelemetryBytesPerSecond host)
      , Down (hostTelemetryCompletedBytes host)
      , hostTelemetryHost host
      )
    hostTelemetryFor gate = do
      state <- readMVar (hostGateState gate)
      pure DownloadHostTelemetry
        { hostTelemetryHost = hostGateHost gate
        , hostTelemetryLane = renderLane (gateLane state)
        , hostTelemetryActiveConnections = gateActive state
        , hostTelemetryGate = gateLimit state
        , hostTelemetryMaxGate = gateMaxLimit state
        , hostTelemetryBytesPerSecond = gateLastBytesPerSecond state
        , hostTelemetryCompletedBytes = gateCompletedBytes state
        , hostTelemetryCompletedJobs = gateCompletedJobs state
        , hostTelemetryRetryCount = gateRetryCount state
        }

acquireHostGate :: HostGate -> IO ()
acquireHostGate gate = do
  acquired <-
    modifyMVar (hostGateState gate) $ \state ->
      if gateActive state < gateLimit state
        then
          let next = state { gateActive = gateActive state + 1 }
           in pure (next, True)
        else pure (state, False)
  unless acquired $ do
    threadDelay 10000
    acquireHostGate gate

releaseHostGate :: HostGate -> IO ()
releaseHostGate gate =
  modifyMVar (hostGateState gate) $ \state ->
    pure (state { gateActive = max 0 (gateActive state - 1) }, ())

recordHostGateOutcome :: Map Text HostGate -> DownloadJob -> DownloadOutcome -> Int -> IO (Maybe Text)
recordHostGateOutcome hostGates job outcome elapsedMs =
  case Map.lookup host hostGates of
    Nothing -> pure Nothing
    Just gate -> do
      (line, reasonText) <- modifyMVar (hostGateState gate) $ \state ->
        let sampleBps = rateBytesPerSecond (outcomeBytes outcome) elapsedMs
            previousBps = gateLastBytesPerSecond state
            smoothedBps =
              if sampleBps <= 0
                then previousBps
                else if previousBps <= 0
                  then sampleBps
                  else (previousBps * 3 + sampleBps) `div` 4
            floorLimit = hostGateFloor (gateLane state)
            currentLimit = gateLimit state
            (nextLimit, reason) =
              nextHostGateLimit floorLimit (gateMaxLimit state) currentLimit previousBps sampleBps (outcomeRetries outcome)
            next =
              state
                { gateLimit = nextLimit
                , gateCompletedBytes = gateCompletedBytes state + outcomeBytes outcome
                , gateCompletedJobs = gateCompletedJobs state + 1
                , gateRetryCount = gateRetryCount state + outcomeRetries outcome
                , gateLastBytesPerSecond = smoothedBps
                }
            logLine =
              "download_scheduler_host"
                <> " host="
                <> Text.unpack (hostGateHost gate)
                <> " lane="
                <> Text.unpack (renderLane (gateLane state))
                <> " gate="
                <> show currentLimit
                <> "->"
                <> show nextLimit
                <> " active="
                <> show (gateActive state)
                <> " bps="
                <> show sampleBps
                <> " retries="
                <> show (outcomeRetries outcome)
                <> " reason="
                <> reason
         in pure (next, (logLine, Text.pack reason))
      putStrLn line
      pure (Just reasonText)
  where
    host = fromMaybe (schedulerJobHost (schedulerJob job)) (outcomeHost outcome)

nextHostGateLimit :: Int -> Int -> Int -> Int64 -> Int64 -> Int -> (Int, String)
nextHostGateLimit floorLimit maxLimit current previousBps sampleBps retries
  | retries > 0 =
      (max floorLimit (current `div` 2), "retry")
  | sampleBps <= 0 =
      (current, "no_transfer")
  | previousBps <= 0 =
      (min maxLimit (current + 1), "warmup")
  | sampleBps * 100 >= previousBps * 105 =
      (min maxLimit (current + 1), "throughput_up")
  | sampleBps * 100 < previousBps * 70 =
      (max floorLimit (current - 1), "throughput_down")
  | otherwise =
      (current, "stable")

hostGateFloor :: DownloadLane -> Int
hostGateFloor SmallObjectLane = 1
hostGateFloor LargeObjectLane = 1

hostGateCeiling :: DownloadLane -> Int
hostGateCeiling SmallObjectLane = 48
hostGateCeiling LargeObjectLane = 16

rateBytesPerSecond :: Int64 -> Int -> Int64
rateBytesPerSecond bytes elapsedMs =
  round (fromIntegral bytes * 1000 / max 1 (fromIntegral elapsedMs :: Double))

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
              loop
                HashState
                  { hashStateSize = hashStateSize state + fromIntegral (BS.length chunk)
                  , hashStateContext = SHA1.update (hashStateContext state) chunk
                }
                reportedPending
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

sha1HexFile :: FilePath -> IO Text
sha1HexFile path =
  fileDigestSha1 . finalizeHashState <$> hashFileState path

hashFileState :: FilePath -> IO HashState
hashFileState path =
  withBinaryFile path ReadMode $ \handle ->
    hashLoop handle emptyHashState

hashLoop :: Handle -> HashState -> IO HashState
hashLoop handle context = do
  chunk <- BS.hGetSome handle 262144
  if BS.null chunk
    then pure context
    else
      hashLoop
        handle
        HashState
          { hashStateSize = hashStateSize context + fromIntegral (BS.length chunk)
          , hashStateContext = SHA1.update (hashStateContext context) chunk
          }

emptyHashState :: HashState
emptyHashState =
  HashState
    { hashStateSize = 0
    , hashStateContext = SHA1.init
    }

finalizeHashState :: HashState -> FileDigest
finalizeHashState state =
  FileDigest
    { fileDigestSize = hashStateSize state
    , fileDigestSha1 = Text.pack (concatMap byteToHex (BS.unpack (SHA1.finalize (hashStateContext state))))
    }

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

byteToHex :: Word8 -> String
byteToHex byte =
  case showHex byte "" of
    [single] -> ['0', single]
    pair -> pair

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
