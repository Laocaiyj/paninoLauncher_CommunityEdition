{-# LANGUAGE OverloadedStrings #-}

module Panino.Download.Scheduler
  ( DownloadLane(..)
  , SchedulerJob(..)
  , hostConcurrencyLimit
  , laneForJob
  , plannedWorkerCount
  , renderLane
  , schedulerJobHost
  ) where

import Control.Concurrent (getNumCapabilities)
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Core.Types
  ( Url
  , urlString
  )
import Panino.Net.Probe (sourceHostKey)

data DownloadLane
  = SmallObjectLane
  | LargeObjectLane
  deriving (Eq, Show)

data SchedulerJob = SchedulerJob
  { schedulerJobUrl :: Url
  , schedulerJobSize :: Maybe Int64
  } deriving (Eq, Show)

plannedWorkerCount :: Int -> [SchedulerJob] -> IO Int
plannedWorkerCount requested jobs = do
  capabilities <- getNumCapabilities
  let upperBound = clampRequested requested
      smallCount = length (filter ((== SmallObjectLane) . laneForJob) jobs)
      largeCount = length jobs - smallCount
      cpuFloor = max 4 (capabilities * 4)
      desired =
        max 1 $
          min (length jobs) $
            max
              (min upperBound cpuFloor)
              (min upperBound (smallCount + largeCount * 2))
  pure (min upperBound desired)

laneForJob :: SchedulerJob -> DownloadLane
laneForJob job =
  if fromMaybe 0 (schedulerJobSize job) >= largeObjectThreshold
    then LargeObjectLane
    else SmallObjectLane

hostConcurrencyLimit :: DownloadLane -> Int
hostConcurrencyLimit SmallObjectLane = 8
hostConcurrencyLimit LargeObjectLane = 3

renderLane :: DownloadLane -> Text
renderLane SmallObjectLane = "small-object"
renderLane LargeObjectLane = "large-object"

schedulerJobHost :: SchedulerJob -> Text
schedulerJobHost =
  Text.pack . sourceHostKey . urlString . schedulerJobUrl

largeObjectThreshold :: Int64
largeObjectThreshold = 32 * 1024 * 1024

clampRequested :: Int -> Int
clampRequested value =
  max 1 (min 64 value)
