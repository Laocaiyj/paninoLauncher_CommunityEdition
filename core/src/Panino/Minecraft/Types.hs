{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.Types
  ( ArgPiece(..)
  , AssetIndex(..)
  , AssetObject(..)
  , DownloadInfo(..)
  , JavaVersion(..)
  , Library(..)
  , LibraryDownloads(..)
  , OsRule(..)
  , Rule(..)
  , RuleAction(..)
  , VersionArguments(..)
  , VersionJson(..)
  , VersionManifest(..)
  , VersionSummary(..)
  , allowedArgValues
  , currentMinecraftArch
  , currentMinecraftOs
  , isAllowedByRules
  ) where

import Data.Aeson
  ( FromJSON(..)
  , Object
  , Value(..)
  , withObject
  , withText
  , (.:)
  , (.:?)
  , (.!=)
  )
import Data.Aeson.Types (Parser)
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Core.Types
  ( RelativePath
  , Sha1
  , Url
  , VersionId
  )
import System.Info (arch, os)

data VersionManifest = VersionManifest
  { manifestVersions :: [VersionSummary]
  } deriving (Eq, Show)

instance FromJSON VersionManifest where
  parseJSON = withObject "VersionManifest" $ \obj ->
    VersionManifest <$> obj .: "versions"

data VersionSummary = VersionSummary
  { versionSummaryId :: VersionId
  , versionSummaryUrl :: Url
  , versionSummarySha1 :: Maybe Sha1
  } deriving (Eq, Show)

instance FromJSON VersionSummary where
  parseJSON = withObject "VersionSummary" $ \obj ->
    VersionSummary
      <$> obj .: "id"
      <*> obj .: "url"
      <*> obj .:? "sha1"

data VersionJson = VersionJson
  { versionId :: VersionId
  , versionType :: Maybe Text
  , versionJavaVersion :: Maybe JavaVersion
  , versionDownloads :: Map Text DownloadInfo
  , versionAssetIndex :: DownloadInfo
  , versionLibraries :: [Library]
  , versionMainClass :: Text
  , versionArguments :: Maybe VersionArguments
  , versionMinecraftArguments :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON VersionJson where
  parseJSON = withObject "VersionJson" $ \obj ->
    VersionJson
      <$> obj .: "id"
      <*> obj .:? "type"
      <*> obj .:? "javaVersion"
      <*> obj .: "downloads"
      <*> obj .: "assetIndex"
      <*> obj .: "libraries"
      <*> obj .: "mainClass"
      <*> obj .:? "arguments"
      <*> obj .:? "minecraftArguments"

data JavaVersion = JavaVersion
  { javaVersionComponent :: Maybe Text
  , javaVersionMajorVersion :: Maybe Int
  } deriving (Eq, Show)

instance FromJSON JavaVersion where
  parseJSON = withObject "JavaVersion" $ \obj ->
    JavaVersion
      <$> obj .:? "component"
      <*> obj .:? "majorVersion"

data VersionArguments = VersionArguments
  { versionGameArguments :: [ArgPiece]
  , versionJvmArguments :: [ArgPiece]
  } deriving (Eq, Show)

instance FromJSON VersionArguments where
  parseJSON = withObject "VersionArguments" $ \obj ->
    VersionArguments
      <$> obj .: "game"
      <*> obj .: "jvm"

data ArgPiece
  = ArgLiteral [Text]
  | ArgConditional [Rule] [Text]
  deriving (Eq, Show)

instance FromJSON ArgPiece where
  parseJSON value@(String _) = ArgLiteral <$> parseArgValue value
  parseJSON (Object obj) =
    ArgConditional
      <$> obj .:? "rules" .!= []
      <*> (obj .: "value" >>= parseArgValue)
  parseJSON invalid = fail ("unsupported argument piece: " <> show invalid)

parseArgValue :: Value -> Parser [Text]
parseArgValue = \case
  String text -> pure [text]
  Array items -> traverse (withText "argument value" pure) (toList items)
  invalid -> fail ("unsupported argument value: " <> show invalid)

data DownloadInfo = DownloadInfo
  { downloadId :: Maybe Text
  , downloadSha1 :: Maybe Sha1
  , downloadSize :: Maybe Int64
  , downloadUrl :: Maybe Url
  , downloadPath :: Maybe RelativePath
  } deriving (Eq, Show)

instance FromJSON DownloadInfo where
  parseJSON = withObject "DownloadInfo" $ \obj ->
    DownloadInfo
      <$> obj .:? "id"
      <*> obj .:? "sha1"
      <*> obj .:? "size"
      <*> obj .:? "url"
      <*> obj .:? "path"

data Library = Library
  { libraryName :: Text
  , libraryDownloads :: Maybe LibraryDownloads
  , libraryUrl :: Maybe Url
  , libraryRules :: [Rule]
  , libraryNatives :: Map Text Text
  } deriving (Eq, Show)

instance FromJSON Library where
  parseJSON = withObject "Library" $ \obj ->
    Library
      <$> obj .: "name"
      <*> obj .:? "downloads"
      <*> obj .:? "url"
      <*> obj .:? "rules" .!= []
      <*> obj .:? "natives" .!= Map.empty

data LibraryDownloads = LibraryDownloads
  { libraryArtifact :: Maybe DownloadInfo
  , libraryClassifiers :: Map Text DownloadInfo
  } deriving (Eq, Show)

instance FromJSON LibraryDownloads where
  parseJSON = withObject "LibraryDownloads" $ \obj ->
    LibraryDownloads
      <$> obj .:? "artifact"
      <*> obj .:? "classifiers" .!= Map.empty

data AssetIndex = AssetIndex
  { assetObjects :: Map Text AssetObject
  } deriving (Eq, Show)

instance FromJSON AssetIndex where
  parseJSON = withObject "AssetIndex" $ \obj ->
    AssetIndex <$> obj .: "objects"

data AssetObject = AssetObject
  { assetHash :: Sha1
  , assetSize :: Int64
  } deriving (Eq, Show)

instance FromJSON AssetObject where
  parseJSON = withObject "AssetObject" $ \obj ->
    AssetObject
      <$> obj .: "hash"
      <*> obj .: "size"

data Rule = Rule
  { ruleAction :: RuleAction
  , ruleOs :: Maybe OsRule
  , ruleFeatures :: Map Text Bool
  } deriving (Eq, Show)

instance FromJSON Rule where
  parseJSON = withObject "Rule" $ \obj ->
    Rule
      <$> obj .: "action"
      <*> obj .:? "os"
      <*> parseFeatures obj

data RuleAction
  = Allow
  | Disallow
  deriving (Eq, Show)

instance FromJSON RuleAction where
  parseJSON = withText "RuleAction" $ \case
    "allow" -> pure Allow
    "disallow" -> pure Disallow
    other -> fail ("unknown rule action: " <> Text.unpack other)

data OsRule = OsRule
  { osRuleName :: Maybe Text
  , osRuleArch :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON OsRule where
  parseJSON = withObject "OsRule" $ \obj ->
    OsRule
      <$> obj .:? "name"
      <*> obj .:? "arch"

allowedArgValues :: [ArgPiece] -> [Text]
allowedArgValues = concatMap values
  where
    values (ArgLiteral raw) = raw
    values (ArgConditional rules raw)
      | isAllowedByRules rules = raw
      | otherwise = []

isAllowedByRules :: [Rule] -> Bool
isAllowedByRules [] = True
isAllowedByRules rules = foldl applyRule False rules
  where
    applyRule allowed rule
      | ruleMatches rule =
          case ruleAction rule of
            Allow -> True
            Disallow -> False
      | otherwise = allowed

ruleMatches :: Rule -> Bool
ruleMatches rule = osMatches (ruleOs rule) && featuresMatch (ruleFeatures rule)

osMatches :: Maybe OsRule -> Bool
osMatches Nothing = True
osMatches (Just rule) =
  matches osRuleName currentMinecraftOs
    && matches osRuleArch currentMinecraftArch
  where
    matches getter current = maybe True (== current) (getter rule)

featuresMatch :: Map Text Bool -> Bool
featuresMatch = Map.foldr (&&) True . Map.map not

currentMinecraftOs :: Text
currentMinecraftOs =
  case os of
    "darwin" -> "osx"
    "mingw32" -> "windows"
    "linux" -> "linux"
    other -> Text.pack other

currentMinecraftArch :: Text
currentMinecraftArch =
  case arch of
    "x86_64" -> "x86_64"
    "aarch64" -> "arm64"
    other -> Text.pack other

parseFeatures :: Object -> Parser (Map Text Bool)
parseFeatures obj =
  case KeyMap.lookup (Key.fromString "features") obj of
    Nothing -> pure Map.empty
    Just (Object features) -> traverse parseJSON (keyMapToTextMap features)
    Just invalid -> fail ("unsupported features object: " <> show invalid)

keyMapToTextMap :: KeyMap.KeyMap Value -> Map Text Value
keyMapToTextMap =
  Map.fromList . fmap (\(key, value) -> (Key.toText key, value)) . KeyMap.toList

toList :: Foldable f => f a -> [a]
toList = foldr (:) []
