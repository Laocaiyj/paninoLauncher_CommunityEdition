{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.Explain
  ( recommendationFromProfiles
  ) where

import Data.Text (Text)
import Panino.Performance.Profile.Types
  ( PerformanceConfidence(..)
  , PerformanceEvidence(..)
  , PerformanceProfile(..)
  , PerformanceRecommendation(..)
  )

recommendationFromProfiles :: FilePath -> PerformanceProfile -> Maybe PerformanceProfile -> PerformanceRecommendation
recommendationFromProfiles gameDir baseline maybeCandidate =
  PerformanceRecommendation
    { recommendationProfileId = maybe (profileId baseline) profileId maybeCandidate
    , recommendationConfidence = maybe (profileConfidence baseline) profileConfidence maybeCandidate
    , recommendationEvidence =
        profileEvidence baseline <> maybe [] profileEvidence maybeCandidate
    , recommendationObjectiveScore = Nothing
    , recommendationWarnings = warningText
    , recommendationActions = actionText
    , recommendationRollbackRef = maybe (profileRollbackRef baseline) profileRollbackRef maybeCandidate
    , recommendationDiagnosticPaths =
        [ gameDir <> "/.panino/performance/sessions"
        , gameDir <> "/.panino/performance/profiles"
        ]
    , recommendationBaseline = baseline
    , recommendationCandidate = maybeCandidate
    }
  where
    warningText =
      case maybe (profileConfidence baseline) profileConfidence maybeCandidate of
        ConfidenceEstimated -> ["estimated_baseline_not_measured"]
        ConfidenceBlocked -> ["recommendation_blocked"]
        _ -> []
    actionText =
      case maybeCandidate of
        Nothing -> ["reviewBaseline"]
        Just _ -> ["reviewCandidate", "applyWithRollback"]

_evidenceText :: PerformanceEvidence -> Text
_evidenceText evidence =
  evidenceKey evidence <> "=" <> evidenceValue evidence
