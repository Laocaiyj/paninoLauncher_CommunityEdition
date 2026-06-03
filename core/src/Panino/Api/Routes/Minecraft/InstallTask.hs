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
import Control.Monad
  ( filterM
  , forM
  , forM_
  , when
  )
import Data.Aeson
  ( Value
  , encode
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.List
  ( (\\)
  , sortOn
  )
import Data.Maybe (fromMaybe)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (getCurrentTime)
import Panino.Api.Routes.Minecraft.Common
  ( downloadOptionsFromRuntime
  , requestLayout
  , resolveLoaderInstallerJavaPath
  )
import Panino.Api.Routes.Minecraft.Progress
  ( emitPhaseMarker
  , newInstallProgressSink
  )
import Panino.Api.Routes.Tasks (taskIsCancelled)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( InstallRequest(..)
  , TaskSnapshot(..)
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
  , assetIndexesDir
  , librariesDir
  , minecraftRoot
  , versionJsonPath
  , versionsDir
  )
import System.Directory
  ( copyFile
  , createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , listDirectory
  , removeDirectory
  , removeFile
  )
import System.FilePath
  ( isRelative
  , makeRelative
  , normalise
  , splitDirectories
  , takeDirectory
  , takeExtension
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
    emitPhaseMarker state task "prepare" "Prepare install plan" 1 5 0 "preparing install"
    emitProgress <- newInstallProgressSink state task request
    installerJava <-
      resolveLoaderInstallerJavaPath
        state
        layout
        (installRequestVersion request)
        (installRequestLoader request)
        (installRequestDownload request)
        (taskIsCancelled state task)
        emitProgress
    profileResult <-
      installMinecraftProfileWithOptionsAndProgressAndCancel
        (stateHttpManager state)
        layout
        (installRequestVersion request)
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

writeInstallState :: MinecraftLayout -> TaskSnapshot -> InstallRequest -> Text -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe FilePath -> IO ()
writeInstallState layout task request installState errorCode errorDetail installedProfile failedPhase rollbackReportPath = do
  now <- getCurrentTime
  let payload =
        object
          [ "state" .= installState
          , "taskId" .= taskSnapshotId task
          , "requestedMinecraftVersion" .= installRequestVersion request
          , "requestedLoader" .= installRequestLoader request
          , "requestedShaderLoader" .= installRequestShaderLoader request
          , "installedProfile" .= installedProfile
          , "errorCode" .= errorCode
          , "errorDetail" .= errorDetail
          , "failedPhase" .= failedPhase
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

data InstallRollbackSnapshot = InstallRollbackSnapshot
  { installRollbackSnapshotFiles :: Set.Set FilePath
  , installRollbackSnapshotBackups :: [(FilePath, FilePath)]
  , installRollbackSnapshotProfiles :: [Text]
  , installRollbackSnapshotBackupRoot :: FilePath
  } deriving (Eq, Show)

data InstallRollbackOutcome = InstallRollbackOutcome
  { installRollbackStatus :: Text
  , installRollbackReportPath :: FilePath
  , installRollbackRemovedFiles :: [FilePath]
  , installRollbackRestoredFiles :: [FilePath]
  , installRollbackNewProfiles :: [Text]
  , installRollbackFailures :: [Text]
  } deriving (Eq, Show)

prepareInstallRollbackSnapshot :: MinecraftLayout -> TaskSnapshot -> IO InstallRollbackSnapshot
prepareInstallRollbackSnapshot layout task = do
  files <- watchedInstallFiles layout
  profiles <- rollbackProfileIds layout
  let backupRoot = minecraftRoot layout </> "downloads" </> "rollback-backups" </> Text.unpack (taskSnapshotId task)
      backupTargets = filter (shouldBackupForInstallRollback layout) files
  createDirectoryIfMissing True backupRoot
  backups <- forM backupTargets $ \target -> do
    let backup = backupRoot </> safeRelativeToRoot layout target
    createDirectoryIfMissing True (takeDirectory backup)
    copyFile target backup
    pure (target, backup)
  backupFiles <- listFilesRecursiveIfExists backupRoot
  pure
    InstallRollbackSnapshot
      { installRollbackSnapshotFiles = Set.fromList (map normalise (files <> backupFiles))
      , installRollbackSnapshotBackups = backups
      , installRollbackSnapshotProfiles = profiles
      , installRollbackSnapshotBackupRoot = backupRoot
      }

rollbackInstallFailure :: MinecraftLayout -> TaskSnapshot -> InstallRollbackSnapshot -> IO InstallRollbackOutcome
rollbackInstallFailure layout task snapshot = do
  afterFiles <- watchedInstallFiles layout
  afterProfiles <- rollbackProfileIds layout
  let beforeSet = installRollbackSnapshotFiles snapshot
      afterSet = Set.fromList (map normalise afterFiles)
      createdFiles = filter (shouldRemoveCreatedInstallFile layout) (Set.toList (afterSet `Set.difference` beforeSet))
      newProfiles = afterProfiles \\ installRollbackSnapshotProfiles snapshot
  removeResults <- forM createdFiles $ \path ->
    rollbackAction "removeCreatedFile" path $ do
      exists <- doesFileExist path
      when exists (removeFile path)
  restoreResults <- forM (installRollbackSnapshotBackups snapshot) $ \(target, backup) ->
    rollbackAction "restoreBackup" target $ do
      backupExists <- doesFileExist backup
      when backupExists $ do
        createDirectoryIfMissing True (takeDirectory target)
        copyFile backup target
  let removedFiles = [path | Right path <- removeResults]
      restoredFiles = [path | Right path <- restoreResults]
      failures = [message | Left message <- removeResults <> restoreResults]
  forM_ removedFiles (cleanupEmptyInstallDirectories layout)
  let status =
        if null failures
          then "rolled_back"
          else "partial_install_left_for_diagnosis"
      reportPath = minecraftRoot layout </> "downloads" </> "install-rollback.json"
      outcome =
        InstallRollbackOutcome
          { installRollbackStatus = status
          , installRollbackReportPath = reportPath
          , installRollbackRemovedFiles = removedFiles
          , installRollbackRestoredFiles = restoredFiles
          , installRollbackNewProfiles = newProfiles
          , installRollbackFailures = failures
          }
  writeInstallRollbackReport task snapshot outcome
  pure outcome

rollbackAction :: Text -> FilePath -> IO () -> IO (Either Text FilePath)
rollbackAction action path io = do
  outcome <- try io
  pure $ case outcome of
    Right () -> Right path
    Left (err :: SomeException) ->
      Left (action <> ":" <> Text.pack path <> ":" <> Text.pack (show err))

writeInstallRollbackReport :: TaskSnapshot -> InstallRollbackSnapshot -> InstallRollbackOutcome -> IO ()
writeInstallRollbackReport task snapshot outcome = do
  now <- getCurrentTime
  let reportPath = installRollbackReportPath outcome
  createDirectoryIfMissing True (takeDirectory reportPath)
  BL.writeFile
    reportPath
    ( encode $
        object
          [ "taskId" .= taskSnapshotId task
          , "state" .= installRollbackStatus outcome
          , "removedFiles" .= installRollbackRemovedFiles outcome
          , "restoredFiles" .= installRollbackRestoredFiles outcome
          , "newProfiles" .= installRollbackNewProfiles outcome
          , "failures" .= installRollbackFailures outcome
          , "backupRoot" .= installRollbackSnapshotBackupRoot snapshot
          , "writtenAt" .= now
          ]
    )

watchedInstallFiles :: MinecraftLayout -> IO [FilePath]
watchedInstallFiles layout = do
  directoryFiles <-
    fmap concat $
      traverse
        listFilesRecursiveIfExists
        [ versionsDir layout
        , librariesDir layout
        , assetIndexesDir layout
        , minecraftRoot layout </> "mods"
        , minecraftRoot layout </> ".panino"
        , minecraftRoot layout </> "downloads"
        ]
  rootFiles <-
    filterM
      doesFileExist
      [ minecraftRoot layout </> "launcher_profiles.json"
      ]
  pure (directoryFiles <> map normalise rootFiles)

listFilesRecursiveIfExists :: FilePath -> IO [FilePath]
listFilesRecursiveIfExists directory = do
  exists <- doesDirectoryExist directory
  if not exists
    then pure []
    else listFilesRecursive directory

listFilesRecursive :: FilePath -> IO [FilePath]
listFilesRecursive directory = do
  entries <- sortOn id <$> listDirectory directory
  fmap concat $
    forM entries $ \entry -> do
      let path = directory </> entry
      isFile <- doesFileExist path
      isDirectory <- doesDirectoryExist path
      if isFile
        then pure [normalise path]
        else
          if isDirectory
            then listFilesRecursive path
            else pure []

rollbackProfileIds :: MinecraftLayout -> IO [Text]
rollbackProfileIds layout = do
  exists <- doesDirectoryExist (versionsDir layout)
  if not exists
    then pure []
    else do
      entries <- sortOn id <$> listDirectory (versionsDir layout)
      fmap concat $
        forM entries $ \entry -> do
          let version = Text.pack entry
          jsonExists <- doesFileExist (versionJsonPath layout version)
          pure [version | jsonExists]

shouldBackupForInstallRollback :: MinecraftLayout -> FilePath -> Bool
shouldBackupForInstallRollback layout path =
  (isUnderDirectory (versionsDir layout) path && takeExtension path == ".json")
    || (isUnderDirectory (minecraftRoot layout </> "mods") path && takeExtension path == ".jar")
    || normalise path == normalise (minecraftRoot layout </> ".panino" </> "instance.json")
    || normalise path == normalise (minecraftRoot layout </> "launcher_profiles.json")
    || normalise path == normalise (minecraftRoot layout </> "downloads" </> "install-plan-graph.json")

shouldRemoveCreatedInstallFile :: MinecraftLayout -> FilePath -> Bool
shouldRemoveCreatedInstallFile layout path =
  not (isUnderDirectory (minecraftRoot layout </> "downloads" </> "rollback-backups") path)
    && ( isUnderDirectory (versionsDir layout) path
           || isUnderDirectory (librariesDir layout) path
           || isUnderDirectory (assetIndexesDir layout) path
           || (isUnderDirectory (minecraftRoot layout </> "mods") path && takeExtension path == ".jar")
           || normalise path == normalise (minecraftRoot layout </> ".panino" </> "instance.json")
           || normalise path == normalise (minecraftRoot layout </> "launcher_profiles.json")
           || (isUnderDirectory (minecraftRoot layout </> "downloads") path && takeExtension path == ".jar")
       )

cleanupEmptyInstallDirectories :: MinecraftLayout -> FilePath -> IO ()
cleanupEmptyInstallDirectories layout path =
  cleanup (takeDirectory path)
  where
    boundaries =
      map normalise
        [ versionsDir layout
        , librariesDir layout
        , assetIndexesDir layout
        , minecraftRoot layout </> "mods"
        , minecraftRoot layout </> "downloads"
        ]
    cleanup directory
      | normalise directory `elem` boundaries = pure ()
      | not (isUnderAnyDirectory boundaries directory) = pure ()
      | otherwise = do
          outcome <- try (removeDirectory directory)
          case outcome of
            Right () -> cleanup (takeDirectory directory)
            Left (_ :: SomeException) -> pure ()

isUnderAnyDirectory :: [FilePath] -> FilePath -> Bool
isUnderAnyDirectory roots path =
  any (`isUnderDirectory` path) roots

isUnderDirectory :: FilePath -> FilePath -> Bool
isUnderDirectory directory path =
  let relative = makeRelative (normalise directory) (normalise path)
   in relative /= "."
        && isRelative relative
        && not (".." `elem` splitDirectories relative)

safeRelativeToRoot :: MinecraftLayout -> FilePath -> FilePath
safeRelativeToRoot layout path =
  let relative = makeRelative (normalise (minecraftRoot layout)) (normalise path)
   in if isRelative relative && not (".." `elem` splitDirectories relative)
        then relative
        else "external" </> Text.unpack (Text.replace "/" "_" (Text.pack (normalise path)))

installFailurePhase :: Text -> Text
installFailurePhase code
  | "loader_" `Text.isPrefixOf` code = "loader"
  | "shader_" `Text.isPrefixOf` code || code == "manual_install_required" = "content"
  | code == "install_post_verify_failed" = "verify"
  | "java_runtime_" `Text.isPrefixOf` code || code == "java_not_found" = "prepare"
  | code `elem` ["network_error", "hash_mismatch", "manifest_parse_failed"] = "minecraft"
  | otherwise = "install"

installFailureDetail :: MinecraftLayout -> InstallRequest -> LoaderInstallPreflightResponse -> SomeException -> Text -> Text -> Text -> InstallRollbackOutcome -> IO Text
installFailureDetail layout request preflight err originalCode finalCode failedPhase rollback =
  do
    loaderLogTail <- readInstallLogTail (minecraftRoot layout </> "downloads" </> "loader-install.log")
    pure $
      Text.unlines $
        [ finalCode <> ": install task failed"
        , "requestedMinecraftVersion=" <> installRequestVersion request
        , "requestedGameDir=" <> Text.pack (fromMaybe "-" (installRequestGameDir request))
        , "requestedLoader=" <> fromMaybe "-" (installRequestLoader request)
        , "requestedShaderLoader=" <> fromMaybe "-" (installRequestShaderLoader request)
        , "loaderVersion=" <> fromMaybe "-" (preflightResponseLoaderVersion preflight)
        , "loaderProfileId=" <> fromMaybe "-" (preflightResponseLoaderProfileId preflight)
        , "shaderProjects=" <> Text.intercalate "," (preflightResponseShaderProjects preflight)
        , "blockedReasons=" <> Text.intercalate "," (preflightResponseBlockedReasons preflight)
        , "originalErrorCode=" <> originalCode
        , "failedPhase=" <> failedPhase
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
