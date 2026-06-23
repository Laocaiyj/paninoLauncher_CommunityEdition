{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.LoaderInstall.Verify
  ( installProfilePlanGraphPath
  , postVerifyInstall
  ) where

import Control.Monad
  ( filterM
  , when
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Download.Manager
  ( DownloadJob(..)
  , sha1HexFile
  )
import Panino.Minecraft.Install (InstallResult(..))
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  , clientJarPath
  , versionJsonPath
  )
import Panino.Minecraft.LoaderInstall.Shader (ShaderInstallResult(..))
import System.Directory
  ( doesFileExist
  , getFileSize
  )
import System.FilePath ((</>))

installProfilePlanGraphPath :: MinecraftLayout -> FilePath
installProfilePlanGraphPath layout =
  minecraftRoot layout </> "downloads" </> "install-plan-graph.json"

postVerifyInstall :: MinecraftLayout -> Text -> Text -> Maybe Text -> InstallResult -> ShaderInstallResult -> IO ()
postVerifyInstall layout minecraftVersion launchVersion expectedProfileId result shaderResult = do
  case expectedProfileId of
    Just expected | expected /= launchVersion ->
      fail
        ( "install_post_verify_failed: installed profile "
            <> Text.unpack launchVersion
            <> " does not match preflight profile "
            <> Text.unpack expected
        )
    _ -> pure ()
  versionJsonExists <- doesFileExist (versionJsonPath layout launchVersion)
  when (not versionJsonExists) $
    fail ("install_post_verify_failed: missing version profile " <> versionJsonPath layout launchVersion)
  let expectedClientJar =
        if launchVersion == minecraftVersion
          then clientJarPath layout launchVersion
          else clientJarPath layout minecraftVersion
  clientJarExists <- doesFileExist expectedClientJar
  when (not clientJarExists) $
    fail ("install_post_verify_failed: missing client jar " <> expectedClientJar)
  missingLibraries <- filterM (fmap not . doesFileExist) (installClasspathJars result)
  when (not (null missingLibraries)) $
    fail ("install_post_verify_failed: missing libraries " <> unwords (take 5 missingLibraries))
  mapM_ verifyShaderFile (shaderInstallFiles shaderResult)

verifyShaderFile :: DownloadJob -> IO ()
verifyShaderFile job = do
  let path = jobTargetPath job
  exists <- doesFileExist path
  when (not exists) $
    fail ("install_post_verify_failed: missing shader file " <> path)
  case jobSize job of
    Nothing -> pure ()
    Just expected -> do
      actual <- getFileSize path
      when (actual /= toInteger expected) $
        fail ("install_post_verify_failed: shader file size mismatch " <> path)
  case jobSha1 job of
    Nothing -> pure ()
    Just expected -> do
      actual <- sha1HexFile path
      when (actual /= Text.toLower expected) $
        fail ("install_post_verify_failed: shader file sha1 mismatch " <> path)
