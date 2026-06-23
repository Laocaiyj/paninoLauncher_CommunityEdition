{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Configuration.Modpack.Manifest
  ( CurseManifestFile(..)
  , ModpackPlanFile(..)
  , curseFileKey
  , curseFileToMrpackFile
  , curseFiles
  , curseMinecraftVersion
  , curseModLoaders
  , curseOverrides
  , fieldName
  , loaderFromDependencies
  , loaderNameFromId
  , loaderVersionFromDependencies
  , loaderVersionFromId
  , lookupText
  , modpackFileKey
  , modrinthDependencies
  , modrinthFiles
  , sumMaybe
  , unzipNames
  , unzipText
  ) where

import Control.Exception (try)
import Data.Aeson
  ( Object
  , Value(..)
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Aeson.Types (Parser)
import Data.Foldable (find)
import Data.Int (Int64)
import Data.List (sort)
import Data.Maybe
  ( mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.CoreLogic.Determinism
  ( stableSortOnText
  )
import System.Exit (ExitCode(..))
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )

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
    , maybe "" id (mrpackFileSha1 file)
    , maybe "" id (mrpackFileUrl file)
    , maybe "" (Text.pack . show) (mrpackFileSize file)
    ]

curseFileKey :: CurseManifestFile -> Text
curseFileKey file =
  Text.pack (show (curseManifestProjectId file))
    <> "|"
    <> Text.pack (show (curseManifestFileId file))

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

lookupText :: Text -> [(Text, Text)] -> Maybe Text
lookupText key values = lookup key values

loaderFromDependencies :: [(Text, Text)] -> Maybe Text
loaderFromDependencies values =
  normalizeLoaderKey . fst <$> find ((`elem` ["fabric-loader", "forge", "quilt-loader", "neoforge"]) . fst) values

loaderVersionFromDependencies :: [(Text, Text)] -> Maybe Text
loaderVersionFromDependencies values =
  snd <$> find ((`elem` ["fabric-loader", "forge", "quilt-loader", "neoforge"]) . fst) values

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

sumMaybe :: [Maybe Int64] -> Maybe Int64
sumMaybe values =
  if any (== Nothing) values
    then Nothing
    else Just (sum (mapMaybe id values))

traverseKeyValues :: Object -> Parser [(Text, Text)]
traverseKeyValues objectValue =
  pure
    [ (key, value)
    | (key, String value) <- objectToList objectValue
    ]

objectToList :: Object -> [(Text, Value)]
objectToList =
  stableSortOnText fst . map (\(key, value) -> (Key.toText key, value)) . KeyMap.toList

normalizeLoaderKey :: Text -> Text
normalizeLoaderKey "fabric-loader" = "fabric"
normalizeLoaderKey "quilt-loader" = "quilt"
normalizeLoaderKey "neoforge" = "neoForge"
normalizeLoaderKey value = value

listToMaybeCompat :: [a] -> Maybe a
listToMaybeCompat [] = Nothing
listToMaybeCompat (value : _) = Just value
