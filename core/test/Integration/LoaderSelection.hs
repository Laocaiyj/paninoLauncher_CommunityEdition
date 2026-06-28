{-# LANGUAGE OverloadedStrings #-}

module Integration.LoaderSelection
  ( assertModrinthPreferredVersionSelection
  , assertPreferredLoaderMetadataSelection
  ) where

import qualified Data.Map.Strict as Map
import Data.Aeson (decode)
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Panino.Content.Online.Minecraft
  ( preferredLoaderMetadata
  )
import Panino.Content.Online.Types
  ( LoaderMetadata(..)
  )
import Panino.Core.Types
  ( VersionId
  , projectIdText
  , urlFromText
  , urlText
  , versionIdFromText
  , versionIdText
  )
import Panino.Minecraft.LoaderInstall
  ( ModrinthFile(..)
  , ModrinthVersion(..)
  , selectPreferredModrinthVersion
  )
import TestSupport (assertEqual)

assertModrinthPreferredVersionSelection :: IO ()
assertModrinthPreferredVersionSelection = do
  let sodium1218 =
        testModrinthVersion
          "sodium-1218"
          "Sodium 0.7.0 for Fabric 1.21.8"
          "mc1.21.8-0.7.0-fabric"
          "2026-01-02T00:00:00Z"
          "sodium-fabric-0.7.0+mc1.21.8.jar"
      sodium1217 =
        testModrinthVersion
          "sodium-1217"
          "Sodium 0.7.0 for Fabric 1.21.7"
          "mc1.21.7-0.7.0-fabric"
          "2026-01-01T00:00:00Z"
          "sodium-fabric-0.7.0+mc1.21.7.jar"
      selected =
        selectPreferredModrinthVersion "1.21.7" "quilt" [sodium1218, sodium1217]
  assertEqual
    "Modrinth selection prefers file/version text matching requested Minecraft version"
    (Just "sodium-1217")
    (versionIdText . modrinthVersionId <$> selected)
  assertEqual
    "Modrinth loader resolver JSON decodes typed ids and url"
    (Just ("typed-version", "typed-project", Just "https://cdn.modrinth.test/typed.jar"))
    (modrinthLoaderVersionSummary <$> (decode modrinthLoaderVersionJson :: Maybe ModrinthVersion))
  assertEqual
    "Modrinth loader resolver JSON rejects empty version id"
    Nothing
    (decode modrinthLoaderVersionWithEmptyIdJson :: Maybe ModrinthVersion)

testModrinthVersion :: Text -> Text -> Text -> Text -> Text -> ModrinthVersion
testModrinthVersion modrinthId displayName versionNumber publishedAt jarName =
  ModrinthVersion
    { modrinthVersionId = testVersionId modrinthId
    , modrinthVersionProjectId = "AANobbMI"
    , modrinthVersionGameVersions = ["1.21.7", "1.21.8"]
    , modrinthVersionLoaders = ["fabric", "quilt"]
    , modrinthVersionName = displayName
    , modrinthVersionNumber = versionNumber
    , modrinthVersionType = "release"
    , modrinthVersionDatePublished = Just publishedAt
    , modrinthVersionFeatured = False
    , modrinthVersionFiles =
        [ ModrinthFile
            { modrinthFileName = jarName
            , modrinthFileUrl = urlFromText ("https://cdn.modrinth.test/" <> jarName)
            , modrinthFilePrimary = True
            , modrinthFileHashes = Map.empty
            , modrinthFileSize = Just 1
            }
        ]
    , modrinthVersionDependencies = []
    }

testVersionId :: Text -> VersionId
testVersionId value =
  fromMaybe "invalid-test-version-id" (versionIdFromText value)

modrinthLoaderVersionSummary :: ModrinthVersion -> (Text, Text, Maybe Text)
modrinthLoaderVersionSummary version =
  ( versionIdText (modrinthVersionId version)
  , projectIdText (modrinthVersionProjectId version)
  , case modrinthVersionFiles version of
      file:_ -> Just (urlText (modrinthFileUrl file))
      [] -> Nothing
  )

modrinthLoaderVersionJson :: LBS.ByteString
modrinthLoaderVersionJson =
  LBS.pack $
    "{"
      <> "\"id\":\"typed-version\","
      <> "\"project_id\":\"typed-project\","
      <> "\"game_versions\":[\"1.21.7\"],"
      <> "\"loaders\":[\"fabric\"],"
      <> "\"files\":[{\"filename\":\"typed.jar\",\"url\":\"https://cdn.modrinth.test/typed.jar\"}]"
      <> "}"

modrinthLoaderVersionWithEmptyIdJson :: LBS.ByteString
modrinthLoaderVersionWithEmptyIdJson =
  LBS.pack $
    "{"
      <> "\"id\":\"\","
      <> "\"project_id\":\"typed-project\","
      <> "\"game_versions\":[\"1.21.7\"],"
      <> "\"loaders\":[\"fabric\"],"
      <> "\"files\":[{\"filename\":\"typed.jar\",\"url\":\"https://cdn.modrinth.test/typed.jar\"}]"
      <> "}"

assertPreferredLoaderMetadataSelection :: IO ()
assertPreferredLoaderMetadataSelection = do
  let loader version stable =
        LoaderMetadata
          { loaderMetadataId = "quilt-" <> version
          , loaderMetadataSource = "quilt"
          , loaderMetadataMinecraftVersion = "1.21.7"
          , loaderMetadataLoaderVersion = version
          , loaderMetadataInstallerVersion = Nothing
          , loaderMetadataStable = stable
          , loaderMetadataDownloadUrl = Nothing
          }
      selected =
        loaderMetadataLoaderVersion
          <$> preferredLoaderMetadata
            [ loader "0.20.0-beta.9" True
            , loader "0.24.0" True
            , loader "0.29.2-beta.5" False
            , loader "0.29.1" True
            ]
      betaOnly =
        loaderMetadataLoaderVersion
          <$> preferredLoaderMetadata
            [ loader "0.20.0-beta.9" False
            , loader "0.29.2-beta.5" False
            ]
  assertEqual "preferred loader ignores response order and beta-stable flags" (Just "0.29.1") selected
  assertEqual "preferred loader falls back to newest beta when no release exists" (Just "0.29.2-beta.5") betaOnly
