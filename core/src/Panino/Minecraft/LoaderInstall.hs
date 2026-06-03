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
  ( FromJSON(..)
  , Value(..)
  , decode
  , encode
  , object
  , toJSON
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Aeson.Types ((.!=))
import Control.Concurrent.Async (mapConcurrently)
import Data.Foldable (toList)
import qualified Data.ByteString.Lazy as BL
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Int (Int64)
import Data.List
  ( (\\)
  , sortOn
  )
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  , mapMaybe
  , maybeToList
  )
import Data.Ord (Down(..))
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
  ( stableSortOnText
  , stableTextSet
  )
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
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  , clientJarPath
  , versionJsonPath
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

launcherProfilesPath :: MinecraftLayout -> FilePath
launcherProfilesPath layout =
  minecraftRoot layout </> "launcher_profiles.json"

ensureLauncherProfilesJson :: MinecraftLayout -> Text -> IO ()
ensureLauncherProfilesJson layout minecraftVersion = do
  let target = launcherProfilesPath layout
  exists <- doesFileExist target
  if exists
    then ensureLauncherProfilesJsonIsUsable target minecraftVersion
    else do
      createDirectoryIfMissing True (takeDirectory target)
      BL.writeFile target (encode (launcherProfilesJson minecraftVersion))

ensureLauncherProfilesJsonIsUsable :: FilePath -> Text -> IO ()
ensureLauncherProfilesJsonIsUsable target minecraftVersion = do
  raw <- BL.readFile target
  case decode raw :: Maybe Value of
    Just value ->
      case normalizeLauncherProfilesJson minecraftVersion value of
        Just normalized -> BL.writeFile target (encode normalized)
        Nothing -> fail ("loader_launcher_profiles_invalid: launcher_profiles.json must be an object at " <> target)
    Nothing ->
      fail ("loader_launcher_profiles_invalid: failed to decode existing launcher_profiles.json at " <> target)

launcherProfilesJson :: Text -> Value
launcherProfilesJson minecraftVersion =
  case normalizeLauncherProfilesJson minecraftVersion (Object KeyMap.empty) of
    Just value -> value
    Nothing -> Object KeyMap.empty

normalizeLauncherProfilesJson :: Text -> Value -> Maybe Value
normalizeLauncherProfilesJson minecraftVersion (Object obj) =
  Just $
    Object $
      KeyMap.insert (Key.fromString "profiles") (Object profiles) $
        KeyMap.insert (Key.fromString "selectedProfile") (String selectedProfile) $
          KeyMap.insert (Key.fromString "clientToken") (String "panino") $
            KeyMap.insert (Key.fromString "authenticationDatabase") (Object KeyMap.empty) $
              KeyMap.insert (Key.fromString "launcherVersion") launcherVersionValue obj
  where
    existingProfiles =
      case KeyMap.lookup (Key.fromString "profiles") obj of
        Just (Object values) -> values
        _ -> KeyMap.empty
    profiles =
      KeyMap.insert paninoProfileKey (paninoLauncherProfile minecraftVersion) existingProfiles
    selectedProfile =
      case KeyMap.lookup (Key.fromString "selectedProfile") obj of
        Just (String value) | not (Text.null value) -> value
        _ -> paninoProfileId
normalizeLauncherProfilesJson _ _ =
  Nothing

paninoProfileId :: Text
paninoProfileId = "Panino"

paninoProfileKey :: Key.Key
paninoProfileKey =
  Key.fromText paninoProfileId

paninoLauncherProfile :: Text -> Value
paninoLauncherProfile minecraftVersion =
  object
    [ "name" .= paninoProfileId
    , "type" .= ("custom" :: Text)
    , "created" .= ("1970-01-01T00:00:00.000Z" :: Text)
    , "lastUsed" .= ("1970-01-01T00:00:00.000Z" :: Text)
    , "lastVersionId" .= minecraftVersion
    ]

launcherVersionValue :: Value
launcherVersionValue =
  object
    [ "name" .= ("Panino Launcher" :: Text)
    , "format" .= (21 :: Int)
    ]

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

