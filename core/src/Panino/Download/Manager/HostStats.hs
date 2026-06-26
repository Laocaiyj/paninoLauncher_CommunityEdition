module Panino.Download.Manager.HostStats
  ( HostDownloadStats
  , recordHostOutcome
  , reportHostStats
  ) where

import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , readMVar
  )
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Data.Time.Clock
  ( UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Panino.Download.Transfer
  ( DownloadOutcome(..)
  )
import Panino.Download.Types
  ( DownloadResult(..)
  )
import Panino.Perf.Metrics
  ( recordDownloadHostSummary
  )

data HostDownloadStats = HostDownloadStats
  { hostStatsBytes :: Int64
  , hostStatsDownloaded :: Int
  , hostStatsRetries :: Int
  , hostStatsResumed :: Int
  } deriving (Eq, Show)

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
