{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Panino.Core
  ( Command(..)
  , InstallOptions(..)
  , LaunchOptions(..)
  , ResolveOptions(..)
  , ServeOptions(..)
  , parseCommand
  , renderCommand
  , selectServeSessionToken
  , versionLine
  )
import Panino.Api.Types
  ( ContentInstallDependency(..)
  , ContentInstallFile(..)
  , ContentInstallPlanFile(..)
  , ContentInstallPlanResponse(..)
  , ContentInstallRequest(..)
  , ContentUpdateLockEntry(..)
  , ContentUpdatePlanRequest(..)
  , ContentUpdatePlanResource(..)
  , ContentUpdatePlanResponse(..)
  , DownloadRuntimeOptions(..)
  , InstallRequest(..)
  , LaunchRequest(..)
  , TaskProgress(..)
  , TaskSnapshot(..)
  , TaskState(..)
  )
import Panino.Api.MinecraftStatus
  ( MinecraftInstallStatusRequest(..)
  , MinecraftInstalledInstance(..)
  , fetchInstalledMinecraftInstances
  )
import qualified Panino.Api.Routes.Content as ContentRoutes
import Panino.Api.Routes.GraphicsTuning
  ( readGraphicsTuningForEnvironment
  , writeGraphicsTuningDiagnostics
  , writeGraphicsTuningRollbackEvent
  )
import Panino.Api.Routes.Minecraft.LaunchHooks
  ( LaunchHookSession(..)
  , beginLaunchHooks
  , runBestEffortLaunchChecks
  )
import Panino.Api.Routes.Minecraft.Common (resolveAutoJavaPath)
import Panino.Api.Routes.Minecraft.LaunchTask (observeStartedLaunchWithDelay)
import Panino.Api.Routes.Tasks (startTaskWithGameDirContext)
import Panino.Api.Server.State (ServerState(..))
import Control.Exception
  ( SomeException
  , finally
  , fromException
  , try
  )
import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , modifyMVar_
  , newEmptyMVar
  , newMVar
  , putMVar
  , readMVar
  , tryReadMVar
  )
import Control.Concurrent.STM
  ( newTVarIO
  , readTVarIO
  )
import Control.Monad (when)
import Data.Aeson
  ( Value
  , decode
  , eitherDecode
  , encode
  , object
  , toJSON
  , (.=)
  )
import Data.Int (Int64)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as Builder
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List
  ( isInfixOf
  , isPrefixOf
  , isSuffixOf
  , stripPrefix
  )
import Data.Maybe
  ( isJust
  , mapMaybe
  )
import Network.HTTP.Types
  ( hContentType
  , status206
  , status200
  , status404
  , status429
  , status500
  , status503
  )
import Network.Wai
  ( Request
  , Response
  , ResponseReceived
  , queryString
  , rawPathInfo
  , requestHeaderHost
  , requestHeaders
  , requestMethod
  , responseLBS
  , responseStream
  )
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.Content.Online.Modrinth
  ( ModrinthProjectResponse(..)
  , modrinthFacets
  , modrinthRequiredDependencyReleases
  , modrinthSearchQuery
  )
import Panino.Content.Online.CurseForge
  ( curseForgeSearchQueryWithCategoryIds
  )
import Panino.Content.Configuration.Preflight
  ( modpackImport
  , modpackPreflight
  )
import Panino.Content.Configuration.Types
  ( ModpackImportRequest(..)
  , ModpackImportResponse(..)
  , ModpackPreflightRequest(..)
  , ModpackPreflightResponse(..)
  )
import Panino.Content.Local.Java
  ( checkJavaRuntime
  , deleteJavaRuntimeCandidate
  )
import Panino.Content.Local.Types
  ( JavaCheckRequest(..)
  , JavaCheckResponse(..)
  , JavaRuntimeLocalDeleteRequest(..)
  , JavaRuntimeLocalDeleteResponse(..)
  )
import Panino.Content.Online.Types
  ( ContentSearchRequest(..)
  , LoaderMetadata(..)
  , OnlineDependency(..)
  , OnlineFile(..)
  , OnlineRelease(..)
  )
import Panino.Content.Online.Minecraft
  ( preferredLoaderMetadata
  )
import Panino.Download.Manager
  ( DownloadException(..)
  , DownloadJob(..)
  , downloadOptionsWithOverrides
  , DownloadProgress(..)
  , DownloadResult(..)
  , DownloadSummary(..)
  , downloadSingle
  , runDownloadJobsWithOptionsAndProgressAndCancel
  , runDownloadJobsWithProgressAndCancel
  , sha1HexFile
  )
import Panino.Download.VerificationIndex
  ( flushVerificationIndex
  , recordVerifiedFile
  )
import Panino.Events.Bus (newEventBus)
import Panino.Graphics.Tuning.Options
  ( applyOptionsPatch
  , applyOptionsPatchToFile
  , backupOptionsFile
  , buildOptionsPatch
  , buildOptionsPatchForVersion
  , duplicateOptionWarnings
  , graphicsOptionSkippedReason
  , isGraphicsOptionsWritableKey
  , optionValue
  , parseMinecraftOptions
  , renderMinecraftOptions
  , rollbackOptionsFile
  )
import Panino.Graphics.Tuning.Recommend
  ( recommendGraphicsTuning
  )
import Panino.Graphics.Tuning.Types
  ( GraphicsHardwareTier(..)
  , GraphicsTuningProfile(..)
  , GraphicsTuningRequest(..)
  , GraphicsTuningWarning(..)
  , OptionsBackup(..)
  , OptionsPatch(..)
  , OptionsPatchChange(..)
  , ResolvedGraphicsTuning(..)
  , RetinaPolicy(..)
  , defaultGraphicsTuningRequest
  , inferGraphicsHardwareTier
  )
import Panino.Diagnostics.Classify
  ( classifyFailure
  , diagnosticFromBlockedReason
  )
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , DiagnosticAction(..)
  , DiagnosticEvidence(..)
  , FailureInput(..)
  , redactedText
  )
import Panino.CoreLogic.Determinism
  ( canonicalJson
  )
import qualified Property.Runner as PropertyRunner
import Panino.Install.Plan.Types
  ( InstallPlanEdge(..)
  , InstallPlanNode(..)
  , InstallPlanRollbackAction(..)
  , InstallPlanSummary(..)
  , InstallVerification(..)
  , TypedInstallPlan(..)
  , finalizeTypedInstallPlan
  )
import Panino.Install.Plan.Executor
  ( InstallNodeResult(..)
  , InstallNodeStatus(..)
  , InstallPlanExecutionResult(..)
  , executeInstallPlan
  , installPlanExecutionBatches
  )
import Panino.Lockfile.Apply
  ( rollbackLockfilePlanNode
  , runLockfilePlanNode
  )
import Panino.Lockfile.Solver
  ( diffLockfiles
  , lockfileApplyReadyLockfile
  , lockfileLaunchBlockedReasons
  , lockfileSolveCacheGameDir
  , roomLockRepairPlan
  , roomRequiredLockSubset
  , solveLockfile
  , solveLockfileWithServices
  , verifyLockfile
  )
