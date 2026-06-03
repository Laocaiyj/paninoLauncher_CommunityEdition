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

import Control.Exception
  ( SomeException
  , try
  )
import Control.Monad
  ( filterM
  , forM
  , forM_
  , unless
  , when
  )
import Data.Aeson
  ( Object
  , Value(..)
  , encode
  , eitherDecode
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Aeson.Types
  ( Parser
  , parseMaybe
  )
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.Foldable (find)
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
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Network.HTTP.Client (Manager)
import Panino.Content.Configuration.Types
import Panino.Content.Online.Minecraft
  ( contentLoaderMetadata
  , preferredLoaderMetadata
  )
import Panino.Content.Online.Types
  ( ContentLoaderRequest(..)
  , LoaderMetadata(..)
  )
import Panino.Download.Manager
  ( DownloadJob(..)
  , downloadOptionsWithOverrides
  , runDownloadJobsWithOptionsAndProgressAndCancel
  )
import Panino.CoreLogic.Determinism
  ( stableFingerprint
  , stableSortOnText
  , stableSortPackages
  , stableTextSet
  )
import qualified Panino.Install.Plan.Types as Plan
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getFileSize
  , getModificationTime
  , listDirectory
  , removeDirectoryRecursive
  , removeFile
  , renameDirectory
  )
import System.Exit (ExitCode(..))
import System.FilePath
  ( isRelative
  , normalise
  , splitDirectories
  , takeDirectory
  , takeExtension
  , (</>)
  )
import System.IO
  ( IOMode(..)
  , withBinaryFile
  )
