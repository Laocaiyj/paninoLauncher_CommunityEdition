{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Runtime.Java.Catalog
  ( catalogForRuntime
  , catalogForRuntimeWithProvider
  , defaultRuntimeArch
  , defaultRuntimeOs
  , runtimeDownloadSpec
  , runtimeDownloadSpecForProvider
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( FromJSON(..)
  , Result(..)
  , Value(..)
  , eitherDecode
  , fromJSON
  , withObject
  , (.:)
  , (.:?)
  )
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as BL
import Data.Char (isAlphaNum)
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock
  ( UTCTime
  , getCurrentTime
  )
import Network.HTTP.Client (Manager)
import Panino.Net.Http
  ( RequestTimeoutClass(..)
  , coreRequestWithTimeout
  , fetchJson
  )
import Panino.Runtime.Java.Types
  ( JavaRuntimeCatalogItem(..)
  , JavaRuntimeDownloadSpec(..)
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  )
import System.Info (arch, os)

catalogForRuntime :: Int -> Text -> Text -> Text -> [JavaRuntimeCatalogItem]
catalogForRuntime featureVersion runtimeOs runtimeArch imageType =
  [ JavaRuntimeCatalogItem
      { catalogRuntimeId = runtimeCatalogId featureVersion runtimeOs runtimeArch imageType
      , catalogRuntimeName = "Java " <> Text.pack (show featureVersion)
      , catalogRuntimeProvider = "adoptium"
      , catalogRuntimeVendor = "temurin"
      , catalogRuntimeFeatureVersion = featureVersion
      , catalogRuntimeOs = runtimeOs
      , catalogRuntimeArch = runtimeArch
      , catalogRuntimeImageType = imageType
      , catalogRuntimeDownload = runtimeDownloadSpec featureVersion runtimeOs runtimeArch imageType
      , catalogRuntimeStale = False
      , catalogRuntimeCachedAt = Nothing
      , catalogRuntimeWarnings = []
      }
  ]

catalogForRuntimeWithProvider :: Manager -> FilePath -> Maybe Text -> Int -> Text -> Text -> Text -> IO [JavaRuntimeCatalogItem]
catalogForRuntimeWithProvider manager appRoot maybeProvider featureVersion runtimeOs runtimeArch imageType =
  case normalizeProvider (fromMaybe "adoptium" maybeProvider) of
    "all" ->
      concat
        <$> traverse
          (\provider -> catalogForRuntimeWithProvider manager appRoot (Just provider) featureVersion runtimeOs runtimeArch imageType)
          ["adoptium", "zulu", "mojang"]
    "zulu" ->
      cachedProviderCatalog manager appRoot "zulu" featureVersion runtimeOs runtimeArch imageType $
        zuluCatalogForRuntime manager featureVersion runtimeOs runtimeArch imageType
    "mojang" ->
      cachedProviderCatalog manager appRoot "mojang" featureVersion runtimeOs runtimeArch imageType $
        mojangCatalogForRuntime manager featureVersion runtimeOs runtimeArch imageType
    _ ->
      cachedProviderCatalog manager appRoot "adoptium" featureVersion runtimeOs runtimeArch imageType $
        pure (catalogForRuntime featureVersion runtimeOs runtimeArch imageType)

runtimeDownloadSpecForProvider :: Manager -> Text -> Int -> Text -> Text -> Text -> IO JavaRuntimeDownloadSpec
runtimeDownloadSpecForProvider manager provider featureVersion runtimeOs runtimeArch imageType =
  case normalizeProvider provider of
    "zulu" -> zuluRuntimeDownloadSpec manager featureVersion runtimeOs runtimeArch imageType
    "mojang" -> mojangRuntimeDownloadSpec manager featureVersion runtimeOs runtimeArch imageType
    _ -> pure (runtimeDownloadSpec featureVersion runtimeOs runtimeArch imageType)

runtimeDownloadSpec :: Int -> Text -> Text -> Text -> JavaRuntimeDownloadSpec
runtimeDownloadSpec featureVersion runtimeOs runtimeArch imageType =
  JavaRuntimeDownloadSpec
    { runtimeDownloadProvider = "adoptium"
    , runtimeDownloadVendor = "temurin"
    , runtimeDownloadFeatureVersion = featureVersion
    , runtimeDownloadOs = runtimeOs
    , runtimeDownloadArch = runtimeArch
    , runtimeDownloadImageType = imageType
    , runtimeDownloadUrl = url
    , runtimeDownloadChecksumUrl = Just (url <> ".sha256.txt")
    , runtimeDownloadSha256 = Nothing
    }
  where
    url =
      Text.concat
        [ "https://api.adoptium.net/v3/binary/latest/"
        , Text.pack (show featureVersion)
        , "/ga/"
        , runtimeOs
        , "/"
        , runtimeArch
        , "/"
        , imageType
        , "/hotspot/normal/eclipse"
        ]

runtimeCatalogId :: Int -> Text -> Text -> Text -> Text
runtimeCatalogId featureVersion runtimeOs runtimeArch imageType =
  Text.intercalate
    "-"
    [ "temurin"
    , Text.pack (show featureVersion)
    , runtimeOs
    , runtimeArch
    , imageType
    ]

defaultRuntimeOs :: Text
defaultRuntimeOs =
  case os of
    "darwin" -> "mac"
    "mingw32" -> "windows"
    "linux" -> "linux"
    other -> Text.pack other

defaultRuntimeArch :: Text
defaultRuntimeArch =
  case arch of
    "aarch64" -> "aarch64"
    "x86_64" -> "x64"
    "i386" -> "x86"
    other -> Text.pack other

cachedProviderCatalog :: Manager -> FilePath -> Text -> Int -> Text -> Text -> Text -> IO [JavaRuntimeCatalogItem] -> IO [JavaRuntimeCatalogItem]
cachedProviderCatalog _ appRoot provider featureVersion runtimeOs runtimeArch imageType loadFresh = do
  let path = catalogCachePath appRoot provider featureVersion runtimeOs runtimeArch imageType
  result <- try loadFresh
  case result of
    Right items -> do
      now <- getCurrentTime
      let stamped = map (markCatalogFresh now) items
      createDirectoryIfMissing True (takeDirectory path)
      BL.writeFile path (Aeson.encode stamped)
      pure stamped
    Left (_ :: SomeException) -> do
      cached <- readCatalogCache path
      pure (map markCatalogStale cached)

readCatalogCache :: FilePath -> IO [JavaRuntimeCatalogItem]
readCatalogCache path = do
  exists <- doesFileExist path
  if not exists
    then pure []
    else do
      decoded <- eitherDecode <$> BL.readFile path
      case decoded of
        Right items -> pure items
        Left _ -> pure []

catalogCachePath :: FilePath -> Text -> Int -> Text -> Text -> Text -> FilePath
catalogCachePath appRoot provider featureVersion runtimeOs runtimeArch imageType =
  appRoot
    </> "runtimes"
    </> "java"
    </> "catalog"
    </> Text.unpack (sanitizeText (Text.intercalate "-" [provider, Text.pack (show featureVersion), runtimeOs, runtimeArch, imageType]) <> ".json")

markCatalogFresh :: UTCTime -> JavaRuntimeCatalogItem -> JavaRuntimeCatalogItem
markCatalogFresh now item =
  item { catalogRuntimeStale = False, catalogRuntimeCachedAt = Just now }

markCatalogStale :: JavaRuntimeCatalogItem -> JavaRuntimeCatalogItem
markCatalogStale item =
  item
    { catalogRuntimeStale = True
    , catalogRuntimeWarnings =
        uniqueText (catalogRuntimeWarnings item <> ["Provider catalog is stale; using cached runtime metadata."])
    }

zuluCatalogForRuntime :: Manager -> Int -> Text -> Text -> Text -> IO [JavaRuntimeCatalogItem]
zuluCatalogForRuntime manager featureVersion runtimeOs runtimeArch imageType = do
  spec <- zuluRuntimeDownloadSpec manager featureVersion runtimeOs runtimeArch imageType
  pure
    [ JavaRuntimeCatalogItem
        { catalogRuntimeId = zuluRuntimeCatalogId spec
        , catalogRuntimeName = "Java " <> Text.pack (show featureVersion) <> " (Zulu)"
        , catalogRuntimeProvider = "zulu"
        , catalogRuntimeVendor = "zulu"
        , catalogRuntimeFeatureVersion = featureVersion
        , catalogRuntimeOs = runtimeOs
        , catalogRuntimeArch = runtimeArch
        , catalogRuntimeImageType = imageType
        , catalogRuntimeDownload = spec
        , catalogRuntimeStale = False
        , catalogRuntimeCachedAt = Nothing
        , catalogRuntimeWarnings = []
        }
    ]

zuluRuntimeDownloadSpec :: Manager -> Int -> Text -> Text -> Text -> IO JavaRuntimeDownloadSpec
zuluRuntimeDownloadSpec manager featureVersion runtimeOs runtimeArch imageType = do
  packages <- fetchJson manager =<< coreRequestWithTimeout LongMetadata (Text.unpack (zuluMetadataUrl featureVersion runtimeOs runtimeArch imageType)) []
  package <- maybe (fail "java_runtime_download_not_found: Zulu did not return a matching runtime") pure (listToMaybe packages)
  pure JavaRuntimeDownloadSpec
    { runtimeDownloadProvider = "zulu"
    , runtimeDownloadVendor = "zulu"
    , runtimeDownloadFeatureVersion = featureVersion
    , runtimeDownloadOs = runtimeOs
    , runtimeDownloadArch = runtimeArch
    , runtimeDownloadImageType = imageType
    , runtimeDownloadUrl = zuluPackageDownloadUrl package
    , runtimeDownloadChecksumUrl = Nothing
    , runtimeDownloadSha256 = zuluPackageSha256 package
    }

zuluMetadataUrl :: Int -> Text -> Text -> Text -> Text
zuluMetadataUrl featureVersion runtimeOs runtimeArch imageType =
  Text.concat
    [ "https://api.azul.com/metadata/v1/zulu/packages/?java_version="
    , Text.pack (show featureVersion)
    , "&os="
    , zuluOs runtimeOs
    , "&arch="
    , zuluArch runtimeArch
    , "&archive_type=tar.gz&java_package_type="
    , imageType
    , "&javafx_bundled=false&release_status=ga&availability_types=CA&certifications=tck&latest=true&page=1&page_size=1&include_fields=sha256_hash"
    ]

zuluRuntimeCatalogId :: JavaRuntimeDownloadSpec -> Text
zuluRuntimeCatalogId spec =
  Text.intercalate
    "-"
    [ "zulu"
    , Text.pack (show (runtimeDownloadFeatureVersion spec))
    , runtimeDownloadOs spec
    , runtimeDownloadArch spec
    , runtimeDownloadImageType spec
    ]

zuluOs :: Text -> Text
zuluOs value =
  case normalizeProvider value of
    "mac" -> "macos"
    "windows" -> "windows"
    "linux" -> "linux"
    other -> other

zuluArch :: Text -> Text
zuluArch value =
  case normalizeProvider value of
    "aarch64" -> "arm"
    "arm64" -> "arm"
    "x64" -> "x64"
    "x86_64" -> "x64"
    other -> other

data ZuluPackage = ZuluPackage
  { zuluPackageDownloadUrl :: Text
  , zuluPackageSha256 :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON ZuluPackage where
  parseJSON =
    withObject "ZuluPackage" $ \obj ->
      ZuluPackage
        <$> obj .: "download_url"
        <*> obj .:? "sha256_hash"

mojangCatalogForRuntime :: Manager -> Int -> Text -> Text -> Text -> IO [JavaRuntimeCatalogItem]
mojangCatalogForRuntime manager featureVersion runtimeOs runtimeArch imageType = do
  spec <- mojangRuntimeDownloadSpec manager featureVersion runtimeOs runtimeArch imageType
  pure
    [ JavaRuntimeCatalogItem
        { catalogRuntimeId =
            Text.intercalate
              "-"
              [ "mojang"
              , mojangComponentForFeature featureVersion
              , Text.pack (show featureVersion)
              , runtimeOs
              , runtimeArch
              ]
        , catalogRuntimeName = "Java " <> Text.pack (show featureVersion) <> " (Mojang runtime)"
        , catalogRuntimeProvider = "mojang"
        , catalogRuntimeVendor = "mojang"
        , catalogRuntimeFeatureVersion = featureVersion
        , catalogRuntimeOs = runtimeOs
        , catalogRuntimeArch = runtimeArch
        , catalogRuntimeImageType = imageType
        , catalogRuntimeDownload = spec
        , catalogRuntimeStale = False
        , catalogRuntimeCachedAt = Nothing
        , catalogRuntimeWarnings = ["Installs from Mojang runtime file manifest instead of a single archive."]
        }
    ]

mojangRuntimeDownloadSpec :: Manager -> Int -> Text -> Text -> Text -> IO JavaRuntimeDownloadSpec
mojangRuntimeDownloadSpec manager featureVersion runtimeOs runtimeArch imageType = do
  entry <- mojangRuntimeEntry manager featureVersion runtimeOs runtimeArch
  pure JavaRuntimeDownloadSpec
    { runtimeDownloadProvider = "mojang"
    , runtimeDownloadVendor = "mojang"
    , runtimeDownloadFeatureVersion = featureVersion
    , runtimeDownloadOs = runtimeOs
    , runtimeDownloadArch = runtimeArch
    , runtimeDownloadImageType = imageType
    , runtimeDownloadUrl = mojangEntryManifestUrl entry
    , runtimeDownloadChecksumUrl = Nothing
    , runtimeDownloadSha256 = Just (mojangEntryManifestSha1 entry)
    }

mojangRuntimeEntry :: Manager -> Int -> Text -> Text -> IO MojangRuntimeEntry
mojangRuntimeEntry manager featureVersion runtimeOs runtimeArch = do
  value <- fetchJson manager =<< coreRequestWithTimeout LongMetadata (Text.unpack mojangRuntimeIndexUrl) []
  let platform = mojangPlatformKey runtimeOs runtimeArch
      component = mojangComponentForFeature featureVersion
  maybe
    (fail ("java_runtime_download_not_found: Mojang runtime " <> Text.unpack component <> " is not available for " <> Text.unpack platform))
    pure
    (findMojangEntry platform component value)

findMojangEntry :: Text -> Text -> Value -> Maybe MojangRuntimeEntry
findMojangEntry platform component (Object root) = do
  Object platformMap <- KeyMap.lookup (Key.fromText platform) root
  packageValue <- KeyMap.lookup (Key.fromText component) platformMap
  case fromJSON packageValue of
    Success entries -> listToMaybe entries
    Error _ -> Nothing
findMojangEntry _ _ _ =
  Nothing

data MojangRuntimeEntry = MojangRuntimeEntry
  { mojangEntryVersionName :: Text
  , mojangEntryManifestUrl :: Text
  , mojangEntryManifestSha1 :: Text
  } deriving (Eq, Show)

instance FromJSON MojangRuntimeEntry where
  parseJSON =
    withObject "MojangRuntimeEntry" $ \obj -> do
      manifest <- obj .: "manifest"
      version <- obj .: "version"
      MojangRuntimeEntry
        <$> version .: "name"
        <*> manifest .: "url"
        <*> manifest .: "sha1"

mojangRuntimeIndexUrl :: Text
mojangRuntimeIndexUrl =
  "https://piston-meta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json"

mojangPlatformKey :: Text -> Text -> Text
mojangPlatformKey runtimeOs runtimeArch =
  case (normalizeProvider runtimeOs, normalizeProvider runtimeArch) of
    ("mac", "aarch64") -> "mac-os-arm64"
    ("mac", "arm64") -> "mac-os-arm64"
    ("mac", _) -> "mac-os"
    ("windows", "x86") -> "windows-x86"
    ("windows", "x64") -> "windows-x64"
    ("windows", "aarch64") -> "windows-arm64"
    ("windows", "arm64") -> "windows-arm64"
    ("linux", "x86") -> "linux-i386"
    ("linux", _) -> "linux"
    (other, _) -> other

mojangComponentForFeature :: Int -> Text
mojangComponentForFeature featureVersion
  | featureVersion >= 25 = "java-runtime-epsilon"
  | featureVersion >= 21 = "java-runtime-delta"
  | featureVersion >= 17 = "java-runtime-gamma"
  | featureVersion >= 16 = "java-runtime-alpha"
  | otherwise = "jre-legacy"

normalizeProvider :: Text -> Text
normalizeProvider =
  Text.toLower . Text.strip

sanitizeText :: Text -> Text
sanitizeText =
  Text.map sanitizeChar
  where
    sanitizeChar char
      | isAlphaNum char = char
      | char `elem` ("._-+" :: String) = char
      | otherwise = '-'

uniqueText :: [Text] -> [Text]
uniqueText =
  foldr (\value seen -> if value `elem` seen then seen else value : seen) []
