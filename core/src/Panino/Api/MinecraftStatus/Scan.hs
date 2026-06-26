{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.MinecraftStatus.Scan
  ( fetchInstalledMinecraftInstances
  , fetchMinecraftInstallStatus
  ) where

import Control.Exception (IOException, catch)
import Control.Monad (filterM)
import Data.Aeson
  ( FromJSON(..)
  , eitherDecode'
  , withObject
  , (.:)
  )
import qualified Data.ByteString.Lazy as BL
import Data.Char (isAlphaNum)
import Data.List (sortOn)
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.MinecraftStatus.Types
  ( MinecraftInstallStatusRequest(..)
  , MinecraftInstalledInstance(..)
  , MinecraftVersionInstallStatus(..)
  )
import Panino.Minecraft.InstanceMetadata
  ( InstanceMetadata(..)
  , readInstanceMetadata
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout
  , minecraftRoot
  , mkLayout
  )
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , getFileSize
  , listDirectory
  )
import System.FilePath (dropExtension, takeExtension, takeFileName, (</>))

fetchMinecraftInstallStatus :: Maybe FilePath -> MinecraftInstallStatusRequest -> IO [MinecraftVersionInstallStatus]
fetchMinecraftInstallStatus defaultGameDir request = do
  defaultLayout <- mkLayout Nothing
  candidateRoots <-
    expandCandidateRoots $
        uniqueNonEmptyPaths
          (candidateInputRoots defaultGameDir defaultLayout request)
  traverse (minecraftVersionInstallStatus candidateRoots) (installStatusVersionIds request)

fetchInstalledMinecraftInstances :: Maybe FilePath -> MinecraftInstallStatusRequest -> IO [MinecraftInstalledInstance]
fetchInstalledMinecraftInstances defaultGameDir request = do
  defaultLayout <- mkLayout Nothing
  candidateRoots <-
    expandCandidateRoots $
        uniqueNonEmptyPaths
          (candidateInputRoots defaultGameDir defaultLayout request)
  discoveredVersionIds <- uniqueTexts . concat <$> traverse installedVersionIdsInRoot candidateRoots
  let versionIds = uniqueTexts (installStatusVersionIds request <> discoveredVersionIds)
  statuses <- concat <$> traverse (installedInRoot versionIds) candidateRoots
  traverse instanceWithDiskUsage statuses
  where
    installedInRoot versionIds root = do
      localDirectory <- localInstanceDirectory root
      recognizedVersionIds <-
        if localDirectory
          then canonicalLocalVersionIds root
          else pure versionIds
      let statusVersionIds =
            if localDirectory
              then filter (`elem` recognizedVersionIds) versionIds
              else versionIds
      filter (rootIsRecognized localDirectory) <$> traverse (`versionRootStatus` root) statusVersionIds
    rootIsComplete status =
      rootVersionJson status && rootClientJar status && not (rootArchived status) && not (rootInstallFailed status)
    rootIsRecognized localDirectory status =
      if localDirectory
        then rootHasVersion status && not (rootArchived status)
        else rootIsComplete status
    instanceWithDiskUsage status = do
      diskUsage <- directorySizeRecursive (rootVersionPath status)
      fallbackMetadata <- readInstanceMetadata (rootBasePath status) (rootVersionId status)
      metadata <- inferInstanceMetadata (rootBasePath status) fallbackMetadata
      pure
        MinecraftInstalledInstance
          { installedInstanceVersionId = metadataLaunchVersion metadata
          , installedInstanceMinecraftVersion = metadataMinecraftVersion metadata
          , installedInstanceLoader = metadataLoader metadata
          , installedInstanceLoaderVersion = metadataLoaderVersion metadata
          , installedInstanceName = metadataName metadata
          , installedInstanceGameDir = rootBasePath status
          , installedInstanceVersionJson = rootVersionJson status && not (rootInstallFailed status)
          , installedInstanceClientJar = rootClientJar status && not (rootInstallFailed status)
          , installedInstanceDiskUsageBytes = Just diskUsage
          , installedInstanceArchived = rootArchived status
          , installedInstanceArchivePath = if rootArchived status then Just (rootArchivePath status) else Nothing
          , installedInstanceInstallState = rootInstallState status
          , installedInstanceIncompleteReason =
              if rootInstallFailed status
                then Just "install_failed"
                else Nothing
          }