import System.Process
  ( CreateProcess(..)
  , StdStream(..)
  , createProcess
  , proc
  , readCreateProcessWithExitCode
  , waitForProcess
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

modpackPreflight :: ModpackPreflightRequest -> IO ModpackPreflightResponse
modpackPreflight request
  | Text.toLower (modpackPreflightSourceType request) `elem` ["curseforge", "curseforgeadvanced"] =
      pure blockedOnline
  | otherwise =
      case modpackPreflightSourcePath request of
        Nothing -> pure (blocked ["modpack_source_missing"])
        Just path -> do
          exists <- doesFileExist path
          if not exists
            then pure (blocked ["modpack_file_missing"])
            else parseLocalModpack path (modpackPreflightTargetGameDir request)
  where
    blockedOnline =
      (blocked ["curseforge_api_key_required"])
        { modpackPreflightRequiresApiKey = True
        , modpackPreflightWarnings = ["CurseForge advanced import requires a personal API key."]
        }
    blocked reasons =
      ModpackPreflightResponse
        { modpackPreflightValid = False
        , modpackPreflightName = Nothing
        , modpackPreflightMinecraftVersion = Nothing
        , modpackPreflightLoader = Nothing
        , modpackPreflightLoaderVersion = Nothing
        , modpackPreflightModCount = 0
        , modpackPreflightResourcePackCount = 0
        , modpackPreflightShaderPackCount = 0
        , modpackPreflightOverridesCount = 0
        , modpackPreflightEstimatedDownloadBytes = Nothing
        , modpackPreflightRequiresApiKey = False
        , modpackPreflightWarnings = []
        , modpackPreflightBlockingReasons = reasons
        , modpackPreflightTypedPlan = modpackPlanSkeleton "modpack" Nothing Nothing Nothing Nothing (modpackPreflightTargetGameDir request) [] [] [] [] reasons
        }

modpackImport :: Manager -> ModpackImportRequest -> IO ModpackImportResponse
modpackImport manager request = do
  preflight <-
    modpackPreflight
      ModpackPreflightRequest
        { modpackPreflightSourceType = modpackImportSourceType request
        , modpackPreflightSourcePath = Just (modpackImportSourcePath request)
        , modpackPreflightTargetGameDir = Just targetGameDir
        }
  targetDirectoryExists <- doesDirectoryExist targetGameDir
  targetFileExists <- doesFileExist targetGameDir
  let basePlan = modpackPreflightTypedPlan preflight
      importBlockingReasons =
        concat
          [ ["target_game_dir_required" | null targetGameDir]
          , ["target_game_dir_already_exists" | targetDirectoryExists || targetFileExists]
          , unsafePlanTargetReasons basePlan
          ]
      plan =
        Plan.finalizeTypedInstallPlan
          basePlan
            { Plan.typedPlanTargetGameDir = Just targetGameDir
            , Plan.typedPlanBlockedReasons =
                Plan.typedPlanBlockedReasons basePlan <> importBlockingReasons
            }
      blockingReasons =
        modpackPreflightBlockingReasons preflight <> importBlockingReasons <> Plan.typedPlanBlockedReasons plan
  if not (modpackPreflightValid preflight) || Plan.typedPlanStatus plan == "blocked" || not (null importBlockingReasons)
    then pure (modpackImportBlocked preflight plan blockingReasons)
    else do
      removePathIfExists stagingPath
      result <- try (runModpackImport preflight plan) :: IO (Either SomeException Int)
      case result of
        Left err -> do
          removePathIfExists stagingPath
          pure
            (modpackImportBlocked
              preflight
              plan
              ["modpack_import_failed:" <> Text.pack (show err)])
        Right written ->
          pure
            ModpackImportResponse
              { modpackImportImported = True
              , modpackImportResponseTargetGameDir = targetGameDir
              , modpackImportResponseStagingPath = stagingPath
              , modpackImportResponseLockfilePath = lockfilePath
              , modpackImportResponseFilesWritten = written
              , modpackImportResponseWarnings = modpackPreflightWarnings preflight
              , modpackImportBlockingReasons = []
              , modpackImportTypedPlan = plan
              }
  where
    targetGameDir = modpackImportTargetGameDir request
    stagingPath = modpackStagingPath targetGameDir
    lockfilePath = targetGameDir </> "modpack-install-lock.json"
    modpackImportBlocked preflight plan reasons =
      ModpackImportResponse
        { modpackImportImported = False
        , modpackImportResponseTargetGameDir = targetGameDir
        , modpackImportResponseStagingPath = stagingPath
        , modpackImportResponseLockfilePath = lockfilePath
        , modpackImportResponseFilesWritten = 0
        , modpackImportResponseWarnings = modpackPreflightWarnings preflight
        , modpackImportBlockingReasons = stableTextSetCompat reasons
        , modpackImportTypedPlan = plan
        }
    runModpackImport preflight plan = do
      createDirectoryIfMissing True stagingPath
      runModpackDownloads manager stagingPath plan
      writeModpackOverrides (modpackImportSourcePath request) stagingPath plan
      let entries = modpackLockEntries plan
      writeModpackLockfile (stagingPath </> "modpack-install-lock.json") request preflight plan entries
      createDirectoryIfMissing True (takeDirectory targetGameDir)
      renameDirectory stagingPath targetGameDir
      pure (length entries + 1)

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

parseLocalModpack :: FilePath -> Maybe FilePath -> IO ModpackPreflightResponse
parseLocalModpack path targetGameDir
  | takeExtension path == ".mrpack" = parseModrinthPack path targetGameDir
  | otherwise = parseCurseForgePack path targetGameDir

parseModrinthPack :: FilePath -> Maybe FilePath -> IO ModpackPreflightResponse
parseModrinthPack path targetGameDir = do
  indexText <- unzipText path "modrinth.index.json"
  names <- unzipNames path
  case eitherDecode (LBS.pack indexText) of
    Left err ->
      pure (invalid ["modrinth_index_parse_failed:" <> Text.pack err])
    Right value -> do
      let dependencies = parseMaybe modrinthDependencies value
          files = stableSortPackages modpackFileKey (fromMaybe [] (parseMaybe modrinthFiles value))
          paths = map mrpackFilePath files
          archiveNames = stableSortOnText id (map Text.pack names)
          overrides = stableSortOnText id (filter isOverrideArchiveEntry archiveNames)
          serverIndicators = serverPackIndicators (Just "overrides/") archiveNames
          countPrefix prefix = length (filter (Text.isPrefixOf prefix) paths)
          warnings =
            ["target_game_dir_missing" | targetGameDir == Nothing]
              <> serverPackWarnings serverIndicators
          blocking =
            ["target_game_dir_required" | targetGameDir == Nothing]
              <> ["server_pack_not_supported" | not (null serverIndicators)]
      overrideConflicts <- modpackOverrideConflicts targetGameDir overrides
      pure
        ModpackPreflightResponse
          { modpackPreflightValid = null blocking
          , modpackPreflightName = parseMaybe fieldName value
          , modpackPreflightMinecraftVersion = dependencies >>= lookupText "minecraft"
          , modpackPreflightLoader = dependencies >>= loaderFromDependencies
          , modpackPreflightLoaderVersion = dependencies >>= loaderVersionFromDependencies
          , modpackPreflightModCount = countPrefix "mods/"
          , modpackPreflightResourcePackCount = countPrefix "resourcepacks/"
          , modpackPreflightShaderPackCount = countPrefix "shaderpacks/"
          , modpackPreflightOverridesCount = length overrides
          , modpackPreflightEstimatedDownloadBytes = sumMaybe (map mrpackFileSize files)
          , modpackPreflightRequiresApiKey = False
          , modpackPreflightWarnings = warnings
          , modpackPreflightBlockingReasons = blocking
          , modpackPreflightTypedPlan =
              modpackPlanSkeleton
                "modrinth"
                (parseMaybe fieldName value)
                (dependencies >>= lookupText "minecraft")
                (dependencies >>= loaderFromDependencies)
                (dependencies >>= loaderVersionFromDependencies)
                targetGameDir
                files
                overrides
                overrideConflicts
                warnings
                blocking
          }
  where
    invalid reasons =
      emptyModpackResponse
        { modpackPreflightBlockingReasons = reasons
        }

parseCurseForgePack :: FilePath -> Maybe FilePath -> IO ModpackPreflightResponse
parseCurseForgePack path targetGameDir = do
  manifestText <- unzipText path "manifest.json"
  names <- unzipNames path
  case eitherDecode (LBS.pack manifestText) of
    Left err ->
      pure emptyModpackResponse { modpackPreflightBlockingReasons = ["curseforge_manifest_parse_failed:" <> Text.pack err] }
    Right value -> do
      let modLoaders = fromMaybe [] (parseMaybe curseModLoaders value)
          primaryLoader = find snd modLoaders <|> listToMaybeCompat modLoaders
          files = stableSortPackages curseFileKey (fromMaybe [] (parseMaybe curseFiles value))
          overridesDir = fromMaybe "overrides" (parseMaybe curseOverrides value)
          overridePrefix = Text.pack overridesDir <> "/"
          archiveNames = stableSortOnText id (map Text.pack names)
          overrideNames = stableSortOnText id (filter (isOverrideArchiveEntryWithPrefix overridePrefix) archiveNames)
          serverIndicators = serverPackIndicators (Just overridePrefix) archiveNames
          warnings =
            [ "CurseForge manifest files require a personal CurseForge API key before download."
            ]
              <> ["target_game_dir_missing" | targetGameDir == Nothing]
              <> serverPackWarnings serverIndicators
          blocking =
            "curseforge_api_key_required"
              : ["target_game_dir_required" | targetGameDir == Nothing]
              <> ["server_pack_not_supported" | not (null serverIndicators)]
      overrideConflicts <- modpackOverrideConflicts targetGameDir overrideNames
      pure
        ModpackPreflightResponse
          { modpackPreflightValid = False
          , modpackPreflightName = parseMaybe fieldName value
          , modpackPreflightMinecraftVersion = parseMaybe curseMinecraftVersion value
          , modpackPreflightLoader = fst <$> primaryLoader >>= loaderNameFromId
          , modpackPreflightLoaderVersion = fst <$> primaryLoader >>= loaderVersionFromId
          , modpackPreflightModCount = length files
          , modpackPreflightResourcePackCount = 0
          , modpackPreflightShaderPackCount = 0
          , modpackPreflightOverridesCount = length overrideNames
          , modpackPreflightEstimatedDownloadBytes = Nothing
          , modpackPreflightRequiresApiKey = True
          , modpackPreflightWarnings = warnings
          , modpackPreflightBlockingReasons = blocking
          , modpackPreflightTypedPlan =
              modpackPlanSkeleton
                "curseforge"
                (parseMaybe fieldName value)
                (parseMaybe curseMinecraftVersion value)
                (fst <$> primaryLoader >>= loaderNameFromId)
                (fst <$> primaryLoader >>= loaderVersionFromId)
                targetGameDir
                (map curseFileToMrpackFile files)
                overrideNames
                overrideConflicts
                warnings
                blocking
          }

emptyModpackResponse :: ModpackPreflightResponse
emptyModpackResponse =
  ModpackPreflightResponse
    { modpackPreflightValid = False
    , modpackPreflightName = Nothing
    , modpackPreflightMinecraftVersion = Nothing
    , modpackPreflightLoader = Nothing
    , modpackPreflightLoaderVersion = Nothing
    , modpackPreflightModCount = 0
    , modpackPreflightResourcePackCount = 0
    , modpackPreflightShaderPackCount = 0
    , modpackPreflightOverridesCount = 0
    , modpackPreflightEstimatedDownloadBytes = Nothing
    , modpackPreflightRequiresApiKey = False
    , modpackPreflightWarnings = []
    , modpackPreflightBlockingReasons = []
    , modpackPreflightTypedPlan = modpackPlanSkeleton "modpack" Nothing Nothing Nothing Nothing Nothing [] [] [] [] []
    }

data ModpackPlanFile = ModpackPlanFile
  { mrpackFilePath :: Text
  , mrpackFileSize :: Maybe Int64
  , mrpackFileUrl :: Maybe Text
  , mrpackFileSha1 :: Maybe Text
  } deriving (Eq, Show)

data CurseManifestFile = CurseManifestFile
  { curseManifestProjectId :: Int
  , curseManifestFileId :: Int
  } deriving (Eq, Show)

modpackFileKey :: ModpackPlanFile -> Text
modpackFileKey file =
  Text.intercalate
    "|"
    [ mrpackFilePath file
    , fromMaybe "" (mrpackFileSha1 file)
    , fromMaybe "" (mrpackFileUrl file)
    , maybe "" (Text.pack . show) (mrpackFileSize file)
    ]

curseFileKey :: CurseManifestFile -> Text
curseFileKey file =
  Text.pack (show (curseManifestProjectId file))
    <> "|"
    <> Text.pack (show (curseManifestFileId file))

fieldName :: Value -> Parser Text
fieldName = withObject "NamedValue" $ \obj -> obj .:? "name" .!= "Imported Modpack"

modrinthDependencies :: Value -> Parser [(Text, Text)]
modrinthDependencies =
  withObject "ModrinthIndex" $ \obj ->
    obj .: "dependencies" >>= withObject "dependencies" (traverseKeyValues)

modrinthFiles :: Value -> Parser [ModpackPlanFile]
modrinthFiles =
  withObject "ModrinthIndex" $ \obj ->
    obj .:? "files" .!= [] >>= traverse parseFile
  where
    parseFile =
      withObject "ModrinthFile" $ \obj ->
        ModpackPlanFile
          <$> obj .: "path"
          <*> obj .:? "fileSize"
          <*> (obj .:? "downloads" .!= [] >>= pure . listToMaybeCompat)
          <*> (obj .:? "hashes" .!= Object mempty >>= withObject "hashes" (.:? "sha1"))

curseFiles :: Value -> Parser [CurseManifestFile]
curseFiles =
  withObject "CurseManifest" $ \obj ->
    obj .:? "files" .!= [] >>= traverse parseFile
  where
    parseFile =
      withObject "CurseFile" $ \obj ->
        CurseManifestFile
          <$> obj .: "projectID"
          <*> obj .: "fileID"

curseFileToMrpackFile :: CurseManifestFile -> ModpackPlanFile
curseFileToMrpackFile file =
  ModpackPlanFile
    { mrpackFilePath =
        "mods/curseforge-"
          <> Text.pack (show (curseManifestProjectId file))
          <> "-"
          <> Text.pack (show (curseManifestFileId file))
          <> ".jar"
    , mrpackFileSize = Nothing
    , mrpackFileUrl = Nothing
    , mrpackFileSha1 = Nothing
    }

modpackPlanSkeleton :: Text -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe FilePath -> [ModpackPlanFile] -> [Text] -> [Text] -> [Text] -> [Text] -> Plan.TypedInstallPlan
modpackPlanSkeleton source name minecraftVersion loader loaderVersion targetGameDir files overrides overrideConflicts warnings blockedReasons =
  Plan.finalizeTypedInstallPlan
    Plan.TypedInstallPlan
      { Plan.typedPlanId = ""
      , Plan.typedPlanFingerprint = ""
      , Plan.typedPlanKind = "modpack"
      , Plan.typedPlanTitle = fromMaybe "Imported Modpack" name
      , Plan.typedPlanTargetGameDir = targetGameDir
      , Plan.typedPlanSource = Just source
      , Plan.typedPlanStatus = ""
      , Plan.typedPlanSummary = Plan.InstallPlanSummary 0 0 0 0 0 Nothing
      , Plan.typedPlanNodes = directoryNodes <> dependencyNodes <> fileNodes <> overrideNodes <> lockNodes
      , Plan.typedPlanEdges = dependencyEdges <> lockEdges
      , Plan.typedPlanWarnings = warnings
      , Plan.typedPlanBlockedReasons = blockedReasons
      , Plan.typedPlanDiagnostics = []
      , Plan.typedPlanRollbackPolicy = "staging"
      }
  where
    stagingId = "modpack-staging"
    minecraftId = "modpack-minecraft"
    loaderId = "modpack-loader"
    lockId = "modpack-lockfile"
    dependencyIds = stagingId : minecraftId : [loaderId | loader /= Nothing]
    directoryNodes =
      [ Plan.InstallPlanNode
          { Plan.installNodeId = stagingId
          , Plan.installNodeKind = "directory"
          , Plan.installNodeAction = "write"
          , Plan.installNodePhase = "staging"
          , Plan.installNodeLabel = "Create staging directory"
          , Plan.installNodeTargetPath = modpackStagingPath <$> targetGameDir
          , Plan.installNodeSourceUrls = []
          , Plan.installNodeSha1 = Nothing
          , Plan.installNodeSize = Nothing
          , Plan.installNodeRequired = True
          , Plan.installNodeDependsOn = []
          , Plan.installNodeVerifications = [Plan.InstallVerification "targetInsideGameDir" "pending" Nothing]
          , Plan.installNodeRollback =
              Plan.InstallPlanRollbackAction
                { Plan.installRollbackAction = "deleteEmptyDirectory"
                , Plan.installRollbackTargetPath = modpackStagingPath <$> targetGameDir
                , Plan.installRollbackBackupPath = Nothing
                , Plan.installRollbackReason = Nothing
                }
          , Plan.installNodeBlockedReason = firstText ["target_game_dir_required" | targetGameDir == Nothing]
          , Plan.installNodeDiagnostics = []
          }
      ]
    dependencyNodes =
      [ Plan.InstallPlanNode
          { Plan.installNodeId = minecraftId
          , Plan.installNodeKind = "minecraftVersion"
          , Plan.installNodeAction = "verify"
          , Plan.installNodePhase = "metadata"
          , Plan.installNodeLabel = fromMaybe "Minecraft version" minecraftVersion
          , Plan.installNodeTargetPath = targetGameDir
          , Plan.installNodeSourceUrls = []
          , Plan.installNodeSha1 = Nothing
          , Plan.installNodeSize = Nothing
          , Plan.installNodeRequired = True
          , Plan.installNodeDependsOn = [stagingId]
          , Plan.installNodeVerifications =
              [ Plan.InstallVerification "minecraftVersionCompatible" (if minecraftVersion == Nothing then "error" else "ok") minecraftVersion
              ]
          , Plan.installNodeRollback = noModpackRollback "Minecraft version is a prerequisite, not a direct write."
          , Plan.installNodeBlockedReason = firstText ["minecraft_version_missing" | minecraftVersion == Nothing]
          , Plan.installNodeDiagnostics = []
          }
      ]
        <> [ Plan.InstallPlanNode
              { Plan.installNodeId = loaderId
              , Plan.installNodeKind = "loaderProfile"
              , Plan.installNodeAction = "verify"
              , Plan.installNodePhase = "loader"
              , Plan.installNodeLabel = fromMaybe "Mod loader" loader
              , Plan.installNodeTargetPath = targetGameDir
              , Plan.installNodeSourceUrls = []
              , Plan.installNodeSha1 = Nothing
              , Plan.installNodeSize = Nothing
              , Plan.installNodeRequired = True
              , Plan.installNodeDependsOn = [minecraftId]
              , Plan.installNodeVerifications =
                  [ Plan.InstallVerification "loaderCompatible" (if loader == Nothing then "warning" else "ok") loaderVersion
                  ]
              , Plan.installNodeRollback = noModpackRollback "Loader profile is a prerequisite, not a direct write."
              , Plan.installNodeBlockedReason = Nothing
              , Plan.installNodeDiagnostics = []
              }
           | loader /= Nothing
           ]
    sortedFiles = stableSortPackages modpackFileKey files
    sortedOverrides = stableSortOnText id overrides
    sortedOverrideConflicts = stableTextSet overrideConflicts
    fileNodes =
      [ modpackFileNode file dependencyIds
      | file <- sortedFiles
      ]
    overrideNodes =
      [ modpackOverrideNode override dependencyIds (override `elem` sortedOverrideConflicts)
      | override <- sortedOverrides
      ]
    lockNodes =
      [ Plan.InstallPlanNode
          { Plan.installNodeId = lockId
          , Plan.installNodeKind = "rollbackMarker"
          , Plan.installNodeAction = "write"
          , Plan.installNodePhase = "commit"
          , Plan.installNodeLabel = "Write modpack-install-lock.json"
          , Plan.installNodeTargetPath = (</> "modpack-install-lock.json") <$> targetGameDir
          , Plan.installNodeSourceUrls = []
          , Plan.installNodeSha1 = Nothing
          , Plan.installNodeSize = Nothing
          , Plan.installNodeRequired = True
          , Plan.installNodeDependsOn = map Plan.installNodeId (fileNodes <> overrideNodes)
          , Plan.installNodeVerifications = [Plan.InstallVerification "backupWritable" "pending" Nothing]
          , Plan.installNodeRollback = noModpackRollback "Lockfile is written after staging commit."
          , Plan.installNodeBlockedReason = Nothing
          , Plan.installNodeDiagnostics = []
          }
      ]
    dependencyEdges =
      [ Plan.InstallPlanEdge dependencyId nodeId "requires" True
      | node <- fileNodes <> overrideNodes
      , nodeId <- [Plan.installNodeId node]
      , dependencyId <- Plan.installNodeDependsOn node
      ]
    lockEdges =
      [ Plan.InstallPlanEdge (Plan.installNodeId node) lockId "requires" True
      | node <- fileNodes <> overrideNodes
      ]

modpackFileNode :: ModpackPlanFile -> [Text] -> Plan.InstallPlanNode
modpackFileNode file dependencyIds =
  Plan.InstallPlanNode
    { Plan.installNodeId = "modpack-file-" <> Text.take 16 (stableFingerprint (object ["file" .= modpackFileKey file]))
    , Plan.installNodeKind = modpackNodeKindForPath (mrpackFilePath file)
    , Plan.installNodeAction = "download"
    , Plan.installNodePhase = "files"
    , Plan.installNodeLabel = mrpackFilePath file
    , Plan.installNodeTargetPath = Just (Text.unpack (mrpackFilePath file))
    , Plan.installNodeSourceUrls = maybe [] (: []) (mrpackFileUrl file)
    , Plan.installNodeSha1 = mrpackFileSha1 file
    , Plan.installNodeSize = mrpackFileSize file
    , Plan.installNodeRequired = True
    , Plan.installNodeDependsOn = dependencyIds
    , Plan.installNodeVerifications =
        [ Plan.InstallVerification "urlAllowed" (if maybe False isAllowedModpackUrl (mrpackFileUrl file) then "ok" else "error") Nothing
        , Plan.InstallVerification "hashKnown" (if mrpackFileSha1 file == Nothing then "error" else "ok") Nothing
        , Plan.InstallVerification "sizeKnown" (if mrpackFileSize file == Nothing then "warning" else "ok") Nothing
        ]
    , Plan.installNodeRollback =
        Plan.InstallPlanRollbackAction
          { Plan.installRollbackAction = "removeCreatedFile"
          , Plan.installRollbackTargetPath = Just (Text.unpack (mrpackFilePath file))
          , Plan.installRollbackBackupPath = Nothing
          , Plan.installRollbackReason = Nothing
          }
    , Plan.installNodeBlockedReason =
        if mrpackFileUrl file == Nothing || mrpackFileSha1 file == Nothing
          then Just "modpack_file_download_unresolved"
          else Nothing
    , Plan.installNodeDiagnostics = []
    }

modpackOverrideNode :: Text -> [Text] -> Bool -> Plan.InstallPlanNode
modpackOverrideNode override dependencyIds hasConflict =
  Plan.InstallPlanNode
    { Plan.installNodeId = "modpack-override-" <> Text.take 16 (stableFingerprint (object ["override" .= override]))
    , Plan.installNodeKind = "overrideFile"
    , Plan.installNodeAction = if hasConflict then "replace" else "write"
    , Plan.installNodePhase = "overrides"
    , Plan.installNodeLabel = override
    , Plan.installNodeTargetPath = Just (Text.unpack (dropOverridePrefix override))
    , Plan.installNodeSourceUrls = []
    , Plan.installNodeSha1 = Nothing
    , Plan.installNodeSize = Nothing
    , Plan.installNodeRequired = True
    , Plan.installNodeDependsOn = dependencyIds
    , Plan.installNodeVerifications =
        [ Plan.InstallVerification "targetInsideGameDir" "pending" Nothing
        ]
          <> [ Plan.InstallVerification "backupWritable" "pending" (Just "override_conflict_replace")
             | hasConflict
             ]
    , Plan.installNodeRollback =
        Plan.InstallPlanRollbackAction
          { Plan.installRollbackAction = if hasConflict then "restoreBackup" else "removeCreatedFile"
          , Plan.installRollbackTargetPath = Just (Text.unpack (dropOverridePrefix override))
          , Plan.installRollbackBackupPath = if hasConflict then Just (Text.unpack (dropOverridePrefix override) <> ".panino-backup") else Nothing
          , Plan.installRollbackReason = Nothing
          }
    , Plan.installNodeBlockedReason = Nothing
    , Plan.installNodeDiagnostics = []
    }

modpackNodeKindForPath :: Text -> Text
modpackNodeKindForPath path
  | "mods/" `Text.isPrefixOf` path = "mod"
  | "resourcepacks/" `Text.isPrefixOf` path = "resourcePack"
  | "shaderpacks/" `Text.isPrefixOf` path = "shaderPack"
  | otherwise = "overrideFile"

dropOverridePrefix :: Text -> Text
dropOverridePrefix path =
  fromMaybe path (Text.stripPrefix "overrides/" path)

modpackOverrideConflicts :: Maybe FilePath -> [Text] -> IO [Text]
modpackOverrideConflicts Nothing _ =
  pure []
modpackOverrideConflicts (Just targetGameDir) overrides =
  stableSortOnText id <$> filterM hasConflict overrides
  where
    hasConflict override = do
      let target = targetGameDir </> Text.unpack (dropOverridePrefix override)
      fileExists <- doesFileExist target
      directoryExists <- doesDirectoryExist target
      pure (fileExists || directoryExists)

serverPackWarnings :: [Text] -> [Text]
serverPackWarnings indicators =
  [ "server_pack_detected:" <> Text.intercalate "," (take 5 indicators)
  | not (null indicators)
  ]

serverPackIndicators :: Maybe Text -> [Text] -> [Text]
serverPackIndicators overridePrefix names =
  stableTextSetCompat
    [ normalized
    | name <- names
    , candidate <- normalizeArchivePath name : strippedCandidates name
    , let normalized = candidate
    , isServerPackPath normalized
    ]
  where
    strippedCandidates name =
      case overridePrefix >>= (\prefix -> Text.stripPrefix (normalizeArchivePath prefix) (normalizeArchivePath name)) of
        Just stripped -> [stripped]
        Nothing -> []

isServerPackPath :: Text -> Bool
isServerPackPath path =
  path `elem` serverRootFiles
  where
    serverRootFiles =
      [ "server.properties"
      , "eula.txt"
      , "ops.json"
      , "whitelist.json"
      , "banned-ips.json"
      , "banned-players.json"
      , "start.sh"
      , "start.bat"
      , "run.sh"
      , "run.bat"
      , "server.jar"
      ]

normalizeArchivePath :: Text -> Text
normalizeArchivePath =
  Text.toLower . Text.replace "\\" "/"

isOverrideArchiveEntry :: Text -> Bool
isOverrideArchiveEntry =
  isOverrideArchiveEntryWithPrefix "overrides/"

isOverrideArchiveEntryWithPrefix :: Text -> Text -> Bool
isOverrideArchiveEntryWithPrefix prefix path =
  prefix `Text.isPrefixOf` path && not ("/" `Text.isSuffixOf` path)

isAllowedModpackUrl :: Text -> Bool
isAllowedModpackUrl value =
  "https://" `Text.isPrefixOf` Text.toLower value || "http://" `Text.isPrefixOf` Text.toLower value

noModpackRollback :: Text -> Plan.InstallPlanRollbackAction
noModpackRollback reason =
  Plan.InstallPlanRollbackAction
    { Plan.installRollbackAction = "noneWithReason"
    , Plan.installRollbackTargetPath = Nothing
    , Plan.installRollbackBackupPath = Nothing
    , Plan.installRollbackReason = Just reason
    }

firstText :: [Text] -> Maybe Text
firstText [] = Nothing
firstText (value:_) = Just value

modpackStagingPath :: FilePath -> FilePath
modpackStagingPath targetGameDir =
  targetGameDir <> ".panino-modpack-staging"

runModpackDownloads :: Manager -> FilePath -> Plan.TypedInstallPlan -> IO ()
runModpackDownloads manager stagingPath plan = do
  jobs <- forM downloadNodes (modpackDownloadJob stagingPath)
  unless (null jobs) $
    runDownloadJobsWithOptionsAndProgressAndCancel
      manager
      (downloadOptionsWithOverrides (Just 4) (Just 0))
      (pure False)
      jobs
      (const (pure ()))
      >> pure ()
  where
    downloadNodes =
      filter ((== "download") . Plan.installNodeAction) (Plan.typedPlanNodes plan)

modpackDownloadJob :: FilePath -> Plan.InstallPlanNode -> IO DownloadJob
modpackDownloadJob stagingPath node =
  case (Plan.installNodeTargetPath node, listToMaybeCompat (Plan.installNodeSourceUrls node)) of
    (Just relativePath, Just url)
      | safeRelativePath relativePath ->
          pure
            DownloadJob
              { jobLabel = Text.unpack (Plan.installNodeLabel node)
              , jobUrl = Text.unpack url
              , jobTargetPath = stagingPath </> normalise relativePath
              , jobSha1 = Plan.installNodeSha1 node
              , jobSize = Plan.installNodeSize node
              }
    _ ->
      fail ("modpack download node is incomplete: " <> Text.unpack (Plan.installNodeId node))

writeModpackOverrides :: FilePath -> FilePath -> Plan.TypedInstallPlan -> IO ()
writeModpackOverrides archive stagingPath plan =
  forM_ overrideNodes $ \node ->
    case Plan.installNodeTargetPath node of
      Just relativePath
        | safeRelativePath relativePath ->
            unzipEntryToFile
              archive
              (Text.unpack (Plan.installNodeLabel node))
              (stagingPath </> normalise relativePath)
      _ ->
        fail ("modpack override node has unsafe target path: " <> Text.unpack (Plan.installNodeId node))
  where
    overrideNodes =
      [ node
      | node <- Plan.typedPlanNodes plan
      , Plan.installNodeKind node == "overrideFile"
      , Plan.installNodeAction node `elem` ["write", "replace"]
      ]

unzipEntryToFile :: FilePath -> FilePath -> FilePath -> IO ()
unzipEntryToFile archive entry target = do
  createDirectoryIfMissing True (takeDirectory target)
  withBinaryFile target WriteMode $ \handle -> do
    (_, _, _, processHandle) <-
      createProcess
        (proc "/usr/bin/unzip" ["-p", archive, entry])
          { std_out = UseHandle handle
          }
    exitCode <- waitForProcess processHandle
    case exitCode of
      ExitSuccess -> pure ()
      ExitFailure _ -> fail ("could not extract " <> entry <> " from " <> archive)

writeModpackLockfile :: FilePath -> ModpackImportRequest -> ModpackPreflightResponse -> Plan.TypedInstallPlan -> [ModpackImportLockEntry] -> IO ()
writeModpackLockfile path request preflight plan entries = do
  createDirectoryIfMissing True (takeDirectory path)
  LBS.writeFile
    path
    ( encode
        ( object
            [ "planId" .= Plan.typedPlanId plan
            , "fingerprint" .= Plan.typedPlanFingerprint plan
            , "sourceType" .= modpackImportSourceType request
            , "sourcePath" .= modpackImportSourcePath request
            , "targetGameDir" .= modpackImportTargetGameDir request
            , "name" .= modpackPreflightName preflight
            , "minecraftVersion" .= modpackPreflightMinecraftVersion preflight
            , "loader" .= modpackPreflightLoader preflight
            , "loaderVersion" .= modpackPreflightLoaderVersion preflight
            , "files" .= entries
            ]
        )
    )

modpackLockEntries :: Plan.TypedInstallPlan -> [ModpackImportLockEntry]
modpackLockEntries plan =
  stableSortPackages modpackLockEntryKey
    [ ModpackImportLockEntry
        { modpackLockEntryPath = relativePath
        , modpackLockEntryKind = Plan.installNodeKind node
        , modpackLockEntrySha1 = Plan.installNodeSha1 node
        , modpackLockEntrySize = Plan.installNodeSize node
        , modpackLockEntrySource = listToMaybeCompat (Plan.installNodeSourceUrls node)
        }
    | node <- Plan.typedPlanNodes plan
    , Plan.installNodeAction node `elem` ["download", "write", "replace"]
    , Plan.installNodeKind node `notElem` ["directory", "rollbackMarker"]
    , Just relativePath <- [Plan.installNodeTargetPath node]
    , safeRelativePath relativePath
    ]

modpackLockEntryKey :: ModpackImportLockEntry -> Text
modpackLockEntryKey entry =
  Text.intercalate
    "|"
    [ Text.pack (modpackLockEntryPath entry)
    , modpackLockEntryKind entry
    , fromMaybe "" (modpackLockEntrySha1 entry)
    , fromMaybe "" (modpackLockEntrySource entry)
    ]

unsafePlanTargetReasons :: Plan.TypedInstallPlan -> [Text]
unsafePlanTargetReasons plan =
  [ "unsafe_target_path:" <> Plan.installNodeId node
  | node <- Plan.typedPlanNodes plan
  , Plan.installNodeAction node `elem` ["download", "replace", "write", "extract", "patch", "delete"]
  , Plan.installNodeKind node `notElem` ["directory", "rollbackMarker"]
  , maybe True (not . safeRelativePath) (Plan.installNodeTargetPath node)
  ]

safeRelativePath :: FilePath -> Bool
safeRelativePath path =
  let normalized = normalise path
      originalParts = splitDirectories path
      normalizedParts = splitDirectories normalized
   in not (null path)
        && normalized /= "."
        && isRelative normalized
        && ".." `notElem` originalParts
        && ".." `notElem` normalizedParts

removePathIfExists :: FilePath -> IO ()
removePathIfExists path = do
  directoryExists <- doesDirectoryExist path
  when directoryExists (removeDirectoryRecursive path)
  fileExists <- doesFileExist path
  when (fileExists && not directoryExists) (removeFile path)

stableTextSetCompat :: [Text] -> [Text]
stableTextSetCompat =
  foldr insertSorted [] . sort
  where
    insertSorted value values
      | value `elem` values = values
      | otherwise = value : values

curseMinecraftVersion :: Value -> Parser Text
curseMinecraftVersion =
  withObject "CurseManifest" $ \obj ->
    obj .: "minecraft" >>= withObject "minecraft" (.: "version")

curseModLoaders :: Value -> Parser [(Text, Bool)]
curseModLoaders =
  withObject "CurseManifest" $ \obj ->
    obj .: "minecraft" >>= withObject "minecraft" (\minecraft -> minecraft .:? "modLoaders" .!= [] >>= traverse parseLoader)
  where
    parseLoader =
      withObject "CurseLoader" $ \obj ->
        (,)
          <$> obj .: "id"
          <*> obj .:? "primary" .!= False

curseOverrides :: Value -> Parser FilePath
curseOverrides =
  withObject "CurseManifest" $ \obj -> obj .:? "overrides" .!= "overrides"

traverseKeyValues :: Object -> Parser [(Text, Text)]
traverseKeyValues objectValue =
  pure
    [ (key, value)
    | (key, String value) <- objectToList objectValue
    ]

objectToList :: Object -> [(Text, Value)]
objectToList =
  stableSortOnText fst . map (\(key, value) -> (Key.toText key, value)) . KeyMap.toList

lookupText :: Text -> [(Text, Text)] -> Maybe Text
lookupText key values = lookup key values

loaderFromDependencies :: [(Text, Text)] -> Maybe Text
loaderFromDependencies values =
  normalizeLoaderKey . fst <$> find ((`elem` ["fabric-loader", "forge", "quilt-loader", "neoforge"]) . fst) values

loaderVersionFromDependencies :: [(Text, Text)] -> Maybe Text
loaderVersionFromDependencies values =
  snd <$> find ((`elem` ["fabric-loader", "forge", "quilt-loader", "neoforge"]) . fst) values

normalizeLoaderKey :: Text -> Text
normalizeLoaderKey "fabric-loader" = "fabric"
normalizeLoaderKey "quilt-loader" = "quilt"
normalizeLoaderKey "neoforge" = "neoForge"
normalizeLoaderKey value = value

loaderNameFromId :: Text -> Maybe Text
loaderNameFromId value
  | "fabric" `Text.isPrefixOf` value = Just "fabric"
  | "forge" `Text.isPrefixOf` value = Just "forge"
  | "quilt" `Text.isPrefixOf` value = Just "quilt"
  | "neoforge" `Text.isPrefixOf` Text.toLower value = Just "neoForge"
  | otherwise = Nothing

loaderVersionFromId :: Text -> Maybe Text
loaderVersionFromId value =
  case Text.splitOn "-" value of
    _loader : versionParts | not (null versionParts) -> Just (Text.intercalate "-" versionParts)
    _ -> Nothing

unzipText :: FilePath -> FilePath -> IO String
unzipText archive entry = do
  (exitCode, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc "/usr/bin/unzip" ["-p", archive, entry]) ""
  case exitCode of
    ExitSuccess -> pure stdoutText
    ExitFailure _ -> fail ("could not read " <> entry <> " from " <> archive <> ": " <> stderrText)

unzipNames :: FilePath -> IO [FilePath]
unzipNames archive = do
  result <- try (readCreateProcessWithExitCode (proc "/usr/bin/unzip" ["-Z1", archive]) "") :: IO (Either IOError (ExitCode, String, String))
  case result of
    Right (ExitSuccess, stdoutText, _) -> pure (sort (lines stdoutText))
    _ -> pure []

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

sumMaybe :: [Maybe Int64] -> Maybe Int64
sumMaybe values =
  if any (== Nothing) values
    then Nothing
    else Just (sum (mapMaybe id values))

listToMaybeCompat :: [a] -> Maybe a
listToMaybeCompat [] = Nothing
listToMaybeCompat (value : _) = Just value

(<|>) :: Maybe a -> Maybe a -> Maybe a
Just value <|> _ = Just value
Nothing <|> fallback = fallback
