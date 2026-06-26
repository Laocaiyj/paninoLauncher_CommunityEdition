{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.LoaderInstall.Profile
  ( installRequestedLoader
  , mergeDownloadSummaries
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Download.Manager
  ( DownloadOptions
  , DownloadProgress
  )
import Panino.Minecraft.Install (installMinecraftVersionWithOptionsAndProgressAndCancel)
import Panino.Minecraft.Layout (MinecraftLayout)
import Panino.Minecraft.LoaderInstall.Names (normalizeLoaderName)
import Panino.Minecraft.LoaderInstall.Profile.Common (mergeDownloadSummaries)
import Panino.Minecraft.LoaderInstall.Profile.Installer (installInstallerProfile)
import Panino.Minecraft.LoaderInstall.Profile.Meta (installMetaProfile)
import Panino.Minecraft.LoaderInstall.Types (InstalledLoaderProfile(..))

installRequestedLoader :: Manager -> MinecraftLayout -> Text -> DownloadOptions -> IO Bool -> (DownloadProgress -> IO ()) -> Maybe Text -> Maybe Text -> Maybe FilePath -> IO InstalledLoaderProfile
installRequestedLoader manager layout minecraftVersion downloadOptions isCancelled onProgress maybeLoader maybeLoaderVersion javaExecutable =
  case normalizeLoaderName <$> maybeLoader of
    Nothing -> do
      result <- installMinecraftVersionWithOptionsAndProgressAndCancel manager layout minecraftVersion downloadOptions isCancelled onProgress
      pure (InstalledLoaderProfile minecraftVersion Nothing result)
    Just "fabric" -> installMetaProfile manager layout minecraftVersion downloadOptions isCancelled onProgress "fabric" maybeLoaderVersion
    Just "quilt" -> installMetaProfile manager layout minecraftVersion downloadOptions isCancelled onProgress "quilt" maybeLoaderVersion
    Just "forge" -> installInstallerProfile manager layout minecraftVersion downloadOptions isCancelled onProgress "forge" maybeLoaderVersion javaExecutable
    Just "neoforge" -> installInstallerProfile manager layout minecraftVersion downloadOptions isCancelled onProgress "neoforge" maybeLoaderVersion javaExecutable
    Just other -> fail ("unsupported loader: " <> Text.unpack other)