candidateInputRoots :: Maybe FilePath -> MinecraftLayout -> MinecraftInstallStatusRequest -> [FilePath]
candidateInputRoots defaultGameDir defaultLayout request =
  case installStatusGameDirs request of
    [] -> maybe [] (: []) defaultGameDir <> [minecraftRoot defaultLayout]
    explicitRoots -> explicitRoots

minecraftVersionInstallStatus :: [FilePath] -> Text -> IO MinecraftVersionInstallStatus
minecraftVersionInstallStatus candidateRoots versionId = do
  matches <- traverse (versionRootStatus versionId) candidateRoots
  let installableMatches = filter (not . rootInstallFailed) matches
      installedMatches = filter rootHasVersion installableMatches
      selected = case installedMatches of
        firstMatch:_ -> Just firstMatch
        [] -> Nothing
      jsonPresent = any rootVersionJson installableMatches
      jarPresent = any rootClientJar installableMatches
      archivedMatches = filter rootArchived installableMatches
      archiveMatch = case archivedMatches of
        firstArchive:_ -> Just firstArchive
        [] -> Nothing
      selectedRoot = case selected of
        Just installedRoot -> Just installedRoot
        Nothing -> archiveMatch
  diskUsage <- traverse (directorySizeRecursive . rootVersionPath) selected
  pure
    MinecraftVersionInstallStatus
      { minecraftStatusVersionId = versionId
      , minecraftStatusInstalled = jsonPresent || jarPresent
      , minecraftStatusVersionJson = jsonPresent
      , minecraftStatusClientJar = jarPresent
      , minecraftStatusDiskUsageBytes = diskUsage
      , minecraftStatusInstallRoot = rootBasePath <$> selectedRoot
      , minecraftStatusArchived = maybe False rootArchived archiveMatch
      , minecraftStatusArchivePath = rootArchivePath <$> archiveMatch
      }

data VersionRootStatus = VersionRootStatus
  { rootVersionId :: Text
  , rootBasePath :: FilePath
  , rootVersionPath :: FilePath
  , rootVersionJson :: Bool
  , rootClientJar :: Bool
  , rootArchived :: Bool
  , rootArchivePath :: FilePath
  , rootInstallState :: Maybe Text
  , rootInstallFailed :: Bool
  } deriving (Eq, Show)

rootHasVersion :: VersionRootStatus -> Bool
rootHasVersion status =
  rootVersionJson status || rootClientJar status

versionRootStatus :: Text -> FilePath -> IO VersionRootStatus
versionRootStatus versionId root = do
  let versionText = Text.unpack versionId
      nestedVersionPath = root </> "versions" </> versionText
      nestedJsonPath = nestedVersionPath </> (versionText <> ".json")
      nestedJarPath = nestedVersionPath </> (versionText <> ".jar")
      directJsonPath = root </> (versionText <> ".json")
      directJarPath = root </> (versionText <> ".jar")
      archivePath = root </> "versions" </> ".panino-archives" </> versionText <> ".zip"
  nestedJsonPresent <- doesFileExist nestedJsonPath
  nestedJarPresent <- doesFileExist nestedJarPath
  directJsonPresent <- doesFileExist directJsonPath
  directJarPresent <- doesFileExist directJarPath
  archived <- doesFileExist archivePath
  installState <- readInstallState root
  let directPresent = directJsonPresent || directJarPresent
      versionPath =
        if directPresent && not (nestedJsonPresent || nestedJarPresent)
          then root
          else nestedVersionPath
  pure
    VersionRootStatus
      { rootVersionId = versionId
      , rootBasePath = root
      , rootVersionPath = versionPath
      , rootVersionJson = nestedJsonPresent || directJsonPresent
      , rootClientJar = nestedJarPresent || directJarPresent
      , rootArchived = archived
      , rootArchivePath = archivePath
      , rootInstallState = installState
      , rootInstallFailed = installState == Just "failed"
      }

newtype InstallStateRecord = InstallStateRecord
  { installStateRecordState :: Text
  } deriving (Eq, Show)

instance FromJSON InstallStateRecord where
  parseJSON =
    withObject "InstallStateRecord" $ \obj ->
      InstallStateRecord <$> obj .: "state"

