{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Content.Local.Path
  ( enabledPath
  , lowerFileName
  , lowerText
  , movePathToTrash
  , nonEmptyOr
  , removePathIfExists
  , resourceFolderName
  , supportedResourceFile
  , trimString
  ) where

import Control.Monad (unless)
import Data.Char (toLower)
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , doesPathExist
  , getHomeDirectory
  , removeDirectoryRecursive
  , removeFile
  , renameDirectory
  , renameFile
  )
import System.FilePath
  ( dropExtension
  , takeExtension
  , takeFileName
  , (</>)
  )

resourceFolderName :: Text -> FilePath
resourceFolderName kind
  | kind == "mods" = "mods"
  | kind == "resourcePacks" = "resourcepacks"
  | kind == "shaderPacks" = "shaderpacks"
  | otherwise = Text.unpack kind

supportedResourceFile :: FilePath -> Bool
supportedResourceFile name =
  takeExtension name `elem` [".jar", ".zip"]
    || (takeExtension name == ".disabled" && takeExtension (dropExtension name) `elem` [".jar", ".zip"])

enabledPath :: FilePath -> FilePath
enabledPath path =
  if takeExtension path == ".disabled"
    then dropExtension path
    else path

movePathToTrash :: FilePath -> IO (Bool, Maybe FilePath)
movePathToTrash path = do
  exists <- doesPathExist path
  if not exists
    then pure (False, Nothing)
    else do
      home <- getHomeDirectory
      let trash = home </> ".Trash"
      createDirectoryIfMissing True trash
      target <- uniqueTrashPath trash (takeFileName path) 0
      movePath path target
      pure (True, Just target)

movePath :: FilePath -> FilePath -> IO ()
movePath source target = do
  isDirectory <- doesDirectoryExist source
  if isDirectory
    then renameDirectory source target
    else renameFile source target

uniqueTrashPath :: FilePath -> FilePath -> Int -> IO FilePath
uniqueTrashPath trash name attempt = do
  let candidate =
        trash
          </> if attempt == 0
            then name
            else dropExtension name <> " " <> show attempt <> takeExtension name
  exists <- doesPathExist candidate
  if exists
    then uniqueTrashPath trash name (attempt + 1)
    else pure candidate

removePathIfExists :: FilePath -> IO ()
removePathIfExists path = do
  isDirectory <- doesDirectoryExist path
  isFile <- doesFileExist path
  if isDirectory
    then removeDirectoryRecursive path
    else unless (not isFile) (removeFile path)

lowerFileName :: FilePath -> FilePath
lowerFileName =
  map toLower . takeFileName

lowerText :: Text -> String
lowerText =
  map toLower . Text.unpack

trimString :: String -> String
trimString =
  Text.unpack . Text.strip . Text.pack

nonEmptyOr :: String -> String -> String
nonEmptyOr fallback value =
  if null value then fallback else value
