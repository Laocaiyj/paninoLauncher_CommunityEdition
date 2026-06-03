{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Minecraft.LaunchTask
  ( observeStartedLaunchWithDelay
  , runLaunchTask
  ) where

import Control.Applicative ((<|>))
import Control.Concurrent (threadDelay)
import Control.Concurrent.Async (async)
import Control.Exception
  ( SomeException
  , displayException
  , throwIO
  , try
  )
import Control.Monad (when)
import Data.List (sortOn)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Routes.LaunchTuning (systemMemoryBytes)
import Panino.Api.Routes.Minecraft.Common
  ( downloadOptionsFromRuntime
  , launchFailureDiagnostic
  , launchProfile
  , launchRequestedLoader
  , requestLayout
  , resolveAutoJavaPath
  , versionJsonJavaMajor
  )
import Panino.Api.Routes.Minecraft.Common (resolveLoaderInstallerJavaPath)
import Panino.Api.Routes.Minecraft.LaunchHooks
  ( LaunchHookSession(..)
  , beginLaunchHooks
  , runBestEffortLaunchChecks
  , writeLaunchJvmDiagnostics
  )
import Panino.Api.Routes.Minecraft.Progress
  ( emitPhaseMarker
  , launchRepairProgressPhases
  , newAggregatedProgressSink
  )
import Panino.Api.Routes.Tasks (taskIsCancelled)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( LaunchRequest(..)
  , TaskSnapshot
  )
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , diagnosticException
  )
import Panino.Download.Manager (DownloadProgress)
import Panino.Launch.Arguments
  ( LaunchProfile(..)
  , buildJavaArguments
  )
import Panino.Launch.Java
  ( JavaProcessLaunch(..)
  , JavaRunResult(..)
  , startJavaProcessWithTelemetry
  )
import Panino.Launch.Tuning.Recommend (recommendJvmTuning)
import Panino.Launch.Tuning.Types
  ( JvmTuningPolicy(..)
  , JvmTuningRequest(..)
  , MemoryPolicy(..)
  , ResolvedJvmTuning
  )
import Panino.Minecraft.Install
  ( InstallResult(..)
  , classpathJars
  , installMinecraftVersionWithOptionsAndProgressAndCancel
  )
import Panino.Minecraft.InstanceMetadata
  ( InstanceMetadata(..)
  , readInstanceMetadata
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout
  , ensureLayout
  , minecraftRoot
  )
import Panino.Minecraft.LoaderInstall
  ( LoaderInstallOptions(..)
  , LoaderInstallResult(..)
  , installMinecraftProfileWithOptionsAndProgressAndCancel
  , normalizeLoaderName
  , removeTrackedShaderInstallFiles
  )
import Panino.Minecraft.Manifest (loadVersionJson)
import Panino.Minecraft.Types (VersionJson(..))
import System.Directory
  ( doesDirectoryExist
  , listDirectory
  )
import System.Exit (ExitCode(..))
import System.FilePath
  ( takeExtension
  , (</>)
  )

runLaunchTask :: ServerState -> TaskSnapshot -> LaunchRequest -> IO Text
runLaunchTask state task request = do
  layout <- requestLayout state (launchRequestGameDir request)
  ensureLayout layout
  versionJson <-
    if fromMaybe True (launchRequestInstallBefore request)
      then
        installVersionJson <$> runLaunchInstallTask state task layout request
      else loadVersionJson (stateHttpManager state) layout (launchRequestVersion request)
  javaProgress <- newAggregatedProgressSink state task launchRepairProgressPhases
  javaPath <- resolveLaunchJavaPath state task layout request javaProgress
  tuning <- resolveLaunchJvmTuning layout versionJson request
  hooks <- beginLaunchHooks layout versionJson request tuning
  let profile =
        (launchProfile request)
          { profileJavaPath = javaPath
          , profileJvmArgs = map Text.pack (launchHookJvmArgs hooks)
          , profileJvmTuning = Just tuning
          }
      javaArgs = buildJavaArguments layout versionJson (classpathJars layout versionJson) profile
  writeLaunchJvmDiagnostics layout tuning javaArgs
  _ <- async (runBestEffortLaunchChecks layout versionJson)
  launch <- startJavaProcessWithTelemetry javaPath (minecraftRoot layout) javaArgs
  observeStartedLaunch state task layout hooks launch

resolveLaunchJavaPath :: ServerState -> TaskSnapshot -> MinecraftLayout -> LaunchRequest -> (DownloadProgress -> IO ()) -> IO FilePath
resolveLaunchJavaPath state task layout request onProgress =
  case launchRequestJavaPath request of
    Just javaPath | not (null javaPath) -> pure javaPath
    _ ->
      resolveAutoJavaPath
        state
        layout
        (launchRequestVersion request)
        (launchRequestDownload request)
        (taskIsCancelled state task)
        onProgress

