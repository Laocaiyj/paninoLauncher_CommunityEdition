{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.CompanionProtocol
  ( CompanionEnvelope(..)
  , companionProtocolVersion
  , mergeCompanionFrameSample
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Text (Text)
import Panino.Performance.Telemetry.Types
  ( CompanionFrameSample(..)
  , PerformanceSession(..)
  )

companionProtocolVersion :: Text
companionProtocolVersion =
  "panino-companion-v1"

data CompanionEnvelope = CompanionEnvelope
  { companionVersion :: Text
  , companionLaunchSessionId :: Text
  , companionToken :: Maybe Text
  , companionFrameSample :: CompanionFrameSample
  } deriving (Eq, Show)

instance ToJSON CompanionEnvelope where
  toJSON envelope =
    object
      [ "version" .= companionVersion envelope
      , "launchSessionId" .= companionLaunchSessionId envelope
      , "token" .= companionToken envelope
      , "frame" .= companionFrameSample envelope
      ]

instance FromJSON CompanionEnvelope where
  parseJSON =
    withObject "CompanionEnvelope" $ \obj ->
      CompanionEnvelope
        <$> obj .:? "version" .!= companionProtocolVersion
        <*> obj .:? "launchSessionId" .!= ""
        <*> obj .:? "token"
        <*> obj .:? "frame" .!= CompanionFrameSample Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing

mergeCompanionFrameSample :: CompanionEnvelope -> PerformanceSession -> PerformanceSession
mergeCompanionFrameSample envelope session =
  if companionLaunchSessionId envelope == sessionLaunchSessionId session
    then session { sessionCompanionFrameMetrics = Just (companionFrameSample envelope) }
    else session
