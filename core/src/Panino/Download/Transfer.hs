{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections #-}

module Panino.Download.Transfer
  ( DownloadOutcome(..)
  , downloadWithRetry
  , throwIfCancelled
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.Async
  ( AsyncCancelled
  )
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  )
import Control.Exception
  ( IOException
  , SomeAsyncException
  , SomeException
  , catch
  , fromException
  , throwIO
  , try
  )
import Control.Monad
  ( when
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Data.Int (Int64)
import Data.List (isInfixOf)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock
  ( diffUTCTime
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
import Panino.Download.Multipart
  ( MultipartException(..)
  , MultipartJob(..)
  , MultipartProgress(..)
  , multipartDownloadWithProgress
  , multipartMinBytes
  , multipartResultResumed
  )
import Panino.Download.Types
  ( DownloadException(..)
  , DownloadJob(..)
  , DownloadMultipartTelemetry(..)
  , DownloadResult(..)
  )
import Panino.Core.Types
  ( sha1Text
  , urlFromString
  , urlString
  )
import Panino.Download.VerificationIndex
  ( lookupVerifiedFile
  , recordVerifiedFile
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

throwIfCancelled :: IO Bool -> IO ()
throwIfCancelled isCancelled = do
  cancelled <- isCancelled
  when cancelled (throwIO DownloadCancelled)

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
      resolvedUrls <- resolveSourceUrls (urlString (jobUrl job))
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
                    , multipartJobUrl = urlFromString resolvedUrl
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
          Just expected -> fileDigestSha1 digest == sha1Text expected
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
        Just expected -> (== sha1Text expected) <$> sha1HexFile path
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
