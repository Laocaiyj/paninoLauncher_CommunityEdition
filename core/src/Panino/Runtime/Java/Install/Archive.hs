{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Runtime.Java.Install.Archive
  ( archiveExtension
  , copyOrExtractImportSource
  , ensureSafeRuntimePath
  , extractArchive
  , findJavaExecutable
  , runProcessChecked
  , sanitizeRuntimeId
  , takeSafeSourceName
  , validateExtractedTree
  ) where

import Control.Monad
  ( filterM
  , when
  )
import Data.Char
  ( isAlphaNum
  , toLower
  )
import Data.List
  ( isPrefixOf
  , isSuffixOf
  , sortOn
  )
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.Exit (ExitCode(..))
import System.FilePath
  ( isAbsolute
  , normalise
  , splitDirectories
  , takeDirectory
  , takeFileName
  , (</>)
  )
import System.Posix.Files
  ( getSymbolicLinkStatus
  , isSymbolicLink
  , readSymbolicLink
  )
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )

copyOrExtractImportSource :: FilePath -> FilePath -> IO ()
copyOrExtractImportSource sourcePath staging = do
  sourceIsDirectory <- doesDirectoryExist sourcePath
  sourceIsFile <- doesFileExist sourcePath
  if sourceIsDirectory
    then runProcessChecked "/bin/cp" ["-R", sourcePath, staging] "java_runtime_extract_failed"
    else
      if sourceIsFile
        then extractArchive sourcePath staging
        else fail "java_runtime_missing: import source does not exist"

extractArchive :: FilePath -> FilePath -> IO ()
extractArchive archivePath staging
  | ".zip" `isSuffixOf` map toLower archivePath = do
      validateZipNames archivePath
      runProcessChecked "/usr/bin/unzip" ["-q", archivePath, "-d", staging] "java_runtime_extract_failed"
  | otherwise = do
      validateTarNames archivePath
      runProcessChecked "/usr/bin/tar" ["-xzf", archivePath, "-C", staging] "java_runtime_extract_failed"

archiveExtension :: Text -> Text
archiveExtension url
  | ".zip" `Text.isSuffixOf` lowered = ".zip"
  | otherwise = ".tar.gz"
  where
    lowered = Text.toLower url

ensureSafeRuntimePath :: FilePath -> IO ()
ensureSafeRuntimePath path =
  when (unsafeTarEntry path) $
    fail "java_runtime_extract_failed: runtime manifest contains unsafe paths"

validateTarNames :: FilePath -> IO ()
validateTarNames archivePath = do
  (_, stdoutText, _) <- runProcessCheckedCapture "/usr/bin/tar" ["-tzf", archivePath] "java_runtime_extract_failed"
  let entries = filter (not . null) (lines stdoutText)
  when (any unsafeTarEntry entries) $
    fail "java_runtime_extract_failed: archive contains unsafe paths"
  (_, verboseText, _) <- runProcessCheckedCapture "/usr/bin/tar" ["-tzvf", archivePath] "java_runtime_extract_failed"
  validateArchiveSymlinkTargets (mapMaybe tarSymlinkTarget (lines verboseText))

validateZipNames :: FilePath -> IO ()
validateZipNames archivePath = do
  (_, stdoutText, _) <- runProcessCheckedCapture "/usr/bin/unzip" ["-Z", "-1", archivePath] "java_runtime_extract_failed"
  let entries = filter (not . null) (lines stdoutText)
  when (any unsafeTarEntry entries) $
    fail "java_runtime_extract_failed: archive contains unsafe paths"
  (_, listingText, _) <- runProcessCheckedCapture "/usr/bin/unzip" ["-Z", "-l", archivePath] "java_runtime_extract_failed"
  targets <- traverse (zipSymlinkTarget archivePath) (mapMaybe zipSymlinkName (lines listingText))
  validateArchiveSymlinkTargets targets

validateArchiveSymlinkTargets :: [FilePath] -> IO ()
validateArchiveSymlinkTargets targets =
  when (any unsafeTarEntry targets) $
    fail "java_runtime_extract_failed: archive contains unsafe symlink"