resolveLaunchJvmTuning :: MinecraftLayout -> VersionJson -> LaunchRequest -> IO ResolvedJvmTuning
resolveLaunchJvmTuning layout versionJson request = do
  systemMemory <- systemMemoryBytes
  counts <- launchContentCounts (minecraftRoot layout)
  let memoryPolicy =
        fromMaybe
          (if launchRequestCustomMemoryMb request /= Nothing then MemoryPolicyCustom else MemoryPolicyAuto)
          (launchRequestMemoryPolicy request)
      customMemory =
        launchRequestCustomMemoryMb request
          <|> if memoryPolicy == MemoryPolicyCustom then launchRequestMemoryMb request else Nothing
      customArgs =
        if null (launchRequestCustomJvmArgs request)
          then launchRequestJvmArgs request
          else launchRequestCustomJvmArgs request
      tuningRequest =
        JvmTuningRequest
          { tuningRequestInstanceId = launchRequestInstanceId request
          , tuningRequestGameDir = launchRequestGameDir request
          , tuningRequestPolicy = fromMaybe JvmTuningAuto (launchRequestJvmProfile request)
          , tuningRequestMemoryPolicy = memoryPolicy
          , tuningRequestSystemMemoryBytes = systemMemory
          , tuningRequestMinecraftVersion = Just (versionId versionJson)
          , tuningRequestJavaMajorVersion = versionJsonJavaMajor versionJson
          , tuningRequestLoader = launchRequestLoader request
          , tuningRequestModCount = launchRequestModCount request <|> Just (contentMods counts)
          , tuningRequestResourcePackCount = launchRequestResourcePackCount request <|> Just (contentResourcePacks counts)
          , tuningRequestShaderPackCount = launchRequestShaderPackCount request <|> Just (contentShaderPacks counts)
          , tuningRequestPackScale = Nothing
          , tuningRequestModpackIsLarge = False
          , tuningRequestSawHeapOutOfMemory = False
          , tuningRequestSawNativeOutOfMemory = False
          , tuningRequestSawGcOverhead = False
          , tuningRequestLastExitCode = Nothing
          , tuningRequestCustomMemoryMb = customMemory
          , tuningRequestCustomJvmArgs = customArgs
          }
  pure (recommendJvmTuning tuningRequest)

data LaunchContentCounts = LaunchContentCounts
  { contentMods :: Int
  , contentResourcePacks :: Int
  , contentShaderPacks :: Int
  } deriving (Eq, Show)

launchContentCounts :: FilePath -> IO LaunchContentCounts
launchContentCounts gameDir =
  LaunchContentCounts
    <$> countFilesWithExtensions (gameDir </> "mods") [".jar"]
    <*> countFilesWithExtensions (gameDir </> "resourcepacks") [".zip"]
    <*> countFilesWithExtensions (gameDir </> "shaderpacks") [".zip"]

countFilesWithExtensions :: FilePath -> [String] -> IO Int
countFilesWithExtensions directory extensions = do
  exists <- doesDirectoryExist directory
  if not exists
    then pure 0
    else do
      result <- try (sortOn id <$> listDirectory directory)
      pure $ case result of
        Right entries ->
          length
            [ entry
            | entry <- entries
            , takeExtension entry `elem` extensions
            ]
        Left (_ :: SomeException) -> 0

observeStartedLaunch :: ServerState -> TaskSnapshot -> MinecraftLayout -> LaunchHookSession -> JavaProcessLaunch -> IO Text
observeStartedLaunch =
  observeStartedLaunchWithDelay 10000000

observeStartedLaunchWithDelay :: Int -> ServerState -> TaskSnapshot -> MinecraftLayout -> LaunchHookSession -> JavaProcessLaunch -> IO Text
observeStartedLaunchWithDelay delayMicros state task layout hooks launch = do
  threadDelay delayMicros
  earlyExit <- pollJavaProcessExitCode launch
  case earlyExit of
    Nothing -> do
      _ <- async (monitorLaunchProcess layout hooks launch)
      emitPhaseMarker state task "launch" "Start game process" 4 4 100 "game process started"
      pure "java process started"
    Just _ ->
      waitJavaProcess launch >>= finalizeForegroundLaunch state task layout hooks

finalizeForegroundLaunch :: ServerState -> TaskSnapshot -> MinecraftLayout -> LaunchHookSession -> JavaRunResult -> IO Text
finalizeForegroundLaunch state task layout hooks result = do
  completeLaunchHookSession hooks result
  case javaExitCode result of
    ExitSuccess -> do
      emitPhaseMarker state task "launch" "Start game process" 4 4 100 "java exited successfully"
      pure "java exited successfully"
    ExitFailure code ->
      throwIO . diagnosticException =<< launchFailureDiagnostic layout code result

