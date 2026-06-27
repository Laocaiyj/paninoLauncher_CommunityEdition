{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Minecraft.Common
  ( appSupportRoot
  , downloadOptionsFromRuntime
  , javaFailureMessage
  , launchFailureDiagnostic
  , launchProfile
  , launchRequestedLoader
  , missingGameDir
  , requestLayout
  , resolveAutoJavaPath
  , resolveLoaderInstallerJavaPath
  , resolveReadyLoaderInstallerJavaPath
  , trimProcessOutput
  , versionJsonJavaMajor
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.List
  ( isInfixOf
  , sortOn
  )
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( DownloadRuntimeOptions(..)
  , LaunchRequest(..)
  , launchRequestVersionText
  )
import Panino.Core.Types
  ( GameDir
  , gameDirPath
  )
import Panino.Diagnostics.Classify (classifyFailure)
import Panino.Diagnostics.Types
  ( Diagnostic
  , FailureInput(..)
  )
import Panino.Download.Manager
  ( DownloadOptions
  , DownloadProgress
  , downloadOptionsWithOverrides
  )
import Panino.Launch.Arguments (LaunchProfile(..))
import Panino.Launch.Java (JavaRunResult(..))
import Panino.Minecraft.Layout
  ( MinecraftLayout
  , minecraftRoot
  , mkLayout
  )
import Panino.Minecraft.LoaderInstall (normalizeLoaderName)
import Panino.Minecraft.Types
  ( JavaVersion(..)
  , VersionJson(..)
  )
import Panino.Runtime.Java.Install (installJavaRuntime)
import Panino.Runtime.Java.Resolve (resolveJavaRuntimeForVersion)
import Panino.Runtime.Java.Types
  ( JavaManagedRuntime(..)
  , JavaRuntimeDownloadSpec(..)
  , JavaRuntimeInstallRequest(..)
  , JavaRuntimeResolveResponse(..)
  )
import System.Directory
  ( doesDirectoryExist
  , listDirectory
  )
import System.FilePath
  ( takeDirectory
  , takeExtension
  , (</>)
  )

requestLayout :: ServerState -> Maybe GameDir -> IO MinecraftLayout
requestLayout _ requestedGameDir =
  case requestedGameDir of
    Just gameDir | not (null (gameDirPath gameDir)) -> mkLayout (Just (gameDirPath gameDir))
    _ -> fail "gameDir is required for isolated Minecraft operations"

missingGameDir :: Maybe GameDir -> Bool
missingGameDir Nothing = True
missingGameDir (Just value) = null (gameDirPath value)

launchProfile :: LaunchRequest -> LaunchProfile
launchProfile request =
  LaunchProfile
    { profileVersion = launchRequestVersionText request
    , profileMemoryMb = fromMaybe 4096 (launchRequestMemoryMb request)
    , profileJavaPath = fromMaybe "java" (launchRequestJavaPath request)
    , profileUsername = fromMaybe "Steve" (launchRequestUsername request)
    , profileUuid = fromMaybe "00000000-0000-0000-0000-000000000000" (launchRequestUuid request)
    , profileAccessToken = fromMaybe "0" (launchRequestAccessToken request)
    , profileJvmArgs = launchRequestJvmArgs request
    , profileJvmTuning = Nothing
    , profileWindowWidth = launchRequestWindowWidth request
    , profileWindowHeight = launchRequestWindowHeight request
    }

downloadOptionsFromRuntime :: DownloadRuntimeOptions -> DownloadOptions
downloadOptionsFromRuntime options =
  downloadOptionsWithOverrides
    (strategyConcurrency options)
    (strategyRetryCount options)

strategyConcurrency :: DownloadRuntimeOptions -> Maybe Int
strategyConcurrency options =
  case normalizeDownloadStrategy <$> downloadRuntimeStrategy options of
    Just "fast" -> Just (max 48 (fromMaybe 32 (downloadRuntimeConcurrency options)))
    Just "conservative" -> Just (min 12 (fromMaybe 12 (downloadRuntimeConcurrency options)))
    _ -> downloadRuntimeConcurrency options

strategyRetryCount :: DownloadRuntimeOptions -> Maybe Int
strategyRetryCount options =
  case normalizeDownloadStrategy <$> downloadRuntimeStrategy options of
    Just "fast" -> Just (max 4 (fromMaybe 3 (downloadRuntimeRetryCount options)))
    Just "conservative" -> Just (max 2 (fromMaybe 2 (downloadRuntimeRetryCount options)))
    _ -> downloadRuntimeRetryCount options

normalizeDownloadStrategy :: Text -> Text
normalizeDownloadStrategy =
  Text.toLower . Text.replace "-" "" . Text.replace "_" ""

resolveLoaderInstallerJavaPath :: ServerState -> MinecraftLayout -> Text -> Maybe Text -> DownloadRuntimeOptions -> IO Bool -> (DownloadProgress -> IO ()) -> IO (Maybe FilePath)
resolveLoaderInstallerJavaPath state layout minecraftVersion maybeLoader downloadRuntime isCancelled onProgress =
  case normalizeLoaderName <$> maybeLoader of
    Just "forge" -> Just <$> resolveAutoJavaPath state layout minecraftVersion downloadRuntime isCancelled onProgress
    Just "neoforge" -> Just <$> resolveAutoJavaPath state layout minecraftVersion downloadRuntime isCancelled onProgress
    _ -> pure Nothing

resolveReadyLoaderInstallerJavaPath :: ServerState -> MinecraftLayout -> Text -> Maybe Text -> IO (Maybe FilePath)
resolveReadyLoaderInstallerJavaPath state layout minecraftVersion maybeLoader =
  case normalizeLoaderName <$> maybeLoader of
    Just "forge" -> resolveReadyAutoJavaPath state layout minecraftVersion
    Just "neoforge" -> resolveReadyAutoJavaPath state layout minecraftVersion
    _ -> pure Nothing

resolveReadyAutoJavaPath :: ServerState -> MinecraftLayout -> Text -> IO (Maybe FilePath)
resolveReadyAutoJavaPath state layout minecraftVersion = do
  appRoot <- appSupportRoot state
  resolved <- resolveJavaRuntimeForVersion (stateHttpManager state) appRoot layout minecraftVersion
  pure $
    case resolveResponseJavaExecutable resolved of
      Just javaPath | resolveResponseStatus resolved == "ready" -> Just javaPath
      _ -> Nothing

resolveAutoJavaPath :: ServerState -> MinecraftLayout -> Text -> DownloadRuntimeOptions -> IO Bool -> (DownloadProgress -> IO ()) -> IO FilePath
resolveAutoJavaPath state layout minecraftVersion downloadRuntime isCancelled onProgress = do
  appRoot <- appSupportRoot state
  resolved <- resolveJavaRuntimeForVersion (stateHttpManager state) appRoot layout minecraftVersion
  case resolveResponseJavaExecutable resolved of
    Just javaPath | resolveResponseStatus resolved == "ready" -> pure javaPath
    _ | resolveResponseStatus resolved == "downloadable" ->
      case resolveResponseDownload resolved of
        Just spec -> do
          runtime <-
            installJavaRuntime
              (stateHttpManager state)
              appRoot
              (javaInstallRequestFromDownload spec downloadRuntime)
              isCancelled
              onProgress
          pure (managedRuntimeJavaExecutable runtime)
        Nothing ->
          fail
            ( "java_runtime_download_not_found: Java "
                <> show (resolveResponseRequiredMajorVersion resolved)
                <> " is required for Minecraft "
                <> Text.unpack minecraftVersion
                <> ", but no managed runtime download is available."
            )
    _ ->
      fail
        ( "java_runtime_missing: Java "
            <> show (resolveResponseRequiredMajorVersion resolved)
            <> " is required for Minecraft "
            <> Text.unpack minecraftVersion
            <> ". Download it in Runtime settings."
        )

javaInstallRequestFromDownload :: JavaRuntimeDownloadSpec -> DownloadRuntimeOptions -> JavaRuntimeInstallRequest
javaInstallRequestFromDownload spec downloadRuntime =
  JavaRuntimeInstallRequest
    { installRuntimeFeatureVersion = runtimeDownloadFeatureVersion spec
    , installRuntimeProvider = runtimeDownloadProvider spec
    , installRuntimeVendor = runtimeDownloadVendor spec
    , installRuntimeOs = Just (runtimeDownloadOs spec)
    , installRuntimeArch = Just (runtimeDownloadArch spec)
    , installRuntimeImageType = runtimeDownloadImageType spec
    , installRuntimeSetDefault = False
    , installRuntimeDownload = downloadRuntime
    }

appSupportRoot :: ServerState -> IO FilePath
appSupportRoot state = do
  layout <- mkLayout (stateDefaultGameDir state)
  pure (takeDirectory (minecraftRoot layout))

versionJsonJavaMajor :: VersionJson -> Maybe Int
versionJsonJavaMajor versionJson =
  versionJavaVersion versionJson >>= javaVersionMajorVersion

launchRequestedLoader :: LaunchRequest -> Maybe Text
launchRequestedLoader request =
  case normalizeLoaderName <$> launchRequestLoader request of
    Just "vanilla" -> Nothing
    Just "none" -> Nothing
    Just "" -> Nothing
    Just _ -> launchRequestLoader request
    Nothing -> Nothing

javaFailureMessage :: Int -> JavaRunResult -> String
javaFailureMessage code result =
  "java exited with code " <> show code <> renderedOutput
  where
    output = trimProcessOutput (javaStderr result <> "\n" <> javaStdout result)
    renderedOutput
      | null output = ""
      | otherwise = ": " <> output

trimProcessOutput :: String -> String
trimProcessOutput =
  unlines . take 4 . filter (not . null) . lines

launchFailureDiagnostic :: MinecraftLayout -> Int -> JavaRunResult -> IO Diagnostic
launchFailureDiagnostic layout code result = do
  crashReport <- latestCrashReportPath (minecraftRoot layout)
  let latestLog = minecraftRoot layout </> "logs" </> "latest.log"
      signals = detectedLaunchSignals result
      evidence =
        [ ("exitCode", Text.pack (show code))
        , ("latestLogPath", Text.pack latestLog)
        , ("stderrTail", Text.pack (trimProcessOutput (javaStderr result)))
        , ("stdoutTail", Text.pack (trimProcessOutput (javaStdout result)))
        ]
          <> maybe [] (\path -> [("crashReportPath", Text.pack path)]) crashReport
          <> if null signals then [] else [("detectedSignals", Text.intercalate "," signals)]
  pure $
    classifyFailure
      FailureInput
        { failurePhase = "launch"
        , failureOperation = "launch"
        , failureExceptionText = Text.pack (javaFailureMessage code result)
        , failureContext = evidence
        , failureTaskId = Nothing
        , failurePlanId = Nothing
        , failureSource = Just "java"
        }

latestCrashReportPath :: FilePath -> IO (Maybe FilePath)
latestCrashReportPath gameDir = do
  let directory = gameDir </> "crash-reports"
  exists <- doesDirectoryExist directory
  if not exists
    then pure Nothing
    else do
      result <- try (sortOn id <$> listDirectory directory)
      pure $ case result of
        Right entries ->
          case reverse [directory </> entry | entry <- entries, takeExtension entry == ".txt"] of
            path:_ -> Just path
            [] -> Nothing
        Left (_ :: SomeException) -> Nothing

detectedLaunchSignals :: JavaRunResult -> [Text]
detectedLaunchSignals result =
  [ signal
  | (needle, signal) <- signalNeedles
  , needle `isInfixOf` lowered
  ]
  where
    lowered = map toLowerAscii (javaStderr result <> "\n" <> javaStdout result)
    signalNeedles =
      [ ("outofmemoryerror", "out_of_memory")
      , ("could not reserve enough space", "memory_allocation_failed")
      , ("unsupportedclassversionerror", "java_version_incompatible")
      , ("mod resolution failed", "mod_resolution_failed")
      , ("missing or unsupported mandatory dependencies", "missing_mod_dependency")
      , ("failed to find", "missing_class_or_file")
      , ("exception in thread", "java_exception")
      , ("crash report", "crash_report")
      ]

toLowerAscii :: Char -> Char
toLowerAscii char
  | char >= 'A' && char <= 'Z' = toEnum (fromEnum char + 32)
  | otherwise = char