readInstallState :: FilePath -> IO (Maybe Text)
readInstallState root = do
  let path = root </> ".panino" </> "install-state.json"
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else do
      result <- catch (Right <$> BL.readFile path) handleReadFailure
      pure $ case result of
        Right bytes ->
          case eitherDecode' bytes of
            Right record -> Just (Text.toLower (installStateRecordState record))
            Left _ -> Nothing
        Left _ -> Nothing
  where
    handleReadFailure :: IOException -> IO (Either IOException BL.ByteString)
    handleReadFailure err = pure (Left err)

inferInstanceMetadata :: FilePath -> InstanceMetadata -> IO InstanceMetadata
inferInstanceMetadata root metadata = do
  versionIds <- installedVersionIdsInRoot root
  pure $ case inferLoaderFromProfiles (metadataMinecraftVersion metadata) versionIds of
    Nothing -> metadata
    Just (loader, loaderVersion) ->
      metadata
        { metadataLoader = metadataLoader metadata `orElse` Just loader
        , metadataLoaderVersion = metadataLoaderVersion metadata `orElse` loaderVersion
        }

inferLoaderFromProfiles :: Text -> [Text] -> Maybe (Text, Maybe Text)
inferLoaderFromProfiles minecraftVersion versionIds =
  case mapMaybe (inferLoaderProfile minecraftVersion) versionIds of
    profile:_ -> Just profile
    [] -> Nothing

inferLoaderProfile :: Text -> Text -> Maybe (Text, Maybe Text)
inferLoaderProfile minecraftVersion profileId =
  case inferMetaLoaderProfile minecraftVersion "quilt" "quilt-loader-" profileId of
    Just profile -> Just profile
    Nothing ->
      case inferMetaLoaderProfile minecraftVersion "fabric" "fabric-loader-" profileId of
        Just profile -> Just profile
        Nothing -> inferInstallerLoaderProfile minecraftVersion profileId

inferMetaLoaderProfile :: Text -> Text -> Text -> Text -> Maybe (Text, Maybe Text)
inferMetaLoaderProfile minecraftVersion loader prefix profileId
  | lowerPrefix `Text.isPrefixOf` lowerProfile && mcSuffix `Text.isSuffixOf` lowerProfile =
      Just (loader, nonEmptyText rawLoaderVersion)
  | otherwise = Nothing
  where
    lowerProfile = Text.toLower profileId
    lowerPrefix = Text.toLower prefix
    mcSuffix = "-" <> Text.toLower minecraftVersion
    rawLoaderVersion =
      Text.dropEnd (Text.length mcSuffix) $
        Text.drop (Text.length prefix) profileId

inferInstallerLoaderProfile :: Text -> Text -> Maybe (Text, Maybe Text)
inferInstallerLoaderProfile minecraftVersion profileId
  | not (profileMatchesMinecraft minecraftVersion profileId) = Nothing
  | "neoforge" `Text.isInfixOf` normalized =
      Just ("neoForge", loaderVersionAfter "neoforge")
  | "forge" `Text.isInfixOf` normalized =
      Just ("forge", loaderVersionAfter "forge")
  | otherwise = Nothing
  where
    normalized = slugText profileId
    loaderVersionAfter loader =
      nonEmptyText $
        Text.dropAround (== '-') $
          fromMaybe "" (Text.stripPrefix loader (snd (Text.breakOn loader normalized)))

profileMatchesMinecraft :: Text -> Text -> Bool
profileMatchesMinecraft minecraftVersion profileId =
  Text.toLower minecraftVersion `Text.isInfixOf` Text.toLower profileId

nonEmptyText :: Text -> Maybe Text
nonEmptyText value =
  let trimmed = Text.strip value
   in if Text.null trimmed then Nothing else Just trimmed

orElse :: Maybe a -> Maybe a -> Maybe a
orElse (Just value) _ = Just value
orElse Nothing fallback = fallback

directorySizeRecursive :: FilePath -> IO Integer
directorySizeRecursive path = do
  isDirectory <- doesDirectoryExist path
  if not isDirectory
    then pure 0
    else do
      names <- sortOn id <$> listDirectory path
      sizes <- traverse sizeEntry names
      pure (sum sizes)
  where
    sizeEntry name = do
      let child = path </> name
      childIsDirectory <- doesDirectoryExist child
      if childIsDirectory
        then directorySizeRecursive child
        else getFileSize child

uniqueNonEmptyPaths :: [FilePath] -> [FilePath]
uniqueNonEmptyPaths = foldr insertPath []
  where
    insertPath path paths
      | null path = paths
      | path `elem` paths = paths
      | otherwise = path : paths