import Panino.Lockfile.Types
  ( LockfileApplyRequest(..)
  , LockfileFile(..)
  , LockfileSolveRequest(..)
  , LockfileVerifyIssue(..)
  , LockfileVerifyResponse(..)
  , PackageConstraint(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , lockfileChangePackageId
  , solverResultBlockedReasons
  , solverResultChangeset
  , solverResultExplain
  , solverResultLockfile
  , solverResultStatus
  , solverResultTypedPlan
  , solverResultWarnings
  , solverResultConflicts
  , solverConflictCode
  , changesetAdd
  , changesetKeep
  , changesetManual
  , changesetRemove
  , changesetReplace
  , explainRejectedCandidates
  , verifyIssueTargetPath
  , verifyResponseExtraFiles
  , verifyResponseMissingFiles
  , verifyResponseHashMismatches
  , verifyResponseRepairPlan
  , verifyResponseStatus
  )
import Panino.Launch.Arguments
  ( LaunchProfile(..)
  , buildJavaArguments
  , substituteVariables
  )
import Panino.Launch.Java
  ( JavaProcessLaunch(..)
  , JavaRunResult(..)
  )
import Panino.Launch.Tuning.Recommend (inferPackScale, recommendJvmTuning)
import Panino.Launch.Tuning.Types
  ( JvmTuningPolicy(..)
  , JvmTuningRequest(..)
  , JvmTuningWarning(..)
  , PackScale(..)
  , ResolvedJvmTuning(..)
  , defaultJvmTuningRequest
  )
import Panino.Performance.Summary
  ( PerformanceGraphicsSummary(..)
  , PerformancePackSuggestion(..)
  , PerformancePrimaryAction(..)
  , PerformanceSummary(..)
  , recommendPerformanceSummary
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
import Panino.Performance.Profile.Store
  ( baselineProfile
  )
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
import Panino.Performance.Pack
  ( PerformanceModEntry(..)
  , PerformancePackRecommendation(..)
  , performanceModFileNames
  , recommendPerformancePack
  )
import Panino.Platform.Hardware
  ( HardwareProfile(..)
  , hardwareMemoryTier
  , hardwareTierFromChipName
  )
import Panino.Minecraft.Install
  ( InstallResult(..)
  , classpathJars
  , installMinecraftVersionWithOptionsAndProgressAndCancel
  , mavenArtifactPath
  , resolveVersionSummaryJson
  )
import Panino.Minecraft.InstallPreflight
  ( LoaderInstallPreflightRequest(..)
  , LoaderInstallPreflightResponse(..)
  , blockedLoaderInstallPreflightResponse
  , loaderInstallPreflight
  )
import Panino.Minecraft.InstallPlanGraph
  ( addLoaderProfileTypedPlan
  , addInstanceMetadataTypedPlan
  , combineInstallPlanGraphs
  , downloadJobsInstallPlanGraph
  , installPlanGraphNodes
  , installPlanGraphTypedPlan
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  , clientJarPath
  , mkLayout
  , minecraftRoot
  , versionJsonPath
  )
import Panino.Minecraft.InstanceMetadata
  ( InstanceMetadata(..)
  , readInstanceMetadata
  , writeInstanceMetadata
  )
import Panino.Minecraft.LoaderInstall
  ( LoaderInstallOptions(..)
  , LoaderInstallResult(..)
  , ModrinthFile(..)
  , ModrinthVersion(..)
  , emptyShaderInstallResult
  , installMinecraftProfileWithOptionsAndProgressAndCancel
  , postVerifyInstall
  , removeTrackedShaderInstallFiles
  , selectPreferredModrinthVersion
  )
import Panino.Minecraft.ModPreflight
  ( MissingModDependency(..)
  , missingFabricDependenciesFromManifests
  , preflightModDependencies
  )
import Panino.Minecraft.Types
  ( ArgPiece(..)
  , DownloadInfo(..)
  , JavaVersion(..)
  , Library(..)
  , Rule(..)
  , RuleAction(..)
  , VersionArguments(..)
  , VersionJson(..)
  , isAllowedByRules
  )
import Panino.Net.Http
  ( applyRequestTimeoutMicros
  , coreRequest
  , fetchJson
  , makeHttpManager
  , metadataRetryCount
  )
import Panino.Net.Probe (sourceHostKey)
import Panino.Net.Sources (resolveSourceUrls)
import Panino.Runtime.Java.Catalog
  ( defaultRuntimeArch
  , runtimeDownloadSpec
  )
import Panino.Runtime.Java.Requirements
  ( fallbackJavaMajorVersion
  , javaRequirementForVersionJson
  )
import Panino.Runtime.Java.Resolve (resolveJavaRuntimeForRequirement)
import Panino.Runtime.Java.Store
  ( deleteManagedRuntime
  , readManagedRuntimes
  , readRuntimePolicies
  , selectJavaRuntimePolicy
  , upsertManagedRuntime
  )
import Panino.Runtime.Java.Install
  ( importJavaRuntime
  , installJavaRuntime
  )
import Panino.Runtime.Java.Types
  ( JavaManagedRuntime(..)
  , JavaRuntimeDeleteResponse(..)
  , JavaRuntimeDownloadSpec(..)
  , JavaRuntimeImportRequest(..)
  , JavaRuntimeInstallRequest(..)
  , JavaRuntimePolicyRecord(..)
  , JavaRuntimeRequirement(..)
  , JavaRuntimeResolveRequest(..)
  , JavaRuntimeResolveResponse(..)
  , JavaRuntimeSelectRequest(..)
  )
import Data.Time.Clock
  ( addUTCTime
  , getCurrentTime
  )
import Data.Text (Text)
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getFileSize
  , getTemporaryDirectory
  , removeDirectoryRecursive
  , removeFile
  )
import System.Environment
  ( setEnv
  , unsetEnv
  )
import System.Exit
  ( ExitCode(..)
  , exitFailure
  )
import System.FilePath
  ( (</>)
  , (<.>)
  , normalise
  , takeDirectory
  )
import System.Posix.Files (createSymbolicLink)
import System.Process
  ( CreateProcess(..)
  , createProcess
  , proc
  , readCreateProcessWithExitCode
  , waitForProcess
  )

main :: IO ()
main = do
  assertEqual "default command" (Right ShowVersion) (parseCommand [])
  assertEqual "version flag" (Right ShowVersion) (parseCommand ["--version"])
  assertEqual "health command" (Right HealthCheck) (parseCommand ["health"])
  assertEqual "unknown command" (Left "unknown command: nope") (parseCommand ["nope"])
  assertEqual
    "resolve command"
    (Right (Resolve (ResolveOptions "1.20.1" Nothing)))
    (parseCommand ["resolve", "--version", "1.20.1"])
  assertEqual
    "install command"
    (Right (Install (InstallOptions "1.20.1" (Just "/tmp/mc") 4 Nothing Nothing)))
    (parseCommand ["install", "--version", "1.20.1", "--game-dir", "/tmp/mc", "--concurrency", "4"])
  assertEqual
    "install loader command"
    (Right (Install (InstallOptions "1.20.1" (Just "/tmp/mc") 4 (Just "fabric") (Just "iris"))))
    (parseCommand ["install", "--version", "1.20.1", "--game-dir", "/tmp/mc", "--concurrency", "4", "--loader", "fabric", "--shader-loader", "iris"])
  assertEqual
    "args command"
    (Right (PrintArgs (LaunchOptions "1.20.1" Nothing 2048 "java" "Steve" "00000000-0000-0000-0000-000000000000" "0" 32 False)))
    (parseCommand ["args", "--version", "1.20.1", "--memory", "2048"])
  assertEqual
    "serve command"
    (Right (Serve (ServeOptions "127.0.0.1" 37123 (Just "dev-token") Nothing (Just "/tmp/mc"))))
    (parseCommand ["serve", "--port", "37123", "--session-token", "dev-token", "--game-dir", "/tmp/mc"])
  assertEqual
    "serve token file command"
    (Right (Serve (ServeOptions "127.0.0.1" 37123 Nothing (Just "/tmp/core-token") Nothing)))
    (parseCommand ["serve", "--port", "37123", "--session-token-file", "/tmp/core-token"])
  let serveOptions = ServeOptions "127.0.0.1" 37123 (Just "legacy-token") (Just "/tmp/core-token") Nothing
  assertEqual "serve token file wins" (Right "file-token") (selectServeSessionToken (Just " file-token\n") (Just "env-token") serveOptions)
  assertEqual "serve token env fallback" (Right "env-token") (selectServeSessionToken Nothing (Just "env-token") serveOptions)
  assertEqual "serve token legacy fallback" (Right "legacy-token") (selectServeSessionToken Nothing Nothing serveOptions)
  assertEqual
    "serve token rejects empty sources"
    (Left "serve requires --session-token-file, PANINO_CORE_SESSION_TOKEN, or --session-token")
    (selectServeSessionToken (Just "\n") (Just " ") (ServeOptions "127.0.0.1" 37123 (Just "") Nothing Nothing))
  assertEqual "version line" "panino-core 0.1.0.0" (versionLine "0.1.0.0")
  assertEqual "health output" "ok" (renderCommand "0.1.0.0" HealthCheck)
  tempRoot <- getTemporaryDirectory
  assertLaunchTaskCompletesAfterProcessStart tempRoot
  assertLaunchTaskFailsOnEarlyProcessExit tempRoot
  assertLaunchHooksAreBestEffort tempRoot
  assertModrinthPreferredVersionSelection
  assertTrackedShaderInstallCleanup tempRoot
  let failedInstallRoot = tempRoot </> "panino-status-failed"
      failedVersionDir = failedInstallRoot </> "versions" </> "1.20.1"
  failedInstallExists <- doesDirectoryExist failedInstallRoot
  when failedInstallExists (removeDirectoryRecursive failedInstallRoot)
  createDirectoryIfMissing True failedVersionDir
  createDirectoryIfMissing True (failedInstallRoot </> "mods")
  createDirectoryIfMissing True (failedInstallRoot </> ".panino")
  BL8.writeFile (failedVersionDir </> "1.20.1.json") "{}"
  BL8.writeFile (failedVersionDir </> "1.20.1.jar") "jar"
  BL8.writeFile (failedInstallRoot </> ".panino" </> "install-state.json") "{\"state\":\"failed\"}"
  failedInstances <-
    fetchInstalledMinecraftInstances
      Nothing
      (MinecraftInstallStatusRequest ["1.20.1"] [failedInstallRoot])
  assertEqual "failed install-state is discovered but incomplete" [(False, False)] (map (\item -> (installedInstanceVersionJson item, installedInstanceClientJar item)) failedInstances)
  let inferredLoaderRoot = tempRoot </> "panino-status-loader-inferred"
      inferredBaseDir = inferredLoaderRoot </> "versions" </> "1.21.7"
      inferredQuiltDir = inferredLoaderRoot </> "versions" </> "quilt-loader-0.20.0-beta.9-1.21.7"
  inferredLoaderExists <- doesDirectoryExist inferredLoaderRoot
  when inferredLoaderExists (removeDirectoryRecursive inferredLoaderRoot)
  createDirectoryIfMissing True inferredBaseDir
  createDirectoryIfMissing True inferredQuiltDir
  createDirectoryIfMissing True (inferredLoaderRoot </> "mods")
  BL8.writeFile (inferredBaseDir </> "1.21.7.json") "{}"
  BL8.writeFile (inferredBaseDir </> "1.21.7.jar") "jar"
  BL8.writeFile (inferredQuiltDir </> "quilt-loader-0.20.0-beta.9-1.21.7.json") "{}"
  inferredInstances <-
    fetchInstalledMinecraftInstances
      Nothing
      (MinecraftInstallStatusRequest ["1.21.7"] [inferredLoaderRoot])
  assertEqual "local instance loader is inferred from loader profile" [(Just "quilt", Just "0.20.0-beta.9")] (map (\item -> (installedInstanceLoader item, installedInstanceLoaderVersion item)) inferredInstances)
  assertEqual
    "java manifest major version wins"
    (21, "manifest", Just "java-runtime-delta")
    ( let requirement =
            javaRequirementForVersionJson
              "1.21.5"
              testVersionJson
                { versionId = "1.21.5"
                , versionJavaVersion = Just (JavaVersion (Just "java-runtime-delta") (Just 21))
                }
       in ( javaRequirementMajorVersion requirement
          , javaRequirementSource requirement
          , javaRequirementComponent requirement
          )
    )
  assertEqual
    "java fallback rules"
    [21, 21, 17, 16, 8, 21]
    (map fallbackJavaMajorVersion ["1.20.5", "1.21.1", "1.20.4", "1.17.1", "1.16.5", "26.2-pre-2"])
  assertEqual
    "adoptium arm64 jre catalog url"
    "https://api.adoptium.net/v3/binary/latest/21/ga/mac/aarch64/jre/hotspot/normal/eclipse"
    (runtimeDownloadUrl (runtimeDownloadSpec 21 "mac" "aarch64" "jre"))
  assertJvmTuningRecommendations
  assertGraphicsOptionsTuning
  assertGraphicsTuningRecommendations
  assertGraphicsTuningApiHelpers
  assertPerformanceSummary
  assertAdaptivePerformanceSystem
  assertPerformancePackRecommendation
  assertEqual
    "maven artifact path"
    "org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1.jar"
    (mavenArtifactPath "org.lwjgl:lwjgl:3.3.1" Nothing)
  assertEqual
    "classpath includes loader maven libraries"
    [ "/tmp/mc/libraries/net/fabricmc/fabric-loader/0.19.2/fabric-loader-0.19.2.jar"
    , "/tmp/mc/libraries/org/ow2/asm/asm/9.9/asm-9.9.jar"
    , "/tmp/mc/versions/fabric-loader-0.19.2-1.20.1/fabric-loader-0.19.2-1.20.1.jar"
    ]
    (classpathJars testLayout testVersionJson)
  assertEqual
    "modrinth project endpoint accepts id"
    (Right "sodium")
    (modrinthProjectId <$> eitherDecode modrinthProjectJson)
  assertEqual
    "install request parses nested download runtime options"
    (Right (DownloadRuntimeOptions (Just 7) (Just 2) Nothing))
    (installRequestDownload <$> eitherDecode "{\"version\":\"1.20.1\",\"download\":{\"concurrency\":7,\"retryCount\":2}}")
  assertEqual
    "install request keeps legacy download fields"
    (Right (DownloadRuntimeOptions (Just 4) (Just 1) Nothing))
    (installRequestDownload <$> eitherDecode "{\"version\":\"1.20.1\",\"concurrency\":4,\"retryCount\":1}")
  assertEqual
    "install request parses strategy"
    (Right (DownloadRuntimeOptions (Just 48) (Just 4) (Just "fast")))
    (installRequestDownload <$> eitherDecode "{\"version\":\"1.20.1\",\"download\":{\"concurrency\":48,\"retryCount\":4,\"strategy\":\"fast\"}}")
  let planGraph =
        downloadJobsInstallPlanGraph
          "test"
          "dedupe"
          [ DownloadJob "duplicate-a" "https://example.com/a.jar" "/tmp/a.jar" (Just "abc") (Just 10)
          , DownloadJob "duplicate-b" "https://example.com/b.jar" "/tmp/b.jar" (Just "abc") (Just 10)
          ]
  assertEqual "install plan graph dedupes sha1" 1 (length (installPlanGraphNodes planGraph))
  assertEqual "install plan graph exposes typed plan" "test" (typedPlanKind (installPlanGraphTypedPlan planGraph))
  assertEqual "install plan graph json is typed plan" (Right (installPlanGraphTypedPlan planGraph)) (eitherDecode (encode planGraph))
  assertEqual "install plan graph typed summary" 1 (installSummaryDownloadNodes (typedPlanSummary (installPlanGraphTypedPlan planGraph)))

  let assetGraph =
        downloadJobsInstallPlanGraph
          "minecraft"
          "assets"
          [ DownloadJob "asset index 26" "https://example.com/index.json" "/tmp/mc/assets/indexes/26.json" (Just "indexhash") (Just 20)
          , DownloadJob "asset minecraft/sounds/test.ogg" "https://example.com/object" "/tmp/mc/assets/objects/ab/object" (Just "objecthash") (Just 40)
          ]
      assetGraphShuffled =
        downloadJobsInstallPlanGraph
          "minecraft"
          "assets"
          [ DownloadJob "asset minecraft/sounds/test.ogg" "https://example.com/object" "/tmp/mc/assets/objects/ab/object" (Just "objecthash") (Just 40)
          , DownloadJob "asset index 26" "https://example.com/index.json" "/tmp/mc/assets/indexes/26.json" (Just "indexhash") (Just 20)
          ]
      assetPlan = installPlanGraphTypedPlan assetGraph
      assetPlanShuffled = installPlanGraphTypedPlan assetGraphShuffled
      assetIndexIds =
        [ installNodeId node
        | node <- typedPlanNodes assetPlan
        , installNodeKind node == "assetIndex"
        ]
      assetObjectDependsOn =
        concat
          [ installNodeDependsOn node
          | node <- typedPlanNodes assetPlan
          , installNodeKind node == "assetObject"
          ]
  assertEqual "asset objects depend on asset index" True (not (null assetIndexIds) && all (`elem` assetObjectDependsOn) assetIndexIds)
  assertEqual "download job order does not change graph plan id" (typedPlanId assetPlan) (typedPlanId assetPlanShuffled)
  assertEqual "download job order does not change graph node ids" (map installNodeId (typedPlanNodes assetPlan)) (map installNodeId (typedPlanNodes assetPlanShuffled))

  let largeJobs =
        [ DownloadJob
            ("asset minecraft/large/" <> show index <> ".ogg")
            ("https://example.com/assets/" <> show index)
            ("/tmp/mc/assets/objects/large/" <> show index)
            (Just (Text.pack ("sha" <> show index)))
            (Just (fromIntegral index))
        | index <- [1 :: Int .. 600]
        ]
      largeGraph = downloadJobsInstallPlanGraph "minecraft" "large-assets" largeJobs
      largeGraphShuffled = downloadJobsInstallPlanGraph "minecraft" "large-assets" (reverse largeJobs)
      largePlan = installPlanGraphTypedPlan largeGraph
      largePlanShuffled = installPlanGraphTypedPlan largeGraphShuffled
  assertEqual "large install graph keeps legacy node count" 600 (length (installPlanGraphNodes largeGraph))
  assertEqual "large install graph compacts typed nodes" 1 (length (typedPlanNodes largePlan))
  assertEqual "large install graph preserves summary count" 600 (installSummaryTotalNodes (typedPlanSummary largePlan))
  assertEqual "large install graph compact fingerprint is stable" (typedPlanFingerprint largePlan) (typedPlanFingerprint largePlanShuffled)

  let missingHashGraph =
        downloadJobsInstallPlanGraph
          "minecraft"
          "missing-hash"
          [DownloadJob "client jar missing hash" "https://example.com/client.jar" "/tmp/mc/versions/26/client.jar" Nothing (Just 40)]
  assertEqual "required node without sha1 blocks typed plan" ["missing_sha1"] (typedPlanBlockedReasons (installPlanGraphTypedPlan missingHashGraph))

  let loaderGraph = addLoaderProfileTypedPlan testLayout "fabric-loader-0.19.2-26.1.2" (Just "0.19.2") assetGraph
      loaderPlan = installPlanGraphTypedPlan loaderGraph
      loaderProfileIds =
        [ installNodeId node
        | node <- typedPlanNodes loaderPlan
        , installNodeKind node == "loaderProfile"
        ]
      loaderProfileRollbacks =
        [ installRollbackAction (installNodeRollback node)
        | node <- typedPlanNodes loaderPlan
        , installNodeKind node == "loaderProfile"
        ]
      metadataPlan = installPlanGraphTypedPlan (addInstanceMetadataTypedPlan testLayout loaderGraph)
      metadataRollbacks =
        [ installRollbackAction (installNodeRollback node)
        | node <- typedPlanNodes metadataPlan
        , installNodeKind node == "instanceMetadata"
        ]
      shaderGraph =
        downloadJobsInstallPlanGraph
          "minecraft-companion"
          "iris"
          [DownloadJob "modrinth mod iris" "https://example.com/iris.jar" "/tmp/mc/mods/iris.jar" (Just "irishash") (Just 64)]
      combinedProfilePlan =
        installPlanGraphTypedPlan (combineInstallPlanGraphs "minecraft-profile" "fabric-loader-0.19.2-26.1.2" [loaderGraph, shaderGraph])
      combinedStablePlan =
        installPlanGraphTypedPlan (combineInstallPlanGraphs "determinism-test" "stable" [assetGraph, shaderGraph])
      combinedStablePlanShuffled =
        installPlanGraphTypedPlan (combineInstallPlanGraphs "determinism-test" "stable" [shaderGraph, assetGraph])
      shaderDependsOn =
        concat
          [ installNodeDependsOn node
          | node <- typedPlanNodes combinedProfilePlan
          , installNodeKind node == "mod"
          ]
  assertEqual "loader profile typed node is added" True (not (null loaderProfileIds))
  assertEqual "loader profile rollback removes created profile" ["removeCreatedFile"] loaderProfileRollbacks
  assertEqual "metadata rollback removes final commit marker" ["removeCreatedFile"] metadataRollbacks
  assertEqual "shader companion depends on loader profile" True (not (null loaderProfileIds) && all (`elem` shaderDependsOn) loaderProfileIds)
  assertEqual "combined graph order is stable for unordered combines" (typedPlanFingerprint combinedStablePlan) (typedPlanFingerprint combinedStablePlanShuffled)
  assertTypedInstallPlanTypes
  assertLockfileSolver
  assertStructuredDiagnostics
  PropertyRunner.runProperties
  assertContentTypedInstallPlan
  assertInstallPlanExecutor
  assertContentUpdatePlan
  assertModpackTypedPlan
  assertModpackImportStaging
  assertEqual
    "launch request parses JVM args and window size"
    (Right (["-Dpanino.test=true"], Just 1280, Just 720))
    ( (\request -> (launchRequestJvmArgs request, launchRequestWindowWidth request, launchRequestWindowHeight request))
        <$> eitherDecode "{\"version\":\"1.20.1\",\"jvmArgs\":[\"-Dpanino.test=true\"],\"windowWidth\":1280,\"windowHeight\":720}"
    )
  let progress =
        TaskProgress
          { taskProgressTaskId = "task-1"
          , taskProgressPhaseId = "minecraft"
          , taskProgressPhaseTitle = "Download Minecraft files"
          , taskProgressPhaseIndex = 2
          , taskProgressPhaseCount = 5
          , taskProgressPhasePercent = Just 50
          , taskProgressOverallPercent = Just 40
          , taskProgressCompletedJobs = 4
          , taskProgressTotalJobs = 8
          , taskProgressCompletedBytes = 1024
          , taskProgressTotalBytes = 2048
          , taskProgressSpeedBytesPerSecond = 512
          , taskProgressMovingAverageSpeedBytesPerSecond = 640
          , taskProgressEtaSeconds = Just 2
          , taskProgressCurrentLabel = "libraries/example.jar"
          , taskProgressActiveWorkers = 2
          , taskProgressRetryCount = 1
          , taskProgressSourceHost = Just "https://libraries.minecraft.net"
          , taskProgressHosts = []
          , taskProgressThrottleReason = Just "stable"
          , taskProgressMultipart = Nothing
          }
  assertEqual
    "task progress json roundtrip"
    (Just progress)
    (decode (encode progress))
  assertEqual
    "content search request parses categories"
    (Right ["world-map"])
    (contentSearchCategories <$> eitherDecode "{\"source\":\"modrinth\",\"categories\":[\"world-map\"]}")
  assertEqual
    "modrinth category facet keeps type version loader filters"
    (Just "[[\"project_type:mod\"],[\"versions:26.1.2\"],[\"categories:fabric\"],[\"categories:worldgen\"]]")
    (modrinthFacets categorySearchQuery)
  assertEqual
    "modrinth category search query includes facets"
    True
    ("facets=" `isInfixOf` modrinthSearchQuery categorySearchQuery)
  assertEqual
    "curseforge category id query parameter"
    True
    ("categoryId=4321" `isInfixOf` curseForgeSearchQueryWithCategoryIds categorySearchQuery [4321])
  setEnv "PANINO_MODRINTH_API_BASE" "https://mirror.example"
  assertEqual
    "source override keeps official fallback"
    [ "https://mirror.example/v2/search"
    , "https://api.modrinth.com/v2/search"
    ]
    =<< resolveSourceUrls "https://api.modrinth.com/v2/search"
  setEnv "PANINO_MODRINTH_API_BASE" "https://mirror-a.example,https://mirror-b.example/"
  assertEqual
    "source override accepts mirror profiles"
    [ "https://mirror-a.example/v2/search"
    , "https://mirror-b.example/v2/search"
    , "https://api.modrinth.com/v2/search"
    ]
    =<< resolveSourceUrls "https://api.modrinth.com/v2/search"
  setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
  assertEqual
    "source override can disable official fallback"
    [ "https://mirror-a.example/v2/search"
    , "https://mirror-b.example/v2/search"
    ]
    =<< resolveSourceUrls "https://api.modrinth.com/v2/search"
  unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
  unsetEnv "PANINO_MODRINTH_API_BASE"
  setEnv "PANINO_MOJANG_LIBRARIES_BASE" "https://libraries.mirror.example/maven"
  assertEqual
    "source override rewrites Mojang libraries"
    [ "https://libraries.mirror.example/maven/org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1.jar"
    , "https://libraries.minecraft.net/org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1.jar"
    ]
    =<< resolveSourceUrls "https://libraries.minecraft.net/org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1.jar"
  unsetEnv "PANINO_MOJANG_LIBRARIES_BASE"
  setEnv "PANINO_MOJANG_RESOURCES_BASE" "https://resources.mirror.example/assets"
  assertEqual
    "source override rewrites Mojang assets"
    [ "https://resources.mirror.example/assets/aa/hash"
    , "https://resources.download.minecraft.net/aa/hash"
    ]
    =<< resolveSourceUrls "https://resources.download.minecraft.net/aa/hash"
  unsetEnv "PANINO_MOJANG_RESOURCES_BASE"
  setEnv "PANINO_HTTP_RETRY_COUNT" "0"
  assertEqual "metadata retry count accepts zero" 0 =<< metadataRetryCount
  setEnv "PANINO_HTTP_RETRY_COUNT" "12"
  assertEqual "metadata retry count clamps high values" 10 =<< metadataRetryCount
  setEnv "PANINO_HTTP_RETRY_COUNT" "invalid"
  assertEqual "metadata retry count falls back on invalid input" 3 =<< metadataRetryCount
  unsetEnv "PANINO_HTTP_RETRY_COUNT"
  assertEqual
    "source host key keeps scheme and authority"
    "https://api.modrinth.com"
    (sourceHostKey "https://api.modrinth.com/v2/search")
  assertEqual
    "fabric dependency preflight catches missing required mod"
    ( Right
        [ MissingModDependency
            { missingModFile = "iris.jar"
            , missingModId = "iris"
            , missingDependencyId = "sodium"
            }
        ]
    )
    ( missingFabricDependenciesFromManifests
        [ ( "iris.jar"
          , "{\"id\":\"iris\",\"depends\":{\"minecraft\":\">=1.20\",\"fabricloader\":\">=0.14\",\"sodium\":\"*\"}}"
          )
        ]
    )
  assertEqual
    "fabric dependency preflight accepts installed dependency"
    (Right [])
    ( missingFabricDependenciesFromManifests
        [ ( "iris.jar"
          , "{\"id\":\"iris\",\"depends\":{\"sodium\":\"*\"}}"
          )
        , ( "sodium.jar"
          , "{\"id\":\"sodium\"}"
          )
        ]
    )
  assertFabricApiNestedJarPreflight
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
  let shaPath = tempDir </> "panino-core-sha1-test.txt"
  BS8.writeFile shaPath "abc"
  assertEqual
    "streaming sha1"
    "a9993e364706816aba3e25717850c26c9cd0d89d"
    =<< sha1HexFile shaPath
  setEnv "PANINO_VERIFICATION_INDEX" tempDir
  recordVerifiedFile shaPath (Just "a9993e364706816aba3e25717850c26c9cd0d89d")
  flushVerificationIndex
  unsetEnv "PANINO_VERIFICATION_INDEX"
  removeFile shaPath
  assertDownloadRejects404 tempDir
  assertDownloadRetryOptions tempDir
  assertDownloadProgressCompletion tempDir
  assertDownloadProgressWaitsForUnknownTailJobs tempDir
  assertDownloadConcurrencyOptions tempDir
  assertMultipartDownload tempDir
  assertMultipartRangeGetFallback tempDir
  assertMultipartRangeIgnoredFallsBack tempDir
  assertDownloadCancellation tempDir
  assertEqual
    "variable substitution"
    "hello Steve"
    (substituteVariables (Map.fromList [("name", "Steve")]) "hello ${name}")
  let neoforgeLaunchArgs =
        buildJavaArguments
          testLayout
          testVersionJson
            { versionId = "neoforge-26.1.1.15-beta"
            , versionArguments =
                Just
                  VersionArguments
                    { versionGameArguments = []
                    , versionJvmArguments = [ArgLiteral ["-DlibraryDirectory=${library_directory}"]]
                    }
            }
          (classpathJars testLayout testVersionJson)
          LaunchProfile
            { profileVersion = "neoforge-26.1.1.15-beta"
            , profileMemoryMb = 4096
            , profileJavaPath = "java"
            , profileUsername = "Steve"
            , profileUuid = "00000000-0000-0000-0000-000000000000"
            , profileAccessToken = "0"
            , profileJvmArgs = []
            , profileJvmTuning = Nothing
            , profileWindowWidth = Nothing
            , profileWindowHeight = Nothing
            }
  assertEqual "NeoForge library_directory is substituted" True ("-DlibraryDirectory=/tmp/mc/libraries" `elem` neoforgeLaunchArgs)
  assertEqual "NeoForge library_directory literal is not leaked" False (any ("${library_directory}" `isInfixOf`) neoforgeLaunchArgs)
  assertEqual
    "empty rules allow"
    True
    (isAllowedByRules [])
  assertEqual
    "feature rule false by default"
    False
    (isAllowedByRules [Rule Allow Nothing (Map.fromList [("has_custom_resolution", True)])])

categorySearchQuery :: ContentSearchRequest
categorySearchQuery =
  ContentSearchRequest
    { contentSearchSource = "modrinth"
    , contentSearchText = "world"
    , contentSearchProjectTypes = ["mod"]
    , contentSearchCategories = ["world-map"]
    , contentSearchGameVersion = Just "26.1.2"
    , contentSearchLoaders = ["fabric"]
    , contentSearchSort = "relevance"
    , contentSearchOffset = 30
    , contentSearchLimit = 30
    , contentSearchCurseForgeApiKey = Nothing
    , contentSearchPrefetch = False
    }

assertLaunchTaskCompletesAfterProcessStart :: FilePath -> IO ()
assertLaunchTaskCompletesAfterProcessStart tempRoot = do
  let gameDir = tempRoot </> "panino-launch-task-terminal"
      historyPath = gameDir </> "task-history.json"
  exists <- doesDirectoryExist gameDir
  when exists (removeDirectoryRecursive gameDir)
  createDirectoryIfMissing True gameDir
  now <- getCurrentTime
  tasks <- newTVarIO Map.empty
  taskHandles <- newTVarIO Map.empty
  nextTaskId <- newTVarIO 1
  events <- newEventBus
  manager <- makeHttpManager
  processFinished <- newEmptyMVar
  hookCompleted <- newEmptyMVar
  let state =
        ServerState
          { stateSessionToken = "test-token"
          , stateStartedAt = now
          , stateDefaultGameDir = Just gameDir
          , stateTasks = tasks
          , stateTaskHistoryPath = historyPath
          , stateTaskHandles = taskHandles
          , stateNextTaskId = nextTaskId
          , stateEvents = events
          , stateHttpManager = manager
          , stateShutdown = pure ()
          }
  task <-
    startTaskWithGameDirContext state "launch" "test-version" (Just gameDir) $ \snapshot -> do
      layout <- mkLayout (Just gameDir)
      let hooks =
            LaunchHookSession
              { launchHookJvmArgs = []
              , completeLaunchHookSession = const (putMVar hookCompleted ())
              }
          launch =
            JavaProcessLaunch
              { javaLaunchProcessId = Just 123
              , pollJavaProcessExitCode = pure Nothing
              , waitJavaProcess = readMVar processFinished
              }
      observeStartedLaunchWithDelay 1000 state snapshot layout hooks launch
  taskState <- waitForTaskState state (taskSnapshotId task) TaskSucceeded 100
  latest <- Map.lookup (taskSnapshotId task) <$> readTVarIO (stateTasks state)
  assertEqual "launch task succeeds after Java process starts" (Just TaskSucceeded) taskState
  assertEqual
    "launch task terminal progress reaches 100"
    (Just 100)
    (maybe Nothing taskProgressOverallPercent (taskSnapshotProgress =<< latest))
  putMVar processFinished JavaRunResult { javaExitCode = ExitSuccess, javaStdout = "", javaStderr = "", javaMemorySamples = [] }
  assertEqual "launch background monitor completes hooks" True =<< waitForMVar hookCompleted 100

assertLaunchTaskFailsOnEarlyProcessExit :: FilePath -> IO ()
assertLaunchTaskFailsOnEarlyProcessExit tempRoot = do
  let gameDir = tempRoot </> "panino-launch-task-early-exit"
      historyPath = gameDir </> "task-history.json"
  exists <- doesDirectoryExist gameDir
  when exists (removeDirectoryRecursive gameDir)
  createDirectoryIfMissing True gameDir
  now <- getCurrentTime
  tasks <- newTVarIO Map.empty
  taskHandles <- newTVarIO Map.empty
  nextTaskId <- newTVarIO 1
  events <- newEventBus
  manager <- makeHttpManager
  hookCompleted <- newEmptyMVar
  let state =
        ServerState
          { stateSessionToken = "test-token"
          , stateStartedAt = now
          , stateDefaultGameDir = Just gameDir
          , stateTasks = tasks
          , stateTaskHistoryPath = historyPath
          , stateTaskHandles = taskHandles
          , stateNextTaskId = nextTaskId
          , stateEvents = events
          , stateHttpManager = manager
          , stateShutdown = pure ()
          }
  task <-
    startTaskWithGameDirContext state "launch" "test-version" (Just gameDir) $ \snapshot -> do
      layout <- mkLayout (Just gameDir)
      let hooks =
            LaunchHookSession
              { launchHookJvmArgs = []
              , completeLaunchHookSession = const (putMVar hookCompleted ())
              }
          launch =
            JavaProcessLaunch
              { javaLaunchProcessId = Just 456
              , pollJavaProcessExitCode = pure (Just (ExitFailure 1))
              , waitJavaProcess =
                  pure JavaRunResult
                    { javaExitCode = ExitFailure 1
                    , javaStdout = ""
                    , javaStderr = "quilt loader failed"
                    , javaMemorySamples = []
                    }
              }
      observeStartedLaunchWithDelay 1000 state snapshot layout hooks launch
  taskState <- waitForTaskState state (taskSnapshotId task) TaskFailed 100
  latest <- Map.lookup (taskSnapshotId task) <$> readTVarIO (stateTasks state)
  assertEqual "launch task fails when Java exits inside startup grace period" (Just TaskFailed) taskState
  assertEqual "early launch failure completes hooks" True =<< waitForMVar hookCompleted 100
  assertEqual
    "early launch failure records diagnostic"
    True
    (maybe False (not . null . taskSnapshotDiagnostics) latest)

waitForTaskState :: ServerState -> Text -> TaskState -> Int -> IO (Maybe TaskState)
waitForTaskState state taskId desired attempts
  | attempts <= 0 = pure Nothing
  | otherwise = do
      taskMap <- readTVarIO (stateTasks state)
      let current = taskSnapshotState <$> Map.lookup taskId taskMap
      case current of
        Just value | value == desired -> pure current
        Just TaskFailed -> pure current
        Just TaskCancelled -> pure current
        _ -> do
          threadDelay 20000
          waitForTaskState state taskId desired (attempts - 1)

waitForMVar :: MVar a -> Int -> IO Bool
waitForMVar mvar attempts
  | attempts <= 0 = pure False
  | otherwise = do
      value <- tryReadMVar mvar
      case value of
        Just _ -> pure True
        Nothing -> do
          threadDelay 20000
          waitForMVar mvar (attempts - 1)

assertLaunchHooksAreBestEffort :: FilePath -> IO ()
assertLaunchHooksAreBestEffort tempRoot = do
  let lockfileRoot = tempRoot </> "panino-launch-hook-lockfile"
  lockfileExists <- doesDirectoryExist lockfileRoot
  when lockfileExists (removeDirectoryRecursive lockfileRoot)
  lockfileLayout <- mkLayout (Just lockfileRoot)
  createDirectoryIfMissing True (minecraftRoot lockfileLayout </> ".panino")
  BL8.writeFile (minecraftRoot lockfileLayout </> ".panino" </> "panino-lock.json") "{bad-lockfile-json"
  runBestEffortLaunchChecks lockfileLayout testVersionJson
  lockfileHookLog <- BL8.readFile (minecraftRoot lockfileLayout </> "downloads" </> "launch-hooks.log")
  assertEqual "lockfile hook failure is logged but non-blocking" True ("lockfile_verify" `isInfixOf` BL8.unpack lockfileHookLog)

  let blockedRoot = tempRoot </> "panino-launch-hook-blocked-root"
  blockedRootIsDir <- doesDirectoryExist blockedRoot
  when blockedRootIsDir (removeDirectoryRecursive blockedRoot)
  BL8.writeFile blockedRoot "not a directory"
  blockedLayout <- mkLayout (Just blockedRoot)
  hooks <- beginLaunchHooks blockedLayout testVersionJson minimalLaunchRequest (recommendJvmTuning defaultJvmTuningRequest)
  assertEqual "performance hook failure falls back to no JVM args" [] (launchHookJvmArgs hooks)
  completeLaunchHookSession hooks JavaRunResult { javaExitCode = ExitSuccess, javaStdout = "", javaStderr = "", javaMemorySamples = [] }

minimalLaunchRequest :: LaunchRequest
minimalLaunchRequest =
  LaunchRequest
    { launchRequestVersion = "test-version"
    , launchRequestGameDir = Just "/tmp/panino-test"
    , launchRequestMemoryMb = Nothing
    , launchRequestJavaPath = Nothing
    , launchRequestInstanceId = Nothing
    , launchRequestLoader = Nothing
    , launchRequestMemoryPolicy = Nothing
    , launchRequestJvmProfile = Nothing
    , launchRequestCustomMemoryMb = Nothing
    , launchRequestUsername = Nothing
    , launchRequestUuid = Nothing
    , launchRequestAccessToken = Nothing
    , launchRequestJvmArgs = []
    , launchRequestCustomJvmArgs = []
    , launchRequestModCount = Nothing
    , launchRequestResourcePackCount = Nothing
    , launchRequestShaderPackCount = Nothing
    , launchRequestWindowWidth = Nothing
    , launchRequestWindowHeight = Nothing
    , launchRequestDownload = DownloadRuntimeOptions Nothing Nothing Nothing
    , launchRequestInstallBefore = Nothing
    }

assertTypedInstallPlanTypes :: IO ()
assertTypedInstallPlanTypes = do
  let assetIndexNode =
        InstallPlanNode
          { installNodeId = "asset-index"
          , installNodeKind = "assetIndex"
          , installNodeAction = "download"
          , installNodePhase = "metadata"
          , installNodeLabel = "Asset index"
          , installNodeTargetPath = Just "/tmp/mc/assets/indexes/26.json"
          , installNodeSourceUrls = ["https://example.com/index.json"]
          , installNodeSha1 = Just "abc"
          , installNodeSize = Just 128
          , installNodeRequired = True
          , installNodeDependsOn = []
          , installNodeVerifications =
              [ InstallVerification "hashKnown" "ok" Nothing
              , InstallVerification "urlAllowed" "ok" Nothing
              ]
          , installNodeRollback =
              InstallPlanRollbackAction
                { installRollbackAction = "removeCreatedFile"
                , installRollbackTargetPath = Just "/tmp/mc/assets/indexes/26.json"
                , installRollbackBackupPath = Nothing
          , installRollbackReason = Nothing
                }
          , installNodeBlockedReason = Nothing
          , installNodeDiagnostics = []
          }
      assetObjectNode =
        InstallPlanNode
          { installNodeId = "asset-object"
          , installNodeKind = "assetObject"
          , installNodeAction = "download"
          , installNodePhase = "assets"
          , installNodeLabel = "Asset object"
          , installNodeTargetPath = Just "/tmp/mc/assets/objects/ab/abc"
          , installNodeSourceUrls = ["https://example.com/objects/ab/abc"]
          , installNodeSha1 = Just "abc"
          , installNodeSize = Just 256
          , installNodeRequired = True
          , installNodeDependsOn = ["asset-index"]
          , installNodeVerifications =
              [ InstallVerification "dependencyResolved" "ok" Nothing
              , InstallVerification "sizeKnown" "ok" Nothing
              ]
          , installNodeRollback =
              InstallPlanRollbackAction
                { installRollbackAction = "removeCreatedFile"
                , installRollbackTargetPath = Just "/tmp/mc/assets/objects/ab/abc"
                , installRollbackBackupPath = Nothing
          , installRollbackReason = Nothing
                }
          , installNodeBlockedReason = Nothing
          , installNodeDiagnostics = []
          }
      assetEdge =
        InstallPlanEdge
          { installEdgeFrom = "asset-index"
          , installEdgeTo = "asset-object"
          , installEdgeKind = "requires"
          , installEdgeRequired = True
          }
      optionalEdge =
        InstallPlanEdge
          { installEdgeFrom = "asset-index"
          , installEdgeTo = "asset-object"
          , installEdgeKind = "after"
          , installEdgeRequired = False
          }
      basePlan nodes =
        basePlanWithEdges nodes [assetEdge]
      basePlanWithEdges nodes edges =
        TypedInstallPlan
          { typedPlanId = ""
          , typedPlanFingerprint = ""
          , typedPlanKind = "minecraft"
          , typedPlanTitle = "Minecraft install"
          , typedPlanTargetGameDir = Just "/tmp/mc"
          , typedPlanSource = Just "official"
          , typedPlanStatus = ""
          , typedPlanSummary = InstallPlanSummary 0 0 0 0 0 Nothing
          , typedPlanNodes = nodes
          , typedPlanEdges = edges
          , typedPlanWarnings = []
          , typedPlanBlockedReasons = []
          , typedPlanDiagnostics = []
          , typedPlanRollbackPolicy = "automatic"
          }
      planA = finalizeTypedInstallPlan (basePlan [assetIndexNode, assetObjectNode])
      planB = finalizeTypedInstallPlan (basePlan [assetObjectNode, assetIndexNode])
      blockedPlan =
        finalizeTypedInstallPlan $
          basePlan
            [ assetIndexNode
                { installNodeBlockedReason = Just "missing_url"
                , installNodeSourceUrls = []
                }
            ]
      noisyPlanA =
        finalizeTypedInstallPlan
          (basePlan [assetObjectNode, assetIndexNode])
            { typedPlanWarnings = ["z-warning", "a-warning", "z-warning"]
            , typedPlanBlockedReasons = ["z-blocked", "a-blocked", "z-blocked"]
            }
      noisyPlanB =
        finalizeTypedInstallPlan
          (basePlan [assetIndexNode, assetObjectNode])
            { typedPlanWarnings = ["a-warning", "z-warning"]
            , typedPlanBlockedReasons = ["a-blocked", "z-blocked"]
            }
      edgePlanA = finalizeTypedInstallPlan (basePlanWithEdges [assetIndexNode, assetObjectNode] [optionalEdge, assetEdge])
      edgePlanB = finalizeTypedInstallPlan (basePlanWithEdges [assetObjectNode, assetIndexNode] [assetEdge, optionalEdge])

  assertEqual "typed install plan fingerprint ignores node order" (typedPlanFingerprint planA) (typedPlanFingerprint planB)
  assertEqual "typed install plan id ignores node order" (typedPlanId planA) (typedPlanId planB)
  assertEqual "typed install plan canonical json ignores node order" (canonicalJson (toJSON planA)) (canonicalJson (toJSON planB))
  assertEqual "typed install plan fingerprint ignores edge order" (typedPlanFingerprint edgePlanA) (typedPlanFingerprint edgePlanB)
  assertEqual "typed install plan warnings are sorted and deduped" ["a-warning", "z-warning"] (typedPlanWarnings noisyPlanA)
  assertEqual "typed install plan blocked reasons are sorted and deduped" ["a-blocked", "z-blocked"] (typedPlanBlockedReasons noisyPlanA)
  assertEqual "typed install plan diagnostic order is canonical" (map diagnosticCode (typedPlanDiagnostics noisyPlanA)) (map diagnosticCode (typedPlanDiagnostics noisyPlanB))
  assertEqual "typed install plan default status" "ready" (typedPlanStatus planA)
  assertEqual "typed install plan summarizes downloads" (Just 384) (installSummaryEstimatedBytes (typedPlanSummary planA))
  assertEqual "typed install plan json roundtrips" (Right planA) (eitherDecode (encode planA))
  assertEqual "typed install plan blocked status" "blocked" (typedPlanStatus blockedPlan)
  assertEqual "typed install plan blocked reason" ["missing_url"] (typedPlanBlockedReasons blockedPlan)
  assertEqual "typed install plan blocked diagnostic" True (not (null (typedPlanDiagnostics blockedPlan)))

assertLockfileSolver :: IO ()
assertLockfileSolver = do
  manager <- makeHttpManager
  tempDir <- getTemporaryDirectory
  let gameDir = tempDir </> "panino-lockfile-solver-test"
  gameDirExists <- doesDirectoryExist gameDir
  when gameDirExists (removeDirectoryRecursive gameDir)
  let solveCacheDir = lockfileSolveCacheGameDir gameDir
  assertEqual
    "lockfile solve service cache uses parent-scoped Panino cache"
    (takeDirectory gameDir </> ".panino" </> "lockfile-solve-cache")
    solveCacheDir
  assertEqual
    "lockfile solve service cache stays outside target game dir"
    False
    ((normalise gameDir <> "/") `isPrefixOf` (normalise solveCacheDir <> "/"))
  let fabricApi =
        testLockfilePackage
          "fabric-api"
          "Fabric API"
          "fabric-api-version"
          "fabric-api.jar"
          "mods/fabric-api.jar"
          "a9993e364706816aba3e25717850c26c9cd0d89d"
          []
      sodium =
        testLockfilePackage
          "sodium"
          "Sodium"
          "sodium-version"
          "sodium.jar"
          "mods/sodium.jar"
          "589c22335a381f122d129225f5c0ba3056ed5811"
          []
      iris =
        testLockfilePackage
          "iris"
          "Iris"
          "iris-version"
          "iris.jar"
          "mods/iris.jar"
          "0bbee1b07a248e27c83fc3d5951213c1e8aef20f"
          [ testPackageConstraint "iris" "fabric-api" "requires" True
          , testPackageConstraint "iris" "sodium" "optional" False
          ]
      existingLockfile = testPaninoLockfile gameDir [fabricApi, sodium]
      request = testLockfileSolveRequest gameDir [iris] (Just existingLockfile)
      keepLockedRequest =
        (testLockfileSolveRequest gameDir [iris] (Just existingLockfile))
          { solveRequestUpdatePolicy = "keepLocked" }
      requestShuffled =
        testLockfileSolveRequest
          gameDir
          [iris]
          (Just (testPaninoLockfile gameDir [sodium, fabricApi]))
      rootOrderResult =
        solveLockfile
          (testLockfileSolveRequest gameDir [iris, sodium] (Just (testPaninoLockfile gameDir [fabricApi])))
      rootOrderResultShuffled =
        solveLockfile
          (testLockfileSolveRequest gameDir [sodium, iris] (Just (testPaninoLockfile gameDir [fabricApi])))
      irisNoisyA =
        iris
          { resolvedPackageDownloadUrls = ["https://mirror-b.example/iris.jar", "https://mirror-a.example/iris.jar"]
          , resolvedPackageDependencies = reverse (resolvedPackageDependencies iris)
          , resolvedPackageSelectedBecause = ["z-input", "a-input"]
          }
      irisNoisyB =
        iris
          { resolvedPackageDownloadUrls = ["https://mirror-a.example/iris.jar", "https://mirror-b.example/iris.jar"]
          , resolvedPackageDependencies = resolvedPackageDependencies iris
          , resolvedPackageSelectedBecause = ["a-input", "z-input"]
          }
      noisyResult =
        solveLockfile
          (testLockfileSolveRequest gameDir [irisNoisyA] (Just existingLockfile))
      noisyResultShuffled =
        solveLockfile
          (testLockfileSolveRequest gameDir [irisNoisyB] (Just (testPaninoLockfile gameDir [sodium, fabricApi])))
      result = solveLockfile request
      resultShuffled = solveLockfile requestShuffled

  assertEqual "lockfile solver succeeds with required dependency" "ready" (solverResultStatus result)
  assertEqual "lockfile solver typed plan is ready" "ready" (typedPlanStatus (solverResultTypedPlan result))
  case (solverResultLockfile result, solverResultLockfile resultShuffled) of
    (Just lockfile, Just shuffledLockfile) -> do
      assertEqual "lockfile solver includes required dependency" ["fabric-api", "iris"] (map resolvedPackageId (lockfilePackages lockfile))
      assertEqual "lockfile solver omits optional dependency by default" False ("sodium" `elem` map resolvedPackageId (lockfilePackages lockfile))
      assertEqual "lockfile fingerprint is deterministic" (lockfileFingerprint lockfile) (lockfileFingerprint shuffledLockfile)
      createDirectoryIfMissing True (gameDir </> "mods")
      BS8.writeFile (gameDir </> "mods" </> "fabric-api.jar") "wrong"
      BS8.writeFile (gameDir </> "mods" </> "z-extra.jar") "extra"
      BS8.writeFile (gameDir </> "mods" </> "a-extra.jar") "extra"
      verifyResponse <- verifyLockfile gameDir lockfile
      verifyResponseShuffled <-
        verifyLockfile
          gameDir
          lockfile
            { lockfilePackages = reverse (lockfilePackages lockfile)
            , lockfileFiles = reverse (lockfileFiles lockfile)
            }
      assertEqual "lockfile verify reports missing files" True (not (null (verifyResponseMissingFiles verifyResponse)))
      assertEqual "lockfile verify reports hash mismatch" True (not (null (verifyResponseHashMismatches verifyResponse)))
      assertEqual
        "lockfile verify extra files are sorted"
        [Just "mods/a-extra.jar", Just "mods/z-extra.jar"]
        (map verifyIssueTargetPath (verifyResponseExtraFiles verifyResponse))
      assertEqual
        "lockfile verify ignores lockfile array order"
        (canonicalJson (toJSON verifyResponse))
        (canonicalJson (toJSON verifyResponseShuffled))
      assertEqual "lockfile verify creates repair plan" True (isJust (verifyResponseRepairPlan verifyResponse))
      assertEqual "lockfile launch verify blocks missing or mismatched files" True (not (null (lockfileLaunchBlockedReasons verifyResponse)))
      assertEqual
        "lockfile apply rejects stale solver fingerprint"
        (Left "solver_fingerprint_mismatch")
        ( lockfileApplyReadyLockfile
            LockfileApplyRequest
              { applyRequestTargetGameDir = gameDir
              , applyRequestSolverFingerprint = "stale-fingerprint"
              , applyRequestResult = result
              }
        )
      let applyGameDir = tempDir </> "panino-lockfile-apply-test"
      applyGameDirExists <- doesDirectoryExist applyGameDir
      when applyGameDirExists (removeDirectoryRecursive applyGameDir)
      testWithApplication
        ( pure $ \_ respond ->
            respond (responseLBS status200 [(hContentType, "application/octet-stream"), ("Content-Length", "10")] "downloaded")
        )
        $ \port -> do
          let downloadedPackage =
                (testLockfilePackage "downloaded" "Downloaded" "downloaded-version" "downloaded.jar" "mods/downloaded.jar" "47265105ec5517e46aec2ed5310c177e1e811af8" [])
                  { resolvedPackageDownloadUrls = [Text.pack ("http://127.0.0.1:" <> show port <> "/downloaded.jar")]
                  , resolvedPackageSize = Just 10
                  }
              applyResult = solveLockfile (testLockfileSolveRequest applyGameDir [downloadedPackage] Nothing)
          execution <-
            executeInstallPlan
              (solverResultTypedPlan applyResult)
              (runLockfilePlanNode manager)
              rollbackLockfilePlanNode
              (\_ -> pure ())
          assertEqual "lockfile apply runner executes plan downloads" "succeeded" (installExecutionStatus execution)
          written <- BS8.readFile (applyGameDir </> "mods" </> "downloaded.jar")
          assertEqual "lockfile apply runner writes downloaded file" "downloaded" written
          case solverResultLockfile applyResult of
            Just appliedLockfile -> do
              appliedVerify <- verifyLockfile applyGameDir appliedLockfile
              assertEqual "lockfile apply runner produces verifiable files" "locked" (verifyResponseStatus appliedVerify)
            Nothing ->
              fail "lockfile apply runner solve did not produce lockfile"
    _ ->
      fail "lockfile solver did not produce lockfiles"
  case (solverResultLockfile rootOrderResult, solverResultLockfile rootOrderResultShuffled) of
    (Just lockfile, Just shuffledLockfile) ->
      assertEqual "lockfile root order does not change fingerprint" (lockfileFingerprint lockfile) (lockfileFingerprint shuffledLockfile)
    _ ->
      fail "lockfile root-order solve did not produce lockfiles"
  assertEqual "lockfile root order does not change canonical solver output" (canonicalJson (toJSON rootOrderResult)) (canonicalJson (toJSON rootOrderResultShuffled))
  case (solverResultLockfile noisyResult, solverResultLockfile noisyResultShuffled) of
    (Just lockfile, Just shuffledLockfile) ->
      assertEqual "lockfile package field order does not change fingerprint" (lockfileFingerprint lockfile) (lockfileFingerprint shuffledLockfile)
    _ ->
      fail "lockfile noisy solve did not produce lockfiles"
  assertEqual "lockfile package field order does not change typed plan" (typedPlanFingerprint (solverResultTypedPlan noisyResult)) (typedPlanFingerprint (solverResultTypedPlan noisyResultShuffled))
  assertEqual "lockfile changeset removes unselected relock package" ["sodium"] (map lockfileChangePackageId (changesetRemove (solverResultChangeset result)))
  assertEqual "lockfile explain keeps optional dependency out of plan" True (not (null (explainRejectedCandidates (solverResultExplain result))))
  assertEqual
    "lockfile keepLocked retains existing packages"
    True
    ( maybe
        False
        (\lockfile -> "sodium" `elem` map resolvedPackageId (lockfilePackages lockfile))
        (solverResultLockfile (solveLockfile keepLockedRequest))
    )
  let lithium =
        testLockfilePackage
          "lithium"
          "Lithium"
          "lithium-version"
          "lithium.jar"
          "mods/lithium.jar"
          "7777777777777777777777777777777777777777"
          []
      updatePackage package version sha1 =
        package
          { resolvedPackageCoordinate =
              (resolvedPackageCoordinate package)
                { coordinateVersionId = Just version
                }
          , resolvedPackageVersionName = Just version
          , resolvedPackageHashes = Map.fromList [("sha1", sha1)]
          }
      fabricApiNew =
        updatePackage fabricApi "fabric-api-new-version" "2222222222222222222222222222222222222222"
      sodiumNew =
        (updatePackage sodium "sodium-new-version" "3333333333333333333333333333333333333333")
          { resolvedPackageDependencies = [testPackageConstraint "sodium" "fabric-api" "requires" True]
          }
      selectedUpdateResult =
        solveLockfile
          ( (testLockfileSolveRequest gameDir [sodiumNew, fabricApiNew] (Just (testPaninoLockfile gameDir [fabricApi, sodium, lithium])))
              { solveRequestUpdatePolicy = "updateSelected"
              }
          )
      selectedUpdateVersions =
        [ (resolvedPackageId package, coordinateVersionId (resolvedPackageCoordinate package))
        | package <- maybe [] lockfilePackages (solverResultLockfile selectedUpdateResult)
        ]
  assertEqual
    "lockfile updateSelected updates selected package and required dependency only"
    [("fabric-api", Just "fabric-api-new-version"), ("lithium", Just "lithium-version"), ("sodium", Just "sodium-new-version")]
    selectedUpdateVersions
  assertEqual
    "lockfile updateSelected changeset replaces selected package and dependency"
    ["fabric-api", "sodium"]
    (map lockfileChangePackageId (changesetReplace (solverResultChangeset selectedUpdateResult)))
  assertEqual
    "lockfile updateSelected keeps unselected packages locked"
    ["lithium"]
    (map lockfileChangePackageId (changesetKeep (solverResultChangeset selectedUpdateResult)))

  let sodiumSafeNew =
        (updatePackage sodium "sodium-safe-new-version" "4444444444444444444444444444444444444444")
          { resolvedPackageDependencies = []
          }
      sodiumUnsafeNew =
        sodiumSafeNew
          { resolvedPackageCoordinate =
              (resolvedPackageCoordinate sodiumSafeNew)
                { coordinateVersionId = Just "sodium-unsafe-new-version"
                }
          , resolvedPackageVersionName = Just "sodium-unsafe-new-version"
          , resolvedPackageGameVersions = ["1.20.1"]
          }
      updateAllSafeResult =
        solveLockfile
          ( (testLockfileSolveRequest gameDir [sodiumSafeNew] (Just (testPaninoLockfile gameDir [sodium])))
              { solveRequestUpdatePolicy = "updateAllSafe"
              }
          )
      unsafeUpdateAllSafeResult =
        solveLockfile
          ( (testLockfileSolveRequest gameDir [sodiumUnsafeNew] (Just (testPaninoLockfile gameDir [sodium])))
              { solveRequestUpdatePolicy = "updateAllSafe"
              }
          )
  assertEqual
    "lockfile updateAllSafe updates compatible candidates"
    [("sodium", Just "sodium-safe-new-version")]
    [ (resolvedPackageId package, coordinateVersionId (resolvedPackageCoordinate package))
    | package <- maybe [] lockfilePackages (solverResultLockfile updateAllSafeResult)
    ]
  assertEqual
    "lockfile updateAllSafe keeps existing package when update breaks Minecraft compatibility"
    [("sodium", Just "sodium-version")]
    [ (resolvedPackageId package, coordinateVersionId (resolvedPackageCoordinate package))
    | package <- maybe [] lockfilePackages (solverResultLockfile unsafeUpdateAllSafeResult)
    ]

  let baseManualJar =
        testLockfilePackage "local-manual" "Local Manual" "manual-version" "local-manual.jar" "mods/local-manual.jar" "7777777777777777777777777777777777777777" []
      localManualJar =
        baseManualJar
          { resolvedPackageCoordinate =
              (resolvedPackageCoordinate baseManualJar)
                { coordinateSource = "local"
                }
          , resolvedPackageDownloadUrls = []
          }
      localManualResult =
        solveLockfile
          ( (testLockfileSolveRequest gameDir [] Nothing)
              { solveRequestManualPackages = [localManualJar]
              }
          )
  assertEqual
    "lockfile local manual jar enters manual entries"
    ["local-manual"]
    (maybe [] (map resolvedPackageId . lockfileManualEntries) (solverResultLockfile localManualResult))
  assertEqual
    "lockfile local manual jar uses manual changeset"
    ["local-manual"]
    (map lockfileChangePackageId (changesetManual (solverResultChangeset localManualResult)))

  let roomSubset =
        roomRequiredLockSubset (testPaninoLockfile gameDir [fabricApi, sodium, localManualJar])
      roomLocalLockfile =
        testPaninoLockfile gameDir [fabricApi, lithium]
      roomTargetLockfile =
        testPaninoLockfile gameDir [fabricApiNew, sodium]
      roomDiff =
        diffLockfiles roomLocalLockfile (roomRequiredLockSubset roomTargetLockfile)
      roomRepairPlan =
        roomLockRepairPlan gameDir roomLocalLockfile roomTargetLockfile
      roomRepairActions =
        [ (installNodeLabel node, installNodeAction node)
        | node <- typedPlanNodes roomRepairPlan
        ]
  assertEqual
    "room required lock subset excludes local manual files"
    ["fabric-api", "sodium"]
    (map resolvedPackageId (lockfilePackages roomSubset))
  assertEqual "room lock diff reports missing room package" ["sodium"] (map lockfileChangePackageId (changesetAdd roomDiff))
  assertEqual "room lock diff reports version difference" ["fabric-api"] (map lockfileChangePackageId (changesetReplace roomDiff))
  assertEqual "room lock diff reports local extra package" ["lithium"] (map lockfileChangePackageId (changesetRemove roomDiff))
  assertEqual "room lock repair plan is executable" "ready" (typedPlanStatus roomRepairPlan)
  assertEqual
    "room lock repair plan downloads, replaces and deletes"
    True
    (("Sodium", "download") `elem` roomRepairActions && ("Fabric API", "replace") `elem` roomRepairActions && ("Lithium", "delete") `elem` roomRepairActions)

  let missingDependencyResult =
        solveLockfile
          (testLockfileSolveRequest gameDir [iris] Nothing)
  assertEqual "lockfile missing required dependency blocks solve" "blocked" (solverResultStatus missingDependencyResult)
  assertEqual "lockfile blocked solve has blocked typed plan" "blocked" (typedPlanStatus (solverResultTypedPlan missingDependencyResult))
  assertEqual "lockfile missing dependency reason" True ("solver_no_candidate:fabric-api" `elem` solverResultBlockedReasons missingDependencyResult)

  let pathConflictA = testLockfilePackage "path-a" "Path A" "path-a-version" "path-a.jar" "mods/shared.jar" "a9993e364706816aba3e25717850c26c9cd0d89d" []
      pathConflictB = testLockfilePackage "path-b" "Path B" "path-b-version" "path-b.jar" "mods/shared.jar" "589c22335a381f122d129225f5c0ba3056ed5811" []
      duplicateA =
        withPackageSlug
          "duplicate-mod"
          (testLockfilePackage "duplicate-a" "Duplicate A" "duplicate-a-version" "duplicate-a.jar" "mods/duplicate-a.jar" "a9993e364706816aba3e25717850c26c9cd0d89d" [])
      duplicateB =
        withPackageSlug
          "duplicate-mod"
          (testLockfilePackage "duplicate-b" "Duplicate B" "duplicate-b-version" "duplicate-b.jar" "mods/duplicate-b.jar" "589c22335a381f122d129225f5c0ba3056ed5811" [])
      incompatibleA =
        testLockfilePackage "incompatible-a" "Incompatible A" "incompatible-a-version" "incompatible-a.jar" "mods/incompatible-a.jar" "a9993e364706816aba3e25717850c26c9cd0d89d" []
      incompatibleB =
        (testLockfilePackage "incompatible-b" "Incompatible B" "incompatible-b-version" "incompatible-b.jar" "mods/incompatible-b.jar" "589c22335a381f122d129225f5c0ba3056ed5811" [])
          { resolvedPackageConflicts = [testPackageConstraint "incompatible-b" "incompatible-a" "incompatible" True] }
      javaMajorPackage =
        (testLockfilePackage "java-required" "Java Required" "java-required-version" "java-required.jar" "mods/java-required.jar" "7777777777777777777777777777777777777777" [])
          { resolvedPackageJavaMajor = Just 21 }
      pathConflictResult = solveLockfile (testLockfileSolveRequest gameDir [pathConflictA, pathConflictB] Nothing)
      duplicateResult = solveLockfile (testLockfileSolveRequest gameDir [duplicateA, duplicateB] Nothing)
      incompatibleResult = solveLockfile (testLockfileSolveRequest gameDir [incompatibleA, incompatibleB] Nothing)
      javaMajorResult =
        solveLockfile
          ( (testLockfileSolveRequest gameDir [javaMajorPackage] Nothing)
              { solveRequestJavaPolicy = Just (object ["javaMajor" .= (17 :: Int)])
              }
          )
  assertEqual "lockfile same path different hash blocks solve" True ("solver_conflict" `elem` map solverConflictCode (solverResultConflicts pathConflictResult))
  assertEqual "lockfile duplicate mod id blocks solve" True ("solver_duplicate_mod_id" `elem` map solverConflictCode (solverResultConflicts duplicateResult))
  assertEqual "lockfile incompatible dependency blocks solve" True ("solver_conflict" `elem` map solverConflictCode (solverResultConflicts incompatibleResult))
  assertEqual "lockfile Java major mismatch blocks solve" True ("solver_no_candidate" `elem` map solverConflictCode (solverResultConflicts javaMajorResult))

  let packageA =
        testLockfilePackage
          "cycle-a"
          "Cycle A"
          "cycle-a-version"
          "cycle-a.jar"
          "mods/cycle-a.jar"
          "a9993e364706816aba3e25717850c26c9cd0d89d"
          [testPackageConstraint "cycle-a" "cycle-b" "requires" True]
      packageB =
        testLockfilePackage
          "cycle-b"
          "Cycle B"
          "cycle-b-version"
          "cycle-b.jar"
          "mods/cycle-b.jar"
          "589c22335a381f122d129225f5c0ba3056ed5811"
          [testPackageConstraint "cycle-b" "cycle-a" "requires" True]
      cycleResult =
        solveLockfile
          (testLockfileSolveRequest gameDir [packageA] (Just (testPaninoLockfile gameDir [packageB])))
  assertEqual "lockfile dependency cycle does not recurse forever" True ("solver_cycle_detected:cycle-a" `elem` solverResultWarnings cycleResult)

testLockfileSolveRequest :: FilePath -> [ResolvedPackage] -> Maybe PaninoLockfile -> LockfileSolveRequest
testLockfileSolveRequest gameDir roots existingLockfile =
  LockfileSolveRequest
    { solveRequestMode = "install"
    , solveRequestTargetGameDir = gameDir
    , solveRequestMinecraftVersion = Just "1.21.5"
    , solveRequestLoader = Just "fabric"
    , solveRequestLoaderVersion = Just "0.16.10"
    , solveRequestJavaPolicy = Nothing
    , solveRequestShaderLoader = Just "iris"
    , solveRequestSourceType = Nothing
    , solveRequestSourcePath = Nothing
    , solveRequestIncludePerformancePack = False
    , solveRequestRoots = roots
    , solveRequestExistingLockfile = existingLockfile
    , solveRequestUpdatePolicy = "relock"
    , solveRequestSourcePolicy = Just "modrinth"
    , solveRequestCurseForgeApiKey = Nothing
    , solveRequestIncludeOptionalDependencies = False
    , solveRequestSelectedOptionalDependencies = []
    , solveRequestIgnoredDependencies = []
    , solveRequestPinnedPackages = []
    , solveRequestManualPackages = []
    }

testLockfilePackage :: Text -> Text -> Text -> Text -> FilePath -> Text -> [PackageConstraint] -> ResolvedPackage
testLockfilePackage packageId name releaseIdText fileNameText targetPath sha1 dependencies =
  ResolvedPackage
    { resolvedPackageId = packageId
    , resolvedPackageCoordinate =
        PackageCoordinate
          { coordinateSource = "modrinth"
          , coordinateProjectId = Just packageId
          , coordinateVersionId = Just releaseIdText
          , coordinateFileId = Just fileNameText
          , coordinateSlug = Just packageId
          , coordinateName = Just name
          , coordinateKind = "mod"
          }
    , resolvedPackageDisplayName = name
    , resolvedPackageVersionName = Just releaseIdText
    , resolvedPackageFileName = Just fileNameText
    , resolvedPackageTargetPath = Just targetPath
    , resolvedPackageHashes = Map.fromList [("sha1", sha1)]
    , resolvedPackageSize = Just 123
    , resolvedPackageDownloadUrls = ["https://cdn.modrinth.example/" <> fileNameText]
    , resolvedPackageGameVersions = ["1.21.5"]
    , resolvedPackageLoaders = ["fabric"]
    , resolvedPackageJavaMajor = Nothing
    , resolvedPackageSide = Just "client"
    , resolvedPackageSelectedBecause = []
    , resolvedPackageLocked = False
    , resolvedPackagePinReason = Nothing
    , resolvedPackageDependencies = dependencies
    , resolvedPackageConflicts = []
    , resolvedPackageSourceSnapshot = Just "test"
    }

withPackageSlug :: Text -> ResolvedPackage -> ResolvedPackage
withPackageSlug slug package =
  package
    { resolvedPackageCoordinate =
        (resolvedPackageCoordinate package)
          { coordinateSlug = Just slug
          }
    }

testPackageConstraint :: Text -> Text -> Text -> Bool -> PackageConstraint
testPackageConstraint sourcePackage targetPackage relation required =
  PackageConstraint
    { constraintId = sourcePackage <> "-" <> relation <> "-" <> targetPackage
    , constraintSourcePackage = Just sourcePackage
    , constraintTargetPackageId = Just targetPackage
    , constraintTargetKind = "mod"
    , constraintRelation = relation
    , constraintMinecraftVersions = ["1.21.5"]
    , constraintLoaders = ["fabric"]
    , constraintJavaMajor = Nothing
    , constraintSide = Just "client"
    , constraintRequired = required
    , constraintReason = sourcePackage <> " " <> relation <> " " <> targetPackage
    }

testPaninoLockfile :: FilePath -> [ResolvedPackage] -> PaninoLockfile
testPaninoLockfile gameDir packages =
  PaninoLockfile
    { lockfileVersion = 1
    , lockfileSolverVersion = "test"
    , lockfileFingerprint = ""
    , lockfileCreatedAt = Nothing
    , lockfileUpdatedAt = Nothing
    , lockfileTargetGameDir = Just gameDir
    , lockfileMinecraft = Just "1.21.5"
    , lockfileJava = Nothing
    , lockfileLoader = Nothing
    , lockfileShaderLoader = Nothing
    , lockfileRoots = []
    , lockfilePackages = packages
    , lockfileFiles = mapMaybe testLockfileFile packages
    , lockfileConstraints = concatMap resolvedPackageDependencies packages
    , lockfileOverrides = []
    , lockfileSourceSnapshots = []
    , lockfileManualEntries = []
    , lockfileWarnings = []
    }

testLockfileFile :: ResolvedPackage -> Maybe LockfileFile
testLockfileFile package = do
  targetPath <- resolvedPackageTargetPath package
  packageFileName <- resolvedPackageFileName package
  pure
    LockfileFile
      { lockfileFilePackageId = resolvedPackageId package
      , lockfileFileName = packageFileName
      , lockfileFileTargetPath = targetPath
      , lockfileFileHashes = resolvedPackageHashes package
      , lockfileFileSize = resolvedPackageSize package
      , lockfileFileDownloadUrls = resolvedPackageDownloadUrls package
      , lockfileFileKind = coordinateKind (resolvedPackageCoordinate package)
      }

assertStructuredDiagnostics :: IO ()
assertStructuredDiagnostics = do
  let input =
        FailureInput
          { failurePhase = "download"
          , failureOperation = "install"
          , failureExceptionText = "HttpException request failed access_token=secret-token"
          , failureContext = [("url", "https://meta.fabricmc.net/v2/versions/loader")]
          , failureTaskId = Just "install-1"
          , failurePlanId = Just "plan-1"
          , failureSource = Nothing
          }
      diagnostic = classifyFailure input
      blockedDiagnostic = diagnosticFromBlockedReason "preflight" "loader" "shader_release_not_found:iris 1.21.5 fabric"
      blockedPreflight =
        blockedLoaderInstallPreflightResponse
          LoaderInstallPreflightRequest
            { preflightMinecraftVersion = "1.21.9"
            , preflightLoader = Just "fabric"
            , preflightLoaderVersion = Nothing
            , preflightShaderLoader = Just "iris"
            , preflightShaderVersion = Nothing
            , preflightGameDir = Just "/tmp/panino-preflight-target"
            , preflightJavaExecutable = Nothing
            , preflightSourceProfile = Nothing
            }
          diagnostic
      redactedSample =
        redactedText $
          Text.unlines
            [ "Authorization: Bearer bearer-secret"
            , "Authorization: Basic basic-secret"
            , "Cookie: sid=cookie-secret"
            , "Set-Cookie: sid=set-cookie-secret"
            , "X-Api-Key: api-key-secret"
            , "X-Auth-Token: auth-token-secret"
            , "X-Ms-Token: ms-secret"
            , "https://example.test/download?sig=url-secret&X-Amz-Signature=aws-secret&AWSAccessKeyId=key-secret"
            , "/Users/sen/Library/Application Support/Panino Launcher"
            , "file:///Users/sen/Downloads/panino.log"
            , "{\"sessionToken\":\"json-secret\",\"clientSecret\":\"client-secret\"}"
            ]
      redactedEvidenceJson =
        BL8.unpack (encode (DiagnosticEvidence "sessionToken" "evidence-secret" False))
  assertEqual "network diagnostic code" "network_error" (diagnosticCode diagnostic)
  assertEqual "diagnostic phase is preserved" "download" (diagnosticPhase diagnostic)
  assertEqual "diagnostic has action" True (not (Text.null (diagnosticActionKind (diagnosticAction diagnostic))))
  assertEqual "diagnostic redacts developer detail" True (maybe False ("<redacted>" `Text.isInfixOf`) (diagnosticDeveloperDetail diagnostic))
  assertEqual "diagnostic redacts Authorization Bearer" False ("bearer-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts Authorization Basic" False ("basic-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts cookies" False ("cookie-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts API key headers" False ("api-key-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts auth token headers" False ("auth-token-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts X-MS headers" False ("ms-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts URL query signatures" False ("url-secret" `Text.isInfixOf` redactedSample || "aws-secret" `Text.isInfixOf` redactedSample || "key-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts local user paths" False ("/Users/sen" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts JSON token fields" False ("json-secret" `Text.isInfixOf` redactedSample || "client-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic evidence redacts sensitive key values" False ("evidence-secret" `isInfixOf` redactedEvidenceJson)
  assertEqual "diagnostic evidence marks sensitive keys redacted" True ("\"redacted\":true" `isInfixOf` redactedEvidenceJson)
  assertEqual "blocked reason maps code" "shader_release_not_found" (diagnosticCode blockedDiagnostic)
  assertEqual "blocked reason maps action" "switchLoader" (diagnosticActionKind (diagnosticAction blockedDiagnostic))
  assertEqual "preflight exception is blocked response" "blocked" (preflightStatus blockedPreflight)
  assertEqual "preflight exception keeps diagnostic" (Just diagnostic) (preflightResponseDiagnostic blockedPreflight)
  assertEqual "preflight exception typed plan blocked" "blocked" (typedPlanStatus (preflightResponseTypedPlan blockedPreflight))

assertContentTypedInstallPlan :: IO ()
assertContentTypedInstallPlan = do
  let mainFile =
        ContentInstallFile
          { contentFileName = "sodium.jar"
          , contentFileUrl = "https://cdn.modrinth.com/sodium.jar"
          , contentFileSha1 = Just "mainsha"
          , contentFileSize = Just 10
          , contentFilePrimary = Just True
          }
      dependencyFile =
        ContentInstallFile
          { contentFileName = "fabric-api.jar"
          , contentFileUrl = "https://cdn.modrinth.com/fabric-api.jar"
          , contentFileSha1 = Just "depsha"
          , contentFileSize = Just 20
          , contentFilePrimary = Just True
          }
      mainPlanFile =
        ContentInstallPlanFile
          { contentPlanFileName = "sodium.jar"
          , contentPlanTargetPath = "/tmp/mc/mods/sodium.jar"
          , contentPlanFileSize = Just 10
          , contentPlanFileSha1 = Just "mainsha"
          , contentPlanFileAction = "replace"
          , contentPlanFilePrimary = True
          }
      dependencyPlanFile =
        ContentInstallPlanFile
          { contentPlanFileName = "fabric-api.jar"
          , contentPlanTargetPath = "/tmp/mc/mods/fabric-api.jar"
          , contentPlanFileSize = Just 20
          , contentPlanFileSha1 = Just "depsha"
          , contentPlanFileAction = "download"
          , contentPlanFilePrimary = True
          }
      requiredDependency =
        ContentInstallDependency
          { contentDependencyProjectId = Just "fabric-api"
          , contentDependencyVersionId = Just "dep-version"
          , contentDependencySource = Just "modrinth"
          , contentDependencyName = "Fabric API"
          , contentDependencyRequired = True
          , contentDependencyInstalled = Just True
          , contentDependencySha1 = Just "depsha"
          }
      optionalDependency =
        ContentInstallDependency
          { contentDependencyProjectId = Just "lambdynamiclights"
          , contentDependencyVersionId = Nothing
          , contentDependencySource = Just "modrinth"
          , contentDependencyName = "LambDynamicLights"
          , contentDependencyRequired = False
          , contentDependencyInstalled = Nothing
          , contentDependencySha1 = Nothing
          }
      request =
        ContentInstallRequest
          { contentInstallSource = "modrinth"
          , contentInstallProjectId = Just "sodium"
          , contentInstallProjectTitle = "Sodium"
          , contentInstallProjectType = Just "mod"
          , contentInstallReleaseId = "main-version"
          , contentInstallGameDir = Just "/tmp/mc"
          , contentInstallTargetSubdir = "mods"
          , contentInstallFiles = [mainFile]
          , contentInstallDependencies = [requiredDependency, optionalDependency]
          , contentInstallGameVersions = ["26.1.2"]
          , contentInstallLoaders = ["fabric"]
          , contentInstallInstances = []
          , contentInstallDownload = DownloadRuntimeOptions Nothing Nothing Nothing
          }
      typedPlan =
        ContentRoutes.contentTypedInstallPlan
          request
          "/tmp/mc/mods"
          [mainFile, dependencyFile]
          [mainPlanFile, dependencyPlanFile]
          [requiredDependency, optionalDependency]
          ["optional_dependencies_not_found"]
          []
      typedPlanShuffled =
        ContentRoutes.contentTypedInstallPlan
          request
          "/tmp/mc/mods"
          [dependencyFile, mainFile]
          [dependencyPlanFile, mainPlanFile]
          [optionalDependency, requiredDependency]
          ["optional_dependencies_not_found"]
          []
      response =
        ContentInstallPlanResponse
          { contentPlanAction = "install"
          , contentPlanSource = "modrinth"
          , contentPlanProjectId = Just "sodium"
          , contentPlanProjectTitle = "Sodium"
          , contentPlanReleaseId = "main-version"
          , contentPlanTargetDir = "/tmp/mc/mods"
          , contentPlanFiles = [mainPlanFile, dependencyPlanFile]
          , contentPlanDependencies = [requiredDependency, optionalDependency]
          , contentPlanWarnings = ["optional_dependencies_not_found"]
          , contentPlanBlockedReasons = typedPlanBlockedReasons typedPlan
          , contentPlanTotalSize = Just 30
          , contentPlanTypedPlan = typedPlan
          }
      dependencyNodeIds =
        [ installNodeId node
        | node <- typedPlanNodes typedPlan
        , installNodeLabel node == "Fabric API"
        ]
      mainNodes =
        [ node
        | node <- typedPlanNodes typedPlan
        , installNodeLabel node == "sodium.jar"
        ]
      replaceRollbacks =
        [ installRollbackAction (installNodeRollback node)
        | node <- mainNodes
        ]
      downloadJobs = ContentRoutes.contentDownloadJobsFromTypedPlan response

  assertEqual "content typed plan is ready with optional dependency warning" "ready" (typedPlanStatus typedPlan)
  assertEqual "content typed plan keeps optional warning" ["optional_dependencies_not_found"] (typedPlanWarnings typedPlan)
  assertEqual "content required dependency becomes node" True (not (null dependencyNodeIds))
  assertEqual "content primary file depends on required dependency" True (not (null dependencyNodeIds) && all (`elem` concatMap installNodeDependsOn mainNodes) dependencyNodeIds)
  assertEqual "content dependency edge is present" True (not (null (typedPlanEdges typedPlan)))
  assertEqual "content replace declares restore backup rollback" ["restoreBackup"] replaceRollbacks
  assertEqual "content typed executor downloads dependency before replace file" ["/tmp/mc/mods/fabric-api.jar", "/tmp/mc/mods/sodium.jar"] (map jobTargetPath downloadJobs)
  assertEqual "content typed plan ignores file and dependency input order" (typedPlanFingerprint typedPlan) (typedPlanFingerprint typedPlanShuffled)

  let curseForgeDependency =
        requiredDependency
          { contentDependencySource = Just "curseforge"
          , contentDependencyInstalled = Nothing
          }
      curseForgePlan =
        ContentRoutes.contentTypedInstallPlan
          request { contentInstallSource = "curseforge", contentInstallDependencies = [curseForgeDependency] }
          "/tmp/mc/mods"
          [mainFile]
          [mainPlanFile]
          [curseForgeDependency]
          []
          []
  assertEqual "content CurseForge unresolved required dependency blocks plan" "blocked" (typedPlanStatus curseForgePlan)
  assertEqual "content CurseForge unresolved reason" True ("curseforge_required_dependency_unresolved" `elem` typedPlanBlockedReasons curseForgePlan)

assertInstallPlanExecutor :: IO ()
assertInstallPlanExecutor = do
  let nodeA = executorTestNode "a" "metadata" [] "download"
      nodeC = executorTestNode "c" "metadata" [] "download"
      nodeB = executorTestNode "b" "content" ["a"] "download"
      nodeAfter = executorTestNode "after" "verify" ["b"] "download"
      plan =
        finalizeTypedInstallPlan
          TypedInstallPlan
            { typedPlanId = ""
            , typedPlanFingerprint = ""
            , typedPlanKind = "test"
            , typedPlanTitle = "Executor test"
            , typedPlanTargetGameDir = Just "/tmp/mc"
            , typedPlanSource = Just "test"
            , typedPlanStatus = ""
            , typedPlanSummary = InstallPlanSummary 0 0 0 0 0 Nothing
            , typedPlanNodes = [nodeA, nodeB, nodeC, nodeAfter]
            , typedPlanEdges =
                [ InstallPlanEdge
                    { installEdgeFrom = "a"
                    , installEdgeTo = "b"
                    , installEdgeKind = "requires"
                    , installEdgeRequired = True
                    }
                , InstallPlanEdge
                    { installEdgeFrom = "b"
                    , installEdgeTo = "after"
                    , installEdgeKind = "requires"
                    , installEdgeRequired = True
                    }
                ]
            , typedPlanWarnings = []
            , typedPlanBlockedReasons = []
            , typedPlanDiagnostics = []
            , typedPlanRollbackPolicy = "automatic"
            }
  assertEqual "executor batches by dependency and phase" (Right [[nodeA, nodeC], [nodeB], [nodeAfter]]) (installPlanExecutionBatches plan)

  events <- newMVar []
  result <-
    executeInstallPlan
      plan
      ( \node -> do
          modifyMVar_ events (pure . (<> ["run:" <> installNodeId node]))
          when (installNodeId node == "b") (fail "boom")
      )
      (\node -> modifyMVar_ events (pure . (<> ["rollback:" <> installNodeId node])))
      (\_ -> pure ())
  recordedEvents <- readMVar events
  assertEqual "executor stops on failed node" "failed" (installExecutionStatus result)
  assertEqual "executor records failed node" (Just "b") (installExecutionFailedNodeId result)
  assertEqual "executor rolls back completed nodes in reverse" ["rollback:c", "rollback:a"] (filter ("rollback:" `Text.isPrefixOf`) recordedEvents)
  assertEqual "executor does not run successors after failure" True ("run:b" `elem` recordedEvents && not ("run:after" `elem` recordedEvents))
  assertEqual "executor marks successors skipped after failure" [("after", InstallNodeSkipped)] [(installResultNodeId item, installResultStatus item) | item <- installExecutionResults result, installResultNodeId item == "after"]

  let blockedPlan =
        finalizeTypedInstallPlan
          plan
            { typedPlanBlockedReasons = ["blocked_by_test"]
            }
  blockedResult <- executeInstallPlan blockedPlan (\_ -> fail "must not run") (\_ -> fail "must not rollback") (\_ -> pure ())
  assertEqual "executor refuses blocked plan" "blocked" (installExecutionStatus blockedResult)
  assertEqual "executor marks nodes blocked" True (all ((== InstallNodeBlocked) . installResultStatus) (installExecutionResults blockedResult))
  assertEqual "executor blocked nodes include diagnostics" True (all (maybe False ((== "blocked_by_test") . diagnosticCode) . installResultDiagnostic) (installExecutionResults blockedResult))
  assertEqual "executor blocked node result includes kind" True (all ((== Just "test") . installResultNodeKind) (installExecutionResults blockedResult))
  assertEqual "executor blocked node result includes phase" True (all (isJust . installResultPhase) (installExecutionResults blockedResult))

  ranInvalid <- newMVar False
  let invalidPlan =
        finalizeTypedInstallPlan
          plan
            { typedPlanNodes =
                [ nodeA
                    { installNodeVerifications =
                        [InstallVerification "urlAllowed" "error" (Just "bad url")]
                    }
                ]
            , typedPlanEdges = []
            }
  invalidResult <-
    executeInstallPlan
      invalidPlan
      (\_ -> modifyMVar_ ranInvalid (const (pure True)))
      (\_ -> pure ())
      (\_ -> pure ())
  invalidRan <- readMVar ranInvalid
  assertEqual "executor validates node before running" False invalidRan
  assertEqual "executor marks verification error failed" "failed" (installExecutionStatus invalidResult)
  assertEqual "executor failed node includes diagnostic" True (any (maybe False ((== "task_failed") . diagnosticCode) . installResultDiagnostic) (installExecutionResults invalidResult))
  assertEqual "executor failed node result includes kind" True (any ((== Just "test") . installResultNodeKind) (installExecutionResults invalidResult))
  assertEqual "executor failed node result includes phase" True (any ((== Just "metadata") . installResultPhase) (installExecutionResults invalidResult))

  let concurrentPlan =
        finalizeTypedInstallPlan
          plan
            { typedPlanNodes =
                [ executorTestNode "slow" "metadata" [] "download"
                , executorTestNode "fast" "metadata" [] "download"
                ]
            , typedPlanEdges = []
            }
  concurrentResult <-
    executeInstallPlan
      concurrentPlan
      ( \node ->
          when (installNodeId node == "fast") (threadDelay 1000)
      )
      (\_ -> pure ())
      (\_ -> pure ())
  assertEqual
    "executor result json is ordered by stable batch order"
    ["fast", "slow"]
    [ installResultNodeId item
    | item <- installExecutionResults concurrentResult
    , installResultStatus item == InstallNodeSucceeded
    ]

executorTestNode :: Text -> Text -> [Text] -> Text -> InstallPlanNode
executorTestNode nodeId phase dependencies action =
  InstallPlanNode
    { installNodeId = nodeId
    , installNodeKind = "test"
    , installNodeAction = action
    , installNodePhase = phase
    , installNodeLabel = nodeId
    , installNodeTargetPath = Nothing
    , installNodeSourceUrls = []
    , installNodeSha1 = Just nodeId
    , installNodeSize = Nothing
    , installNodeRequired = True
    , installNodeDependsOn = dependencies
    , installNodeVerifications = []
    , installNodeRollback =
        InstallPlanRollbackAction
          { installRollbackAction = "noneWithReason"
          , installRollbackTargetPath = Nothing
          , installRollbackBackupPath = Nothing
          , installRollbackReason = Just "test"
          }
    , installNodeBlockedReason = Nothing
    , installNodeDiagnostics = []
    }

assertContentUpdatePlan :: IO ()
assertContentUpdatePlan = do
  let requiredDependency =
        ContentInstallDependency
          { contentDependencyProjectId = Just "fabric-api"
          , contentDependencyVersionId = Just "dep-version"
          , contentDependencySource = Just "modrinth"
          , contentDependencyName = "Fabric API"
          , contentDependencyRequired = True
          , contentDependencyInstalled = Just True
          , contentDependencySha1 = Just "depsha"
          }
      updateResource =
        ContentUpdatePlanResource
          { updateResourceProjectId = Just "sodium"
          , updateResourceProjectTitle = "Sodium"
          , updateResourceCurrentReleaseId = Just "old-release"
          , updateResourceCurrentFileName = "sodium-old.jar"
          , updateResourceCurrentSha1 = Just "oldsha"
          , updateResourceCurrentTargetPath = "/tmp/mc/mods/sodium.jar"
          , updateResourceRemoteReleaseId = Just "new-release"
          , updateResourceRemoteFileName = Just "sodium-new.jar"
          , updateResourceRemoteUrl = Just "https://cdn.modrinth.com/sodium-new.jar"
          , updateResourceRemoteSha1 = Just "newsha"
          , updateResourceRemoteSize = Just 42
          , updateResourceSelected = Just True
          , updateResourceDependencies = [requiredDependency]
          }
      removeCandidate =
        ContentUpdatePlanResource
          { updateResourceProjectId = Just "old-mod"
          , updateResourceProjectTitle = "Old Mod"
          , updateResourceCurrentReleaseId = Just "gone-release"
          , updateResourceCurrentFileName = "old-mod.jar"
          , updateResourceCurrentSha1 = Just "oldmodsha"
          , updateResourceCurrentTargetPath = "/tmp/mc/mods/old-mod.jar"
          , updateResourceRemoteReleaseId = Nothing
          , updateResourceRemoteFileName = Nothing
          , updateResourceRemoteUrl = Nothing
          , updateResourceRemoteSha1 = Nothing
          , updateResourceRemoteSize = Nothing
          , updateResourceSelected = Just True
          , updateResourceDependencies = []
          }
      ignoredResource =
        updateResource
          { updateResourceProjectId = Just "ignored"
          , updateResourceProjectTitle = "Ignored"
          , updateResourceCurrentTargetPath = "/tmp/mc/mods/ignored.jar"
          , updateResourceSelected = Just False
          }
      updateRequest =
        ContentUpdatePlanRequest
          { updatePlanMode = "updateSelected"
          , updatePlanGameDir = "/tmp/mc"
          , updatePlanSource = "modrinth"
          , updatePlanResources = [updateResource, removeCandidate, ignoredResource]
          }
      updateResponse = ContentRoutes.resolveContentUpdatePlan updateRequest
      updateResponseShuffled =
        ContentRoutes.resolveContentUpdatePlan
          updateRequest { updatePlanResources = [ignoredResource, removeCandidate, updateResource] }
      updatePlan = contentUpdateTypedPlan updateResponse
      nodeActions =
        [ (installNodeLabel node, installNodeAction node)
        | node <- typedPlanNodes updatePlan
        ]
      lockEntries = contentUpdateLockEntries updateResponse
  assertEqual "update plan action" "update" (contentUpdateAction updateResponse)
  assertEqual "update plan includes replace node" True (("Sodium", "replace") `elem` nodeActions)
  assertEqual "update plan includes remove candidate" True (("Old Mod", "removeCandidate") `elem` nodeActions)
  assertEqual "update plan does not auto-include unselected resource" False (any ((== "Ignored") . fst) nodeActions)
  assertEqual "update plan includes dependency node and edge" True (any ((== "Fabric API") . installNodeLabel) (typedPlanNodes updatePlan) && not (null (typedPlanEdges updatePlan)))
  assertEqual "update lockfile records old and new sha" [(Just "oldsha", Just "newsha", Just "new-release")] (map (\entry -> (updateLockOldSha1 entry, updateLockNewSha1 entry, updateLockNewReleaseId entry)) lockEntries)
  assertEqual "update plan ignores selected resource input order" (typedPlanFingerprint updatePlan) (typedPlanFingerprint (contentUpdateTypedPlan updateResponseShuffled))
  assertEqual "update lock entries ignore selected resource input order" lockEntries (contentUpdateLockEntries updateResponseShuffled)

  let badResource =
        updateResource
          { updateResourceRemoteSha1 = Nothing
          }
      badResponse =
        ContentRoutes.resolveContentUpdatePlan
          updateRequest { updatePlanResources = [badResource] }
  assertEqual "update plan blocks missing remote sha" "blocked" (contentUpdateAction badResponse)
  assertEqual "update plan reports missing sha" True ("update_sha1_missing" `elem` contentUpdateBlockedReasons badResponse)

assertModpackTypedPlan :: IO ()
assertModpackTypedPlan = do
  manager <- makeHttpManager
  tempDir <- getTemporaryDirectory
  let sourceRoot = tempDir </> "panino-modpack-plan-test"
      mrpackPath = sourceRoot </> "pack.mrpack"
      mrpackShuffledPath = sourceRoot </> "pack-shuffled.mrpack"
      serverPackPath = sourceRoot </> "server-pack.mrpack"
      cursePath = sourceRoot </> "curse.zip"
      targetPackDir = sourceRoot </> "target-pack"
  exists <- doesDirectoryExist sourceRoot
  when exists (removeDirectoryRecursive sourceRoot)
  createDirectoryIfMissing True (sourceRoot </> "overrides")
  createDirectoryIfMissing True targetPackDir
  BL8.writeFile
    (sourceRoot </> "modrinth.index.json")
    "{\"name\":\"Typed Pack\",\"dependencies\":{\"minecraft\":\"1.20.1\",\"fabric-loader\":\"0.15.0\"},\"files\":[{\"path\":\"mods/sodium.jar\",\"downloads\":[\"https://example.com/sodium.jar\"],\"hashes\":{\"sha1\":\"abc\"},\"fileSize\":123}]}"
  BL8.writeFile (sourceRoot </> "overrides" </> "options.txt") "renderDistance:12\n"
  BL8.writeFile (targetPackDir </> "options.txt") "renderDistance:8\n"
  (zipExit, _, zipErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", mrpackPath, "modrinth.index.json", "overrides/options.txt"]) { cwd = Just sourceRoot }
      ""
  assertEqual "mrpack test zip succeeds" ExitSuccess zipExit
  assertEqual "mrpack test zip stderr" "" zipErr
  (zipShuffledExit, _, zipShuffledErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", mrpackShuffledPath, "overrides/options.txt", "modrinth.index.json"]) { cwd = Just sourceRoot }
      ""
  assertEqual "mrpack shuffled test zip succeeds" ExitSuccess zipShuffledExit
  assertEqual "mrpack shuffled test zip stderr" "" zipShuffledErr

  mrpackResponse <-
    modpackPreflight
      ModpackPreflightRequest
        { modpackPreflightSourceType = "local"
        , modpackPreflightSourcePath = Just mrpackPath
        , modpackPreflightTargetGameDir = Just targetPackDir
        }
  mrpackShuffledResponse <-
    modpackPreflight
      ModpackPreflightRequest
        { modpackPreflightSourceType = "local"
        , modpackPreflightSourcePath = Just mrpackShuffledPath
        , modpackPreflightTargetGameDir = Just targetPackDir
        }
  let mrpackPlan = modpackPreflightTypedPlan mrpackResponse
      mrpackShuffledPlan = modpackPreflightTypedPlan mrpackShuffledResponse
      mrpackKinds = map installNodeKind (typedPlanNodes mrpackPlan)
      mrpackOverrideActions =
        [ (installNodeLabel node, installNodeAction node, installRollbackAction (installNodeRollback node))
        | node <- typedPlanNodes mrpackPlan
        , installNodeKind node == "overrideFile"
        ]
  assertEqual "mrpack preflight stays valid" True (modpackPreflightValid mrpackResponse)
  assertEqual "mrpack typed plan ready" "ready" (typedPlanStatus mrpackPlan)
  assertEqual "mrpack typed plan includes minecraft dependency" True ("minecraftVersion" `elem` mrpackKinds)
  assertEqual "mrpack typed plan includes loader dependency" True ("loaderProfile" `elem` mrpackKinds)
  assertEqual "mrpack typed plan includes mod node" True ("mod" `elem` mrpackKinds)
  assertEqual "mrpack typed plan includes override node" True ("overrideFile" `elem` mrpackKinds)
  assertEqual "mrpack override conflict uses replace plan" True (("overrides/options.txt", "replace", "restoreBackup") `elem` mrpackOverrideActions)
  assertEqual "mrpack typed plan includes lockfile node" True ("rollbackMarker" `elem` mrpackKinds)
  assertEqual "mrpack entry order does not change typed plan fingerprint" (typedPlanFingerprint mrpackPlan) (typedPlanFingerprint mrpackShuffledPlan)
  assertEqual "mrpack entry order does not change canonical typed plan" (canonicalJson (toJSON mrpackPlan)) (canonicalJson (toJSON mrpackShuffledPlan))
  mrpackLockResult <-
    solveLockfileWithServices
      manager
      ( (testLockfileSolveRequest targetPackDir [] Nothing)
          { solveRequestMinecraftVersion = Nothing
          , solveRequestLoader = Nothing
          , solveRequestShaderLoader = Nothing
          , solveRequestSourceType = Just "modrinth"
          , solveRequestSourcePath = Just mrpackPath
          }
      )
  assertEqual "mrpack import maps to lockfile root packages" "ready" (solverResultStatus mrpackLockResult)
  assertEqual
    "mrpack lockfile includes mod and override packages"
    True
    ( maybe
        False
        (\lockfile -> "mod" `elem` map (coordinateKind . resolvedPackageCoordinate) (lockfilePackages lockfile) && "overrideFile" `elem` map (coordinateKind . resolvedPackageCoordinate) (lockfilePackages lockfile))
        (solverResultLockfile mrpackLockResult)
    )

  BL8.writeFile (sourceRoot </> "overrides" </> "server.properties") "motd=server-only\n"
  (serverZipExit, _, serverZipErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", serverPackPath, "modrinth.index.json", "overrides/server.properties"]) { cwd = Just sourceRoot }
      ""
  assertEqual "server mrpack test zip succeeds" ExitSuccess serverZipExit
  assertEqual "server mrpack test zip stderr" "" serverZipErr
  serverResponse <-
    modpackPreflight
      ModpackPreflightRequest
        { modpackPreflightSourceType = "local"
        , modpackPreflightSourcePath = Just serverPackPath
        , modpackPreflightTargetGameDir = Just targetPackDir
        }
  assertEqual "server pack preflight blocks client import" True ("server_pack_not_supported" `elem` modpackPreflightBlockingReasons serverResponse)

  BL8.writeFile
    (sourceRoot </> "manifest.json")
    "{\"name\":\"Curse Pack\",\"minecraft\":{\"version\":\"1.20.1\",\"modLoaders\":[{\"id\":\"fabric-0.15.0\",\"primary\":true}]},\"files\":[{\"projectID\":1,\"fileID\":2}],\"overrides\":\"overrides\"}"
  (curseZipExit, _, curseZipErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", cursePath, "manifest.json", "overrides/options.txt"]) { cwd = Just sourceRoot }
      ""
  assertEqual "curse modpack test zip succeeds" ExitSuccess curseZipExit
  assertEqual "curse modpack test zip stderr" "" curseZipErr
  curseResponse <-
    modpackPreflight
      ModpackPreflightRequest
        { modpackPreflightSourceType = "local"
        , modpackPreflightSourcePath = Just cursePath
        , modpackPreflightTargetGameDir = Just "/tmp/mc-pack"
        }
  assertEqual "curse modpack requires api key" True (modpackPreflightRequiresApiKey curseResponse)
  assertEqual "curse modpack blocks without api key" True ("curseforge_api_key_required" `elem` modpackPreflightBlockingReasons curseResponse)
  assertEqual "curse typed plan blocked" "blocked" (typedPlanStatus (modpackPreflightTypedPlan curseResponse))
  curseLockResult <-
    solveLockfileWithServices
      manager
      ( (testLockfileSolveRequest "/tmp/mc-pack" [] Nothing)
          { solveRequestMinecraftVersion = Nothing
          , solveRequestLoader = Nothing
          , solveRequestShaderLoader = Nothing
          , solveRequestSourceType = Just "local"
          , solveRequestSourcePath = Just cursePath
          }
      )
  assertEqual "curse zip import maps to blocked lockfile solve" "blocked" (solverResultStatus curseLockResult)
  assertEqual
    "curse zip lockfile keeps manifest file package"
    True
    ( maybe
        False
        (any (("curseforge-1-2.jar" `Text.isInfixOf`) . resolvedPackageDisplayName) . lockfilePackages)
        (solverResultLockfile curseLockResult)
    )

assertModpackImportStaging :: IO ()
assertModpackImportStaging = do
  tempDir <- getTemporaryDirectory
  let sourceRoot = tempDir </> "panino-modpack-import-test"
      sourcePack = sourceRoot </> "pack.mrpack"
      badPack = sourceRoot </> "bad-pack.mrpack"
      targetDir = sourceRoot </> "instances" </> "typed-pack"
      badTargetDir = sourceRoot </> "instances" </> "bad-pack"
      stagingDir = targetDir <> ".panino-modpack-staging"
      badStagingDir = badTargetDir <> ".panino-modpack-staging"
  exists <- doesDirectoryExist sourceRoot
  when exists (removeDirectoryRecursive sourceRoot)
  createDirectoryIfMissing True (sourceRoot </> "success" </> "overrides")
  BL8.writeFile
    (sourceRoot </> "success" </> "modrinth.index.json")
    "{\"name\":\"Import Pack\",\"dependencies\":{\"minecraft\":\"1.20.1\",\"fabric-loader\":\"0.15.0\"},\"files\":[]}"
  BL8.writeFile (sourceRoot </> "success" </> "overrides" </> "options.txt") "renderDistance:12\n"
  (zipExit, _, zipErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", sourcePack, "modrinth.index.json", "overrides/options.txt"]) { cwd = Just (sourceRoot </> "success") }
      ""
  assertEqual "modpack import test zip succeeds" ExitSuccess zipExit
  assertEqual "modpack import test zip stderr" "" zipErr

  manager <- makeHttpManager
  importResponse <-
    modpackImport
      manager
      ModpackImportRequest
        { modpackImportSourceType = "local"
        , modpackImportSourcePath = sourcePack
        , modpackImportTargetGameDir = targetDir
        }
  targetExists <- doesDirectoryExist targetDir
  stagingExists <- doesDirectoryExist stagingDir
  optionsExists <- doesFileExist (targetDir </> "options.txt")
  lockExists <- doesFileExist (targetDir </> "modpack-install-lock.json")
  lockText <- if lockExists then BL8.readFile (targetDir </> "modpack-install-lock.json") else pure ""
  assertEqual "modpack import succeeds" True (modpackImportImported importResponse)
  assertEqual "modpack import atomically creates target" True targetExists
  assertEqual "modpack import removes staging" False stagingExists
  assertEqual "modpack import writes override" True optionsExists
  assertEqual "modpack import writes lockfile" True lockExists
  assertEqual "modpack lockfile records override" True ("options.txt" `isInfixOf` BL8.unpack lockText)

  createDirectoryIfMissing True (sourceRoot </> "failure")
  BL8.writeFile
    (sourceRoot </> "failure" </> "modrinth.index.json")
    "{\"name\":\"Bad Import Pack\",\"dependencies\":{\"minecraft\":\"1.20.1\",\"fabric-loader\":\"0.15.0\"},\"files\":[{\"path\":\"mods/missing.jar\",\"downloads\":[\"http://127.0.0.1:1/missing.jar\"],\"hashes\":{\"sha1\":\"0123456789012345678901234567890123456789\"},\"fileSize\":12}]}"
  (badZipExit, _, badZipErr) <-
    readCreateProcessWithExitCode
      (proc "/usr/bin/zip" ["-qr", badPack, "modrinth.index.json"]) { cwd = Just (sourceRoot </> "failure") }
      ""
  assertEqual "bad modpack import test zip succeeds" ExitSuccess badZipExit
  assertEqual "bad modpack import test zip stderr" "" badZipErr

  failedResponse <-
    modpackImport
      manager
      ModpackImportRequest
        { modpackImportSourceType = "local"
        , modpackImportSourcePath = badPack
        , modpackImportTargetGameDir = badTargetDir
        }
  badTargetExists <- doesDirectoryExist badTargetDir
  badStagingExists <- doesDirectoryExist badStagingDir
  assertEqual "failed modpack import reports failure" False (modpackImportImported failedResponse)
  assertEqual "failed modpack import reports reason" True (any ("modpack_import_failed:" `Text.isPrefixOf`) (modpackImportBlockingReasons failedResponse))
  assertEqual "failed modpack import does not leave target" False badTargetExists
  assertEqual "failed modpack import removes staging" False badStagingExists

assertJvmTuningRecommendations :: IO ()
assertJvmTuningRecommendations = do
  let large16 =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestSystemMemoryBytes = Just (gbBytes 16)
            , tuningRequestJavaMajorVersion = Just 21
            , tuningRequestModCount = Just 180
            }
  assertEqual "jvm tuning infers large pack" PackScaleLargePack (resolvedTuningPackScale large16)
  assertEqual "16GB large pack recommends 8GB heap" 8192 (resolvedTuningXmxMb large16)
  assertEqual "large pack uses 1GB Xms" 1024 (resolvedTuningXmsMb large16)
  assertEqual "auto tuning uses G1GC" True ("-XX:+UseG1GC" `elem` resolvedTuningJvmArgs large16)

  let lowMemoryLarge =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestSystemMemoryBytes = Just (gbBytes 8)
            , tuningRequestModCount = Just 180
            }
  assertEqual "8GB large pack is capped to 4GB" 4096 (resolvedTuningXmxMb lowMemoryLarge)
  assertEqual "8GB large pack warns" True ("large_pack_not_recommended" `elem` warningCodes lowMemoryLarge)

  let customHigh =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestSystemMemoryBytes = Just (gbBytes 16)
            , tuningRequestCustomMemoryMb = Just 16384
            }
  assertEqual "custom high memory keeps explicit heap" 16384 (resolvedTuningXmxMb customHigh)
  assertEqual "custom high memory warns" True ("memory_too_high" `elem` warningCodes customHigh)

  let customLow =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestSystemMemoryBytes = Just (gbBytes 16)
            , tuningRequestModCount = Just 180
            , tuningRequestCustomMemoryMb = Just 512
            }
  assertEqual "custom low memory is clamped" 1024 (resolvedTuningXmxMb customLow)
  assertEqual "custom low memory warns" True ("memory_too_low" `elem` warningCodes customLow)

  let zgcUnsupported =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestPolicy = JvmTuningExperimentalZgc
            , tuningRequestJavaMajorVersion = Just 8
            }
  assertEqual "ZGC falls back on Java 8" JvmTuningAuto (resolvedTuningEffectivePolicy zgcUnsupported)
  assertEqual "ZGC fallback warns" True ("experimental_zgc_unsupported" `elem` warningCodes zgcUnsupported)

  let zgcSupported =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestPolicy = JvmTuningExperimentalZgc
            , tuningRequestJavaMajorVersion = Just 21
            }
  assertEqual "ZGC remains experimental on Java 21" JvmTuningExperimentalZgc (resolvedTuningEffectivePolicy zgcSupported)
  assertEqual "ZGC profile uses ZGC" True ("-XX:+UseZGC" `elem` resolvedTuningJvmArgs zgcSupported)

  let customConflict =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestCustomJvmArgs = ["-Xmx12G", "-Dpanino.test=true", "-XX:+UseZGC"]
            }
  assertEqual "custom conflicting Xmx is removed" False ("-Xmx12G" `elem` resolvedTuningJvmArgs customConflict)
  assertEqual "custom non-conflicting arg is kept" True ("-Dpanino.test=true" `elem` resolvedTuningJvmArgs customConflict)
  assertEqual "custom JVM arg conflict warns" True ("custom_jvm_args_conflict" `elem` warningCodes customConflict)
  let launchArgs =
        buildJavaArguments
          testLayout
          testVersionJson
          (classpathJars testLayout testVersionJson)
          LaunchProfile
            { profileVersion = "1.20.1"
            , profileMemoryMb = 4096
            , profileJavaPath = "java"
            , profileUsername = "Steve"
            , profileUuid = "00000000-0000-0000-0000-000000000000"
            , profileAccessToken = "0"
            , profileJvmArgs = []
            , profileJvmTuning = Just customConflict
            , profileWindowWidth = Nothing
            , profileWindowHeight = Nothing
            }
  assertEqual "effective launch args keep one Xmx" 1 (length (filter ("-Xmx" `isPrefixOf`) launchArgs))
  assertEqual "effective launch args drops conflicting custom ZGC" False ("-XX:+UseZGC" `elem` launchArgs)
  assertEqual
    "launch request parses JVM tuning fields"
    (Right (Just JvmTuningLargePack, ["-Dpanino.test=true"], Just 8192))
    ( (\request -> (launchRequestJvmProfile request, launchRequestCustomJvmArgs request, launchRequestCustomMemoryMb request))
        <$> eitherDecode "{\"version\":\"1.20.1\",\"memoryPolicy\":\"custom\",\"jvmProfile\":\"largePack\",\"customMemoryMb\":8192,\"customJvmArgs\":[\"-Dpanino.test=true\"]}"
    )

  assertEqual
    "jvm tuning json roundtrip"
    (Just large16)
    (decode (encode large16))
  assertEqual
    "jvm tuning medium pack inference"
    PackScaleMediumPack
    (inferPackScale defaultJvmTuningRequest { tuningRequestLoader = Just "fabric" })

gbBytes :: Int64 -> Int64
gbBytes gb =
  gb * 1024 * 1024 * 1024

warningCodes :: ResolvedJvmTuning -> [Text.Text]
warningCodes =
  map tuningWarningCode . resolvedTuningWarnings

graphicsWarningCodes :: ResolvedGraphicsTuning -> [Text.Text]
graphicsWarningCodes =
  map graphicsWarningCode . resolvedGraphicsWarnings

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

assertGraphicsOptionsTuning :: IO ()
assertGraphicsOptionsTuning = do
  let rawOptions =
        Text.intercalate
          "\r\n"
          [ "renderDistance:24"
          , "simulationDistance:12"
          , "maxFps:260"
          , "unknownPaninoKeeps:this must stay"
          , "renderDistance:32"
          ]
          <> "\r\n"
      parsed = parseMinecraftOptions rawOptions
  assertEqual "graphics options preserve CRLF render" rawOptions (renderMinecraftOptions parsed)
  assertEqual "graphics options last duplicate wins" (Just "32") (optionValue "renderDistance" parsed)
  assertEqual
    "graphics options duplicate warning"
    ["duplicate_options_key"]
    (map graphicsWarningCode (duplicateOptionWarnings parsed))
  assertEqual "graphics hardware tier max" GraphicsHardwareMMaxUltra (inferGraphicsHardwareTier (Just "Apple M3 Max"))
  assertEqual "graphics hardware tier pro" GraphicsHardwareMPro (inferGraphicsHardwareTier (Just "Apple M2 Pro"))
  assertEqual "platform hardware tier pro" GraphicsHardwareMPro (hardwareTierFromChipName (Just "Apple M3 Pro"))
  assertEqual "platform hardware tier max" GraphicsHardwareMMaxUltra (hardwareTierFromChipName (Just "Apple M2 Ultra"))
  assertEqual "platform hardware memory tier 32" "24/32GB" (hardwareMemoryTier (Just (32 * 1024 * 1024 * 1024)))
  assertEqual "graphics whitelist allows render distance" True (isGraphicsOptionsWritableKey "renderDistance")
  assertEqual "graphics whitelist blocks fov" False (isGraphicsOptionsWritableKey "fov")
  assertEqual "graphics old version skips simulation distance" (Just "unsupported_version") (graphicsOptionSkippedReason (Just "1.16.5") "simulationDistance")

  let patch =
        buildOptionsPatch
          (Just "/tmp/options.txt")
          (Map.fromList
            [ ("renderDistance", "16")
            , ("fov", "90")
            , ("mipmapLevels", "4")
            , ("maxFps", "260")
            ])
          parsed
  assertEqual
    "graphics patch statuses"
    [("fov", "skipped"), ("maxFps", "keep"), ("mipmapLevels", "create"), ("renderDistance", "change")]
    [(optionsPatchChangeKey change, optionsPatchChangeStatus change) | change <- optionsPatchChanges patch]
  let oldVersionPatch =
        buildOptionsPatchForVersion
          (Just "1.16.5")
          Nothing
          (Map.fromList [("simulationDistance", "8")])
          parsed
  assertEqual
    "graphics version capability returns skipped reason"
    [("simulationDistance", "skipped", "unsupported_version")]
    [(optionsPatchChangeKey change, optionsPatchChangeStatus change, optionsPatchChangeReason change) | change <- optionsPatchChanges oldVersionPatch]
  let patched = applyOptionsPatch patch parsed
  assertEqual "graphics patch updates last render distance" (Just "16") (optionValue "renderDistance" patched)
  assertEqual "graphics patch keeps unknown options" True ("unknownPaninoKeeps:this must stay" `Text.isInfixOf` renderMinecraftOptions patched)
  assertEqual "graphics patch keeps max fps" (Just "260") (optionValue "maxFps" patched)

  tempDir <- getTemporaryDirectory
  now <- getCurrentTime
  let optionsDir = tempDir </> ("panino-graphics-options-test-" <> safePathSuffix (show now))
      optionsPath = optionsDir </> "options.txt"
  removeDirectoryRecursive optionsDir `catchAny` \_ -> pure ()
  createDirectoryIfMissing True optionsDir
  BS8.writeFile optionsPath "renderDistance:24\nsimulationDistance:12\nmaxFps:260\n"
  backup <- backupOptionsFile now optionsPath
  assertEqual "graphics stable backup created" True (optionsBackupCreated backup && maybe False (not . null) (optionsBackupStablePath backup))
  fileBackup <- applyOptionsPatchToFile (addUTCTime 1 now) optionsPath patch
  assertEqual "graphics apply backup created" True (optionsBackupCreated fileBackup)
  appliedBytes <- BS8.readFile optionsPath
  assertEqual "graphics apply writes render distance" True ("renderDistance:16" `BS8.isInfixOf` appliedBytes)
  case optionsBackupStablePath backup of
    Nothing -> do
      putStrLn "FAIL: graphics rollback stable backup missing"
      exitFailure
    Just stableBackup -> do
      _ <- rollbackOptionsFile (addUTCTime 2 now) optionsPath stableBackup
      restoredBytes <- BS8.readFile optionsPath
      assertEqual "graphics rollback restores stable backup" True ("renderDistance:24" `BS8.isInfixOf` restoredBytes)
  removeDirectoryRecursive optionsDir `catchAny` \_ -> pure ()

assertGraphicsTuningRecommendations :: IO ()
assertGraphicsTuningRecommendations = do
  let currentOptions =
        parseMinecraftOptions $
          Text.intercalate "\n"
            [ "renderDistance:24"
            , "simulationDistance:12"
            , "maxFps:260"
            , "enableVsync:true"
            , "renderClouds:\"true\""
            , "particles:0"
            , "entityDistanceScaling:1.0"
            , "mipmapLevels:4"
            , "graphicsMode:1"
            ]
            <> "\n"
      baseM =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMBase
            , graphicsRequestDisplayScale = Just 2
            , graphicsRequestIsBuiltinDisplay = Just True
            , graphicsRequestRefreshRate = Just 60
            }
          currentOptions
  assertEqual "graphics M base retina uses balanced retina" BalancedRetina (resolvedGraphicsRetinaPolicy baseM)
  assertEqual "graphics M base render conservative" (Just "8") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions baseM))
  assertEqual "graphics M base flags render distance too high" True ("render_distance_too_high" `elem` graphicsWarningCodes baseM)
  assertEqual "graphics M base flags retina pressure" True ("retina_gpu_pressure" `elem` graphicsWarningCodes baseM)

  let proBalanced =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMPro
            , graphicsRequestRefreshRate = Just 120
            }
          currentOptions
  assertEqual "graphics M Pro balanced render" (Just "14") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions proBalanced))
  assertEqual "graphics M Pro balanced fps" (Just "120") (Map.lookup "maxFps" (resolvedGraphicsRecommendedOptions proBalanced))

  let proExternal5k =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMPro
            , graphicsRequestIsBuiltinDisplay = Just False
            , graphicsRequestDisplayWidth = Just 5120
            , graphicsRequestDisplayHeight = Just 2880
            }
          currentOptions
  assertEqual "graphics external 5K lowers render" (Just "12") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions proExternal5k))
  assertEqual "graphics external 5K warns" True ("retina_gpu_pressure" `elem` graphicsWarningCodes proExternal5k)

  let maxClarity =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMMaxUltra
            , graphicsRequestProfile = GraphicsProfileClarity
            , graphicsRequestDisplayScale = Just 2
            , graphicsRequestIsBuiltinDisplay = Just True
            , graphicsRequestRefreshRate = Just 144
            }
          currentOptions
  assertEqual "graphics Max clarity render" (Just "24") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions maxClarity))
  assertEqual "graphics Max high refresh fps" (Just "144") (Map.lookup "maxFps" (resolvedGraphicsRecommendedOptions maxClarity))
  assertEqual "graphics Max high refresh can disable vsync" (Just "false") (Map.lookup "enableVsync" (resolvedGraphicsRecommendedOptions maxClarity))
  assertEqual "graphics clarity maps to Retina quality" RetinaQuality (resolvedGraphicsRetinaPolicy maxClarity)

  let largePack =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMPro
            , graphicsRequestModCount = Just 180
            }
          currentOptions
  assertEqual "graphics large pack lowers render" (Just "10") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions largePack))
  assertEqual "graphics large pack caps simulation" (Just "8") (Map.lookup "simulationDistance" (resolvedGraphicsRecommendedOptions largePack))
  assertEqual "graphics large pack decreases particles" (Just "1") (Map.lookup "particles" (resolvedGraphicsRecommendedOptions largePack))

  let shaderPack =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMMaxUltra
            , graphicsRequestShaderEnabled = True
            , graphicsRequestResourcePackScale = Just "high-128x"
            }
          currentOptions
  assertEqual "graphics shader lowers render" (Just "12") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions shaderPack))
  assertEqual "graphics shader warns" True ("shader_pressure" `elem` graphicsWarningCodes shaderPack)

  let historySnapshot =
        baseM
          { resolvedGraphicsWarnings =
              [ GraphicsTuningWarning
                  { graphicsWarningCode = "low_fps"
                  , graphicsWarningSeverity = "warning"
                  , graphicsWarningMessage = "low fps"
                  , graphicsWarningAction = Just "switchPerformance"
                  }
              ]
          }
      historyAdvice =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMPro
            , graphicsRequestPreviousSnapshot = Just historySnapshot
            }
          currentOptions
  assertEqual "graphics history only recommends" True ("previous_low_fps" `elem` graphicsWarningCodes historyAdvice)
  assertEqual "graphics recommendation is pure dry run" (Just "24") (optionValue "renderDistance" currentOptions)

  let manualOverride =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMBase
            , graphicsRequestProfile = GraphicsProfileManual
            , graphicsRequestManualOverrides = Map.fromList [("renderDistance", "11"), ("maxFps", "75")]
            }
          currentOptions
  assertEqual "graphics manual override render" (Just "11") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions manualOverride))
  assertEqual "graphics manual override fps" (Just "75") (Map.lookup "maxFps" (resolvedGraphicsRecommendedOptions manualOverride))

