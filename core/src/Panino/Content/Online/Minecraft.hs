{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Content.Online.Minecraft
  ( LoaderMetadataSourceResult(..)
  , contentLoaderMetadata
  , contentLoaderMetadataSources
  , contentMinecraftPackage
  , contentMinecraftVersions
  , preferredLoaderMetadata
  ) where

import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import Control.Concurrent.Async (mapConcurrently)
import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , Value
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Aeson.Types ((.!=))
import Data.Int (Int64)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe)
import Data.List (sortOn)
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time
  ( UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Http
  ( coreRequest
  , fetchJson
  , fetchText
  )
import Panino.Content.Online.Types
  ( ContentLoaderRequest(..)
  , LoaderMetadata(..)
  , MinecraftAssetIndex(..)
  , MinecraftDownload(..)
  , MinecraftPackageRequest(..)
  , MinecraftRemoteVersion(..)
  , MinecraftVersionPackage(..)
  )
import Panino.Core.Types
  ( Sha1
  , Url
  , VersionId
  , urlString
  )
import Text.Read (readMaybe)

contentMinecraftVersions :: Manager -> IO [MinecraftRemoteVersion]
contentMinecraftVersions manager = do
  manifest <- fetchJson manager =<< coreRequest "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json" []
  pure (map mojangVersion (mojangVersions manifest))

contentMinecraftPackage :: Manager -> MinecraftPackageRequest -> IO MinecraftVersionPackage
contentMinecraftPackage manager request = do
  package <- fetchJson manager =<< coreRequest (urlString (minecraftPackageUrl request)) []
  pure (mojangPackage package)

contentLoaderMetadata :: Manager -> ContentLoaderRequest -> IO [LoaderMetadata]
contentLoaderMetadata manager (ContentLoaderRequest minecraftVersion) = do
  concat
    . map loaderSourceVersions
    <$> contentLoaderMetadataSources manager (ContentLoaderRequest minecraftVersion)

data LoaderMetadataSourceResult = LoaderMetadataSourceResult
  { loaderSourceName :: Text
  , loaderSourceOk :: Bool
  , loaderSourceVersions :: [LoaderMetadata]
  , loaderSourceVersionCount :: Int
  , loaderSourceSelectedVersion :: Maybe Text
  , loaderSourceError :: Maybe Text
  , loaderSourceLatencyMs :: Int
  } deriving (Eq, Show)

instance ToJSON LoaderMetadataSourceResult where
  toJSON result =
    object
      [ "source" .= loaderSourceName result
      , "ok" .= loaderSourceOk result
      , "versions" .= loaderSourceVersions result
      , "versionCount" .= loaderSourceVersionCount result
      , "selectedVersion" .= loaderSourceSelectedVersion result
      , "error" .= loaderSourceError result
      , "latencyMs" .= loaderSourceLatencyMs result
      ]

contentLoaderMetadataSources :: Manager -> ContentLoaderRequest -> IO [LoaderMetadataSourceResult]
contentLoaderMetadataSources manager (ContentLoaderRequest minecraftVersion) =
  mapConcurrently
    (runLoaderSource manager minecraftVersion)
    [ ("fabric", fabricMetadata)
    , ("quilt", quiltMetadata)
    , ("forge", forgeMetadata)
    , ("neoforge", neoForgeMetadata)
    ]

runLoaderSource :: Manager -> Text -> (Text, Manager -> Text -> IO [LoaderMetadata]) -> IO LoaderMetadataSourceResult
runLoaderSource manager minecraftVersion (source, action) = do
  started <- getCurrentTime
  outcome <- try (action manager minecraftVersion)
  finished <- getCurrentTime
  let latencyMs = max 0 (floor (realToFrac (diffUTCTime finished started) * (1000 :: Double)))
  case outcome of
    Right versions ->
      pure
        LoaderMetadataSourceResult
          { loaderSourceName = source
          , loaderSourceOk = True
          , loaderSourceVersions = versions
          , loaderSourceVersionCount = length versions
          , loaderSourceSelectedVersion = loaderMetadataLoaderVersion <$> preferredLoaderMetadata versions
          , loaderSourceError = Nothing
          , loaderSourceLatencyMs = latencyMs
          }
    Left (err :: SomeException) ->
      pure
        LoaderMetadataSourceResult
          { loaderSourceName = source
          , loaderSourceOk = False
          , loaderSourceVersions = []
          , loaderSourceVersionCount = 0
          , loaderSourceSelectedVersion = Nothing
          , loaderSourceError = Just (Text.pack (displayException err))
          , loaderSourceLatencyMs = latencyMs
          }

preferredLoaderMetadata :: [LoaderMetadata] -> Maybe LoaderMetadata
preferredLoaderMetadata versions =
  case sortOn loaderMetadataSelectionKey versions of
    item:_ -> Just item
    [] -> Nothing

loaderMetadataSelectionKey :: LoaderMetadata -> (Int, Down [Int], Text)
loaderMetadataSelectionKey metadata =
  ( if effectiveStableLoaderVersion (loaderMetadataLoaderVersion metadata) && loaderMetadataStable metadata then 0 else 1
  , Down (loaderVersionParts (loaderMetadataLoaderVersion metadata))
  , loaderMetadataLoaderVersion metadata
  )

effectiveStableLoaderVersion :: Text -> Bool
effectiveStableLoaderVersion version =
  not $
    any
      (`Text.isInfixOf` Text.toLower version)
      ["alpha", "beta", "snapshot", "rc"]

loaderVersionParts :: Text -> [Int]
loaderVersionParts =
  mapMaybe readMaybe . words . Text.unpack . Text.map normalizeChar
  where
    normalizeChar char
      | char >= '0' && char <= '9' = char
      | otherwise = ' '

data MojangManifest = MojangManifest
  { mojangVersions :: [MojangManifestVersion]
  } deriving (Eq, Show)

instance FromJSON MojangManifest where
  parseJSON =
    withObject "MojangManifest" $ \obj ->
      MojangManifest <$> obj .:? "versions" .!= []

data MojangManifestVersion = MojangManifestVersion
  { mojangVersionId :: VersionId
  , mojangVersionType :: Text
  , mojangVersionUrl :: Url
  , mojangVersionReleaseTime :: Maybe UTCTime
  } deriving (Eq, Show)

instance FromJSON MojangManifestVersion where
  parseJSON =
    withObject "MojangManifestVersion" $ \obj ->
      MojangManifestVersion
        <$> obj .: "id"
        <*> obj .: "type"
        <*> obj .: "url"
        <*> obj .:? "releaseTime"

mojangVersion :: MojangManifestVersion -> MinecraftRemoteVersion
mojangVersion version =
  MinecraftRemoteVersion
    { remoteVersionId = mojangVersionId version
    , remoteVersionType = mojangVersionType version
    , remoteVersionUrl = mojangVersionUrl version
    , remoteVersionReleaseTime = mojangVersionReleaseTime version
    }

data MojangPackage = MojangPackage
  { mojangPackageId :: VersionId
  , mojangPackageType :: Text
  , mojangPackageJavaVersion :: Maybe MojangJavaVersion
  , mojangPackageAssetIndex :: Maybe MojangAssetIndex
  , mojangPackageDownloads :: Map Text MojangDownload
  , mojangPackageLibraries :: [MojangLibrary]
  } deriving (Eq, Show)

instance FromJSON MojangPackage where
  parseJSON =
    withObject "MojangPackage" $ \obj ->
      MojangPackage
        <$> obj .: "id"
        <*> obj .:? "type" .!= "release"
        <*> obj .:? "javaVersion"
        <*> obj .:? "assetIndex"
        <*> obj .:? "downloads" .!= Map.empty
        <*> obj .:? "libraries" .!= []

newtype MojangLibrary = MojangLibrary
  { mojangLibraryDownloads :: Maybe MojangLibraryDownloads
  } deriving (Eq, Show)

instance FromJSON MojangLibrary where
  parseJSON =
    withObject "MojangLibrary" $ \obj ->
      MojangLibrary <$> obj .:? "downloads"

newtype MojangLibraryDownloads = MojangLibraryDownloads
  { mojangLibraryClassifiers :: Maybe (Map Text Value)
  } deriving (Eq, Show)

instance FromJSON MojangLibraryDownloads where
  parseJSON =
    withObject "MojangLibraryDownloads" $ \obj ->
      MojangLibraryDownloads <$> obj .:? "classifiers"

newtype MojangJavaVersion = MojangJavaVersion { mojangJavaMajorVersion :: Maybe Int }
  deriving (Eq, Show)

instance FromJSON MojangJavaVersion where
  parseJSON =
    withObject "MojangJavaVersion" $ \obj ->
      MojangJavaVersion <$> obj .:? "majorVersion"

data MojangAssetIndex = MojangAssetIndex
  { mojangAssetIndexId :: Text
  , mojangAssetIndexUrl :: Url
  , mojangAssetIndexSha1 :: Maybe Sha1
  , mojangAssetIndexSize :: Maybe Int64
  , mojangAssetIndexTotalSize :: Maybe Int64
  } deriving (Eq, Show)

instance FromJSON MojangAssetIndex where
  parseJSON =
    withObject "MojangAssetIndex" $ \obj ->
      MojangAssetIndex
        <$> obj .: "id"
        <*> obj .: "url"
        <*> obj .:? "sha1"
        <*> obj .:? "size"
        <*> obj .:? "totalSize"

data MojangDownload = MojangDownload
  { mojangDownloadUrl :: Url
  , mojangDownloadSha1 :: Maybe Sha1
  , mojangDownloadSize :: Maybe Int64
  } deriving (Eq, Show)

instance FromJSON MojangDownload where
  parseJSON =
    withObject "MojangDownload" $ \obj ->
      MojangDownload
        <$> obj .: "url"
        <*> obj .:? "sha1"
        <*> obj .:? "size"

mojangPackage :: MojangPackage -> MinecraftVersionPackage
mojangPackage package =
  MinecraftVersionPackage
    { packageId = mojangPackageId package
    , packageType = mojangPackageType package
    , packageJavaMajorVersion = mojangPackageJavaVersion package >>= mojangJavaMajorVersion
    , packageAssetIndex = mojangAssetIndex <$> mojangPackageAssetIndex package
    , packageDownloads = Map.map mojangDownload (mojangPackageDownloads package)
    , packageLibraryCount = Just (length (mojangPackageLibraries package))
    , packageNativeLibraryCount = length (filter hasNativeClassifiers (mojangPackageLibraries package))
    }

hasNativeClassifiers :: MojangLibrary -> Bool
hasNativeClassifiers library =
  case mojangLibraryDownloads library >>= mojangLibraryClassifiers of
    Just classifiers -> not (Map.null classifiers)
    Nothing -> False

mojangAssetIndex :: MojangAssetIndex -> MinecraftAssetIndex
mojangAssetIndex asset =
  MinecraftAssetIndex
    { assetIndexId = mojangAssetIndexId asset
    , assetIndexUrl = mojangAssetIndexUrl asset
    , assetIndexSha1 = mojangAssetIndexSha1 asset
    , assetIndexSizeBytes = mojangAssetIndexSize asset
    , assetIndexTotalSizeBytes = mojangAssetIndexTotalSize asset
    }

mojangDownload :: MojangDownload -> MinecraftDownload
mojangDownload download =
  MinecraftDownload
    { downloadUrl = mojangDownloadUrl download
    , downloadSha1 = mojangDownloadSha1 download
    , downloadSizeBytes = mojangDownloadSize download
    }

data FabricLoaderResponse = FabricLoaderResponse
  { fabricLoader :: LoaderVersion
  , fabricInstaller :: Maybe LoaderVersion
  } deriving (Eq, Show)

instance FromJSON FabricLoaderResponse where
  parseJSON =
    withObject "FabricLoaderResponse" $ \obj ->
      FabricLoaderResponse
        <$> obj .: "loader"
        <*> obj .:? "installer"

data QuiltLoaderResponse = QuiltLoaderResponse
  { quiltLoader :: LoaderVersion
  , quiltInstaller :: Maybe LoaderVersion
  } deriving (Eq, Show)

instance FromJSON QuiltLoaderResponse where
  parseJSON =
    withObject "QuiltLoaderResponse" $ \obj ->
      QuiltLoaderResponse
        <$> obj .: "loader"
        <*> obj .:? "installer"

data LoaderVersion = LoaderVersion
  { loaderVersionNumber :: Text
  , loaderVersionStable :: Bool
  } deriving (Eq, Show)

instance FromJSON LoaderVersion where
  parseJSON =
    withObject "LoaderVersion" $ \obj ->
      LoaderVersion
        <$> obj .: "version"
        <*> obj .:? "stable" .!= True

fabricMetadata :: Manager -> Text -> IO [LoaderMetadata]
fabricMetadata manager minecraftVersion = do
  response <-
    fetchJson manager
      =<< coreRequest
        ("https://meta.fabricmc.net/v2/versions/loader/" <> Text.unpack minecraftVersion)
        []
  pure (map (fabricLoaderMetadata minecraftVersion) response)

fabricLoaderMetadata :: Text -> FabricLoaderResponse -> LoaderMetadata
fabricLoaderMetadata minecraftVersion response =
  LoaderMetadata
    { loaderMetadataId = "fabric-" <> minecraftVersion <> "-" <> loaderVersionNumber (fabricLoader response)
    , loaderMetadataSource = "fabric"
    , loaderMetadataMinecraftVersion = minecraftVersion
    , loaderMetadataLoaderVersion = loaderVersionNumber (fabricLoader response)
    , loaderMetadataInstallerVersion = loaderVersionNumber <$> fabricInstaller response
    , loaderMetadataStable = loaderVersionStable (fabricLoader response)
    , loaderMetadataDownloadUrl = Nothing
    }

quiltMetadata :: Manager -> Text -> IO [LoaderMetadata]
quiltMetadata manager minecraftVersion = do
  response <-
    fetchJson manager
      =<< coreRequest
        ("https://meta.quiltmc.org/v3/versions/loader/" <> Text.unpack minecraftVersion)
        []
  pure (map (quiltLoaderMetadata minecraftVersion) response)

quiltLoaderMetadata :: Text -> QuiltLoaderResponse -> LoaderMetadata
quiltLoaderMetadata minecraftVersion response =
  LoaderMetadata
    { loaderMetadataId = "quilt-" <> minecraftVersion <> "-" <> loaderVersionNumber (quiltLoader response)
    , loaderMetadataSource = "quilt"
    , loaderMetadataMinecraftVersion = minecraftVersion
    , loaderMetadataLoaderVersion = loaderVersionNumber (quiltLoader response)
    , loaderMetadataInstallerVersion = loaderVersionNumber <$> quiltInstaller response
    , loaderMetadataStable = loaderVersionStable (quiltLoader response) && effectiveStableLoaderVersion (loaderVersionNumber (quiltLoader response))
    , loaderMetadataDownloadUrl = Nothing
    }

newtype ForgePromotions = ForgePromotions
  { forgePromos :: Map Text Text
  } deriving (Eq, Show)

instance FromJSON ForgePromotions where
  parseJSON =
    withObject "ForgePromotions" $ \obj ->
      ForgePromotions <$> obj .:? "promos" .!= Map.empty

forgeMetadata :: Manager -> Text -> IO [LoaderMetadata]
forgeMetadata manager minecraftVersion = do
  response <-
    fetchJson manager
      =<< coreRequest "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json" []
  pure
    [ LoaderMetadata
        { loaderMetadataId = "forge-" <> minecraftVersion <> "-" <> version
        , loaderMetadataSource = "forge"
        , loaderMetadataMinecraftVersion = minecraftVersion
        , loaderMetadataLoaderVersion = version
        , loaderMetadataInstallerVersion = Nothing
        , loaderMetadataStable = "-recommended" `Text.isSuffixOf` key
        , loaderMetadataDownloadUrl = Nothing
        }
    | (key, version) <- Map.toList (forgePromos response)
    , (minecraftVersion <> "-") `Text.isPrefixOf` key
    ]

neoForgeMetadata :: Manager -> Text -> IO [LoaderMetadata]
neoForgeMetadata manager minecraftVersion = do
  xml <- fetchText manager =<< coreRequest "https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml" []
  pure
    [ LoaderMetadata
        { loaderMetadataId = "neoforge-" <> version
        , loaderMetadataSource = "neoForge"
        , loaderMetadataMinecraftVersion = minecraftVersion
        , loaderMetadataLoaderVersion = version
        , loaderMetadataInstallerVersion = Nothing
        , loaderMetadataStable = not ("beta" `Text.isInfixOf` Text.toLower version)
        , loaderMetadataDownloadUrl = Nothing
        }
    | version <- xmlVersions xml
    , minecraftVersion `Text.isPrefixOf` version || ("." <> minecraftVersion <> ".") `Text.isInfixOf` version
    ]

xmlVersions :: Text -> [Text]
xmlVersions text =
  mapMaybe betweenVersionTag (Text.splitOn "<version>" text)
  where
    betweenVersionTag chunk =
      case Text.splitOn "</version>" chunk of
        value : _ | not (Text.null value) && value /= chunk -> Just value
        _ -> Nothing