data ResolvedModrinthMod = ResolvedModrinthMod
  { resolvedModrinthProject :: Text
  , resolvedModrinthVersion :: Text
  , resolvedModrinthFile :: ModrinthFile
  } deriving (Eq, Show)

resolveModrinthProject :: Manager -> Text -> Text -> [Text] -> Text -> IO [ResolvedModrinthMod]
resolveModrinthProject manager minecraftVersion loader visited project =
  resolveModrinthProjectWithVersion manager minecraftVersion loader visited project Nothing

resolveModrinthProjectWithVersion :: Manager -> Text -> Text -> [Text] -> Text -> Maybe Text -> IO [ResolvedModrinthMod]
resolveModrinthProjectWithVersion manager minecraftVersion loader visited project maybeVersionId
  | project `elem` visited = pure []
  | otherwise = do
      selectedVersion <-
        case maybeVersionId of
          Just versionId -> do
            version <- modrinthVersionById manager versionId
            if modrinthVersionProjectId version == project
              then pure version
              else fail ("shader_release_not_found: Modrinth release " <> Text.unpack versionId <> " does not belong to " <> Text.unpack project)
          Nothing -> do
            versions <- modrinthVersions manager project minecraftVersion loader
            case selectPreferredModrinthVersion minecraftVersion loader versions of
              Just version -> pure version
              Nothing ->
                fail
                  ( "shader_release_not_found: no Modrinth "
                      <> Text.unpack project
                      <> " release found for Minecraft "
                      <> Text.unpack minecraftVersion
                      <> " and loader "
                      <> Text.unpack loader
                  )
      resolveModrinthVersion manager minecraftVersion loader (project : visited) project selectedVersion

resolveModrinthVersion :: Manager -> Text -> Text -> [Text] -> Text -> ModrinthVersion -> IO [ResolvedModrinthMod]
resolveModrinthVersion manager minecraftVersion loader visited project version = do
  when (not (modrinthVersionCompatible minecraftVersion loader version)) $
    fail
      ( "shader_release_not_found: Modrinth "
          <> Text.unpack project
          <> " release "
          <> Text.unpack (modrinthVersionId version)
          <> " is not compatible with Minecraft "
          <> Text.unpack minecraftVersion
          <> " and loader "
          <> Text.unpack loader
      )
  selectedFile <-
    case preferredFile version of
      Just file -> pure file
      Nothing -> fail ("shader_file_missing_download: Modrinth release has no downloadable file: " <> Text.unpack project)
  dependencies <-
    concat
      <$> mapConcurrently
        (resolveRequiredDependency manager minecraftVersion loader visited)
        (requiredDependencies (modrinthVersionDependencies version))
  pure (dependencies <> [ResolvedModrinthMod project (modrinthVersionId version) selectedFile])

resolveRequiredDependency :: Manager -> Text -> Text -> [Text] -> ModrinthDependency -> IO [ResolvedModrinthMod]
resolveRequiredDependency manager minecraftVersion loader visited dependency =
  case modrinthDependencyVersionId dependency of
    Just versionId
      | versionId `elem` visited -> pure []
      | otherwise -> do
          version <- modrinthVersionById manager versionId
          let project = fromMaybe (modrinthVersionProjectId version) (modrinthDependencyProjectId dependency)
          if modrinthVersionCompatible minecraftVersion loader version
            then resolveModrinthVersion manager minecraftVersion loader (versionId : visited) project version
            else
              case modrinthDependencyProjectId dependency of
                Just projectId ->
                  resolveModrinthProject manager minecraftVersion loader (versionId : visited) projectId
                Nothing ->
                  fail
                    ( "shader_dependency_unresolved: dependency version "
                        <> Text.unpack versionId
                        <> " is not compatible with Minecraft "
                        <> Text.unpack minecraftVersion
                        <> " and loader "
                        <> Text.unpack loader
                        <> ", and no project_id was provided"
                    )
    Nothing ->
      case modrinthDependencyProjectId dependency of
        Just project -> resolveModrinthProject manager minecraftVersion loader visited project
        Nothing -> fail "shader_dependency_unresolved: Modrinth required dependency is missing project_id and version_id"

