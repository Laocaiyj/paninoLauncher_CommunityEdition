{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.Install
  ( InstallResult(..)
  , classpathJars
  , installMinecraftVersion
  , installMinecraftVersionWithOptions
  , installMinecraftVersionWithOptionsAndProgress
  , installMinecraftVersionWithOptionsAndProgressAndCancel
  , installMinecraftVersionWithProgress
  , installMinecraftVersionWithProgressAndCancel
  , installMinecraftInheritedProfileWithOptionsAndProgressAndCancel
  , mavenArtifactPath
  , resolveVersionSummaryJson
  ) where

import Control.Exception (throwIO)
import Control.Monad (forM_, unless, when)
import Data.Aeson
  ( FromJSON
  , ToJSON
  , Value
  , decode
  , encode
  , object
  , withObject
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Aeson.Types (parseEither)
import qualified Data.ByteString.Lazy.Char8 as BL8
import qualified Data.ByteString.Lazy as BL
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import Network.HTTP.Client (Manager)
import Panino.Download.Manager
  ( DownloadException(..)
  , DownloadJob(..)
  , DownloadOptions
  , DownloadProgress
  , DownloadResult(..)
  , DownloadSummary(..)
  , downloadSingle
  , downloadOptionsWithConcurrency
  , runDownloadJobsWithOptionsAndProgressAndCancel
  )
import Panino.Minecraft.InstallPlanGraph
  ( dedupeInstallPlanJobs
  , downloadJobsInstallPlanGraph
  , installPlanGraphId
  , installPlanGraphNodes
  , InstallPlanGraph
  , writeInstallPlanGraph
  )
import Panino.Minecraft.Install.Jobs
  ( assetIndexId
  , assetIndexJob
  , assetJobs
  , baseJobs
  , classpathJars
  , downloadInfoSummary
  , isAllowedLibrary
  , libraryArtifactJobs
  , libraryArtifactJobsForLibraries
  , mavenArtifactPath
  , nativeArchivePaths
  , nativeLibraries
  , nativeLibraryJobs
  , nativeLibraryJobsForLibraries
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  , assetIndexPath
  , clientJarPath
  , ensureLayout
  , nativesDir
  , versionJsonPath
  )
import Panino.Minecraft.Manifest
  ( decodeJsonFile
  , loadVersionJson
  )
import Panino.Minecraft.Types
  ( DownloadInfo(..)
  , Library(..)
  , VersionJson(..)
  )
import System.Directory
  ( createDirectoryIfMissing
  , copyFile
  , doesFileExist
  , getFileSize
  , getModificationTime
  )
import System.Exit (ExitCode(..))
import System.FilePath (takeDirectory, (</>))
import System.Process (readProcessWithExitCode)

data InstallResult = InstallResult
  { installVersionJson :: VersionJson
  , installClasspathJars :: [FilePath]
  , installNativeArchives :: [FilePath]
  , installDownloadSummary :: DownloadSummary
  , installPlanGraph :: InstallPlanGraph
  } deriving (Eq, Show)

data NativeExtractionMarker = NativeExtractionMarker
  { nativeMarkerVersion :: Text
  , nativeMarkerArchives :: [NativeArchiveRecord]
  } deriving (Eq, Show, Generic)

instance ToJSON NativeExtractionMarker
instance FromJSON NativeExtractionMarker

data NativeArchiveRecord = NativeArchiveRecord
  { nativeArchivePath :: FilePath
  , nativeArchiveSize :: Integer
  , nativeArchiveModifiedAt :: UTCTime
  } deriving (Eq, Show, Generic)

instance ToJSON NativeArchiveRecord
instance FromJSON NativeArchiveRecord

installMinecraftVersion :: Manager -> MinecraftLayout -> Text -> Int -> IO InstallResult
installMinecraftVersion manager layout requestedVersion concurrency =
  installMinecraftVersionWithProgress manager layout requestedVersion concurrency (\_ -> pure ())

installMinecraftVersionWithProgress :: Manager -> MinecraftLayout -> Text -> Int -> (DownloadProgress -> IO ()) -> IO InstallResult
installMinecraftVersionWithProgress manager layout requestedVersion concurrency onProgress =
  installMinecraftVersionWithProgressAndCancel manager layout requestedVersion concurrency (pure False) onProgress

installMinecraftVersionWithProgressAndCancel :: Manager -> MinecraftLayout -> Text -> Int -> IO Bool -> (DownloadProgress -> IO ()) -> IO InstallResult
installMinecraftVersionWithProgressAndCancel manager layout requestedVersion concurrency =
  installMinecraftVersionWithOptionsAndProgressAndCancel manager layout requestedVersion (downloadOptionsWithConcurrency concurrency)

installMinecraftVersionWithOptions :: Manager -> MinecraftLayout -> Text -> DownloadOptions -> IO InstallResult
installMinecraftVersionWithOptions manager layout requestedVersion options =
  installMinecraftVersionWithOptionsAndProgress manager layout requestedVersion options (\_ -> pure ())

installMinecraftVersionWithOptionsAndProgress :: Manager -> MinecraftLayout -> Text -> DownloadOptions -> (DownloadProgress -> IO ()) -> IO InstallResult
installMinecraftVersionWithOptionsAndProgress manager layout requestedVersion options onProgress =
  installMinecraftVersionWithOptionsAndProgressAndCancel manager layout requestedVersion options (pure False) onProgress

installMinecraftVersionWithOptionsAndProgressAndCancel :: Manager -> MinecraftLayout -> Text -> DownloadOptions -> IO Bool -> (DownloadProgress -> IO ()) -> IO InstallResult
installMinecraftVersionWithOptionsAndProgressAndCancel manager layout requestedVersion options isCancelled onProgress = do
  throwIfCancelled isCancelled
  ensureLayout layout
  versionJson <- loadVersionJson manager layout requestedVersion
  throwIfCancelled isCancelled

  putStrLn ("installing Minecraft " <> Text.unpack (versionId versionJson))
  clientInfo <- requireClientDownload versionJson
  assetIndexDownload <- assetIndexJob layout versionJson
  let metadataJobs = [assetIndexDownload]

  -- The asset index is metadata required to enumerate asset-object nodes. Resolve it
  -- before plan execution so the payload phase never discovers new dependencies.
  assetIndexSummary <- prefetchAssetIndexForPlan manager assetIndexDownload
  throwIfCancelled isCancelled
  assetIndex <- decodeJsonFile (assetIndexPath layout (assetIndexId versionJson))
  baseDownloadJobs <- baseJobs layout versionJson clientInfo
  libraryDownloadJobs <- libraryArtifactJobs layout versionJson
  nativeDownloadJobs <- nativeLibraryJobs layout versionJson
  let payloadJobs =
        dedupeInstallPlanJobs
          (baseDownloadJobs <> libraryDownloadJobs <> nativeDownloadJobs <> assetJobs layout assetIndex)
      fullGraph = downloadJobsInstallPlanGraph "minecraft" (versionId versionJson) (metadataJobs <> payloadJobs)
  writeInstallPlanGraph (installPlanGraphPath layout) fullGraph
  putStrLn
    ( "install_plan_graph"
        <> " plan_id="
        <> Text.unpack (installPlanGraphId fullGraph)
        <> " nodes="
        <> show (length (installPlanGraphNodes fullGraph))
        <> " phase=resolved"
    )
  payloadSummary <-
    runDownloadJobsWithOptionsAndProgressAndCancel
      manager
      options
      isCancelled
      payloadJobs
      onProgress

  throwIfCancelled isCancelled
  nativeArchives <- nativeArchivePaths layout versionJson
  extractNatives layout versionJson nativeArchives
  throwIfCancelled isCancelled

  pure InstallResult
    { installVersionJson = versionJson
    , installClasspathJars = classpathJars layout versionJson
    , installNativeArchives = nativeArchives
    , installDownloadSummary = mergeSummaries assetIndexSummary payloadSummary
    , installPlanGraph = fullGraph
    }

installMinecraftInheritedProfileWithOptionsAndProgressAndCancel :: Manager -> MinecraftLayout -> Text -> Text -> DownloadOptions -> IO Bool -> (DownloadProgress -> IO ()) -> IO InstallResult
installMinecraftInheritedProfileWithOptionsAndProgressAndCancel manager layout inheritedVersion profileId options isCancelled onProgress = do
  throwIfCancelled isCancelled
  ensureLayout layout
  profileValue <- decodeJsonFile (versionJsonPath layout profileId) :: IO Value
  profileLibraries <- profileLibrariesFromValue profileId profileValue
  versionJson <- loadVersionJson manager layout profileId
  ensureProfileClientJar layout inheritedVersion (versionId versionJson)
  throwIfCancelled isCancelled
  libraryDownloadJobs <- libraryArtifactJobsForLibraries layout profileLibraries
  nativeDownloadJobs <- nativeLibraryJobsForLibraries layout profileLibraries
  let payloadJobs = dedupeInstallPlanJobs (libraryDownloadJobs <> nativeDownloadJobs)
      graph = downloadJobsInstallPlanGraph "minecraft-profile" profileId payloadJobs
  writeInstallPlanGraph (installPlanGraphPath layout) graph
  payloadSummary <-
    runDownloadJobsWithOptionsAndProgressAndCancel
      manager
      options
      isCancelled
      payloadJobs
      onProgress
  throwIfCancelled isCancelled
  nativeArchives <- nativeArchivePaths layout versionJson
  extractNatives layout versionJson nativeArchives
  pure InstallResult
    { installVersionJson = versionJson
    , installClasspathJars = classpathJars layout versionJson
    , installNativeArchives = nativeArchives
    , installDownloadSummary = payloadSummary
    , installPlanGraph = graph
    }

profileLibrariesFromValue :: Text -> Value -> IO [Library]
profileLibrariesFromValue profileId value =
  case parseEither parser value of
    Right libraries -> pure libraries
    Left err -> fail ("loader_profile_parse_failed: " <> Text.unpack profileId <> " libraries: " <> err)
  where
    parser =
      withObject "LoaderProfile" $ \obj ->
        obj .:? "libraries" .!= []

ensureProfileClientJar :: MinecraftLayout -> Text -> Text -> IO ()
ensureProfileClientJar layout inheritedVersion profileId
  | inheritedVersion == profileId = pure ()
  | otherwise = do
      let source = clientJarPath layout inheritedVersion
          target = clientJarPath layout profileId
      targetExists <- doesFileExist target
      unless targetExists $ do
        sourceExists <- doesFileExist source
        unless sourceExists $
          fail ("loader_profile_client_missing: inherited client jar missing: " <> source)
        createDirectoryIfMissing True (takeDirectory target)
        copyFile source target

prefetchAssetIndexForPlan :: Manager -> DownloadJob -> IO DownloadSummary
prefetchAssetIndexForPlan manager job = do
  outcome <- downloadSingle manager job
  pure $
    case outcome of
      Downloaded _ -> DownloadSummary 1 0 1
      Skipped _ -> DownloadSummary 0 1 1

throwIfCancelled :: IO Bool -> IO ()
throwIfCancelled isCancelled = do
  cancelled <- isCancelled
  when cancelled (throwIO DownloadCancelled)

resolveVersionSummaryJson :: VersionJson -> BL8.ByteString
resolveVersionSummaryJson versionJson =
  encode
    ( object
        [ "version" .= versionId versionJson
        , "type" .= versionType versionJson
        , "mainClass" .= versionMainClass versionJson
        , "client" .= fmap downloadInfoSummary (clientDownload versionJson)
        , "assetIndex" .= downloadInfoSummary (versionAssetIndex versionJson)
        , "libraries" .= length (filter isAllowedLibrary (versionLibraries versionJson))
        , "nativeLibraries" .= length (nativeLibraries versionJson)
        ]
    )

extractNatives :: MinecraftLayout -> VersionJson -> [FilePath] -> IO ()
extractNatives _ _ [] = pure ()
extractNatives layout versionJson archivePaths = do
  let targetDir = nativesDir layout (versionId versionJson)
  createDirectoryIfMissing True targetDir
  marker <- nativeExtractionMarker (versionId versionJson) archivePaths
  current <- readNativeMarker targetDir
  if current == Just marker
    then putStrLn ("skipped natives for " <> Text.unpack (versionId versionJson))
    else do
      forM_ archivePaths $ \archivePath -> do
        (exitCode, _stdout, stderrText) <-
          readProcessWithExitCode
            "/usr/bin/unzip"
            ["-oq", archivePath, "-d", targetDir, "-x", "META-INF/*"]
            ""
        case exitCode of
          ExitSuccess -> pure ()
          ExitFailure code ->
            fail ("failed to extract natives from " <> archivePath <> " with code " <> show code <> ": " <> stderrText)
      writeNativeMarker targetDir marker

nativeExtractionMarker :: Text -> [FilePath] -> IO NativeExtractionMarker
nativeExtractionMarker version archivePaths =
  NativeExtractionMarker version <$> traverse nativeArchiveRecord archivePaths

nativeArchiveRecord :: FilePath -> IO NativeArchiveRecord
nativeArchiveRecord archivePath = do
  exists <- doesFileExist archivePath
  unless exists (fail ("native archive missing after install: " <> archivePath))
  NativeArchiveRecord archivePath
    <$> getFileSize archivePath
    <*> getModificationTime archivePath

readNativeMarker :: FilePath -> IO (Maybe NativeExtractionMarker)
readNativeMarker targetDir = do
  exists <- doesFileExist (nativeMarkerPath targetDir)
  if exists
    then decode <$> BL.readFile (nativeMarkerPath targetDir)
    else pure Nothing

writeNativeMarker :: FilePath -> NativeExtractionMarker -> IO ()
writeNativeMarker targetDir marker =
  BL.writeFile (nativeMarkerPath targetDir) (encode marker)

nativeMarkerPath :: FilePath -> FilePath
nativeMarkerPath targetDir =
  targetDir </> ".panino-native-marker.json"

requireClientDownload :: VersionJson -> IO DownloadInfo
requireClientDownload versionJson =
  case clientDownload versionJson of
    Just info -> pure info
    Nothing ->
      fail
        ( "manifest_parse_failed: version JSON is missing downloads.client for "
            <> Text.unpack (versionId versionJson)
        )

clientDownload :: VersionJson -> Maybe DownloadInfo
clientDownload versionJson =
  Map.lookup "client" (versionDownloads versionJson)

mergeSummaries :: DownloadSummary -> DownloadSummary -> DownloadSummary
mergeSummaries left right =
  DownloadSummary
    { downloadedCount = downloadedCount left + downloadedCount right
    , skippedCount = skippedCount left + skippedCount right
    , totalCount = totalCount left + totalCount right
    }

installPlanGraphPath :: MinecraftLayout -> FilePath
installPlanGraphPath layout =
  minecraftRoot layout </> "downloads" </> "install-plan-graph.json"
