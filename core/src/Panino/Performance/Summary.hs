{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.Summary
  ( PerformanceGraphicsSummary(..)
  , PerformanceJvmSummary(..)
  , PerformancePackSuggestion(..)
  , PerformancePrimaryAction(..)
  , PerformanceSummary(..)
  , performancePackSuggestion
  , recommendPerformanceSummary
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Control.Applicative ((<|>))
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Graphics.Tuning.Types
  ( GraphicsHardwareTier(..)
  , GraphicsTuningProfile
  , ResolvedGraphicsTuning(..)
  )
import Panino.Launch.Tuning.Types
  ( JvmTuningAction(..)
  , ResolvedJvmTuning(..)
  )
import Panino.Performance.Profile.Types
  ( PerformanceConfidence(..)
  , PerformanceEvidence(..)
  )
import Panino.Platform.Hardware
  ( HardwareProfile(..)
  )

data PerformanceSummary = PerformanceSummary
  { performanceSummaryStatus :: Text
  , performanceSummaryTitle :: Text
  , performanceSummaryDetail :: Text
  , performanceSummaryHardwareTier :: GraphicsHardwareTier
  , performanceSummaryHardwareLabel :: Text
  , performanceSummaryJvm :: PerformanceJvmSummary
  , performanceSummaryGraphics :: Maybe PerformanceGraphicsSummary
  , performanceSummaryPerformancePack :: PerformancePackSuggestion
  , performanceSummaryPrimaryAction :: PerformancePrimaryAction
  , performanceSummaryReasons :: [Text]
  , performanceSummaryConfidence :: PerformanceConfidence
  , performanceSummaryEvidence :: [PerformanceEvidence]
  , performanceSummaryRollbackRef :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON PerformanceSummary where
  toJSON summary =
    object
      [ "status" .= performanceSummaryStatus summary
      , "title" .= performanceSummaryTitle summary
      , "detail" .= performanceSummaryDetail summary
      , "hardwareTier" .= performanceSummaryHardwareTier summary
      , "hardwareLabel" .= performanceSummaryHardwareLabel summary
      , "jvm" .= performanceSummaryJvm summary
      , "graphics" .= performanceSummaryGraphics summary
      , "performancePack" .= performanceSummaryPerformancePack summary
      , "primaryAction" .= performanceSummaryPrimaryAction summary
      , "reasons" .= performanceSummaryReasons summary
      , "confidence" .= performanceSummaryConfidence summary
      , "evidence" .= performanceSummaryEvidence summary
      , "rollbackRef" .= performanceSummaryRollbackRef summary
      ]

data PerformanceJvmSummary = PerformanceJvmSummary
  { performanceJvmProfileName :: Text
  , performanceJvmMemoryMb :: Int
  , performanceJvmSummary :: Text
  } deriving (Eq, Show)

instance ToJSON PerformanceJvmSummary where
  toJSON summary =
    object
      [ "profileName" .= performanceJvmProfileName summary
      , "memoryMb" .= performanceJvmMemoryMb summary
      , "summary" .= performanceJvmSummary summary
      ]

data PerformanceGraphicsSummary = PerformanceGraphicsSummary
  { performanceGraphicsProfile :: GraphicsTuningProfile
  , performanceGraphicsRenderDistance :: Maybe Text
  , performanceGraphicsSimulationDistance :: Maybe Text
  , performanceGraphicsMaxFps :: Maybe Text
  , performanceGraphicsSummary :: Text
  , performanceGraphicsCanApply :: Bool
  } deriving (Eq, Show)

instance ToJSON PerformanceGraphicsSummary where
  toJSON summary =
    object
      [ "profile" .= performanceGraphicsProfile summary
      , "renderDistance" .= performanceGraphicsRenderDistance summary
      , "simulationDistance" .= performanceGraphicsSimulationDistance summary
      , "maxFps" .= performanceGraphicsMaxFps summary
      , "summary" .= performanceGraphicsSummary summary
      , "canApply" .= performanceGraphicsCanApply summary
      ]

data PerformancePackSuggestion = PerformancePackSuggestion
  { performancePackStatus :: Text
  , performancePackTitle :: Text
  , performancePackDetail :: Text
  , performancePackLoader :: Maybe Text
  , performancePackInstallAutomatically :: Bool
  } deriving (Eq, Show)

instance ToJSON PerformancePackSuggestion where
  toJSON suggestion =
    object
      [ "status" .= performancePackStatus suggestion
      , "title" .= performancePackTitle suggestion
      , "detail" .= performancePackDetail suggestion
      , "loader" .= performancePackLoader suggestion
      , "installAutomatically" .= performancePackInstallAutomatically suggestion
      ]

data PerformancePrimaryAction = PerformancePrimaryAction
  { performanceActionId :: Text
  , performanceActionTitle :: Text
  , performanceActionMemoryMb :: Maybe Int
  } deriving (Eq, Show)

instance ToJSON PerformancePrimaryAction where
  toJSON action =
    object
      [ "id" .= performanceActionId action
      , "title" .= performanceActionTitle action
      , "memoryMb" .= performanceActionMemoryMb action
      ]

recommendPerformanceSummary
  :: Maybe Text
  -> Maybe Int
  -> HardwareProfile
  -> ResolvedJvmTuning
  -> Maybe ResolvedGraphicsTuning
  -> PerformanceSummary
recommendPerformanceSummary loader _javaMajor hardware jvm graphics =
  PerformanceSummary
    { performanceSummaryStatus = status
    , performanceSummaryTitle = title
    , performanceSummaryDetail = detail
    , performanceSummaryHardwareTier = tier
    , performanceSummaryHardwareLabel = hardwareLabel
    , performanceSummaryJvm = jvmSummary
    , performanceSummaryGraphics = graphicsSummary
    , performanceSummaryPerformancePack = packSuggestion
    , performanceSummaryPrimaryAction = primaryAction
    , performanceSummaryReasons = reasons
    , performanceSummaryConfidence = summaryConfidence
    , performanceSummaryEvidence = summaryEvidence
    , performanceSummaryRollbackRef = resolvedTuningRollbackRef jvm <|> (graphics >>= resolvedGraphicsRollbackRef)
    }
  where
    tier = hardwareProfileChipTier hardware
    hardwareLabel = hardwareTierLabel tier
    packSuggestion = performancePackSuggestion loader
    jvmSummary =
      PerformanceJvmSummary
        { performanceJvmProfileName = resolvedTuningProfileName jvm
        , performanceJvmMemoryMb = resolvedTuningXmxMb jvm
        , performanceJvmSummary = resolvedTuningSummary jvm
        }
    graphicsSummary = performanceGraphicsSummaryFrom <$> graphics
    status =
      if actionNeedsUser primaryAction
        then "needsAction"
        else "ready"
    title =
      if actionNeedsUser primaryAction
        then "Panino has one recommended performance step"
        else "Ready for this Mac"
    detail =
      if actionNeedsUser primaryAction
        then "Apply the recommendation before launch; technical details stay in diagnostics."
        else "Automatic memory and graphics guidance is active for this instance."
    primaryAction =
      case resolvedTuningPrimaryAction jvm of
        Just action -> fromJvmAction action
        Nothing ->
          case graphics of
            Just resolved | resolvedGraphicsCanApply resolved ->
              PerformancePrimaryAction "applyGraphics" "Use recommended settings" Nothing
            _ | performancePackStatus packSuggestion == "recommended" ->
                PerformancePrimaryAction "installPerformancePack" "Install smoother pack" Nothing
              | otherwise ->
                PerformancePrimaryAction "viewDetails" "View details" Nothing
    reasons =
      [ "Panino chooses safe memory from this Mac and the instance size."
      , "Video settings are capped for Retina displays, heat, and unified memory."
      , "Performance packs are reviewed first; Panino will not install them silently."
      ]
    summaryConfidence =
      case graphics of
        Just resolved | resolvedGraphicsConfidence resolved > resolvedTuningConfidence jvm -> resolvedGraphicsConfidence resolved
        _ -> resolvedTuningConfidence jvm
    summaryEvidence =
      resolvedTuningEvidence jvm <> maybe [] resolvedGraphicsEvidence graphics

performancePackSuggestion :: Maybe Text -> PerformancePackSuggestion
performancePackSuggestion loader =
  case normalizeLoader <$> loader of
    Just "fabric" -> recommended
    Just "quilt" -> recommended
    Just "forge" -> recommended
    Just "neoforge" -> recommended
    Just _ ->
      PerformancePackSuggestion
        { performancePackStatus = "unsupported"
        , performancePackTitle = "No safe one-click pack"
        , performancePackDetail = "Panino does not have a safe recipe for this loader yet."
        , performancePackLoader = loader
        , performancePackInstallAutomatically = False
        }
    Nothing ->
      PerformancePackSuggestion
        { performancePackStatus = "optional"
        , performancePackTitle = "Keep vanilla first"
        , performancePackDetail = "Start the instance first; if it stutters, Panino can suggest a smoother pack."
        , performancePackLoader = Nothing
        , performancePackInstallAutomatically = False
        }
  where
    recommended =
      PerformancePackSuggestion
        { performancePackStatus = "recommended"
        , performancePackTitle = "Recommend smoother pack"
        , performancePackDetail = "Panino can show the matched file list first, then install only after confirmation."
        , performancePackLoader = loader
        , performancePackInstallAutomatically = False
        }

performanceGraphicsSummaryFrom :: ResolvedGraphicsTuning -> PerformanceGraphicsSummary
performanceGraphicsSummaryFrom resolved =
  PerformanceGraphicsSummary
    { performanceGraphicsProfile = resolvedGraphicsEffectiveProfile resolved
    , performanceGraphicsRenderDistance = option "renderDistance"
    , performanceGraphicsSimulationDistance = option "simulationDistance"
    , performanceGraphicsMaxFps = option "maxFps"
    , performanceGraphicsSummary = resolvedGraphicsSummary resolved
    , performanceGraphicsCanApply = resolvedGraphicsCanApply resolved
    }
  where
    option key =
      Map.lookup key (resolvedGraphicsRecommendedOptions resolved)

fromJvmAction :: JvmTuningAction -> PerformancePrimaryAction
fromJvmAction action =
  PerformancePrimaryAction
    { performanceActionId = tuningActionId action
    , performanceActionTitle = tuningActionTitle action
    , performanceActionMemoryMb = tuningActionMemoryMb action
    }

actionNeedsUser :: PerformancePrimaryAction -> Bool
actionNeedsUser action =
  performanceActionId action /= "viewDetails"

hardwareTierLabel :: GraphicsHardwareTier -> Text
hardwareTierLabel tier =
  case tier of
    GraphicsHardwareMBase -> "M Base"
    GraphicsHardwareMPro -> "M Pro"
    GraphicsHardwareMMaxUltra -> "M Max/Ultra"
    GraphicsHardwareUnknown -> "Apple Silicon"

normalizeLoader :: Text -> Text
normalizeLoader =
  Text.toLower . Text.strip
