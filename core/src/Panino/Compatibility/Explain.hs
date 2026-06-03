{-# LANGUAGE OverloadedStrings #-}

module Panino.Compatibility.Explain
  ( CompatibilityExplanation(..)
  , explainCompatibilityReport
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.Text (Text)
import Panino.Compatibility.Types
  ( CompatibilityReport(..)
  , CompatibilityStatus(..)
  , compatibilityStatusText
  )
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , DiagnosticAction(..)
  )

data CompatibilityExplanation = CompatibilityExplanation
  { compatibilityExplanationStatus :: CompatibilityStatus
  , compatibilityExplanationSummary :: Text
  , compatibilityExplanationReasons :: [Text]
  , compatibilityExplanationActions :: [Text]
  , compatibilityExplanationReport :: CompatibilityReport
  } deriving (Eq, Show)

instance ToJSON CompatibilityExplanation where
  toJSON explanation =
    object
      [ "status" .= compatibilityExplanationStatus explanation
      , "summary" .= compatibilityExplanationSummary explanation
      , "reasons" .= compatibilityExplanationReasons explanation
      , "actions" .= compatibilityExplanationActions explanation
      , "report" .= compatibilityExplanationReport explanation
      ]

explainCompatibilityReport :: CompatibilityReport -> CompatibilityExplanation
explainCompatibilityReport report =
  CompatibilityExplanation
    { compatibilityExplanationStatus = compatibilityReportStatus report
    , compatibilityExplanationSummary = compatibilityReportSummary report
    , compatibilityExplanationReasons = reasons
    , compatibilityExplanationActions = actions
    , compatibilityExplanationReport = report
    }
  where
    reasons =
      case compatibilityReportStatus report of
        CompatibilityCompatible ->
          ["status:" <> compatibilityStatusText CompatibilityCompatible]
        CompatibilityWarning ->
          compatibilityReportWarnings report
        CompatibilityBlocked ->
          compatibilityReportBlockedReasons report
        CompatibilityUnknown ->
          unknownReasons
    unknownReasons =
      [ diagnosticCode diagnostic <> ":" <> diagnosticMessage diagnostic
      | diagnostic <- compatibilityReportGlobalDiagnostics report
      , diagnosticCode diagnostic == "compat_metadata_unknown"
      ]
        <> compatibilityReportWarnings report
    actions =
      [ diagnosticActionKind action <> ":" <> diagnosticActionLabel action
      | action <- compatibilityReportActions report
      ]
