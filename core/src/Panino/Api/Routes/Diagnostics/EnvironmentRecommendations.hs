{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Diagnostics.EnvironmentRecommendations
  ( environmentGraphicsTuning
  , environmentJvmTuning
  , environmentPerformancePackRecommendation
  ) where

import Data.Aeson
  ( Value
  , toJSON
  )
import Data.Int (Int64)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Panino.Api.Routes.Diagnostics.EnvironmentContext (EnvironmentReportContext(..))
import Panino.Api.Routes.GraphicsTuning (readGraphicsTuningForEnvironment)
import Panino.Graphics.Tuning.Types
  ( GraphicsHardwareTier(..)
  , GraphicsTuningProfile(..)
  , GraphicsTuningRequest(..)
  , ResolvedGraphicsTuning
  )
import Panino.Launch.Tuning.Recommend (recommendJvmTuning)
import Panino.Launch.Tuning.Types
  ( JvmTuningPolicy(..)
  , JvmTuningRequest(..)
  , MemoryPolicy(..)
  , ResolvedJvmTuning
  )
import Panino.Performance.Pack
  ( performanceModFileNames
  , recommendPerformancePack
  )

environmentJvmTuning :: EnvironmentReportContext -> Maybe Int64 -> Maybe Int -> IO ResolvedJvmTuning
environmentJvmTuning context memory requiredMajor =
  pure $
    recommendJvmTuning
      JvmTuningRequest
        { tuningRequestInstanceId = Nothing
        , tuningRequestGameDir = environmentContextGameDir context
        , tuningRequestPolicy = fromMaybe JvmTuningAuto (environmentContextJvmProfile context)
        , tuningRequestMemoryPolicy =
            fromMaybe
              (if environmentContextCustomMemoryMb context /= Nothing then MemoryPolicyCustom else MemoryPolicyAuto)
              (environmentContextMemoryPolicy context)
        , tuningRequestSystemMemoryBytes = memory
        , tuningRequestMinecraftVersion = environmentContextVersion context
        , tuningRequestJavaMajorVersion = requiredMajor
        , tuningRequestLoader = environmentContextLoader context
        , tuningRequestModCount = environmentContextModCount context
        , tuningRequestResourcePackCount = environmentContextResourcePackCount context
        , tuningRequestShaderPackCount = environmentContextShaderPackCount context
        , tuningRequestPackScale = Nothing
        , tuningRequestModpackIsLarge = False
        , tuningRequestSawHeapOutOfMemory = False
        , tuningRequestSawNativeOutOfMemory = False
        , tuningRequestSawGcOverhead = False
        , tuningRequestLastExitCode = Nothing
        , tuningRequestCustomMemoryMb = environmentContextCustomMemoryMb context
        , tuningRequestCustomJvmArgs = environmentContextCustomJvmArgs context
        }

environmentGraphicsTuning :: EnvironmentReportContext -> Maybe FilePath -> IO (Maybe ResolvedGraphicsTuning)
environmentGraphicsTuning _ Nothing =
  pure Nothing
environmentGraphicsTuning context (Just gameDir) =
  Just
    <$> readGraphicsTuningForEnvironment
      GraphicsTuningRequest
        { graphicsRequestInstanceId = Nothing
        , graphicsRequestGameDir = Just gameDir
        , graphicsRequestMinecraftVersion = environmentContextVersion context
        , graphicsRequestLoader = environmentContextLoader context
        , graphicsRequestHardwareTier =
            fromMaybe GraphicsHardwareUnknown (environmentContextGraphicsHardwareTier context)
        , graphicsRequestDisplayScale = environmentContextDisplayScale context
        , graphicsRequestDisplayWidth = environmentContextDisplayWidth context
        , graphicsRequestDisplayHeight = environmentContextDisplayHeight context
        , graphicsRequestRefreshRate = environmentContextRefreshRate context
        , graphicsRequestIsBuiltinDisplay = environmentContextIsBuiltinDisplay context
        , graphicsRequestPowerMode = Nothing
        , graphicsRequestProfile =
            fromMaybe GraphicsProfileBalanced (environmentContextGraphicsProfile context)
        , graphicsRequestShaderEnabled = environmentContextShaderEnabled context
        , graphicsRequestResourcePackScale = environmentContextResourcePackScale context
        , graphicsRequestModCount = environmentContextModCount context
        , graphicsRequestPreviousSnapshot = Nothing
        , graphicsRequestManualOverrides = Map.empty
        , graphicsRequestDryRun = True
        }
      gameDir

environmentPerformancePackRecommendation :: EnvironmentReportContext -> Maybe FilePath -> IO Value
environmentPerformancePackRecommendation context gameDir = do
  modFiles <- performanceModFileNames gameDir
  pure $
    toJSON $
      recommendPerformancePack
        (environmentContextLoader context)
        (environmentContextVersion context)
        (environmentContextModCount context)
        modFiles
