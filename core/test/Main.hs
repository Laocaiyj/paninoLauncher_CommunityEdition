{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Integration.ApiJson
  ( assertApiJsonContracts
  )
import Integration.ContentPlan
  ( assertContentSearchQueries
  , assertContentTargetResolution
  , assertContentTypedInstallPlan
  , assertContentUpdatePlan
  )
import Integration.CoreCli
  ( assertCoreCli
  )
import Integration.DownloadManager
  ( assertDownloadCancellation
  , assertDownloadConcurrencyOptions
  , assertDownloadProgressCompletion
  , assertDownloadProgressWaitsForUnknownTailJobs
  , assertDownloadRejects404
  , assertDownloadRetryOptions
  , assertMultipartDownload
  , assertMultipartRangeGetFallback
  , assertMultipartRangeIgnoredFallsBack
  )
import Integration.DownloadVerification
  ( assertDownloadVerification
  )
import Integration.Diagnostics
  ( assertStructuredDiagnostics
  )
import Integration.GraphicsTuning
  ( assertGraphicsOptionsTuning
  , assertGraphicsTuningApiHelpers
  , assertGraphicsTuningRecommendations
  )
import Integration.InstallPlanExecutor
  ( assertInstallPlanExecutor
  )
import Integration.InstanceMetadata
  ( assertInstanceMetadataFallbackRepairsLoaderProfile
  )
import Integration.JavaRequirements
  ( assertJavaRequirements
  )
import Integration.JavaRuntime
  ( assertAutoJavaPathDownloadsManagedRuntime
  , assertJavaRuntimeArchiveSafety
  , assertJavaRuntimeCheckSummary
  , assertJavaRuntimeInstallWithFakeAdoptium
  , assertJavaRuntimeLocalDeleteSafety
  , assertJavaRuntimeManagerStore
  )
import Integration.JvmTuning
  ( assertJvmTuningRecommendations
  )
import Integration.LaunchArguments
  ( assertLaunchArgumentRules
  )
import Integration.LaunchTask
  ( assertLaunchHooksAreBestEffort
  , assertLaunchTaskCompletesAfterProcessStart
  , assertLaunchTaskFailsOnEarlyProcessExit
  )
import Integration.LocalInstanceStatus
  ( assertLocalInstanceStatus
  )
import Integration.LockfileSolver
  ( assertLockfileSolver
  )
import Integration.LoaderSelection
  ( assertModrinthPreferredVersionSelection
  , assertPreferredLoaderMetadataSelection
  )
import Integration.LoaderShader
  ( assertInstallerProbeRateLimitCooldown
  , assertLoaderShaderInstallFixtures
  , assertLoaderShaderPreflightFixtures
  , assertTrackedShaderInstallCleanup
  )
import Integration.MinecraftInstall
  ( assertInstallMissingClientDownload
  , assertInstallPostVerifyMissingClientJar
  )
import Integration.MinecraftPlan
  ( assertMinecraftInstallPlanGraph
  )
import Integration.Modpack
  ( assertModpackImportStaging
  , assertModpackTypedPlan
  )
import Integration.ModPreflight
  ( assertModPreflight
  )
import Integration.ModrinthDependencyResolver
  ( assertModrinthDependencyResolver
  )
import Integration.NetworkFailure
  ( assertNetworkFailureFixtures
  )
import Integration.Performance
  ( assertAdaptivePerformanceSystem
  , assertPerformancePackRecommendation
  , assertPerformanceSummary
  )
import Integration.SourceOverrides
  ( assertSourceOverrides
  )
import Integration.Taowa
  ( testTaowaP0
  , testTaowaP1
  )
import Integration.TypedInstallPlan
  ( assertTypedInstallPlanTypes
  )
import qualified Property.Runner as PropertyRunner
import System.Directory
  ( getTemporaryDirectory
  )

main :: IO ()
main = do
  assertCoreCli
  tempRoot <- getTemporaryDirectory
  testTaowaP0 tempRoot
  testTaowaP1 tempRoot
  assertLaunchTaskCompletesAfterProcessStart tempRoot
  assertLaunchTaskFailsOnEarlyProcessExit tempRoot
  assertLaunchHooksAreBestEffort tempRoot
  assertModrinthPreferredVersionSelection
  assertTrackedShaderInstallCleanup tempRoot
  assertLocalInstanceStatus tempRoot
  assertJavaRequirements
  assertJvmTuningRecommendations
  assertGraphicsOptionsTuning
  assertGraphicsTuningRecommendations
  assertGraphicsTuningApiHelpers
  assertPerformanceSummary
  assertAdaptivePerformanceSystem
  assertPerformancePackRecommendation
  assertMinecraftInstallPlanGraph
  assertApiJsonContracts
  assertTypedInstallPlanTypes
  assertLockfileSolver
  assertStructuredDiagnostics
  PropertyRunner.runProperties
  assertContentTargetResolution
  assertContentTypedInstallPlan
  assertInstallPlanExecutor
  assertContentUpdatePlan
  assertModpackTypedPlan
  assertModpackImportStaging
  assertContentSearchQueries
  assertSourceOverrides
  assertModPreflight
  assertModrinthDependencyResolver
  assertPreferredLoaderMetadataSelection
  assertLoaderShaderPreflightFixtures
  assertInstallerProbeRateLimitCooldown
  assertLoaderShaderInstallFixtures
  assertInstallMissingClientDownload
  assertInstallPostVerifyMissingClientJar
  assertNetworkFailureFixtures
  tempDir <- getTemporaryDirectory
  assertInstanceMetadataFallbackRepairsLoaderProfile tempDir
  assertJavaRuntimeCheckSummary tempDir
  assertJavaRuntimeLocalDeleteSafety tempDir
  assertJavaRuntimeManagerStore tempDir
  assertJavaRuntimeInstallWithFakeAdoptium tempDir
  assertAutoJavaPathDownloadsManagedRuntime tempDir
  assertJavaRuntimeArchiveSafety tempDir
  assertDownloadVerification tempDir
  assertDownloadRejects404 tempDir
  assertDownloadRetryOptions tempDir
  assertDownloadProgressCompletion tempDir
  assertDownloadProgressWaitsForUnknownTailJobs tempDir
  assertDownloadConcurrencyOptions tempDir
  assertMultipartDownload tempDir
  assertMultipartRangeGetFallback tempDir
  assertMultipartRangeIgnoredFallsBack tempDir
  assertDownloadCancellation tempDir
  assertLaunchArgumentRules
