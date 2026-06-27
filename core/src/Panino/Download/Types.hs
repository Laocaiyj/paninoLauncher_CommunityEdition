{-# LANGUAGE DeriveDataTypeable #-}

module Panino.Download.Types
  ( DownloadException(..)
  , DownloadHostTelemetry(..)
  , DownloadJob(..)
  , DownloadMultipartTelemetry(..)
  , DownloadOptions(..)
  , DownloadProgress(..)
  , DownloadResult(..)
  , DownloadSummary(..)
  ) where

import Control.Exception (Exception)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Typeable (Typeable)
import Panino.Core.Types
  ( Sha1
  , Url
  )

data DownloadJob = DownloadJob
  { jobLabel :: String
  , jobUrl :: Url
  , jobTargetPath :: FilePath
  , jobSha1 :: Maybe Sha1
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
