{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.Experiment
  ( ExperimentResult(..)
  , completeExperiment
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.Text (Text)
import Panino.Performance.Objective
  ( PerformanceObjective
  , PerformanceScore(..)
  , scoreSession
  )
import Panino.Performance.Telemetry.Types
  ( PerformanceSession
  )

data ExperimentResult = ExperimentResult
  { experimentWinner :: Text
  , experimentBaselineScore :: PerformanceScore
  , experimentCandidateScore :: PerformanceScore
  , experimentReasons :: [Text]
  } deriving (Eq, Show)

instance ToJSON ExperimentResult where
  toJSON result =
    object
      [ "winner" .= experimentWinner result
      , "baselineScore" .= experimentBaselineScore result
      , "candidateScore" .= experimentCandidateScore result
      , "reasons" .= experimentReasons result
      ]

completeExperiment :: PerformanceObjective -> PerformanceSession -> PerformanceSession -> ExperimentResult
completeExperiment objective baseline candidate =
  ExperimentResult
    { experimentWinner = winner
    , experimentBaselineScore = baselineScore
    , experimentCandidateScore = candidateScore
    , experimentReasons = reasons
    }
  where
    baselineScore = scoreSession objective baseline
    candidateScore = scoreSession objective candidate
    candidateWins =
      not (scoreRejected candidateScore)
        && scoreOverall candidateScore > scoreOverall baselineScore
    winner =
      if candidateWins then "candidate" else "baseline"
    reasons =
      if candidateWins
        then ["candidate_score_improved"]
        else "candidate_rejected_or_not_better" : scoreRejectReasons candidateScore
