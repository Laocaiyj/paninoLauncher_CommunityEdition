{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Configuration.Modpack
  ( modpackImport
  , modpackPreflight
  ) where

import Control.Applicative ((<|>))
import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson (eitherDecode)
import Data.Aeson.Types (parseMaybe)
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.Foldable (find)
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  )
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Configuration.Modpack.Import
  ( modpackLockEntries
  , removePathIfExists
  , runModpackDownloads
  , writeModpackLockfile
  , writeModpackOverrides
  )
import Panino.Content.Configuration.Modpack.Manifest
import Panino.Content.Configuration.Modpack.Plan
  ( isOverrideArchiveEntry
  , isOverrideArchiveEntryWithPrefix
  , modpackOverrideConflicts
  , modpackPlanSkeleton
  , modpackStagingPath
  , serverPackIndicators
  , serverPackWarnings
  , stableTextSetCompat
  , unsafePlanTargetReasons
  )
import Panino.Content.Configuration.Types
import Panino.CoreLogic.Determinism
  ( stableSortOnText
  , stableSortPackages
  )
import qualified Panino.Install.Plan.Types as Plan
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , renameDirectory
  )
import System.FilePath
  ( takeDirectory
  , takeExtension
  , (</>)
  )

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
            { Plan.typedPlanTargetGameDir = Plan.typedPlanTargetGameDirFromPath (Just targetGameDir)
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
          primaryLoader = find snd modLoaders <|> listToMaybe modLoaders
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
