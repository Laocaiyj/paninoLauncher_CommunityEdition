{-# LANGUAGE OverloadedStrings #-}

module Integration.MinecraftInstall
  ( assertInstallMissingClientDownload
  , assertInstallPostVerifyMissingClientJar
  ) where

import Control.Exception
  ( SomeException
  , finally
  , try
  )
import Control.Monad (when)
import Data.Aeson
  ( Value
  , decode
  )
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List (isInfixOf)
import Integration.LoaderShaderFixtureServer (fakeLoaderShaderPreflightApp)
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.Download.Manager
  ( DownloadSummary(..)
  , downloadOptionsWithOverrides
  )
import Panino.Minecraft.Install
  ( InstallResult(..)
  , installMinecraftVersionWithOptionsAndProgressAndCancel
  , resolveVersionSummaryJson
  )
import Panino.Minecraft.InstallPlanGraph (downloadJobsInstallPlanGraph)
import Panino.Minecraft.Layout
  ( mkLayout
  , versionJsonPath
  )
import Panino.Minecraft.LoaderInstall
  ( emptyShaderInstallResult
  , postVerifyInstall
  )
import Panino.Minecraft.Types
  ( DownloadInfo(..)
  , VersionJson(..)
  )
import Panino.Net.Http (makeHttpManager)
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , getTemporaryDirectory
  , removeDirectoryRecursive
  )
import System.Environment
  ( setEnv
  , unsetEnv
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  )
import TestFixtures (testVersionJson)
import TestSupport
  ( assertEqual
  , catchAny
  )

assertInstallMissingClientDownload :: IO ()
assertInstallMissingClientDownload = do
  assertEqual "version summary tolerates missing client download" True (isJustVersionSummary testVersionJson)
  manager <- makeHttpManager
  tempDir <- getTemporaryDirectory
  testWithApplication (pure fakeLoaderShaderPreflightApp) $ \port -> do
    let base = "http://127.0.0.1:" <> show port
        withSources action =
          ( do
              setEnv "PANINO_MOJANG_META_BASE" base
              setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
              action
          )
            `finally` do
              unsetEnv "PANINO_MOJANG_META_BASE"
              unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
    withSources $ do
      let root = tempDir </> "panino-install-missing-client-download"
      exists <- doesDirectoryExist root
      when exists (removeDirectoryRecursive root `catchAny` \_ -> pure ())
      layout <- mkLayout (Just root)
      result <-
        try
          ( installMinecraftVersionWithOptionsAndProgressAndCancel
              manager
              layout
              "missing-client"
              (downloadOptionsWithOverrides (Just 1) (Just 0))
              (pure False)
              (\_ -> pure ())
          ) :: IO (Either SomeException InstallResult)
      case result of
        Left err ->
          assertEqual "missing client download reports manifest parse failure" True ("manifest_parse_failed: version JSON is missing downloads.client for missing-client" `isInfixOf` show err)
        Right _ ->
          assertEqual "install should fail when downloads.client is missing" True False

isJustVersionSummary :: VersionJson -> Bool
isJustVersionSummary versionJson =
  case decode (resolveVersionSummaryJson versionJson) :: Maybe Value of
    Just _ -> True
    Nothing -> False

assertInstallPostVerifyMissingClientJar :: IO ()
assertInstallPostVerifyMissingClientJar = do
  tempDir <- getTemporaryDirectory
  let root = tempDir </> "panino-post-verify-missing-client"
      fixtureLaunchVersion = "fabric-loader-0.16.0-26.1.2"
  exists <- doesDirectoryExist root
  when exists (removeDirectoryRecursive root `catchAny` \_ -> pure ())
  layout <- mkLayout (Just root)
  createDirectoryIfMissing True (takeDirectory (versionJsonPath layout fixtureLaunchVersion))
  BL8.writeFile (versionJsonPath layout fixtureLaunchVersion) "{}"
  let result =
        InstallResult
          { installVersionJson =
              VersionJson
                { versionId = fixtureLaunchVersion
                , versionType = Nothing
                , versionJavaVersion = Nothing
                , versionDownloads = mempty
                , versionAssetIndex = DownloadInfo Nothing Nothing Nothing Nothing Nothing
                , versionLibraries = []
                , versionMainClass = "net.minecraft.client.main.Main"
                , versionArguments = Nothing
                , versionMinecraftArguments = Nothing
                }
          , installClasspathJars = []
          , installNativeArchives = []
          , installDownloadSummary = DownloadSummary 0 0 0
          , installPlanGraph = downloadJobsInstallPlanGraph "minecraft" "post-verify" []
      }
  verifyResult <-
    try
      (postVerifyInstall layout "26.1.2" fixtureLaunchVersion Nothing result emptyShaderInstallResult)
        :: IO (Either SomeException ())
  case verifyResult of
    Left err ->
      assertEqual "post-verify missing client jar has stable error" True ("install_post_verify_failed: missing client jar" `isInfixOf` show err)
    Right () ->
      assertEqual "post-verify should fail when client jar is missing" True False
