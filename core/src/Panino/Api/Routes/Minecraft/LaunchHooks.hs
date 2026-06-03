{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Minecraft.LaunchHooks
  ( LaunchHookSession(..)
  , beginLaunchHooks
  , runBestEffortLaunchChecks
  , writeLaunchJvmDiagnostics
  ) where

import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import Control.Monad (when)
import Data.Aeson
  ( encode
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Routes.LaunchTuning (systemMemoryBytes)
import Panino.Api.Routes.Minecraft.Common (versionJsonJavaMajor)
import Panino.Api.Types (LaunchRequest(..))
import Panino.Launch.Java (JavaRunResult(..))
import Panino.Launch.Tuning.Types (ResolvedJvmTuning(..))
import Panino.Lockfile.Solver
  ( lockfileLaunchBlockedReasons
  , verifyLockfile
  )
import Panino.Lockfile.Store (readCurrentLockfile)
import Panino.Minecraft.Layout
  ( MinecraftLayout
  , minecraftRoot
  )
import Panino.Minecraft.ModPreflight (preflightModDependencies)
import Panino.Minecraft.Types (VersionJson(..))
import Panino.Performance.Profile.Store
  ( baselineProfile
  , storeProfile
  )
import Panino.Performance.Profile.Types
  ( InstanceFingerprint(..)
  , PerformanceKnobs(..)
  , defaultInstanceFingerprint
  , defaultPerformanceKnobs
  , estimatedEvidence
  , profileId
  )
import Panino.Performance.Telemetry.Collect
  ( beginPerformanceSession
  , completePerformanceSession
  , javaGcLogArguments
  )
import Panino.Performance.Telemetry.Types
  ( PerformanceSession
  , sessionLaunchSessionId
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  )
import System.FilePath
  ( takeDirectory
  , (</>)
  )
import System.Timeout (timeout)

data LaunchHookSession = LaunchHookSession
  { launchHookJvmArgs :: [String]
  , completeLaunchHookSession :: JavaRunResult -> IO ()
  }

beginLaunchHooks :: MinecraftLayout -> VersionJson -> LaunchRequest -> ResolvedJvmTuning -> IO LaunchHookSession
beginLaunchHooks layout versionJson request tuning = do
  outcome <- timeout 1000000 (try (beginPerformanceHooks layout versionJson request tuning))
  case outcome of
    Just (Right hooks) -> pure hooks
    Just (Left (err :: SomeException)) -> do
      recordLaunchHookWarning layout "performance_begin" (Text.pack (displayException err))
      pure noLaunchHookSession
    Nothing -> do
      recordLaunchHookWarning layout "performance_begin_timeout" "performance hook setup exceeded 1s"
      pure noLaunchHookSession

runBestEffortLaunchChecks :: MinecraftLayout -> VersionJson -> IO ()
runBestEffortLaunchChecks layout versionJson = do
  runBestEffortHook layout "lockfile_verify" (verifyLaunchLockfile layout)
  when (usesModLoader versionJson) $
    runBestEffortHook layout "mod_dependency_preflight" (preflightModDependencies (minecraftRoot layout))

writeLaunchJvmDiagnostics :: MinecraftLayout -> ResolvedJvmTuning -> [String] -> IO ()
writeLaunchJvmDiagnostics layout tuning javaArgs = do
  let directory = minecraftRoot layout </> "downloads"
  result <-
    try $ do
      createDirectoryIfMissing True directory
      graphicsPatch <- readTextFileIfExists (directory </> "graphics-options-patch.txt")
      graphicsTuningExists <- doesFileExist (directory </> "graphics-tuning.json")
      BL.writeFile (directory </> "jvm-tuning.json") (encode tuning)
      writeFile (directory </> "launch-effective-jvm-args.txt") (unlines javaArgs)
      BL.writeFile
        (directory </> "launch-performance-profile.json")
        ( encode $
            object
              [ "jvmProfile" .= resolvedTuningEffectivePolicy tuning
              , "jvmMemoryMb" .= resolvedTuningXmxMb tuning
              , "jvmTuning" .= tuning
              , "effectiveJvmArgs" .= javaArgs
              , "graphicsTuningPath" .= (directory </> "graphics-tuning.json")
              , "graphicsTuningRecorded" .= graphicsTuningExists
              , "graphicsOptionsPatchPath" .= (directory </> "graphics-options-patch.txt")
              , "graphicsOptionsPatch" .= graphicsPatch
              ]
        )
  case result of
    Right () -> pure ()
    Left (err :: SomeException) ->
      recordLaunchHookWarning layout "jvm_diagnostics" (Text.pack (displayException err))

beginPerformanceHooks :: MinecraftLayout -> VersionJson -> LaunchRequest -> ResolvedJvmTuning -> IO LaunchHookSession
beginPerformanceHooks layout versionJson request tuning = do
  let fingerprint = launchInstanceFingerprint versionJson request
      profileKnobs = performanceKnobsFromTuning tuning
      baseline =
        baselineProfile
          (minecraftRoot layout)
          fingerprint
          profileKnobs
          [ estimatedEvidence "source" "launch safe baseline"
          , estimatedEvidence "jvmProfile" (Text.pack (show (resolvedTuningEffectivePolicy tuning)))
          ]
  storeProfile (minecraftRoot layout) baseline
  session <-
    beginPerformanceSession
      (minecraftRoot layout)
      fingerprint
      (Just (profileId baseline))
      Nothing
      (Just baseline)
      (resolvedTuningRollbackRef tuning)
  let javaMajor = fromMaybe 17 (versionJsonJavaMajor versionJson)
  (gcLogPath, gcArgs) <- javaGcLogArguments javaMajor (minecraftRoot layout) (sessionLaunchSessionId session)
  pure
    LaunchHookSession
      { launchHookJvmArgs = gcArgs
      , completeLaunchHookSession = completePerformanceHook layout session gcLogPath
      }

completePerformanceHook :: MinecraftLayout -> PerformanceSession -> Maybe FilePath -> JavaRunResult -> IO ()
completePerformanceHook layout session gcLogPath result = do
  outcome <- try $ do
    systemMemory <- systemMemoryBytes
    _ <- completePerformanceSession session (javaExitCode result) systemMemory (javaMemorySamples result) gcLogPath
    pure ()
  case outcome of
    Right () -> pure ()
    Left (err :: SomeException) ->
      recordLaunchHookWarning layout "performance_complete" (Text.pack (displayException err))

noLaunchHookSession :: LaunchHookSession
noLaunchHookSession =
  LaunchHookSession
    { launchHookJvmArgs = []
    , completeLaunchHookSession = const (pure ())
    }

runBestEffortHook :: MinecraftLayout -> Text -> IO () -> IO ()
runBestEffortHook layout hookName action = do
  outcome <- try action
  case outcome of
    Right () -> pure ()
    Left (err :: SomeException) ->
      recordLaunchHookWarning layout hookName (Text.pack (displayException err))

recordLaunchHookWarning :: MinecraftLayout -> Text -> Text -> IO ()
recordLaunchHookWarning layout hookName message = do
  putStrLn ("launch_hook_warning:" <> Text.unpack hookName <> ":" <> Text.unpack message)
  let path = minecraftRoot layout </> "downloads" </> "launch-hooks.log"
      rendered = Text.unpack hookName <> ": " <> Text.unpack message <> "\n"
  outcome <-
    try $ do
      createDirectoryIfMissing True (takeDirectory path)
      appendFile path rendered
  case outcome of
    Right () -> pure ()
    Left (_ :: SomeException) -> pure ()

launchInstanceFingerprint :: VersionJson -> LaunchRequest -> InstanceFingerprint
launchInstanceFingerprint versionJson request =
  defaultInstanceFingerprint
    { fingerprintMinecraftVersion = Just (versionId versionJson)
    , fingerprintJavaRequirement = Text.pack . show <$> versionJsonJavaMajor versionJson
    , fingerprintLoaderFamily = launchRequestLoader request
    , fingerprintRendererCapability = Just "java_renderer_unknown"
    , fingerprintModCount = launchRequestModCount request
    , fingerprintShaderLoader = Nothing
    }

performanceKnobsFromTuning :: ResolvedJvmTuning -> PerformanceKnobs
performanceKnobsFromTuning tuning =
  defaultPerformanceKnobs
    { knobHeapMaxMb = Just (resolvedTuningXmxMb tuning)
    , knobHeapInitialPolicy = Just "adaptive"
    , knobGcPolicy = Just (if any ("UseZGC" `Text.isInfixOf`) (resolvedTuningJvmArgs tuning) then "zgc" else "g1_or_default")
    }

verifyLaunchLockfile :: MinecraftLayout -> IO ()
verifyLaunchLockfile layout = do
  loaded <- readCurrentLockfile (minecraftRoot layout)
  case loaded of
    Left err ->
      fail ("lockfile_launch_verify_failed: " <> err)
    Right Nothing ->
      pure ()
    Right (Just lockfile) -> do
      verifyResponse <- verifyLockfile (minecraftRoot layout) lockfile
      let blockedReasons = lockfileLaunchBlockedReasons verifyResponse
      when (not (null blockedReasons)) $
        fail ("solver_lock_drift: " <> Text.unpack (Text.intercalate "," blockedReasons))

usesModLoader :: VersionJson -> Bool
usesModLoader versionJson =
  any (`Text.isInfixOf` normalized)
    [ "fabric"
    , "quilt"
    , "forge"
    , "neoforge"
    ]
  where
    normalized =
      Text.toLower (versionId versionJson <> " " <> versionMainClass versionJson)

readTextFileIfExists :: FilePath -> IO (Maybe String)
readTextFileIfExists path = do
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else do
      result <- try (readFile path)
      pure $ case result of
        Right text -> Just text
        Left (_ :: SomeException) -> Nothing
