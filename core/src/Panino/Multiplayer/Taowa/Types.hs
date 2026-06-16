{-# LANGUAGE OverloadedStrings #-}

module Panino.Multiplayer.Taowa.Types
  ( TaowaTunnelProtocol(..)
  , TaowaFrpProfile(..)
  , TaowaFrpProfileRequest(..)
  , TaowaFrpProfilePublic(..)
  , TaowaFrpProfileTestCheck(..)
  , TaowaFrpProfileTestResponse(..)
  , TaowaProfilesResponse(..)
  , TaowaLanDetectRequest(..)
  , TaowaLanDetectStatus(..)
  , TaowaLanEvidence(..)
  , TaowaLanPortDetection(..)
  , TaowaLanValidatePortRequest(..)
  , TaowaSessionStatus(..)
  , TaowaSession(..)
  , TaowaSessionHistoryClearRequest(..)
  , TaowaSessionHistoryClearResponse(..)
  , TaowaSessionStartRequest(..)
  , TaowaSessionsResponse(..)
  , publicProfile
  , redactedToken
  , taowaRemoteAddress
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
import Data.Time.Clock (UTCTime)
import Panino.Diagnostics.Types (Diagnostic)

data TaowaTunnelProtocol
  = TaowaTcp
  deriving (Eq, Show)

instance ToJSON TaowaTunnelProtocol where
  toJSON TaowaTcp = "tcp"

instance FromJSON TaowaTunnelProtocol where
  parseJSON =
    withText "TaowaTunnelProtocol" $ \value ->
      case Text.toLower value of
        "tcp" -> pure TaowaTcp
        other -> fail ("unsupported taowa tunnel protocol: " <> Text.unpack other)

data TaowaFrpProfile = TaowaFrpProfile
  { taowaProfileId :: Text
  , taowaProfileDisplayName :: Text
  , taowaProfileServerAddr :: Text
  , taowaProfileServerPort :: Int
  , taowaProfileToken :: Maybe Text
  , taowaProfileRemotePort :: Int
  , taowaProfileProtocol :: TaowaTunnelProtocol
  , taowaProfileFrpcPath :: FilePath
  , taowaProfileEnabled :: Bool
  , taowaProfileCreatedAt :: UTCTime
  , taowaProfileUpdatedAt :: UTCTime
  } deriving (Eq, Show)

instance ToJSON TaowaFrpProfile where
  toJSON profile =
    object
      [ "profileId" .= taowaProfileId profile
      , "displayName" .= taowaProfileDisplayName profile
      , "serverAddr" .= taowaProfileServerAddr profile
      , "serverPort" .= taowaProfileServerPort profile
      , "token" .= taowaProfileToken profile
      , "remotePort" .= taowaProfileRemotePort profile
      , "protocol" .= taowaProfileProtocol profile
      , "frpcPath" .= taowaProfileFrpcPath profile
      , "enabled" .= taowaProfileEnabled profile
      , "createdAt" .= taowaProfileCreatedAt profile
      , "updatedAt" .= taowaProfileUpdatedAt profile
      ]

instance FromJSON TaowaFrpProfile where
  parseJSON =
    withObject "TaowaFrpProfile" $ \obj ->
      TaowaFrpProfile
        <$> obj .: "profileId"
        <*> obj .: "displayName"
        <*> obj .: "serverAddr"
        <*> obj .: "serverPort"
        <*> obj .:? "token"
        <*> obj .: "remotePort"
        <*> obj .:? "protocol" .!= TaowaTcp
        <*> obj .: "frpcPath"
        <*> obj .:? "enabled" .!= True
        <*> obj .: "createdAt"
        <*> obj .: "updatedAt"

data TaowaFrpProfileRequest = TaowaFrpProfileRequest
  { taowaRequestProfileId :: Maybe Text
  , taowaRequestDisplayName :: Text
  , taowaRequestServerAddr :: Text
  , taowaRequestServerPort :: Int
  , taowaRequestToken :: Maybe Text
  , taowaRequestRemotePort :: Int
  , taowaRequestProtocol :: TaowaTunnelProtocol
  , taowaRequestFrpcPath :: FilePath
  , taowaRequestEnabled :: Bool
  } deriving (Eq, Show)

instance FromJSON TaowaFrpProfileRequest where
  parseJSON =
    withObject "TaowaFrpProfileRequest" $ \obj ->
      TaowaFrpProfileRequest
        <$> obj .:? "profileId"
        <*> obj .: "displayName"
        <*> obj .: "serverAddr"
        <*> obj .: "serverPort"
        <*> obj .:? "token"
        <*> obj .: "remotePort"
        <*> obj .:? "protocol" .!= TaowaTcp
        <*> obj .: "frpcPath"
        <*> obj .:? "enabled" .!= True

data TaowaFrpProfilePublic = TaowaFrpProfilePublic
  { taowaPublicProfileId :: Text
  , taowaPublicDisplayName :: Text
  , taowaPublicServerAddr :: Text
  , taowaPublicServerPort :: Int
  , taowaPublicToken :: Maybe Text
  , taowaPublicHasToken :: Bool
  , taowaPublicRemotePort :: Int
  , taowaPublicProtocol :: TaowaTunnelProtocol
  , taowaPublicFrpcPath :: FilePath
  , taowaPublicEnabled :: Bool
  , taowaPublicCreatedAt :: UTCTime
  , taowaPublicUpdatedAt :: UTCTime
  } deriving (Eq, Show)

instance ToJSON TaowaFrpProfilePublic where
  toJSON profile =
    object
      [ "profileId" .= taowaPublicProfileId profile
      , "displayName" .= taowaPublicDisplayName profile
      , "serverAddr" .= taowaPublicServerAddr profile
      , "serverPort" .= taowaPublicServerPort profile
      , "token" .= taowaPublicToken profile
      , "hasToken" .= taowaPublicHasToken profile
      , "remotePort" .= taowaPublicRemotePort profile
      , "protocol" .= taowaPublicProtocol profile
      , "frpcPath" .= taowaPublicFrpcPath profile
      , "enabled" .= taowaPublicEnabled profile
      , "createdAt" .= taowaPublicCreatedAt profile
      , "updatedAt" .= taowaPublicUpdatedAt profile
      ]

newtype TaowaProfilesResponse = TaowaProfilesResponse
  { taowaProfiles :: [TaowaFrpProfilePublic]
  } deriving (Eq, Show)

instance ToJSON TaowaProfilesResponse where
  toJSON response =
    object ["profiles" .= taowaProfiles response]

data TaowaFrpProfileTestCheck = TaowaFrpProfileTestCheck
  { taowaProfileTestCheckName :: Text
  , taowaProfileTestCheckOk :: Bool
  , taowaProfileTestCheckMessage :: Text
  } deriving (Eq, Show)

instance ToJSON TaowaFrpProfileTestCheck where
  toJSON check =
    object
      [ "name" .= taowaProfileTestCheckName check
      , "ok" .= taowaProfileTestCheckOk check
      , "message" .= taowaProfileTestCheckMessage check
      ]

data TaowaFrpProfileTestResponse = TaowaFrpProfileTestResponse
  { taowaProfileTestProfileId :: Text
  , taowaProfileTestOk :: Bool
  , taowaProfileTestChecks :: [TaowaFrpProfileTestCheck]
  , taowaProfileTestDiagnostics :: [Diagnostic]
  } deriving (Eq, Show)

instance ToJSON TaowaFrpProfileTestResponse where
  toJSON response =
    object
      [ "profileId" .= taowaProfileTestProfileId response
      , "ok" .= taowaProfileTestOk response
      , "checks" .= taowaProfileTestChecks response
      , "diagnostics" .= taowaProfileTestDiagnostics response
      ]

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

data TaowaSessionStatus
  = TaowaSessionPrepared
  | TaowaSessionStartingFrpc
  | TaowaSessionRunning
  | TaowaSessionStopped
  | TaowaSessionFailed
  deriving (Eq, Show)

instance ToJSON TaowaSessionStatus where
  toJSON status =
    case status of
      TaowaSessionPrepared -> "prepared"
      TaowaSessionStartingFrpc -> "startingFrpc"
      TaowaSessionRunning -> "running"
      TaowaSessionStopped -> "stopped"
      TaowaSessionFailed -> "failed"

instance FromJSON TaowaSessionStatus where
  parseJSON =
    withText "TaowaSessionStatus" $ \value ->
      case value of
        "prepared" -> pure TaowaSessionPrepared
        "startingFrpc" -> pure TaowaSessionStartingFrpc
        "running" -> pure TaowaSessionRunning
        "stopped" -> pure TaowaSessionStopped
        "failed" -> pure TaowaSessionFailed
        other -> fail ("unsupported taowa session status: " <> Text.unpack other)

data TaowaSession = TaowaSession
  { taowaSessionId :: Text
  , taowaSessionProfileId :: Text
  , taowaSessionInstanceId :: Maybe Text
  , taowaSessionGameDir :: FilePath
  , taowaSessionLocalPort :: Int
  , taowaSessionRemoteAddress :: Text
  , taowaSessionRemotePort :: Int
  , taowaSessionFrpcConfigPath :: FilePath
  , taowaSessionFrpcLogPath :: FilePath
  , taowaSessionStatus :: TaowaSessionStatus
  , taowaSessionProcessId :: Maybe Int
  , taowaSessionDiagnostics :: [Diagnostic]
  , taowaSessionStartedAt :: UTCTime
  , taowaSessionUpdatedAt :: UTCTime
  } deriving (Eq, Show)

instance ToJSON TaowaSession where
  toJSON session =
    object
      [ "sessionId" .= taowaSessionId session
      , "profileId" .= taowaSessionProfileId session
      , "instanceId" .= taowaSessionInstanceId session
      , "gameDir" .= taowaSessionGameDir session
      , "localPort" .= taowaSessionLocalPort session
      , "remoteAddress" .= taowaSessionRemoteAddress session
      , "remotePort" .= taowaSessionRemotePort session
      , "frpcConfigPath" .= taowaSessionFrpcConfigPath session
      , "frpcLogPath" .= taowaSessionFrpcLogPath session
      , "status" .= taowaSessionStatus session
      , "processId" .= taowaSessionProcessId session
      , "diagnostics" .= taowaSessionDiagnostics session
      , "startedAt" .= taowaSessionStartedAt session
      , "updatedAt" .= taowaSessionUpdatedAt session
      ]

instance FromJSON TaowaSession where
  parseJSON =
    withObject "TaowaSession" $ \obj ->
      TaowaSession
        <$> obj .: "sessionId"
        <*> obj .: "profileId"
        <*> obj .:? "instanceId"
        <*> obj .: "gameDir"
        <*> obj .: "localPort"
        <*> obj .: "remoteAddress"
        <*> obj .: "remotePort"
        <*> obj .: "frpcConfigPath"
        <*> obj .: "frpcLogPath"
        <*> obj .:? "status" .!= TaowaSessionPrepared
        <*> obj .:? "processId"
        <*> obj .:? "diagnostics" .!= []
        <*> obj .: "startedAt"
        <*> obj .: "updatedAt"

data TaowaSessionStartRequest = TaowaSessionStartRequest
  { taowaStartProfileId :: Text
  , taowaStartInstanceId :: Maybe Text
  , taowaStartGameDir :: FilePath
  , taowaStartLocalPort :: Int
  } deriving (Eq, Show)

instance FromJSON TaowaSessionStartRequest where
  parseJSON =
    withObject "TaowaSessionStartRequest" $ \obj ->
      TaowaSessionStartRequest
        <$> obj .: "profileId"
        <*> obj .:? "instanceId"
        <*> obj .: "gameDir"
        <*> obj .: "localPort"

newtype TaowaSessionsResponse = TaowaSessionsResponse
  { taowaSessions :: [TaowaSession]
  } deriving (Eq, Show)

instance ToJSON TaowaSessionsResponse where
  toJSON response =
    object ["sessions" .= taowaSessions response]

data TaowaSessionHistoryClearRequest = TaowaSessionHistoryClearRequest
  { taowaClearSessionStatuses :: Maybe [TaowaSessionStatus]
  , taowaClearKeepActive :: Bool
  } deriving (Eq, Show)

instance FromJSON TaowaSessionHistoryClearRequest where
  parseJSON =
    withObject "TaowaSessionHistoryClearRequest" $ \obj ->
      TaowaSessionHistoryClearRequest
        <$> obj .:? "statuses"
        <*> obj .:? "keepActive" .!= True

data TaowaSessionHistoryClearResponse = TaowaSessionHistoryClearResponse
  { taowaClearDeleted :: Int
  , taowaClearKept :: Int
  , taowaClearSkippedActive :: Int
  } deriving (Eq, Show)

instance ToJSON TaowaSessionHistoryClearResponse where
  toJSON response =
    object
      [ "deleted" .= taowaClearDeleted response
      , "kept" .= taowaClearKept response
      , "skippedActive" .= taowaClearSkippedActive response
      ]

publicProfile :: TaowaFrpProfile -> TaowaFrpProfilePublic
publicProfile profile =
  TaowaFrpProfilePublic
    { taowaPublicProfileId = taowaProfileId profile
    , taowaPublicDisplayName = taowaProfileDisplayName profile
    , taowaPublicServerAddr = taowaProfileServerAddr profile
    , taowaPublicServerPort = taowaProfileServerPort profile
    , taowaPublicToken = redactedToken <$> taowaProfileToken profile
    , taowaPublicHasToken = maybe False (not . Text.null) (taowaProfileToken profile)
    , taowaPublicRemotePort = taowaProfileRemotePort profile
    , taowaPublicProtocol = taowaProfileProtocol profile
    , taowaPublicFrpcPath = taowaProfileFrpcPath profile
    , taowaPublicEnabled = taowaProfileEnabled profile
    , taowaPublicCreatedAt = taowaProfileCreatedAt profile
    , taowaPublicUpdatedAt = taowaProfileUpdatedAt profile
    }

redactedToken :: Text -> Text
redactedToken token
  | Text.null token = ""
  | Text.length token <= 4 = "<redacted>"
  | otherwise = Text.take 2 token <> "..." <> Text.takeEnd 2 token

taowaRemoteAddress :: TaowaFrpProfile -> Text
taowaRemoteAddress profile =
  taowaProfileServerAddr profile <> ":" <> Text.pack (show (taowaProfileRemotePort profile))
