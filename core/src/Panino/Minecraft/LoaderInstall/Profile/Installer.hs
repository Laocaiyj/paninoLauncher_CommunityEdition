{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.LoaderInstall.Profile.Installer
  ( installInstallerProfile
  ) where

import Control.Monad (filterM)
import Data.Aeson
  ( Value(..)
  , decode
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as BL
import Data.Foldable (toList)
import Data.List
  ( (\\)
  , sortOn
  )
import Data.Maybe
  ( fromMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Types (LoaderMetadata(..))
import Panino.Download.Manager
  ( DownloadJob(..)
  , DownloadOptions
  , DownloadProgress
  , runDownloadJobsWithOptionsAndProgressAndCancel
  , withDownloadConcurrency
  )
import Panino.Download.Transfer (throwIfCancelled)
import Panino.Minecraft.Install
  ( InstallResult(..)
  , installMinecraftVersionWithOptionsAndProgressAndCancel
  )
import Panino.Minecraft.InstallPlanGraph
  ( combineInstallPlanGraphs
  , downloadJobsInstallPlanGraph
  )
import Panino.Minecraft.LauncherProfiles
  ( ensureLauncherProfilesJson
  , launcherProfilesPath
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  , versionJsonPath
  )
import Panino.Minecraft.LoaderInstall.Names (normalizeLoaderName)
import Panino.Minecraft.LoaderInstall.Profile.Common
  ( mergeDownloadSummaries
  , selectLoaderMetadata
  )
import Panino.Minecraft.LoaderInstall.Types (InstalledLoaderProfile(..))
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)

installInstallerProfile :: Manager -> MinecraftLayout -> Text -> DownloadOptions -> IO Bool -> (DownloadProgress -> IO ()) -> Text -> Maybe Text -> Maybe FilePath -> IO InstalledLoaderProfile
installInstallerProfile manager layout minecraftVersion downloadOptions isCancelled onProgress loader maybeLoaderVersion javaExecutable = do
  throwIfCancelled isCancelled
  metadata <- selectLoaderMetadata manager minecraftVersion loader maybeLoaderVersion
  let loaderVersion = loaderMetadataLoaderVersion metadata
  baseResult <- installMinecraftVersionWithOptionsAndProgressAndCancel manager layout minecraftVersion downloadOptions isCancelled onProgress
  throwIfCancelled isCancelled
  before <- installedProfileIds layout
  installerDownloadUrl <- requireInstallerUrl loader minecraftVersion loaderVersion
  let installerPath = minecraftRoot layout </> "downloads" </> Text.unpack loader <> "-" <> Text.unpack minecraftVersion <> "-" <> Text.unpack loaderVersion <> "-installer.jar"
      installerJobs =
        [ DownloadJob
            { jobLabel = Text.unpack loader <> " installer"
            , jobUrl = installerDownloadUrl
            , jobTargetPath = installerPath
            , jobSha1 = Nothing
            , jobSize = Nothing
            }
        ]
      installerGraph = downloadJobsInstallPlanGraph "minecraft-loader-installer" (loader <> "-" <> minecraftVersion) installerJobs
  installerSummary <-
    runDownloadJobsWithOptionsAndProgressAndCancel
      manager
      (withDownloadConcurrency 1 downloadOptions)
      isCancelled
      installerJobs
      onProgress
  throwIfCancelled isCancelled
  runJavaInstaller (fromMaybe "java" javaExecutable) layout minecraftVersion installerPath
  throwIfCancelled isCancelled
  after <- installedProfileIds layout
  appendInstallerProfileDiff layout before after
  profileId <- selectInstalledProfile layout loader minecraftVersion loaderVersion before after
  profileResult <- installMinecraftVersionWithOptionsAndProgressAndCancel manager layout profileId downloadOptions isCancelled onProgress
  let result =
        profileResult
          { installDownloadSummary =
              mergeDownloadSummaries
                (installDownloadSummary baseResult)
                (mergeDownloadSummaries installerSummary (installDownloadSummary profileResult))
          , installPlanGraph =
              combineInstallPlanGraphs
                "minecraft-installer-profile"
                profileId
                [installPlanGraph baseResult, installerGraph, installPlanGraph profileResult]
          }
  pure (InstalledLoaderProfile profileId (Just loaderVersion) result)

requireInstallerUrl :: Text -> Text -> Text -> IO String
requireInstallerUrl "forge" minecraftVersion loaderVersion =
  let artifactVersion = minecraftVersion <> "-" <> loaderVersion
   in pure $
        "https://maven.minecraftforge.net/net/minecraftforge/forge/"
          <> Text.unpack artifactVersion
          <> "/forge-"
          <> Text.unpack artifactVersion
          <> "-installer.jar"
requireInstallerUrl "neoforge" _ loaderVersion =
  pure $
    "https://maven.neoforged.net/releases/net/neoforged/neoforge/"
      <> Text.unpack loaderVersion
      <> "/neoforge-"
      <> Text.unpack loaderVersion
      <> "-installer.jar"
requireInstallerUrl loader _ _ =
  fail ("loader_installer_download_failed: installer URL is not available for " <> Text.unpack loader)

runJavaInstaller :: FilePath -> MinecraftLayout -> Text -> FilePath -> IO ()
runJavaInstaller javaExecutable layout minecraftVersion installerPath = do
  createDirectoryIfMissing True (minecraftRoot layout </> "downloads")
  ensureLauncherProfilesJson layout minecraftVersion
  (exitCode, stdoutText, stderrText) <-
    readProcessWithExitCode
      javaExecutable
      ["-jar", installerPath, "--installClient", minecraftRoot layout]
      ""
  writeFile
    (minecraftRoot layout </> "downloads" </> "loader-install.log")
    ( unlines
        [ "installer=" <> installerPath
        , "java=" <> javaExecutable
        , "target=" <> minecraftRoot layout
        , "launcherProfiles=" <> launcherProfilesPath layout
        , "exit=" <> show exitCode
        , "stdout:"
        , stdoutText
        , "stderr:"
        , stderrText
        ]
    )
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure code ->
      fail (Text.unpack (installerFailureDetail code stdoutText stderrText))

installerFailureDetail :: Int -> String -> String -> Text
installerFailureDetail code stdoutText stderrText =
  Text.strip $
    Text.unlines
      [ "loader_installer_exit_failed: loader installer failed with code " <> Text.pack (show code)
      , "stdout:"
      , textTailLines 20 (Text.pack stdoutText)
      , "stderr:"
      , textTailLines 20 (Text.pack stderrText)
      ]

textTailLines :: Int -> Text -> Text
textTailLines count value =
  Text.unlines (drop (max 0 (length linesValue - count)) linesValue)
  where
    linesValue = Text.lines value

selectInstalledProfile :: MinecraftLayout -> Text -> Text -> Text -> [Text] -> [Text] -> IO Text
selectInstalledProfile layout loader minecraftVersion loaderVersion before after = do
  validProfiles <- filterM (installerProfileMatches layout loader minecraftVersion loaderVersion) (newProfiles <> after)
  case validProfiles of
    profile:_ -> pure profile
    [] ->
      fail
        ( "loader_profile_not_created: loader installer did not create a launch profile for "
            <> Text.unpack loader
            <> " "
            <> Text.unpack minecraftVersion
            <> " "
            <> Text.unpack loaderVersion
        )
  where
    newProfiles = after \\ before

installerProfileMatches :: MinecraftLayout -> Text -> Text -> Text -> Text -> IO Bool
installerProfileMatches layout loader minecraftVersion loaderVersion profile = do
  let path = versionJsonPath layout profile
  exists <- doesFileExist path
  if not exists
    then pure False
    else do
      decoded <- decode <$> BL.readFile path
      pure $
        case decoded of
          Just value -> installerProfileValueMatches loader minecraftVersion loaderVersion profile value
          Nothing -> False

installerProfileValueMatches :: Text -> Text -> Text -> Text -> Value -> Bool
installerProfileValueMatches loader minecraftVersion loaderVersion profile value =
  profileIdIsConsistent profile value
    && inheritsFromIsCompatible minecraftVersion value
    && loaderMatchesText loader profile
    && (minecraftMatchesText minecraftVersion profile || loaderVersionMatchesText loaderVersion profile)
    && loaderMatchesProfileValue loader value
    && versionMatchesProfileValue minecraftVersion loaderVersion profile value

profileIdIsConsistent :: Text -> Value -> Bool
profileIdIsConsistent profile value =
  case profileIdText value of
    [] -> True
    values -> profile `elem` values

inheritsFromIsCompatible :: Text -> Value -> Bool
inheritsFromIsCompatible minecraftVersion value =
  case inheritsFromText value of
    [] -> True
    values -> minecraftVersion `elem` values

loaderMatchesProfileValue :: Text -> Value -> Bool
loaderMatchesProfileValue loader value =
  any (loaderMatchesText loader) (profileIdText value <> libraryNamesFromValue value)

versionMatchesProfileValue :: Text -> Text -> Text -> Value -> Bool
versionMatchesProfileValue minecraftVersion loaderVersion profile value =
  any (minecraftMatchesText minecraftVersion) searchable
    || any (loaderVersionMatchesText loaderVersion) searchable
  where
    searchable = profile : profileIdText value <> inheritsFromText value <> libraryNamesFromValue value

profileIdText :: Value -> [Text]
profileIdText (Object obj) =
  case KeyMap.lookup (Key.fromString "id") obj of
    Just (String value) -> [value]
    _ -> []
profileIdText _ = []

inheritsFromText :: Value -> [Text]
inheritsFromText (Object obj) =
  case KeyMap.lookup (Key.fromString "inheritsFrom") obj of
    Just (String value) -> [value]
    _ -> []
inheritsFromText _ = []

libraryNamesFromValue :: Value -> [Text]
libraryNamesFromValue (Object obj) =
  case KeyMap.lookup (Key.fromString "libraries") obj of
    Just (Array values) -> mapMaybe libraryName (toList values)
    _ -> []
  where
    libraryName (Object libraryObj) =
      case KeyMap.lookup (Key.fromString "name") libraryObj of
        Just (String name) -> Just name
        _ -> Nothing
    libraryName _ = Nothing
libraryNamesFromValue _ = []

loaderMatchesText :: Text -> Text -> Bool
loaderMatchesText loader value =
  normalizeLoaderName loader `Text.isInfixOf` normalizeLoaderName value

minecraftMatchesText :: Text -> Text -> Bool
minecraftMatchesText minecraftVersion value =
  Text.toLower minecraftVersion `Text.isInfixOf` Text.toLower value

loaderVersionMatchesText :: Text -> Text -> Bool
loaderVersionMatchesText loaderVersion value =
  Text.toLower loaderVersion `Text.isInfixOf` Text.toLower value

installedProfileIds :: MinecraftLayout -> IO [Text]
installedProfileIds layout = do
  exists <- doesDirectoryExist (versionsDir layout)
  if not exists
    then pure []
    else do
      entries <- sortOn id <$> listDirectory (versionsDir layout)
      fmap concat $
        traverse profileId entries
  where
    profileId entry = do
      let version = Text.pack entry
          jsonPath = versionJsonPath layout version
      exists <- doesFileExist jsonPath
      pure [version | exists]

appendInstallerProfileDiff :: MinecraftLayout -> [Text] -> [Text] -> IO ()
appendInstallerProfileDiff layout before after = do
  createDirectoryIfMissing True (minecraftRoot layout </> "downloads")
  appendFile
    (minecraftRoot layout </> "downloads" </> "loader-install.log")
    ( unlines
        [ "profilesBefore=" <> Text.unpack (Text.intercalate "," before)
        , "profilesAfter=" <> Text.unpack (Text.intercalate "," after)
        , "profilesCreated=" <> Text.unpack (Text.intercalate "," (after \\ before))
        ]
    )
