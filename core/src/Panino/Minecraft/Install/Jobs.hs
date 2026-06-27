{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.Install.Jobs
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
  ) where

import Control.Applicative ((<|>))
import Control.Monad (forM)
import Data.List
  ( nubBy
  , sortOn
  )
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( catMaybes
  , mapMaybe
  )
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Download.Manager
  ( DownloadJob(..)
  )
import Panino.Core.Types
  ( sha1FromText
  , urlFromString
  , urlFromText
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  , assetIndexPath
  , assetObjectPath
  , clientJarPath
  , libraryPathFromDownload
  )
import Panino.Minecraft.Types
  ( AssetIndex(..)
  , AssetObject(..)
  , DownloadInfo(..)
  , Library(..)
  , LibraryDownloads(..)
  , VersionJson(..)
  , currentMinecraftArch
  , isAllowedByRules
  )
import System.FilePath ((</>))

baseJobs :: MinecraftLayout -> VersionJson -> DownloadInfo -> IO [DownloadJob]
baseJobs layout versionJson clientInfo =
  (: []) <$> downloadJob "client jar" (clientJarPath layout (versionId versionJson)) clientInfo

assetIndexJob :: MinecraftLayout -> VersionJson -> IO DownloadJob
assetIndexJob layout versionJson =
  downloadJob "asset index" (assetIndexPath layout (assetIndexId versionJson)) (versionAssetIndex versionJson)

assetJobs :: MinecraftLayout -> AssetIndex -> [DownloadJob]
assetJobs layout index =
  [ DownloadJob
      { jobLabel = "asset " <> Text.unpack name
      , jobUrl = urlFromString (assetObjectUrl objectInfo)
      , jobTargetPath = assetObjectPath layout (assetHash objectInfo)
      , jobSha1 = sha1FromText (assetHash objectInfo)
      , jobSize = Just (assetSize objectInfo)
      }
  | (name, objectInfo) <- sortOn (Down . assetSize . snd) (Map.toList (assetObjects index))
  ]

libraryArtifactJobs :: MinecraftLayout -> VersionJson -> IO [DownloadJob]
libraryArtifactJobs layout versionJson =
  libraryArtifactJobsForLibraries layout (versionLibraries versionJson)

libraryArtifactJobsForLibraries :: MinecraftLayout -> [Library] -> IO [DownloadJob]
libraryArtifactJobsForLibraries layout libraries =
  fmap catMaybes (forM (filter isAllowedLibrary libraries) libraryArtifactJob)
  where
    libraryArtifactJob library = do
      case libraryDownloads library >>= libraryArtifact of
        Just artifact -> do
          case libraryTargetPath layout (libraryName library) artifact of
            Just target -> Just <$> downloadJob ("library " <> Text.unpack (libraryName library)) target artifact
            Nothing -> pure Nothing
        Nothing ->
          pure (libraryMavenJob layout library)

nativeLibraryJobs :: MinecraftLayout -> VersionJson -> IO [DownloadJob]
nativeLibraryJobs layout versionJson =
  nativeLibraryJobsForLibraries layout (nativeLibraries versionJson)

nativeLibraryJobsForLibraries :: MinecraftLayout -> [Library] -> IO [DownloadJob]
nativeLibraryJobsForLibraries layout libraries =
  fmap catMaybes (forM libraries nativeLibraryJob)
  where
    nativeLibraryJob library = do
      case libraryDownloads library of
        Nothing -> pure Nothing
        Just downloads ->
          case nativeClassifierName library >>= (`Map.lookup` libraryClassifiers downloads) of
            Nothing -> pure Nothing
            Just classifier ->
              case libraryTargetPath layout (libraryName library) classifier of
                Just target -> Just <$> downloadJob ("native " <> Text.unpack (libraryName library)) target classifier
                Nothing -> pure Nothing

nativeArchivePaths :: MinecraftLayout -> VersionJson -> IO [FilePath]
nativeArchivePaths layout versionJson =
  pure (mapMaybe nativeArchiveForLibrary (nativeLibraries versionJson))
  where
    nativeArchiveForLibrary library = do
      downloads <- libraryDownloads library
      case nativeClassifierName library of
        Just classifierName -> do
          classifier <- Map.lookup classifierName (libraryClassifiers downloads)
          libraryTargetPath layout (libraryName library) classifier
        Nothing -> do
          artifact <- libraryArtifact downloads
          libraryTargetPath layout (libraryName library) artifact

classpathJars :: MinecraftLayout -> VersionJson -> [FilePath]
classpathJars layout versionJson =
  mapMaybe (libraryClasspathJar layout) (classpathLibraries versionJson)
    <> [clientJarPath layout (versionId versionJson)]

assetIndexId :: VersionJson -> Text
assetIndexId versionJson =
  case downloadId (versionAssetIndex versionJson) of
    Just indexId -> indexId
    Nothing -> "legacy"

downloadInfoSummary :: DownloadInfo -> Map Text Text
downloadInfoSummary info =
  Map.fromList
    ( catMaybes
        [ pair "id" <$> downloadId info
        , pair "url" <$> downloadUrl info
        , pair "sha1" <$> downloadSha1 info
        , pair "path" . Text.pack <$> downloadPath info
        ]
    )
  where
    pair key value = (key, value)

