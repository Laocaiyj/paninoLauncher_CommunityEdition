{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Minecraft.InstallTask
  ( runInstallTask
  ) where

import Control.Concurrent.Async (AsyncCancelled)
import Control.Exception
  ( SomeAsyncException
  , SomeException
  , fromException
  , throwIO
  , try
  )
import Data.Aeson
  ( Value
  , encode
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (getCurrentTime)
import Panino.Api.Routes.Minecraft.Common
  ( downloadOptionsFromRuntime
  , requestLayout
  , resolveLoaderInstallerJavaPath
  )
import Panino.Api.Routes.Minecraft.Progress
  ( MinecraftTaskPhase(..)
  , emitPhaseMarker
  , newInstallProgressSink
  )
import Panino.Api.Routes.Minecraft.Phase
  ( minecraftTaskPhaseId
  )
import Panino.Api.Routes.Minecraft.InstallTask.Rollback
  ( InstallRollbackOutcome(..)
  , prepareInstallRollbackSnapshot
  , rollbackInstallFailure
  )
import Panino.Api.Routes.Tasks (taskIsCancelled)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( InstallRequest(..)
  , TaskSnapshot(..)
  , installRequestGameDirPath
  , installRequestVersionText
  , taskPhaseIdText
  )
import Panino.Download.Manager
  ( DownloadException(..)
  , DownloadSummary(..)
  )
import Panino.Minecraft.Install
  ( InstallResult(..)
  )
import Panino.Minecraft.InstallPreflight
  ( LoaderInstallPreflightResponse(..)
  , writeInstallPreflightDiagnostics
  )
import Panino.Minecraft.LoaderInstall
  ( LoaderInstallOptions(..)
  , LoaderInstallResult(..)
  , installMinecraftProfileWithOptionsAndProgressAndCancel
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout
  , minecraftRoot
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  )
import System.FilePath
  ( takeDirectory
  , (</>)
  )

runInstallTask :: ServerState -> TaskSnapshot -> InstallRequest -> LoaderInstallPreflightResponse -> IO Text
runInstallTask state task request preflight = do
  layout <- requestLayout state (installRequestGameDir request)
  let downloadOptions = downloadOptionsFromRuntime (installRequestDownload request)
  writeInstallPreflightDiagnostics layout preflight
  writeInstallState layout task request "running" Nothing Nothing Nothing Nothing Nothing
  rollbackSnapshot <- prepareInstallRollbackSnapshot layout task
  outcome <- try $ do
    emitPhaseMarker state task MinecraftPhasePrepare "Prepare install plan" 1 5 0 "preparing install"
    emitProgress <- newInstallProgressSink state task request
    installerJava <-
      resolveLoaderInstallerJavaPath
        state
        layout
        (installRequestVersionText request)
        (installRequestLoader request)
        (installRequestDownload request)
        (taskIsCancelled state task)
        emitProgress
    profileResult <-
      installMinecraftProfileWithOptionsAndProgressAndCancel
        (stateHttpManager state)
        layout
        (installRequestVersionText request)
        downloadOptions
        (taskIsCancelled state task)
        emitProgress
        LoaderInstallOptions
          { loaderInstallLoader = installRequestLoader request
          , loaderInstallLoaderVersion = installRequestLoaderVersion request
          , loaderInstallShaderLoader = installRequestShaderLoader request
          , loaderInstallShaderVersion = installRequestShaderVersion request
          , loaderInstallInstanceName = installRequestInstanceName request
          , loaderInstallJavaExecutable = installerJava
          , loaderInstallExpectedProfileId = preflightResponseLoaderProfileId preflight
          }
    let result = loaderInstallResult profileResult
    let summary = installDownloadSummary result
    writeInstallState layout task request "succeeded" Nothing Nothing (Just (loaderInstallProfileVersion profileResult)) Nothing Nothing
    pure
      ( Text.pack
          ( "installed into "
              <> minecraftRoot layout
              <> " as "
              <> Text.unpack (loaderInstallProfileVersion profileResult)
              <> " with "
              <> show (length (installClasspathJars result))
              <> " classpath jars and "
              <> show (totalCount summary)
              <> " checked downloads"
          )
      )
  case outcome of
    Right message -> pure message
    Left (err :: SomeException)
      | isInstallCancellationException err -> do
          writeInstallState layout task request "cancelled" Nothing Nothing Nothing Nothing Nothing
          throwIO err
    Left (err :: SomeException) -> do
      rollback <- rollbackInstallFailure layout task rollbackSnapshot
      let originalCode = installErrorCodeFromException err
          finalCode =
            if installRollbackStatus rollback == "partial_install_left_for_diagnosis"
              then "partial_install_left_for_diagnosis"
              else originalCode
          failedPhase = installFailurePhase originalCode
      detail <- installFailureDetail layout request preflight err originalCode finalCode failedPhase rollback
      writeInstallState
        layout
        task
        request
        "failed"
        (Just finalCode)
        (Just detail)
        Nothing
        (Just failedPhase)
        (Just (installRollbackReportPath rollback))
      throwIO (userError (Text.unpack detail))

isInstallCancellationException :: SomeException -> Bool
isInstallCancellationException err =
  isDownloadCancelled || isAsyncCancelled || isSomeAsyncException
  where
    isDownloadCancelled =
      case fromException err of
        Just DownloadCancelled -> True
        Just _ -> False
        Nothing -> False
    isAsyncCancelled =
      case fromException err of
        Just (_ :: AsyncCancelled) -> True
        Nothing -> False
    isSomeAsyncException =
      case fromException err of
        Just (_ :: SomeAsyncException) -> True
        Nothing -> False

writeInstallState :: MinecraftLayout -> TaskSnapshot -> InstallRequest -> Text -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe MinecraftTaskPhase -> Maybe FilePath -> IO ()
writeInstallState layout task request installState errorCode errorDetail installedProfile failedPhase rollbackReportPath = do
  now <- getCurrentTime
  let payload =
        object
          [ "state" .= installState
          , "taskId" .= taskSnapshotId task
          , "requestedMinecraftVersion" .= installRequestVersionText request
          , "requestedLoader" .= installRequestLoader request
          , "requestedShaderLoader" .= installRequestShaderLoader request
          , "installedProfile" .= installedProfile
          , "errorCode" .= errorCode
          , "errorDetail" .= errorDetail
          , "failedPhase" .= fmap minecraftTaskPhaseId failedPhase
          , "rollbackReportPath" .= rollbackReportPath
          , "logPaths" .= installDiagnosticLogPaths layout
          , "startedAt" .= taskSnapshotCreatedAt task
          , "updatedAt" .= now
          ]
      statePath = minecraftRoot layout </> ".panino" </> "install-state.json"
      diagnosticPath = minecraftRoot layout </> "downloads" </> "install-state.json"
  createDirectoryIfMissing True (takeDirectory statePath)
  createDirectoryIfMissing True (takeDirectory diagnosticPath)
  BL.writeFile statePath (encode payload)
  BL.writeFile diagnosticPath (encode payload)

installDiagnosticLogPaths :: MinecraftLayout -> Value
installDiagnosticLogPaths layout =
  object
    [ "installState" .= (minecraftRoot layout </> "downloads" </> "install-state.json")
    , "preflight" .= (minecraftRoot layout </> "downloads" </> "install-preflight.json")
    , "loaderInstall" .= (minecraftRoot layout </> "downloads" </> "loader-install.log")
    , "shaderInstall" .= (minecraftRoot layout </> "downloads" </> "shader-install.log")
    , "rollback" .= (minecraftRoot layout </> "downloads" </> "install-rollback.json")
    ]

installFailurePhase :: Text -> MinecraftTaskPhase
installFailurePhase code
  | "loader_" `Text.isPrefixOf` code = MinecraftPhaseLoader
  | "shader_" `Text.isPrefixOf` code || code == "manual_install_required" = MinecraftPhaseContent
  | code == "install_post_verify_failed" = MinecraftPhaseVerify
  | "java_runtime_" `Text.isPrefixOf` code || code == "java_not_found" = MinecraftPhasePrepare
  | code `elem` ["network_error", "hash_mismatch", "manifest_parse_failed"] = MinecraftPhaseMinecraft
  | otherwise = MinecraftPhaseInstall

installFailureDetail :: MinecraftLayout -> InstallRequest -> LoaderInstallPreflightResponse -> SomeException -> Text -> Text -> MinecraftTaskPhase -> InstallRollbackOutcome -> IO Text
installFailureDetail layout request preflight err originalCode finalCode failedPhase rollback =
  do
    loaderLogTail <- readInstallLogTail (minecraftRoot layout </> "downloads" </> "loader-install.log")
    pure $
      Text.unlines $
        [ finalCode <> ": install task failed"
        , "requestedMinecraftVersion=" <> installRequestVersionText request
        , "requestedGameDir=" <> Text.pack (fromMaybe "-" (installRequestGameDirPath request))
        , "requestedLoader=" <> fromMaybe "-" (installRequestLoader request)
        , "requestedShaderLoader=" <> fromMaybe "-" (installRequestShaderLoader request)
        , "loaderVersion=" <> fromMaybe "-" (preflightResponseLoaderVersion preflight)
        , "loaderProfileId=" <> fromMaybe "-" (preflightResponseLoaderProfileId preflight)
        , "shaderProjects=" <> Text.intercalate "," (preflightResponseShaderProjects preflight)
        , "blockedReasons=" <> Text.intercalate "," (preflightResponseBlockedReasons preflight)
        , "originalErrorCode=" <> originalCode
        , "failedPhase=" <> taskPhaseIdText (minecraftTaskPhaseId failedPhase)
        , "rollbackState=" <> installRollbackStatus rollback
        , "rollbackReport=" <> Text.pack (installRollbackReportPath rollback)
        , "loaderLog=" <> Text.pack (minecraftRoot layout </> "downloads" </> "loader-install.log")
        , "shaderLog=" <> Text.pack (minecraftRoot layout </> "downloads" </> "shader-install.log")
        , "installState=" <> Text.pack (minecraftRoot layout </> "downloads" </> "install-state.json")
        , "originalError:"
        , Text.pack (show err)
        ]
          <> ( if Text.null loaderLogTail
                 then []
                 else ["loaderLogTail:", loaderLogTail]
             )
          <> [ "rollbackFailures=" <> Text.intercalate "; " (installRollbackFailures rollback)
             | not (null (installRollbackFailures rollback))
             ]

readInstallLogTail :: FilePath -> IO Text
readInstallLogTail path = do
  exists <- doesFileExist path
  if not exists
    then pure ""
    else do
      outcome <- try (readFile path)
      pure $ case outcome of
        Left (_ :: SomeException) -> ""
        Right contents ->
          Text.unlines $
            reverse $
              take 24 $
                reverse $
                  Text.lines (Text.pack contents)

installErrorCodeFromException :: SomeException -> Text
installErrorCodeFromException err =
  case filter (`Text.isInfixOf` raw) knownInstallErrorCodes of
    code:_ -> code
    [] -> "install_failed"
  where
    raw = Text.toLower (Text.pack (show err))
    knownInstallErrorCodes =
      [ "loader_metadata_source_failed"
      , "loader_version_not_found"
      , "loader_profile_fetch_failed"
      , "loader_profile_invalid"
      , "loader_installer_download_failed"
      , "loader_installer_java_missing"
      , "java_runtime_missing"
      , "loader_launcher_profiles_invalid"
      , "loader_installer_exit_failed"
      , "loader_profile_not_created"
      , "shader_loader_incompatible"
      , "shader_release_not_found"
      , "shader_dependency_unresolved"
      , "shader_dependency_conflict"
      , "shader_file_missing_download"
      , "manual_install_required"
      , "install_post_verify_failed"
      , "partial_install_rolled_back"
      , "partial_install_left_for_diagnosis"
      ]
