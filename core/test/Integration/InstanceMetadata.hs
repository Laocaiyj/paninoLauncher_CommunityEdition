{-# LANGUAGE OverloadedStrings #-}

module Integration.InstanceMetadata
  ( assertInstanceMetadataFallbackRepairsLoaderProfile
  ) where

import Control.Monad (when)
import Data.Aeson
  ( encode
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Minecraft.InstanceMetadata
  ( InstanceMetadata(..)
  , readInstanceMetadata
  , writeInstanceMetadata
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , removeDirectoryRecursive
  )
import System.FilePath
  ( (</>)
  , (<.>)
  , takeDirectory
  )
import TestSupport (assertEqual)

assertInstanceMetadataFallbackRepairsLoaderProfile :: FilePath -> IO ()
assertInstanceMetadataFallbackRepairsLoaderProfile tempDir = do
  let root = tempDir </> "panino-instance-metadata-fallback"
      quiltProfile :: Text
      quiltProfile = "quilt-loader-0.29.2-26.1.1"
      quiltProfilePath = root </> "versions" </> Text.unpack quiltProfile </> Text.unpack quiltProfile <.> "json"
  exists <- doesDirectoryExist root
  when exists (removeDirectoryRecursive root)
  createDirectoryIfMissing True (takeDirectory quiltProfilePath)
  BL.writeFile
    quiltProfilePath
    ( encode
        ( object
            [ "id" .= quiltProfile
            , "inheritsFrom" .= ("26.1.1" :: Text)
            , "mainClass" .= ("org.quiltmc.loader.impl.launch.knot.KnotClient" :: Text)
            , "libraries" .=
                [ object
                    [ "name" .= ("org.quiltmc:quilt-loader:0.29.2" :: Text)
                    ]
                ]
            ]
        )
    )
  quiltMetadata <- readInstanceMetadata root quiltProfile
  assertEqual "fallback metadata keeps loader profile as launch version" quiltProfile (metadataLaunchVersion quiltMetadata)
  assertEqual "fallback metadata reads inherited Minecraft version" "26.1.1" (metadataMinecraftVersion quiltMetadata)
  assertEqual "fallback metadata infers Quilt loader" (Just "quilt") (metadataLoader quiltMetadata)
  assertEqual "fallback metadata infers Quilt loader version" (Just "0.29.2") (metadataLoaderVersion quiltMetadata)
  writeInstanceMetadata
    root
    InstanceMetadata
      { metadataName = Just "Preserve Name"
      , metadataMinecraftVersion = quiltProfile
      , metadataLaunchVersion = quiltProfile
      , metadataLoader = Nothing
      , metadataLoaderVersion = Nothing
      , metadataShaderLoader = Just "iris"
      }
  staleQuiltMetadata <- readInstanceMetadata root quiltProfile
  assertEqual "stale metadata repair keeps user name" (Just "Preserve Name") (metadataName staleQuiltMetadata)
  assertEqual "stale metadata repair keeps shader selection" (Just "iris") (metadataShaderLoader staleQuiltMetadata)
  assertEqual "stale metadata repair replaces loader profile Minecraft version" "26.1.1" (metadataMinecraftVersion staleQuiltMetadata)
  assertEqual "stale metadata repair fills missing Quilt loader" (Just "quilt") (metadataLoader staleQuiltMetadata)
  assertEqual "stale metadata repair fills missing Quilt loader version" (Just "0.29.2") (metadataLoaderVersion staleQuiltMetadata)

  let fabricRoot = root </> "fabric-id-only"
      fabricProfile :: Text
      fabricProfile = "fabric-loader-0.16.0-1.21.7"
  fabricMetadata <- readInstanceMetadata fabricRoot fabricProfile
  assertEqual "fallback metadata parses Fabric Minecraft suffix" "1.21.7" (metadataMinecraftVersion fabricMetadata)
  assertEqual "fallback metadata parses Fabric loader version" (Just "0.16.0") (metadataLoaderVersion fabricMetadata)

  let betaQuiltRoot = root </> "quilt-beta-id-only"
      betaQuiltProfile :: Text
      betaQuiltProfile = "quilt-loader-0.20.0-beta.9-1.21.7"
  betaQuiltMetadata <- readInstanceMetadata betaQuiltRoot betaQuiltProfile
  assertEqual "fallback metadata parses beta Quilt Minecraft suffix" "1.21.7" (metadataMinecraftVersion betaQuiltMetadata)
  assertEqual "fallback metadata preserves beta Quilt loader version" (Just "0.20.0-beta.9") (metadataLoaderVersion betaQuiltMetadata)

  let neoForgeRoot = root </> "neoforge-json"
      neoForgeProfile :: Text
      neoForgeProfile = "neoforge-21.1.179"
      neoForgeProfilePath = neoForgeRoot </> "versions" </> Text.unpack neoForgeProfile </> Text.unpack neoForgeProfile <.> "json"
  createDirectoryIfMissing True (takeDirectory neoForgeProfilePath)
  BL.writeFile
    neoForgeProfilePath
    ( encode
        ( object
            [ "id" .= neoForgeProfile
            , "inheritsFrom" .= ("1.21.1" :: Text)
            , "mainClass" .= ("cpw.mods.bootstrap.BootstrapLauncher" :: Text)
            , "libraries" .=
                [ object
                    [ "name" .= ("net.neoforged:neoforge:21.1.179" :: Text)
                    ]
                ]
            ]
        )
    )
  neoForgeMetadata <- readInstanceMetadata neoForgeRoot neoForgeProfile
  assertEqual "fallback metadata reads NeoForge inherited Minecraft version" "1.21.1" (metadataMinecraftVersion neoForgeMetadata)
  assertEqual "fallback metadata infers NeoForge loader from library" (Just "neoForge") (metadataLoader neoForgeMetadata)
  assertEqual "fallback metadata infers NeoForge loader version" (Just "21.1.179") (metadataLoaderVersion neoForgeMetadata)
