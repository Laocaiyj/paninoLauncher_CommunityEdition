{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE OverloadedStrings #-}

module Panino.Diagnostics.Types
  ( Diagnostic(..)
  , DiagnosticAction(..)
  , DiagnosticEvidence(..)
  , DiagnosticException(..)
  , FailureInput(..)
  , diagnosticCodeDetail
  , diagnosticException
  , diagnosticWithEvidence
  , diagnosticWithFilePath
  , diagnosticWithPlanId
  , diagnosticWithTaskId
  , redactedText
  ) where

import Control.Exception (Exception)
import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , Value
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Data (Typeable)
import Data.List (isInfixOf)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.CoreLogic.Determinism (stableSortDiagnostics)

data DiagnosticAction = DiagnosticAction
  { diagnosticActionKind :: Text
  , diagnosticActionLabel :: Text
  , diagnosticActionTarget :: Maybe Text
  , diagnosticActionPayload :: Maybe Value
  } deriving (Eq, Show)

instance ToJSON DiagnosticAction where
  toJSON action =
    object
      [ "kind" .= diagnosticActionKind action
      , "label" .= diagnosticActionLabel action
      , "target" .= diagnosticActionTarget action
      , "payload" .= diagnosticActionPayload action
      ]

instance FromJSON DiagnosticAction where
  parseJSON =
    withObject "DiagnosticAction" $ \obj ->
      DiagnosticAction
        <$> obj .:? "kind" .!= "openDiagnostics"
        <*> obj .:? "label" .!= "Open diagnostics"
        <*> obj .:? "target"
        <*> obj .:? "payload"

data DiagnosticEvidence = DiagnosticEvidence
  { diagnosticEvidenceKey :: Text
  , diagnosticEvidenceValue :: Text
  , diagnosticEvidenceRedacted :: Bool
  } deriving (Eq, Show)

instance ToJSON DiagnosticEvidence where
  toJSON evidence =
    object
      [ "key" .= diagnosticEvidenceKey evidence
      , "value" .= diagnosticEvidenceValue evidence
      , "redacted" .= diagnosticEvidenceRedacted evidence
      ]

instance FromJSON DiagnosticEvidence where
  parseJSON =
    withObject "DiagnosticEvidence" $ \obj ->
      DiagnosticEvidence
        <$> obj .: "key"
        <*> obj .:? "value" .!= ""
        <*> obj .:? "redacted" .!= False

data Diagnostic = Diagnostic
  { diagnosticCode :: Text
  , diagnosticPhase :: Text
  , diagnosticSeverity :: Text
  , diagnosticTitle :: Text
  , diagnosticMessage :: Text
  , diagnosticCause :: Text
  , diagnosticAction :: DiagnosticAction
  , diagnosticRetryable :: Bool
  , diagnosticUserVisible :: Bool
  , diagnosticSource :: Text
  , diagnosticTaskId :: Maybe Text
  , diagnosticPlanId :: Maybe Text
  , diagnosticPackageId :: Maybe Text
  , diagnosticFilePath :: Maybe FilePath
  , diagnosticUrlHost :: Maybe Text
  , diagnosticEvidence :: [DiagnosticEvidence]
  , diagnosticDeveloperDetail :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON Diagnostic where
  toJSON diagnostic =
    object
      [ "code" .= diagnosticCode diagnostic
      , "phase" .= diagnosticPhase diagnostic
      , "severity" .= diagnosticSeverity diagnostic
      , "title" .= diagnosticTitle diagnostic
      , "message" .= diagnosticMessage diagnostic
      , "cause" .= diagnosticCause diagnostic
      , "action" .= diagnosticAction diagnostic
      , "retryable" .= diagnosticRetryable diagnostic
      , "userVisible" .= diagnosticUserVisible diagnostic
      , "source" .= diagnosticSource diagnostic
      , "taskId" .= diagnosticTaskId diagnostic
      , "planId" .= diagnosticPlanId diagnostic
      , "packageId" .= diagnosticPackageId diagnostic
      , "filePath" .= diagnosticFilePath diagnostic
      , "urlHost" .= diagnosticUrlHost diagnostic
      , "evidence" .= stableDiagnosticEvidence (diagnosticEvidence diagnostic)
      , "developerDetail" .= diagnosticDeveloperDetail diagnostic
      ]

instance FromJSON Diagnostic where
  parseJSON =
    withObject "Diagnostic" $ \obj ->
      Diagnostic
        <$> obj .: "code"
        <*> obj .:? "phase" .!= "diagnostic"
        <*> obj .:? "severity" .!= "error"
        <*> obj .:? "title" .!= "Task failed"
        <*> obj .:? "message" .!= "Task failed. Open diagnostics for details."
        <*> obj .:? "cause" .!= "The operation failed before Core could provide a specific cause."
        <*> obj .:? "action" .!= defaultDiagnosticAction
        <*> obj .:? "retryable" .!= False
        <*> obj .:? "userVisible" .!= True
        <*> obj .:? "source" .!= "core"
        <*> obj .:? "taskId"
        <*> obj .:? "planId"
        <*> obj .:? "packageId"
        <*> obj .:? "filePath"
        <*> obj .:? "urlHost"
        <*> obj .:? "evidence" .!= []
        <*> obj .:? "developerDetail"

data FailureInput = FailureInput
  { failurePhase :: Text
  , failureOperation :: Text
  , failureExceptionText :: Text
  , failureContext :: [(Text, Text)]
  , failureTaskId :: Maybe Text
  , failurePlanId :: Maybe Text
  , failureSource :: Maybe Text
  } deriving (Eq, Show)

newtype DiagnosticException = DiagnosticException Diagnostic
  deriving (Show, Typeable)

instance Exception DiagnosticException

diagnosticException :: Diagnostic -> DiagnosticException
diagnosticException = DiagnosticException

diagnosticWithTaskId :: Text -> Diagnostic -> Diagnostic
diagnosticWithTaskId taskId diagnostic =
  diagnostic { diagnosticTaskId = Just taskId }

diagnosticWithPlanId :: Text -> Diagnostic -> Diagnostic
diagnosticWithPlanId planId diagnostic =
  diagnostic { diagnosticPlanId = Just planId }

diagnosticWithFilePath :: FilePath -> Diagnostic -> Diagnostic
diagnosticWithFilePath filePath diagnostic =
  diagnostic { diagnosticFilePath = Just filePath }

diagnosticWithEvidence :: [DiagnosticEvidence] -> Diagnostic -> Diagnostic
diagnosticWithEvidence evidence diagnostic =
  diagnostic { diagnosticEvidence = stableDiagnosticEvidence (diagnosticEvidence diagnostic <> evidence) }

diagnosticCodeDetail :: Diagnostic -> (Maybe Text, Maybe Text)
diagnosticCodeDetail diagnostic =
  (Just (diagnosticCode diagnostic), diagnosticDeveloperDetail diagnostic)

defaultDiagnosticAction :: DiagnosticAction
defaultDiagnosticAction =
  DiagnosticAction
    { diagnosticActionKind = "openDiagnostics"
    , diagnosticActionLabel = "Open diagnostics"
    , diagnosticActionTarget = Nothing
    , diagnosticActionPayload = Nothing
    }

stableDiagnosticEvidence :: [DiagnosticEvidence] -> [DiagnosticEvidence]
stableDiagnosticEvidence =
  stableSortDiagnostics stableDiagnosticEvidenceKey

stableDiagnosticEvidenceKey :: DiagnosticEvidence -> Text
stableDiagnosticEvidenceKey evidence =
  Text.intercalate
    "|"
    [ diagnosticEvidenceKey evidence
    , diagnosticEvidenceValue evidence
    , if diagnosticEvidenceRedacted evidence then "redacted" else "visible"
    ]

redactedText :: Text -> Text
redactedText =
  Text.unlines . map redactLine . Text.lines
  where
    redactLine line
      | any (`isInfixOf` lowered) sensitiveNeedles =
          keyPart line <> "<redacted>"
      | otherwise =
          redactUrlToken line
      where
        lowered = Text.unpack (Text.toLower line)
    keyPart line =
      fromMaybe "" $
        case Text.breakOn "=" line of
          (key, rest) | not (Text.null rest) -> Just (key <> "=")
          _ ->
            case Text.breakOn ":" line of
              (key, rest) | not (Text.null rest) -> Just (key <> ": ")
              _ -> Nothing
    sensitiveNeedles =
      [ "token"
      , "access_token"
      , "api_key"
      , "apikey"
      , "authorization"
      , "password"
      , "secret"
      ]
    redactUrlToken line =
      Text.replace "access_token=" "access_token=<redacted>&" $
        Text.replace "api_key=" "api_key=<redacted>&" line
