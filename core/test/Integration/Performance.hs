{-# LANGUAGE OverloadedStrings #-}

module Integration.Performance
  ( assertAdaptivePerformanceSystem
  , assertPerformancePackRecommendation
  , assertPerformanceSummary
  ) where

import Control.Monad (when)
import Data.Aeson
  ( decode
  , encode
  , toJSON
  )
import Data.Int (Int64)
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List (isPrefixOf)
import qualified Data.Text as Text
import Data.Time.Clock (getCurrentTime)
import Panino.CoreLogic.Determinism (canonicalJson)
import Panino.Graphics.Tuning.Options (parseMinecraftOptions)
import Panino.Graphics.Tuning.Recommend (recommendGraphicsTuning)
import Panino.Graphics.Tuning.Types
  ( GraphicsHardwareTier(..)
  , GraphicsTuningRequest(..)
  , defaultGraphicsTuningRequest
  )
import Panino.Launch.Tuning.Recommend (recommendJvmTuning)
import Panino.Launch.Tuning.Types
  ( JvmTuningRequest(..)
  , defaultJvmTuningRequest
  )
import Panino.Performance.Candidate
  ( CandidateBudget(..)
  , candidateChangeCount
  , generateCandidate
  )
import Panino.Performance.Objective
  ( PerformanceScore(..)
  , defaultPerformanceObjective
  , scoreSession
  )
import Panino.Performance.Pack
  ( PerformanceModEntry(..)
  , PerformancePackRecommendation(..)
  , performanceModFileNames
  , recommendPerformancePack
  )
import Panino.Performance.Profile.Store (baselineProfile)
import Panino.Performance.Profile.Types
  ( InstanceFingerprint(..)
  , PerformanceConfidence(..)
  , PerformanceKnobs(..)
  , defaultInstanceFingerprint
  , defaultPerformanceKnobs
  , estimatedEvidence
  , profileConfidence
  , profileEvidence
  , profileKnobs
  )
import Panino.Performance.SafetyGate
  ( SafetyGateDecision(..)
  , checkSafetyGate
  )
import Panino.Performance.Summary
  ( PerformanceGraphicsSummary(..)
  , PerformancePackSuggestion(..)
  , PerformancePrimaryAction(..)
  , PerformanceSummary(..)
  , recommendPerformanceSummary
  )
import Panino.Performance.Telemetry.GcLog
  ( gcLogArguments
  , parseGcLogMetrics
  )
import Panino.Performance.Telemetry.Types
  ( GcMetrics(..)
  , LaunchMetrics(..)
  , MemoryMetrics(..)
  , MemorySample(..)
  , PerformanceSession(..)
  , PerformanceSessionStatus(..)
  , emptyMemoryMetrics
  )
import Panino.Performance.ValidationMatrix
  ( ProfilePrior(..)
  , ValidationResult(..)
  , defaultValidationHardwareMatrix
  , defaultValidationInstances
  , defaultValidationMatrix
  , generateProfilePriors
  , successiveHalving
  )
import Panino.Platform.Hardware (HardwareProfile(..))
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , getTemporaryDirectory
  , removeDirectoryRecursive
  )
import System.FilePath ((</>))
import TestSupport (assertEqual)

assertPerformanceSummary :: IO ()
assertPerformanceSummary = do
  let hardware =
        HardwareProfile
          { hardwareProfileChipName = Just "Apple M3 Pro"
          , hardwareProfileChipTier = GraphicsHardwareMPro
          , hardwareProfileMemoryBytes = Just (gbBytes 32)
          , hardwareProfileMemoryTier = "24/32GB"
          }
      jvm =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestSystemMemoryBytes = Just (gbBytes 32)
            , tuningRequestMinecraftVersion = Just "1.21.1"
            , tuningRequestJavaMajorVersion = Just 21
            , tuningRequestLoader = Just "fabric"
            }
      graphics =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestLoader = Just "fabric"
            , graphicsRequestGameDir = Just "/tmp/mc"
            , graphicsRequestHardwareTier = GraphicsHardwareMPro
            , graphicsRequestMinecraftVersion = Just "1.21.1"
            }
          (parseMinecraftOptions "renderDistance:2\nmaxFps:30\n")
      summary =
        recommendPerformanceSummary
          (Just "fabric")
          (Just 21)
          hardware
          jvm
          (Just graphics)
  assertEqual "performance summary hardware label" "M Pro" (performanceSummaryHardwareLabel summary)
  assertEqual
    "performance summary pack recommended"
    "recommended"
    (performancePackStatus (performanceSummaryPerformancePack summary))
  assertEqual
    "performance summary never auto-installs pack"
    False
    (performancePackInstallAutomatically (performanceSummaryPerformancePack summary))
  assertEqual
    "performance summary exposes main action"
    "applyGraphics"
    (performanceActionId (performanceSummaryPrimaryAction summary))
  assertEqual
    "performance summary detail hides view distance from first layer"
    False
    ("view distance" `Text.isInfixOf` performanceSummaryDetail summary)
  assertEqual
    "performance summary diagnostics keep render distance"
    (Just "12")
    (performanceSummaryGraphics summary >>= performanceGraphicsRenderDistance)

