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

import Control.Monad
  ( filterM
  , when
  )
import Data.Aeson
  ( Value(..)
  , decode
  , encode
  , object
  , toJSON
  , (.=)
  )
import Data.Foldable (toList)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List
  ( (\\)
  , sortOn
  )
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  , mapMaybe
  , maybeToList
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Minecraft
  ( contentLoaderMetadata
  , preferredLoaderMetadata
  )
import Panino.Content.Online.Http
  ( coreRequest
  , fetchJson
  )
import Panino.Content.Online.Types
  ( ContentLoaderRequest(..)
  , LoaderMetadata(..)
  )
import Panino.Download.Manager
  ( DownloadJob(..)
  , DownloadOptions
  , DownloadProgress
  , DownloadSummary(..)
  , downloadOptionsWithConcurrency
  , runDownloadJobsWithOptionsAndProgressAndCancel
  , sha1HexFile
  , withDownloadConcurrency
  )
import Panino.Download.Transfer (throwIfCancelled)
import Panino.Minecraft.Install
  ( InstallResult(..)
  , installMinecraftInheritedProfileWithOptionsAndProgressAndCancel
  , installMinecraftVersionWithOptionsAndProgressAndCancel
  )
import Panino.Minecraft.InstallPlanGraph
  ( addLoaderProfileTypedPlan
  , addInstanceMetadataTypedPlan
  , combineInstallPlanGraphs
  , downloadJobsInstallPlanGraph
  , writeInstallPlanGraph
  )
import Panino.Minecraft.InstanceMetadata
  ( InstanceMetadata(..)
  , writeInstanceMetadata
  )
import Panino.Minecraft.LauncherProfiles
  ( ensureLauncherProfilesJson
  , launcherProfilesPath
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  , clientJarPath
  , versionJsonPath
  )
