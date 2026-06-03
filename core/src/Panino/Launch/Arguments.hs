{-# LANGUAGE OverloadedStrings #-}

module Panino.Launch.Arguments
  ( LaunchProfile(..)
  , buildJavaArguments
  , substituteVariables
  ) where

import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.List (intercalate)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  , clientJarPath
  , nativesDir
  )
import Panino.Minecraft.Types
  ( DownloadInfo(..)
  , VersionArguments(..)
  , VersionJson(..)
  , allowedArgValues
  )
import Panino.Launch.Tuning.Types
  ( ResolvedJvmTuning(..)
  )
import System.FilePath (searchPathSeparator)

data LaunchProfile = LaunchProfile
  { profileVersion :: Text
  , profileMemoryMb :: Int
  , profileJavaPath :: FilePath
  , profileUsername :: Text
  , profileUuid :: Text
  , profileAccessToken :: Text
  , profileJvmArgs :: [Text]
  , profileJvmTuning :: Maybe ResolvedJvmTuning
  , profileWindowWidth :: Maybe Int
  , profileWindowHeight :: Maybe Int
  } deriving (Eq, Show)

buildJavaArguments :: MinecraftLayout -> VersionJson -> [FilePath] -> LaunchProfile -> [String]
buildJavaArguments layout versionJson classpathJars profile =
  memoryArguments profile
    <> map Text.unpack (profileJvmArgs profile)
    <> jvmArguments layout versionJson classpathJars profile
    <> [Text.unpack (versionMainClass versionJson)]
    <> gameArguments layout versionJson classpathJars profile
    <> windowArguments profile

memoryArguments :: LaunchProfile -> [String]
memoryArguments profile =
  case profileJvmTuning profile of
    Just tuning ->
      map Text.unpack (resolvedTuningJvmArgs tuning)
    Nothing ->
      [ "-Xms512M"
      , "-Xmx" <> show (profileMemoryMb profile) <> "M"
      ]

jvmArguments :: MinecraftLayout -> VersionJson -> [FilePath] -> LaunchProfile -> [String]
jvmArguments layout versionJson classpathJars profile =
  case versionArguments versionJson of
    Just args ->
      map Text.unpack
        ( substituteVariables (variableMap layout versionJson classpathJars profile)
            <$> allowedArgValues (versionJvmArguments args)
        )
    Nothing ->
      [ "-Djava.library.path=" <> nativesDir layout (versionId versionJson)
      , "-cp"
      , classpathString classpathJars
      ]

gameArguments :: MinecraftLayout -> VersionJson -> [FilePath] -> LaunchProfile -> [String]
gameArguments layout versionJson classpathJars profile =
  case versionArguments versionJson of
    Just args ->
      map Text.unpack
        ( substituteVariables (variableMap layout versionJson classpathJars profile)
            <$> allowedArgValues (versionGameArguments args)
        )
    Nothing ->
      legacyGameArguments layout versionJson profile

legacyGameArguments :: MinecraftLayout -> VersionJson -> LaunchProfile -> [String]
legacyGameArguments layout versionJson profile =
  map
    (Text.unpack . substituteVariables (variableMap layout versionJson (defaultClasspath layout versionJson) profile) . Text.pack)
    (words (Text.unpack (fromMaybe "" (versionMinecraftArguments versionJson))))

windowArguments :: LaunchProfile -> [String]
windowArguments profile =
  case (profileWindowWidth profile, profileWindowHeight profile) of
    (Just width, Just height) ->
      [ "--width"
      , show width
      , "--height"
      , show height
      ]
    _ -> []

variableMap :: MinecraftLayout -> VersionJson -> [FilePath] -> LaunchProfile -> Map Text Text
variableMap layout versionJson classpathJars profile =
  Map.fromList
    [ ("auth_player_name", profileUsername profile)
    , ("version_name", versionId versionJson)
    , ("game_directory", Text.pack (minecraftRoot layout))
    , ("assets_root", Text.pack (assetsDir layout))
    , ("assets_index_name", assetIndexName versionJson)
    , ("auth_uuid", profileUuid profile)
    , ("auth_access_token", profileAccessToken profile)
    , ("user_type", "msa")
    , ("version_type", fromMaybe "release" (versionType versionJson))
    , ("natives_directory", Text.pack (nativesDir layout (versionId versionJson)))
    , ("library_directory", Text.pack (librariesDir layout))
    , ("launcher_name", "PaninoLauncher")
    , ("launcher_version", "0.1.0.0")
    , ("classpath", Text.pack (classpathString classpathJars))
    , ("classpath_separator", Text.singleton searchPathSeparator)
    , ("clientid", "")
    , ("auth_xuid", "")
    ]

assetIndexName :: VersionJson -> Text
assetIndexName versionJson =
  fromMaybe "legacy" (downloadId (versionAssetIndex versionJson))

classpathString :: [FilePath] -> String
classpathString =
  intercalate [searchPathSeparator]

defaultClasspath :: MinecraftLayout -> VersionJson -> [FilePath]
defaultClasspath layout versionJson =
  [clientJarPath layout (versionId versionJson)]

substituteVariables :: Map Text Text -> Text -> Text
substituteVariables variables raw =
  Map.foldlWithKey' replaceOne raw variables
  where
    replaceOne current key value =
      Text.replace ("${" <> key <> "}") value current
