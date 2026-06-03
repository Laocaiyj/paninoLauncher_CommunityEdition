{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.Profile.Types
  ( AdaptiveApplyMode(..)
  , InstanceFingerprint(..)
  , PerformanceConfidence(..)
  , PerformanceEvidence(..)
  , PerformanceKnobs(..)
  , PerformanceProfile(..)
  , PerformanceProfileSource(..)
  , PerformanceRecommendation(..)
  , ProfileKind(..)
  , defaultInstanceFingerprint
  , defaultPerformanceKnobs
  , estimatedEvidence
  , performanceConfidenceText
  , performanceRoot
  , profileKindText
  , profileRollbackRef
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
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import System.FilePath ((</>))

data PerformanceConfidence
  = ConfidenceEstimated
  | ConfidenceMeasuredOnce
  | ConfidenceMeasuredStable
  | ConfidenceExperimentWon
  | ConfidenceBlocked
  deriving (Eq, Ord, Show)

performanceConfidenceText :: PerformanceConfidence -> Text
performanceConfidenceText confidence =
  case confidence of
    ConfidenceEstimated -> "estimated"
    ConfidenceMeasuredOnce -> "measured_once"
    ConfidenceMeasuredStable -> "measured_stable"
    ConfidenceExperimentWon -> "experiment_won"
    ConfidenceBlocked -> "blocked"

parsePerformanceConfidence :: Text -> PerformanceConfidence
parsePerformanceConfidence raw =
  case normalized raw of
    "estimated" -> ConfidenceEstimated
    "measuredonce" -> ConfidenceMeasuredOnce
    "measuredstable" -> ConfidenceMeasuredStable
    "experimentwon" -> ConfidenceExperimentWon
    "blocked" -> ConfidenceBlocked
    _ -> ConfidenceEstimated

instance ToJSON PerformanceConfidence where
  toJSON =
    toJSON . performanceConfidenceText

instance FromJSON PerformanceConfidence where
  parseJSON =
    withText "PerformanceConfidence" (pure . parsePerformanceConfidence)

data PerformanceEvidence = PerformanceEvidence
  { evidenceKey :: Text
  , evidenceValue :: Text
  , evidenceSource :: Text
  } deriving (Eq, Show)

instance ToJSON PerformanceEvidence where
  toJSON evidence =
    object
      [ "key" .= evidenceKey evidence
      , "value" .= evidenceValue evidence
      , "source" .= evidenceSource evidence
      ]

instance FromJSON PerformanceEvidence where
  parseJSON =
    withObject "PerformanceEvidence" $ \obj ->
      PerformanceEvidence
        <$> obj .:? "key" .!= ""
        <*> obj .:? "value" .!= ""
        <*> obj .:? "source" .!= "core"

data AdaptiveApplyMode
  = ApplyAutomatic
  | ApplyAsk
  | ApplyNever
  deriving (Eq, Show)

instance ToJSON AdaptiveApplyMode where
  toJSON mode =
    toJSON $
      case mode of
        ApplyAutomatic -> "automatic" :: Text
        ApplyAsk -> "ask"
        ApplyNever -> "never"

instance FromJSON AdaptiveApplyMode where
  parseJSON =
    withText "AdaptiveApplyMode" $ \raw ->
      pure $
        case normalized raw of
          "automatic" -> ApplyAutomatic
          "auto" -> ApplyAutomatic
          "never" -> ApplyNever
          _ -> ApplyAsk

data InstanceFingerprint = InstanceFingerprint
  { fingerprintMinecraftVersion :: Maybe Text
  , fingerprintJavaRequirement :: Maybe Text
  , fingerprintLoaderFamily :: Maybe Text
  , fingerprintLoaderVersion :: Maybe Text
  , fingerprintRendererCapability :: Maybe Text
  , fingerprintModCount :: Maybe Int
  , fingerprintShaderLoader :: Maybe Text
  , fingerprintActiveShaderPackHash :: Maybe Text
  , fingerprintResourcePackScale :: Maybe Text
  , fingerprintLockfileFingerprint :: Maybe Text
  , fingerprintWorldTypeHint :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON InstanceFingerprint where
  toJSON fingerprint =
    object
      [ "minecraftVersion" .= fingerprintMinecraftVersion fingerprint
      , "javaRequirement" .= fingerprintJavaRequirement fingerprint
      , "loaderFamily" .= fingerprintLoaderFamily fingerprint
      , "loaderVersion" .= fingerprintLoaderVersion fingerprint
      , "rendererCapability" .= fingerprintRendererCapability fingerprint
      , "modCount" .= fingerprintModCount fingerprint
      , "shaderLoader" .= fingerprintShaderLoader fingerprint
      , "activeShaderPackHash" .= fingerprintActiveShaderPackHash fingerprint
      , "resourcePackScale" .= fingerprintResourcePackScale fingerprint
      , "lockfileFingerprint" .= fingerprintLockfileFingerprint fingerprint
      , "worldTypeHint" .= fingerprintWorldTypeHint fingerprint
      ]

instance FromJSON InstanceFingerprint where
  parseJSON =
    withObject "InstanceFingerprint" $ \obj ->
      InstanceFingerprint
        <$> obj .:? "minecraftVersion"
        <*> obj .:? "javaRequirement"
        <*> obj .:? "loaderFamily"
        <*> obj .:? "loaderVersion"
        <*> obj .:? "rendererCapability"
        <*> obj .:? "modCount"
        <*> obj .:? "shaderLoader"
        <*> obj .:? "activeShaderPackHash"
        <*> obj .:? "resourcePackScale"
        <*> obj .:? "lockfileFingerprint"
        <*> obj .:? "worldTypeHint"

defaultInstanceFingerprint :: InstanceFingerprint
defaultInstanceFingerprint =
  InstanceFingerprint
    { fingerprintMinecraftVersion = Nothing
    , fingerprintJavaRequirement = Nothing
    , fingerprintLoaderFamily = Nothing
    , fingerprintLoaderVersion = Nothing
    , fingerprintRendererCapability = Just "unknown"
    , fingerprintModCount = Nothing
    , fingerprintShaderLoader = Nothing
    , fingerprintActiveShaderPackHash = Nothing
    , fingerprintResourcePackScale = Nothing
    , fingerprintLockfileFingerprint = Nothing
    , fingerprintWorldTypeHint = Nothing
    }

data PerformanceKnobs = PerformanceKnobs
  { knobHeapMaxMb :: Maybe Int
  , knobHeapInitialPolicy :: Maybe Text
  , knobGcPolicy :: Maybe Text
  , knobRenderDistance :: Maybe Int
  , knobSimulationDistance :: Maybe Int
  , knobMaxFps :: Maybe Int
  , knobVsyncPolicy :: Maybe Text
  , knobParticles :: Maybe Text
  , knobClouds :: Maybe Text
  , knobEntityDistanceScaling :: Maybe Text
  , knobPerformancePackSet :: [Text]
  } deriving (Eq, Show)

instance ToJSON PerformanceKnobs where
  toJSON knobs =
    object
      [ "heapMaxMb" .= knobHeapMaxMb knobs
      , "heapInitialPolicy" .= knobHeapInitialPolicy knobs
      , "gcPolicy" .= knobGcPolicy knobs
      , "renderDistance" .= knobRenderDistance knobs
      , "simulationDistance" .= knobSimulationDistance knobs
      , "maxFps" .= knobMaxFps knobs
      , "vsyncPolicy" .= knobVsyncPolicy knobs
      , "particles" .= knobParticles knobs
      , "clouds" .= knobClouds knobs
      , "entityDistanceScaling" .= knobEntityDistanceScaling knobs
      , "performancePackSet" .= knobPerformancePackSet knobs
      ]

instance FromJSON PerformanceKnobs where
  parseJSON =
    withObject "PerformanceKnobs" $ \obj ->
      PerformanceKnobs
        <$> obj .:? "heapMaxMb"
        <*> obj .:? "heapInitialPolicy"
        <*> obj .:? "gcPolicy"
        <*> obj .:? "renderDistance"
        <*> obj .:? "simulationDistance"
        <*> obj .:? "maxFps"
        <*> obj .:? "vsyncPolicy"
        <*> obj .:? "particles"
        <*> obj .:? "clouds"
        <*> obj .:? "entityDistanceScaling"
        <*> obj .:? "performancePackSet" .!= []

defaultPerformanceKnobs :: PerformanceKnobs
defaultPerformanceKnobs =
  PerformanceKnobs
    { knobHeapMaxMb = Nothing
    , knobHeapInitialPolicy = Just "adaptive"
    , knobGcPolicy = Just "default"
    , knobRenderDistance = Nothing
    , knobSimulationDistance = Nothing
    , knobMaxFps = Nothing
    , knobVsyncPolicy = Just "keep"
    , knobParticles = Nothing
    , knobClouds = Nothing
    , knobEntityDistanceScaling = Nothing
    , knobPerformancePackSet = []
    }

data ProfileKind
  = ProfileBaseline
  | ProfileCandidate
  | ProfileUserOverride
  deriving (Eq, Show)

profileKindText :: ProfileKind -> Text
profileKindText kind =
  case kind of
    ProfileBaseline -> "baseline"
    ProfileCandidate -> "candidate"
    ProfileUserOverride -> "userOverride"

instance ToJSON ProfileKind where
  toJSON =
    toJSON . profileKindText

instance FromJSON ProfileKind where
  parseJSON =
    withText "ProfileKind" $ \raw ->
      pure $
        case normalized raw of
          "candidate" -> ProfileCandidate
          "useroverride" -> ProfileUserOverride
          _ -> ProfileBaseline

data PerformanceProfileSource
  = ProfileSourceStaticBaseline
  | ProfileSourceMeasuredHistory
  | ProfileSourceExperiment
  | ProfileSourceUserOverride
  deriving (Eq, Show)

instance ToJSON PerformanceProfileSource where
  toJSON source =
    toJSON $
      case source of
        ProfileSourceStaticBaseline -> "staticBaseline" :: Text
        ProfileSourceMeasuredHistory -> "measuredHistory"
        ProfileSourceExperiment -> "experiment"
        ProfileSourceUserOverride -> "userOverride"

instance FromJSON PerformanceProfileSource where
  parseJSON =
    withText "PerformanceProfileSource" $ \raw ->
      pure $
        case normalized raw of
          "measuredhistory" -> ProfileSourceMeasuredHistory
          "experiment" -> ProfileSourceExperiment
          "useroverride" -> ProfileSourceUserOverride
          _ -> ProfileSourceStaticBaseline

data PerformanceProfile = PerformanceProfile
  { profileId :: Text
  , profileKind :: ProfileKind
  , profileSource :: PerformanceProfileSource
  , profileInstanceFingerprint :: InstanceFingerprint
  , profileKnobs :: PerformanceKnobs
  , profileConfidence :: PerformanceConfidence
  , profileEvidence :: [PerformanceEvidence]
  , profileRollbackRef :: Maybe Text
  , profileCooldownUntil :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON PerformanceProfile where
  toJSON profile =
    object
      [ "profileId" .= profileId profile
      , "profileKind" .= profileKind profile
      , "source" .= profileSource profile
      , "instanceFingerprint" .= profileInstanceFingerprint profile
      , "knobs" .= profileKnobs profile
      , "confidence" .= profileConfidence profile
      , "evidence" .= profileEvidence profile
      , "rollbackRef" .= profileRollbackRef profile
      , "cooldownUntil" .= profileCooldownUntil profile
      ]

instance FromJSON PerformanceProfile where
  parseJSON =
    withObject "PerformanceProfile" $ \obj ->
      PerformanceProfile
        <$> obj .:? "profileId" .!= ""
        <*> obj .:? "profileKind" .!= ProfileBaseline
        <*> obj .:? "source" .!= ProfileSourceStaticBaseline
        <*> obj .:? "instanceFingerprint" .!= defaultInstanceFingerprint
        <*> obj .:? "knobs" .!= defaultPerformanceKnobs
        <*> obj .:? "confidence" .!= ConfidenceEstimated
        <*> obj .:? "evidence" .!= []
        <*> obj .:? "rollbackRef"
        <*> obj .:? "cooldownUntil"

data PerformanceRecommendation = PerformanceRecommendation
  { recommendationProfileId :: Text
  , recommendationConfidence :: PerformanceConfidence
  , recommendationEvidence :: [PerformanceEvidence]
  , recommendationObjectiveScore :: Maybe Double
  , recommendationWarnings :: [Text]
  , recommendationActions :: [Text]
  , recommendationRollbackRef :: Maybe Text
  , recommendationDiagnosticPaths :: [FilePath]
  , recommendationBaseline :: PerformanceProfile
  , recommendationCandidate :: Maybe PerformanceProfile
  } deriving (Eq, Show)

instance ToJSON PerformanceRecommendation where
  toJSON recommendation =
    object
      [ "profileId" .= recommendationProfileId recommendation
      , "confidence" .= recommendationConfidence recommendation
      , "evidence" .= recommendationEvidence recommendation
      , "objectiveScore" .= recommendationObjectiveScore recommendation
      , "warnings" .= recommendationWarnings recommendation
      , "actions" .= recommendationActions recommendation
      , "rollbackRef" .= recommendationRollbackRef recommendation
      , "diagnosticPaths" .= recommendationDiagnosticPaths recommendation
      , "baseline" .= recommendationBaseline recommendation
      , "candidate" .= recommendationCandidate recommendation
      ]

estimatedEvidence :: Text -> Text -> PerformanceEvidence
estimatedEvidence key value =
  PerformanceEvidence
    { evidenceKey = key
    , evidenceValue = value
    , evidenceSource = "estimated-baseline"
    }

performanceRoot :: FilePath -> FilePath
performanceRoot gameDir =
  gameDir </> ".panino" </> "performance"

normalized :: Text -> Text
normalized =
  Text.toLower . Text.filter isAlphaNum
