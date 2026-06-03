{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.SafetyGate
  ( SafetyGateDecision(..)
  , checkSafetyGate
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.Text (Text)
import Panino.Performance.Objective
  ( PerformanceObjective(..)
  , PerformanceScore(..)
  , scoreSession
  )
import Panino.Performance.Profile.Types
  ( PerformanceKnobs(..)
  , PerformanceProfile(..)
  )
import Panino.Performance.Telemetry.Types
  ( PerformanceSession
  )

data SafetyGateDecision = SafetyGateDecision
  { safetyAllowed :: Bool
  , safetyReasons :: [Text]
  , safetyScore :: Maybe PerformanceScore
  } deriving (Eq, Show)

instance ToJSON SafetyGateDecision where
  toJSON decision =
    object
      [ "allowed" .= safetyAllowed decision
      , "reasons" .= safetyReasons decision
      , "score" .= safetyScore decision
      ]

checkSafetyGate :: PerformanceObjective -> Maybe PerformanceSession -> PerformanceProfile -> SafetyGateDecision
checkSafetyGate objective maybeBaseline candidate =
  case maybeBaseline of
    Nothing ->
      baseDecision ["estimated_only"]
    Just session ->
      let score = scoreSession objective session
          reasons =
            scoreRejectReasons score
              <> visualLossReasons
              <> [ "cooldown_active" | profileCooldownUntil candidate /= Nothing ]
       in SafetyGateDecision
            { safetyAllowed = null reasons
            , safetyReasons = reasons
            , safetyScore = Just score
            }
  where
    baseDecision reasons =
      let allReasons =
            reasons
              <> visualLossReasons
              <> [ "cooldown_active" | profileCooldownUntil candidate /= Nothing ]
       in
      SafetyGateDecision
        { safetyAllowed = null allReasons
        , safetyReasons = allReasons
        , safetyScore = Nothing
        }
    visualLossReasons =
      [ "visual_loss"
      | visualLossEstimate (profileKnobs candidate) > objectiveMaxVisualLoss objective
      ]

visualLossEstimate :: PerformanceKnobs -> Double
visualLossEstimate knobs =
  maximum
    [ maybe 0 renderDistanceLoss (knobRenderDistance knobs)
    , maybe 0 simulationDistanceLoss (knobSimulationDistance knobs)
    , maybe 0 maxFpsLoss (knobMaxFps knobs)
    ]
  where
    renderDistanceLoss distance
      | distance < 6 = 0.35
      | distance < 8 = 0.20
      | otherwise = 0
    simulationDistanceLoss distance
      | distance < 4 = 0.30
      | distance < 6 = 0.15
      | otherwise = 0
    maxFpsLoss fps
      | fps < 45 = 0.30
      | fps < 60 = 0.10
      | otherwise = 0
