{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Local.Delete
  ( archiveLocalDirectory
  , archiveMinecraftVersion
  , cleanMinecraftVersion
  , deleteLocalResource
  , importLocalArchive
  , restoreArchivedMinecraftVersion
  , toggleLocalResource
  , mutateMinecraftVersionStorage
  ) where

import Control.Monad (unless)
import qualified Data.Text as Text
import System.Exit (ExitCode(..))
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , removeDirectoryRecursive
  , removeFile
  , renameFile
  )
import System.FilePath
  ( dropExtension
  , replaceExtension
  , takeDirectory
  , takeExtension
  , takeFileName
  , (</>)
  )
import System.Process (proc, readCreateProcessWithExitCode)
import Panino.Content.Local.Path (movePathToTrash)
import Panino.Content.Local.Types

toggleLocalResource :: LocalResourceMutationRequest -> IO LocalResourceMutationResponse
toggleLocalResource request = do
  let source = localResourcePath request
      target =
        if takeExtension source == ".disabled"
          then dropExtension source
          else replaceExtension source (drop 1 (takeExtension source) <> ".disabled")
  exists <- doesFileExist source
  unless exists (ioError (userError ("Local resource does not exist: " <> source)))
  renameFile source target
  pure
    LocalResourceMutationResponse
      { mutationChanged = True
      , mutationPath = Just target
      , mutationMessage = "Resource state changed"
      }

deleteLocalResource :: LocalResourceMutationRequest -> IO LocalResourceMutationResponse
deleteLocalResource request = do
  moved <- movePathToTrash (localResourcePath request)
  pure
    LocalResourceMutationResponse
      { mutationChanged = fst moved
      , mutationPath = snd moved
      , mutationMessage =
          if fst moved
            then "Resource moved to Trash"
            else "Resource was already missing"
      }

archiveLocalDirectory :: LocalArchiveRequest -> IO LocalResourceMutationResponse
archiveLocalDirectory request = do
  let source = localArchiveSourcePath request
      target = localArchiveTargetPath request
  sourceExists <- doesDirectoryExist source
  unless sourceExists (ioError (userError ("Directory does not exist: " <> source)))
  validateZipPath target
  createDirectoryIfMissing True (takeDirectory target)
  targetExists <- doesFileExist target
  whenArchiveExists targetExists target
  runProcessChecked "/usr/bin/ditto" ["-c", "-k", "--sequesterRsrc", "--keepParent", source, target]
  pure
    LocalResourceMutationResponse
      { mutationChanged = True
      , mutationPath = Just target
      , mutationMessage = "Directory archived"
      }

importLocalArchive :: LocalArchiveImportRequest -> IO LocalResourceMutationResponse
importLocalArchive request = do
  let source = localArchiveImportPath request
      target = localArchiveImportTargetDir request
  validateZipPath source
  sourceExists <- doesFileExist source
  unless sourceExists (ioError (userError ("Archive does not exist: " <> source)))
  createDirectoryIfMissing True target
  runProcessChecked "/usr/bin/ditto" ["-x", "-k", source, target]
  if localArchiveImportDeleteArchive request
    then removeFile source
    else pure ()
  pure
    LocalResourceMutationResponse
      { mutationChanged = True
      , mutationPath = Just target
      , mutationMessage =
          if localArchiveImportDeleteArchive request
            then "Archive imported and removed"
            else "Archive imported"
      }

cleanMinecraftVersion :: MinecraftCleanVersionRequest -> IO LocalResourceMutationResponse
cleanMinecraftVersion request = do
  let versionPath = minecraftVersionPath (cleanVersionGameDir request) (cleanVersionId request)
  moved <- movePathToTrash versionPath
  pure
    LocalResourceMutationResponse
      { mutationChanged = fst moved
      , mutationPath = snd moved
      , mutationMessage =
          if fst moved
            then "Minecraft version moved to Trash"
            else "Minecraft version was already missing"
      }

