{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Diagnostics
  ( diagnosticsProbeResponse
  , diagnosticsStatusResponse
  , environmentReportResponse
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Control.Applicative ((<|>))
import Control.Concurrent.STM (readTVarIO)
import Data.Aeson
  ( Value(..)
  , object
  , (.=)
  )
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  )
import Data.Text (Text)
import Data.Time.Clock
  ( UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Network.HTTP.Types
  ( status200
  , status400
  )
import Network.Wai
  ( Request
  , Response
  , strictRequestBody
  )
import Panino.Api.Response (jsonResponse)
import Panino.Api.Routes.Diagnostics.EnvironmentConclusions
  ( compatibilityConclusion
  , conclusionActions
  , conclusionIsOk
  , conclusionNotBlocking
  , conclusionStatus
  , javaArchitectureMatches
  , javaResolutionConclusion
  , javaRuleConclusion
  , memoryConclusionWithRecommendation
  )
import Panino.Api.Routes.Diagnostics.EnvironmentContext
  ( EnvironmentReportContext(..)
  , environmentReportContext
  , environmentRequiredJavaMajor
  )
import Panino.Api.Routes.Diagnostics.EnvironmentRecommendations
  ( environmentGraphicsTuning
  , environmentJvmTuning
  , environmentPerformancePackRecommendation
  )
import Panino.Api.Routes.Diagnostics.RuntimeFeedback (environmentRuntimeFeedback)
import Panino.Api.Routes.Network
  ( effectiveNetworkConfigValue
  , sourceTestValue
  )
import Panino.Api.Routes.Diagnostics.Probes
  ( DiagnosticsProbeRequest(..)
  , baselineOk
  , checkOk
  , curseForgeProbe
  , decodeProbeRequest
  , directoryBaseline
  , fileDescriptorLimit
  , targetDirectoryProbe
  , valueBool
  )
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( TaskSnapshot(..)
  , TaskState(..)
  )
import qualified Panino.Content.Local.Java as LocalJava
import Panino.Content.Local.Types
  ( JavaCheckRequest(..)
  , JavaCheckResponse(..)
  )
import Panino.Launch.Tuning.Types (ResolvedJvmTuning(..))
import Panino.Net.Http
  ( metadataRetryCount
  )
import Panino.Performance.Summary (recommendPerformanceSummary)
import Panino.Platform.Hardware
  ( detectHardwareProfile
  , hardwareProfileMemoryBytes
  )
import Panino.Minecraft.Layout
  ( minecraftRoot
  , mkLayout
  )
import Panino.Runtime.Java.Resolve (resolveJavaRuntime)
import Panino.Runtime.Java.Types
  ( JavaRuntimeResolveRequest(..)
  , JavaRuntimeResolveResponse(..)
  )
import System.FilePath (takeDirectory)
import System.Info
  ( arch
  , os
  )
import GHC.Conc (getNumCapabilities)

diagnosticsStatusResponse :: ServerState -> IO Response
diagnosticsStatusResponse state = do
  now <- getCurrentTime
  tasks <- readTVarIO (stateTasks state)
  network <- effectiveNetworkConfigValue
  retryCount <- metadataRetryCount
  pure $
    jsonResponse status200 $
      object
        [ "core" .= object
            [ "version" .= ("panino-core" :: Text)
            , "startedAt" .= stateStartedAt state
            , "uptimeSeconds" .= uptimeSeconds (stateStartedAt state) now
            ]
        , "effectiveNetwork" .= network
        , "download" .= object
            [ "retryCount" .= retryCount
            ]
        , "cachePaths" .= object
            [ "gameDir" .= stateDefaultGameDir state
            , "taskHistory" .= stateTaskHistoryPath state
            ]
        , "java" .= object
            [ "status" .= ("not_checked_by_core" :: Text)
            , "detail" .= ("Java runtime is checked by the macOS app through /api/v1/runtime/java/check." :: Text)
            ]
        , "tasks" .= object
            [ "total" .= Map.size tasks
            , "active" .= length (filter taskIsActive (Map.elems tasks))
            ]
        ]

diagnosticsProbeResponse :: ServerState -> Request -> IO Response
diagnosticsProbeResponse state request = do
  body <- strictRequestBody request
  case decodeProbeRequest body of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right probeRequest -> do
      generatedAt <- getCurrentTime
      source <- sourceTestValue state
      target <- targetDirectoryProbe (diagnosticsProbeGameDir probeRequest <|> stateDefaultGameDir state)
      curseForge <- curseForgeProbe state (diagnosticsProbeCurseForgeApiKey probeRequest)
      let checks = [target, curseForge]
          overallOk = valueBool "ok" source && all checkOk checks
      pure $
        jsonResponse status200 $
          object
            [ "ok" .= overallOk
            , "generatedAt" .= generatedAt
            , "source" .= source
            , "checks" .= checks
            ]

environmentReportResponse :: ServerState -> Request -> IO Response
environmentReportResponse state request = do
  let context = environmentReportContext request
      gameDir = environmentContextGameDir context <|> stateDefaultGameDir state
  generatedAt <- getCurrentTime
  capabilities <- getNumCapabilities
  hardware <- detectHardwareProfile
  let memory = hardwareProfileMemoryBytes hardware
  fdLimit <- fileDescriptorLimit
  java <- LocalJava.checkJavaRuntime (JavaCheckRequest Nothing)
  javaResolution <- javaResolutionForEnvironment state context gameDir
  let requiredMajor =
        maybe (environmentRequiredJavaMajor context) (Just . resolveResponseRequiredMajorVersion) javaResolution
  jvmTuning <- environmentJvmTuning context memory requiredMajor
  graphicsTuning <- environmentGraphicsTuning context gameDir
  performancePackRecommendation <- environmentPerformancePackRecommendation context gameDir
  runtimeFeedback <- environmentRuntimeFeedback state gameDir
  network <- effectiveNetworkConfigValue
  source <- sourceTestValue state
  directory <- directoryBaseline gameDir
  let javaRule = maybe (javaRuleConclusion context java) javaResolutionConclusion javaResolution
      memoryRule =
        memoryConclusionWithRecommendation
          memory
          (environmentContextMemoryMb context <|> environmentContextCustomMemoryMb context)
          (resolvedTuningRecommendedMemoryMb jvmTuning)
      compatibility = compatibilityConclusion context
      performanceSummary =
        recommendPerformanceSummary
          (environmentContextLoader context)
          requiredMajor
          hardware
          jvmTuning
          graphicsTuning
  pure $
    jsonResponse status200 $
      object
        [ "ok" .= (baselineOk directory && conclusionIsOk javaRule && conclusionNotBlocking memoryRule && conclusionNotBlocking compatibility)
        , "generatedAt" .= generatedAt
        , "performanceSummary" .= performanceSummary
        , "context" .= object
            [ "gameDir" .= gameDir
            , "minecraftVersion" .= environmentContextVersion context
            , "loader" .= environmentContextLoader context
            , "loaderVersion" .= environmentContextLoaderVersion context
            , "configuredMemoryMb" .= environmentContextMemoryMb context
            , "memoryPolicy" .= environmentContextMemoryPolicy context
            , "jvmProfile" .= environmentContextJvmProfile context
            , "graphicsProfile" .= environmentContextGraphicsProfile context
            , "graphicsHardwareTier" .= environmentContextGraphicsHardwareTier context
            , "displayScale" .= environmentContextDisplayScale context
            , "displayWidth" .= environmentContextDisplayWidth context
            , "displayHeight" .= environmentContextDisplayHeight context
            , "refreshRate" .= environmentContextRefreshRate context
            , "isBuiltinDisplay" .= environmentContextIsBuiltinDisplay context
            , "shaderEnabled" .= environmentContextShaderEnabled context
            , "resourcePackScale" .= environmentContextResourcePackScale context
            ]
        , "system" .= object
            [ "os" .= os
            , "architecture" .= arch
            , "cpuCapabilities" .= capabilities
            , "memoryBytes" .= memory
            , "hardwareProfile" .= hardware
            , "fileDescriptorLimit" .= fdLimit
            ]
        , "java" .= object
            [ "status" .= java
            , "architecture" .= arch
            , "requiredMajorVersion" .= requiredMajor
            , "installedMajorVersion" .= javaResponseMajorVersion java
            , "architectureMatchesSystem" .= javaArchitectureMatches java
            , "conclusion" .= conclusionStatus javaRule
            , "actions" .= conclusionActions javaRule
            ]
        , "javaResolution" .= javaResolution
        , "jvmTuning" .= jvmTuning
        , "launchEffectiveJvmArgs" .= resolvedTuningJvmArgs jvmTuning
        , "graphicsTuning" .= graphicsTuning
        , "performancePackRecommendation" .= performancePackRecommendation
        , "runtimeFeedback" .= runtimeFeedback
        , "directories" .= directory
        , "memory" .= object
            [ "systemBytes" .= memory
            , "configuredMb" .= environmentContextMemoryMb context
            , "recommendedMb" .= resolvedTuningRecommendedMemoryMb jvmTuning
            , "conclusion" .= conclusionStatus memoryRule
            , "actions" .= conclusionActions memoryRule
            ]
        , "network" .= object
            [ "effective" .= network
            , "speedTestEndpoint" .= ("/api/v1/network/speed-test" :: Text)
            , "sourceTest" .= source
            , "sourceSpeedSummary" .= Null
            ]
        , "compatibility" .= object
            [ "minecraftVersion" .= environmentContextVersion context
            , "loader" .= environmentContextLoader context
            , "loaderVersion" .= environmentContextLoaderVersion context
            , "conclusion" .= conclusionStatus compatibility
            , "actions" .= conclusionActions compatibility
            ]
        ]

javaResolutionForEnvironment :: ServerState -> EnvironmentReportContext -> Maybe FilePath -> IO (Maybe JavaRuntimeResolveResponse)
javaResolutionForEnvironment _ context _ | environmentContextVersion context == Nothing =
  pure Nothing
javaResolutionForEnvironment state context gameDir = do
  let version = fromMaybe "1.20.1" (environmentContextVersion context)
  layout <- mkLayout gameDir
  let appRoot = takeDirectory (minecraftRoot layout)
      request =
        JavaRuntimeResolveRequest
          { resolveMinecraftVersion = version
          , resolveGameDir = gameDir
          , resolveInstanceId = Nothing
          , resolvePolicy = Nothing
          , resolvePreferredRuntimeId = Nothing
          , resolveCustomPath = Nothing
          }
  result <- try (resolveJavaRuntime (stateHttpManager state) appRoot (Just layout) request)
  pure $ case result of
    Right response -> Just response
    Left (_ :: SomeException) -> Nothing

taskIsActive :: TaskSnapshot -> Bool
taskIsActive task =
  taskSnapshotState task `elem` [TaskQueued, TaskRunning]

uptimeSeconds :: UTCTime -> UTCTime -> Int
uptimeSeconds startedAt now =
  floor (realToFrac (diffUTCTime now startedAt) :: Double)