import Panino.Minecraft.LoaderInstall.Names
  ( normalizeLoaderName
  , normalizedLoaderTitle
  , normalizedShaderLoader
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
import Panino.Minecraft.Modrinth
  ( ModrinthFile(..)
  , ModrinthVersion(..)
  , ResolvedModrinthMod(..)
  , resolveModrinthProject
  , selectPreferredModrinthVersion
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getFileSize
  , listDirectory
  )
import System.Exit (ExitCode(..))
import System.FilePath
  ( takeDirectory
  , (</>)
  )
import System.Process (readProcessWithExitCode)

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
  loaderProfile <- installRequestedLoader manager layout minecraftVersion downloadOptions isCancelled onProgress (loaderInstallLoader options) (loaderInstallLoaderVersion options) (loaderInstallJavaExecutable options)
  throwIfCancelled isCancelled
  shaderResult <- installRequestedShader manager layout minecraftVersion (loaderInstallLoader options) (loaderInstallShaderLoader options) (loaderInstallShaderVersion options) downloadOptions isCancelled onProgress
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

data InstalledLoaderProfile = InstalledLoaderProfile
  { loaderProfileVersion :: Text
  , loaderProfileLoaderVersion :: Maybe Text
  , loaderProfileResult :: InstallResult
  } deriving (Eq, Show)

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

installMetaProfile :: Manager -> MinecraftLayout -> Text -> DownloadOptions -> IO Bool -> (DownloadProgress -> IO ()) -> Text -> Maybe Text -> IO InstalledLoaderProfile
installMetaProfile manager layout minecraftVersion downloadOptions isCancelled onProgress loader maybeLoaderVersion = do
  throwIfCancelled isCancelled
  metadata <- selectLoaderMetadata manager minecraftVersion loader maybeLoaderVersion
  let loaderVersion = loaderMetadataLoaderVersion metadata
  baseResult <- installMinecraftVersionWithOptionsAndProgressAndCancel manager layout minecraftVersion downloadOptions isCancelled onProgress
  throwIfCancelled isCancelled
  loaderProfileUrl <- requireProfileUrl loader minecraftVersion loaderVersion
  rawProfile <- fetchJson manager =<< coreRequest loaderProfileUrl []
  let profile = normalizeLoaderProfile loader minecraftVersion rawProfile
  throwIfCancelled isCancelled
  profileId <- requireProfileId profile
  let target = versionJsonPath layout profileId
  createDirectoryIfMissing True (takeDirectory target)
  BL.writeFile target (encode profile)
  throwIfCancelled isCancelled
  profileResult <-
    installMinecraftInheritedProfileWithOptionsAndProgressAndCancel
      manager
      layout
      minecraftVersion
      profileId
      downloadOptions
      isCancelled
      onProgress
  let result =
        profileResult
          { installDownloadSummary =
              mergeDownloadSummaries
                (installDownloadSummary baseResult)
                (installDownloadSummary profileResult)
          , installPlanGraph =
              combineInstallPlanGraphs
                "minecraft-profile"
                profileId
                [installPlanGraph baseResult, installPlanGraph profileResult]
          }
  pure (InstalledLoaderProfile profileId (Just loaderVersion) result)

requireProfileUrl :: Text -> Text -> Text -> IO String
requireProfileUrl "fabric" minecraftVersion loaderVersion =
  pure $
    "https://meta.fabricmc.net/v2/versions/loader/"
      <> Text.unpack minecraftVersion
      <> "/"
      <> Text.unpack loaderVersion
      <> "/profile/json"
requireProfileUrl "quilt" minecraftVersion loaderVersion =
  pure $
    "https://meta.quiltmc.org/v3/versions/loader/"
      <> Text.unpack minecraftVersion
      <> "/"
      <> Text.unpack loaderVersion
      <> "/profile/json"
requireProfileUrl loader _ _ =
  fail ("loader_profile_fetch_failed: profile JSON is not available for " <> Text.unpack loader)

normalizeLoaderProfile :: Text -> Text -> Value -> Value
normalizeLoaderProfile loader minecraftVersion profile
  | normalizeLoaderName loader `elem` ["fabric", "quilt"] =
      ensureIntermediaryLibrary minecraftVersion profile
  | otherwise = profile

ensureIntermediaryLibrary :: Text -> Value -> Value
ensureIntermediaryLibrary minecraftVersion (Object obj) =
  Object (KeyMap.insert (Key.fromString "libraries") nextLibraries obj)
  where
    libraries =
      case KeyMap.lookup (Key.fromString "libraries") obj of
        Just (Array values) -> toList values
        _ -> mempty
    hasIntermediary =
      any isIntermediaryLibrary libraries
    nextLibraries =
      toJSON $
        if hasIntermediary
          then libraries
          else libraries <> [intermediaryLibrary minecraftVersion]
ensureIntermediaryLibrary _ value = value

intermediaryLibrary :: Text -> Value
intermediaryLibrary minecraftVersion =
  object
    [ "name" .= ("net.fabricmc:intermediary:" <> minecraftVersion)
    , "url" .= ("https://maven.fabricmc.net/" :: Text)
    ]

isIntermediaryLibrary :: Value -> Bool
isIntermediaryLibrary (Object obj) =
  case KeyMap.lookup (Key.fromString "name") obj of
    Just (String name) -> "net.fabricmc:intermediary:" `Text.isPrefixOf` name
    _ -> False
isIntermediaryLibrary _ = False

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

selectLoaderMetadata :: Manager -> Text -> Text -> Maybe Text -> IO LoaderMetadata
selectLoaderMetadata manager minecraftVersion loader maybeLoaderVersion = do
  metadata <- contentLoaderMetadata manager (ContentLoaderRequest minecraftVersion)
  let matches =
        filter (\item -> normalizeLoaderName (loaderMetadataSource item) == normalizeLoaderName loader) metadata
      selected =
        case maybeLoaderVersion of
          Just requestedVersion -> findLoaderMetadataVersion requestedVersion matches
          Nothing -> preferredLoaderMetadata matches
  case maybeToList selected of
    item:_ -> pure item
    [] ->
      fail
        ( "loader_version_not_found: no "
            <> Text.unpack loader
            <> " loader metadata found for Minecraft "
            <> Text.unpack minecraftVersion
            <> maybe "" ((" version " <>) . Text.unpack) maybeLoaderVersion
        )

findLoaderMetadataVersion :: Text -> [LoaderMetadata] -> Maybe LoaderMetadata
findLoaderMetadataVersion requestedVersion =
  listToMaybe . filter ((== requestedVersion) . loaderMetadataLoaderVersion)

requireProfileId :: Value -> IO Text
requireProfileId (Object obj) =
  case KeyMap.lookup (Key.fromString "id") obj of
    Just (String value) -> pure value
    _ -> fail "loader profile JSON is missing id"
requireProfileId _ =
  fail "loader profile JSON must be an object"

mergeDownloadSummaries :: DownloadSummary -> DownloadSummary -> DownloadSummary
mergeDownloadSummaries lhs rhs =
  DownloadSummary
    { downloadedCount = downloadedCount lhs + downloadedCount rhs
    , skippedCount = skippedCount lhs + skippedCount rhs
    , totalCount = totalCount lhs + totalCount rhs
    }

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