expandCandidateRoots :: [FilePath] -> IO [FilePath]
expandCandidateRoots roots =
  uniqueNonEmptyPaths . concat <$> traverse expandRoot roots
  where
    expandRoot root = do
      rootChildren <- childDirectories root
      rootsWithVersions <- filterM hasVersionsDirectory (root : rootChildren)
      directVersionRoots <- filterM hasDirectVersionFiles rootChildren
      localInstanceRoots <- filterM localInstanceDirectory rootChildren
      nestedMinecraftRoots <- filterM hasVersionsDirectory (map (</> "minecraft") rootChildren)
      pure (root : rootsWithVersions <> directVersionRoots <> localInstanceRoots <> nestedMinecraftRoots)

    hasVersionsDirectory path =
      doesDirectoryExist (path </> "versions")

    hasDirectVersionFiles path = do
      directIds <- directVersionIdsInRoot path
      pure (not (null directIds))

    childDirectories path = do
      entries <- safeListDirectory path
      filterM doesDirectoryExist (map (path </>) entries)

safeListDirectory :: FilePath -> IO [FilePath]
safeListDirectory path =
  catch (sortOn id <$> listDirectory path) handleListFailure
  where
    handleListFailure :: IOException -> IO [FilePath]
    handleListFailure _ = pure []

installedVersionIdsInRoot :: FilePath -> IO [Text]
installedVersionIdsInRoot root = do
  versionDirectories <- childDirectories (root </> "versions")
  directVersionIds <- directVersionIdsInRoot root
  pure
    ( uniqueTexts
        ( directVersionIds
            <> map (Text.pack . takeFileName) (filter visibleVersionDirectory versionDirectories)
        )
    )
  where
    visibleVersionDirectory path =
      case takeFileName path of
        '.':_ -> False
        "" -> False
        _ -> True

    childDirectories path = do
      entries <- safeListDirectory path
      filterM doesDirectoryExist (map (path </>) entries)

directVersionIdsInRoot :: FilePath -> IO [Text]
directVersionIdsInRoot root = do
  entries <- safeListDirectory root
  let jsonNames =
        [ dropExtension entry
        | entry <- entries
        , takeExtension entry == ".json"
        , not (null (dropExtension entry))
        ]
      hasJar versionName = (versionName <> ".jar") `elem` entries
  pure (map Text.pack (filter hasJar jsonNames))

localInstanceDirectory :: FilePath -> IO Bool
localInstanceDirectory root = do
  hasSaves <- doesDirectoryExist (root </> "saves")
  hasMods <- doesDirectoryExist (root </> "mods")
  hasResources <- doesDirectoryExist (root </> "resourcepacks")
  hasShaders <- doesDirectoryExist (root </> "shaderpacks")
  pure (hasSaves || hasMods || hasResources || hasShaders)

canonicalLocalVersionIds :: FilePath -> IO [Text]
canonicalLocalVersionIds root = do
  versionIds <- installedVersionIdsInRoot root
  metadata <-
    case versionIds of
      [] -> pure Nothing
      fallbackVersion:_ -> Just <$> readInstanceMetadata root fallbackVersion
  case metadata of
    Just instanceMetadata
      | metadataLaunchVersion instanceMetadata `elem` versionIds ->
          pure [metadataLaunchVersion instanceMetadata]
    _ -> case versionIds of
      [] -> pure []
      [_] -> pure versionIds
      _ -> pure (filter (rootMatchesVersion root) versionIds)

rootMatchesVersion :: FilePath -> Text -> Bool
rootMatchesVersion root versionId =
  rootSlug == expected
    || rootSlug == versionSlug
    || Text.isPrefixOf (expected <> "-") rootSlug
    || Text.isSuffixOf ("-" <> versionSlug) rootSlug
  where
    rootSlug = slugText (Text.pack (takeFileName root))
    versionSlug = slugText versionId
    expected = "minecraft-" <> versionSlug

slugText :: Text -> Text
slugText value =
  Text.dropAround (== '-') (Text.foldr appendSlug "" (Text.toLower value))
  where
    appendSlug char acc
      | isAlphaNum char = Text.cons char acc
      | Text.isPrefixOf "-" acc = acc
      | otherwise = Text.cons '-' acc

uniqueTexts :: [Text] -> [Text]
uniqueTexts = foldr insertText []
  where
    insertText value values
      | Text.null value = values
      | value `elem` values = values
      | otherwise = value : values