requiredDependencies :: [ModrinthDependency] -> [ModrinthDependency]
requiredDependencies =
  stableSortOnText modrinthDependencyKey . filter ((== "required") . Text.toLower . modrinthDependencyType)

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

stableResolvedModrinthMods :: [ResolvedModrinthMod] -> [ResolvedModrinthMod]
stableResolvedModrinthMods =
  stableSortOnText resolvedModrinthKey . foldr collect []
  where
    collect item acc
      | resolvedModrinthKey item `elem` map resolvedModrinthKey acc = acc
      | otherwise = item : acc

resolvedModrinthKey :: ResolvedModrinthMod -> Text
resolvedModrinthKey item =
  Text.intercalate
    "|"
    [ resolvedModrinthProject item
    , modrinthFileName file
    , modrinthFileUrl file
    , fromMaybe "" (Map.lookup "sha1" (modrinthFileHashes file))
    ]
  where
    file = resolvedModrinthFile item

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

modrinthVersions :: Manager -> Text -> Text -> Text -> IO [ModrinthVersion]
modrinthVersions manager project minecraftVersion loader = do
  request <-
    coreRequest
      ( "https://api.modrinth.com/v2/project/"
          <> Text.unpack project
          <> "/version?game_versions=%5B%22"
          <> Text.unpack minecraftVersion
          <> "%22%5D&loaders=%5B%22"
          <> Text.unpack (modrinthLoaderName loader)
          <> "%22%5D"
      )
      []
  fetchJson manager request

modrinthVersionById :: Manager -> Text -> IO ModrinthVersion
modrinthVersionById manager versionId =
  fetchJson manager
    =<< coreRequest
      ("https://api.modrinth.com/v2/version/" <> Text.unpack versionId)
      []

modrinthLoaderName :: Text -> Text
modrinthLoaderName "neoforge" = "neoforge"
modrinthLoaderName other = Text.toLower other

data ModrinthVersion = ModrinthVersion
  { modrinthVersionId :: Text
  , modrinthVersionProjectId :: Text
  , modrinthVersionGameVersions :: [Text]
  , modrinthVersionLoaders :: [Text]
  , modrinthVersionName :: Text
  , modrinthVersionNumber :: Text
  , modrinthVersionType :: Text
  , modrinthVersionDatePublished :: Maybe Text
  , modrinthVersionFeatured :: Bool
  , modrinthVersionFiles :: [ModrinthFile]
  , modrinthVersionDependencies :: [ModrinthDependency]
  } deriving (Eq, Show)

instance FromJSON ModrinthVersion where
  parseJSON =
    withObject "ModrinthVersion" $ \obj ->
      ModrinthVersion
        <$> obj .: "id"
        <*> obj .: "project_id"
        <*> obj .:? "game_versions" .!= []
        <*> obj .:? "loaders" .!= []
        <*> obj .:? "name" .!= ""
        <*> obj .:? "version_number" .!= ""
        <*> obj .:? "version_type" .!= ""
        <*> obj .:? "date_published"
        <*> obj .:? "featured" .!= False
        <*> obj .:? "files" .!= []
        <*> obj .:? "dependencies" .!= []

data ModrinthDependency = ModrinthDependency
  { modrinthDependencyProjectId :: Maybe Text
  , modrinthDependencyVersionId :: Maybe Text
  , modrinthDependencyType :: Text
  } deriving (Eq, Show)

instance FromJSON ModrinthDependency where
  parseJSON =
    withObject "ModrinthDependency" $ \obj ->
      ModrinthDependency
        <$> obj .:? "project_id"
        <*> obj .:? "version_id"
        <*> obj .:? "dependency_type" .!= "required"

data ModrinthFile = ModrinthFile
  { modrinthFileName :: Text
  , modrinthFileUrl :: Text
  , modrinthFilePrimary :: Bool
  , modrinthFileHashes :: Map Text Text
  , modrinthFileSize :: Maybe Int64
  } deriving (Eq, Show)

