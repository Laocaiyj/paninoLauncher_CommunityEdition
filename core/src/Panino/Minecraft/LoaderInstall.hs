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

import Control.Exception
  ( SomeException
  , catch
  , displayException
  , throwIO
  , try
  )
import Control.Monad
  ( filterM
  , forM_
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
import qualified Data.Map.Strict as Map
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
import Panino.CoreLogic.Determinism
  ( stableTextSet )
import Panino.Download.Manager
  ( DownloadException(..)
  , DownloadJob(..)
  , DownloadOptions
  , DownloadProgress
  , DownloadSummary(..)
  , downloadOptionsWithConcurrency
  , runDownloadJobsWithOptionsAndProgressAndCancel
  , sha1HexFile
  , withDownloadConcurrency
  )
import Panino.Minecraft.Install
  ( InstallResult(..)
  , installMinecraftInheritedProfileWithOptionsAndProgressAndCancel
  , installMinecraftVersionWithOptionsAndProgressAndCancel
  )
import Panino.Minecraft.InstallPlanGraph
  ( InstallPlanGraph
  , addLoaderProfileTypedPlan
  , addInstanceMetadataTypedPlan
  , combineInstallPlanGraphs
  , dedupeInstallPlanJobs
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
import Panino.Minecraft.Modrinth
  ( ModrinthFile(..)
  , ModrinthVersion(..)
  , ResolvedModrinthMod(..)
  , resolveModrinthProject
  , resolveModrinthProjectWithVersion
  , safeFileName
  , selectPreferredModrinthVersion
  , stableResolvedModrinthMods
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getFileSize
  , listDirectory
  , removeFile
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

throwIfCancelled :: IO Bool -> IO ()
throwIfCancelled isCancelled = do
  cancelled <- isCancelled
  when cancelled (throwIO DownloadCancelled)

validateRequestedShaderCompatibility :: Maybe Text -> Maybe Text -> IO ()
validateRequestedShaderCompatibility maybeLoader maybeShader =
  case normalizeLoaderName <$> maybeShader of
    Nothing -> pure ()
    Just "none" -> pure ()
    Just "iris" ->
      requireShaderLoader "iris" ["fabric", "quilt"] maybeLoader
    Just "oculus" ->
      requireShaderLoader "oculus" ["forge", "neoforge"] maybeLoader
    Just "optifine" ->
      fail "manual_install_required: OptiFine cannot be installed automatically because it has no stable public download API; install it manually after creating a Vanilla instance"
    Just other ->
      fail ("unsupported shader loader: " <> Text.unpack other)

requireShaderLoader :: Text -> [Text] -> Maybe Text -> IO ()
requireShaderLoader shader supportedLoaders maybeLoader =
  case normalizeLoaderName <$> maybeLoader of
    Nothing ->
      fail ("shader_loader_incompatible:" <> Text.unpack shader <> " requires loader")
    Just loader
      | loader `elem` supportedLoaders -> pure ()
      | otherwise -> fail ("shader_loader_incompatible:" <> Text.unpack shader <> " " <> Text.unpack loader)

data InstalledLoaderProfile = InstalledLoaderProfile
  { loaderProfileVersion :: Text
  , loaderProfileLoaderVersion :: Maybe Text
  , loaderProfileResult :: InstallResult
  } deriving (Eq, Show)

data ShaderInstallResult = ShaderInstallResult
  { shaderInstallSummary :: DownloadSummary
  , shaderInstallGraph :: Maybe InstallPlanGraph
  , shaderInstallFiles :: [DownloadJob]
  } deriving (Eq, Show)

data ShaderResolution = ShaderResolution
  { shaderResolutionProject :: Text
  , shaderResolutionVersion :: Text
  , shaderResolutionRequestedLoader :: Text
  , shaderResolutionResolvedLoader :: Text
  , shaderResolutionMods :: [ResolvedModrinthMod]
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

installRequestedShader :: Manager -> MinecraftLayout -> Text -> Maybe Text -> Maybe Text -> Maybe Text -> DownloadOptions -> IO Bool -> (DownloadProgress -> IO ()) -> IO ShaderInstallResult
installRequestedShader manager layout minecraftVersion maybeLoader maybeShader maybeShaderVersion downloadOptions isCancelled onProgress =
  case normalizeLoaderName <$> maybeShader of
    Nothing -> pure emptyShaderInstallResult
    Just "none" -> pure emptyShaderInstallResult
    Just "iris" -> installModrinthShader manager layout minecraftVersion (fromMaybe "fabric" (normalizeLoaderName <$> maybeLoader)) "iris" maybeShaderVersion downloadOptions isCancelled onProgress
    Just "oculus" -> installModrinthShader manager layout minecraftVersion (fromMaybe "forge" (normalizeLoaderName <$> maybeLoader)) "oculus" maybeShaderVersion downloadOptions isCancelled onProgress
    Just "optifine" -> fail "manual_install_required: OptiFine cannot be installed automatically because it has no stable public download API; install it manually after creating a Vanilla instance"
    Just other -> fail ("unsupported shader loader: " <> Text.unpack other)

installModrinthShader :: Manager -> MinecraftLayout -> Text -> Text -> Text -> Maybe Text -> DownloadOptions -> IO Bool -> (DownloadProgress -> IO ()) -> IO ShaderInstallResult
installModrinthShader manager layout minecraftVersion loader project maybeShaderVersion downloadOptions isCancelled onProgress = do
  throwIfCancelled isCancelled
  resolution <- resolveShaderModrinthProject manager minecraftVersion loader project maybeShaderVersion
  throwIfCancelled isCancelled
  companionMods <- resolveFabricApiCompanion manager minecraftVersion (shaderResolutionResolvedLoader resolution) (map resolvedModrinthProject (shaderResolutionMods resolution))
  throwIfCancelled isCancelled
  createDirectoryIfMissing True (minecraftRoot layout </> "mods")
  let resolved = stableResolvedModrinthMods (shaderResolutionMods resolution <> companionMods)
  let rawJobs = map (modrinthDownloadJob layout) resolved
  validateShaderDownloadJobs rawJobs
  let jobs = dedupeInstallPlanJobs rawJobs
      graph = downloadJobsInstallPlanGraph "minecraft-companion" project jobs
  summary <-
    runDownloadJobsWithOptionsAndProgressAndCancel
      manager
      downloadOptions
      isCancelled
      jobs
      onProgress
  removeStaleShaderFiles layout resolved
  writeShaderInstallLog layout minecraftVersion resolution resolved
  pure
    ShaderInstallResult
      { shaderInstallSummary = summary
      , shaderInstallGraph = Just graph
      , shaderInstallFiles = jobs
      }

resolveFabricApiCompanion :: Manager -> Text -> Text -> [Text] -> IO [ResolvedModrinthMod]
resolveFabricApiCompanion manager minecraftVersion loader visited
  | normalizeLoaderName loader == "fabric" =
      resolveModrinthProject manager minecraftVersion loader visited "fabric-api"
  | otherwise = pure []

resolveShaderModrinthProject :: Manager -> Text -> Text -> Text -> Maybe Text -> IO ShaderResolution
resolveShaderModrinthProject manager minecraftVersion loader project maybeShaderVersion =
  case shaderReleaseLoaderCandidates project loader of
    [] ->
      fail ("shader_loader_incompatible:" <> Text.unpack project <> " " <> Text.unpack loader)
    candidates ->
      tryCandidates candidates
  where
    tryCandidates [] =
      fail
        ( "shader_release_not_found: no Modrinth "
            <> Text.unpack project
            <> " release found for Minecraft "
            <> Text.unpack minecraftVersion
            <> " and loader "
            <> Text.unpack loader
        )
    tryCandidates (candidate:rest) = do
      outcome <- try (resolveModrinthProjectWithVersion manager minecraftVersion candidate [] project maybeShaderVersion) :: IO (Either SomeException [ResolvedModrinthMod])
      case outcome of
        Right resolved -> do
          let selectedVersion =
                fromMaybe
                  (fromMaybe project (listToMaybe [versionId | ResolvedModrinthMod itemProject versionId _ <- resolved, itemProject == project]))
                  maybeShaderVersion
          pure
            ShaderResolution
              { shaderResolutionProject = project
              , shaderResolutionVersion = selectedVersion
              , shaderResolutionRequestedLoader = loader
              , shaderResolutionResolvedLoader = candidate
              , shaderResolutionMods = resolved
              }
        Left err
          | shaderReleaseNotFound err && not (null rest) ->
              tryCandidates rest
          | otherwise ->
              throwIO err

shaderReleaseLoaderCandidates :: Text -> Text -> [Text]
shaderReleaseLoaderCandidates project loader =
  case (normalizeLoaderName project, normalizeLoaderName loader) of
    ("iris", "fabric") -> ["fabric"]
    ("iris", "quilt") -> ["quilt", "fabric"]
    ("oculus", "forge") -> ["forge"]
    ("oculus", "neoforge") -> ["neoforge", "forge"]
    _ -> []

shaderReleaseNotFound :: SomeException -> Bool
shaderReleaseNotFound =
  Text.isInfixOf "shader_release_not_found" . Text.pack . displayException

modrinthDownloadJob :: MinecraftLayout -> ResolvedModrinthMod -> DownloadJob
modrinthDownloadJob layout resolved =
  DownloadJob
    { jobLabel = "modrinth mod " <> Text.unpack (resolvedModrinthProject resolved)
    , jobUrl = Text.unpack (modrinthFileUrl selectedFile)
    , jobTargetPath = minecraftRoot layout </> "mods" </> Text.unpack (safeFileName (modrinthFileName selectedFile))
    , jobSha1 = Map.lookup "sha1" (modrinthFileHashes selectedFile)
    , jobSize = modrinthFileSize selectedFile
    }
  where
    selectedFile = resolvedModrinthFile resolved

validateShaderDownloadJobs :: [DownloadJob] -> IO ()
validateShaderDownloadJobs jobs =
  case concatMap pathConflict (Map.toList jobsByTarget) of
    [] -> pure ()
    conflict:_ -> fail (Text.unpack conflict)
  where
    jobsByTarget =
      Map.fromListWith (<>) [(jobTargetPath job, [job]) | job <- jobs]
    pathConflict (targetPath, targetJobs)
      | length targetJobs <= 1 = []
      | length distinctSha1s > 1 =
          [ "shader_dependency_conflict: multiple downloads target "
              <> Text.pack targetPath
              <> " sha1="
              <> Text.intercalate "," distinctSha1s
          ]
      | otherwise = []
      where
        distinctSha1s = stableTextSet (map (fromMaybe "missing" . jobSha1) targetJobs)

requireProfileId :: Value -> IO Text
requireProfileId (Object obj) =
  case KeyMap.lookup (Key.fromString "id") obj of
    Just (String value) -> pure value
    _ -> fail "loader profile JSON is missing id"
requireProfileId _ =
  fail "loader profile JSON must be an object"

normalizeLoaderName :: Text -> Text
normalizeLoaderName =
  Text.toLower . Text.replace "-" "" . Text.replace "_" ""

normalizedLoaderTitle :: Text -> Text
normalizedLoaderTitle value =
  case normalizeLoaderName value of
    "neoforge" -> "neoForge"
    other -> other

normalizedShaderTitle :: Text -> Text
normalizedShaderTitle value =
  case normalizeLoaderName value of
    "iris" -> "iris"
    "oculus" -> "oculus"
    "optifine" -> "optifine"
    other -> other

normalizedShaderLoader :: Maybe Text -> Maybe Text
normalizedShaderLoader Nothing = Nothing
normalizedShaderLoader (Just value)
  | normalizeLoaderName value == "none" = Nothing
  | otherwise = Just (normalizedShaderTitle value)

mergeDownloadSummaries :: DownloadSummary -> DownloadSummary -> DownloadSummary
mergeDownloadSummaries lhs rhs =
  DownloadSummary
    { downloadedCount = downloadedCount lhs + downloadedCount rhs
    , skippedCount = skippedCount lhs + skippedCount rhs
    , totalCount = totalCount lhs + totalCount rhs
    }

emptyDownloadSummary :: DownloadSummary
emptyDownloadSummary =
  DownloadSummary
    { downloadedCount = 0
    , skippedCount = 0
    , totalCount = 0
    }

emptyShaderInstallResult :: ShaderInstallResult
emptyShaderInstallResult =
  ShaderInstallResult
    { shaderInstallSummary = emptyDownloadSummary
    , shaderInstallGraph = Nothing
    , shaderInstallFiles = []
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

writeShaderInstallLog :: MinecraftLayout -> Text -> ShaderResolution -> [ResolvedModrinthMod] -> IO ()
writeShaderInstallLog layout minecraftVersion resolution resolved = do
  let directory = minecraftRoot layout </> "downloads"
  createDirectoryIfMissing True directory
  writeFile
    (directory </> "shader-install.log")
    ( unlines
        ( [ "minecraftVersion=" <> Text.unpack minecraftVersion
          , "loader=" <> Text.unpack (shaderResolutionResolvedLoader resolution)
          , "requestedLoader=" <> Text.unpack (shaderResolutionRequestedLoader resolution)
          , "shaderProject=" <> Text.unpack (shaderResolutionProject resolution)
          , "fallback="
              <> if shaderResolutionRequestedLoader resolution == shaderResolutionResolvedLoader resolution
                then "false"
                else "true"
          ]
            <> map resolvedLine resolved
        )
    )
  where
    resolvedLine item =
      Text.unpack (resolvedModrinthProject item)
        <> " file="
        <> Text.unpack (modrinthFileName (resolvedModrinthFile item))
        <> maybe "" ((" sha1=" <>) . Text.unpack) (Map.lookup "sha1" (modrinthFileHashes (resolvedModrinthFile item)))
        <> " url="
        <> Text.unpack (modrinthFileUrl (resolvedModrinthFile item))

removeStaleShaderFiles :: MinecraftLayout -> [ResolvedModrinthMod] -> IO ()
removeStaleShaderFiles layout resolved = do
  previous <- readShaderInstallLogFiles layout
  let selected =
        Map.fromList
          [ (resolvedModrinthProject item, modrinthFileName (resolvedModrinthFile item))
          | item <- resolved
          ]
  forM_ previous $ \(project, previousFile) ->
    case Map.lookup project selected of
      Just currentFile | currentFile /= previousFile ->
        removeShaderFile layout previousFile
      _ -> pure ()

removeTrackedShaderInstallFiles :: MinecraftLayout -> IO ()
removeTrackedShaderInstallFiles layout = do
  previous <- readShaderInstallLogFiles layout
  forM_ previous $ \(_, previousFile) ->
    removeShaderFile layout previousFile

readShaderInstallLogFiles :: MinecraftLayout -> IO [(Text, Text)]
readShaderInstallLogFiles layout = do
  result <- try (readFile (minecraftRoot layout </> "downloads" </> "shader-install.log")) :: IO (Either SomeException String)
  pure $ case result of
    Left _ -> []
    Right content -> foldr collect [] (lines content)
  where
    collect line acc =
      case parseShaderLogLine (Text.pack line) of
        Just item -> item : acc
        Nothing -> acc

parseShaderLogLine :: Text -> Maybe (Text, Text)
parseShaderLogLine line = do
  let (project, rest) = Text.breakOn " file=" line
      afterFile = Text.drop (Text.length (" file=" :: Text)) rest
      (fileName, _) = Text.breakOn " url=" afterFile
  if Text.null project || Text.null rest || Text.null fileName
    then Nothing
    else Just (project, fileName)

removeShaderFile :: MinecraftLayout -> Text -> IO ()
removeShaderFile layout fileName =
  removeFile (minecraftRoot layout </> "mods" </> Text.unpack (safeFileName fileName))
    `catch` ignoreRemoveError
  where
    ignoreRemoveError :: SomeException -> IO ()
    ignoreRemoveError _ = pure ()
