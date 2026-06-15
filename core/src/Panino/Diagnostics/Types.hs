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
import Data.Char (isAlphaNum)
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
    let sanitized = sanitizeDiagnosticEvidence evidence
     in
    object
      [ "key" .= diagnosticEvidenceKey sanitized
      , "value" .= diagnosticEvidenceValue sanitized
      , "redacted" .= diagnosticEvidenceRedacted sanitized
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
  diagnostic { diagnosticEvidence = stableDiagnosticEvidence (diagnosticEvidence diagnostic <> map sanitizeDiagnosticEvidence evidence) }

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
  stableSortDiagnostics stableDiagnosticEvidenceKey . map sanitizeDiagnosticEvidence

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
  Text.intercalate "\n" . map (redactLocalPaths . redactLine) . Text.lines
  where
    redactLine line
      | Just prefix <- sensitiveLinePrefix withUrlTokens =
          prefix <> "<redacted>"
      | otherwise =
          redactCliSecretFlag "--session-token" withUrlTokens
      where
        withUrlTokens = redactUrlTokens line
    sensitiveLinePrefix line =
      case lineKeyPrefix "=" line of
        Just (key, prefix) | sensitiveEvidenceKey key -> Just prefix
        _ ->
          case lineKeyPrefix ":" line of
            Just (key, prefix) | sensitiveEvidenceKey key -> Just prefix
            _ -> Nothing
    lineKeyPrefix separator line =
      case Text.breakOn separator line of
        (key, rest)
          | Text.null rest -> Nothing
          | otherwise ->
              let afterSeparator = Text.drop (Text.length separator) rest
                  spaces = Text.takeWhile (== ' ') afterSeparator
               in Just (key, key <> separator <> spaces)
    redactUrlTokens line =
      foldl (\current key -> redactUrlTokenKey key current)
        line
        [ "token"
        , "access_token"
        , "refresh_token"
        , "client_secret"
        , "signature"
        , "sig"
        , "X-Amz-Signature"
        , "AWSAccessKeyId"
        , "api_key"
        ]

sanitizeDiagnosticEvidence :: DiagnosticEvidence -> DiagnosticEvidence
sanitizeDiagnosticEvidence evidence
  | diagnosticEvidenceRedacted evidence || sensitiveEvidenceKey (diagnosticEvidenceKey evidence) =
      evidence { diagnosticEvidenceValue = "<redacted>", diagnosticEvidenceRedacted = True }
  | otherwise =
      let redacted = redactedText (diagnosticEvidenceValue evidence)
       in evidence { diagnosticEvidenceValue = redacted, diagnosticEvidenceRedacted = redacted /= diagnosticEvidenceValue evidence }

sensitiveEvidenceKey :: Text -> Bool
sensitiveEvidenceKey key =
  any (`Text.isInfixOf` normalized)
    [ "token"
    , "secret"
    , "apikey"
    , "authorization"
    , "cookie"
    , "signature"
    , "password"
    , "awsaccesskeyid"
    ]
    || normalized == "sig"
    || "xms" `Text.isPrefixOf` normalized
    || normalized `elem` ["xauthtoken", "xapikey"]
  where
    normalized =
      Text.filter isAlphaNum (Text.toLower key)

redactUrlTokenKey :: Text -> Text -> Text
redactUrlTokenKey key =
  redactUrlTokenPrefix ("?" <> key <> "=") . redactUrlTokenPrefix ("&" <> key <> "=")

redactUrlTokenPrefix :: Text -> Text -> Text
redactUrlTokenPrefix prefix text =
  case Text.breakOn prefix text of
    (before, rest)
      | Text.null rest -> text
      | otherwise ->
          let afterPrefix = Text.drop (Text.length prefix) rest
              (value, suffix) = Text.break (`elem` ['&', ' ', '\n', '\t', '"', '\'']) afterPrefix
           in before <> prefix <> if Text.null value then suffix else "<redacted>" <> redactUrlTokenPrefix prefix suffix

redactCliSecretFlag :: Text -> Text -> Text
redactCliSecretFlag flag =
  redactTokenAfter (flag <> " ") . redactTokenAfter (flag <> "=")

redactTokenAfter :: Text -> Text -> Text
redactTokenAfter prefix text =
  case Text.breakOn prefix text of
    (before, rest)
      | Text.null rest -> text
      | otherwise ->
          let afterPrefix = Text.drop (Text.length prefix) rest
              (value, suffix) = Text.break (`elem` [' ', '\n', '\t', '"', '\'']) afterPrefix
           in before <> prefix <> if Text.null value then suffix else "<redacted>" <> redactTokenAfter prefix suffix

redactLocalPaths :: Text -> Text
redactLocalPaths =
  redactPathPrefix "file:///Users/" "file://~/" . redactPathPrefix "/Users/" "~/"

redactPathPrefix :: Text -> Text -> Text -> Text
redactPathPrefix prefix replacement text =
  case Text.breakOn prefix text of
    (before, rest)
      | Text.null rest -> text
      | otherwise ->
          let afterPrefix = Text.drop (Text.length prefix) rest
              (_, afterUser) = Text.break (== '/') afterPrefix
           in before <> replacement <> redactPathPrefix prefix replacement (Text.dropWhile (== '/') afterUser)