tarSymlinkTarget :: String -> Maybe FilePath
tarSymlinkTarget line
  | "l" `isPrefixOf` line = trimStringLocal <$> arrowTarget line
  | otherwise = Nothing

arrowTarget :: String -> Maybe String
arrowTarget [] = Nothing
arrowTarget text@(_:rest)
  | " -> " `isPrefixOf` text = Just (drop 4 text)
  | otherwise = arrowTarget rest

zipSymlinkName :: String -> Maybe FilePath
zipSymlinkName line =
  case words line of
    permissions:_
      | "l" `isPrefixOf` permissions && length fields >= 10 ->
          Just (unwords (drop 9 fields))
    _ -> Nothing
  where
    fields = words line

zipSymlinkTarget :: FilePath -> FilePath -> IO FilePath
zipSymlinkTarget archivePath entry = do
  (_, stdoutText, _) <- runProcessCheckedCapture "/usr/bin/unzip" ["-p", archivePath, entry] "java_runtime_extract_failed"
  pure (trimStringLocal stdoutText)

unsafeTarEntry :: FilePath -> Bool
unsafeTarEntry path =
  isAbsolute path || any (== "..") (splitDirectories (normalise path))

trimStringLocal :: String -> String
trimStringLocal =
  Text.unpack . Text.strip . Text.pack

validateExtractedTree :: FilePath -> IO ()
validateExtractedTree root = do
  exists <- doesDirectoryExist root
  when exists $ do
    names <- sortOn id <$> listDirectory root
    mapM_ (validatePath . (root </>)) names
  where
    validatePath path = do
      status <- getSymbolicLinkStatus path
      let symlink = isSymbolicLink status
      when symlink $ do
        target <- readSymbolicLink path
        when (unsafeTarEntry target) $
          fail "java_runtime_extract_failed: archive contains unsafe symlink"
      isDir <- if symlink then pure False else doesDirectoryExist path
      when isDir $ do
        names <- sortOn id <$> listDirectory path
        mapM_ (validatePath . (path </>)) names

findJavaExecutable :: FilePath -> IO (Maybe FilePath)
findJavaExecutable root = do
  exists <- doesDirectoryExist root
  if not exists
    then pure Nothing
    else search root
  where
    search path = do
      names <- sortOn id <$> listDirectory path
      let direct = [path </> name | name <- names, name == "java" && "bin" `isSuffixOf` takeDirectory (path </> name)]
      foundFiles <- filterM doesFileExist direct
      case foundFiles of
        first:_ -> pure (Just first)
        [] -> do
          dirs <- filterM doesDirectoryExist [path </> name | name <- names]
          firstJust <$> traverse search dirs

firstJust :: [Maybe a] -> Maybe a
firstJust [] = Nothing
firstJust (Just value:_) = Just value
firstJust (Nothing:rest) = firstJust rest

runProcessChecked :: FilePath -> [String] -> String -> IO ()
runProcessChecked command args errorCode = do
  (exitCode, _, stderrText) <- readCreateProcessWithExitCode (proc command args) ""
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure _ -> fail (errorCode <> ": " <> stderrText)

runProcessCheckedCapture :: FilePath -> [String] -> String -> IO (ExitCode, String, String)
runProcessCheckedCapture command args errorCode = do
  result@(exitCode, _, stderrText) <- readCreateProcessWithExitCode (proc command args) ""
  case exitCode of
    ExitSuccess -> pure result
    ExitFailure _ -> fail (errorCode <> ": " <> stderrText)

sanitizeRuntimeId :: Text -> Text
sanitizeRuntimeId =
  Text.map sanitizeChar
  where
    sanitizeChar char
      | isAlphaNum char = char
      | char `elem` ("._-+" :: String) = char
      | otherwise = '-'

takeSafeSourceName :: FilePath -> String
takeSafeSourceName path =
  case takeFileName (normalise path) of
    "" -> "runtime"
    name -> name
