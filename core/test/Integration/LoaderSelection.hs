{-# LANGUAGE OverloadedStrings #-}

module Integration.LoaderSelection
  ( assertModrinthPreferredVersionSelection
  , assertPreferredLoaderMetadataSelection
  ) where

import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Panino.Content.Online.Minecraft
  ( preferredLoaderMetadata
  )
import Panino.Content.Online.Types
  ( LoaderMetadata(..)
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
    (modrinthVersionId <$> selected)

testModrinthVersion :: Text -> Text -> Text -> Text -> Text -> ModrinthVersion
testModrinthVersion modrinthId displayName versionNumber publishedAt jarName =
  ModrinthVersion
    { modrinthVersionId = modrinthId
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
            , modrinthFileUrl = "https://cdn.modrinth.test/" <> jarName
            , modrinthFilePrimary = True
            , modrinthFileHashes = Map.empty
            , modrinthFileSize = Just 1
            }
        ]
    , modrinthVersionDependencies = []
    }

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