assertGraphicsTuningApiHelpers :: IO ()
assertGraphicsTuningApiHelpers = do
  tempDir <- getTemporaryDirectory
  now <- getCurrentTime
  let gameDir = tempDir </> ("panino-graphics-api-test-" <> safePathSuffix (show now))
      optionsPath = gameDir </> "options.txt"
  removeDirectoryRecursive gameDir `catchAny` \_ -> pure ()
  createDirectoryIfMissing True gameDir
  BS8.writeFile optionsPath "renderDistance:24\nsimulationDistance:12\nmaxFps:260\nenableVsync:true\nrenderClouds:\"true\"\nparticles:0\nentityDistanceScaling:1.0\nmipmapLevels:4\ngraphicsMode:1\n"
  resolved <-
    readGraphicsTuningForEnvironment
      defaultGraphicsTuningRequest
        { graphicsRequestGameDir = Just gameDir
        , graphicsRequestHardwareTier = GraphicsHardwareMBase
        , graphicsRequestDisplayScale = Just 2
        , graphicsRequestIsBuiltinDisplay = Just True
        }
      gameDir
  assertEqual "graphics API helper sets patch path" (Just optionsPath) (optionsPatchPath (resolvedGraphicsOptionsPatch resolved))
  assertEqual "graphics API helper recommends changes" True (resolvedGraphicsCanApply resolved)
  beforeApply <- BS8.readFile optionsPath
  assertEqual "graphics API resolve is dry run" True ("renderDistance:24" `BS8.isInfixOf` beforeApply)
  backup <- applyOptionsPatchToFile (addUTCTime 1 now) optionsPath (resolvedGraphicsOptionsPatch resolved)
  let backupPath =
        case optionsBackupTimestampPath backup of
          Just path -> Just path
          Nothing -> optionsBackupStablePath backup
      resolvedWithBackup =
        resolved
          { resolvedGraphicsBackupPath = backupPath
          , resolvedGraphicsCanRollback = backupPath /= Nothing
          }
  writeGraphicsTuningDiagnostics gameDir resolvedWithBackup backup
  appliedBytes <- BS8.readFile optionsPath
  assertEqual "graphics API apply writes options" True ("renderDistance:8" `BS8.isInfixOf` appliedBytes)
  tuningDiagnosticExists <- doesFileExist (gameDir </> "downloads" </> "graphics-tuning.json")
  patchDiagnosticExists <- doesFileExist (gameDir </> "downloads" </> "graphics-options-patch.txt")
  assertEqual "graphics API writes tuning diagnostic" True tuningDiagnosticExists
  assertEqual "graphics API writes patch diagnostic" True patchDiagnosticExists
  tuningDiagnostic <- BS8.readFile (gameDir </> "downloads" </> "graphics-tuning.json")
  patchDiagnostic <- BS8.readFile (gameDir </> "downloads" </> "graphics-options-patch.txt")
  assertEqual "graphics tuning diagnostic includes backup" True ("\"backup\"" `BS8.isInfixOf` tuningDiagnostic)
  assertEqual "graphics patch diagnostic includes change" True ("renderDistance" `BS8.isInfixOf` patchDiagnostic)
  case optionsBackupStablePath backup of
    Nothing -> do
      putStrLn "FAIL: graphics API rollback stable backup missing"
      exitFailure
    Just stableBackup -> do
      rollbackBackup <- rollbackOptionsFile (addUTCTime 2 now) optionsPath stableBackup
      writeGraphicsTuningRollbackEvent gameDir stableBackup rollbackBackup
      restoredBytes <- BS8.readFile optionsPath
      assertEqual "graphics API rollback restores options" True ("renderDistance:24" `BS8.isInfixOf` restoredBytes)
      eventLog <- BS8.readFile (gameDir </> "downloads" </> "graphics-tuning-events.jsonl")
      assertEqual "graphics API rollback writes event log" True ("\"action\":\"rollback\"" `BS8.isInfixOf` eventLog)
  removeDirectoryRecursive gameDir `catchAny` \_ -> pure ()

  let missingGameDir = tempDir </> ("panino-graphics-missing-options-test-" <> safePathSuffix (show now))
      missingOptionsPath = missingGameDir </> "options.txt"
  removeDirectoryRecursive missingGameDir `catchAny` \_ -> pure ()
  createDirectoryIfMissing True missingGameDir
  missingResolved <-
    readGraphicsTuningForEnvironment
      defaultGraphicsTuningRequest
        { graphicsRequestGameDir = Just missingGameDir
        , graphicsRequestHardwareTier = GraphicsHardwareMBase
        }
      missingGameDir
  assertEqual "graphics missing options can create initial file" True (resolvedGraphicsCanApply missingResolved)
  assertEqual
    "graphics missing options patch creates keys"
    True
    (any ((== "create") . optionsPatchChangeStatus) (optionsPatchChanges (resolvedGraphicsOptionsPatch missingResolved)))
  missingBackup <- applyOptionsPatchToFile (addUTCTime 3 now) missingOptionsPath (resolvedGraphicsOptionsPatch missingResolved)
  assertEqual "graphics missing options has no backup error" Nothing (optionsBackupError missingBackup)
  createdOptions <- BS8.readFile missingOptionsPath
  assertEqual "graphics missing options writes initial file" True ("renderDistance:" `BS8.isInfixOf` createdOptions)
  removeDirectoryRecursive missingGameDir `catchAny` \_ -> pure ()

