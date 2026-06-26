{-# LANGUAGE OverloadedStrings #-}

module Panino.Graphics.Tuning.Recommend.Policy
  ( currentValueWarnings
  , graphicsPackScale
  , pressureWarnings
  , recommendedGraphicsOptions
  , recommendedRetinaPolicy
  ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Graphics.Tuning.Options
  ( MinecraftOptions
  , optionValue
  )
import Panino.Graphics.Tuning.Types
  ( GraphicsHardwareTier(..)
  , GraphicsTuningProfile(..)
  , GraphicsTuningRequest(..)
  , GraphicsTuningWarning(..)
  , RetinaPolicy(..)
  )

data GraphicsPackScale
  = GraphicsPackVanillaLight
  | GraphicsPackMedium
  | GraphicsPackLarge
  deriving (Eq, Show)

recommendedGraphicsOptions :: GraphicsTuningRequest -> Map Text Text
recommendedGraphicsOptions request =
  normalizeGraphicsOptions (graphicsRequestManualOverrides request)
    `Map.union`
      normalizeGraphicsOptions
        ( Map.fromList
            [ ("renderDistance", renderInt finalRenderDistance)
            , ("simulationDistance", renderInt finalSimulationDistance)
            , ("maxFps", renderInt finalMaxFps)
            , ("enableVsync", renderBool finalVsync)
            , ("renderClouds", finalClouds)
            , ("particles", finalParticles)
            , ("entityDistanceScaling", finalEntityDistance)
            , ("mipmapLevels", renderInt finalMipmap)
            , ("graphicsMode", finalGraphicsMode)
            ]
        )
  where
    tier =
      case graphicsRequestHardwareTier request of
        GraphicsHardwareUnknown -> GraphicsHardwareMBase
        value -> value
    profile =
      case graphicsRequestProfile request of
        GraphicsProfileManual -> GraphicsProfileBalanced
        value -> value
    packScale = graphicsPackScale request
    base = baseGraphicsRecommendation tier profile
    renderPenalty =
      packRenderPenalty packScale
        + shaderRenderPenalty request
        + resourcePackRenderPenalty request
        + retinaRenderPenalty request tier profile
        + externalDisplayRenderPenalty request
    simulationCap =
      min (packSimulationCap packScale) (shaderSimulationCap request)
    finalRenderDistance =
      clamp 4 32 (recRenderDistance base - renderPenalty)
    finalSimulationDistance =
      clamp 4 16 (min (recSimulationDistance base) simulationCap)
    finalMaxFps =
      min (recMaxFps base) (displayFpsCap request tier profile)
    finalVsync =
      recommendedVsync request tier profile
    finalClouds =
      if graphicsRequestShaderEnabled request || packScale == GraphicsPackLarge || profile == GraphicsProfilePerformance || profile == GraphicsProfileBatterySaver
        then "fast"
        else recClouds base
    finalParticles =
      if graphicsRequestShaderEnabled request || packScale == GraphicsPackLarge || profile == GraphicsProfilePerformance || profile == GraphicsProfileBatterySaver
        then "decreased"
        else recParticles base
    finalEntityDistance =
      if profile == GraphicsProfilePerformance || packScale == GraphicsPackLarge
        then "0.75"
        else recEntityDistance base
    finalMipmap =
      recMipmap base
    finalGraphicsMode =
      if profile == GraphicsProfilePerformance || profile == GraphicsProfileBatterySaver || tier == GraphicsHardwareMBase
        then "fast"
        else "fancy"

graphicsPackScale :: GraphicsTuningRequest -> GraphicsPackScale
graphicsPackScale request
  | maybe False (>= 151) (graphicsRequestModCount request) = GraphicsPackLarge
  | graphicsRequestShaderEnabled request = GraphicsPackMedium
  | maybe False isLargeResourcePack (graphicsRequestResourcePackScale request) = GraphicsPackMedium
  | maybe False (>= 41) (graphicsRequestModCount request) = GraphicsPackMedium
  | moddedLoader && graphicsRequestModCount request == Nothing = GraphicsPackMedium
  | otherwise = GraphicsPackVanillaLight
  where
    moddedLoader =
      maybe False (`notElem` ["", "vanilla", "none"]) $
        Text.toLower . Text.strip <$> graphicsRequestLoader request

recommendedRetinaPolicy :: GraphicsTuningRequest -> GraphicsTuningProfile -> RetinaPolicy
recommendedRetinaPolicy request profile
  | not (fromMaybe False (graphicsRequestIsBuiltinDisplay request)) = BalancedRetina
  | fromMaybe 1 (graphicsRequestDisplayScale request) < 2 = BalancedRetina
  | profile == GraphicsProfileClarity = RetinaQuality
  | profile == GraphicsProfilePerformance || profile == GraphicsProfileBatterySaver = PerformanceScale
  | otherwise = BalancedRetina

currentValueWarnings :: MinecraftOptions -> Map Text Text -> GraphicsTuningRequest -> [GraphicsTuningWarning]
currentValueWarnings currentOptions recommended request =
  concat
    [ highIntWarning "renderDistance" "render_distance_too_high" "Current render distance is higher than Panino's safe recommendation." "reduceRenderDistance" 4
    , highIntWarning "simulationDistance" "simulation_distance_too_high" "Current simulation distance is higher than Panino's safe recommendation." "reduceSimulationDistance" 2
    , highIntWarning "maxFps" "fps_cap_too_high" "Current FPS cap can add heat or GPU pressure without improving play." "limitFps" 30
    , [ shaderPressureWarning | graphicsRequestShaderEnabled request ]
    ]
  where
    highIntWarning key code message action tolerance =
      case (readTextInt =<< optionValue key currentOptions, readTextInt =<< Map.lookup key recommended) of
        (Just current, Just target)
          | current > target + tolerance -> [warning code message action]
        _ -> []

pressureWarnings :: GraphicsTuningRequest -> GraphicsTuningProfile -> GraphicsHardwareTier -> Map Text Text -> [GraphicsTuningWarning]
pressureWarnings request profile tier recommended =
  concat
    [ [ retinaPressureWarning
      | fromMaybe False (graphicsRequestIsBuiltinDisplay request)
      , fromMaybe 1 (graphicsRequestDisplayScale request) >= 2
      , tier == GraphicsHardwareMBase
      , profile /= GraphicsProfilePerformance && profile /= GraphicsProfileBatterySaver
      ]
    , [ highRefreshWarning
      | maybe False (>= 144) (graphicsRequestRefreshRate request)
      , maybe False (> 120) (readTextInt =<< Map.lookup "maxFps" recommended)
      , tier /= GraphicsHardwareMMaxUltra
      ]
    , [ externalHighResolutionWarning
      | isExternalHighResolutionDisplay request
      , tier /= GraphicsHardwareMMaxUltra
      ]
    ]

normalizeGraphicsOptions :: Map Text Text -> Map Text Text
normalizeGraphicsOptions =
  Map.foldlWithKey' insertNormalized Map.empty
  where
    insertNormalized acc rawKey rawValue =
      let key = normalizeGraphicsOptionKey rawKey
      in Map.insert key (normalizeGraphicsOptionValue key rawValue) acc

normalizeGraphicsOptionKey :: Text -> Text
normalizeGraphicsOptionKey key
  | key == "clouds" = "renderClouds"
  | otherwise = key

normalizeGraphicsOptionValue :: Text -> Text -> Text
normalizeGraphicsOptionValue key value =
  case key of
    "renderClouds" -> normalizeCloudsValue value
    "particles" -> normalizeParticlesValue value
    "graphicsMode" -> normalizeGraphicsModeValue value
    _ -> value

normalizeCloudsValue :: Text -> Text
normalizeCloudsValue value =
  case Text.toLower (Text.strip (Text.replace "\"" "" value)) of
    "false" -> "\"false\""
    "off" -> "\"false\""
    "fast" -> "\"fast\""
    "true" -> "\"true\""
    "fancy" -> "\"true\""
    "all" -> "\"true\""
    other -> other

normalizeParticlesValue :: Text -> Text
normalizeParticlesValue value =
  case Text.toLower (Text.strip value) of
    "all" -> "0"
    "full" -> "0"
    "decreased" -> "1"
    "minimal" -> "2"
    other -> other

normalizeGraphicsModeValue :: Text -> Text
normalizeGraphicsModeValue value =
  case Text.toLower (Text.strip value) of
    "fast" -> "0"
    "fancy" -> "1"
    "fabulous" -> "2"
    other -> other

data GraphicsRecommendation = GraphicsRecommendation
  { recRenderDistance :: Int
  , recSimulationDistance :: Int
  , recMaxFps :: Int
  , recClouds :: Text
  , recParticles :: Text
  , recEntityDistance :: Text
  , recMipmap :: Int
  }

baseGraphicsRecommendation :: GraphicsHardwareTier -> GraphicsTuningProfile -> GraphicsRecommendation
baseGraphicsRecommendation tier profile =
  case (tier, profile) of
    (GraphicsHardwareMBase, GraphicsProfileClarity) -> GraphicsRecommendation 12 8 90 "fast" "decreased" "1.0" 4
    (GraphicsHardwareMBase, GraphicsProfileBalanced) -> GraphicsRecommendation 10 6 90 "fast" "decreased" "0.9" 3
    (GraphicsHardwareMBase, GraphicsProfilePerformance) -> GraphicsRecommendation 8 5 60 "false" "decreased" "0.75" 2
    (GraphicsHardwareMBase, GraphicsProfileBatterySaver) -> GraphicsRecommendation 6 4 45 "false" "minimal" "0.75" 2
    (GraphicsHardwareMPro, GraphicsProfileClarity) -> GraphicsRecommendation 18 10 120 "fast" "all" "1.0" 4
    (GraphicsHardwareMPro, GraphicsProfileBalanced) -> GraphicsRecommendation 14 8 120 "fast" "decreased" "1.0" 4
    (GraphicsHardwareMPro, GraphicsProfilePerformance) -> GraphicsRecommendation 12 8 90 "fast" "decreased" "0.9" 4
    (GraphicsHardwareMPro, GraphicsProfileBatterySaver) -> GraphicsRecommendation 10 6 60 "fast" "decreased" "0.75" 3
    (GraphicsHardwareMMaxUltra, GraphicsProfileClarity) -> GraphicsRecommendation 24 12 144 "fancy" "all" "1.25" 4
    (GraphicsHardwareMMaxUltra, GraphicsProfileBalanced) -> GraphicsRecommendation 20 10 120 "fast" "all" "1.0" 4
    (GraphicsHardwareMMaxUltra, GraphicsProfilePerformance) -> GraphicsRecommendation 18 10 120 "fast" "decreased" "1.0" 4
    (GraphicsHardwareMMaxUltra, GraphicsProfileBatterySaver) -> GraphicsRecommendation 12 8 60 "fast" "decreased" "0.75" 3
    (GraphicsHardwareUnknown, _) -> baseGraphicsRecommendation GraphicsHardwareMBase profile
    (_, GraphicsProfileManual) -> baseGraphicsRecommendation tier GraphicsProfileBalanced

packRenderPenalty :: GraphicsPackScale -> Int
packRenderPenalty scale =
  case scale of
    GraphicsPackVanillaLight -> 0
    GraphicsPackMedium -> 2
    GraphicsPackLarge -> 4

packSimulationCap :: GraphicsPackScale -> Int
packSimulationCap scale =
  case scale of
    GraphicsPackVanillaLight -> 16
    GraphicsPackMedium -> 10
    GraphicsPackLarge -> 8

shaderRenderPenalty :: GraphicsTuningRequest -> Int
shaderRenderPenalty request =
  if graphicsRequestShaderEnabled request then 4 else 0

shaderSimulationCap :: GraphicsTuningRequest -> Int
shaderSimulationCap request =
  if graphicsRequestShaderEnabled request then 8 else 16

resourcePackRenderPenalty :: GraphicsTuningRequest -> Int
resourcePackRenderPenalty request =
  if maybe False isLargeResourcePack (graphicsRequestResourcePackScale request) then 2 else 0

retinaRenderPenalty :: GraphicsTuningRequest -> GraphicsHardwareTier -> GraphicsTuningProfile -> Int
retinaRenderPenalty request tier profile =
  if fromMaybe False (graphicsRequestIsBuiltinDisplay request)
      && fromMaybe 1 (graphicsRequestDisplayScale request) >= 2
      && tier == GraphicsHardwareMBase
      && profile /= GraphicsProfilePerformance
    then 2
    else 0

externalDisplayRenderPenalty :: GraphicsTuningRequest -> Int
externalDisplayRenderPenalty request =
  if isExternalHighResolutionDisplay request then 2 else 0

displayFpsCap :: GraphicsTuningRequest -> GraphicsHardwareTier -> GraphicsTuningProfile -> Int
displayFpsCap request tier profile
  | profile == GraphicsProfileBatterySaver = 60
  | tier == GraphicsHardwareMBase = if highRefresh then 90 else 90
  | tier == GraphicsHardwareMPro = if highRefresh then 120 else 120
  | tier == GraphicsHardwareMMaxUltra = if highRefresh then 144 else 120
  | otherwise = 90
  where
    highRefresh =
      maybe False (>= 120) (graphicsRequestRefreshRate request)

recommendedVsync :: GraphicsTuningRequest -> GraphicsHardwareTier -> GraphicsTuningProfile -> Bool
recommendedVsync request tier profile =
  not (tier == GraphicsHardwareMMaxUltra && highRefresh && profile == GraphicsProfileClarity)
  where
    highRefresh =
      maybe False (>= 120) (graphicsRequestRefreshRate request)

isLargeResourcePack :: Text -> Bool
isLargeResourcePack raw =
  any (`Text.isInfixOf` normalized) ["high", "large", "hd", "128", "256", "512", "4k", "5k"]
  where
    normalized =
      Text.toLower raw

isExternalHighResolutionDisplay :: GraphicsTuningRequest -> Bool
isExternalHighResolutionDisplay request =
  fromMaybe False (not <$> graphicsRequestIsBuiltinDisplay request)
    && maybe False (>= (3840 * 2160)) pixelArea
  where
    pixelArea =
      (*) <$> graphicsRequestDisplayWidth request <*> graphicsRequestDisplayHeight request

shaderPressureWarning :: GraphicsTuningWarning
shaderPressureWarning =
  warning "shader_pressure" "Shader is enabled, so Panino recommends a more conservative render distance, clouds, and particles." "switchPerformance"

retinaPressureWarning :: GraphicsTuningWarning
retinaPressureWarning =
  warning "retina_gpu_pressure" "Built-in Retina display is sharp but increases GPU pressure. Balanced or smoother graphics is safer on base M-series Macs." "switchPerformance"

highRefreshWarning :: GraphicsTuningWarning
highRefreshWarning =
  warning "fps_cap_too_high" "High refresh displays can add heat. Panino will cap FPS unless the GPU tier can sustain it." "limitFps"

externalHighResolutionWarning :: GraphicsTuningWarning
externalHighResolutionWarning =
  warning "retina_gpu_pressure" "External 4K/5K displays increase GPU pressure. Panino recommends a safer render distance." "switchPerformance"

warning :: Text -> Text -> Text -> GraphicsTuningWarning
warning code message actionId =
  GraphicsTuningWarning
    { graphicsWarningCode = code
    , graphicsWarningSeverity = "warning"
    , graphicsWarningMessage = message
    , graphicsWarningAction = Just actionId
    }

readTextInt :: Text -> Maybe Int
readTextInt value =
  case reads (Text.unpack value) of
    [(number, "")] -> Just number
    _ -> Nothing

renderInt :: Int -> Text
renderInt =
  Text.pack . show

renderBool :: Bool -> Text
renderBool True = "true"
renderBool False = "false"

clamp :: Int -> Int -> Int -> Int
clamp lower upper =
  max lower . min upper