downloadJob :: String -> FilePath -> DownloadInfo -> IO DownloadJob
downloadJob label target info = do
  url <- requireUrl label info
  pure
    DownloadJob
      { jobLabel = label
      , jobUrl = urlFromString url
      , jobTargetPath = target
      , jobSha1 = downloadSha1 info >>= sha1FromText
      , jobSize = downloadSize info
      }

libraryTargetPath :: MinecraftLayout -> Text -> DownloadInfo -> Maybe FilePath
libraryTargetPath layout name info =
  libraryPathFromDownload layout info
    <|> Just (librariesDir layout </> mavenArtifactPath name Nothing)

libraryClasspathJar :: MinecraftLayout -> Library -> Maybe FilePath
libraryClasspathJar layout library =
  case libraryDownloads library >>= libraryArtifact of
    Just artifact -> libraryTargetPath layout (libraryName library) artifact
    Nothing ->
      case libraryUrl library of
        Just _ -> Just (librariesDir layout </> mavenArtifactPath (libraryName library) Nothing)
        Nothing -> Nothing

classpathLibraries :: VersionJson -> [Library]
classpathLibraries =
  reverse
    . nubBy sameClasspathModule
    . reverse
    . filter isAllowedLibrary
    . versionLibraries

sameClasspathModule :: Library -> Library -> Bool
sameClasspathModule lhs rhs =
  classpathModuleKey lhs == classpathModuleKey rhs

classpathModuleKey :: Library -> [Text]
classpathModuleKey library =
  case Text.splitOn ":" (libraryName library) of
    [groupId, artifactId, _version] -> [groupId, artifactId, ""]
    [groupId, artifactId, _version, classifier] -> [groupId, artifactId, classifier]
    _ -> [libraryName library]

libraryMavenJob :: MinecraftLayout -> Library -> Maybe DownloadJob
libraryMavenJob layout library = do
  baseUrl <- libraryUrl library
  pure
    DownloadJob
      { jobLabel = "library " <> Text.unpack (libraryName library)
      , jobUrl = urlFromText (ensureTrailingSlash baseUrl <> Text.pack (mavenArtifactPath (libraryName library) Nothing))
      , jobTargetPath = librariesDir layout </> mavenArtifactPath (libraryName library) Nothing
      , jobSha1 = Nothing
      , jobSize = Nothing
      }

ensureTrailingSlash :: Text -> Text
ensureTrailingSlash value
  | "/" `Text.isSuffixOf` value = value
  | otherwise = value <> "/"

mavenArtifactPath :: Text -> Maybe Text -> FilePath
mavenArtifactPath name overrideClassifier =
  case Text.splitOn ":" name of
    [groupId, artifactId, version] ->
      Text.unpack (Text.replace "." "/" groupId)
        </> Text.unpack artifactId
        </> Text.unpack version
        </> Text.unpack (artifactFile artifactId version overrideClassifier)
    [groupId, artifactId, version, classifier] ->
      Text.unpack (Text.replace "." "/" groupId)
        </> Text.unpack artifactId
        </> Text.unpack version
        </> Text.unpack (artifactFile artifactId version (Just classifier))
    _ -> Text.unpack (Text.replace ":" "/" name) <> ".jar"

artifactFile :: Text -> Text -> Maybe Text -> Text
artifactFile artifactId version classifier =
  artifactId <> "-" <> version <> maybe "" ("-" <>) classifier <> ".jar"

nativeLibraries :: VersionJson -> [Library]
nativeLibraries versionJson =
  filter isNativeLibrary (filter isAllowedLibrary (versionLibraries versionJson))

isNativeLibrary :: Library -> Bool
isNativeLibrary library =
  nativeClassifierName library /= Nothing || isNativeArtifactLibrary library

isNativeArtifactLibrary :: Library -> Bool
isNativeArtifactLibrary library =
  maybe False ("natives-" `Text.isPrefixOf`) (artifactClassifier library)

nativeClassifierName :: Library -> Maybe Text
nativeClassifierName library =
  replaceArch <$> Map.lookup "osx" (libraryNatives library)

replaceArch :: Text -> Text
replaceArch = Text.replace "${arch}" "64"

isAllowedLibrary :: Library -> Bool
isAllowedLibrary library =
  isAllowedByRules (libraryRules library) && nativeArtifactMatchesCurrentArch library

nativeArtifactMatchesCurrentArch :: Library -> Bool
nativeArtifactMatchesCurrentArch library =
  case artifactClassifier library of
    Just "natives-macos-arm64" -> currentMinecraftArch == "arm64"
    Just "natives-macos" -> currentMinecraftArch /= "arm64"
    _ -> True

artifactClassifier :: Library -> Maybe Text
artifactClassifier library =
  case Text.splitOn ":" (libraryName library) of
    [_groupId, _artifactId, _version, classifier] -> Just classifier
    _ -> Nothing

assetObjectUrl :: AssetObject -> String
assetObjectUrl objectInfo =
  "https://resources.download.minecraft.net/"
    <> Text.unpack (Text.take 2 (assetHash objectInfo))
    <> "/"
    <> Text.unpack (assetHash objectInfo)

requireUrl :: String -> DownloadInfo -> IO String
requireUrl label info =
  case downloadUrl info of
    Just url -> pure (Text.unpack url)
    Nothing -> fail ("metadata_parse_failed: download is missing url: " <> label)