instance FromJSON ModrinthFile where
  parseJSON =
    withObject "ModrinthFile" $ \obj ->
      ModrinthFile
        <$> obj .: "filename"
        <*> obj .: "url"
        <*> obj .:? "primary" .!= False
        <*> obj .:? "hashes" .!= Map.empty
        <*> obj .:? "size"

preferredFile :: ModrinthVersion -> Maybe ModrinthFile
preferredFile version =
  case filter modrinthFilePrimary files of
    file:_ -> Just file
    [] -> listToMaybe files
  where
    files = stableSortOnText modrinthFileKey (modrinthVersionFiles version)

selectPreferredModrinthVersion :: Text -> Text -> [ModrinthVersion] -> Maybe ModrinthVersion
selectPreferredModrinthVersion minecraftVersion loader versions =
  listToMaybe (sortOn (modrinthVersionSelectionKey minecraftVersion loader) candidates)
  where
    candidates = filter (modrinthVersionCompatible minecraftVersion loader) versions

modrinthVersionSelectionKey :: Text -> Text -> ModrinthVersion -> (Int, Int, Int, Int, Down Text, Text, Text)
modrinthVersionSelectionKey minecraftVersion loader version =
  ( if modrinthVersionSupportsLoader loader version then 0 else 1
  , if modrinthVersionTextMatchesMinecraft minecraftVersion version then 0 else 1
  , modrinthReleaseRank (modrinthVersionType version)
  , if modrinthVersionFeatured version then 0 else 1
  , Down (fromMaybe "" (modrinthVersionDatePublished version))
  , modrinthVersionProjectId version
  , modrinthVersionId version
  )

modrinthVersionSupportsMinecraft :: Text -> ModrinthVersion -> Bool
modrinthVersionSupportsMinecraft minecraftVersion version =
  minecraftVersion `elem` modrinthVersionGameVersions version

modrinthVersionSupportsLoader :: Text -> ModrinthVersion -> Bool
modrinthVersionSupportsLoader loader version =
  modrinthLoaderName loader `elem` map Text.toLower (modrinthVersionLoaders version)

modrinthVersionCompatible :: Text -> Text -> ModrinthVersion -> Bool
modrinthVersionCompatible minecraftVersion loader version =
  modrinthVersionSupportsMinecraft minecraftVersion version
    && modrinthVersionSupportsLoader loader version

modrinthVersionTextMatchesMinecraft :: Text -> ModrinthVersion -> Bool
modrinthVersionTextMatchesMinecraft minecraftVersion version =
  any matchesVersionText haystacks
  where
    target = Text.toLower minecraftVersion
    targetMc = "mc" <> target
    haystacks =
      map Text.toLower $
        [ modrinthVersionName version
        , modrinthVersionNumber version
        ]
          <> map modrinthFileName (modrinthVersionFiles version)
    matchesVersionText value =
      targetMc `Text.isInfixOf` value || target `Text.isInfixOf` value

modrinthReleaseRank :: Text -> Int
modrinthReleaseRank value =
  case Text.toLower value of
    "release" -> 0
    "beta" -> 1
    "alpha" -> 2
    _ -> 3

modrinthDependencyKey :: ModrinthDependency -> Text
modrinthDependencyKey dependency =
  Text.intercalate
    "|"
    [ fromMaybe "" (modrinthDependencyProjectId dependency)
    , fromMaybe "" (modrinthDependencyVersionId dependency)
    , modrinthDependencyType dependency
    ]

modrinthFileKey :: ModrinthFile -> Text
modrinthFileKey file =
  Text.intercalate
    "|"
    [ modrinthFileName file
    , modrinthFileUrl file
    , maybe "" (Text.pack . show) (modrinthFileSize file)
    , fromMaybe "" (Map.lookup "sha1" (modrinthFileHashes file))
    ]

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

safeFileName :: Text -> Text
safeFileName value =
  Text.filter allowed value
  where
    allowed char =
      char == '.'
        || char == '-'
        || char == '_'
        || char == '+'
        || ('a' <= char && char <= 'z')
        || ('A' <= char && char <= 'Z')
        || ('0' <= char && char <= '9')

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
