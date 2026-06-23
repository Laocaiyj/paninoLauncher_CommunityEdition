{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Tasks.Progress
  ( monotonicTaskProgress
  , taskProgressPayload
  , terminalProgress
  ) where

import Data.Aeson
  ( Value
  , object
  , (.=)
  )
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Panino.Api.Types
  ( TaskProgress(..)
  , TaskSnapshot(..)
  , TaskState(..)
  )

taskProgressPayload :: TaskProgress -> Value
taskProgressPayload progress =
  object
    [ "taskId" .= taskProgressTaskId progress
    , "phaseId" .= taskProgressPhaseId progress
    , "phaseTitle" .= taskProgressPhaseTitle progress
    , "phaseIndex" .= taskProgressPhaseIndex progress
    , "phaseCount" .= taskProgressPhaseCount progress
    , "phasePercent" .= taskProgressPhasePercent progress
    , "overallPercent" .= taskProgressOverallPercent progress
    , "percent" .= taskProgressOverallPercent progress
    , "completedJobs" .= taskProgressCompletedJobs progress
    , "totalJobs" .= taskProgressTotalJobs progress
    , "completedBytes" .= taskProgressCompletedBytes progress
    , "totalBytes" .= taskProgressTotalBytes progress
    , "speedBytesPerSecond" .= taskProgressSpeedBytesPerSecond progress
    , "movingAverageSpeedBytesPerSecond" .= taskProgressMovingAverageSpeedBytesPerSecond progress
    , "etaSeconds" .= taskProgressEtaSeconds progress
    , "currentLabel" .= taskProgressCurrentLabel progress
    , "label" .= taskProgressCurrentLabel progress
    , "activeWorkers" .= taskProgressActiveWorkers progress
    , "retryCount" .= taskProgressRetryCount progress
    , "sourceHost" .= taskProgressSourceHost progress
    , "host" .= taskProgressSourceHost progress
    , "source" .= taskProgressSourceHost progress
    , "hosts" .= taskProgressHosts progress
    , "throttleReason" .= taskProgressThrottleReason progress
    , "multipart" .= taskProgressMultipart progress
    ]

monotonicTaskProgress :: Maybe TaskProgress -> TaskProgress -> TaskProgress
monotonicTaskProgress previous progress =
  progress
    { taskProgressOverallPercent =
        maxMaybePercent (taskProgressOverallPercent =<< previous) (taskProgressOverallPercent progress)
    }

terminalProgress :: TaskSnapshot -> TaskState -> Maybe Text -> Maybe TaskProgress
terminalProgress current taskState message =
  case taskState of
    TaskSucceeded ->
      Just $
        case taskSnapshotProgress current of
          Just progress ->
            progress
              { taskProgressPhasePercent = Just 100
              , taskProgressOverallPercent = Just 100
              , taskProgressCurrentLabel = fromMaybe "completed" message
              , taskProgressActiveWorkers = 0
              }
          Nothing ->
            TaskProgress
              { taskProgressTaskId = taskSnapshotId current
              , taskProgressPhaseId = "complete"
              , taskProgressPhaseTitle = "Complete"
              , taskProgressPhaseIndex = 1
              , taskProgressPhaseCount = 1
              , taskProgressPhasePercent = Just 100
              , taskProgressOverallPercent = Just 100
              , taskProgressCompletedJobs = 0
              , taskProgressTotalJobs = 0
              , taskProgressCompletedBytes = 0
              , taskProgressTotalBytes = 0
              , taskProgressSpeedBytesPerSecond = 0
              , taskProgressMovingAverageSpeedBytesPerSecond = 0
              , taskProgressEtaSeconds = Nothing
              , taskProgressCurrentLabel = fromMaybe "completed" message
              , taskProgressActiveWorkers = 0
              , taskProgressRetryCount = 0
              , taskProgressSourceHost = Nothing
              , taskProgressHosts = []
              , taskProgressThrottleReason = Nothing
              , taskProgressMultipart = Nothing
              }
    TaskFailed -> taskSnapshotProgress current
    TaskCancelled -> taskSnapshotProgress current
    _ -> taskSnapshotProgress current

maxMaybePercent :: Maybe Double -> Maybe Double -> Maybe Double
maxMaybePercent Nothing next = clampPercent <$> next
maxMaybePercent previous Nothing = previous
maxMaybePercent (Just previous) (Just next) = Just (max (clampPercent previous) (clampPercent next))

clampPercent :: Double -> Double
clampPercent =
  min 100 . max 0