assertAdaptivePerformanceSystem :: IO ()
assertAdaptivePerformanceSystem = do
  now <- getCurrentTime
  let fingerprint =
        defaultInstanceFingerprint
          { fingerprintMinecraftVersion = Just "1.21.1"
          , fingerprintJavaRequirement = Just "21"
          , fingerprintLoaderFamily = Just "fabric"
          , fingerprintRendererCapability = Just "java_renderer_unknown"
          , fingerprintModCount = Just 48
          }
      knobs =
        defaultPerformanceKnobs
          { knobHeapMaxMb = Just 6144
          , knobRenderDistance = Just 12
          , knobSimulationDistance = Just 8
          , knobMaxFps = Just 90
          }
      baseline =
        baselineProfile
          "/tmp/panino-adaptive"
          fingerprint
          knobs
          [estimatedEvidence "source" "test baseline"]
      candidate =
        generateCandidate
          CandidateBudget
            { candidateBudgetLaunches = 1
            , candidateBudgetChangedKnobs = 1
            }
          baseline
      gcLog =
        unlines
          [ "[0.123s][info][gc] GC(0) Pause Young 12.0ms"
          , "[1.456s][info][gc] GC(1) Pause Young 64.0ms"
          , "[2.789s][info][gc] GC(2) Pause Full 220.0ms"
          ]
      gcMetrics = parseGcLogMetrics "/tmp/gc.log" gcLog
      session =
        PerformanceSession
          { sessionLaunchSessionId = "launch-test"
          , sessionGameDir = "/tmp/panino-adaptive"
          , sessionInstanceFingerprint = fingerprint
          , sessionBaselineProfileId = Just "baseline"
          , sessionCandidateProfileId = Just "candidate"
          , sessionStatus = SessionEnded
          , sessionStartedAt = now
          , sessionEndedAt = Just now
          , sessionLaunchMetrics =
              LaunchMetrics
                { launchTimeToProcessStartMs = Just 4
                , launchTimeToGameLogReadyMs = Just 20
                , launchTimeToMainWindowHintMs = Nothing
                , launchProcessExitCode = Just 0
                , launchCrashReportCreated = False
                , launchLatestLogErrors = []
                }
          , sessionMemoryMetrics =
              emptyMemoryMetrics
                { memoryPeakResidentBytes = gbBytes 6
                , memoryPressureHint = Just "low"
                , memorySamples =
                    [ MemorySample 0 (gbBytes 4) (gbBytes 9)
                    , MemorySample 500 (gbBytes 6) (gbBytes 10)
                    ]
                }
          , sessionGcMetrics = gcMetrics
          , sessionCompanionFrameMetrics = Nothing
          , sessionAppliedProfile = Just baseline
          , sessionRollbackRef = Just "rollback-test"
          }
      score = scoreSession defaultPerformanceObjective session
      decision = checkSafetyGate defaultPerformanceObjective (Just session) candidate
      validationScore =
        PerformanceScore
          { scoreSmoothness = 80
          , scoreStability = 100
          , scoreMemorySafety = 90
          , scoreVisualQuality = 95
          , scoreEnergy = Nothing
          , scoreOverall = 365
          , scoreRejected = False
          , scoreRejectReasons = []
          }
      validationResults =
        [ ValidationResult "vanilla-M1-mem8-builtin" "baseline-balanced" "baseline" "complete" (Just validationScore)
        , ValidationResult "vanilla-M1-mem8-builtin" "candidate-smoothness" "candidate" "complete" (Just validationScore { scoreOverall = 380 })
        ]
      priors = generateProfilePriors validationResults
  assertEqual "static adaptive baseline is estimated" ConfidenceEstimated (profileConfidence baseline)
  assertEqual "adaptive baseline carries evidence" True (not (null (profileEvidence baseline)))
  assertEqual "candidate changes only one knob" True (candidateChangeCount (profileKnobs baseline) (profileKnobs candidate) <= 1)
  assertEqual "Java 8 uses legacy GC logging" True (any ("-Xloggc:" `isPrefixOf`) (gcLogArguments 8 "/tmp/gc.log"))
  assertEqual "Java 21 uses unified GC logging" True (any ("-Xlog:gc*" `isPrefixOf`) (gcLogArguments 21 "/tmp/gc.log"))
  assertEqual "GC parser counts pauses" 3 (gcPauseCount gcMetrics)
  assertEqual "GC parser computes P95" (Just 220.0) (gcPauseP95Ms gcMetrics)
  assertEqual "objective rejects high GC pause" True (scoreRejected score)
  assertEqual "safety gate blocks rejected candidate" False (safetyAllowed decision)
  assertEqual "performance session JSON roundtrip" (Just session) (decode (encode session))
  assertEqual "validation matrix defines five instance classes" 5 (length defaultValidationInstances)
  assertEqual "validation matrix covers M1-M4 memory/display" 24 (length defaultValidationHardwareMatrix)
  assertEqual "validation matrix combines scenarios" 120 (length defaultValidationMatrix)
  assertEqual "successive halving keeps winner budget" ["candidate-smoothness"] (map validationResultProfileId (successiveHalving 1 validationResults))
  assertEqual "profile priors summarize completed scores" [("baseline-balanced", 1), ("candidate-smoothness", 1)] (map (\prior -> (profilePriorProfileId prior, profilePriorScenarioCount prior)) priors)

