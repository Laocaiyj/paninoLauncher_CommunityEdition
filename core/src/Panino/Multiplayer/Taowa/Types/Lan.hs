{-# LANGUAGE OverloadedStrings #-}

module Panino.Multiplayer.Taowa.Types.Lan
  ( TaowaLanDetectRequest(..)
  , TaowaLanDetectStatus(..)
  , TaowaLanEvidence(..)
  , TaowaLanPortDetection(..)
  , TaowaLanValidatePortRequest(..)
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , withText
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Diagnostics.Types (Diagnostic)

data TaowaLanDetectRequest = TaowaLanDetectRequest
  { taowaLanDetectInstanceId :: Maybe Text
  , taowaLanDetectGameDir :: FilePath
  , taowaLanDetectTimeoutSeconds :: Maybe Int
  } deriving (Eq, Show)

instance FromJSON TaowaLanDetectRequest where
  parseJSON =
    withObject "TaowaLanDetectRequest" $ \obj ->
      TaowaLanDetectRequest
        <$> obj .:? "instanceId"
        <*> obj .: "gameDir"
        <*> obj .:? "timeoutSeconds"

data TaowaLanValidatePortRequest = TaowaLanValidatePortRequest
  { taowaValidateInstanceId :: Maybe Text
  , taowaValidateGameDir :: Maybe FilePath
  , taowaValidateLocalPort :: Int
  } deriving (Eq, Show)

instance FromJSON TaowaLanValidatePortRequest where
  parseJSON =
    withObject "TaowaLanValidatePortRequest" $ \obj ->
      TaowaLanValidatePortRequest
        <$> obj .:? "instanceId"
        <*> obj .:? "gameDir"
        <*> obj .: "localPort"

data TaowaLanDetectStatus
  = TaowaLanWaitingForGame
  | TaowaLanWatchingLog
  | TaowaLanDetected
  | TaowaLanTimeout
  | TaowaLanManualRequired
  | TaowaLanFailed
  deriving (Eq, Show)

instance ToJSON TaowaLanDetectStatus where
  toJSON status =
    case status of
      TaowaLanWaitingForGame -> "waitingForGame"
      TaowaLanWatchingLog -> "watchingLog"
      TaowaLanDetected -> "detected"
      TaowaLanTimeout -> "timeout"
      TaowaLanManualRequired -> "manualRequired"
      TaowaLanFailed -> "failed"

instance FromJSON TaowaLanDetectStatus where
  parseJSON =
    withText "TaowaLanDetectStatus" $ \value ->
      case value of
        "waitingForGame" -> pure TaowaLanWaitingForGame
        "watchingLog" -> pure TaowaLanWatchingLog
        "detected" -> pure TaowaLanDetected
        "timeout" -> pure TaowaLanTimeout
        "manualRequired" -> pure TaowaLanManualRequired
        "failed" -> pure TaowaLanFailed
        other -> fail ("unsupported taowa LAN detection status: " <> Text.unpack other)

data TaowaLanEvidence = TaowaLanEvidence
  { taowaLanEvidenceKind :: Text
  , taowaLanEvidenceMessage :: Text
  , taowaLanEvidencePort :: Maybe Int
  } deriving (Eq, Show)

instance ToJSON TaowaLanEvidence where
  toJSON evidence =
    object
      [ "kind" .= taowaLanEvidenceKind evidence
      , "message" .= taowaLanEvidenceMessage evidence
      , "port" .= taowaLanEvidencePort evidence
      ]

instance FromJSON TaowaLanEvidence where
  parseJSON =
    withObject "TaowaLanEvidence" $ \obj ->
      TaowaLanEvidence
        <$> obj .: "kind"
        <*> obj .: "message"
        <*> obj .:? "port"

data TaowaLanPortDetection = TaowaLanPortDetection
  { taowaLanInstanceId :: Maybe Text
  , taowaLanGameDir :: FilePath
  , taowaLanLogPath :: FilePath
  , taowaLanStatus :: TaowaLanDetectStatus
  , taowaLanDetectedPort :: Maybe Int
  , taowaLanEvidence :: [TaowaLanEvidence]
  , taowaLanDiagnostics :: [Diagnostic]
  } deriving (Eq, Show)

instance ToJSON TaowaLanPortDetection where
  toJSON detection =
    object
      [ "instanceId" .= taowaLanInstanceId detection
      , "gameDir" .= taowaLanGameDir detection
      , "logPath" .= taowaLanLogPath detection
      , "status" .= taowaLanStatus detection
      , "detectedPort" .= taowaLanDetectedPort detection
      , "evidence" .= taowaLanEvidence detection
      , "diagnostics" .= taowaLanDiagnostics detection
      ]

instance FromJSON TaowaLanPortDetection where
  parseJSON =
    withObject "TaowaLanPortDetection" $ \obj ->
      TaowaLanPortDetection
        <$> obj .:? "instanceId"
        <*> obj .: "gameDir"
        <*> obj .: "logPath"
        <*> obj .:? "status" .!= TaowaLanWaitingForGame
        <*> obj .:? "detectedPort"
        <*> obj .:? "evidence" .!= []
        <*> obj .:? "diagnostics" .!= []