assertJavaRuntimeManagerStore :: FilePath -> IO ()
assertJavaRuntimeManagerStore tempDir = do
  now <- getCurrentTime
  let appRoot = tempDir </> ("panino-java-runtime-manager-test-" <> safePathSuffix (show now))
      javaExecutable = appRoot </> "runtimes" </> "java" </> "managed" </> "temurin-21-test" </> "Contents" </> "Home" </> "bin" </> "java"
      java25Executable = appRoot </> "runtimes" </> "java" </> "managed" </> "temurin-25-test" </> "Contents" </> "Home" </> "bin" </> "java"
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
  createDirectoryIfMissing True (takeDirectory javaExecutable)
  writeFile javaExecutable "#!/bin/sh\n"
  runtime <-
    upsertManagedRuntime appRoot JavaManagedRuntime
      { managedRuntimeId = "temurin-21-test"
      , managedRuntimeVendor = "temurin"
      , managedRuntimeProvider = "adoptium"
      , managedRuntimeFeatureVersion = 21
      , managedRuntimeVersion = "21.0.0"
      , managedRuntimeOs = "mac"
      , managedRuntimeArch = "aarch64"
      , managedRuntimeImageType = "jre"
      , managedRuntimeJavaHome = takeDirectory (takeDirectory javaExecutable)
      , managedRuntimeJavaExecutable = javaExecutable
      , managedRuntimeSourceUrl = "https://example.invalid/java.tar.gz"
      , managedRuntimeSha256 = Just "abc"
      , managedRuntimeInstalledAt = now
      , managedRuntimeLastVerifiedAt = Just now
      , managedRuntimeDiskUsageBytes = Nothing
      , managedRuntimeUsedByInstanceCount = 0
      }
  assertEqual "managed runtime index writes runtime" "temurin-21-test" (managedRuntimeId runtime)
  _ <-
    upsertManagedRuntime appRoot runtime
      { managedRuntimeId = "temurin-25-test"
      , managedRuntimeFeatureVersion = 25
      , managedRuntimeVersion = "25.0.0"
      , managedRuntimeJavaHome = takeDirectory (takeDirectory java25Executable)
      , managedRuntimeJavaExecutable = java25Executable
      }
  resolved <-
    resolveJavaRuntimeForRequirement
      appRoot
      (JavaRuntimeResolveRequest "1.21.5" Nothing Nothing (Just "auto") Nothing Nothing)
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = "1.21.5"
        , javaRequirementMajorVersion = 21
        , javaRequirementComponent = Just "java-runtime-delta"
        , javaRequirementSource = "manifest"
        }
  assertEqual "managed runtime is selected before local Java" (Just "temurin-21-test") (resolveResponseSelectedRuntimeId resolved)
  resolvedExactMajor <-
    resolveJavaRuntimeForRequirement
      appRoot
      (JavaRuntimeResolveRequest "1.21.5" Nothing Nothing (Just "auto") Nothing Nothing)
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = "1.21.5"
        , javaRequirementMajorVersion = 21
        , javaRequirementComponent = Just "java-runtime-delta"
        , javaRequirementSource = "manifest"
        }
  assertEqual "auto Java prefers exact managed major over newer compatible runtime" (Just "temurin-21-test") (resolveResponseSelectedRuntimeId resolvedExactMajor)
  resolvedNewestMajor <-
    resolveJavaRuntimeForRequirement
      appRoot
      (JavaRuntimeResolveRequest "java-25" Nothing Nothing (Just "auto") Nothing Nothing)
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = "java-25"
        , javaRequirementMajorVersion = 25
        , javaRequirementComponent = Nothing
        , javaRequirementSource = "test"
        }
  assertEqual "auto Java still selects newer runtime when it is the exact requirement" (Just "temurin-25-test") (resolveResponseSelectedRuntimeId resolvedNewestMajor)
  _ <-
    selectJavaRuntimePolicy appRoot JavaRuntimeSelectRequest
      { selectRuntimeScope = "instance"
      , selectRuntimeInstanceId = Just "instance-a"
      , selectRuntimePolicy = "managed"
      , selectRuntimePreferredRuntimeId = Just "temurin-21-test"
      , selectRuntimeCustomPath = Nothing
      , selectRuntimeLockPatchVersion = True
      }
  runtimes <- readManagedRuntimes appRoot
  assertEqual
    "managed runtime usage count includes instance policy"
    [1]
    [managedRuntimeUsedByInstanceCount item | item <- runtimes, managedRuntimeId item == "temurin-21-test"]
  deleteResponse <- deleteManagedRuntime appRoot "temurin-21-test"
  assertEqual "referenced managed runtime delete is blocked" False (deleteRuntimeDeleted deleteResponse)
  assertEqual "referenced managed runtime delete lists instance" ["instance:instance-a"] (deleteRuntimeReferences deleteResponse)
  customResult <-
    resolveJavaRuntimeForRequirement
      appRoot
      (JavaRuntimeResolveRequest "1.16.5" Nothing Nothing (Just "custom") Nothing (Just (appRoot </> "missing-java")))
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = "1.16.5"
        , javaRequirementMajorVersion = 8
        , javaRequirementComponent = Nothing
        , javaRequirementSource = "fallback"
        }
  assertEqual "custom policy only trusts custom path when valid" "incompatible" (resolveResponseStatus customResult)
  modernFallback <-
    resolveJavaRuntimeForRequirement
      appRoot
      (JavaRuntimeResolveRequest "1.16.5" Nothing Nothing (Just "auto") Nothing Nothing)
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = "1.16.5"
        , javaRequirementMajorVersion = 8
        , javaRequirementComponent = Nothing
        , javaRequirementSource = "fallback"
        }
  assertEqual "legacy fallback does not select modern managed Java" Nothing (resolveResponseSelectedRuntimeId modernFallback)
  assertJavaRuntimeResolutionMatrix appRoot
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
  assertManagedIndexRebuild tempDir runtime

