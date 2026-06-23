{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.LoaderInstall.Types
  ( InstalledLoaderProfile(..)
  , LoaderInstallOptions(..)
  , LoaderInstallResult(..)
  ) where

import Data.Text (Text)
import Panino.Minecraft.Install (InstallResult)
import Panino.Minecraft.InstanceMetadata (InstanceMetadata)

data LoaderInstallOptions = LoaderInstallOptions
  { loaderInstallLoader :: Maybe Text
  , loaderInstallLoaderVersion :: Maybe Text
  , loaderInstallShaderLoader :: Maybe Text
  , loaderInstallShaderVersion :: Maybe Text
  , loaderInstallInstanceName :: Maybe Text
  , loaderInstallJavaExecutable :: Maybe FilePath
  , loaderInstallExpectedProfileId :: Maybe Text
  } deriving (Eq, Show)

data LoaderInstallResult = LoaderInstallResult
  { loaderInstallResult :: InstallResult
  , loaderInstallProfileVersion :: Text
  , loaderInstallMetadata :: InstanceMetadata
  } deriving (Eq, Show)

data InstalledLoaderProfile = InstalledLoaderProfile
  { loaderProfileVersion :: Text
  , loaderProfileLoaderVersion :: Maybe Text
  , loaderProfileResult :: InstallResult
  } deriving (Eq, Show)
