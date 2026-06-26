{-# LANGUAGE OverloadedStrings #-}

module Panino.Multiplayer.Taowa.Types.Session
  ( TaowaSessionStatus(..)
  , TaowaSession(..)
  , TaowaSessionHistoryClearRequest(..)
  , TaowaSessionHistoryClearResponse(..)
  , TaowaSessionStartRequest(..)
  , TaowaSessionsResponse(..)
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