assertJavaRuntimeCheckSummary :: FilePath -> IO ()
assertJavaRuntimeCheckSummary tempDir = do
  now <- getCurrentTime
  let appRoot = tempDir </> ("panino-java-check-summary-test-" <> safePathSuffix (show now))
      javaExecutable = appRoot </> "bin" </> "java"
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
  createDirectoryIfMissing True (takeDirectory javaExecutable)
  BS8.writeFile javaExecutable (BS8.pack fakeJavaSettingsScript)
  _ <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", javaExecutable]) ""
  response <- checkJavaRuntime (JavaCheckRequest (Just javaExecutable))
  assertEqual
    "java check summary uses parsed runtime details"
    "Java 21.0.0 · Panino Test · aarch64"
    (javaResponseSummary response)
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()

assertJavaRuntimeLocalDeleteSafety :: FilePath -> IO ()
assertJavaRuntimeLocalDeleteSafety tempDir = do
  now <- getCurrentTime
  let appRoot = tempDir </> ("panino-java-local-delete-test-" <> safePathSuffix (show now))
      bundleRoot = appRoot </> "Library" </> "Java" </> "JavaVirtualMachines" </> "test-21.jdk"
      javaExecutable = bundleRoot </> "Contents" </> "Home" </> "bin" </> "java"
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
  blocked <- deleteJavaRuntimeCandidate (JavaRuntimeLocalDeleteRequest "/usr/bin/java")
  assertEqual "system Java delete is blocked" False (javaLocalDeleteDeleted blocked)
  createDirectoryIfMissing True (takeDirectory javaExecutable)
  writeFile javaExecutable "#!/bin/sh\n"
  deleted <- deleteJavaRuntimeCandidate (JavaRuntimeLocalDeleteRequest javaExecutable)
  assertEqual "self-contained jdk bundle can be deleted" True (javaLocalDeleteDeleted deleted)
  exists <- doesDirectoryExist bundleRoot
  assertEqual "deleted jdk bundle directory is gone" False exists
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()

assertJavaRuntimeResolutionMatrix :: FilePath -> IO ()
assertJavaRuntimeResolutionMatrix appRoot =
  mapM_ assertRequirement [8, 16, 17, 21, 25]
  where
    assertRequirement major = do
      response <-
        resolveJavaRuntimeForRequirement
          appRoot
          (JavaRuntimeResolveRequest (Text.pack ("java-" <> show major)) Nothing Nothing (Just "auto") Nothing Nothing)
          JavaRuntimeRequirement
            { javaRequirementMinecraftVersion = Text.pack ("java-" <> show major)
            , javaRequirementMajorVersion = major
            , javaRequirementComponent = Nothing
            , javaRequirementSource = "test"
            }
      assertEqual ("resolution keeps required Java " <> show major) major (resolveResponseRequiredMajorVersion response)
      when (resolveResponseStatus response == "downloadable") $
        assertEqual
          ("downloadable resolution points at Java " <> show major)
          (Just major)
          (runtimeDownloadFeatureVersion <$> resolveResponseDownload response)

assertManagedIndexRebuild :: FilePath -> JavaManagedRuntime -> IO ()
assertManagedIndexRebuild tempDir runtime = do
  now <- getCurrentTime
  let appRoot = tempDir </> ("panino-java-runtime-rebuild-test-" <> safePathSuffix (show now))
      runtimeId = managedRuntimeId runtime
      runtimeDir = appRoot </> "runtimes" </> "java" </> "managed" </> Text.unpack runtimeId
      runtimeJson = runtimeDir </> "runtime.json"
      indexJson = appRoot </> "runtimes" </> "java" </> "managed-index.json"
      javaExecutable = runtimeDir </> "Contents" </> "Home" </> "bin" </> "java"
      rebuildRuntime =
        runtime
          { managedRuntimeJavaHome = takeDirectory (takeDirectory javaExecutable)
          , managedRuntimeJavaExecutable = javaExecutable
          }
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()
  createDirectoryIfMissing True (takeDirectory runtimeJson)
  BL.writeFile runtimeJson (encode rebuildRuntime)
  createDirectoryIfMissing True (takeDirectory indexJson)
  BS8.writeFile indexJson "{not json"
  rebuilt <- readManagedRuntimes appRoot
  assertEqual "managed index rebuilds from runtime json" [runtimeId] (map managedRuntimeId rebuilt)
  removeDirectoryRecursive appRoot `catchAny` \_ -> pure ()

safePathSuffix :: String -> String
safePathSuffix =
  map (\char -> if char `elem` (['a'..'z'] <> ['A'..'Z'] <> ['0'..'9']) then char else '-')

assertJavaRuntimeInstallWithFakeAdoptium :: FilePath -> IO ()
assertJavaRuntimeInstallWithFakeAdoptium tempDir = do
  manager <- makeHttpManager
  now <- getCurrentTime
  let root = tempDir </> ("panino-fake-adoptium-" <> safePathSuffix (show now))
      sourceRoot = root </> "source"
      javaExecutable = sourceRoot </> "Contents" </> "Home" </> "bin" </> "java"
      archivePath = root </> "fake-java.tar.gz"
      appRoot = root </> "app"
  removeDirectoryRecursive root `catchAny` \_ -> pure ()
  createDirectoryIfMissing True (takeDirectory javaExecutable)
  BS8.writeFile javaExecutable (BS8.pack fakeJavaScript)
  _ <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", javaExecutable]) ""
  createTarGz sourceRoot archivePath
  checksum <- sha256Hex archivePath
  archive <- BL.fromStrict <$> BS.readFile archivePath
  let runInstall targetAppRoot shouldSetDefault checksumText =
        testWithApplication
          ( pure $ \request respond -> do
              let path = BS8.unpack (rawPathInfo request)
              if ".sha256.txt" `isSuffixOf` path
                then respond (responseLBS status200 [(hContentType, "text/plain")] (BL8.pack checksumText))
                else respond (responseLBS status200 [(hContentType, "application/gzip")] archive)
          )
          $ \port -> do
            setEnv "PANINO_ADOPTIUM_API_BASE" ("http://127.0.0.1:" <> show port)
            setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
            installJavaRuntime
              manager
              targetAppRoot
              JavaRuntimeInstallRequest
                { installRuntimeFeatureVersion = 21
                , installRuntimeProvider = "adoptium"
                , installRuntimeVendor = "temurin"
                , installRuntimeOs = Just "mac"
                , installRuntimeArch = Just "aarch64"
                , installRuntimeImageType = "jre"
                , installRuntimeSetDefault = shouldSetDefault
                , installRuntimeDownload = DownloadRuntimeOptions (Just 1) (Just 0) Nothing
                }
              (pure False)
              (\_ -> pure ())
  runtime <- runInstall appRoot True (Text.unpack checksum)
  assertEqual "fake Adoptium install writes managed runtime" 21 (managedRuntimeFeatureVersion runtime)
  policies <- readRuntimePolicies appRoot
  assertEqual "setDefault writes global managed runtime policy" [Just (managedRuntimeId runtime)] (map policyRecordPreferredRuntimeId policies)
  leftoverArchive <- doesFileExist (appRoot </> "runtimes" </> "java" </> "downloads" </> "temurin-21-mac-aarch64-jre.tar.gz")
  assertEqual "fake Adoptium install cleans archive" False leftoverArchive
  let mismatchRoot = root </> "mismatch-app"
  result <- try (runInstall mismatchRoot False (replicate 64 '0'))
  case (result :: Either SomeException JavaManagedRuntime) of
    Left _ -> pure ()
    Right _ -> do
      putStrLn "FAIL: fake Adoptium checksum mismatch"
      putStrLn "  expected: exception"
      putStrLn "  actual:   success"
      exitFailure
  mismatchManaged <- doesDirectoryExist (mismatchRoot </> "runtimes" </> "java" </> "managed")
  assertEqual "fake checksum mismatch does not install runtime" False mismatchManaged
  unsetEnv "PANINO_ADOPTIUM_API_BASE"
  unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
  removeDirectoryRecursive root `catchAny` \_ -> pure ()

assertAutoJavaPathDownloadsManagedRuntime :: FilePath -> IO ()
assertAutoJavaPathDownloadsManagedRuntime tempDir = do
  manager <- makeHttpManager
  now <- getCurrentTime
  let root = tempDir </> ("panino-auto-java-path-" <> safePathSuffix (show now))
      gameDir = root </> "minecraft"
      appRoot = takeDirectory gameDir
      sourceRoot = root </> "source"
      javaExecutable = sourceRoot </> "Contents" </> "Home" </> "bin" </> "java"
      archivePath = root </> "fake-java.tar.gz"
      historyPath = root </> "task-history.json"
  removeDirectoryRecursive root `catchAny` \_ -> pure ()
  createDirectoryIfMissing True (takeDirectory javaExecutable)
  BS8.writeFile javaExecutable (BS8.pack fakeJavaScript)
  _ <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", javaExecutable]) ""
  createTarGz sourceRoot archivePath
  checksum <- sha256Hex archivePath
  archive <- BL.fromStrict <$> BS.readFile archivePath
  tasks <- newTVarIO Map.empty
  taskHandles <- newTVarIO Map.empty
  nextTaskId <- newTVarIO 1
  events <- newEventBus
  progressLabels <- newMVar []
  testWithApplication (pure fakeLoaderShaderPreflightApp) $ \minecraftPort ->
    testWithApplication
      ( pure $ \request respond -> do
          let path = BS8.unpack (rawPathInfo request)
          if ".sha256.txt" `isSuffixOf` path
            then respond (responseLBS status200 [(hContentType, "text/plain")] (BL8.pack (Text.unpack checksum)))
            else respond (responseLBS status200 [(hContentType, "application/gzip")] archive)
      )
      $ \javaPort -> do
        let minecraftBase = "http://127.0.0.1:" <> show minecraftPort
            javaBase = "http://127.0.0.1:" <> show javaPort
            state =
              ServerState
                { stateSessionToken = "test-token"
                , stateStartedAt = now
                , stateDefaultGameDir = Just gameDir
                , stateTasks = tasks
                , stateTaskHistoryPath = historyPath
                , stateTaskHandles = taskHandles
                , stateNextTaskId = nextTaskId
                , stateEvents = events
                , stateHttpManager = manager
                , stateShutdown = pure ()
                }
            withSources action =
              ( do
                  setEnv "PANINO_MOJANG_META_BASE" minecraftBase
                  setEnv "PANINO_ADOPTIUM_API_BASE" javaBase
                  setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
                  action
              )
                `finally` do
                  unsetEnv "PANINO_MOJANG_META_BASE"
                  unsetEnv "PANINO_ADOPTIUM_API_BASE"
                  unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
        withSources $ do
          layout <- mkLayout (Just gameDir)
          resolvedJava <-
            resolveAutoJavaPath
              state
              layout
              "26.1.2"
              (DownloadRuntimeOptions (Just 1) (Just 0) Nothing)
              (pure False)
              (\progress -> modifyMVar_ progressLabels (pure . (progressLabel progress :)))
          resolvedExists <- doesFileExist resolvedJava
          status <- checkJavaRuntime (JavaCheckRequest (Just resolvedJava))
          runtimes <- readManagedRuntimes appRoot
          labels <- readMVar progressLabels
          assertEqual "auto Java path downloads executable" True resolvedExists
          assertEqual "auto Java path returns Java 21" (Just 21) (javaResponseMajorVersion status)
          assertEqual "auto Java path writes managed runtime" [21] (map managedRuntimeFeatureVersion runtimes)
          assertEqual "auto Java path reports Java download progress" True (any ("Java 21 runtime" `isInfixOf`) labels)
  removeDirectoryRecursive root `catchAny` \_ -> pure ()

assertJavaRuntimeArchiveSafety :: FilePath -> IO ()
assertJavaRuntimeArchiveSafety tempDir = do
  now <- getCurrentTime
  let root = tempDir </> ("panino-java-archive-safety-" <> safePathSuffix (show now))
      traversalRoot = root </> "traversal"
      traversalArchive = traversalRoot </> "bad.zip"
      traversalOutside = root </> "outside.txt"
      symlinkRoot = root </> "symlink"
      symlinkArchive = symlinkRoot </> "bad-symlink.zip"
      appRoot = root </> "app"
  removeDirectoryRecursive root `catchAny` \_ -> pure ()
  createUnsafeTraversalZip traversalRoot traversalArchive
  traversalResult <- try (importRuntimeArchive appRoot traversalArchive)
  case (traversalResult :: Either SomeException JavaManagedRuntime) of
    Left _ -> pure ()
    Right _ -> do
      putStrLn "FAIL: unsafe zip traversal import"
      putStrLn "  expected: exception"
      putStrLn "  actual:   success"
      exitFailure
  escaped <- doesFileExist traversalOutside
  assertEqual "unsafe zip traversal does not create outside file" False escaped
  createUnsafeSymlinkZip symlinkRoot symlinkArchive
  symlinkResult <- try (importRuntimeArchive appRoot symlinkArchive)
  case (symlinkResult :: Either SomeException JavaManagedRuntime) of
    Left _ -> pure ()
    Right _ -> do
      putStrLn "FAIL: unsafe symlink zip import"
      putStrLn "  expected: exception"
      putStrLn "  actual:   success"
      exitFailure
  removeDirectoryRecursive root `catchAny` \_ -> pure ()

importRuntimeArchive :: FilePath -> FilePath -> IO JavaManagedRuntime
importRuntimeArchive appRoot archivePath =
  importJavaRuntime
    appRoot
    JavaRuntimeImportRequest
      { importRuntimeSourcePath = archivePath
      , importRuntimeProvider = "local"
      , importRuntimeVendor = "local"
      , importRuntimeFeatureVersion = Just 21
      , importRuntimeOs = Just "mac"
      , importRuntimeArch = Just "aarch64"
      , importRuntimeImageType = "jre"
      , importRuntimeSetDefault = False
      }

createUnsafeTraversalZip :: FilePath -> FilePath -> IO ()
createUnsafeTraversalZip sourceRoot archivePath = do
  createDirectoryIfMissing True (sourceRoot </> "inside")
  writeFile (sourceRoot </> "evil.txt") "escape"
  let process = (proc "/usr/bin/zip" ["-q", archivePath, "../evil.txt"]) { cwd = Just (sourceRoot </> "inside") }
  (exitCode, _, stderrText) <- readCreateProcessWithExitCode process ""
  assertEqual ("create unsafe traversal zip: " <> stderrText) ExitSuccess exitCode

createUnsafeSymlinkZip :: FilePath -> FilePath -> IO ()
createUnsafeSymlinkZip sourceRoot archivePath = do
  let runtimeRoot = sourceRoot </> "runtime"
      linkPath = runtimeRoot </> "escape-link"
  createDirectoryIfMissing True runtimeRoot
  createSymbolicLink "../outside" linkPath
  let process = (proc "/usr/bin/zip" ["-q", "-y", "-r", archivePath, "."]) { cwd = Just runtimeRoot }
  (exitCode, _, stderrText) <- readCreateProcessWithExitCode process ""
  assertEqual ("create unsafe symlink zip: " <> stderrText) ExitSuccess exitCode

fakeJavaScript :: String
fakeJavaScript =
  unlines
    [ "#!/bin/sh"
    , "echo 'java.version = 21.0.0' >&2"
    , "echo 'java.vendor = Panino Test' >&2"
    , "echo 'os.arch = aarch64' >&2"
    , "echo 'openjdk version \"21.0.0\"' >&2"
    , "exit 0"
    ]

fakeJavaSettingsScript :: String
fakeJavaSettingsScript =
  unlines
    [ "#!/bin/sh"
    , "echo 'Property settings:' >&2"
    , "echo '    java.version = 21.0.0' >&2"
    , "echo '    java.vendor = Panino Test' >&2"
    , "echo '    os.arch = aarch64' >&2"
    , "echo 'openjdk version \"21.0.0\"' >&2"
    , "exit 0"
    ]

createTarGz :: FilePath -> FilePath -> IO ()
createTarGz sourceRoot archivePath = do
  createDirectoryIfMissing True (takeDirectory archivePath)
  (_, _, _) <- readCreateProcessWithExitCode (proc "/usr/bin/tar" ["-czf", archivePath, "-C", sourceRoot, "."]) ""
  pure ()

sha256Hex :: FilePath -> IO Text.Text
sha256Hex path = do
  (exitCode, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc "/usr/bin/shasum" ["-a", "256", path]) ""
  case exitCode of
    ExitSuccess -> pure (Text.pack (takeWhile (/= ' ') stdoutText))
    ExitFailure _ -> fail stderrText

assertDownloadRejects404 :: FilePath -> IO ()
assertDownloadRejects404 tempDir = do
  manager <- makeHttpManager
  let target = tempDir </> "panino-core-download-404-test.jar"
      part = target <.> "part"
  removeIfExists target
  removeIfExists part
  testWithApplication
    ( pure $ \_ respond ->
        respond (responseLBS status404 [] "missing")
    )
    $ \port -> do
      result <-
        try
          ( do
              _ <-
                downloadSingle manager DownloadJob
                  { jobLabel = "404-test"
                  , jobUrl = "http://127.0.0.1:" <> show port <> "/missing.jar"
                  , jobTargetPath = target
                  , jobSha1 = Nothing
                  , jobSize = Nothing
                  }
              pure ()
          )
      case (result :: Either SomeException ()) of
        Left _ -> pure ()
        Right _ -> do
          putStrLn "FAIL: download rejects 404"
          putStrLn "  expected: exception"
          putStrLn "  actual:   success"
          exitFailure
      targetExists <- doesFileExist target
      partExists <- doesFileExist part
      assertEqual "download 404 does not write target" False targetExists
      assertEqual "download 404 does not write part" False partExists

assertDownloadRetryOptions :: FilePath -> IO ()
assertDownloadRetryOptions tempDir = do
  manager <- makeHttpManager
  attempts <- newMVar (0 :: Int)
  let target = tempDir </> "panino-core-retry-test.bin"
      part = target <.> "part"
      payload = "ok"
      baseJob =
        DownloadJob
          { jobLabel = "retry-test"
          , jobUrl = ""
          , jobTargetPath = target
          , jobSha1 = Nothing
          , jobSize = Just 2
          }
  removeIfExists target
  removeIfExists part
  testWithApplication
    ( pure $ \_ respond -> do
        count <- modifyMVar attempts $ \current -> do
          let next = current + 1
          pure (next, next)
        if count == 1
          then respond (responseLBS status503 [] "try again")
          else respond (responseLBS status200 [("Content-Length", "2")] payload)
    )
    $ \port -> do
      let job = baseJob { jobUrl = "http://127.0.0.1:" <> show port <> "/retry.bin" }
      summary <-
        runDownloadJobsWithOptionsAndProgressAndCancel
          manager
          (downloadOptionsWithOverrides (Just 1) (Just 1))
          (pure False)
          [job]
          (\_ -> pure ())
      assertEqual "download retry options checked files" 1 (totalCount summary)
      assertEqual "download retry options retried once" 2 =<< readMVar attempts
      targetExists <- doesFileExist target
      assertEqual "download retry options writes target" True targetExists

