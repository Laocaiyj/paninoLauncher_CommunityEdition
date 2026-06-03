{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  , assetIndexPath
  , assetObjectPath
  , clientJarPath
  , defaultMinecraftRoot
  , ensureLayout
  , libraryPathFromDownload
  , mkLayout
  , nativesDir
  , versionJsonPath
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Minecraft.Types (DownloadInfo(..))
import System.Directory
  ( createDirectoryIfMissing
  , getHomeDirectory
  )
import System.FilePath ((</>))

data MinecraftLayout = MinecraftLayout
  { minecraftRoot :: FilePath
  , versionsDir :: FilePath
  , librariesDir :: FilePath
  , assetsDir :: FilePath
  , assetIndexesDir :: FilePath
  , assetObjectsDir :: FilePath
  , allNativesDir :: FilePath
  } deriving (Eq, Show)

mkLayout :: Maybe FilePath -> IO MinecraftLayout
mkLayout override = do
  root <- maybe defaultMinecraftRoot pure override
  pure MinecraftLayout
    { minecraftRoot = root
    , versionsDir = root </> "versions"
    , librariesDir = root </> "libraries"
    , assetsDir = root </> "assets"
    , assetIndexesDir = root </> "assets" </> "indexes"
    , assetObjectsDir = root </> "assets" </> "objects"
    , allNativesDir = root </> "natives"
    }

defaultMinecraftRoot :: IO FilePath
defaultMinecraftRoot = do
  home <- getHomeDirectory
  pure (home </> "Library" </> "Application Support" </> "Panino Launcher" </> "minecraft")

ensureLayout :: MinecraftLayout -> IO ()
ensureLayout layout = do
  createDirectoryIfMissing True (versionsDir layout)
  createDirectoryIfMissing True (librariesDir layout)
  createDirectoryIfMissing True (assetIndexesDir layout)
  createDirectoryIfMissing True (assetObjectsDir layout)
  createDirectoryIfMissing True (allNativesDir layout)
  createDirectoryIfMissing True (minecraftRoot layout </> "saves")
  createDirectoryIfMissing True (minecraftRoot layout </> "mods")
  createDirectoryIfMissing True (minecraftRoot layout </> "resourcepacks")
  createDirectoryIfMissing True (minecraftRoot layout </> "shaderpacks")
  createDirectoryIfMissing True (minecraftRoot layout </> "logs")
  createDirectoryIfMissing True (minecraftRoot layout </> "downloads")

versionJsonPath :: MinecraftLayout -> Text -> FilePath
versionJsonPath layout version =
  versionsDir layout </> Text.unpack version </> Text.unpack version <> ".json"

clientJarPath :: MinecraftLayout -> Text -> FilePath
clientJarPath layout version =
  versionsDir layout </> Text.unpack version </> Text.unpack version <> ".jar"

libraryPathFromDownload :: MinecraftLayout -> DownloadInfo -> Maybe FilePath
libraryPathFromDownload layout info =
  fmap ((librariesDir layout </>) . normaliseManifestPath) (downloadPath info)

assetIndexPath :: MinecraftLayout -> Text -> FilePath
assetIndexPath layout indexId =
  assetIndexesDir layout </> Text.unpack indexId <> ".json"

assetObjectPath :: MinecraftLayout -> Text -> FilePath
assetObjectPath layout hashText =
  assetObjectsDir layout </> prefix </> Text.unpack hashText
  where
    prefix = Text.unpack (Text.take 2 hashText)

nativesDir :: MinecraftLayout -> Text -> FilePath
nativesDir layout version =
  allNativesDir layout </> Text.unpack version

normaliseManifestPath :: FilePath -> FilePath
normaliseManifestPath = fmap slash
  where
    slash '/' = '/'
    slash char = char
