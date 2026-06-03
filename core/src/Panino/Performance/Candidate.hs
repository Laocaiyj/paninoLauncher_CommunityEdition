{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.Candidate
  ( CandidateBudget(..)
  , candidateChangeCount
  , generateCandidate
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.Maybe (catMaybes)
import qualified Data.Text as Text
import Panino.Performance.Profile.Types
  ( PerformanceConfidence(..)
  , PerformanceEvidence(..)
  , PerformanceKnobs(..)
  , PerformanceProfile(..)
  , PerformanceProfileSource(..)
  , ProfileKind(..)
  )

data CandidateBudget = CandidateBudget
  { candidateBudgetLaunches :: Int
  , candidateBudgetChangedKnobs :: Int
  } deriving (Eq, Show)

instance ToJSON CandidateBudget where
  toJSON budget =
    object
      [ "launches" .= candidateBudgetLaunches budget
      , "changedKnobs" .= candidateBudgetChangedKnobs budget
      ]

generateCandidate :: CandidateBudget -> PerformanceProfile -> PerformanceProfile
generateCandidate budget baseline =
  baseline
    { profileId = "candidate-" <> profileId baseline
    , profileKind = ProfileCandidate
    , profileSource = ProfileSourceExperiment
    , profileKnobs = candidateKnobs
    , profileConfidence = ConfidenceEstimated
    , profileEvidence =
        PerformanceEvidence "experimentBudget" (Text.pack (show (candidateBudgetLaunches budget)) <> " launch") "candidate-generator"
          : PerformanceEvidence "changedKnobs" (Text.pack (show (candidateChangeCount (profileKnobs baseline) candidateKnobs))) "candidate-generator"
          : profileEvidence baseline
    }
  where
    baseKnobs = profileKnobs baseline
    candidateKnobs =
      if candidateBudgetChangedKnobs budget <= 1
        then lowerOnePressureKnob baseKnobs
        else lowerTwoPressureKnobs baseKnobs

candidateChangeCount :: PerformanceKnobs -> PerformanceKnobs -> Int
candidateChangeCount before after =
  length $
    catMaybes
      [ changed knobHeapMaxMb
      , changed knobRenderDistance
      , changed knobSimulationDistance
      , changed knobMaxFps
      , changed knobVsyncPolicy
      , changed knobParticles
      , changed knobClouds
      , changed knobEntityDistanceScaling
      ]
  where
    changed selector =
      if selector before == selector after then Nothing else Just ()

lowerOnePressureKnob :: PerformanceKnobs -> PerformanceKnobs
lowerOnePressureKnob knobs =
  knobs
    { knobRenderDistance = Just (max 4 (maybe 10 (subtract 2) (knobRenderDistance knobs)))
    }

lowerTwoPressureKnobs :: PerformanceKnobs -> PerformanceKnobs
lowerTwoPressureKnobs knobs =
  (lowerOnePressureKnob knobs)
    { knobMaxFps = Just (max 45 (maybe 90 (subtract 15) (knobMaxFps knobs)))
    }