monitorLaunchProcess :: MinecraftLayout -> LaunchHookSession -> JavaProcessLaunch -> IO ()
monitorLaunchProcess layout hooks launch = do
  outcome <- try (waitJavaProcess launch)
  case outcome of
    Right result -> do
      completeLaunchHookSession hooks result
      case javaExitCode result of
        ExitSuccess -> pure ()
        ExitFailure code -> do
          diagnosticOutcome <- try (launchFailureDiagnostic layout code result)
          case diagnosticOutcome of
            Right diagnostic ->
              putStrLn ("launch_process_failed:" <> Text.unpack (diagnosticCode diagnostic) <> ":" <> Text.unpack (diagnosticMessage diagnostic))
            Left (err :: SomeException) ->
              putStrLn ("launch_process_failed:diagnostic_failed:" <> displayException err)
    Left (err :: SomeException) ->
      putStrLn ("launch_process_monitor_failed:" <> displayException err)

runLaunchInstallTask :: ServerState -> TaskSnapshot -> MinecraftLayout -> LaunchRequest -> IO InstallResult
runLaunchInstallTask state task layout request = do
  metadata <- readInstanceMetadata (minecraftRoot layout) (launchRequestVersion request)
  let downloadOptions = downloadOptionsFromRuntime (launchRequestDownload request)
      requestedLoader = launchRequestedLoader request
      repairShaderLoader = launchRepairShaderLoader metadata
  emitProgress <- newAggregatedProgressSink state task launchRepairProgressPhases
  when (launchRepairShouldRemoveTrackedShaderFiles metadata requestedLoader repairShaderLoader) $ do
    removeTrackedShaderInstallFiles layout
    putStrLn "launch_repair_shader_cleanup:quilt_tracked_shader_files"
  if metadataLaunchVersion metadata == launchRequestVersion request && metadataHasExtendedInstall metadata
    then do
      installerJava <-
        resolveLoaderInstallerJavaPath
          state
          layout
          (metadataMinecraftVersion metadata)
          (metadataLoader metadata)
          (launchRequestDownload request)
          (taskIsCancelled state task)
          emitProgress
      when (repairShaderLoader /= metadataShaderLoader metadata) $
        putStrLn "launch_repair_shader_skipped:quilt_iris_incompatible"
      loaderInstallResult
        <$> installMinecraftProfileWithOptionsAndProgressAndCancel
          (stateHttpManager state)
          layout
          (metadataMinecraftVersion metadata)
          downloadOptions
          (taskIsCancelled state task)
          emitProgress
          LoaderInstallOptions
            { loaderInstallLoader = metadataLoader metadata
            , loaderInstallLoaderVersion = metadataLoaderVersion metadata
            , loaderInstallShaderLoader = repairShaderLoader
            , loaderInstallShaderVersion = Nothing
            , loaderInstallInstanceName = metadataName metadata
            , loaderInstallJavaExecutable = installerJava
            , loaderInstallExpectedProfileId = Nothing
            }
    else
      case requestedLoader of
        Just loader -> do
          installerJava <-
            resolveLoaderInstallerJavaPath
              state
              layout
              (launchRequestVersion request)
              (Just loader)
              (launchRequestDownload request)
              (taskIsCancelled state task)
              emitProgress
          loaderInstallResult
            <$> installMinecraftProfileWithOptionsAndProgressAndCancel
              (stateHttpManager state)
              layout
              (launchRequestVersion request)
              downloadOptions
              (taskIsCancelled state task)
              emitProgress
              LoaderInstallOptions
                { loaderInstallLoader = Just loader
                , loaderInstallLoaderVersion = Nothing
                , loaderInstallShaderLoader = Nothing
                , loaderInstallShaderVersion = Nothing
                , loaderInstallInstanceName = metadataName metadata
                , loaderInstallJavaExecutable = installerJava
                , loaderInstallExpectedProfileId = Nothing
                }
        Nothing ->
          installMinecraftVersionWithOptionsAndProgressAndCancel
            (stateHttpManager state)
            layout
            (launchRequestVersion request)
            downloadOptions
            (taskIsCancelled state task)
            emitProgress

metadataHasExtendedInstall :: InstanceMetadata -> Bool
metadataHasExtendedInstall metadata =
  metadataLoader metadata /= Nothing || metadataShaderLoader metadata /= Nothing

launchRepairShaderLoader :: InstanceMetadata -> Maybe Text
launchRepairShaderLoader metadata =
  case (normalizeLoaderName <$> metadataLoader metadata, normalizeLoaderName <$> metadataShaderLoader metadata) of
    (Just "quilt", Just "iris") -> Nothing
    _ -> metadataShaderLoader metadata

launchRepairShouldRemoveTrackedShaderFiles :: InstanceMetadata -> Maybe Text -> Maybe Text -> Bool
launchRepairShouldRemoveTrackedShaderFiles metadata requestedLoader repairShaderLoader =
  (normalizeLoaderName <$> (requestedLoader <|> metadataLoader metadata)) == Just "quilt"
    && repairShaderLoader == Nothing
