{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.Objective
  ( PerformanceObjective(..)
  , PerformanceScore(..)
  , defaultPerformanceObjective
  , scoreSession
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Text (Text)
import Panino.Performance.Telemetry.Types
  ( CompanionFrameSample(..)
  , GcMetrics(..)
  , LaunchMetrics(..)
  , MemoryMetrics(..)
  , PerformanceSession(..)
  , PerformanceSessionStatus(..)
  )

data PerformanceObjective = PerformanceObjective
  { objectiveMaxMemoryPressure :: Text
  , objectiveMaxGcPauseP95Ms :: Double
  , objectiveMaxVisualLoss :: Double
  , objectivePreferEnergyWhenAvailable :: Bool
  } deriving (Eq, Show)

instance ToJSON PerformanceObjective where
  toJSON objective =
    object
      [ "maxMemoryPressure" .= objectiveMaxMemoryPressure objective
      , "maxGcPauseP95Ms" .= objectiveMaxGcPauseP95Ms objective
      , "maxVisualLoss" .= objectiveMaxVisualLoss objective
      , "preferEnergyWhenAvailable" .= objectivePreferEnergyWhenAvailable objective
      ]

instance FromJSON PerformanceObjective where
  parseJSON =
    withObject "PerformanceObjective" $ \obj ->
      PerformanceObjective
        <$> obj .:? "maxMemoryPressure" .!= "medium"
        <*> obj .:? "maxGcPauseP95Ms" .!= 160
        <*> obj .:? "maxVisualLoss" .!= 0.25
        <*> obj .:? "preferEnergyWhenAvailable" .!= False

defaultPerformanceObjective :: PerformanceObjective
defaultPerformanceObjective =
  PerformanceObjective
    { objectiveMaxMemoryPressure = "medium"
    , objectiveMaxGcPauseP95Ms = 160
    , objectiveMaxVisualLoss = 0.25
    , objectivePreferEnergyWhenAvailable = False
    }

data PerformanceScore = PerformanceScore
  { scoreSmoothness :: Double
  , scoreStability :: Double
  , scoreMemorySafety :: Double
  , scoreVisualQuality :: Double
  , scoreEnergy :: Maybe Double
  , scoreOverall :: Double
  , scoreRejected :: Bool
  , scoreRejectReasons :: [Text]
  } deriving (Eq, Show)

instance ToJSON PerformanceScore where
  toJSON score =
    object
      [ "smoothness" .= scoreSmoothness score
      , "stability" .= scoreStability score
      , "memorySafety" .= scoreMemorySafety score
      , "visualQuality" .= scoreVisualQuality score
      , "energy" .= scoreEnergy score
      , "overall" .= scoreOverall score
      , "rejected" .= scoreRejected score
      , "rejectReasons" .= scoreRejectReasons score
      ]

instance FromJSON PerformanceScore where
  parseJSON =
    withObject "PerformanceScore" $ \obj ->
      PerformanceScore
        <$> obj .:? "smoothness" .!= 0
        <*> obj .:? "stability" .!= 0
        <*> obj .:? "memorySafety" .!= 0
        <*> obj .:? "visualQuality" .!= 0
        <*> obj .:? "energy"
        <*> obj .:? "overall" .!= 0
        <*> obj .:? "rejected" .!= False
        <*> obj .:? "rejectReasons" .!= []

scoreSession :: PerformanceObjective -> PerformanceSession -> PerformanceScore
scoreSession objective session =
  PerformanceScore
    { scoreSmoothness = smoothness
    , scoreStability = stability
    , scoreMemorySafety = memorySafety
    , scoreVisualQuality = visualQuality
    , scoreEnergy = Nothing
    , scoreOverall = smoothness + stability + memorySafety + visualQuality - penalty
    , scoreRejected = not (null rejectReasons)
    , scoreRejectReasons = rejectReasons
    }
  where
    launch = sessionLaunchMetrics session
    memory = sessionMemoryMetrics session
    gc = sessionGcMetrics session
    frame = sessionCompanionFrameMetrics session
    smoothness =
      case frame >>= companionFrameTimeP95Ms of
        Just frameP95 -> max 0 (100 - frameP95 * 2)
        Nothing -> maybe 0 (\pause -> max 0 (100 - pause / 2)) (gcPauseP95Ms gc)
    stability =
      case sessionStatus session of
        SessionEnded -> 100
        _ -> 0
    memorySafety =
      case memoryPressureHint memory of
        Just "high" -> 10
        Just "medium" -> 60
        _ -> 100
    visualQuality = 100
    penalty =
      sum
        [ if launchCrashReportCreated launch then 100 else 0
        , if gcRegression then 30 else 0
        , if memoryPressureTooHigh then 40 else 0
        ]
    rejectReasons =
      [ "crash" | sessionStatus session /= SessionEnded || launchCrashReportCreated launch ]
        <> [ "memory_pressure" | memoryPressureTooHigh ]
        <> [ "gc_regression" | gcRegression ]
        <> [ "world_not_loaded" | maybe False ((== Just False) . companionWorldLoaded) frame ]
    memoryPressureTooHigh =
      case (objectiveMaxMemoryPressure objective, memoryPressureHint memory) of
        ("low", Just value) -> value /= "low"
        ("medium", Just "high") -> True
        _ -> False
    gcRegression =
      maybe False (> objectiveMaxGcPauseP95Ms objective) (gcPauseP95Ms gc)