assertPerformancePackRecommendation :: IO ()
assertPerformancePackRecommendation = do
  tempDir <- getTemporaryDirectory
  let recommendation =
        recommendPerformancePack
          (Just "fabric")
          (Just "1.21.1")
          (Just 24)
          ["sodium-fabric-mc1.21.jar", "OptiFine_1.21.1_HD.jar"]
      recommendationShuffled =
        recommendPerformancePack
          (Just "fabric")
          (Just "1.21.1")
          (Just 24)
          ["OptiFine_1.21.1_HD.jar", "sodium-fabric-mc1.21.jar"]
  assertEqual
    "performance pack requires review with optifine"
    "needsReview"
    (performanceRecommendationStatus recommendation)
  assertEqual
    "performance pack never installs silently"
    False
    (performanceRecommendationInstallAutomatically recommendation)
  assertEqual
    "performance pack sees existing sodium"
    ["sodium"]
    (map performanceModId (performanceRecommendationExisting recommendation))
  assertEqual
    "performance pack detects optifine conflict"
    ["optifine"]
    (map performanceModId (performanceRecommendationConflicts recommendation))
  assertEqual
    "performance pack blocks renderer install during optifine review"
    False
    ("sodium" `elem` map performanceModId (performanceRecommendationInstallable recommendation))
  assertEqual
    "performance pack recommendation ignores existing file input order"
    (canonicalJson (toJSON recommendation))
    (canonicalJson (toJSON recommendationShuffled))
  let gameDir = tempDir </> "panino-performance-mod-sort"
      modsDir = gameDir </> "mods"
  exists <- doesDirectoryExist gameDir
  when exists (removeDirectoryRecursive gameDir)
  createDirectoryIfMissing True modsDir
  BL8.writeFile (modsDir </> "z-performance.jar") ""
  BL8.writeFile (modsDir </> "a-performance.jar") ""
  sortedModFiles <- performanceModFileNames (Just gameDir)
  assertEqual
    "performance mod file snapshot is sorted"
    ["a-performance.jar", "z-performance.jar"]
    sortedModFiles
  assertEqual
    "vanilla performance pack skips install"
    []
    ( performanceRecommendationInstallable $
        recommendPerformancePack Nothing (Just "1.21.1") (Just 0) []
    )

gbBytes :: Int64 -> Int64
gbBytes gb =
  gb * 1024 * 1024 * 1024
