{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.LoaderInstall
  ( LoaderInstallOptions(..)
  , LoaderInstallResult(..)
  , ModrinthFile(..)
  , ModrinthVersion(..)
  , ResolvedModrinthMod(..)
  , ShaderResolution(..)
  , ShaderInstallResult(..)
  , emptyShaderInstallResult
  , installMinecraftProfile
  , installMinecraftProfileWithOptions
  , installMinecraftProfileWithOptionsAndProgress
  , installMinecraftProfileWithOptionsAndProgressAndCancel
  , installMinecraftProfileWithProgress
  , installMinecraftProfileWithProgressAndCancel
  , modrinthDownloadJob
  , normalizeLoaderName
  , postVerifyInstall
  , removeTrackedShaderInstallFiles
  , resolveModrinthProject
  , resolveShaderModrinthProject
  , selectPreferredModrinthVersion
  ) where

import Data.Text (Text)
import Network.HTTP.Client (Manager)
import Panino.Download.Manager
  ( DownloadOptions
  , DownloadProgress
  , downloadOptionsWithConcurrency
  )
import Panino.Download.Transfer (throwIfCancelled)
import Panino.Minecraft.Install (InstallResult(..))
import Panino.Minecraft.InstallPlanGraph
  ( addInstanceMetadataTypedPlan
  , addLoaderProfileTypedPlan
  , combineInstallPlanGraphs
  , writeInstallPlanGraph
  )
import Panino.Minecraft.InstanceMetadata
  ( InstanceMetadata(..)
  , writeInstanceMetadata
  )
import Panino.Minecraft.Layout (MinecraftLayout(..))
import Panino.Minecraft.LoaderInstall.Names
  ( normalizeLoaderName
  , normalizedLoaderTitle
  , normalizedShaderLoader
  )
import Panino.Minecraft.LoaderInstall.Profile
  ( installRequestedLoader
  , mergeDownloadSummaries
  )
import Panino.Minecraft.LoaderInstall.Shader
  ( ShaderInstallResult(..)
  , ShaderResolution(..)
  , emptyShaderInstallResult
  , installRequestedShader
  , modrinthDownloadJob
  , removeTrackedShaderInstallFiles
  , resolveShaderModrinthProject
  , validateRequestedShaderCompatibility
  )
import Panino.Minecraft.LoaderInstall.Types
  ( InstalledLoaderProfile(..)
  , LoaderInstallOptions(..)
  , LoaderInstallResult(..)
  )
import Panino.Minecraft.LoaderInstall.Verify
  ( installProfilePlanGraphPath
  , postVerifyInstall
  )
import Panino.Minecraft.Modrinth
  ( ModrinthFile(..)
  , ModrinthVersion(..)
  , ResolvedModrinthMod(..)
  , resolveModrinthProject
  , selectPreferredModrinthVersion
  )

installMinecraftProfile :: Manager -> MinecraftLayout -> Text -> Int -> LoaderInstallOptions -> IO LoaderInstallResult
installMinecraftProfile manager layout minecraftVersion concurrency =
  installMinecraftProfileWithProgress manager layout minecraftVersion concurrency (\_ -> pure ())

installMinecraftProfileWithProgress :: Manager -> MinecraftLayout -> Text -> Int -> (DownloadProgress -> IO ()) -> LoaderInstallOptions -> IO LoaderInstallResult
installMinecraftProfileWithProgress manager layout minecraftVersion concurrency onProgress =
  installMinecraftProfileWithProgressAndCancel manager layout minecraftVersion concurrency (pure False) onProgress

installMinecraftProfileWithProgressAndCancel :: Manager -> MinecraftLayout -> Text -> Int -> IO Bool -> (DownloadProgress -> IO ()) -> LoaderInstallOptions -> IO LoaderInstallResult
installMinecraftProfileWithProgressAndCancel manager layout minecraftVersion concurrency =
  installMinecraftProfileWithOptionsAndProgressAndCancel manager layout minecraftVersion (downloadOptionsWithConcurrency concurrency)

installMinecraftProfileWithOptions :: Manager -> MinecraftLayout -> Text -> DownloadOptions -> LoaderInstallOptions -> IO LoaderInstallResult
installMinecraftProfileWithOptions manager layout minecraftVersion downloadOptions =
  installMinecraftProfileWithOptionsAndProgress manager layout minecraftVersion downloadOptions (\_ -> pure ())

installMinecraftProfileWithOptionsAndProgress :: Manager -> MinecraftLayout -> Text -> DownloadOptions -> (DownloadProgress -> IO ()) -> LoaderInstallOptions -> IO LoaderInstallResult
installMinecraftProfileWithOptionsAndProgress manager layout minecraftVersion downloadOptions onProgress =
  installMinecraftProfileWithOptionsAndProgressAndCancel manager layout minecraftVersion downloadOptions (pure False) onProgress

installMinecraftProfileWithOptionsAndProgressAndCancel :: Manager -> MinecraftLayout -> Text -> DownloadOptions -> IO Bool -> (DownloadProgress -> IO ()) -> LoaderInstallOptions -> IO LoaderInstallResult
installMinecraftProfileWithOptionsAndProgressAndCancel manager layout minecraftVersion downloadOptions isCancelled onProgress options = do
  throwIfCancelled isCancelled
  validateRequestedShaderCompatibility (loaderInstallLoader options) (loaderInstallShaderLoader options)
  loaderProfile <-
    installRequestedLoader
      manager
      layout
      minecraftVersion
      downloadOptions
      isCancelled
      onProgress
      (loaderInstallLoader options)
      (loaderInstallLoaderVersion options)
      (loaderInstallJavaExecutable options)
  throwIfCancelled isCancelled
  shaderResult <-
    installRequestedShader
      manager
      layout
      minecraftVersion
      (loaderInstallLoader options)
      (loaderInstallShaderLoader options)
      (loaderInstallShaderVersion options)
      downloadOptions
      isCancelled
      onProgress
  throwIfCancelled isCancelled
  let launchVersion = loaderProfileVersion loaderProfile
      loaderVersion = loaderProfileLoaderVersion loaderProfile
      baseResult = loaderProfileResult loaderProfile
      baseGraph =
        addLoaderProfileTypedPlan
          layout
          launchVersion
          loaderVersion
          (installPlanGraph baseResult)
      combinedGraph =
        case shaderInstallGraph shaderResult of
          Nothing -> baseGraph
          Just shaderGraph ->
            combineInstallPlanGraphs
              "minecraft-profile"
              launchVersion
              [baseGraph, shaderGraph]
      finalGraph =
        addInstanceMetadataTypedPlan layout combinedGraph
      result =
        baseResult
          { installDownloadSummary =
              mergeDownloadSummaries
                (installDownloadSummary baseResult)
                (shaderInstallSummary shaderResult)
          , installPlanGraph = finalGraph
          }
      metadata =
        InstanceMetadata
          { metadataName = loaderInstallInstanceName options
          , metadataMinecraftVersion = minecraftVersion
          , metadataLaunchVersion = launchVersion
          , metadataLoader = normalizedLoaderTitle <$> loaderInstallLoader options
          , metadataLoaderVersion = loaderVersion
          , metadataShaderLoader = normalizedShaderLoader (loaderInstallShaderLoader options)
          }
  throwIfCancelled isCancelled
  postVerifyInstall layout minecraftVersion launchVersion (loaderInstallExpectedProfileId options) result shaderResult
  throwIfCancelled isCancelled
  writeInstallPlanGraph (installProfilePlanGraphPath layout) finalGraph
  writeInstanceMetadata (minecraftRoot layout) metadata
  pure
    LoaderInstallResult
      { loaderInstallResult = result
      , loaderInstallProfileVersion = launchVersion
      , loaderInstallMetadata = metadata
      }
