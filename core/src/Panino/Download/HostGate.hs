{-# LANGUAGE OverloadedStrings #-}

module Panino.Download.HostGate
  ( HostGate
  , buildHostGates
  , recordHostGateOutcome
  , snapshotHostTelemetry
  , withHostGate
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , newMVar
  , readMVar
  )
import Control.Exception (bracket_)
import Control.Monad
  ( unless
  )
import Data.Int (Int64)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Download.Scheduler
  ( DownloadLane(..)
  , SchedulerJob(..)
  , hostConcurrencyLimit
  , laneForJob
  , renderLane
  , schedulerJobHost
  )
import Panino.Download.Types
  ( DownloadHostTelemetry(..)
  , DownloadJob(..)
  )

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

maxProgressHostTelemetry :: Int
maxProgressHostTelemetry = 12

buildHostGates :: Int -> [SchedulerJob] -> IO (Map Text HostGate)
buildHostGates requested jobs =
  Map.traverseWithKey (newHostGate requestedLimit) gatePlans
  where
    requestedLimit = clampHostGateConcurrency requested
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

recordHostGateOutcome :: Map Text HostGate -> DownloadJob -> Maybe Text -> Int64 -> Int -> Int -> IO (Maybe Text)
recordHostGateOutcome hostGates job selectedHost transferredBytes retryCount elapsedMs =
  case Map.lookup host hostGates of
    Nothing -> pure Nothing
    Just gate -> do
      (line, reasonText) <- modifyMVar (hostGateState gate) $ \state ->
        let sampleBps = rateBytesPerSecond transferredBytes elapsedMs
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
              nextHostGateLimit floorLimit (gateMaxLimit state) currentLimit previousBps sampleBps retryCount
            next =
              state
                { gateLimit = nextLimit
                , gateCompletedBytes = gateCompletedBytes state + transferredBytes
                , gateCompletedJobs = gateCompletedJobs state + 1
                , gateRetryCount = gateRetryCount state + retryCount
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
                <> show retryCount
                <> " reason="
                <> reason
         in pure (next, (logLine, Text.pack reason))
      putStrLn line
      pure (Just reasonText)
  where
    host = fromMaybe (schedulerJobHost (schedulerJob job)) selectedHost

schedulerJob :: DownloadJob -> SchedulerJob
schedulerJob job =
  SchedulerJob
    { schedulerJobUrl = jobUrl job
    , schedulerJobSize = jobSize job
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

clampHostGateConcurrency :: Int -> Int
clampHostGateConcurrency value =
  min 64 (max 1 value)