assertDownloadProgressCompletion :: FilePath -> IO ()
assertDownloadProgressCompletion tempDir = do
  manager <- makeHttpManager
  events <- newMVar []
  let target = tempDir </> "panino-core-progress-test.bin"
      part = target <.> "part"
      payload = BS.replicate 8192 80
      expectedSize = fromIntegral (BS.length payload)
      job =
        DownloadJob
          { jobLabel = "progress-test"
          , jobUrl = ""
          , jobTargetPath = target
          , jobSha1 = Nothing
          , jobSize = Just expectedSize
          }
  removeIfExists target
  removeIfExists part
  testWithApplication
    ( pure $ \_ respond ->
        respond
          ( responseLBS
              status200
              [("Content-Length", BS8.pack (show expectedSize))]
              (BL.fromStrict payload)
          )
    )
    $ \port -> do
      let downloadJob = job { jobUrl = "http://127.0.0.1:" <> show port <> "/progress.bin" }
      _ <-
        runDownloadJobsWithOptionsAndProgressAndCancel
          manager
          (downloadOptionsWithOverrides (Just 1) (Just 0))
          (pure False)
          [downloadJob]
          (\progress -> modifyMVar_ events (pure . (progress :)))
      snapshots <- reverse <$> readMVar events
      let percentages = [value | DownloadProgress { progressPercent = Just value } <- snapshots]
      assertEqual "download progress starts at 0" (Just 0) (roundedHead percentages)
      assertEqual "download progress ends at 100" (Just 100) (roundedLast percentages)
      assertEqual "download progress terminal jobs" (Just (1, 1)) (terminalJobs snapshots)
      targetExists <- doesFileExist target
      assertEqual "download progress writes target" True targetExists

assertDownloadProgressWaitsForUnknownTailJobs :: FilePath -> IO ()
assertDownloadProgressWaitsForUnknownTailJobs tempDir = do
  manager <- makeHttpManager
  events <- newMVar []
  let knownPayload = BS.replicate 8192 81
      unknownPayload = "tail"
      expectedSize = fromIntegral (BS.length knownPayload)
      knownTarget = tempDir </> "panino-core-progress-known-tail-test.bin"
      unknownTarget = tempDir </> "panino-core-progress-unknown-tail-test.bin"
      knownJob port =
        DownloadJob
          { jobLabel = "known-tail-test"
          , jobUrl = "http://127.0.0.1:" <> show port <> "/known.bin"
          , jobTargetPath = knownTarget
          , jobSha1 = Nothing
          , jobSize = Just expectedSize
          }
      unknownJob port =
        DownloadJob
          { jobLabel = "unknown-tail-test"
          , jobUrl = "http://127.0.0.1:" <> show port <> "/unknown.bin"
          , jobTargetPath = unknownTarget
          , jobSha1 = Nothing
          , jobSize = Nothing
          }
  removeIfExists knownTarget
  removeIfExists (knownTarget <.> "part")
  removeIfExists unknownTarget
  removeIfExists (unknownTarget <.> "part")
  testWithApplication
    ( pure $ \request respond ->
        case rawPathInfo request of
          "/known.bin" ->
            respond
              ( responseStream
                  status200
                  [("Content-Length", BS8.pack (show expectedSize))]
                  $ \send flush -> do
                    send (Builder.byteString (BS.take 4096 knownPayload))
                    flush
                    threadDelay 300000
                    send (Builder.byteString (BS.drop 4096 knownPayload))
                    flush
              )
          "/unknown.bin" ->
            respond (responseLBS status200 [] (BL.fromStrict unknownPayload))
          _ ->
            respond (responseLBS status404 [] "not found")
    )
    $ \port -> do
      _ <-
        runDownloadJobsWithOptionsAndProgressAndCancel
          manager
          (downloadOptionsWithOverrides (Just 1) (Just 0))
          (pure False)
          [knownJob port, unknownJob port]
          (\progress -> modifyMVar_ events (pure . (progress :)))
      snapshots <- reverse <$> readMVar events
      let tailSnapshots =
            [ progress
            | progress <- snapshots
            , progressCompletedJobs progress < progressTotalJobs progress
            , progressTotalBytes progress > 0
            , progressCompletedBytes progress == progressTotalBytes progress
            ]
          cappedTail =
            [ progress
            | progress@DownloadProgress { progressPercent = Just percent } <- tailSnapshots
            , percent < 100
            , round percent < (100 :: Int)
            , progressEtaSeconds progress == Nothing
            ]
      assertEqual "download progress keeps tail below 100 before all jobs finish" True (not (null cappedTail))
      assertEqual "download progress tail still reaches terminal jobs" (Just (2, 2)) (terminalJobs snapshots)
      assertEqual "download progress tail terminal reaches 100" (Just 100) (roundedLast [value | DownloadProgress { progressPercent = Just value } <- snapshots])

assertDownloadConcurrencyOptions :: FilePath -> IO ()
assertDownloadConcurrencyOptions tempDir = do
  manager <- makeHttpManager
  let payload = BS.replicate 4096 65
      expectedSize = fromIntegral (BS.length payload)
      makeJobs port label =
        [ DownloadJob
            { jobLabel = label <> "-" <> show index
            , jobUrl = "http://127.0.0.1:" <> show port <> "/" <> label <> "/" <> show index <> ".bin"
            , jobTargetPath = tempDir </> ("panino-core-" <> label <> "-" <> show index <> ".bin")
            , jobSha1 = Nothing
            , jobSize = Just expectedSize
            }
        | index <- [1 :: Int .. 8]
        ]
      cleanup jobs = mapM_ (\job -> removeIfExists (jobTargetPath job) >> removeIfExists (jobTargetPath job <.> "part")) jobs
  testWithApplication
    ( pure $ \_ respond ->
        respond
          ( responseStream
              status200
              [("Content-Length", BS8.pack (show expectedSize))]
              $ \send flush -> do
                send (Builder.byteString (BS.take 1024 payload))
                flush
                threadDelay 30000
                send (Builder.byteString (BS.drop 1024 payload))
                flush
          )
    )
    $ \port -> do
      let runWith requested label = do
            maxActive <- newMVar (0 :: Int)
            let jobs = makeJobs port label
            cleanup jobs
            _ <-
              runDownloadJobsWithOptionsAndProgressAndCancel
                manager
                (downloadOptionsWithOverrides (Just requested) (Just 0))
                (pure False)
                jobs
                (\progress -> modifyMVar_ maxActive (pure . max (progressActiveWorkers progress)))
            readMVar maxActive
      oneWorkerMax <- runWith 1 "concurrency-one"
      eightWorkerMax <- runWith 8 "concurrency-eight"
      assertEqual "download concurrency 1 keeps one active worker" True (oneWorkerMax <= 1)
      assertEqual "download concurrency 8 uses multiple active workers" True (eightWorkerMax > 1)

assertMultipartDownload :: FilePath -> IO ()
assertMultipartDownload tempDir = do
  manager <- makeHttpManager
  let payload = BS.concat (replicate 1300000 "0123456789abcdef")
      expectedSize = fromIntegral (BS.length payload)
      target = tempDir </> "panino-core-multipart-test.bin"
      part = target <.> "part"
  removeIfExists target
  removeIfExists part
  testWithApplication
    ( pure $ \request respond ->
        case requestMethod request of
          "HEAD" ->
            respond
              ( responseLBS
                  status200
                  [ ("Accept-Ranges", "bytes")
                  , ("Content-Length", BS8.pack (show (BS.length payload)))
                  ]
                  ""
              )
          _ ->
            case parseRange (lookup "Range" (requestHeaders request)) of
              Just (start, end) ->
                let slice = BS.take (end - start + 1) (BS.drop start payload)
                 in respond
                      ( responseLBS
                          status206
                          [ ("Accept-Ranges", "bytes")
                          , ("Content-Length", BS8.pack (show (BS.length slice)))
                          ]
                          (BL.fromStrict slice)
                      )
              Nothing ->
                respond
                  ( responseLBS
                      status200
                      [ ("Accept-Ranges", "bytes")
                      , ("Content-Length", BS8.pack (show (BS.length payload)))
                      ]
                      (BL.fromStrict payload)
                  )
    )
    $ \port ->
      finally
        ( do
            setEnv "PANINO_MULTIPART_MIN_BYTES" "1024"
            let targetUrl = "http://127.0.0.1:" <> show port <> "/file.bin"
                job =
                  DownloadJob
                    { jobLabel = "multipart-test"
                    , jobUrl = targetUrl
                    , jobTargetPath = target
                    , jobSha1 = Nothing
                    , jobSize = Just expectedSize
                    }
            result <- downloadSingle manager job
            assertEqual "multipart download result" (Downloaded job) result
            exists <- doesFileExist target
            assertEqual "multipart writes final target" True exists
            actualSize <- fromIntegral <$> getFileSize target
            assertEqual "multipart final size" expectedSize actualSize
        )
        (unsetEnv "PANINO_MULTIPART_MIN_BYTES")

assertMultipartRangeGetFallback :: FilePath -> IO ()
assertMultipartRangeGetFallback tempDir = do
  manager <- makeHttpManager
  rangedRequests <- newMVar (0 :: Int)
  let payload = BS.concat (replicate 1024 "range-fallback")
      expectedSize = fromIntegral (BS.length payload)
      target = tempDir </> "panino-core-multipart-range-fallback.bin"
      part = target <.> "part"
  removeIfExists target
  removeIfExists part
  removeIfExists (part <> ".map")
  testWithApplication
    ( pure $ \request respond ->
        case requestMethod request of
          "HEAD" ->
            respond
              ( responseLBS
                  status200
                  [("Content-Length", BS8.pack (show (BS.length payload)))]
                  ""
              )
          _ ->
            case parseRange (lookup "Range" (requestHeaders request)) of
              Just (start, end) -> do
                _ <- modifyMVar rangedRequests $ \current -> let next = current + 1 in pure (next, next)
                let slice = BS.take (end - start + 1) (BS.drop start payload)
                respond
                  ( responseLBS
                      status206
                      [("Content-Length", BS8.pack (show (BS.length slice)))]
                      (BL.fromStrict slice)
                  )
              Nothing ->
                respond
                  ( responseLBS
                      status200
                      [("Content-Length", BS8.pack (show (BS.length payload)))]
                      (BL.fromStrict payload)
                  )
    )
    $ \port ->
      finally
        ( do
            setEnv "PANINO_MULTIPART_MIN_BYTES" "1024"
            let job =
                  DownloadJob
                    { jobLabel = "multipart-range-fallback"
                    , jobUrl = "http://127.0.0.1:" <> show port <> "/range.bin"
                    , jobTargetPath = target
                    , jobSha1 = Nothing
                    , jobSize = Just expectedSize
                    }
            result <- downloadSingle manager job
            assertEqual "multipart range fallback result" (Downloaded job) result
            rangeCount <- readMVar rangedRequests
            assertEqual "multipart range fallback used GET Range" True (rangeCount > 0)
            actualSize <- fromIntegral <$> getFileSize target
            assertEqual "multipart range fallback final size" expectedSize actualSize
            sidecarExists <- doesFileExist (part <> ".map")
            assertEqual "multipart range fallback removes sidecar" False sidecarExists
        )
        (unsetEnv "PANINO_MULTIPART_MIN_BYTES")

assertMultipartRangeIgnoredFallsBack :: FilePath -> IO ()
assertMultipartRangeIgnoredFallsBack tempDir = do
  manager <- makeHttpManager
  rangedRequests <- newMVar (0 :: Int)
  fullRequests <- newMVar (0 :: Int)
  let payload = BS.concat (replicate 1024 "range-ignored")
      expectedSize = fromIntegral (BS.length payload)
      target = tempDir </> "panino-core-multipart-range-ignored.bin"
      part = target <.> "part"
  removeIfExists target
  removeIfExists part
  removeIfExists (part <> ".map")
  testWithApplication
    ( pure $ \request respond ->
        case requestMethod request of
          "HEAD" ->
            respond
              ( responseLBS
                  status200
                  [("Content-Length", BS8.pack (show (BS.length payload)))]
                  ""
              )
          _ -> do
            case lookup "Range" (requestHeaders request) of
              Just _ -> do
                _ <- modifyMVar rangedRequests $ \current -> let next = current + 1 in pure (next, next)
                respond (responseLBS status200 [("Content-Length", BS8.pack (show (BS.length payload)))] (BL.fromStrict payload))
              Nothing -> do
                _ <- modifyMVar fullRequests $ \current -> let next = current + 1 in pure (next, next)
                respond (responseLBS status200 [("Content-Length", BS8.pack (show (BS.length payload)))] (BL.fromStrict payload))
    )
    $ \port ->
      finally
        ( do
            setEnv "PANINO_MULTIPART_MIN_BYTES" "1024"
            let job =
                  DownloadJob
                    { jobLabel = "multipart-range-ignored"
                    , jobUrl = "http://127.0.0.1:" <> show port <> "/ignored.bin"
                    , jobTargetPath = target
                    , jobSha1 = Nothing
                    , jobSize = Just expectedSize
                    }
            result <- downloadSingle manager job
            assertEqual "multipart ignored range fallback result" (Downloaded job) result
            assertEqual "multipart ignored range probes once" 1 =<< readMVar rangedRequests
            assertEqual "multipart ignored range falls back to full GET" 1 =<< readMVar fullRequests
            actualSize <- fromIntegral <$> getFileSize target
            assertEqual "multipart ignored range final size" expectedSize actualSize
        )
        (unsetEnv "PANINO_MULTIPART_MIN_BYTES")

assertDownloadCancellation :: FilePath -> IO ()
assertDownloadCancellation tempDir = do
  manager <- makeHttpManager
  cancelFlag <- newMVar False
  let chunk = BS.replicate 65536 65
      chunkCount = 64
      expectedSize = fromIntegral (BS.length chunk * chunkCount)
      target = tempDir </> "panino-core-cancel-test.bin"
      part = target <.> "part"
  removeIfExists target
  removeIfExists part
  testWithApplication
    ( pure $ \_ respond ->
        respond
          ( responseStream
              status200
              [("Content-Length", BS8.pack (show expectedSize))]
              $ \send flush -> do
                let loop 0 = pure ()
                    loop remaining = do
                      send (Builder.byteString chunk)
                      flush
                      threadDelay 10000
                      loop (remaining - 1)
                loop chunkCount
          )
    )
    $ \port -> do
      let job =
            DownloadJob
              { jobLabel = "cancel-test"
              , jobUrl = "http://127.0.0.1:" <> show port <> "/cancel.bin"
              , jobTargetPath = target
              , jobSha1 = Nothing
              , jobSize = Just expectedSize
              }
      result <-
        try
          ( do
              _ <-
                runDownloadJobsWithProgressAndCancel
                  manager
                  1
                  (readMVar cancelFlag)
                  [job]
                  $ \progress ->
                    when (progressCompletedBytes progress > 0) $
                      modifyMVar_ cancelFlag (const (pure True))
              pure ()
          )
      case (result :: Either SomeException ()) of
        Left err ->
          case fromException err of
            Just DownloadCancelled -> pure ()
            _ -> do
              putStrLn "FAIL: cancelled download raises DownloadCancelled"
              putStrLn ("  actual: " <> show err)
              exitFailure
        Right _ -> do
          putStrLn "FAIL: cancelled download stops"
          putStrLn "  expected: DownloadCancelled"
          putStrLn "  actual:   success"
          exitFailure
      threadDelay 100000
      targetExists <- doesFileExist target
      assertEqual "cancelled download does not write final target" False targetExists
      partExists <- doesFileExist part
      when partExists $ do
        partSize <- fromIntegral <$> getFileSize part
        assertEqual "cancelled download leaves incomplete part" True (partSize < expectedSize)

parseRange :: Maybe BS.ByteString -> Maybe (Int, Int)
parseRange Nothing = Nothing
parseRange (Just raw) =
  case stripPrefix "bytes=" (BS8.unpack raw) of
    Nothing -> Nothing
    Just value ->
      case break (== '-') value of
        (startText, '-' : endText) -> do
          start <- readMaybeString startText
          end <- readMaybeString endText
          pure (start, end)
        _ -> Nothing

readMaybeString :: String -> Maybe Int
readMaybeString value =
  case reads value of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing

assertFabricApiNestedJarPreflight :: IO ()
assertFabricApiNestedJarPreflight = do
  tempDir <- getTemporaryDirectory
  let root = tempDir </> "panino-core-nested-preflight-test"
      gameDir = root </> "game"
      modsDir = gameDir </> "mods"
      sodiumDir = root </> "sodium"
      fabricOuterDir = root </> "fabric-api"
      fabricNestedDir = root </> "fabric-block-view-api-v2"
      sodiumJar = modsDir </> "sodium.jar"
      fabricApiJar = modsDir </> "fabric-api.jar"
      nestedJar = fabricOuterDir </> "jars" </> "fabric-block-view-api-v2.jar"
  removeDirectoryRecursive root `catchAny` \_ -> pure ()
  createDirectoryIfMissing True modsDir
  createDirectoryIfMissing True sodiumDir
  createDirectoryIfMissing True (fabricOuterDir </> "jars")
  createDirectoryIfMissing True fabricNestedDir
  BL8.writeFile (sodiumDir </> "fabric.mod.json") "{\"id\":\"sodium\",\"depends\":{\"fabric-block-view-api-v2\":\"*\"}}"
  BL8.writeFile (fabricOuterDir </> "fabric.mod.json") "{\"id\":\"fabric-api\",\"jars\":[{\"file\":\"jars/fabric-block-view-api-v2.jar\"}]}"
  BL8.writeFile (fabricNestedDir </> "fabric.mod.json") "{\"id\":\"fabric-block-view-api-v2\"}"
  zipDirectory fabricNestedDir nestedJar
  zipDirectory sodiumDir sodiumJar
  zipDirectory fabricOuterDir fabricApiJar
  preflightModDependencies gameDir
  removeDirectoryRecursive root `catchAny` \_ -> pure ()

zipDirectory :: FilePath -> FilePath -> IO ()
zipDirectory sourceDir targetJar = do
  removeIfExists targetJar
  (_, _, _, processHandle) <-
    createProcess
      (proc "/usr/bin/zip" ["-q", "-r", targetJar, "."])
        { cwd = Just sourceDir
        }
  exitCode <- waitForProcess processHandle
  assertEqual ("zip " <> targetJar) ExitSuccess exitCode

assertModrinthPreferredVersionSelection :: IO ()
assertModrinthPreferredVersionSelection = do
  let sodium1218 =
        testModrinthVersion
          "sodium-1218"
          "Sodium 0.7.0 for Fabric 1.21.8"
          "mc1.21.8-0.7.0-fabric"
          "2026-01-02T00:00:00Z"
          "sodium-fabric-0.7.0+mc1.21.8.jar"
      sodium1217 =
        testModrinthVersion
          "sodium-1217"
          "Sodium 0.7.0 for Fabric 1.21.7"
          "mc1.21.7-0.7.0-fabric"
          "2026-01-01T00:00:00Z"
          "sodium-fabric-0.7.0+mc1.21.7.jar"
      selected =
        selectPreferredModrinthVersion "1.21.7" "quilt" [sodium1218, sodium1217]
  assertEqual
    "Modrinth selection prefers file/version text matching requested Minecraft version"
    (Just "sodium-1217")
    (modrinthVersionId <$> selected)

assertTrackedShaderInstallCleanup :: FilePath -> IO ()
assertTrackedShaderInstallCleanup tempRoot = do
  let root = tempRoot </> "panino-shader-cleanup"
      trackedIris = "iris-1.0.0.jar"
      trackedSodium = "sodium-fabric-0.7.0+mc1.21.8.jar"
      userJar = "user-mod.jar"
  exists <- doesDirectoryExist root
  when exists (removeDirectoryRecursive root)
  layout <- mkLayout (Just root)
  createDirectoryIfMissing True (minecraftRoot layout </> "mods")
  createDirectoryIfMissing True (minecraftRoot layout </> "downloads")
  writeFile (minecraftRoot layout </> "mods" </> trackedIris) "iris"
  writeFile (minecraftRoot layout </> "mods" </> trackedSodium) "sodium"
  writeFile (minecraftRoot layout </> "mods" </> userJar) "user"
  writeFile
    (minecraftRoot layout </> "downloads" </> "shader-install.log")
    ( unlines
        [ "iris file=iris-1.0.0.jar url=https://cdn.example/iris.jar"
        , "AANobbMI file=sodium-fabric-0.7.0+mc1.21.8.jar url=https://cdn.example/sodium.jar"
        ]
    )
  removeTrackedShaderInstallFiles layout
  trackedIrisExists <- doesFileExist (minecraftRoot layout </> "mods" </> trackedIris)
  trackedSodiumExists <- doesFileExist (minecraftRoot layout </> "mods" </> trackedSodium)
  userJarExists <- doesFileExist (minecraftRoot layout </> "mods" </> userJar)
  assertEqual "tracked shader cleanup removes Iris companion" False trackedIrisExists
  assertEqual "tracked shader cleanup removes Sodium companion" False trackedSodiumExists
  assertEqual "tracked shader cleanup preserves untracked user mod" True userJarExists

testModrinthVersion :: Text -> Text -> Text -> Text -> Text -> ModrinthVersion
testModrinthVersion modrinthId displayName versionNumber publishedAt jarName =
  ModrinthVersion
    { modrinthVersionId = modrinthId
    , modrinthVersionProjectId = "AANobbMI"
    , modrinthVersionGameVersions = ["1.21.7", "1.21.8"]
    , modrinthVersionLoaders = ["fabric", "quilt"]
    , modrinthVersionName = displayName
    , modrinthVersionNumber = versionNumber
    , modrinthVersionType = "release"
    , modrinthVersionDatePublished = Just publishedAt
    , modrinthVersionFeatured = False
    , modrinthVersionFiles =
        [ ModrinthFile
            { modrinthFileName = jarName
            , modrinthFileUrl = "https://cdn.modrinth.test/" <> jarName
            , modrinthFilePrimary = True
            , modrinthFileHashes = Map.empty
            , modrinthFileSize = Just 1
            }
        ]
    , modrinthVersionDependencies = []
    }

assertModrinthDependencyResolver :: IO ()
assertModrinthDependencyResolver = do
  manager <- makeHttpManager
  tempDir <- getTemporaryDirectory
  testWithApplication
    ( pure $ \request respond -> do
        let requestBase =
              "http://"
                <> BS8.unpack
                  ( case requestHeaderHost request of
                      Just host -> host
                      Nothing -> "127.0.0.1"
                  )
        respond $
          case BS8.unpack (rawPathInfo request) of
            "/mc/game/version_manifest_v2.json" ->
              responseLBS status200 [(hContentType, "application/json")] (minecraftManifestFixture requestBase)
            "/versions/26.1.2.json" ->
              responseLBS status200 [(hContentType, "application/json")] (minecraftVersionFixture requestBase)
            "/v2/project/iris" ->
              responseLBS status200 [(hContentType, "application/json")] (modrinthProjectMetadataFixture "iris" "Iris")
            "/v2/project/iris/version" ->
              responseLBS status200 [(hContentType, "application/json")] modrinthIrisVersionsJson
            "/v2/project/fabric-api" ->
              responseLBS status200 [(hContentType, "application/json")] (modrinthProjectMetadataFixture "fabric-api" "Fabric API")
            "/v2/project/fabric-api/version" ->
              responseLBS status200 [(hContentType, "application/json")] modrinthDependencyVersionsJson
            "/v1/mods/123" ->
              responseLBS status200 [(hContentType, "application/json")] (curseForgeProjectFixture 123 "Curse Root")
            "/v1/mods/123/files" ->
              responseLBS status200 [(hContentType, "application/json")] (curseForgeFilesFixture 1001 "curse-root.jar" "3333333333333333333333333333333333333333" [456])
            "/v1/mods/456" ->
              responseLBS status200 [(hContentType, "application/json")] (curseForgeProjectFixture 456 "Curse Dependency")
            "/v1/mods/456/files" ->
              responseLBS status200 [(hContentType, "application/json")] (curseForgeFilesFixture 2002 "curse-dependency.jar" "4444444444444444444444444444444444444444" [])
            _ ->
              responseLBS status200 [(hContentType, "application/json")] modrinthDependencyVersionsJson
    )
    $ \port ->
      ( do
          setEnv "PANINO_MODRINTH_API_BASE" ("http://127.0.0.1:" <> show port)
          setEnv "PANINO_CURSEFORGE_API_BASE" ("http://127.0.0.1:" <> show port)
          setEnv "PANINO_MOJANG_META_BASE" ("http://127.0.0.1:" <> show port)
          setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
          releases <- modrinthRequiredDependencyReleases manager dependencyQuery [fabricApiDependency]
          assertEqual "modrinth dependency resolver release" ["fabric-api-version"] (map releaseId releases)
          assertEqual "modrinth dependency resolver file" ["fabric-api-1.0.0.jar"] (concatMap (map fileName . releaseFiles) releases)
          let irisRoot =
                (testLockfilePackage "iris" "Iris" "iris-version" "iris.jar" "mods/iris.jar" "2222222222222222222222222222222222222222" [testPackageConstraint "iris" "fabric-api" "requires" True])
                  { resolvedPackageGameVersions = ["26.1.2"]
                  }
              solverRequest =
                (testLockfileSolveRequest "/tmp/panino-lockfile-modrinth-deps" [irisRoot] Nothing)
                  { solveRequestMinecraftVersion = Just "26.1.2"
                  , solveRequestLoader = Nothing
                  , solveRequestShaderLoader = Nothing
                  }
          solverResult <- solveLockfileWithServices manager solverRequest
          assertEqual "lockfile solver reuses Modrinth dependency resolver" "ready" (solverResultStatus solverResult)
          assertEqual
            "lockfile solver includes resolved Modrinth dependency"
            True
            ( maybe
                False
                (("fabric-api" `elem`) . map resolvedPackageId . lockfilePackages)
                (solverResultLockfile solverResult)
            )
          assertEqual
            "lockfile solver records Java runtime requirement"
            True
            ( maybe
                False
                (("java:21" `elem`) . map resolvedPackageId . lockfilePackages)
                (solverResultLockfile solverResult)
            )
          let modrinthRoot =
                (testLockfilePackage "iris" "Iris" "placeholder" "iris.jar" "mods/iris.jar" "2222222222222222222222222222222222222222" [])
                  { resolvedPackageCoordinate =
                      PackageCoordinate
                        { coordinateSource = "modrinth"
                        , coordinateProjectId = Just "iris"
                        , coordinateVersionId = Nothing
                        , coordinateFileId = Nothing
                        , coordinateSlug = Just "iris"
                        , coordinateName = Just "Iris"
                        , coordinateKind = "mod"
                        }
                  , resolvedPackageVersionName = Nothing
                  , resolvedPackageFileName = Nothing
                  , resolvedPackageTargetPath = Nothing
                  , resolvedPackageHashes = Map.empty
                  , resolvedPackageDownloadUrls = []
                  , resolvedPackageGameVersions = []
                  , resolvedPackageLoaders = []
                  }
              modrinthRootRequest =
                (testLockfileSolveRequest "/tmp/panino-lockfile-modrinth-root" [modrinthRoot] Nothing)
                  { solveRequestMinecraftVersion = Just "26.1.2"
                  , solveRequestLoader = Nothing
                  , solveRequestShaderLoader = Nothing
                  }
          modrinthRootResult <- solveLockfileWithServices manager modrinthRootRequest
          assertEqual ("lockfile solver resolves Modrinth project root: " <> show (solverResultBlockedReasons modrinthRootResult)) "ready" (solverResultStatus modrinthRootResult)
          assertEqual
            "lockfile solver resolves Modrinth root dependency"
            ["fabric-api", "iris", "java:21"]
            (maybe [] (map resolvedPackageId . lockfilePackages) (solverResultLockfile modrinthRootResult))
          let curseRoot =
                modrinthRoot
                  { resolvedPackageId = "123"
                  , resolvedPackageDisplayName = "Curse Root"
                  , resolvedPackageCoordinate =
                      PackageCoordinate
                        { coordinateSource = "curseforge"
                        , coordinateProjectId = Just "123"
                        , coordinateVersionId = Nothing
                        , coordinateFileId = Nothing
                        , coordinateSlug = Just "curse-root"
                        , coordinateName = Just "Curse Root"
                        , coordinateKind = "mod"
                        }
                  }
              curseRootRequest =
                (testLockfileSolveRequest "/tmp/panino-lockfile-curse-root" [curseRoot] Nothing)
                  { solveRequestMinecraftVersion = Just "26.1.2"
                  , solveRequestLoader = Nothing
                  , solveRequestShaderLoader = Nothing
                  , solveRequestCurseForgeApiKey = Just "test-key"
                  }
          curseRootResult <- solveLockfileWithServices manager curseRootRequest
          assertEqual ("lockfile solver resolves CurseForge project root: " <> show (solverResultBlockedReasons curseRootResult)) "ready" (solverResultStatus curseRootResult)
          assertEqual
            "lockfile solver resolves CurseForge required dependency"
            ["123", "456", "java:21"]
            (maybe [] (map resolvedPackageId . lockfilePackages) (solverResultLockfile curseRootResult))
          performancePackResult <-
            solveLockfileWithServices
              manager
              ( (testLockfileSolveRequest "/tmp/panino-lockfile-performance-pack" [] Nothing)
                  { solveRequestMinecraftVersion = Nothing
                  , solveRequestLoader = Just "fabric"
                  , solveRequestShaderLoader = Nothing
                  , solveRequestIncludePerformancePack = True
                  }
              )
          assertEqual "lockfile solver records performance pack root request" "ready" (solverResultStatus performancePackResult)
          assertEqual
            "lockfile performance pack is a root package"
            True
            ( maybe
                False
                (("performance-pack:fabric" `elem`) . map resolvedPackageId . lockfilePackages)
                (solverResultLockfile performancePackResult)
            )
          assertEqual "lockfile performance pack keeps recommended mods optional" True (not (null (explainRejectedCandidates (solverResultExplain performancePackResult))))
          let managedJavaRequest =
                (testLockfileSolveRequest (tempDir </> "panino-lockfile-managed-java" </> "game") [] Nothing)
                  { solveRequestMinecraftVersion = Just "26.1.2"
                  , solveRequestLoader = Nothing
                  , solveRequestShaderLoader = Nothing
                  , solveRequestJavaPolicy = Just (object ["policy" .= ("managed" :: Text)])
                  }
          managedJavaTargetExistsBefore <- doesDirectoryExist (solveRequestTargetGameDir managedJavaRequest)
          when managedJavaTargetExistsBefore (removeDirectoryRecursive (solveRequestTargetGameDir managedJavaRequest))
          managedJavaResult <- solveLockfileWithServices manager managedJavaRequest
          managedJavaTargetExists <- doesDirectoryExist (solveRequestTargetGameDir managedJavaRequest)
          assertEqual "lockfile solver blocks unavailable managed Java" "blocked" (solverResultStatus managedJavaResult)
          assertEqual "lockfile solver still locks required Java package when managed runtime is unavailable" True (maybe False (("java:21" `elem`) . map resolvedPackageId . lockfilePackages) (solverResultLockfile managedJavaResult))
          assertEqual "blocked Java runtime plan is not executable" "blocked" (typedPlanStatus (solverResultTypedPlan managedJavaResult))
          assertEqual "lockfile service solve does not create target game directory" False managedJavaTargetExists
          now <- getCurrentTime
          let managedAppRoot = tempDir </> "panino-lockfile-managed-java-ready"
              managedJavaExecutable = managedAppRoot </> "runtimes" </> "java" </> "managed" </> "temurin-21-test" </> "Contents" </> "Home" </> "bin" </> "java"
              managedRuntime =
                JavaManagedRuntime
                  { managedRuntimeId = "temurin-21-test"
                  , managedRuntimeVendor = "temurin"
                  , managedRuntimeProvider = "adoptium"
                  , managedRuntimeFeatureVersion = 21
                  , managedRuntimeVersion = "21.0.0"
                  , managedRuntimeOs = "mac"
                  , managedRuntimeArch = "aarch64"
                  , managedRuntimeImageType = "jre"
                  , managedRuntimeJavaHome = takeDirectory (takeDirectory managedJavaExecutable)
                  , managedRuntimeJavaExecutable = managedJavaExecutable
                  , managedRuntimeSourceUrl = "https://example.invalid/java-21.tar.gz"
                  , managedRuntimeSha256 = Just "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                  , managedRuntimeInstalledAt = now
                  , managedRuntimeLastVerifiedAt = Just now
                  , managedRuntimeDiskUsageBytes = Just 0
                  , managedRuntimeUsedByInstanceCount = 0
                  }
          createDirectoryIfMissing True (takeDirectory managedJavaExecutable)
          _ <- upsertManagedRuntime managedAppRoot managedRuntime
          let managedX64JavaExecutable = managedAppRoot </> "runtimes" </> "java" </> "managed" </> "temurin-21-x64-test" </> "Contents" </> "Home" </> "bin" </> "java"
              managedX64Runtime =
                managedRuntime
                  { managedRuntimeId = "temurin-21-x64-test"
                  , managedRuntimeArch = "x64"
                  , managedRuntimeJavaHome = takeDirectory (takeDirectory managedX64JavaExecutable)
                  , managedRuntimeJavaExecutable = managedX64JavaExecutable
                  }
          createDirectoryIfMissing True (takeDirectory managedX64JavaExecutable)
          _ <- upsertManagedRuntime managedAppRoot managedX64Runtime
          let managedReadyRequest =
                (testLockfileSolveRequest (managedAppRoot </> "game") [] Nothing)
                  { solveRequestMinecraftVersion = Just "26.1.2"
                  , solveRequestLoader = Nothing
                  , solveRequestShaderLoader = Nothing
                  , solveRequestJavaPolicy =
                      Just
                        ( object
                            [ "policy" .= ("managed" :: Text)
                            , "preferredRuntimeId" .= ("temurin-21-test" :: Text)
                            ]
                        )
                  }
          managedReadyResult <- solveLockfileWithServices manager managedReadyRequest
          assertEqual "lockfile solver accepts matching managed Java" "ready" (solverResultStatus managedReadyResult)
          assertEqual
            "managed Java runtime is written into lockfile and matches host architecture"
            [Just (if defaultRuntimeArch == "x64" then "temurin-21-x64-test" else "temurin-21-test")]
            [ coordinateVersionId (resolvedPackageCoordinate package)
            | package <- maybe [] lockfilePackages (solverResultLockfile managedReadyResult)
            , resolvedPackageId package == "java:21"
            ]
          let customAppRoot = tempDir </> "panino-lockfile-custom-java"
              customJavaExecutable = customAppRoot </> "fake-java"
          customAppRootExists <- doesDirectoryExist customAppRoot
          when customAppRootExists (removeDirectoryRecursive customAppRoot)
          createDirectoryIfMissing True (takeDirectory customJavaExecutable)
          writeFile customJavaExecutable $
            "#!/bin/sh\n"
              <> "echo 'openjdk version \"21.0.1\" 2026-01-01' >&2\n"
              <> "echo 'OpenJDK Runtime Environment Panino Test' >&2\n"
              <> "echo 'OpenJDK 64-Bit Server VM Panino Test' >&2\n"
              <> "echo 'java.version = 21.0.1' >&2\n"
              <> "echo 'java.vendor = Panino Test' >&2\n"
              <> "echo 'os.arch = "
              <> Text.unpack defaultRuntimeArch
              <> "' >&2\n"
              <> "exit 0\n"
          (chmodExit, _, chmodErr) <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", customJavaExecutable]) ""
          assertEqual "custom Java chmod succeeds" ExitSuccess chmodExit
          assertEqual "custom Java chmod stderr" "" chmodErr
          let customJavaRequest =
                (testLockfileSolveRequest (customAppRoot </> "game") [] Nothing)
                  { solveRequestMinecraftVersion = Just "26.1.2"
                  , solveRequestLoader = Nothing
                  , solveRequestShaderLoader = Nothing
                  , solveRequestJavaPolicy =
                      Just
                        ( object
                            [ "policy" .= ("custom" :: Text)
                            , "customPath" .= customJavaExecutable
                            ]
                        )
                  }
          customJavaResult <- solveLockfileWithServices manager customJavaRequest
          let customJavaLockJson =
                maybe
                  ""
                  (maybe "" (BL8.unpack . encode) . lockfileJava)
                  (solverResultLockfile customJavaResult)
          assertEqual ("lockfile solver accepts custom Java: " <> show (solverResultBlockedReasons customJavaResult)) "ready" (solverResultStatus customJavaResult)
          assertEqual "custom Java lockfile records executable checksum" True ("executableSha1" `isInfixOf` customJavaLockJson)
          assertEqual
            "custom Java runtime does not force a download URL"
            [[]]
            [ resolvedPackageDownloadUrls package
            | package <- maybe [] lockfilePackages (solverResultLockfile customJavaResult)
            , resolvedPackageId package == "java:21"
            ]
      )
        `finally` do
          unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
          unsetEnv "PANINO_MOJANG_META_BASE"
          unsetEnv "PANINO_MODRINTH_API_BASE"
          unsetEnv "PANINO_CURSEFORGE_API_BASE"
  where
    dependencyQuery =
      ContentSearchRequest
        { contentSearchSource = "modrinth"
        , contentSearchText = ""
        , contentSearchProjectTypes = ["mod"]
        , contentSearchCategories = []
        , contentSearchGameVersion = Just "26.1.2"
        , contentSearchLoaders = ["fabric"]
        , contentSearchSort = "downloads"
        , contentSearchOffset = 0
        , contentSearchLimit = 20
        , contentSearchCurseForgeApiKey = Nothing
        , contentSearchPrefetch = False
        }
    fabricApiDependency =
      OnlineDependency
        { dependencyId = "fabric-api:required"
        , dependencyProjectId = Just "fabric-api"
        , dependencyVersionId = Nothing
        , dependencySource = "modrinth"
        , dependencyRelation = "required"
        }

