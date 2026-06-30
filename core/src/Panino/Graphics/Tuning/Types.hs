{-# LANGUAGE OverloadedStrings #-}

module Panino.Graphics.Tuning.Types
  ( GraphicsHardwareTier(..)
  , GraphicsOptionOverride
  , GraphicsTuningAction(..)
  , GraphicsTuningProfile(..)
  , GraphicsTuningRequest(..)
  , GraphicsTuningWarning(..)
  , OptionsBackup(..)
  , OptionsPatch(..)
  , OptionsPatchChange(..)
  , RetinaPolicy(..)
  , ResolvedGraphicsTuning(..)
  , defaultGraphicsTuningRequest
  , graphicsRequestGameDirPath
  , inferGraphicsHardwareTier
  , parseGraphicsHardwareTier
  , parseGraphicsTuningProfile
  , parseRetinaPolicy
  , renderGraphicsHardwareTier
  , renderGraphicsTuningProfile
  , renderRetinaPolicy
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , withText
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Char (isAlphaNum)
import Data.Map.Strict (Map)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Performance.Profile.Types
  ( AdaptiveApplyMode(..)
  , PerformanceConfidence(..)
  , PerformanceEvidence
  )
import Panino.Core.Types
  ( GameDir
  , gameDirFromPath
  , gameDirPath
  )

data GraphicsTuningProfile
  = GraphicsProfileClarity
  | GraphicsProfileBalanced
  | GraphicsProfilePerformance
  | GraphicsProfileBatterySaver
  | GraphicsProfileManual
  deriving (Eq, Show)

renderGraphicsTuningProfile :: GraphicsTuningProfile -> Text
renderGraphicsTuningProfile profile =
  case profile of
    GraphicsProfileClarity -> "clarity"
    GraphicsProfileBalanced -> "balanced"
    GraphicsProfilePerformance -> "performance"
    GraphicsProfileBatterySaver -> "batterySaver"
    GraphicsProfileManual -> "manual"

parseGraphicsTuningProfile :: Text -> Maybe GraphicsTuningProfile
parseGraphicsTuningProfile raw =
  case normalizedIdentifier raw of
    "clarity" -> Just GraphicsProfileClarity
    "quality" -> Just GraphicsProfileClarity
    "retinaquality" -> Just GraphicsProfileClarity
    "balanced" -> Just GraphicsProfileBalanced
    "balancedretina" -> Just GraphicsProfileBalanced
    "auto" -> Just GraphicsProfileBalanced
    "performance" -> Just GraphicsProfilePerformance
    "performancescale" -> Just GraphicsProfilePerformance
    "smooth" -> Just GraphicsProfilePerformance
    "batterysaver" -> Just GraphicsProfileBatterySaver
    "battery" -> Just GraphicsProfileBatterySaver
    "manual" -> Just GraphicsProfileManual
    "custom" -> Just GraphicsProfileManual
    _ -> Nothing

instance ToJSON GraphicsTuningProfile where
  toJSON =
    toJSON . renderGraphicsTuningProfile

instance FromJSON GraphicsTuningProfile where
  parseJSON =
    withText "GraphicsTuningProfile" $ \raw ->
      case parseGraphicsTuningProfile raw of
        Just profile -> pure profile
        Nothing -> fail ("unknown graphics tuning profile: " <> Text.unpack raw)

data GraphicsHardwareTier
  = GraphicsHardwareMBase
  | GraphicsHardwareMPro
  | GraphicsHardwareMMaxUltra
  | GraphicsHardwareUnknown
  deriving (Eq, Show)

renderGraphicsHardwareTier :: GraphicsHardwareTier -> Text
renderGraphicsHardwareTier tier =
  case tier of
    GraphicsHardwareMBase -> "mBase"
    GraphicsHardwareMPro -> "mPro"
    GraphicsHardwareMMaxUltra -> "mMaxUltra"
    GraphicsHardwareUnknown -> "unknown"

parseGraphicsHardwareTier :: Text -> Maybe GraphicsHardwareTier
parseGraphicsHardwareTier raw =
  case normalizedIdentifier raw of
    "mbase" -> Just GraphicsHardwareMBase
    "base" -> Just GraphicsHardwareMBase
    "m" -> Just GraphicsHardwareMBase
    "mpro" -> Just GraphicsHardwareMPro
    "pro" -> Just GraphicsHardwareMPro
    "mmax" -> Just GraphicsHardwareMMaxUltra
    "max" -> Just GraphicsHardwareMMaxUltra
    "multra" -> Just GraphicsHardwareMMaxUltra
    "ultra" -> Just GraphicsHardwareMMaxUltra
    "mmaxultra" -> Just GraphicsHardwareMMaxUltra
    "unknown" -> Just GraphicsHardwareUnknown
    _ -> Nothing

inferGraphicsHardwareTier :: Maybe Text -> GraphicsHardwareTier
inferGraphicsHardwareTier Nothing = GraphicsHardwareUnknown
inferGraphicsHardwareTier (Just raw)
  | any (`Text.isInfixOf` normalized) ["ultra", "max"] = GraphicsHardwareMMaxUltra
  | "pro" `Text.isInfixOf` normalized = GraphicsHardwareMPro
  | "applem" `Text.isInfixOf` normalized || "m1" `Text.isInfixOf` normalized || "m2" `Text.isInfixOf` normalized || "m3" `Text.isInfixOf` normalized || "m4" `Text.isInfixOf` normalized = GraphicsHardwareMBase
  | otherwise = GraphicsHardwareUnknown
  where
    normalized =
      Text.toLower raw

instance ToJSON GraphicsHardwareTier where
  toJSON =
    toJSON . renderGraphicsHardwareTier

instance FromJSON GraphicsHardwareTier where
  parseJSON =
    withText "GraphicsHardwareTier" $ \raw ->
      case parseGraphicsHardwareTier raw of
        Just tier -> pure tier
        Nothing -> fail ("unknown graphics hardware tier: " <> Text.unpack raw)

data RetinaPolicy
  = RetinaQuality
  | BalancedRetina
  | PerformanceScale
  | RetinaPolicyUnsupported
  deriving (Eq, Show)

renderRetinaPolicy :: RetinaPolicy -> Text
renderRetinaPolicy policy =
  case policy of
    RetinaQuality -> "retinaQuality"
    BalancedRetina -> "balancedRetina"
    PerformanceScale -> "performanceScale"
    RetinaPolicyUnsupported -> "unsupported"

parseRetinaPolicy :: Text -> Maybe RetinaPolicy
parseRetinaPolicy raw =
  case normalizedIdentifier raw of
    "retinaquality" -> Just RetinaQuality
    "quality" -> Just RetinaQuality
    "balancedretina" -> Just BalancedRetina
    "balanced" -> Just BalancedRetina
    "performancescale" -> Just PerformanceScale
    "performance" -> Just PerformanceScale
    "unsupported" -> Just RetinaPolicyUnsupported
    _ -> Nothing

instance ToJSON RetinaPolicy where
  toJSON =
    toJSON . renderRetinaPolicy

instance FromJSON RetinaPolicy where
  parseJSON =
    withText "RetinaPolicy" $ \raw ->
      case parseRetinaPolicy raw of
        Just policy -> pure policy
        Nothing -> fail ("unknown retina policy: " <> Text.unpack raw)

data GraphicsTuningWarning = GraphicsTuningWarning
  { graphicsWarningCode :: Text
  , graphicsWarningSeverity :: Text
  , graphicsWarningMessage :: Text
  , graphicsWarningAction :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON GraphicsTuningWarning where
  toJSON warning =
    object
      [ "code" .= graphicsWarningCode warning
      , "severity" .= graphicsWarningSeverity warning
      , "message" .= graphicsWarningMessage warning
      , "action" .= graphicsWarningAction warning
      ]

instance FromJSON GraphicsTuningWarning where
  parseJSON =
    withObject "GraphicsTuningWarning" $ \obj ->
      GraphicsTuningWarning
        <$> obj .:? "code" .!= "warning"
        <*> obj .:? "severity" .!= "warning"
        <*> obj .:? "message" .!= ""
        <*> obj .:? "action"

data GraphicsTuningAction = GraphicsTuningAction
  { graphicsActionId :: Text
  , graphicsActionTitle :: Text
  , graphicsActionOptions :: Map Text Text
  } deriving (Eq, Show)

instance ToJSON GraphicsTuningAction where
  toJSON action =
    object
      [ "id" .= graphicsActionId action
      , "title" .= graphicsActionTitle action
      , "options" .= graphicsActionOptions action
      ]

instance FromJSON GraphicsTuningAction where
  parseJSON =
    withObject "GraphicsTuningAction" $ \obj ->
      GraphicsTuningAction
        <$> obj .:? "id" .!= ""
        <*> obj .:? "title" .!= ""
        <*> obj .:? "options" .!= mempty

data OptionsPatchChange = OptionsPatchChange
  { optionsPatchChangeKey :: Text
  , optionsPatchChangeOldValue :: Maybe Text
  , optionsPatchChangeNewValue :: Maybe Text
  , optionsPatchChangeReason :: Text
  , optionsPatchChangeStatus :: Text
  } deriving (Eq, Show)

instance ToJSON OptionsPatchChange where
  toJSON change =
    object
      [ "key" .= optionsPatchChangeKey change
      , "oldValue" .= optionsPatchChangeOldValue change
      , "newValue" .= optionsPatchChangeNewValue change
      , "reason" .= optionsPatchChangeReason change
      , "status" .= optionsPatchChangeStatus change
      ]

instance FromJSON OptionsPatchChange where
  parseJSON =
    withObject "OptionsPatchChange" $ \obj ->
      OptionsPatchChange
        <$> obj .:? "key" .!= ""
        <*> obj .:? "oldValue"
        <*> obj .:? "newValue"
        <*> obj .:? "reason" .!= ""
        <*> obj .:? "status" .!= "change"

data OptionsPatch = OptionsPatch
  { optionsPatchPath :: Maybe FilePath
  , optionsPatchChanges :: [OptionsPatchChange]
  } deriving (Eq, Show)

instance ToJSON OptionsPatch where
  toJSON patch =
    object
      [ "path" .= optionsPatchPath patch
      , "changes" .= optionsPatchChanges patch
      ]

instance FromJSON OptionsPatch where
  parseJSON =
    withObject "OptionsPatch" $ \obj ->
      OptionsPatch
        <$> obj .:? "path"
        <*> obj .:? "changes" .!= []

data OptionsBackup = OptionsBackup
  { optionsBackupSourcePath :: FilePath
  , optionsBackupStablePath :: Maybe FilePath
  , optionsBackupTimestampPath :: Maybe FilePath
  , optionsBackupCreated :: Bool
  , optionsBackupError :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON OptionsBackup where
  toJSON backup =
    object
      [ "sourcePath" .= optionsBackupSourcePath backup
      , "stablePath" .= optionsBackupStablePath backup
      , "timestampPath" .= optionsBackupTimestampPath backup
      , "created" .= optionsBackupCreated backup
      , "error" .= optionsBackupError backup
      ]

instance FromJSON OptionsBackup where
  parseJSON =
    withObject "OptionsBackup" $ \obj ->
      OptionsBackup
        <$> obj .:? "sourcePath" .!= ""
        <*> obj .:? "stablePath"
        <*> obj .:? "timestampPath"
        <*> obj .:? "created" .!= False
        <*> obj .:? "error"

type GraphicsOptionOverride = Map Text Text

data GraphicsTuningRequest = GraphicsTuningRequest
  { graphicsRequestInstanceId :: Maybe Text
  , graphicsRequestGameDir :: Maybe GameDir
  , graphicsRequestMinecraftVersion :: Maybe Text
  , graphicsRequestLoader :: Maybe Text
  , graphicsRequestHardwareTier :: GraphicsHardwareTier
  , graphicsRequestDisplayScale :: Maybe Double
  , graphicsRequestDisplayWidth :: Maybe Int
  , graphicsRequestDisplayHeight :: Maybe Int
  , graphicsRequestRefreshRate :: Maybe Int
  , graphicsRequestIsBuiltinDisplay :: Maybe Bool
  , graphicsRequestPowerMode :: Maybe Text
  , graphicsRequestProfile :: GraphicsTuningProfile
  , graphicsRequestShaderEnabled :: Bool
  , graphicsRequestResourcePackScale :: Maybe Text
  , graphicsRequestModCount :: Maybe Int
  , graphicsRequestPreviousSnapshot :: Maybe ResolvedGraphicsTuning
  , graphicsRequestManualOverrides :: GraphicsOptionOverride
  , graphicsRequestDryRun :: Bool
  } deriving (Eq, Show)

instance FromJSON GraphicsTuningRequest where
  parseJSON =
    withObject "GraphicsTuningRequest" $ \obj ->
      GraphicsTuningRequest
        <$> obj .:? "instanceId"
        <*> (obj .:? "gameDir" >>= pure . (>>= gameDirFromPath))
        <*> obj .:? "minecraftVersion"
        <*> obj .:? "loader"
        <*> obj .:? "hardwareTier" .!= GraphicsHardwareUnknown
        <*> obj .:? "displayScale"
        <*> obj .:? "displayWidth"
        <*> obj .:? "displayHeight"
        <*> obj .:? "refreshRate"
        <*> obj .:? "isBuiltinDisplay"
        <*> obj .:? "powerMode"
        <*> obj .:? "requestedProfile" .!= GraphicsProfileBalanced
        <*> obj .:? "shaderEnabled" .!= False
        <*> obj .:? "resourcePackScale"
        <*> obj .:? "modCount"
        <*> obj .:? "previousSnapshot"
        <*> obj .:? "manualOverrides" .!= mempty
        <*> obj .:? "dryRun" .!= True

instance ToJSON GraphicsTuningRequest where
  toJSON request =
    object
      [ "instanceId" .= graphicsRequestInstanceId request
      , "gameDir" .= graphicsRequestGameDir request
      , "minecraftVersion" .= graphicsRequestMinecraftVersion request
      , "loader" .= graphicsRequestLoader request
      , "hardwareTier" .= graphicsRequestHardwareTier request
      , "displayScale" .= graphicsRequestDisplayScale request
      , "displayWidth" .= graphicsRequestDisplayWidth request
      , "displayHeight" .= graphicsRequestDisplayHeight request
      , "refreshRate" .= graphicsRequestRefreshRate request
      , "isBuiltinDisplay" .= graphicsRequestIsBuiltinDisplay request
      , "powerMode" .= graphicsRequestPowerMode request
      , "requestedProfile" .= graphicsRequestProfile request
      , "shaderEnabled" .= graphicsRequestShaderEnabled request
      , "resourcePackScale" .= graphicsRequestResourcePackScale request
      , "modCount" .= graphicsRequestModCount request
      , "previousSnapshot" .= graphicsRequestPreviousSnapshot request
      , "manualOverrides" .= graphicsRequestManualOverrides request
      , "dryRun" .= graphicsRequestDryRun request
      ]

data ResolvedGraphicsTuning = ResolvedGraphicsTuning
  { resolvedGraphicsRequestedProfile :: GraphicsTuningProfile
  , resolvedGraphicsEffectiveProfile :: GraphicsTuningProfile
  , resolvedGraphicsHardwareTier :: GraphicsHardwareTier
  , resolvedGraphicsRetinaPolicy :: RetinaPolicy
  , resolvedGraphicsCurrentOptions :: Map Text Text
  , resolvedGraphicsRecommendedOptions :: Map Text Text
  , resolvedGraphicsOptionsPatch :: OptionsPatch
  , resolvedGraphicsSummary :: Text
  , resolvedGraphicsConfidence :: PerformanceConfidence
  , resolvedGraphicsEvidence :: [PerformanceEvidence]
  , resolvedGraphicsRollbackRef :: Maybe Text
  , resolvedGraphicsApplyMode :: AdaptiveApplyMode
  , resolvedGraphicsWarnings :: [GraphicsTuningWarning]
  , resolvedGraphicsActions :: [GraphicsTuningAction]
  , resolvedGraphicsPrimaryAction :: Maybe GraphicsTuningAction
  , resolvedGraphicsBackupPath :: Maybe FilePath
  , resolvedGraphicsCanApply :: Bool
  , resolvedGraphicsCanRollback :: Bool
  } deriving (Eq, Show)

instance ToJSON ResolvedGraphicsTuning where
  toJSON resolved =
    object
      [ "requestedProfile" .= resolvedGraphicsRequestedProfile resolved
      , "effectiveProfile" .= resolvedGraphicsEffectiveProfile resolved
      , "hardwareTier" .= resolvedGraphicsHardwareTier resolved
      , "retinaPolicy" .= resolvedGraphicsRetinaPolicy resolved
      , "currentOptions" .= resolvedGraphicsCurrentOptions resolved
      , "recommendedOptions" .= resolvedGraphicsRecommendedOptions resolved
      , "optionsPatch" .= resolvedGraphicsOptionsPatch resolved
      , "summary" .= resolvedGraphicsSummary resolved
      , "confidence" .= resolvedGraphicsConfidence resolved
      , "evidence" .= resolvedGraphicsEvidence resolved
      , "rollbackRef" .= resolvedGraphicsRollbackRef resolved
      , "applyMode" .= resolvedGraphicsApplyMode resolved
      , "warnings" .= resolvedGraphicsWarnings resolved
      , "actions" .= resolvedGraphicsActions resolved
      , "primaryAction" .= resolvedGraphicsPrimaryAction resolved
      , "backupPath" .= resolvedGraphicsBackupPath resolved
      , "canApply" .= resolvedGraphicsCanApply resolved
      , "canRollback" .= resolvedGraphicsCanRollback resolved
      ]

instance FromJSON ResolvedGraphicsTuning where
  parseJSON =
    withObject "ResolvedGraphicsTuning" $ \obj ->
      ResolvedGraphicsTuning
        <$> obj .:? "requestedProfile" .!= GraphicsProfileBalanced
        <*> obj .:? "effectiveProfile" .!= GraphicsProfileBalanced
        <*> obj .:? "hardwareTier" .!= GraphicsHardwareUnknown
        <*> obj .:? "retinaPolicy" .!= BalancedRetina
        <*> obj .:? "currentOptions" .!= mempty
        <*> obj .:? "recommendedOptions" .!= mempty
        <*> obj .:? "optionsPatch" .!= OptionsPatch Nothing []
        <*> obj .:? "summary" .!= ""
        <*> obj .:? "confidence" .!= ConfidenceEstimated
        <*> obj .:? "evidence" .!= []
        <*> obj .:? "rollbackRef"
        <*> obj .:? "applyMode" .!= ApplyAsk
        <*> obj .:? "warnings" .!= []
        <*> obj .:? "actions" .!= []
        <*> obj .:? "primaryAction"
        <*> obj .:? "backupPath"
        <*> obj .:? "canApply" .!= False
        <*> obj .:? "canRollback" .!= False

defaultGraphicsTuningRequest :: GraphicsTuningRequest
defaultGraphicsTuningRequest =
  GraphicsTuningRequest
    { graphicsRequestInstanceId = Nothing
    , graphicsRequestGameDir = Nothing
    , graphicsRequestMinecraftVersion = Nothing
    , graphicsRequestLoader = Nothing
    , graphicsRequestHardwareTier = GraphicsHardwareUnknown
    , graphicsRequestDisplayScale = Nothing
    , graphicsRequestDisplayWidth = Nothing
    , graphicsRequestDisplayHeight = Nothing
    , graphicsRequestRefreshRate = Nothing
    , graphicsRequestIsBuiltinDisplay = Nothing
    , graphicsRequestPowerMode = Nothing
    , graphicsRequestProfile = GraphicsProfileBalanced
    , graphicsRequestShaderEnabled = False
    , graphicsRequestResourcePackScale = Nothing
    , graphicsRequestModCount = Nothing
    , graphicsRequestPreviousSnapshot = Nothing
    , graphicsRequestManualOverrides = mempty
    , graphicsRequestDryRun = True
    }

graphicsRequestGameDirPath :: GraphicsTuningRequest -> Maybe FilePath
graphicsRequestGameDirPath =
  fmap gameDirPath . graphicsRequestGameDir

normalizedIdentifier :: Text -> Text
normalizedIdentifier =
  Text.toLower . Text.filter isAlphaNum
