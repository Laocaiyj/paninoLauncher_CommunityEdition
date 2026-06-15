{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Content.Common
  ( allowedContentSubdirs
  , byteToHex
  , contentDependencyKey
  , contentTargetLoaderCompatible
  , inferLoaderFromVersionIds
  , installedVersionIdsInGameDir
  , isAllowedContentUrl
  , isCurseForgeRequest
  , isPaninoIsolatedInstanceDir
  , matchesAnyMinecraftVersion
  , missingRequiredDependency
  , normalizeLoader
  , normalizeLookupText
  , normalizePathText
  , safeContentFileName
  , safeListDirectory
  , samePath
  , shortContentHash
  , sumMaybe
  , unresolvedOptionalDependency
  , unresolvedRequiredDependency
  ) where

import Control.Exception (SomeException, catch)
import qualified Crypto.Hash.SHA1 as SHA1
import qualified Data.ByteString as BS
import Data.List (sortOn)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Data.Word (Word8)
import Numeric (showHex)
import Panino.Api.Types
import System.Directory (doesFileExist, listDirectory)
import System.FilePath (dropExtension, takeDirectory, takeExtension, takeFileName, (</>))

allowedContentSubdirs :: [FilePath]
allowedContentSubdirs =
  [ "mods"
  , "resourcepacks"
  , "shaderpacks"
  ]

contentDependencyKey :: ContentInstallDependency -> Text
contentDependencyKey dependency =
  Text.intercalate
    "|"
    [ Text.toLower (fromMaybe "" (contentDependencySource dependency))
    , Text.toLower (fromMaybe "" (contentDependencyProjectId dependency))
    , Text.toLower (fromMaybe "" (contentDependencyVersionId dependency))
    , Text.toLower (contentDependencyName dependency)
    ]

samePath :: FilePath -> FilePath -> Bool
samePath lhs rhs =
  normalizePathText lhs == normalizePathText rhs

normalizePathText :: FilePath -> Text
normalizePathText =
  Text.dropWhileEnd (== '/') . Text.pack

isPaninoIsolatedInstanceDir :: FilePath -> Bool
isPaninoIsolatedInstanceDir path =
  takeFileName (takeDirectory path) == "versions"
    && takeFileName (takeDirectory (takeDirectory path)) == "minecraft"

installedVersionIdsInGameDir :: FilePath -> IO [Text]
installedVersionIdsInGameDir gameDir = do
  entries <- safeListDirectory gameDir
  let directIds =
        [ Text.pack (dropExtension entry)
        | entry <- entries
        , takeExtension entry == ".json"
        , (dropExtension entry <> ".jar") `elem` entries
        ]
  nestedEntries <- safeListDirectory (gameDir </> "versions")
  nestedIds <- traverse nestedVersionId nestedEntries
  pure (uniqueTexts (directIds <> concat nestedIds))
  where
    nestedVersionId entry = do
      let versionDir = gameDir </> "versions" </> entry
          jsonPath = versionDir </> (entry <> ".json")
          jarPath = versionDir </> (entry <> ".jar")
      jsonPresent <- doesFileExist jsonPath
      jarPresent <- doesFileExist jarPath
      pure [Text.pack entry | jsonPresent || jarPresent]

safeListDirectory :: FilePath -> IO [FilePath]
safeListDirectory path =
  sortOn id <$> listDirectory path `catch` \(_ :: SomeException) -> pure []

uniqueTexts :: [Text] -> [Text]
uniqueTexts = foldr insertText []
  where
    insertText value values
      | Text.null value = values
      | value `elem` values = values
      | otherwise = value : values

matchesAnyMinecraftVersion :: [Text] -> Text -> Bool
matchesAnyMinecraftVersion allowed target =
  any matches allowed
  where
    normalizedTarget = Text.toLower target
    matches version =
      let normalizedVersion = Text.toLower version
       in normalizedTarget == normalizedVersion
            || Text.isSuffixOf ("-" <> normalizedVersion) normalizedTarget

contentTargetLoaderCompatible :: FilePath -> [Text] -> Maybe Text -> Bool
contentTargetLoaderCompatible targetSubdir releaseLoaderValues maybeTargetLoader =
  case targetSubdir of
    "resourcepacks" -> True
    "mods" ->
      case maybeTargetLoader of
        Nothing -> False
        Just targetLoader ->
          not (null releaseLoaderValues)
            && normalizeLoader targetLoader `elem` map normalizeLoader releaseLoaderValues
    "shaderpacks" ->
      shaderTargetCompatible releaseLoaderValues maybeTargetLoader
    _ -> False

shaderTargetCompatible :: [Text] -> Maybe Text -> Bool
shaderTargetCompatible releaseLoaderValues maybeTargetLoader
  | null releaseLoaderValues = True
  | otherwise =
      case maybeTargetLoader of
        Nothing -> any ((== "optifine") . normalizeLoader) releaseLoaderValues
        Just targetLoader ->
          let normalizedTarget = normalizeLoader targetLoader
              normalizedReleaseLoaders = map normalizeLoader releaseLoaderValues
           in any (`elem` normalizedReleaseLoaders) [normalizedTarget, "optifine"]
                || ("iris" `elem` normalizedReleaseLoaders && normalizedTarget `elem` ["fabric", "quilt"])
                || ("oculus" `elem` normalizedReleaseLoaders && normalizedTarget `elem` ["forge", "neoforge"])

inferLoaderFromVersionIds :: [Text] -> Maybe Text
inferLoaderFromVersionIds versionIds
  | any (Text.isInfixOf "neoforge" . Text.toLower) versionIds = Just "neoforge"
  | any (Text.isInfixOf "fabric" . Text.toLower) versionIds = Just "fabric"
  | any (Text.isInfixOf "quilt" . Text.toLower) versionIds = Just "quilt"
  | any (Text.isInfixOf "forge" . Text.toLower) versionIds = Just "forge"
  | otherwise = Nothing

isAllowedContentUrl :: Text -> Bool
isAllowedContentUrl value =
  "https://" `Text.isPrefixOf` Text.toLower value
    || "http://" `Text.isPrefixOf` Text.toLower value

missingRequiredDependency :: ContentInstallDependency -> Bool
missingRequiredDependency dependency =
  contentDependencyRequired dependency
    && contentDependencyInstalled dependency == Just False

unresolvedRequiredDependency :: ContentInstallDependency -> Bool
unresolvedRequiredDependency dependency =
  contentDependencyRequired dependency
    && contentDependencyInstalled dependency == Nothing

unresolvedOptionalDependency :: ContentInstallDependency -> Bool
unresolvedOptionalDependency dependency =
  not (contentDependencyRequired dependency)
    && contentDependencyInstalled dependency == Nothing

isCurseForgeRequest :: ContentInstallRequest -> Bool
isCurseForgeRequest request =
  normalizeLoader (contentInstallSource request) `elem` ["curseforge", "curseforgeadvanced"]

normalizeLoader :: Text -> Text
normalizeLoader =
  Text.toLower . Text.replace "-" "" . Text.replace "_" ""

normalizeLookupText :: Text -> Text
normalizeLookupText =
  Text.filter (\char -> char /= '-' && char /= '_' && char /= '.' && char /= ' ')
    . Text.toLower


byteToHex :: Word8 -> String
byteToHex byte =
  case showHex byte "" of
    [single] -> ['0', single]
    pair -> pair

shortContentHash :: Text -> Text
shortContentHash =
  Text.take 16 . Text.pack . concatMap byteToHex . BS.unpack . SHA1.hash . Text.encodeUtf8


safeContentFileName :: Text -> FilePath
safeContentFileName value =
  case takeFileName (Text.unpack value) of
    "" -> "download.bin"
    "." -> "download.bin"
    ".." -> "download.bin"
    cleanName -> cleanName

sumMaybe :: Num value => [Maybe value] -> Maybe value
sumMaybe values =
  sum <$> sequenceA values