mutateMinecraftVersionStorage :: MinecraftVersionStorageRequest -> IO LocalResourceMutationResponse
mutateMinecraftVersionStorage request =
  case versionStorageAction request of
    VersionStorageDelete ->
      cleanMinecraftVersion
        MinecraftCleanVersionRequest
          { cleanVersionId = versionStorageId request
          , cleanVersionGameDir = versionStorageGameDir request
          }
    VersionStorageArchive ->
      archiveMinecraftVersion request
    VersionStorageRestore ->
      restoreArchivedMinecraftVersion request

archiveMinecraftVersion :: MinecraftVersionStorageRequest -> IO LocalResourceMutationResponse
archiveMinecraftVersion request = do
  let versionId = versionStorageId request
      gameDir = versionStorageGameDir request
      versionPath = minecraftVersionPath gameDir versionId
      archivePath = minecraftArchivePath gameDir versionId
  validateVersionId versionId
  exists <- doesDirectoryExist versionPath
  unless exists (ioError (userError ("Minecraft version is not installed: " <> Text.unpack versionId)))
  createDirectoryIfMissing True (minecraftArchiveDir gameDir)
  archiveExists <- doesFileExist archivePath
  whenArchiveExists archiveExists archivePath
  runProcessChecked "/usr/bin/ditto" ["-c", "-k", "--sequesterRsrc", "--keepParent", versionPath, archivePath]
  removeDirectoryRecursive versionPath
  pure
    LocalResourceMutationResponse
      { mutationChanged = True
      , mutationPath = Just archivePath
      , mutationMessage = "Minecraft version archived"
      }

restoreArchivedMinecraftVersion :: MinecraftVersionStorageRequest -> IO LocalResourceMutationResponse
restoreArchivedMinecraftVersion request = do
  let versionId = versionStorageId request
      gameDir = versionStorageGameDir request
      versionPath = minecraftVersionPath gameDir versionId
      archivePath = minecraftArchivePath gameDir versionId
      versionsPath = gameDir </> "versions"
  validateVersionId versionId
  archiveExists <- doesFileExist archivePath
  unless archiveExists (ioError (userError ("Minecraft version archive is missing: " <> archivePath)))
  installed <- doesDirectoryExist versionPath
  whenInstalled installed versionPath
  createDirectoryIfMissing True versionsPath
  runProcessChecked "/usr/bin/ditto" ["-x", "-k", archivePath, versionsPath]
  removeFile archivePath
  pure
    LocalResourceMutationResponse
      { mutationChanged = True
      , mutationPath = Just versionPath
      , mutationMessage = "Minecraft version restored from archive"
      }

minecraftVersionPath :: FilePath -> Text.Text -> FilePath
minecraftVersionPath gameDir versionId =
  gameDir </> "versions" </> Text.unpack versionId

minecraftArchiveDir :: FilePath -> FilePath
minecraftArchiveDir gameDir =
  gameDir </> "versions" </> ".panino-archives"

minecraftArchivePath :: FilePath -> Text.Text -> FilePath
minecraftArchivePath gameDir versionId =
  minecraftArchiveDir gameDir </> Text.unpack versionId <> ".zip"

validateVersionId :: Text.Text -> IO ()
validateVersionId versionId = do
  let raw = Text.unpack versionId
  unless (not (null raw) && takeFileName raw == raw) $
    ioError (userError ("Invalid Minecraft version id: " <> raw))

validateZipPath :: FilePath -> IO ()
validateZipPath path =
  unless (takeExtension path == ".zip") $
    ioError (userError ("Archive path must end with .zip: " <> path))

whenArchiveExists :: Bool -> FilePath -> IO ()
whenArchiveExists exists archivePath =
  unless (not exists) $
    ioError (userError ("Minecraft version archive already exists: " <> archivePath))

whenInstalled :: Bool -> FilePath -> IO ()
whenInstalled installed versionPath =
  unless (not installed) $
    ioError (userError ("Minecraft version is already installed: " <> versionPath))

runProcessChecked :: FilePath -> [String] -> IO ()
runProcessChecked executable arguments = do
  (exitCode, _stdoutText, stderrText) <- readCreateProcessWithExitCode (proc executable arguments) ""
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure code ->
      ioError (userError (executable <> " failed with exit code " <> show code <> ": " <> stderrText))
