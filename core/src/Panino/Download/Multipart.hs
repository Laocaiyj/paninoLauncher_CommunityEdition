{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Download.Multipart
  ( MultipartException(..)
  , MultipartJob(..)
  , MultipartProgress(..)
  , MultipartResult(..)
  , multipartDownload
  , multipartDownloadWithProgress
  , multipartMinBytes
  ) where

import Control.Concurrent.Async
  ( AsyncCancelled
  , mapConcurrently
  )
import Control.Concurrent.Chan
  ( newChan
  , readChan
  , writeChan
  )
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar_
  , newMVar
  , readMVar
  )
import Control.Exception
  ( Exception
  , IOException
  , SomeException
  , SomeAsyncException
  , catch
  , fromException
  , throwIO
  )
import Control.Monad
  ( unless
  , when
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Data.Int (Int64)
import Data.Typeable (Typeable)
import Network.HTTP.Client
  ( Manager
  , method
  , parseRequest
  , requestHeaders
  , responseBody
  , responseHeaders
  , responseStatus
  , responseTimeout
  , responseTimeoutMicro
  , withResponse
  , httpNoBody
  )
import Network.HTTP.Types
  ( HeaderName
  , statusCode
  )
import Panino.Core.Types
  ( Url
  , urlString
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , removeFile
  )
import System.Environment (lookupEnv)
import System.FilePath (takeDirectory)
import System.IO
  ( Handle
  , IOMode(..)
  , SeekMode(..)
  , hFlush
  , hSeek
  , hSetFileSize
  , withBinaryFile
  )

data MultipartJob = MultipartJob
  { multipartJobLabel :: String
  , multipartJobUrl :: Url
  , multipartJobTargetPartPath :: FilePath
  , multipartJobSize :: Int64
  } deriving (Eq, Show)

data MultipartResult = MultipartResult
  { multipartResultBytes :: Int64
  , multipartResultResumed :: Bool
  } deriving (Eq, Show)

data MultipartProgress = MultipartProgress
  { multipartProgressLabel :: String
  , multipartProgressCompletedSegments :: Int
  , multipartProgressTotalSegments :: Int
  , multipartProgressActiveSegments :: Int
  , multipartProgressSegmentBytes :: Int64
  , multipartProgressTotalBytes :: Int64
  , multipartProgressCurrentSegment :: Maybe Int
  } deriving (Eq, Show)

data MultipartException
  = MultipartUnsupported String
  | MultipartHttpStatus Int String
  deriving (Eq, Show, Typeable)

instance Exception MultipartException

multipartDownload :: Manager -> Int -> IO () -> MultipartJob -> (Int64 -> IO ()) -> IO MultipartResult
multipartDownload manager concurrency checkCancelled job onChunk =
  multipartDownloadWithProgress manager concurrency checkCancelled job onChunk (\_ -> pure ())

multipartDownloadWithProgress :: Manager -> Int -> IO () -> MultipartJob -> (Int64 -> IO ()) -> (MultipartProgress -> IO ()) -> IO MultipartResult
multipartDownloadWithProgress manager concurrency checkCancelled job onChunk onProgress = do
  checkCancelled
  minBytes <- multipartMinBytes
  segmentBytes <- multipartSegmentBytes
  configuredConcurrency <- multipartWorkerCount concurrency
  if multipartJobSize job < minBytes
    then throwIO (MultipartUnsupported "file below multipart threshold")
    else do
      checkCancelled
      support <- rangeSupport manager job
      checkCancelled
      putStrLn ("multipart_range_probe " <> multipartJobLabel job <> " reason=" <> rangeSupportReason support)
      unless (rangeSupportOk support) $
        throwIO (MultipartUnsupported (rangeSupportReason support))
      createDirectoryIfMissing True (takeDirectory (multipartJobTargetPartPath job))
      let segments = makeSegments (multipartJobSize job) segmentBytes
          workerCount = max 1 (min configuredConcurrency (length segments))
      preparePartFile job
      completed <- loadCompletedSegments job segments
      mapM_ (onChunk . segmentLength) completed
      completedVar <- newMVar (map segmentIndex completed)
      emitMultipartProgress job segments workerCount completedVar segmentBytes Nothing onProgress
      queue <- newChan
      mapM_ (writeChan queue . Just) [segment | segment <- segments, segmentIndex segment `notElem` map segmentIndex completed]
      mapM_ (\_ -> writeChan queue Nothing) [1 .. workerCount]
      resumedFlags <-
        withBinaryFile (multipartJobTargetPartPath job) ReadWriteMode $ \partHandle -> do
          partHandleVar <- newMVar partHandle
          concat <$> mapConcurrently (const (worker segments workerCount segmentBytes partHandleVar completedVar queue)) [1 .. workerCount]
      checkCancelled
      completedIndexes <- readMVar completedVar
      unless (all (`elem` completedIndexes) (map segmentIndex segments)) $
        throwIO (MultipartUnsupported "segment map incomplete")
      removeIfExists (sidecarPath job)
      pure MultipartResult
        { multipartResultBytes = multipartJobSize job
        , multipartResultResumed = not (null completed) || or resumedFlags
        }
  where
    worker segments workerCount segmentBytes partHandleVar completedVar queue = do
      checkCancelled
      next <- readChan queue
      checkCancelled
      case next of
        Nothing -> pure []
        Just segment -> do
          resumed <- downloadSegment manager checkCancelled partHandleVar completedVar job onChunk onProgress segments workerCount segmentBytes segment
          (resumed :) <$> worker segments workerCount segmentBytes partHandleVar completedVar queue

multipartMinBytes :: IO Int64
multipartMinBytes = do
  value <- lookupEnv "PANINO_MULTIPART_MIN_BYTES"
  pure (maybe defaultMultipartMinBytes readOrDefault value)
  where
    readOrDefault raw =
      case reads raw of
        (parsed, _) : _ -> max 1 parsed
        [] -> defaultMultipartMinBytes

defaultMultipartMinBytes :: Int64
defaultMultipartMinBytes = 32 * 1024 * 1024

multipartSegmentBytes :: IO Int64
multipartSegmentBytes = do
  value <- lookupEnv "PANINO_MULTIPART_SEGMENT_BYTES"
  pure (maybe defaultMultipartSegmentBytes readOrDefault value)
  where
    readOrDefault raw =
      case reads raw of
        (parsed, _) : _ -> max (256 * 1024) parsed
        [] -> defaultMultipartSegmentBytes

defaultMultipartSegmentBytes :: Int64
defaultMultipartSegmentBytes = 8 * 1024 * 1024

multipartWorkerCount :: Int -> IO Int
multipartWorkerCount requested = do
  value <- lookupEnv "PANINO_MULTIPART_WORKERS"
  pure (maybe defaultWorkerCount readOrDefault value)
  where
    defaultWorkerCount = max 1 (min 16 requested)
    readOrDefault raw =
      case reads raw of
        (parsed, _) : _ -> max 1 (min 16 parsed)
        [] -> defaultWorkerCount

data MultipartSegment = MultipartSegment
  { segmentIndex :: Int
  , segmentStart :: Int64
  , segmentEnd :: Int64
  } deriving (Eq, Show)

segmentLength :: MultipartSegment -> Int64
segmentLength segment =
  segmentEnd segment - segmentStart segment + 1

makeSegments :: Int64 -> Int64 -> [MultipartSegment]
makeSegments total segmentSize =
  go 0 0
  where
    go index start
      | start >= total = []
      | otherwise =
          let end = min (total - 1) (start + segmentSize - 1)
           in MultipartSegment index start end : go (index + 1) (end + 1)

data RangeSupport = RangeSupport
  { rangeSupportOk :: Bool
  , rangeSupportReason :: String
  } deriving (Eq, Show)

rangeSupport :: Manager -> MultipartJob -> IO RangeSupport
rangeSupport manager job = do
  result <-
    ( do
        request <- parseRequest (urlString (multipartJobUrl job))
        let headRequest =
              request
                { method = "HEAD"
                , responseTimeout = responseTimeoutMicro 15000000
                }
        response <- httpNoBody headRequest manager
        let status = statusCode (responseStatus response)
            headers = responseHeaders response
            ranges = maybe "" BS8.unpack (lookup hAcceptRanges headers)
            lengthOk =
              case lookup hContentLength headers >>= readMaybeBytes of
                Nothing -> True
                Just value -> value == multipartJobSize job
        if status < 200 || status >= 300
          then pure (RangeSupport False "status_4xx_5xx")
          else if not lengthOk
            then pure (RangeSupport False "content_length_mismatch")
            else if ranges == "bytes"
              then pure (RangeSupport True "head_accept_ranges")
              else probeRangeGet manager job
    )
      `catch` \(err :: SomeException) ->
        if isCancellationException err
          then throwIO err
          else probeRangeGet manager job
  pure result

probeRangeGet :: Manager -> MultipartJob -> IO RangeSupport
probeRangeGet manager job =
  ( do
      request <- parseRequest (urlString (multipartJobUrl job))
      let rangedRequest =
            request
              { requestHeaders = ("Range", "bytes=0-0") : requestHeaders request
              , responseTimeout = responseTimeoutMicro 15000000
              }
      response <- httpNoBody rangedRequest manager
      let status = statusCode (responseStatus response)
      pure $
        case status of
          206 -> RangeSupport True "range_get_206"
          200 -> RangeSupport False "range_ignored_200"
          _ | status >= 400 -> RangeSupport False "status_4xx_5xx"
          _ -> RangeSupport False ("unexpected_status_" <> show status)
  )
    `catch` \(err :: SomeException) ->
      if isCancellationException err
        then throwIO err
        else pure (RangeSupport False ("timeout_or_error:" <> show err))

preparePartFile :: MultipartJob -> IO ()
preparePartFile job = do
  exists <- doesFileExist (multipartJobTargetPartPath job)
  unless exists (BS.writeFile (multipartJobTargetPartPath job) BS.empty)
  withBinaryFile (multipartJobTargetPartPath job) ReadWriteMode $ \handle ->
    hSetFileSize handle (fromIntegral (multipartJobSize job))

loadCompletedSegments :: MultipartJob -> [MultipartSegment] -> IO [MultipartSegment]
loadCompletedSegments job segments = do
  exists <- doesFileExist (sidecarPath job)
  if not exists
    then pure []
    else do
      raw <- BS8.readFile (sidecarPath job)
      let completedIndexes = mapMaybeReadInt (lines (BS8.unpack raw))
      pure [segment | segment <- segments, segmentIndex segment `elem` completedIndexes]

markSegmentComplete :: MVar [Int] -> MultipartJob -> MultipartSegment -> IO ()
markSegmentComplete completedVar job segment =
  modifyMVar_ completedVar $ \completed ->
    if segmentIndex segment `elem` completed
      then pure completed
      else do
        BS8.appendFile (sidecarPath job) (BS8.pack (show (segmentIndex segment) <> "\n"))
        pure (segmentIndex segment : completed)

mapMaybeReadInt :: [String] -> [Int]
mapMaybeReadInt =
  foldr collect []
  where
    collect value values =
      case reads value of
        (parsed, _) : _ -> parsed : values
        [] -> values

downloadSegment :: Manager -> IO () -> MVar Handle -> MVar [Int] -> MultipartJob -> (Int64 -> IO ()) -> (MultipartProgress -> IO ()) -> [MultipartSegment] -> Int -> Int64 -> MultipartSegment -> IO Bool
downloadSegment manager checkCancelled partHandleVar completedVar job onChunk onProgress segments workerCount segmentBytes segment = do
  checkCancelled
  request <- parseRequest (urlString (multipartJobUrl job))
  let rangedRequest =
        request
          { requestHeaders =
              ("Range", BS8.pack ("bytes=" <> show (segmentStart segment) <> "-" <> show (segmentEnd segment)))
                : requestHeaders request
          , responseTimeout = responseTimeoutMicro 300000000
          }
  withResponse rangedRequest manager $ \response -> do
    checkCancelled
    let status = statusCode (responseStatus response)
    if status == 206
      then streamSegmentAtOffset checkCancelled partHandleVar (segmentStart segment) (segmentLength segment) onChunk (responseBody response)
      else if status == 200
        then throwIO (MultipartUnsupported "server ignored range request")
        else throwIO (MultipartHttpStatus status (multipartJobLabel job))
  checkCancelled
  markSegmentComplete completedVar job segment
  emitMultipartProgress job segments workerCount completedVar segmentBytes (Just (segmentIndex segment)) onProgress
  pure False

emitMultipartProgress :: MultipartJob -> [MultipartSegment] -> Int -> MVar [Int] -> Int64 -> Maybe Int -> (MultipartProgress -> IO ()) -> IO ()
emitMultipartProgress job segments workerCount completedVar segmentBytes currentSegment onProgress = do
  completed <- readMVar completedVar
  onProgress
    MultipartProgress
      { multipartProgressLabel = multipartJobLabel job
      , multipartProgressCompletedSegments = length completed
      , multipartProgressTotalSegments = length segments
      , multipartProgressActiveSegments = min workerCount (max 0 (length segments - length completed))
      , multipartProgressSegmentBytes = segmentBytes
      , multipartProgressTotalBytes = multipartJobSize job
      , multipartProgressCurrentSegment = currentSegment
      }

streamSegmentAtOffset :: IO () -> MVar Handle -> Int64 -> Int64 -> (Int64 -> IO ()) -> IO BS.ByteString -> IO ()
streamSegmentAtOffset checkCancelled partHandleVar offset expectedLength onChunk reader =
  let reportThreshold = 262144 :: Int64
      loop writtenBytes pendingBytes = do
        checkCancelled
        chunk <- reader
        checkCancelled
        if BS.null chunk
          then do
            unless (writtenBytes == expectedLength) $
              throwIO (MultipartUnsupported "segment length mismatch")
            when (pendingBytes > 0) (onChunk pendingBytes >> checkCancelled)
            modifyMVar_ partHandleVar (\handle -> hFlush handle >> pure handle)
          else do
            let chunkLength = fromIntegral (BS.length chunk)
                nextWritten = writtenBytes + chunkLength
                nextPending = pendingBytes + chunkLength
            when (nextWritten > expectedLength) $
              throwIO (MultipartUnsupported "segment overrun")
            modifyMVar_ partHandleVar $ \handle -> do
              hSeek handle AbsoluteSeek (fromIntegral (offset + writtenBytes))
              BS.hPut handle chunk
              pure handle
            reportedPending <-
              if nextPending >= reportThreshold
                then onChunk nextPending >> checkCancelled >> pure 0
                else pure nextPending
            loop nextWritten reportedPending
   in loop 0 0

sidecarPath :: MultipartJob -> FilePath
sidecarPath job =
  multipartJobTargetPartPath job <> ".map"

hAcceptRanges :: HeaderName
hAcceptRanges = "Accept-Ranges"

hContentLength :: HeaderName
hContentLength = "Content-Length"

readMaybeBytes :: BS.ByteString -> Maybe Int64
readMaybeBytes value =
  case reads (BS8.unpack value) of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing

removeIfExists :: FilePath -> IO ()
removeIfExists path =
  removeFile path `catch` \(_ :: IOException) -> pure ()

isCancellationException :: SomeException -> Bool
isCancellationException err =
  isAsyncCancelled || isSomeAsyncException
  where
    isAsyncCancelled =
      case fromException err of
        Just (_ :: AsyncCancelled) -> True
        Nothing -> False
    isSomeAsyncException =
      case fromException err of
        Just (_ :: SomeAsyncException) -> True
        Nothing -> False
