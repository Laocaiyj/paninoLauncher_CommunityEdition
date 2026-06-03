{-# LANGUAGE OverloadedStrings #-}

module Panino.Launch.Tuning.Types
  ( JvmTuningAction(..)
  , JvmTuningApplyRequest(..)
  , JvmTuningApplyResponse(..)
  , JvmTuningPolicy(..)
  , JvmTuningRequest(..)
  , JvmTuningWarning(..)
  , MemoryPolicy(..)
  , PackScale(..)
  , ResolvedJvmTuning(..)
  , defaultJvmTuningRequest
  , parseJvmTuningPolicy
  , parseMemoryPolicy
  , parsePackScale
  , renderJvmTuningPolicy
  , renderMemoryPolicy
  , renderPackScale
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
import Data.Char (isAlphaNum)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Performance.Profile.Types
  ( AdaptiveApplyMode(..)
  , PerformanceConfidence(..)
  , PerformanceEvidence
  )

data JvmTuningPolicy
  = JvmTuningAuto
  | JvmTuningLargePack
  | JvmTuningLowMemory
  | JvmTuningBatterySaver
  | JvmTuningExperimentalZgc
  | JvmTuningCustom
  deriving (Eq, Show)

renderJvmTuningPolicy :: JvmTuningPolicy -> Text
renderJvmTuningPolicy policy =
  case policy of
    JvmTuningAuto -> "auto"
    JvmTuningLargePack -> "largePack"
    JvmTuningLowMemory -> "lowMemory"
    JvmTuningBatterySaver -> "batterySaver"
    JvmTuningExperimentalZgc -> "experimentalZgc"
    JvmTuningCustom -> "custom"

parseJvmTuningPolicy :: Text -> Maybe JvmTuningPolicy
parseJvmTuningPolicy raw =
  case normalizedIdentifier raw of
    "auto" -> Just JvmTuningAuto
    "largepack" -> Just JvmTuningLargePack
    "lowmemory" -> Just JvmTuningLowMemory
    "batterysaver" -> Just JvmTuningBatterySaver
    "experimentalzgc" -> Just JvmTuningExperimentalZgc
    "zgc" -> Just JvmTuningExperimentalZgc
    "custom" -> Just JvmTuningCustom
    _ -> Nothing

instance ToJSON JvmTuningPolicy where
  toJSON =
    toJSON . renderJvmTuningPolicy

instance FromJSON JvmTuningPolicy where
  parseJSON =
    withText "JvmTuningPolicy" $ \raw ->
      case parseJvmTuningPolicy raw of
        Just policy -> pure policy
        Nothing -> fail ("unknown JVM tuning policy: " <> Text.unpack raw)

data MemoryPolicy
  = MemoryPolicyAuto
  | MemoryPolicyCustom
  deriving (Eq, Show)

renderMemoryPolicy :: MemoryPolicy -> Text
renderMemoryPolicy policy =
  case policy of
    MemoryPolicyAuto -> "auto"
    MemoryPolicyCustom -> "custom"

parseMemoryPolicy :: Text -> Maybe MemoryPolicy
parseMemoryPolicy raw =
  case normalizedIdentifier raw of
    "auto" -> Just MemoryPolicyAuto
    "custom" -> Just MemoryPolicyCustom
    _ -> Nothing

instance ToJSON MemoryPolicy where
  toJSON =
    toJSON . renderMemoryPolicy

instance FromJSON MemoryPolicy where
  parseJSON =
    withText "MemoryPolicy" $ \raw ->
      case parseMemoryPolicy raw of
        Just policy -> pure policy
        Nothing -> fail ("unknown memory policy: " <> Text.unpack raw)

data PackScale
  = PackScaleVanillaLight
  | PackScaleMediumPack
  | PackScaleLargePack
  | PackScaleUnknown
  deriving (Eq, Show)

renderPackScale :: PackScale -> Text
renderPackScale scale =
  case scale of
    PackScaleVanillaLight -> "vanillaLight"
    PackScaleMediumPack -> "mediumPack"
    PackScaleLargePack -> "largePack"
    PackScaleUnknown -> "unknown"

parsePackScale :: Text -> Maybe PackScale
parsePackScale raw =
  case normalizedIdentifier raw of
    "vanillalight" -> Just PackScaleVanillaLight
    "light" -> Just PackScaleVanillaLight
    "mediumpack" -> Just PackScaleMediumPack
    "medium" -> Just PackScaleMediumPack
    "largepack" -> Just PackScaleLargePack
    "large" -> Just PackScaleLargePack
    "unknown" -> Just PackScaleUnknown
    _ -> Nothing

instance ToJSON PackScale where
  toJSON =
    toJSON . renderPackScale

instance FromJSON PackScale where
  parseJSON =
    withText "PackScale" $ \raw ->
      case parsePackScale raw of
        Just scale -> pure scale
        Nothing -> fail ("unknown pack scale: " <> Text.unpack raw)

data JvmTuningWarning = JvmTuningWarning
  { tuningWarningCode :: Text
  , tuningWarningSeverity :: Text
  , tuningWarningMessage :: Text
  , tuningWarningAction :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON JvmTuningWarning where
  toJSON warning =
    object
      [ "code" .= tuningWarningCode warning
      , "severity" .= tuningWarningSeverity warning
      , "message" .= tuningWarningMessage warning
      , "action" .= tuningWarningAction warning
      ]

instance FromJSON JvmTuningWarning where
  parseJSON =
    withObject "JvmTuningWarning" $ \obj ->
      JvmTuningWarning
        <$> obj .:? "code" .!= "warning"
        <*> obj .:? "severity" .!= "warning"
        <*> obj .:? "message" .!= ""
        <*> obj .:? "action"

data JvmTuningAction = JvmTuningAction
  { tuningActionId :: Text
  , tuningActionTitle :: Text
  , tuningActionMemoryMb :: Maybe Int
  } deriving (Eq, Show)

instance ToJSON JvmTuningAction where
  toJSON action =
    object
      [ "id" .= tuningActionId action
      , "title" .= tuningActionTitle action
      , "memoryMb" .= tuningActionMemoryMb action
      ]

instance FromJSON JvmTuningAction where
  parseJSON =
    withObject "JvmTuningAction" $ \obj ->
      JvmTuningAction
        <$> obj .:? "id" .!= ""
        <*> obj .:? "title" .!= ""
        <*> obj .:? "memoryMb"

data JvmTuningRequest = JvmTuningRequest
  { tuningRequestInstanceId :: Maybe Text
  , tuningRequestGameDir :: Maybe FilePath
  , tuningRequestPolicy :: JvmTuningPolicy
  , tuningRequestMemoryPolicy :: MemoryPolicy
  , tuningRequestSystemMemoryBytes :: Maybe Int64
  , tuningRequestMinecraftVersion :: Maybe Text
  , tuningRequestJavaMajorVersion :: Maybe Int
  , tuningRequestLoader :: Maybe Text
  , tuningRequestModCount :: Maybe Int
  , tuningRequestResourcePackCount :: Maybe Int
  , tuningRequestShaderPackCount :: Maybe Int
  , tuningRequestPackScale :: Maybe PackScale
  , tuningRequestModpackIsLarge :: Bool
  , tuningRequestSawHeapOutOfMemory :: Bool
  , tuningRequestSawNativeOutOfMemory :: Bool
  , tuningRequestSawGcOverhead :: Bool
  , tuningRequestLastExitCode :: Maybe Int
  , tuningRequestCustomMemoryMb :: Maybe Int
  , tuningRequestCustomJvmArgs :: [Text]
  } deriving (Eq, Show)

instance FromJSON JvmTuningRequest where
  parseJSON =
    withObject "JvmTuningRequest" $ \obj ->
      JvmTuningRequest
        <$> obj .:? "instanceId"
        <*> obj .:? "gameDir"
        <*> (obj .:? "policy" .!= JvmTuningAuto)
        <*> obj .:? "memoryPolicy" .!= MemoryPolicyAuto
        <*> obj .:? "systemMemoryBytes"
        <*> obj .:? "minecraftVersion"
        <*> obj .:? "javaMajorVersion"
        <*> obj .:? "loader"
        <*> obj .:? "modCount"
        <*> obj .:? "resourcePackCount"
        <*> obj .:? "shaderPackCount"
        <*> obj .:? "packScale"
        <*> obj .:? "modpackIsLarge" .!= False
        <*> obj .:? "sawHeapOutOfMemory" .!= False
        <*> obj .:? "sawNativeOutOfMemory" .!= False
        <*> obj .:? "sawGcOverhead" .!= False
        <*> obj .:? "lastExitCode"
        <*> obj .:? "customMemoryMb"
        <*> obj .:? "customJvmArgs" .!= []

instance ToJSON JvmTuningRequest where
  toJSON request =
    object
      [ "instanceId" .= tuningRequestInstanceId request
      , "gameDir" .= tuningRequestGameDir request
      , "policy" .= tuningRequestPolicy request
      , "memoryPolicy" .= tuningRequestMemoryPolicy request
      , "systemMemoryBytes" .= tuningRequestSystemMemoryBytes request
      , "minecraftVersion" .= tuningRequestMinecraftVersion request
      , "javaMajorVersion" .= tuningRequestJavaMajorVersion request
      , "loader" .= tuningRequestLoader request
      , "modCount" .= tuningRequestModCount request
      , "resourcePackCount" .= tuningRequestResourcePackCount request
      , "shaderPackCount" .= tuningRequestShaderPackCount request
      , "packScale" .= tuningRequestPackScale request
      , "modpackIsLarge" .= tuningRequestModpackIsLarge request
      , "sawHeapOutOfMemory" .= tuningRequestSawHeapOutOfMemory request
      , "sawNativeOutOfMemory" .= tuningRequestSawNativeOutOfMemory request
      , "sawGcOverhead" .= tuningRequestSawGcOverhead request
      , "lastExitCode" .= tuningRequestLastExitCode request
      , "customMemoryMb" .= tuningRequestCustomMemoryMb request
      , "customJvmArgs" .= tuningRequestCustomJvmArgs request
      ]

data ResolvedJvmTuning = ResolvedJvmTuning
  { resolvedTuningRequestedPolicy :: JvmTuningPolicy
  , resolvedTuningEffectivePolicy :: JvmTuningPolicy
  , resolvedTuningMemoryPolicy :: MemoryPolicy
  , resolvedTuningPackScale :: PackScale
  , resolvedTuningSystemMemoryMb :: Maybe Int
  , resolvedTuningRecommendedMemoryMb :: Int
  , resolvedTuningXmsMb :: Int
  , resolvedTuningXmxMb :: Int
  , resolvedTuningJvmArgs :: [Text]
  , resolvedTuningProfileName :: Text
  , resolvedTuningSummary :: Text
  , resolvedTuningConfidence :: PerformanceConfidence
  , resolvedTuningEvidence :: [PerformanceEvidence]
  , resolvedTuningRollbackRef :: Maybe Text
  , resolvedTuningApplyMode :: AdaptiveApplyMode
  , resolvedTuningWarnings :: [JvmTuningWarning]
  , resolvedTuningActions :: [JvmTuningAction]
  , resolvedTuningPrimaryAction :: Maybe JvmTuningAction
  , resolvedTuningCanRollback :: Bool
  } deriving (Eq, Show)

instance ToJSON ResolvedJvmTuning where
  toJSON resolved =
    object
      [ "requestedPolicy" .= resolvedTuningRequestedPolicy resolved
      , "effectivePolicy" .= resolvedTuningEffectivePolicy resolved
      , "memoryPolicy" .= resolvedTuningMemoryPolicy resolved
      , "packScale" .= resolvedTuningPackScale resolved
      , "systemMemoryMb" .= resolvedTuningSystemMemoryMb resolved
      , "recommendedMemoryMb" .= resolvedTuningRecommendedMemoryMb resolved
      , "xmsMb" .= resolvedTuningXmsMb resolved
      , "xmxMb" .= resolvedTuningXmxMb resolved
      , "jvmArgs" .= resolvedTuningJvmArgs resolved
      , "profileName" .= resolvedTuningProfileName resolved
      , "summary" .= resolvedTuningSummary resolved
      , "confidence" .= resolvedTuningConfidence resolved
      , "evidence" .= resolvedTuningEvidence resolved
      , "rollbackRef" .= resolvedTuningRollbackRef resolved
      , "applyMode" .= resolvedTuningApplyMode resolved
      , "warnings" .= resolvedTuningWarnings resolved
      , "actions" .= resolvedTuningActions resolved
      , "primaryAction" .= resolvedTuningPrimaryAction resolved
      , "canRollback" .= resolvedTuningCanRollback resolved
      ]

instance FromJSON ResolvedJvmTuning where
  parseJSON =
    withObject "ResolvedJvmTuning" $ \obj ->
      ResolvedJvmTuning
        <$> obj .:? "requestedPolicy" .!= JvmTuningAuto
        <*> obj .:? "effectivePolicy" .!= JvmTuningAuto
        <*> obj .:? "memoryPolicy" .!= MemoryPolicyAuto
        <*> obj .:? "packScale" .!= PackScaleUnknown
        <*> obj .:? "systemMemoryMb"
        <*> obj .:? "recommendedMemoryMb" .!= 4096
        <*> obj .:? "xmsMb" .!= 512
        <*> obj .:? "xmxMb" .!= 4096
        <*> obj .:? "jvmArgs" .!= []
        <*> obj .:? "profileName" .!= "Automatic Recommendation"
        <*> obj .:? "summary" .!= ""
        <*> obj .:? "confidence" .!= ConfidenceEstimated
        <*> obj .:? "evidence" .!= []
        <*> obj .:? "rollbackRef"
        <*> obj .:? "applyMode" .!= ApplyAsk
        <*> obj .:? "warnings" .!= []
        <*> obj .:? "actions" .!= []
        <*> obj .:? "primaryAction"
        <*> obj .:? "canRollback" .!= False

defaultJvmTuningRequest :: JvmTuningRequest
defaultJvmTuningRequest =
  JvmTuningRequest
    { tuningRequestInstanceId = Nothing
    , tuningRequestGameDir = Nothing
    , tuningRequestPolicy = JvmTuningAuto
    , tuningRequestMemoryPolicy = MemoryPolicyAuto
    , tuningRequestSystemMemoryBytes = Nothing
    , tuningRequestMinecraftVersion = Nothing
    , tuningRequestJavaMajorVersion = Nothing
    , tuningRequestLoader = Nothing
    , tuningRequestModCount = Nothing
    , tuningRequestResourcePackCount = Nothing
    , tuningRequestShaderPackCount = Nothing
    , tuningRequestPackScale = Nothing
    , tuningRequestModpackIsLarge = False
    , tuningRequestSawHeapOutOfMemory = False
    , tuningRequestSawNativeOutOfMemory = False
    , tuningRequestSawGcOverhead = False
    , tuningRequestLastExitCode = Nothing
    , tuningRequestCustomMemoryMb = Nothing
    , tuningRequestCustomJvmArgs = []
    }

data JvmTuningApplyRequest = JvmTuningApplyRequest
  { applyTuningScope :: Text
  , applyTuningInstanceId :: Maybe Text
  , applyTuningRequest :: JvmTuningRequest
  } deriving (Eq, Show)

instance FromJSON JvmTuningApplyRequest where
  parseJSON =
    withObject "JvmTuningApplyRequest" $ \obj ->
      JvmTuningApplyRequest
        <$> obj .:? "scope" .!= "instance"
        <*> obj .:? "instanceId"
        <*> obj .: "tuning"

data JvmTuningApplyResponse = JvmTuningApplyResponse
  { applyResponseScope :: Text
  , applyResponseInstanceId :: Maybe Text
  , applyResponsePersistence :: Text
  , applyResponseTuning :: ResolvedJvmTuning
  } deriving (Eq, Show)

instance ToJSON JvmTuningApplyResponse where
  toJSON response =
    object
      [ "scope" .= applyResponseScope response
      , "instanceId" .= applyResponseInstanceId response
      , "persistence" .= applyResponsePersistence response
      , "tuning" .= applyResponseTuning response
      , "patch" .= object
          [ "memoryPolicy" .= ("custom" :: Text)
          , "jvmProfile" .= resolvedTuningEffectivePolicy (applyResponseTuning response)
          , "memoryMb" .= resolvedTuningXmxMb (applyResponseTuning response)
          , "customMemoryMb" .= resolvedTuningXmxMb (applyResponseTuning response)
          , "customJvmArgs" .= resolvedTuningJvmArgs (applyResponseTuning response)
          ]
      ]

normalizedIdentifier :: Text -> Text
normalizedIdentifier =
  Text.toLower . Text.filter isAlphaNum
