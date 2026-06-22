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
  ( toJSON
  , Value(..)
  , object
  , (.=)
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import Data.Char
  ( isDigit
  , toLower
  )
import Data.Int (Int64)
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( catMaybes
  , fromMaybe
  , listToMaybe
  )
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Text.Encoding.Error (lenientDecode)
import qualified Data.Text.Read as TextRead
import Data.Time.Clock
  ( UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Network.HTTP.Types
  ( status200
  , status400
  )
import Network.HTTP.Types.URI (urlDecode)
import Network.Wai
  ( Request
  , Response
  , queryString
  , strictRequestBody
  )
import Panino.Api.Response (jsonResponse)
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
import Panino.Api.Routes.GraphicsTuning (readGraphicsTuningForEnvironment)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( TaskSnapshot(..)
  , TaskState(..)
  , taskStateText
  )
import qualified Panino.Content.Local.Java as LocalJava
import Panino.Content.Local.Types
  ( JavaCheckRequest(..)
  , JavaCheckResponse(..)
  )
import Panino.Graphics.Tuning.Types
  ( GraphicsHardwareTier(..)
  , GraphicsTuningProfile(..)
  , GraphicsTuningRequest(..)
  , ResolvedGraphicsTuning
  , parseGraphicsHardwareTier
  , parseGraphicsTuningProfile
  )
import Panino.Launch.Tuning.Recommend (recommendJvmTuning)
import Panino.Launch.Tuning.Types
  ( JvmTuningPolicy(..)
  , JvmTuningRequest(..)
  , MemoryPolicy(..)
  , ResolvedJvmTuning(..)
  , parseJvmTuningPolicy
  , parseMemoryPolicy
  )
import Panino.Net.Http
  ( metadataRetryCount
  )
import Panino.Performance.Pack
  ( performanceModFileNames
  , recommendPerformancePack
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
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.FilePath
  ( (</>)
  , takeExtension
  , takeDirectory
  )
import System.Info
  ( arch
  , os
  )
import GHC.Conc (getNumCapabilities)

data EnvironmentReportContext = EnvironmentReportContext
  { environmentContextGameDir :: Maybe FilePath
  , environmentContextVersion :: Maybe Text
  , environmentContextLoader :: Maybe Text
  , environmentContextLoaderVersion :: Maybe Text
  , environmentContextMemoryMb :: Maybe Int
  , environmentContextMemoryPolicy :: Maybe MemoryPolicy
  , environmentContextJvmProfile :: Maybe JvmTuningPolicy
  , environmentContextModCount :: Maybe Int
  , environmentContextResourcePackCount :: Maybe Int
  , environmentContextResourcePackScale :: Maybe Text
  , environmentContextShaderPackCount :: Maybe Int
  , environmentContextCustomMemoryMb :: Maybe Int
  , environmentContextCustomJvmArgs :: [Text]
  , environmentContextGraphicsProfile :: Maybe GraphicsTuningProfile
  , environmentContextGraphicsHardwareTier :: Maybe GraphicsHardwareTier
  , environmentContextDisplayScale :: Maybe Double
  , environmentContextDisplayWidth :: Maybe Int
  , environmentContextDisplayHeight :: Maybe Int
  , environmentContextRefreshRate :: Maybe Int
  , environmentContextIsBuiltinDisplay :: Maybe Bool
  , environmentContextShaderEnabled :: Bool
  } deriving (Eq, Show)

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

data ReportConclusion = ReportConclusion
  { conclusionStatus :: Text
  , conclusionActions :: [Text]
  } deriving (Eq, Show)

environmentReportContext :: Request -> EnvironmentReportContext
environmentReportContext request =
  let shaderPackCount = queryInt "shaderPackCount"
   in EnvironmentReportContext
        { environmentContextGameDir = textToString <$> queryText "gameDir"
        , environmentContextVersion = queryText "version" <|> queryText "minecraftVersion"
        , environmentContextLoader = queryText "loader"
        , environmentContextLoaderVersion = queryText "loaderVersion"
        , environmentContextMemoryMb = queryInt "memoryMb" <|> queryInt "configuredMemoryMb"
        , environmentContextMemoryPolicy = queryText "memoryPolicy" >>= parseMemoryPolicy
        , environmentContextJvmProfile =
            (queryText "jvmProfile" <|> queryText "policy") >>= parseJvmTuningPolicy
        , environmentContextModCount = queryInt "modCount"
        , environmentContextResourcePackCount = queryInt "resourcePackCount"
        , environmentContextResourcePackScale = queryText "resourcePackScale"
        , environmentContextShaderPackCount = shaderPackCount
        , environmentContextCustomMemoryMb = queryInt "customMemoryMb"
        , environmentContextCustomJvmArgs = maybe [] Text.words (queryText "customJvmArgs")
        , environmentContextGraphicsProfile =
            (queryText "graphicsProfile" <|> queryText "requestedProfile") >>= parseGraphicsTuningProfile
        , environmentContextGraphicsHardwareTier =
            (queryText "graphicsHardwareTier" <|> queryText "hardwareTier") >>= parseGraphicsHardwareTier
        , environmentContextDisplayScale = queryDouble "displayScale"
        , environmentContextDisplayWidth = queryInt "displayWidth"
        , environmentContextDisplayHeight = queryInt "displayHeight"
        , environmentContextRefreshRate = queryInt "refreshRate"
        , environmentContextIsBuiltinDisplay = queryBool "isBuiltinDisplay"
        , environmentContextShaderEnabled =
            fromMaybe (maybe False (> 0) shaderPackCount) (queryBool "shaderEnabled")
        }
  where
    queryText key = do
      value <- lookup (BS8.pack key) (queryString request)
      Text.strip . Text.pack . BS8.unpack . urlDecode True <$> value
    queryInt key =
      queryText key >>= readIntText
    queryDouble key =
      queryText key >>= readDoubleText
    queryBool key =
      queryText key >>= readBoolText
    textToString = Text.unpack

environmentRequiredJavaMajor :: EnvironmentReportContext -> Maybe Int
environmentRequiredJavaMajor =
  minecraftRequiredJavaMajor . environmentContextVersion

javaRuleConclusion :: EnvironmentReportContext -> JavaCheckResponse -> ReportConclusion
javaRuleConclusion context java
  | not (javaResponseAvailable java) =
      ReportConclusion
        "blocking"
        ["Install Java " <> Text.pack (show (fromMaybe 21 requiredMajor)) <> "+ or set a custom Java executable in Settings."]
  | Just required <- requiredMajor
  , maybe True (< required) (javaResponseMajorVersion java) =
      ReportConclusion
        "blocking"
        ["Select a Java " <> Text.pack (show required) <> "+ runtime for this Minecraft version."]
  | javaArchitectureMatches java == Just False =
      ReportConclusion
        "warning"
        ["Use a Java runtime that matches the macOS CPU architecture to avoid Rosetta overhead."]
  | otherwise =
      ReportConclusion "ok" []
  where
    requiredMajor = environmentRequiredJavaMajor context

javaResolutionConclusion :: JavaRuntimeResolveResponse -> ReportConclusion
javaResolutionConclusion response =
  case resolveResponseStatus response of
    "ready" ->
      ReportConclusion "ok" []
    "downloadable" ->
      ReportConclusion
        "blocking"
        ["Download Java " <> Text.pack (show (resolveResponseRequiredMajorVersion response)) <> " before launch."]
    "missing" ->
      ReportConclusion
        "blocking"
        ["Choose or download Java " <> Text.pack (show (resolveResponseRequiredMajorVersion response)) <> "."]
    "incompatible" ->
      ReportConclusion
        "blocking"
        (nonEmptyActions ["Select a matching Java runtime."] (resolveResponseBlockingReasons response))
    "blocked" ->
      ReportConclusion
        "blocking"
        (nonEmptyActions ["Fix Java runtime permissions or provider access."] (resolveResponseBlockingReasons response))
    _ ->
      ReportConclusion "warning" (resolveResponseWarnings response)

nonEmptyActions :: [Text] -> [Text] -> [Text]
nonEmptyActions fallback values
  | null values = fallback
  | otherwise = values

javaArchitectureMatches :: JavaCheckResponse -> Maybe Bool
javaArchitectureMatches java =
  architectureMatches (Text.pack arch) <$> javaResponseArchitecture java

memoryConclusionWithRecommendation :: Maybe Int64 -> Maybe Int -> Int -> ReportConclusion
memoryConclusionWithRecommendation systemBytes configuredMb recommended =
  case configuredMb of
    Nothing ->
      ReportConclusion "warning" ["Set an instance memory value so launch diagnostics can validate it before start."]
    Just configured
      | configured < recommended ->
          ReportConclusion
            "warning"
            ["Increase memory to at least " <> Text.pack (show recommended) <> " MB for this version family."]
      | Just total <- systemMb
      , configured > max recommended (total * 3 `div` 4) ->
          ReportConclusion
            "warning"
            ["Lower the configured memory so macOS and the launcher keep enough free RAM."]
      | otherwise ->
          ReportConclusion "ok" []
  where
    systemMb = fromIntegral . (`div` (1024 * 1024)) <$> systemBytes

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

environmentRuntimeFeedback :: ServerState -> Maybe FilePath -> IO Value
environmentRuntimeFeedback state gameDir = do
  latestTask <- latestLaunchTask state gameDir
  let profilePath = (</> "downloads" </> "launch-performance-profile.json") <$> gameDir
      latestLogPath = (</> "logs" </> "latest.log") <$> gameDir
  profilePresent <- maybe (pure False) safeDoesFileExist profilePath
  latestLogTail <- maybe (pure Nothing) readTailText latestLogPath
  latestCrash <- maybe (pure Nothing) latestCrashReport gameDir
  crashTail <- maybe (pure Nothing) (readTailText . fst) latestCrash
  let combined =
        Text.toLower $
          Text.unwords $
            catMaybes
              [ taskRuntimeText <$> latestTask
              , latestLogTail
              , crashTail
              ]
      signals = runtimeSignals latestTask combined
      actions = runtimeActions signals
      status
        | gameDir == Nothing = "unavailable" :: Text
        | null signals = "ok"
        | otherwise = "needs_action"
  pure $
    object
      [ "status" .= status
      , "signals" .= signals
      , "actions" .= actions
      , "lastLaunchState" .= (taskStateText . taskSnapshotState <$> latestTask)
      , "lastLaunchTaskId" .= (taskSnapshotId <$> latestTask)
      , "exitCode" .= (latestTask >>= runtimeExitCode)
      , "durationMs" .= (latestTask >>= runtimeDurationMs)
      , "profilePath" .= profilePath
      , "profilePresent" .= profilePresent
      , "latestLogPath" .= latestLogPath
      , "latestLogPresent" .= maybe False (const True) latestLogTail
      , "crashReportPath" .= (fst <$> latestCrash)
      , "crashReportPresent" .= maybe False (const True) latestCrash
      , "logSummary" .= runtimeSummary signals
      ]

latestLaunchTask :: ServerState -> Maybe FilePath -> IO (Maybe TaskSnapshot)
latestLaunchTask state gameDir = do
  taskMap <- readTVarIO (stateTasks state)
  let matchesGameDir task =
        maybe True (\dir -> taskSnapshotGameDir task == Just dir) gameDir
      tasks =
        filter
          (\task -> taskSnapshotKind task == "launch" && matchesGameDir task)
          (Map.elems taskMap)
  pure (listToMaybe (sortOn (Down . taskSnapshotUpdatedAt) tasks))

latestCrashReport :: FilePath -> IO (Maybe (FilePath, FilePath))
latestCrashReport gameDir = do
  let crashDir = gameDir </> "crash-reports"
  exists <- safeDoesDirectoryExist crashDir
  if not exists
    then pure Nothing
    else do
      result <- try (listDirectory crashDir)
      pure $ case result of
        Right entries ->
          listToMaybe
            [ (crashDir </> entry, entry)
            | entry <- sortOn Down entries
            , takeExtension entry == ".txt"
            ]
        Left (_ :: SomeException) -> Nothing

runtimeSignals :: Maybe TaskSnapshot -> Text -> [Text]
runtimeSignals latestTask combined =
  concat
    [ ["heap_oom" | containsAny ["outofmemoryerror", "java heap space", "heap oom"] combined]
    , ["native_oom" | containsAny ["native memory", "unable to allocate", "os::commit_memory", "mmap failed"] combined]
    , ["gc_overhead" | containsAny ["gc overhead", "gcoverhead"] combined]
    , ["renderer_problem" | containsAny ["opengl", "lwjgl", "glfw", "renderer", "shader", "iris", "sodium", "oculus", "embeddium"] combined]
    , ["quick_exit" | maybe False isQuickFailedLaunch latestTask]
    , ["crash_report" | containsAny ["---- minecraft crash report ----", "crash report"] combined]
    ]

runtimeActions :: [Text] -> [Text]
runtimeActions signals
  | null signals =
      ["Keep automatic performance tuning. If the next launch feels slow, run environment diagnostics again."]
  | otherwise =
      concat
        [ ["Use automatic memory first; do not raise the JVM heap just because Minecraft crashed." | "heap_oom" `elem` signals]
        , ["Lower graphics distance or resource-pack pressure so unified memory keeps room for the GPU." | "native_oom" `elem` signals]
        , ["Restore the automatic JVM profile before adding custom GC or memory flags." | "gc_overhead" `elem` signals]
        , ["Apply recommended graphics settings and relaunch Minecraft before changing advanced video options." | "renderer_problem" `elem` signals]
        , ["Open the latest crash report; fix the first listed mod or renderer error before adding more memory." | "crash_report" `elem` signals]
        , ["If the launch closes within 30 seconds, check Java and loader compatibility before changing performance settings." | "quick_exit" `elem` signals]
        ]

runtimeSummary :: [Text] -> Text
runtimeSummary signals
  | null signals = "No recent launch signal requires a performance change."
  | "heap_oom" `elem` signals = "Last launch looks memory-related. Start with Panino's automatic heap, not a larger manual heap."
  | "renderer_problem" `elem` signals = "Last launch looks graphics or renderer-related. Apply the recommended video settings and restart."
  | "gc_overhead" `elem` signals = "Last launch spent too much effort on garbage collection. Use the automatic JVM profile first."
  | otherwise = "Last launch produced a signal that needs review before further tuning."

taskRuntimeText :: TaskSnapshot -> Text
taskRuntimeText task =
  Text.unwords $
    catMaybes
      [ taskSnapshotMessage task
      , taskSnapshotErrorCode task
      , taskSnapshotErrorDetail task
      ]

runtimeExitCode :: TaskSnapshot -> Maybe Int
runtimeExitCode =
  extractJavaExitCode . taskRuntimeText

runtimeDurationMs :: TaskSnapshot -> Maybe Int
runtimeDurationMs task = do
  finished <- taskSnapshotFinishedAt task
  pure (floor (realToFrac (diffUTCTime finished (taskSnapshotCreatedAt task)) * (1000 :: Double)))

isQuickFailedLaunch :: TaskSnapshot -> Bool
isQuickFailedLaunch task =
  taskSnapshotState task == TaskFailed
    && maybe False (< 30000) (runtimeDurationMs task)

extractJavaExitCode :: Text -> Maybe Int
extractJavaExitCode raw =
  case Text.breakOn marker (Text.toLower raw) of
    (_, rest) | Text.null rest -> Nothing
    (_, rest) ->
      let value = Text.stripStart (Text.drop (Text.length marker) rest)
       in case TextRead.signed TextRead.decimal value of
            Right (code, _) -> Just code
            Left _ -> Nothing
  where
    marker = "java exited with code "

readTailText :: FilePath -> IO (Maybe Text)
readTailText path = do
  result <- try (BS.readFile path)
  pure $ case result of
    Right bytes ->
      let maxBytes = 12000
          start = max 0 (BS.length bytes - maxBytes)
       in Just (TextEncoding.decodeUtf8With lenientDecode (BS.drop start bytes))
    Left (_ :: SomeException) -> Nothing

safeDoesFileExist :: FilePath -> IO Bool
safeDoesFileExist path = do
  result <- try (doesFileExist path)
  pure $ case result of
    Right exists -> exists
    Left (_ :: SomeException) -> False

safeDoesDirectoryExist :: FilePath -> IO Bool
safeDoesDirectoryExist path = do
  result <- try (doesDirectoryExist path)
  pure $ case result of
    Right exists -> exists
    Left (_ :: SomeException) -> False

containsAny :: [Text] -> Text -> Bool
containsAny needles haystack =
  any (`Text.isInfixOf` haystack) needles

compatibilityConclusion :: EnvironmentReportContext -> ReportConclusion
compatibilityConclusion context =
  case environmentContextLoader context of
    Nothing ->
      ReportConclusion "ok" []
    Just loader
      | normalizeLoader loader `elem` supportedLoaders ->
          ReportConclusion "ok" []
      | otherwise ->
          ReportConclusion
            "blocking"
            ["Select a supported loader: Fabric, Quilt, Forge, NeoForge, Iris, Oculus, or Vanilla."]
  where
    supportedLoaders =
      [ "vanilla"
      , "fabric"
      , "quilt"
      , "forge"
      , "neoforge"
      , "iris"
      , "oculus"
      , "none"
      ]

conclusionIsOk :: ReportConclusion -> Bool
conclusionIsOk conclusion =
  conclusionStatus conclusion == "ok"

conclusionNotBlocking :: ReportConclusion -> Bool
conclusionNotBlocking conclusion =
  conclusionStatus conclusion /= "blocking"

minecraftRequiredJavaMajor :: Maybe Text -> Maybe Int
minecraftRequiredJavaMajor Nothing =
  Nothing
minecraftRequiredJavaMajor (Just version)
  | Just release <- parseReleaseVersion version =
      Just
        ( if release >= (1, 20, 5)
            then 21
            else if release >= (1, 18, 0)
              then 17
              else if release >= (1, 17, 0)
                then 16
                else 8
        )
  | Just snapshotYear <- parseSnapshotYear version =
      Just (if snapshotYear >= 24 then 21 else if snapshotYear >= 21 then 17 else 8)
  | otherwise =
      Nothing

parseReleaseVersion :: Text -> Maybe (Int, Int, Int)
parseReleaseVersion value =
  case map readIntText (Text.splitOn "." value) of
    Just major : Just minor : patchMaybe : _ ->
      Just (major, minor, fromMaybe 0 patchMaybe)
    _ -> Nothing

parseSnapshotYear :: Text -> Maybe Int
parseSnapshotYear value =
  let prefix = Text.takeWhile isDigit value
      suffix = Text.dropWhile isDigit value
   in if Text.toLower (Text.take 1 suffix) == "w"
        then readIntText prefix
        else Nothing

readIntText :: Text -> Maybe Int
readIntText value =
  case reads (Text.unpack (Text.takeWhile isDigit value)) of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing

readDoubleText :: Text -> Maybe Double
readDoubleText value =
  case reads (Text.unpack value) of
    [(parsed, "")] -> Just parsed
    _ -> Nothing

readBoolText :: Text -> Maybe Bool
readBoolText value =
  case Text.toLower (Text.strip value) of
    "true" -> Just True
    "1" -> Just True
    "yes" -> Just True
    "false" -> Just False
    "0" -> Just False
    "no" -> Just False
    _ -> Nothing

architectureMatches :: Text -> Text -> Bool
architectureMatches systemArchitecture javaArchitecture =
  normalized systemArchitecture == normalized javaArchitecture
  where
    normalized raw
      | value `elem` ["aarch64", "arm64"] = "arm64"
      | value `elem` ["x86_64", "amd64"] = "x86_64"
      | otherwise = value
      where
        value = Text.pack (map toLower (Text.unpack raw))

normalizeLoader :: Text -> Text
normalizeLoader =
  Text.toLower . Text.replace "-" "" . Text.replace "_" ""

taskIsActive :: TaskSnapshot -> Bool
taskIsActive task =
  taskSnapshotState task `elem` [TaskQueued, TaskRunning]

uptimeSeconds :: UTCTime -> UTCTime -> Int
uptimeSeconds startedAt now =
  floor (realToFrac (diffUTCTime now startedAt) :: Double)
