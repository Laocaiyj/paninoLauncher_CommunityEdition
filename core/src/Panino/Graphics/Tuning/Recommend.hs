{-# LANGUAGE OverloadedStrings #-}

module Panino.Graphics.Tuning.Recommend
  ( graphicsPackScale
  , recommendGraphicsTuning
  , recommendedGraphicsOptions
  ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  )
import Data.Text (Text)
import Panino.Graphics.Tuning.Options
  ( MinecraftOptions
  , buildOptionsPatchForVersion
  , duplicateOptionWarnings
  , optionsMap
  )
import Panino.Graphics.Tuning.Recommend.Policy
  ( currentValueWarnings
  , graphicsPackScale
  , pressureWarnings
  , recommendedGraphicsOptions
  , recommendedRetinaPolicy
  )
import Panino.Graphics.Tuning.Types
  ( GraphicsHardwareTier(..)
  , GraphicsTuningAction(..)
  , GraphicsTuningProfile(..)
  , GraphicsTuningRequest(..)
  , GraphicsTuningWarning(..)
  , OptionsPatch(..)
  , OptionsPatchChange(..)
  , ResolvedGraphicsTuning(..)
  , RetinaPolicy(..)
  , graphicsRequestGameDirPath
  , renderGraphicsHardwareTier
  , renderRetinaPolicy
  )
import Panino.Performance.Profile.Types
  ( AdaptiveApplyMode(..)
  , PerformanceConfidence(..)
  , estimatedEvidence
  )
import System.FilePath ((</>))

recommendGraphicsTuning :: GraphicsTuningRequest -> MinecraftOptions -> ResolvedGraphicsTuning
recommendGraphicsTuning request currentOptions =
  ResolvedGraphicsTuning
    { resolvedGraphicsRequestedProfile = requestedProfile
    , resolvedGraphicsEffectiveProfile = effectiveProfile
    , resolvedGraphicsHardwareTier = effectiveTier
    , resolvedGraphicsRetinaPolicy = retinaPolicy
    , resolvedGraphicsCurrentOptions = currentMap
    , resolvedGraphicsRecommendedOptions = recommended
    , resolvedGraphicsOptionsPatch = patch
    , resolvedGraphicsSummary = summaryText recommended retinaPolicy
    , resolvedGraphicsConfidence = ConfidenceEstimated
    , resolvedGraphicsEvidence =
        [ estimatedEvidence "source" "static graphics baseline"
        , estimatedEvidence "hardwareTier" (renderGraphicsHardwareTier effectiveTier)
        , estimatedEvidence "retinaPolicy" (renderRetinaPolicy retinaPolicy)
        ]
    , resolvedGraphicsRollbackRef = graphicsRequestInstanceId request >>= \ident -> Just ("graphics-" <> ident)
    , resolvedGraphicsApplyMode = ApplyAsk
    , resolvedGraphicsWarnings = warnings
    , resolvedGraphicsActions = actions
    , resolvedGraphicsPrimaryAction = listToMaybe actions
    , resolvedGraphicsBackupPath = previousSnapshotBackupPath
    , resolvedGraphicsCanApply = any isPatchChange (optionsPatchChanges patch)
    , resolvedGraphicsCanRollback = previousSnapshotBackupPath /= Nothing
    }
  where
    requestedProfile = graphicsRequestProfile request
    effectiveProfile =
      case requestedProfile of
        GraphicsProfileManual -> GraphicsProfileBalanced
        _ -> requestedProfile
    effectiveTier =
      case graphicsRequestHardwareTier request of
        GraphicsHardwareUnknown -> GraphicsHardwareMBase
        tier -> tier
    currentMap = optionsMap currentOptions
    recommended = recommendedGraphicsOptions request
    patch =
      buildOptionsPatchForVersion
        (graphicsRequestMinecraftVersion request)
        (optionsPath <$> graphicsRequestGameDirPath request)
        recommended
        currentOptions
    warnings =
      duplicateOptionWarnings currentOptions
        <> currentValueWarnings currentOptions recommended request
        <> pressureWarnings request effectiveProfile effectiveTier recommended
        <> historyWarnings request
        <> skippedPatchWarnings patch
    actions = recommendedActions warnings recommended
    retinaPolicy = recommendedRetinaPolicy request effectiveProfile
    previousSnapshotBackupPath =
      graphicsRequestPreviousSnapshot request >>= resolvedGraphicsBackupPath

historyWarnings :: GraphicsTuningRequest -> [GraphicsTuningWarning]
historyWarnings request =
  case graphicsRequestPreviousSnapshot request of
    Nothing -> []
    Just snapshot ->
      concat
        [ [warning "previous_low_fps" "Last run looked slow. Panino suggests a lower graphics profile, but will not change it without approval." "switchPerformance" | hasPreviousWarning "low_fps" snapshot]
        , [warning "previous_retina_gpu_pressure" "Last run had Retina GPU pressure. Try the smoother profile if this instance still stutters." "switchPerformance" | hasPreviousWarning "retina_gpu_pressure" snapshot]
        , [warning "previous_manual_rollback" "The last graphics change was rolled back. Panino will only show a suggestion this time." "reviewGraphics" | hasPreviousWarning "manual_rollback" snapshot]
        ]

skippedPatchWarnings :: OptionsPatch -> [GraphicsTuningWarning]
skippedPatchWarnings patch =
  [ warning "options_key_skipped" ("Skipped " <> optionsPatchChangeKey change <> ": " <> optionsPatchChangeReason change <> ".") "reviewOptions"
  | change <- optionsPatchChanges patch
  , optionsPatchChangeStatus change == "skipped"
  ]

recommendedActions :: [GraphicsTuningWarning] -> Map Text Text -> [GraphicsTuningAction]
recommendedActions warnings recommended =
  concat
    [ [action "reduceRenderDistance" "Lower Render Distance" ["renderDistance"] | hasWarning "render_distance_too_high"]
    , [action "reduceSimulationDistance" "Lower Simulation Distance" ["simulationDistance"] | hasWarning "simulation_distance_too_high"]
    , [action "limitFps" "Limit FPS" ["maxFps"] | hasWarning "fps_cap_too_high"]
    , [action "switchPerformance" "Switch to Smoother Graphics" ["renderDistance", "simulationDistance", "maxFps", "renderClouds", "particles"] | hasAnyWarning ["retina_gpu_pressure", "shader_pressure", "previous_low_fps", "previous_retina_gpu_pressure"]]
    , [action "applyRecommended" "Apply Recommended Graphics" (Map.keys recommended) | not (null warnings)]
    ]
  where
    hasWarning code =
      any ((== code) . graphicsWarningCode) warnings
    hasAnyWarning codes =
      any (`elem` map graphicsWarningCode warnings) codes
    action actionId title keys =
      GraphicsTuningAction
        { graphicsActionId = actionId
        , graphicsActionTitle = title
        , graphicsActionOptions = Map.filterWithKey (\key _ -> key `elem` keys) recommended
        }

summaryText :: Map Text Text -> RetinaPolicy -> Text
summaryText recommended retinaPolicy =
  "Recommended render distance "
    <> value "renderDistance"
    <> ", simulation distance "
    <> value "simulationDistance"
    <> ", FPS cap "
    <> value "maxFps"
    <> ", "
    <> retinaText retinaPolicy
    <> "."
  where
    value key =
      fromMaybe "-" (Map.lookup key recommended)

retinaText :: RetinaPolicy -> Text
retinaText policy =
  case policy of
    RetinaQuality -> "keep Retina clarity"
    BalancedRetina -> "balance Retina clarity and GPU pressure"
    PerformanceScale -> "prioritize smoother rendering"
    RetinaPolicyUnsupported -> "Retina policy is unsupported"

warning :: Text -> Text -> Text -> GraphicsTuningWarning
warning code message actionId =
  GraphicsTuningWarning
    { graphicsWarningCode = code
    , graphicsWarningSeverity = "warning"
    , graphicsWarningMessage = message
    , graphicsWarningAction = Just actionId
    }

hasPreviousWarning :: Text -> ResolvedGraphicsTuning -> Bool
hasPreviousWarning code snapshot =
  any ((== code) . graphicsWarningCode) (resolvedGraphicsWarnings snapshot)

isPatchChange :: OptionsPatchChange -> Bool
isPatchChange change =
  optionsPatchChangeStatus change == "change"

optionsPath :: FilePath -> FilePath
optionsPath gameDir =
  gameDir </> "options.txt"
