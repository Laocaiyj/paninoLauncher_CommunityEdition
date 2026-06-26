{-# LANGUAGE OverloadedStrings #-}

module Panino.Multiplayer.Taowa.Types.Profile
  ( TaowaTunnelProtocol(..)
  , TaowaFrpProfile(..)
  , TaowaFrpProfileRequest(..)
  , TaowaFrpProfilePublic(..)
  , TaowaFrpProfileTestCheck(..)
  , TaowaFrpProfileTestResponse(..)
  , TaowaProfilesResponse(..)
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
