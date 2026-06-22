{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Configuration.Preflight
  ( configurationCapabilities
  , exportBackupPreflight
  , launchLibrarySummary
  , loaderCompatibility
  , modpackImport
  , modpackPreflight
  , versionSwitchPreflight
  ) where

import Control.Exception (try)
import Control.Monad
  ( forM
  )
import Data.Int (Int64)
import Data.List
  ( sort
  , sortBy
  )
import Data.Ord
  ( Down(..)
  , comparing
  )
import Data.Maybe
  ( fromMaybe
  , isJust
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Network.HTTP.Client (Manager)
import Panino.Content.Configuration.Modpack
  ( modpackImport
  , modpackPreflight
  )
import Panino.Content.Configuration.Types
import Panino.Content.Online.Minecraft
  ( contentLoaderMetadata
  , preferredLoaderMetadata
  )
import Panino.Content.Online.Types
  ( ContentLoaderRequest(..)
  , LoaderMetadata(..)
  )
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , getFileSize
  , getModificationTime
  , listDirectory
  )
import System.FilePath
  ( takeDirectory
  , (</>)
  )

configurationCapabilities :: GameConfigurationRequest -> IO ConfigurationCapabilities
configurationCapabilities request = do
  gameDirExists <- doesDirectoryExist (configRequestGameDir request)
  let hasLoader = isJust (configRequestLoader request)
      active = configRequestStatus request `elem` [Just "installing", Just "running"]
      reasons =
        concat
          [ ["game_directory_missing" | not gameDirExists]
          , ["configuration_busy" | active]
          , ["vanilla_configuration_has_no_mod_loader" | not hasLoader]
          ]
  pure
    ConfigurationCapabilities
      { capabilityCanLaunch = gameDirExists && not active
      , capabilityCanManageMods = hasLoader && gameDirExists
      , capabilityCanManageResourcePacks = gameDirExists
      , capabilityCanManageShaderPacks = hasLoader && gameDirExists
      , capabilityCanInstallLoader = not hasLoader && not active
      , capabilityCanExportModpack = hasLoader && gameDirExists && not active
      , capabilityCanBackupSaves = gameDirExists && not active
      , capabilityCanRepair = not active
      , capabilityReasons = reasons
      }

loaderCompatibility :: Manager -> LoaderCompatibilityRequest -> IO LoaderCompatibilityResponse
loaderCompatibility manager request = do
  metadata <- contentLoaderMetadata manager (ContentLoaderRequest (loaderCompatibilityMinecraftVersion request))
  let mkEntry loaderName =
        let versionsForLoader =
              sort
                [ loaderMetadataLoaderVersion item
                | item <- metadata
                , loaderMetadataSource item == loaderName
                ]
            metadataForLoader =
              [ item
              | item <- metadata
              , loaderMetadataSource item == loaderName
              ]
            stable =
              [ loaderMetadataLoaderVersion item
              | item <- metadataForLoader
              , loaderMetadataStable item
              ]
            recommended = loaderMetadataLoaderVersion <$> preferredLoaderMetadata metadataForLoader
         in LoaderCompatibilityEntry
              { loaderEntryLoader = loaderName
              , loaderEntryAvailable = not (null versionsForLoader)
              , loaderEntryRecommendedVersion = recommended
              , loaderEntryVersions = versionsForLoader
              , loaderEntryReason =
                  if null versionsForLoader
                    then Just ("No compatible " <> loaderName <> " metadata was reported for this Minecraft version.")
                    else Nothing
              , loaderEntryExperimental = null stable && not (null versionsForLoader)
              }
  pure
    LoaderCompatibilityResponse
      { loaderResponseMinecraftVersion = loaderCompatibilityMinecraftVersion request
      , loaderResponseOptions =
          LoaderCompatibilityEntry
            { loaderEntryLoader = "vanilla"
            , loaderEntryAvailable = True
            , loaderEntryRecommendedVersion = Nothing
            , loaderEntryVersions = []
            , loaderEntryReason = Nothing
            , loaderEntryExperimental = False
            }
            : map mkEntry ["fabric", "forge", "quilt", "neoForge"]
      }

versionSwitchPreflight :: VersionSwitchPreflightRequest -> IO VersionSwitchPreflightResponse
versionSwitchPreflight request = do
  capabilities <- configurationCapabilities config
  targetInstalled <- versionFilesPresent (configRequestGameDir config) target
  let busy = configRequestStatus config `elem` [Just "installing", Just "running"]
      loaderRisk = isJust (configRequestLoader config) && majorLine (configRequestMinecraftVersion config) /= majorLine target
      blockingReasons =
        concat
          [ ["configuration_busy" | busy]
          ]
      warnings =
        concat
          [ ["target_version_files_missing" | not targetInstalled]
          , ["loader_and_content_may_be_incompatible" | loaderRisk]
          , ["java_requirement_may_change" | configRequestMinecraftVersion config /= target]
          ]
      action
        | busy = "blocked"
        | loaderRisk = "copyConfiguration"
        | not targetInstalled = "installThenSwitch"
        | otherwise = "switchInPlace"
  pure
    VersionSwitchPreflightResponse
      { switchPreflightAllowed = null blockingReasons
      , switchPreflightRecommendedAction = action
      , switchPreflightWarnings = warnings
      , switchPreflightBlockingReasons = blockingReasons
      , switchPreflightCapabilities = capabilities
      }
  where
    config = switchPreflightConfiguration request
    target = switchPreflightTargetMinecraftVersion request

exportBackupPreflight :: ExportBackupPreflightRequest -> IO ExportBackupPreflightResponse
exportBackupPreflight request = do
  let config = exportPreflightConfiguration request
      gameDir = configRequestGameDir config
      savesDir = gameDir </> "saves"
      versionDir = gameDir </> "versions" </> Text.unpack (configRequestMinecraftVersion config)
      kind = Text.toLower (exportPreflightKind request)
  gameDirExists <- doesDirectoryExist gameDir
  savesExist <- doesDirectoryExist savesDir
  versionOk <- versionFilesPresent gameDir (configRequestMinecraftVersion config)
  targetWritable <- targetParentExists (exportPreflightTargetPath request)
  size <- if gameDirExists then Just <$> directorySizeRecursive gameDir else pure Nothing
  let busy = configRequestStatus config `elem` [Just "installing", Just "running"]
      blockingReasons =
        concat
          [ ["game_directory_missing" | not gameDirExists]
          , ["configuration_busy" | busy]
          , ["target_parent_missing" | not targetWritable]
          , ["saves_directory_missing" | kind == "backup" && not savesExist]
          ]
      warnings =
        concat
          [ ["version_files_incomplete" | kind == "export" && not versionOk]
          , ["mod_loader_missing_for_modpack_export" | kind == "export" && configRequestLoader config == Nothing]
          ]
  pure
    ExportBackupPreflightResponse
      { exportPreflightAllowed = null blockingReasons
      , exportPreflightWarnings = warnings
      , exportPreflightBlockingReasons = blockingReasons
      , exportPreflightEstimatedBytes = size
      , exportPreflightCheckedPaths = [gameDir, savesDir, versionDir]
      }

launchLibrarySummary :: LaunchLibraryRequest -> IO LaunchLibraryResponse
launchLibrarySummary (LaunchLibraryRequest configurations) = do
  summaries <- traverse summarizeLaunchInstance configurations
  let readyCount = length (filter launchInstanceCanLaunch summaries)
      attentionCount = length (filter launchInstanceNeedsAttention summaries)
      recent =
        take 6
          . map launchInstanceStableId
          . sortByLastLaunch
          . filter (\item -> isJust (launchInstanceLastLaunchedAt item) && not (launchInstanceHiddenFromRecent item))
          $ summaries
      recentInstalls =
        take 6
          . map launchInstanceStableId
          . sortByInstalledAt
          . filter (isJust . launchInstanceInstalledAt)
          $ summaries
      favorites =
        take 6
          . map launchInstanceStableId
          . sortByLastLaunch
          . filter launchInstanceIsFavorite
          $ summaries
      attention =
        take 8
          . map launchInstanceStableId
          . sortByLastLaunch
          . filter launchInstanceNeedsAttention
          $ summaries
  pure
    LaunchLibraryResponse
      { launchLibraryInstances = summaries
      , launchLibraryTotalCount = length summaries
      , launchLibraryReadyCount = readyCount
      , launchLibraryAttentionCount = attentionCount
      , launchLibraryRecentIds = recent
      , launchLibraryRecentInstallIds = recentInstalls
      , launchLibraryFavoriteIds = favorites
      , launchLibraryAttentionIds = attention
      }

summarizeLaunchInstance :: GameConfigurationRequest -> IO LaunchInstanceSummary
summarizeLaunchInstance request = do
  capabilities <- configurationCapabilities request
  gameDirExists <- doesDirectoryExist gameDir
  versionOk <- versionFilesPresent gameDir versionId
  content <- summarizeContent gameDir
  size <- if gameDirExists then Just <$> directorySizeRecursive gameDir else pure Nothing
  installedAt <- if gameDirExists then safeModificationTime gameDir else pure Nothing
  let busy = configRequestStatus request `elem` [Just "installing", Just "running"]
      failed = configRequestStatus request == Just "failed"
      reasons =
        capabilityReasons capabilities
          <> ["version_files_missing" | gameDirExists && not versionOk]
          <> ["last_launch_failed" | failed]
      canLaunch = capabilityCanLaunch capabilities && versionOk && not failed
      status
        | busy = fromMaybe "running" (configRequestStatus request)
        | failed = "failed"
        | not gameDirExists = "missing"
        | not versionOk = "needsInstall"
        | otherwise = "ready"
  pure
    LaunchInstanceSummary
      { launchInstanceId = configRequestId request
      , launchInstanceName = configRequestName request
      , launchInstanceMinecraftVersion = versionId
      , launchInstanceLoader = configRequestLoader request
      , launchInstanceGameDir = gameDir
      , launchInstanceStatus = status
      , launchInstanceCanLaunch = canLaunch
      , launchInstanceNeedsAttention = not canLaunch || not (null reasons)
      , launchInstanceAttentionReasons = reasons
      , launchInstanceIsFavorite = configRequestIsFavorite request
      , launchInstanceLastLaunchedAt = configRequestLastLaunchedAt request
      , launchInstanceLastLaunchState = configRequestLastLaunchState request
      , launchInstanceLaunchCount = configRequestLaunchCount request
      , launchInstanceHiddenFromRecent = configRequestHiddenFromRecent request
      , launchInstanceInstalledAt = installedAt
      , launchInstanceContent = content
      , launchInstanceDiskUsageBytes = size
      }
  where
    gameDir = configRequestGameDir request
    versionId = configRequestMinecraftVersion request

sortByLastLaunch :: [LaunchInstanceSummary] -> [LaunchInstanceSummary]
sortByLastLaunch =
  sortBy (comparing (Down . fromMaybe "" . launchInstanceLastLaunchedAt))

sortByInstalledAt :: [LaunchInstanceSummary] -> [LaunchInstanceSummary]
sortByInstalledAt =
  sortBy (comparing (Down . launchInstanceInstalledAt))

launchInstanceStableId :: LaunchInstanceSummary -> Text
launchInstanceStableId summary =
  fromMaybe (Text.pack (launchInstanceGameDir summary)) (launchInstanceId summary)

safeModificationTime :: FilePath -> IO (Maybe UTCTime)
safeModificationTime path = do
  result <- try (getModificationTime path) :: IO (Either IOError UTCTime)
  case result of
    Left _ -> pure Nothing
    Right value -> pure (Just value)

summarizeContent :: FilePath -> IO LaunchContentSummary
summarizeContent gameDir =
  LaunchContentSummary
    <$> countVisibleEntries (gameDir </> "mods")
    <*> countVisibleEntries (gameDir </> "resourcepacks")
    <*> countVisibleEntries (gameDir </> "shaderpacks")
    <*> countVisibleEntries (gameDir </> "saves")
    <*> countVisibleEntries (gameDir </> "logs")
    <*> pure 0
    <*> pure 0

countVisibleEntries :: FilePath -> IO Int
countVisibleEntries directory = do
  result <- try (listDirectory directory) :: IO (Either IOError [FilePath])
  case result of
    Left _ -> pure 0
    Right entries -> do
      existing <-
        forM (filter visible entries) $ \entry -> do
          let path = directory </> entry
          file <- doesFileExist path
          dir <- doesDirectoryExist path
          pure (file || dir)
      pure (length (filter id existing))
  where
    visible ('.' : _) = False
    visible _ = True

versionFilesPresent :: FilePath -> Text -> IO Bool
versionFilesPresent gameDir versionId = do
  let versionText = Text.unpack versionId
      versionDir = gameDir </> "versions" </> versionText
  jsonExists <- doesFileExist (versionDir </> versionText <> ".json")
  jarExists <- doesFileExist (versionDir </> versionText <> ".jar")
  pure (jsonExists && jarExists)

targetParentExists :: Maybe FilePath -> IO Bool
targetParentExists Nothing = pure True
targetParentExists (Just path) = doesDirectoryExist (takeDirectory path)

directorySizeRecursive :: FilePath -> IO Int64
directorySizeRecursive path = do
  isDir <- doesDirectoryExist path
  if not isDir
    then do
      isFile <- doesFileExist path
      if isFile
        then fromIntegral <$> getFileSize path
        else pure 0
    else do
      children <- sort <$> listDirectory path
      sum <$> traverse (directorySizeRecursive . (path </>)) children

majorLine :: Text -> Text
majorLine value =
  Text.intercalate "." (take 2 (Text.splitOn "." value))
