{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Minecraft.InstallTask.Rollback
  ( InstallRollbackOutcome(..)
  , InstallRollbackSnapshot
  , prepareInstallRollbackSnapshot
  , rollbackInstallFailure
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Control.Monad
  ( filterM
  , forM
  , forM_
  , when
  )
import Data.Aeson
  ( encode
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.List
  ( (\\)
  , sortOn
  )
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (getCurrentTime)
import Panino.Api.Types (TaskSnapshot(..))
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
