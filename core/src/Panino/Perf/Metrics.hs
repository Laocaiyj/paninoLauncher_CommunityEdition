{-# LANGUAGE OverloadedStrings #-}

module Panino.Perf.Metrics
  ( CacheStatus(..)
  , cacheStatusHeader
  , cacheStatusText
  , recordApiMetric
  , recordCoreResourceSnapshot
  , recordDownloadHostSummary
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Data.Time.Clock (NominalDiffTime)
import Network.HTTP.Types (Header)
import System.Exit (ExitCode(..))
import System.Posix.Process (getProcessID)
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )

data CacheStatus
  = CacheHit
  | StaleHit
  | NetworkFetch
  | CacheError
  | NotCacheable
  deriving (Eq, Show)

cacheStatusText :: CacheStatus -> Text
cacheStatusText CacheHit = "hit"
cacheStatusText StaleHit = "stale"
cacheStatusText NetworkFetch = "network"
cacheStatusText CacheError = "error"
cacheStatusText NotCacheable = "not-cacheable"

cacheStatusHeader :: CacheStatus -> Header
cacheStatusHeader status =
  ("X-Panino-Cache", Text.encodeUtf8 (cacheStatusText status))

recordApiMetric :: Text -> Text -> CacheStatus -> NominalDiffTime -> Int64 -> IO ()
recordApiMetric route key status duration bytes =
  putStrLn
    ( "perf.api"
        <> " route="
        <> Text.unpack route
        <> " cache="
        <> Text.unpack (cacheStatusText status)
        <> " duration_ms="
        <> show (durationMillis duration)
        <> " bytes="
        <> show bytes
        <> " key="
        <> Text.unpack (redactLongKey key)
    )

recordDownloadHostSummary :: Text -> Int64 -> Int64 -> Int -> Int -> Int -> IO ()
recordDownloadHostSummary host bytes bytesPerSecond downloaded retries resumed =
  putStrLn
    ( "perf.download_host"
        <> " host="
        <> Text.unpack host
        <> " bytes="
        <> show bytes
        <> " bps="
        <> show bytesPerSecond
        <> " downloaded="
        <> show downloaded
        <> " retries="
        <> show retries
        <> " resumed="
        <> show resumed
    )

recordCoreResourceSnapshot :: Int -> Int -> Int -> Int -> IO ()
recordCoreResourceSnapshot activeWorkers openFilesEstimate queuedJobs eventRateHz = do
  rssBytes <- currentRssBytes
  putStrLn
    ( "perf.core_resources"
        <> " rss_bytes="
        <> show rssBytes
        <> " active_workers="
        <> show activeWorkers
        <> " open_files_estimate="
        <> show openFilesEstimate
        <> " queued_jobs="
        <> show queuedJobs
        <> " event_rate_hz="
        <> show eventRateHz
    )

currentRssBytes :: IO Int64
currentRssBytes = do
  pid <- getProcessID
  result <- try (readCreateProcessWithExitCode (proc "ps" ["-o", "rss=", "-p", show pid]) "") :: IO (Either SomeException (ExitCode, String, String))
  pure $ case result of
    Right (ExitSuccess, stdoutText, _) ->
      maybe 0 (* 1024) (parseInt64 stdoutText)
    _ -> 0

parseInt64 :: String -> Maybe Int64
parseInt64 value =
  case reads value of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing

durationMillis :: NominalDiffTime -> Int
durationMillis duration =
  round (realToFrac duration * 1000 :: Double)

redactLongKey :: Text -> Text
redactLongKey key
  | Text.length key <= 180 = key
  | otherwise = Text.take 180 key <> "..."