assertPreferredLoaderMetadataSelection :: IO ()
assertPreferredLoaderMetadataSelection = do
  let loader version stable =
        LoaderMetadata
          { loaderMetadataId = "quilt-" <> version
          , loaderMetadataSource = "quilt"
          , loaderMetadataMinecraftVersion = "1.21.7"
          , loaderMetadataLoaderVersion = version
          , loaderMetadataInstallerVersion = Nothing
          , loaderMetadataStable = stable
          , loaderMetadataDownloadUrl = Nothing
          }
      selected =
        loaderMetadataLoaderVersion
          <$> preferredLoaderMetadata
            [ loader "0.20.0-beta.9" True
            , loader "0.24.0" True
            , loader "0.29.2-beta.5" False
            , loader "0.29.1" True
            ]
      betaOnly =
        loaderMetadataLoaderVersion
          <$> preferredLoaderMetadata
            [ loader "0.20.0-beta.9" False
            , loader "0.29.2-beta.5" False
            ]
  assertEqual "preferred loader ignores response order and beta-stable flags" (Just "0.29.1") selected
  assertEqual "preferred loader falls back to newest beta when no release exists" (Just "0.29.2-beta.5") betaOnly

assertLoaderShaderPreflightFixtures :: IO ()
assertLoaderShaderPreflightFixtures = do
  manager <- makeHttpManager
  testWithApplication (pure fakeLoaderShaderPreflightApp) $ \port ->
    let base = "http://127.0.0.1:" <> show port
        withSources action =
          ( do
              setEnv "PANINO_MOJANG_META_BASE" base
              setEnv "PANINO_FABRIC_META_BASE" base
              setEnv "PANINO_FABRIC_MAVEN_BASE" base
              setEnv "PANINO_QUILT_META_BASE" base
              setEnv "PANINO_FORGE_FILES_BASE" base
              setEnv "PANINO_FORGE_MAVEN_BASE" base
              setEnv "PANINO_NEOFORGE_MAVEN_BASE" base
              setEnv "PANINO_MODRINTH_API_BASE" base
              setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
              action
          )
            `finally` do
              unsetEnv "PANINO_MOJANG_META_BASE"
              unsetEnv "PANINO_FABRIC_META_BASE"
              unsetEnv "PANINO_FABRIC_MAVEN_BASE"
              unsetEnv "PANINO_QUILT_META_BASE"
              unsetEnv "PANINO_FORGE_FILES_BASE"
              unsetEnv "PANINO_FORGE_MAVEN_BASE"
              unsetEnv "PANINO_NEOFORGE_MAVEN_BASE"
              unsetEnv "PANINO_MODRINTH_API_BASE"
              unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
     in withSources $ do
          let run minecraftVersion loader shader javaExecutable =
                loaderInstallPreflight
                  manager
                  LoaderInstallPreflightRequest
                    { preflightMinecraftVersion = minecraftVersion
                    , preflightLoader = loader
                    , preflightLoaderVersion = Nothing
                    , preflightShaderLoader = shader
                    , preflightShaderVersion = Nothing
                    , preflightGameDir = Nothing
                    , preflightJavaExecutable = javaExecutable
                    , preflightSourceProfile = Nothing
                    }
          fabricOk <- run "26.1.2" (Just "fabric") (Just "iris") (Just "/usr/bin/java")
          assertEqual "Fabric + Iris fixture preflight ok" [] (preflightResponseBlockedReasons fabricOk)
          assertEqual "Fabric fixture selects loader" (Just "0.16.0") (preflightResponseLoaderVersion fabricOk)
          assertEqual "Iris fixture resolves Fabric API companion" True ("fabric-api" `elem` preflightResponseShaderProjects fabricOk)
          lockfilePreflightResult <-
            solveLockfileWithServices
              manager
              ( (testLockfileSolveRequest "/tmp/panino-lockfile-preflight" [] Nothing)
                  { solveRequestMinecraftVersion = Just "26.1.2"
                  , solveRequestLoader = Just "fabric"
                  , solveRequestLoaderVersion = Nothing
                  , solveRequestShaderLoader = Just "iris"
                  }
              )
          let lockfilePreflightPackages =
                maybe [] lockfilePackages (solverResultLockfile lockfilePreflightResult)
              lockfilePreflightPackageIds =
                map resolvedPackageId lockfilePreflightPackages
              lockfilePreflightLoaderVersions =
                [ coordinateVersionId (resolvedPackageCoordinate package)
                | package <- lockfilePreflightPackages
                , resolvedPackageId package == "loader:fabric"
                ]
          assertEqual ("lockfile solver reuses install preflight: " <> show (solverResultBlockedReasons lockfilePreflightResult)) "ready" (solverResultStatus lockfilePreflightResult)
          assertEqual "lockfile solver carries preflight loader version" [Just "0.16.0"] lockfilePreflightLoaderVersions
          assertEqual "lockfile solver carries preflight shader dependency" True ("fabric-api" `elem` lockfilePreflightPackageIds)

          fabricMissing <- run "unsupported" (Just "fabric") Nothing (Just "/usr/bin/java")
          assertEqual "Fabric unsupported fixture blocks" True (any ("loader_version_not_found" `Text.isPrefixOf`) (preflightResponseBlockedReasons fabricMissing))

          quiltOk <- run "26.1.2" (Just "quilt") Nothing (Just "/usr/bin/java")
          assertEqual "Quilt fixture preflight ok" [] (preflightResponseBlockedReasons quiltOk)
          assertEqual "Quilt fixture selects latest stable loader" (Just "0.29.1") (preflightResponseLoaderVersion quiltOk)

          quiltIrisOk <- run "26.1.2" (Just "quilt") (Just "iris") (Just "/usr/bin/java")
          assertEqual
            "Quilt + Iris fixture preflight falls back to Fabric release"
            []
            (preflightResponseBlockedReasons quiltIrisOk)
          assertEqual "Quilt + Iris fixture records resolved shader loader" (Just "fabric") (preflightResponseShaderResolvedLoader quiltIrisOk)
          assertEqual "Quilt + Iris fixture records fallback source" (Just "quilt") (preflightResponseShaderFallbackFrom quiltIrisOk)
          assertEqual "Quilt + Iris fixture records fallback target" (Just "fabric") (preflightResponseShaderFallbackTo quiltIrisOk)
          assertEqual "Quilt + Iris fixture warns about fallback" True (any ("shader_loader_fallback:" `Text.isPrefixOf`) (preflightResponseWarnings quiltIrisOk))

          quiltMissing <- run "unsupported" (Just "quilt") Nothing (Just "/usr/bin/java")
          assertEqual "Quilt unsupported fixture blocks" True (any ("loader_version_not_found" `Text.isPrefixOf`) (preflightResponseBlockedReasons quiltMissing))

          forgeJavaMissing <- run "26.1.2" (Just "forge") Nothing Nothing
          assertEqual "Forge Java missing fixture does not block preflight" [] (preflightResponseBlockedReasons forgeJavaMissing)
          assertEqual "Forge Java missing fixture warns" True (any ("loader_installer_java_missing" `Text.isPrefixOf`) (preflightResponseWarnings forgeJavaMissing))

          forgeDownloadMissing <- run "forge-missing-installer" (Just "forge") Nothing (Just "/usr/bin/java")
          assertEqual "Forge installer HEAD failure does not block when range GET is available" [] (preflightResponseBlockedReasons forgeDownloadMissing)
          assertEqual "Forge installer HEAD failure records probe status" True (maybe False ("range-get:ok" `Text.isPrefixOf`) (preflightResponseInstallerProbeStatus forgeDownloadMissing))

          forgeOculusOk <- run "26.1.2" (Just "forge") (Just "oculus") (Just "/usr/bin/java")
          assertEqual "Forge + Oculus fixture preflight ok" [] (preflightResponseBlockedReasons forgeOculusOk)
          assertEqual "Forge + Oculus fixture resolves Oculus project" True ("oculus" `elem` preflightResponseShaderProjects forgeOculusOk)

          neoForgeOculusOk <- run "26.1.2" (Just "neoforge") (Just "oculus") (Just "/usr/bin/java")
          assertEqual "NeoForge + Oculus fixture preflight ok through Forge release fallback" [] (preflightResponseBlockedReasons neoForgeOculusOk)
          assertEqual "NeoForge + Oculus fixture resolves Oculus project through fallback" True ("oculus" `elem` preflightResponseShaderProjects neoForgeOculusOk)
          assertEqual "NeoForge + Oculus fixture records Forge fallback" (Just "forge") (preflightResponseShaderResolvedLoader neoForgeOculusOk)

          irisWrongLoader <- run "26.1.2" (Just "forge") (Just "iris") (Just "/usr/bin/java")
          assertEqual "Iris with Forge fixture blocks" True (any ("shader_loader_incompatible" `Text.isPrefixOf`) (preflightResponseBlockedReasons irisWrongLoader))

          oculusWrongLoader <- run "26.1.2" (Just "fabric") (Just "oculus") (Just "/usr/bin/java")
          assertEqual "Oculus with Fabric fixture blocks" True (any ("shader_loader_incompatible" `Text.isPrefixOf`) (preflightResponseBlockedReasons oculusWrongLoader))

          optifine <- run "26.1.2" Nothing (Just "optifine") (Just "/usr/bin/java")
          assertEqual "OptiFine fixture manual install does not block preflight" [] (preflightResponseBlockedReasons optifine)
          assertEqual "OptiFine fixture manual install warns" True (any ("manual_install_required" `Text.isPrefixOf`) (preflightResponseWarnings optifine))

          shaderDependencyMissing <- run "bad-dep" (Just "fabric") (Just "iris") (Just "/usr/bin/java")
          assertEqual "Shader dependency fixture blocks" True (any ("shader_dependency_unresolved" `Text.isPrefixOf`) (preflightResponseBlockedReasons shaderDependencyMissing))

assertInstallerProbeRateLimitCooldown :: IO ()
assertInstallerProbeRateLimitCooldown = do
  manager <- makeHttpManager
  headRequests <- newMVar (0 :: Int)
  rangeRequests <- newMVar (0 :: Int)
  testWithApplication (pure (rateLimitedInstallerProbeApp headRequests rangeRequests)) $ \port -> do
    let base = "http://127.0.0.1:" <> show port
        withSources action =
          ( do
              setEnv "PANINO_FABRIC_META_BASE" base
              setEnv "PANINO_QUILT_META_BASE" base
              setEnv "PANINO_FORGE_FILES_BASE" base
              setEnv "PANINO_FORGE_MAVEN_BASE" base
              setEnv "PANINO_NEOFORGE_MAVEN_BASE" base
              setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
              action
          )
            `finally` do
              unsetEnv "PANINO_FABRIC_META_BASE"
              unsetEnv "PANINO_QUILT_META_BASE"
              unsetEnv "PANINO_FORGE_FILES_BASE"
              unsetEnv "PANINO_FORGE_MAVEN_BASE"
              unsetEnv "PANINO_NEOFORGE_MAVEN_BASE"
              unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
        run =
          loaderInstallPreflight
            manager
            LoaderInstallPreflightRequest
              { preflightMinecraftVersion = "26.1.429"
              , preflightLoader = Just "forge"
              , preflightLoaderVersion = Nothing
              , preflightShaderLoader = Nothing
              , preflightShaderVersion = Nothing
              , preflightGameDir = Nothing
              , preflightJavaExecutable = Just "/usr/bin/java"
              , preflightSourceProfile = Nothing
              }
    withSources $ do
      first <- run
      second <- run
      heads <- readMVar headRequests
      ranges <- readMVar rangeRequests
      assertEqual "Forge 429 probe remains non-blocking" [] (preflightResponseBlockedReasons first)
      assertEqual "cached Forge 429 probe remains non-blocking" [] (preflightResponseBlockedReasons second)
      assertEqual "Forge 429 probe does not fall through to range GET" 0 ranges
      assertEqual "Forge 429 probe is cached across repeated preflights" 1 heads

assertLoaderShaderInstallFixtures :: IO ()
assertLoaderShaderInstallFixtures = do
  manager <- makeHttpManager
  tempDir <- getTemporaryDirectory
  testWithApplication (pure fakeLoaderShaderPreflightApp) $ \port -> do
    let base = "http://127.0.0.1:" <> show port
        withSources action =
          ( do
              setEnv "PANINO_MOJANG_META_BASE" base
              setEnv "PANINO_MOJANG_RESOURCES_BASE" base
              setEnv "PANINO_MOJANG_LIBRARIES_BASE" base
              setEnv "PANINO_FABRIC_META_BASE" base
              setEnv "PANINO_FABRIC_MAVEN_BASE" base
              setEnv "PANINO_QUILT_META_BASE" base
              setEnv "PANINO_FORGE_FILES_BASE" base
              setEnv "PANINO_FORGE_MAVEN_BASE" base
              setEnv "PANINO_NEOFORGE_MAVEN_BASE" base
              setEnv "PANINO_MODRINTH_API_BASE" base
              setEnv "PANINO_MODRINTH_CDN_BASE" base
              setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
              action
          )
            `finally` do
              unsetEnv "PANINO_MOJANG_META_BASE"
              unsetEnv "PANINO_MOJANG_RESOURCES_BASE"
              unsetEnv "PANINO_MOJANG_LIBRARIES_BASE"
              unsetEnv "PANINO_FABRIC_META_BASE"
              unsetEnv "PANINO_FABRIC_MAVEN_BASE"
              unsetEnv "PANINO_QUILT_META_BASE"
              unsetEnv "PANINO_FORGE_FILES_BASE"
              unsetEnv "PANINO_FORGE_MAVEN_BASE"
              unsetEnv "PANINO_NEOFORGE_MAVEN_BASE"
              unsetEnv "PANINO_MODRINTH_API_BASE"
              unsetEnv "PANINO_MODRINTH_CDN_BASE"
              unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
    withSources $ do
      let root = tempDir </> "panino-loader-shader-install-fixture"
          fabricRoot = root </> "fabric"
          quiltRoot = root </> "quilt"
      exists <- doesDirectoryExist root
      when exists (removeDirectoryRecursive root `catchAny` \_ -> pure ())
      fabricLayout <- mkLayout (Just fabricRoot)
      fabricResult <-
        installMinecraftProfileWithOptionsAndProgressAndCancel
          manager
          fabricLayout
          "26.1.2"
          (downloadOptionsWithOverrides (Just 2) (Just 0))
          (pure False)
          (\_ -> pure ())
          LoaderInstallOptions
            { loaderInstallLoader = Just "fabric"
            , loaderInstallLoaderVersion = Nothing
            , loaderInstallShaderLoader = Just "iris"
            , loaderInstallShaderVersion = Nothing
            , loaderInstallInstanceName = Just "Fabric Iris Fixture"
            , loaderInstallJavaExecutable = Nothing
            , loaderInstallExpectedProfileId = Just "fabric-loader-0.16.0-26.1.2"
            }
      fabricProfileExists <- doesFileExist (versionJsonPath fabricLayout (loaderInstallProfileVersion fabricResult))
      fabricClientExists <- doesFileExist (clientJarPath fabricLayout "26.1.2")
      irisExists <- doesFileExist (minecraftRoot fabricLayout </> "mods" </> "iris-1.0.0.jar")
      fabricApiExists <- doesFileExist (minecraftRoot fabricLayout </> "mods" </> "fabric-api-1.0.0.jar")
      assertEqual "Fabric fixture install creates loader profile" True fabricProfileExists
      assertEqual "Fabric fixture install keeps base client jar" True fabricClientExists
      assertEqual "Iris fixture install writes shader mod" True irisExists
      assertEqual "Iris fixture install writes Fabric API companion" True fabricApiExists

      quiltLayout <- mkLayout (Just quiltRoot)
      quiltResult <-
        installMinecraftProfileWithOptionsAndProgressAndCancel
          manager
          quiltLayout
          "26.1.2"
          (downloadOptionsWithOverrides (Just 2) (Just 0))
          (pure False)
          (\_ -> pure ())
          LoaderInstallOptions
            { loaderInstallLoader = Just "quilt"
            , loaderInstallLoaderVersion = Nothing
            , loaderInstallShaderLoader = Nothing
            , loaderInstallShaderVersion = Nothing
            , loaderInstallInstanceName = Just "Quilt Fixture"
            , loaderInstallJavaExecutable = Nothing
            , loaderInstallExpectedProfileId = Just "quilt-loader-0.29.1-26.1.2"
            }
      quiltProfileExists <- doesFileExist (versionJsonPath quiltLayout (loaderInstallProfileVersion quiltResult))
      quiltClientExists <- doesFileExist (clientJarPath quiltLayout "26.1.2")
      quiltIntermediaryExists <- doesFileExist (librariesDir quiltLayout </> "net" </> "fabricmc" </> "intermediary" </> "26.1.2" </> "intermediary-26.1.2.jar")
      let quiltVersionJson = installVersionJson (loaderInstallResult quiltResult)
          quiltLaunchArgs =
            buildJavaArguments
              quiltLayout
              quiltVersionJson
              (classpathJars quiltLayout quiltVersionJson)
              LaunchProfile
                { profileVersion = loaderInstallProfileVersion quiltResult
                , profileMemoryMb = 4096
                , profileJavaPath = "java"
                , profileUsername = "Steve"
                , profileUuid = "00000000-0000-0000-0000-000000000000"
                , profileAccessToken = "0"
                , profileJvmArgs = []
                , profileJvmTuning = Nothing
                , profileWindowWidth = Nothing
                , profileWindowHeight = Nothing
                }
      assertEqual "Quilt fixture install creates loader profile" True quiltProfileExists
      assertEqual "Quilt fixture install keeps base client jar" True quiltClientExists
      assertEqual "Quilt fixture install downloads intermediary mappings" True quiltIntermediaryExists
      assertEqual "Quilt fixture launch version is loader profile" "quilt-loader-0.29.1-26.1.2" (versionId quiltVersionJson)
      assertEqual "Quilt fixture launch main class is Quilt KnotClient" "org.quiltmc.loader.impl.launch.knot.KnotClient" (versionMainClass quiltVersionJson)
      assertEqual "Quilt fixture launch args include Quilt main class" True ("org.quiltmc.loader.impl.launch.knot.KnotClient" `elem` quiltLaunchArgs)
      assertEqual "Quilt fixture launch classpath includes loader profile client jar" True (any ("quilt-loader-0.29.1-26.1.2.jar" `isInfixOf`) quiltLaunchArgs)
      assertEqual "Quilt fixture launch classpath includes Quilt loader jar" True (any ("org/quiltmc/quilt-loader/0.29.1/quilt-loader-0.29.1.jar" `isInfixOf`) quiltLaunchArgs)
      assertEqual "Quilt fixture launch classpath includes intermediary mappings" True (any ("net/fabricmc/intermediary/26.1.2/intermediary-26.1.2.jar" `isInfixOf`) quiltLaunchArgs)

      invalidShaderLayout <- mkLayout (Just (root </> "neoforge-iris-invalid"))
      invalidShaderResult <-
        try
          ( installMinecraftProfileWithOptionsAndProgressAndCancel
              manager
              invalidShaderLayout
              "26.1.2"
              (downloadOptionsWithOverrides (Just 2) (Just 0))
              (pure False)
              (\_ -> pure ())
              LoaderInstallOptions
                { loaderInstallLoader = Just "neoforge"
                , loaderInstallLoaderVersion = Nothing
                , loaderInstallShaderLoader = Just "iris"
                , loaderInstallShaderVersion = Nothing
                , loaderInstallInstanceName = Just "Invalid Shader Fixture"
                , loaderInstallJavaExecutable = Nothing
                , loaderInstallExpectedProfileId = Nothing
                }
          ) :: IO (Either SomeException LoaderInstallResult)
      assertEqual
        "NeoForge + Iris fixture is blocked before partial install"
        True
        (either (("shader_loader_incompatible:iris neoforge" `isInfixOf`) . show) (const False) invalidShaderResult)

      quiltIrisLayout <- mkLayout (Just (root </> "quilt-iris"))
      _quiltIrisResult <-
        installMinecraftProfileWithOptionsAndProgressAndCancel
          manager
          quiltIrisLayout
          "26.1.2"
          (downloadOptionsWithOverrides (Just 2) (Just 0))
          (pure False)
          (\_ -> pure ())
          LoaderInstallOptions
            { loaderInstallLoader = Just "quilt"
            , loaderInstallLoaderVersion = Nothing
            , loaderInstallShaderLoader = Just "iris"
            , loaderInstallShaderVersion = Nothing
            , loaderInstallInstanceName = Just "Quilt Iris Fixture"
            , loaderInstallJavaExecutable = Nothing
            , loaderInstallExpectedProfileId = Just "quilt-loader-0.29.1-26.1.2"
            }
      quiltIrisExists <- doesFileExist (minecraftRoot quiltIrisLayout </> "mods" </> "iris-1.0.0.jar")
      quiltIrisFabricApiExists <- doesFileExist (minecraftRoot quiltIrisLayout </> "mods" </> "fabric-api-1.0.0.jar")
      quiltIrisShaderLog <- readFile (minecraftRoot quiltIrisLayout </> "downloads" </> "shader-install.log")
      assertEqual "Quilt Iris fixture install writes fallback Iris mod" True quiltIrisExists
      assertEqual "Quilt Iris fixture install writes fallback Fabric API dependency" True quiltIrisFabricApiExists
      assertEqual "Quilt Iris fixture install records fallback in shader log" True ("fallback=true" `isInfixOf` quiltIrisShaderLog)

      let fakeJava = root </> "fake-java"
      writeFile fakeJava $
        unlines
          [ "#!/bin/sh"
          , "target=\"\""
          , "for arg in \"$@\"; do target=\"$arg\"; done"
          , "test -f \"$target/launcher_profiles.json\" || exit 42"
          , "grep -q '\"profiles\"' \"$target/launcher_profiles.json\" || exit 43"
          , "grep -q '\"lastVersionId\":\"26.1.2\"' \"$target/launcher_profiles.json\" || exit 44"
          , "test -f \"$target/versions/26.1.2/26.1.2.json\" || exit 45"
          , "exit 0"
          ]
      (chmodExit, _, chmodErr) <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", fakeJava]) ""
      assertEqual "fake Java chmod succeeds" ExitSuccess chmodExit
      assertEqual "fake Java chmod stderr" "" chmodErr
      neoforgeLayout <- mkLayout (Just (root </> "neoforge"))
      neoforgeResult <-
        try
          ( installMinecraftProfileWithOptionsAndProgressAndCancel
              manager
              neoforgeLayout
              "26.1.2"
              (downloadOptionsWithOverrides (Just 1) (Just 0))
              (pure False)
              (\_ -> pure ())
              LoaderInstallOptions
                { loaderInstallLoader = Just "neoforge"
                , loaderInstallLoaderVersion = Nothing
                , loaderInstallShaderLoader = Nothing
                , loaderInstallShaderVersion = Nothing
                , loaderInstallInstanceName = Just "NeoForge Missing Profile Fixture"
                , loaderInstallJavaExecutable = Just fakeJava
                , loaderInstallExpectedProfileId = Nothing
                }
          ) :: IO (Either SomeException LoaderInstallResult)
      case neoforgeResult of
        Left err ->
          assertEqual "NeoForge missing profile reports stable error" True ("loader_profile_not_created" `isInfixOf` show err)
        Right _ ->
          assertEqual "NeoForge fixture should fail when installer creates no profile" True False
      neoforgeLauncherProfilesExists <- doesFileExist (minecraftRoot neoforgeLayout </> "launcher_profiles.json")
      neoforgeLauncherProfiles <- readFile (minecraftRoot neoforgeLayout </> "launcher_profiles.json")
      assertEqual "NeoForge fixture prepares launcher_profiles.json before running installer" True neoforgeLauncherProfilesExists
      assertEqual "NeoForge fixture launcher_profiles.json has Panino marker" True ("Panino Launcher" `isInfixOf` neoforgeLauncherProfiles)
      assertEqual "NeoForge fixture launcher_profiles.json selects Panino profile" True ("\"selectedProfile\":\"Panino\"" `isInfixOf` neoforgeLauncherProfiles)
      assertEqual "NeoForge fixture launcher_profiles.json points at base Minecraft" True ("\"lastVersionId\":\"26.1.2\"" `isInfixOf` neoforgeLauncherProfiles)
      neoforgeBaseVersionExists <- doesFileExist (versionJsonPath neoforgeLayout "26.1.2")
      assertEqual "NeoForge fixture prepares vanilla version before running installer" True neoforgeBaseVersionExists

      let fakeWrongProfileJava = root </> "fake-java-wrong-profile"
      writeFile fakeWrongProfileJava $
        unlines
          [ "#!/bin/sh"
          , "target=\"\""
          , "for arg in \"$@\"; do target=\"$arg\"; done"
          , "profile=\"$target/versions/neoforge-26.1.2.1\""
          , "mkdir -p \"$profile\""
          , "cat > \"$profile/neoforge-26.1.2.1.json\" <<'JSON'"
          , "{\"id\":\"neoforge-26.1.2.1\",\"inheritsFrom\":\"wrong-minecraft\",\"mainClass\":\"cpw.mods.bootstrap.BootstrapLauncher\",\"libraries\":[{\"name\":\"net.neoforged:neoforge:26.1.2.1\"}]}"
          , "JSON"
          , "exit 0"
          ]
      (chmodWrongExit, _, chmodWrongErr) <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", fakeWrongProfileJava]) ""
      assertEqual "fake wrong-profile Java chmod succeeds" ExitSuccess chmodWrongExit
      assertEqual "fake wrong-profile Java chmod stderr" "" chmodWrongErr
      wrongProfileLayout <- mkLayout (Just (root </> "neoforge-wrong-profile"))
      wrongProfileResult <-
        try
          ( installMinecraftProfileWithOptionsAndProgressAndCancel
              manager
              wrongProfileLayout
              "26.1.2"
              (downloadOptionsWithOverrides (Just 1) (Just 0))
              (pure False)
              (\_ -> pure ())
              LoaderInstallOptions
                { loaderInstallLoader = Just "neoforge"
                , loaderInstallLoaderVersion = Nothing
                , loaderInstallShaderLoader = Nothing
                , loaderInstallShaderVersion = Nothing
                , loaderInstallInstanceName = Just "NeoForge Wrong Profile Fixture"
                , loaderInstallJavaExecutable = Just fakeWrongProfileJava
                , loaderInstallExpectedProfileId = Nothing
                }
          ) :: IO (Either SomeException LoaderInstallResult)
      case wrongProfileResult of
        Left err ->
          assertEqual "NeoForge wrong inherited profile is rejected" True ("loader_profile_not_created" `isInfixOf` show err)
        Right _ ->
          assertEqual "NeoForge fixture should reject wrong inherited profile" True False

assertInstanceMetadataFallbackRepairsLoaderProfile :: FilePath -> IO ()
assertInstanceMetadataFallbackRepairsLoaderProfile tempDir = do
  let root = tempDir </> "panino-instance-metadata-fallback"
      quiltProfile :: Text
      quiltProfile = "quilt-loader-0.29.2-26.1.1"
      quiltProfilePath = root </> "versions" </> Text.unpack quiltProfile </> Text.unpack quiltProfile <.> "json"
  exists <- doesDirectoryExist root
  when exists (removeDirectoryRecursive root)
  createDirectoryIfMissing True (takeDirectory quiltProfilePath)
  BL.writeFile
    quiltProfilePath
    ( encode
        ( object
            [ "id" .= quiltProfile
            , "inheritsFrom" .= ("26.1.1" :: Text)
            , "mainClass" .= ("org.quiltmc.loader.impl.launch.knot.KnotClient" :: Text)
            , "libraries" .=
                [ object
                    [ "name" .= ("org.quiltmc:quilt-loader:0.29.2" :: Text)
                    ]
                ]
            ]
        )
    )
  quiltMetadata <- readInstanceMetadata root quiltProfile
  assertEqual "fallback metadata keeps loader profile as launch version" quiltProfile (metadataLaunchVersion quiltMetadata)
  assertEqual "fallback metadata reads inherited Minecraft version" "26.1.1" (metadataMinecraftVersion quiltMetadata)
  assertEqual "fallback metadata infers Quilt loader" (Just "quilt") (metadataLoader quiltMetadata)
  assertEqual "fallback metadata infers Quilt loader version" (Just "0.29.2") (metadataLoaderVersion quiltMetadata)
  writeInstanceMetadata
    root
    InstanceMetadata
      { metadataName = Just "Preserve Name"
      , metadataMinecraftVersion = quiltProfile
      , metadataLaunchVersion = quiltProfile
      , metadataLoader = Nothing
      , metadataLoaderVersion = Nothing
      , metadataShaderLoader = Just "iris"
      }
  staleQuiltMetadata <- readInstanceMetadata root quiltProfile
  assertEqual "stale metadata repair keeps user name" (Just "Preserve Name") (metadataName staleQuiltMetadata)
  assertEqual "stale metadata repair keeps shader selection" (Just "iris") (metadataShaderLoader staleQuiltMetadata)
  assertEqual "stale metadata repair replaces loader profile Minecraft version" "26.1.1" (metadataMinecraftVersion staleQuiltMetadata)
  assertEqual "stale metadata repair fills missing Quilt loader" (Just "quilt") (metadataLoader staleQuiltMetadata)
  assertEqual "stale metadata repair fills missing Quilt loader version" (Just "0.29.2") (metadataLoaderVersion staleQuiltMetadata)

  let fabricRoot = root </> "fabric-id-only"
      fabricProfile :: Text
      fabricProfile = "fabric-loader-0.16.0-1.21.7"
  fabricMetadata <- readInstanceMetadata fabricRoot fabricProfile
  assertEqual "fallback metadata parses Fabric Minecraft suffix" "1.21.7" (metadataMinecraftVersion fabricMetadata)
  assertEqual "fallback metadata parses Fabric loader version" (Just "0.16.0") (metadataLoaderVersion fabricMetadata)

  let betaQuiltRoot = root </> "quilt-beta-id-only"
      betaQuiltProfile :: Text
      betaQuiltProfile = "quilt-loader-0.20.0-beta.9-1.21.7"
  betaQuiltMetadata <- readInstanceMetadata betaQuiltRoot betaQuiltProfile
  assertEqual "fallback metadata parses beta Quilt Minecraft suffix" "1.21.7" (metadataMinecraftVersion betaQuiltMetadata)
  assertEqual "fallback metadata preserves beta Quilt loader version" (Just "0.20.0-beta.9") (metadataLoaderVersion betaQuiltMetadata)

  let neoForgeRoot = root </> "neoforge-json"
      neoForgeProfile :: Text
      neoForgeProfile = "neoforge-21.1.179"
      neoForgeProfilePath = neoForgeRoot </> "versions" </> Text.unpack neoForgeProfile </> Text.unpack neoForgeProfile <.> "json"
  createDirectoryIfMissing True (takeDirectory neoForgeProfilePath)
  BL.writeFile
    neoForgeProfilePath
    ( encode
        ( object
            [ "id" .= neoForgeProfile
            , "inheritsFrom" .= ("1.21.1" :: Text)
            , "mainClass" .= ("cpw.mods.bootstrap.BootstrapLauncher" :: Text)
            , "libraries" .=
                [ object
                    [ "name" .= ("net.neoforged:neoforge:21.1.179" :: Text)
                    ]
                ]
            ]
        )
    )
  neoForgeMetadata <- readInstanceMetadata neoForgeRoot neoForgeProfile
  assertEqual "fallback metadata reads NeoForge inherited Minecraft version" "1.21.1" (metadataMinecraftVersion neoForgeMetadata)
  assertEqual "fallback metadata infers NeoForge loader from library" (Just "neoForge") (metadataLoader neoForgeMetadata)
  assertEqual "fallback metadata infers NeoForge loader version" (Just "21.1.179") (metadataLoaderVersion neoForgeMetadata)

assertInstallMissingClientDownload :: IO ()
assertInstallMissingClientDownload = do
  assertEqual "version summary tolerates missing client download" True (isJust (decode (resolveVersionSummaryJson testVersionJson) :: Maybe Value))
  manager <- makeHttpManager
  tempDir <- getTemporaryDirectory
  testWithApplication (pure fakeLoaderShaderPreflightApp) $ \port -> do
    let base = "http://127.0.0.1:" <> show port
        withSources action =
          ( do
              setEnv "PANINO_MOJANG_META_BASE" base
              setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
              action
          )
            `finally` do
              unsetEnv "PANINO_MOJANG_META_BASE"
              unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
    withSources $ do
      let root = tempDir </> "panino-install-missing-client-download"
      exists <- doesDirectoryExist root
      when exists (removeDirectoryRecursive root `catchAny` \_ -> pure ())
      layout <- mkLayout (Just root)
      result <-
        try
          ( installMinecraftVersionWithOptionsAndProgressAndCancel
              manager
              layout
              "missing-client"
              (downloadOptionsWithOverrides (Just 1) (Just 0))
              (pure False)
              (\_ -> pure ())
          ) :: IO (Either SomeException InstallResult)
      case result of
        Left err ->
          assertEqual "missing client download reports manifest parse failure" True ("manifest_parse_failed: version JSON is missing downloads.client for missing-client" `isInfixOf` show err)
        Right _ ->
          assertEqual "install should fail when downloads.client is missing" True False

assertInstallPostVerifyMissingClientJar :: IO ()
assertInstallPostVerifyMissingClientJar = do
  tempDir <- getTemporaryDirectory
  let root = tempDir </> "panino-post-verify-missing-client"
      fixtureLaunchVersion = "fabric-loader-0.16.0-26.1.2"
  exists <- doesDirectoryExist root
  when exists (removeDirectoryRecursive root `catchAny` \_ -> pure ())
  layout <- mkLayout (Just root)
  createDirectoryIfMissing True (takeDirectory (versionJsonPath layout fixtureLaunchVersion))
  BL8.writeFile (versionJsonPath layout fixtureLaunchVersion) "{}"
  let result =
        InstallResult
          { installVersionJson =
              VersionJson
                { versionId = fixtureLaunchVersion
                , versionType = Nothing
                , versionJavaVersion = Nothing
                , versionDownloads = mempty
                , versionAssetIndex = DownloadInfo Nothing Nothing Nothing Nothing Nothing
                , versionLibraries = []
                , versionMainClass = "net.minecraft.client.main.Main"
                , versionArguments = Nothing
                , versionMinecraftArguments = Nothing
                }
          , installClasspathJars = []
          , installNativeArchives = []
          , installDownloadSummary = DownloadSummary 0 0 0
          , installPlanGraph = downloadJobsInstallPlanGraph "minecraft" "post-verify" []
      }
  verifyResult <-
    try
      (postVerifyInstall layout "26.1.2" fixtureLaunchVersion Nothing result emptyShaderInstallResult)
        :: IO (Either SomeException ())
  case verifyResult of
    Left err ->
      assertEqual "post-verify missing client jar has stable error" True ("install_post_verify_failed: missing client jar" `isInfixOf` show err)
    Right () ->
      assertEqual "post-verify should fail when client jar is missing" True False

assertNetworkFailureFixtures :: IO ()
assertNetworkFailureFixtures = do
  manager <- makeHttpManager
  testWithApplication (pure fakeNetworkFailureApp) $ \port -> do
    let base = "http://127.0.0.1:" <> show port
        fetchFailure label path timeoutMicros = do
          request <- coreRequest (base <> path) []
          let tuned = applyRequestTimeoutMicros timeoutMicros request
          result <- try (fetchJson manager tuned :: IO Value) :: IO (Either SomeException Value)
          case result of
            Left _ -> pure ()
            Right _ -> assertEqual label True False
    fetchFailure "network fixture timeout fails" "/timeout" 1000
    fetchFailure "network fixture 404 fails" "/missing" 1000000
    fetchFailure "network fixture 500 fails" "/server-error" 1000000
    fetchFailure "network fixture invalid JSON fails" "/invalid-json" 1000000

fakeNetworkFailureApp :: Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived
fakeNetworkFailureApp request respond =
  case BS8.unpack (rawPathInfo request) of
    "/timeout" -> do
      threadDelay 100000
      respond (responseLBS status200 [(hContentType, "application/json")] "{}")
    "/missing" ->
      respond (responseLBS status404 [(hContentType, "text/plain")] "missing")
    "/server-error" ->
      respond (responseLBS status500 [(hContentType, "text/plain")] "server error")
    "/invalid-json" ->
      respond (responseLBS status200 [(hContentType, "application/json")] "{invalid")
    _ ->
      respond (responseLBS status404 [(hContentType, "text/plain")] "missing")

rateLimitedInstallerProbeApp :: MVar Int -> MVar Int -> Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived
rateLimitedInstallerProbeApp headRequests rangeRequests request respond = do
  let path = BS8.unpack (rawPathInfo request)
      json = responseLBS status200 [(hContentType, "application/json")]
      text = responseLBS status200 [(hContentType, "text/plain")]
      notFound = responseLBS status404 [(hContentType, "text/plain")] "missing"
      rateLimited = responseLBS status429 [(hContentType, "text/plain")] "too many requests"
      installerPath = "forge-26.1.429-50.0.429-installer.jar" `isInfixOf` path
  case path of
    "/net/minecraftforge/forge/promotions_slim.json" ->
      respond (json "{\"promos\":{\"26.1.429-recommended\":\"50.0.429\"}}")
    "/v2/versions/loader/26.1.429" ->
      respond (json "[]")
    "/v3/versions/loader/26.1.429" ->
      respond (json "[]")
    "/net/neoforged/neoforge/maven-metadata.xml" ->
      respond (text "<metadata><versioning><versions></versions></versioning></metadata>")
    _
      | installerPath && requestMethod request == "HEAD" -> do
          modifyMVar_ headRequests (pure . (+ 1))
          respond rateLimited
      | installerPath && requestMethod request == "GET" -> do
          modifyMVar_ rangeRequests (pure . (+ 1))
          respond (responseLBS status206 [(hContentType, "application/octet-stream"), ("Content-Range", "bytes 0-0/1")] "x")
      | otherwise ->
          respond notFound

fakeLoaderShaderPreflightApp :: Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived
fakeLoaderShaderPreflightApp request respond = do
  let path = BS8.unpack (rawPathInfo request)
      queryText = show (queryString request)
      requestBase =
        "http://"
          <> BS8.unpack
            ( case requestHeaderHost request of
                Just host -> host
                Nothing -> "127.0.0.1"
            )
      json = responseLBS status200 [(hContentType, "application/json")]
      text = responseLBS status200 [(hContentType, "text/plain")]
      notFound = responseLBS status404 [(hContentType, "text/plain")] "missing"
      okEmpty = responseLBS status200 [(hContentType, "application/octet-stream")] ""
      binary = responseLBS status200 [(hContentType, "application/octet-stream")]
  respond $
    case path of
      "/mc/game/version_manifest_v2.json" -> json (minecraftManifestFixture requestBase)
      "/versions/26.1.2.json" -> json (minecraftVersionFixture requestBase)
      "/versions/missing-client.json" -> json (minecraftMissingClientVersionFixture requestBase)
      "/assets/indexes/empty.json" -> json "{\"objects\":{}}"
      "/client.jar" -> binary "fake-client-jar"
      "/example/loader/1.0/loader-1.0.jar" -> binary "fake-loader-library"
      "/org/quiltmc/quilt-loader/0.29.1/quilt-loader-0.29.1.jar" -> binary "fake-quilt-loader-library"
      "/net/fabricmc/intermediary/26.1.2/intermediary-26.1.2.jar" -> binary "fake-intermediary-library"
      "/data/iris/iris-1.0.0.jar" -> binary "fake-iris-jar"
      "/data/oculus/oculus-1.0.0.jar" -> binary "fake-oculus-jar"
      "/data/fabric-api/fabric-api-1.0.0.jar" -> binary "fake-fabric-api-jar"
      "/data/sodium/sodium-1.0.0.jar" -> binary "fake-sodium-jar"
      "/v2/versions/loader/26.1.2" -> json fabricLoaderFixture
      "/v2/versions/loader/bad-dep" -> json fabricLoaderFixture
      "/v2/versions/loader/unsupported" -> json "[]"
      "/v2/versions/loader/26.1.2/0.16.0/profile/json" -> json (loaderProfileFixture "fabric-loader-0.16.0-26.1.2" "26.1.2")
      "/v2/versions/loader/bad-dep/0.16.0/profile/json" -> json (loaderProfileFixture "fabric-loader-0.16.0-bad-dep" "bad-dep")
      "/v3/versions/loader/26.1.2" -> json quiltLoaderFixture
      "/v3/versions/loader/unsupported" -> json "[]"
      "/v3/versions/loader/26.1.2/0.29.1/profile/json" -> json (loaderProfileFixture "quilt-loader-0.29.1-26.1.2" "26.1.2")
      "/net/minecraftforge/forge/promotions_slim.json" -> json forgePromotionsFixture
      "/net/neoforged/neoforge/maven-metadata.xml" -> text neoForgeMetadataFixture
      "/v2/project/iris" -> json (modrinthProjectMetadataFixture "iris" "Iris")
      "/v2/project/oculus" -> json (modrinthProjectMetadataFixture "oculus" "Oculus")
      "/v2/project/fabric-api" -> json (modrinthProjectMetadataFixture "fabric-api" "Fabric API")
      "/v2/project/sodium" -> json (modrinthProjectMetadataFixture "sodium" "Sodium")
      "/v2/project/iris/version"
        | "bad-dep" `isInfixOf` queryText -> json modrinthBadDependencyFixture
        | "quilt" `isInfixOf` queryText -> json "[]"
        | otherwise -> json (modrinthProjectFixture "iris" "iris-1.0.0.jar")
      "/v2/project/oculus/version"
        | "neoforge" `isInfixOf` queryText -> json "[]"
        | otherwise -> json (modrinthProjectFixtureForLoader "oculus" "oculus-1.0.0.jar" "forge")
      "/v2/project/fabric-api/version" -> json (modrinthProjectFixture "fabric-api" "fabric-api-1.0.0.jar")
      "/v2/project/sodium/version" -> json (modrinthProjectFixture "sodium" "sodium-1.0.0.jar")
      _ | requestMethod request == "HEAD" && "forge-missing-installer" `isInfixOf` path -> notFound
      _ | requestMethod request == "HEAD" -> okEmpty
      _ | "installer.jar" `isInfixOf` path -> binary "fake-installer"
      _ -> notFound

fabricLoaderFixture :: BL.ByteString
fabricLoaderFixture =
  "[{\"loader\":{\"version\":\"0.16.0\",\"stable\":true},\"installer\":{\"version\":\"1.0.0\",\"stable\":true}}]"

quiltLoaderFixture :: BL.ByteString
quiltLoaderFixture =
  "[{\"loader\":{\"version\":\"0.20.0-beta.9\"},\"installer\":{\"version\":\"1.0.0\",\"stable\":true}},{\"loader\":{\"version\":\"0.24.0\",\"stable\":true},\"installer\":{\"version\":\"1.0.0\",\"stable\":true}},{\"loader\":{\"version\":\"0.29.2-beta.5\",\"stable\":false},\"installer\":{\"version\":\"1.0.0\",\"stable\":true}},{\"loader\":{\"version\":\"0.29.1\",\"stable\":true},\"installer\":{\"version\":\"1.0.0\",\"stable\":true}}]"

minecraftManifestFixture :: String -> BL.ByteString
minecraftManifestFixture base =
  BL8.pack
    ( "{\"versions\":[{\"id\":\"26.1.2\",\"url\":\""
        <> base
        <> "/versions/26.1.2.json\"},{\"id\":\"missing-client\",\"url\":\""
        <> base
        <> "/versions/missing-client.json\"}]}"
    )

minecraftVersionFixture :: String -> BL.ByteString
minecraftVersionFixture base =
  BL8.pack
    ( "{\"id\":\"26.1.2\",\"type\":\"release\",\"javaVersion\":{\"majorVersion\":21},\"downloads\":{\"client\":{\"url\":\""
        <> base
        <> "/client.jar\"}},\"assetIndex\":{\"id\":\"empty\",\"url\":\""
        <> base
        <> "/assets/indexes/empty.json\"},\"libraries\":[],\"mainClass\":\"net.minecraft.client.main.Main\",\"arguments\":{\"game\":[],\"jvm\":[\"-Djava.library.path=${natives_directory}\",\"-cp\",\"${classpath}\"]}}"
    )

minecraftMissingClientVersionFixture :: String -> BL.ByteString
minecraftMissingClientVersionFixture base =
  BL8.pack
    ( "{\"id\":\"missing-client\",\"type\":\"release\",\"javaVersion\":{\"majorVersion\":21},\"downloads\":{},\"assetIndex\":{\"id\":\"empty\",\"url\":\""
        <> base
        <> "/assets/indexes/empty.json\"},\"libraries\":[],\"mainClass\":\"net.minecraft.client.main.Main\",\"arguments\":{\"game\":[],\"jvm\":[]}}"
    )

loaderProfileFixture :: String -> String -> BL.ByteString
loaderProfileFixture profileId inheritsFrom =
  BL8.pack
    ( "{\"id\":\""
        <> profileId
        <> "\",\"inheritsFrom\":\""
        <> inheritsFrom
        <> "\",\"mainClass\":\""
        <> profileMainClass
        <> "\",\"libraries\":[{\"name\":\""
        <> profileLibraryName
        <> "\",\"downloads\":{\"artifact\":{\"url\":\""
        <> profileLibraryUrl
        <> "\"}}}]}"
    )
  where
    isQuiltProfile = "quilt-loader-" `isPrefixOf` profileId
    profileMainClass =
      if isQuiltProfile
        then "org.quiltmc.loader.impl.launch.knot.KnotClient"
        else "net.fabricmc.loader.impl.launch.knot.KnotClient"
    profileLibraryName =
      if isQuiltProfile
        then "org.quiltmc:quilt-loader:0.29.1"
        else "example:loader:1.0"
    profileLibraryUrl =
      if isQuiltProfile
        then "https://libraries.minecraft.net/org/quiltmc/quilt-loader/0.29.1/quilt-loader-0.29.1.jar"
        else "https://libraries.minecraft.net/example/loader/1.0/loader-1.0.jar"

forgePromotionsFixture :: BL.ByteString
forgePromotionsFixture =
  "{\"promos\":{\"26.1.2-recommended\":\"50.0.1\",\"forge-missing-installer-recommended\":\"50.0.404\"}}"

neoForgeMetadataFixture :: BL.ByteString
neoForgeMetadataFixture =
  "<metadata><versioning><versions><version>26.1.2.1</version></versions></versioning></metadata>"

modrinthProjectFixture :: String -> String -> BL.ByteString
modrinthProjectFixture project modFileName =
  modrinthProjectFixtureForLoader project modFileName "fabric"

modrinthProjectFixtureForLoader :: String -> String -> String -> BL.ByteString
modrinthProjectFixtureForLoader project modFileName loaderName =
  BL8.pack
    ( "[{\"id\":\""
        <> project
        <> "-version\",\"project_id\":\""
        <> project
        <> "\",\"name\":\""
        <> project
        <> "\",\"version_number\":\"1.0.0\",\"dependencies\":[],\"game_versions\":[\"26.1.2\"],\"loaders\":[\""
        <> loaderName
        <> "\"],\"version_type\":\"release\",\"featured\":true,\"files\":[{\"url\":\"https://cdn.modrinth.com/data/"
        <> project
        <> "/"
        <> modFileName
        <> "\",\"filename\":\""
        <> modFileName
        <> "\",\"primary\":true}]}]"
    )

modrinthBadDependencyFixture :: BL.ByteString
modrinthBadDependencyFixture =
  "[{\"id\":\"iris-bad\",\"project_id\":\"iris\",\"name\":\"Iris Bad\",\"version_number\":\"1.0.0\",\"dependencies\":[{\"dependency_type\":\"required\"}],\"game_versions\":[\"bad-dep\"],\"loaders\":[\"fabric\"],\"version_type\":\"release\",\"featured\":true,\"files\":[{\"hashes\":{\"sha1\":\"1111111111111111111111111111111111111111\"},\"url\":\"https://cdn.example/iris.jar\",\"filename\":\"iris.jar\",\"primary\":true,\"size\":1234}]}]"

modrinthDependencyVersionsJson :: BL8.ByteString
modrinthDependencyVersionsJson =
  "[{\"id\":\"fabric-api-version\",\"project_id\":\"fabric-api\",\"name\":\"Fabric API\",\"version_number\":\"1.0.0\",\"dependencies\":[],\"game_versions\":[\"26.1.2\"],\"loaders\":[\"fabric\"],\"version_type\":\"release\",\"featured\":true,\"files\":[{\"hashes\":{\"sha1\":\"1111111111111111111111111111111111111111\"},\"url\":\"https://cdn.example/fabric-api-1.0.0.jar\",\"filename\":\"fabric-api-1.0.0.jar\",\"primary\":true,\"size\":1234}]}]"

modrinthProjectMetadataFixture :: BL8.ByteString -> BL8.ByteString -> BL8.ByteString
modrinthProjectMetadataFixture projectIdValue title =
  BL8.concat
    [ "{\"id\":\""
    , projectIdValue
    , "\",\"project_id\":\""
    , projectIdValue
    , "\",\"slug\":\""
    , projectIdValue
    , "\",\"title\":\""
    , title
    , "\",\"description\":\""
    , title
    , "\",\"project_type\":\"mod\",\"versions\":[\"26.1.2\"],\"loaders\":[\"fabric\"],\"status\":\"approved\"}"
    ]

modrinthIrisVersionsJson :: BL8.ByteString
modrinthIrisVersionsJson =
  "[{\"id\":\"iris-version\",\"project_id\":\"iris\",\"name\":\"Iris\",\"version_number\":\"1.0.0\",\"dependencies\":[{\"project_id\":\"fabric-api\",\"dependency_type\":\"required\"}],\"game_versions\":[\"26.1.2\"],\"loaders\":[\"fabric\"],\"version_type\":\"release\",\"featured\":true,\"files\":[{\"hashes\":{\"sha1\":\"2222222222222222222222222222222222222222\"},\"url\":\"https://cdn.example/iris-1.0.0.jar\",\"filename\":\"iris-1.0.0.jar\",\"primary\":true,\"size\":2345}]}]"

curseForgeProjectFixture :: Int -> BL8.ByteString -> BL8.ByteString
curseForgeProjectFixture projectIdValue name =
  BL8.concat
    [ "{\"data\":{\"id\":"
    , BL8.pack (show projectIdValue)
    , ",\"name\":\""
    , name
    , "\",\"slug\":\""
    , BL8.pack (show projectIdValue)
    , "\",\"summary\":\""
    , name
    , "\",\"classId\":6,\"latestFilesIndexes\":[{\"gameVersion\":\"26.1.2\",\"modLoader\":4}],\"status\":1}}"
    ]

curseForgeFilesFixture :: Int -> BL8.ByteString -> BL8.ByteString -> [Int] -> BL8.ByteString
curseForgeFilesFixture fileIdValue fileNameValue sha1 dependencies =
  BL8.concat
    [ "{\"data\":[{\"id\":"
    , BL8.pack (show fileIdValue)
    , ",\"displayName\":\""
    , fileNameValue
    , "\",\"fileName\":\""
    , fileNameValue
    , "\",\"fileLength\":3456,\"downloadUrl\":\"https://edge.forgecdn.net/files/"
    , BL8.pack (show fileIdValue)
    , "/"
    , fileNameValue
    , "\",\"gameVersions\":[\"26.1.2\",\"Fabric\"],\"releaseType\":1,\"hashes\":[{\"algo\":1,\"value\":\""
    , sha1
    , "\"}],\"dependencies\":["
    , BL8.intercalate "," (map curseDependencyFixture dependencies)
    , "]}]}"
    ]

curseDependencyFixture :: Int -> BL8.ByteString
curseDependencyFixture projectIdValue =
  BL8.concat
    [ "{\"modId\":"
    , BL8.pack (show projectIdValue)
    , ",\"relationType\":3}"
    ]

removeIfExists :: FilePath -> IO ()
removeIfExists path =
  removeFile path `catchAny` \_ -> pure ()

catchAny :: IO a -> (SomeException -> IO a) -> IO a
catchAny action handler = do
  result <- try action
  either handler pure result

roundedHead :: [Double] -> Maybe Int
roundedHead values =
  case values of
    value:_ -> Just (round value)
    [] -> Nothing

roundedLast :: [Double] -> Maybe Int
roundedLast values =
  case reverse values of
    value:_ -> Just (round value)
    [] -> Nothing

terminalJobs :: [DownloadProgress] -> Maybe (Int, Int)
terminalJobs snapshots =
  case reverse snapshots of
    progress:_ -> Just (progressCompletedJobs progress, progressTotalJobs progress)
    [] -> Nothing

assertEqual :: (Eq a, Show a) => String -> a -> a -> IO ()
assertEqual label expected actual =
  if actual == expected
    then pure ()
    else do
      putStrLn ("FAIL: " <> label)
      putStrLn ("  expected: " <> show expected)
      putStrLn ("  actual:   " <> show actual)
      exitFailure

testLayout :: MinecraftLayout
testLayout =
  MinecraftLayout
    { minecraftRoot = "/tmp/mc"
    , versionsDir = "/tmp/mc/versions"
    , librariesDir = "/tmp/mc/libraries"
    , assetsDir = "/tmp/mc/assets"
    , assetIndexesDir = "/tmp/mc/assets/indexes"
    , assetObjectsDir = "/tmp/mc/assets/objects"
    , allNativesDir = "/tmp/mc/natives"
    }

testVersionJson :: VersionJson
testVersionJson =
  VersionJson
    { versionId = "fabric-loader-0.19.2-1.20.1"
    , versionType = Just "release"
    , versionJavaVersion = Nothing
    , versionDownloads = Map.empty
    , versionAssetIndex = emptyDownloadInfo
    , versionLibraries =
        [ Library
            { libraryName = "org.ow2.asm:asm:9.6"
            , libraryDownloads = Nothing
            , libraryUrl = Just "https://libraries.minecraft.net/"
            , libraryRules = []
            , libraryNatives = Map.empty
            }
        , Library
            { libraryName = "net.fabricmc:fabric-loader:0.19.2"
            , libraryDownloads = Nothing
            , libraryUrl = Just "https://maven.fabricmc.net/"
            , libraryRules = []
            , libraryNatives = Map.empty
            }
        , Library
            { libraryName = "org.ow2.asm:asm:9.9"
            , libraryDownloads = Nothing
            , libraryUrl = Just "https://maven.fabricmc.net/"
            , libraryRules = []
            , libraryNatives = Map.empty
            }
        ]
    , versionMainClass = "net.fabricmc.loader.impl.launch.knot.KnotClient"
    , versionArguments = Nothing
    , versionMinecraftArguments = Nothing
    }

emptyDownloadInfo :: DownloadInfo
emptyDownloadInfo =
  DownloadInfo
    { downloadId = Nothing
    , downloadSha1 = Nothing
    , downloadSize = Nothing
    , downloadUrl = Nothing
    , downloadPath = Nothing
    }

modrinthProjectJson :: BL8.ByteString
modrinthProjectJson =
  "{\"id\":\"sodium\",\"title\":\"Sodium\"}"
