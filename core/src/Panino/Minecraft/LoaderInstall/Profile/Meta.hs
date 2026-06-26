{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.LoaderInstall.Profile.Meta
  ( installMetaProfile
  ) where

import Data.Aeson
  ( Value(..)
  , encode
  , object
  , toJSON
  , (.=)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as BL
import Data.Foldable (toList)
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Http
  ( coreRequest
  , fetchJson
  )
import Panino.Content.Online.Types (LoaderMetadata(..))
import Panino.Download.Manager
  ( DownloadOptions
  , DownloadProgress
  )
import Panino.Download.Transfer (throwIfCancelled)
import Panino.Minecraft.Install
  ( InstallResult(..)
  , installMinecraftInheritedProfileWithOptionsAndProgressAndCancel
  , installMinecraftVersionWithOptionsAndProgressAndCancel
  )
import Panino.Minecraft.InstallPlanGraph (combineInstallPlanGraphs)
import Panino.Minecraft.Layout
  ( MinecraftLayout
  , versionJsonPath
  )
import Panino.Minecraft.LoaderInstall.Names (normalizeLoaderName)
import Panino.Minecraft.LoaderInstall.Profile.Common
  ( mergeDownloadSummaries
  , selectLoaderMetadata
  )
import Panino.Minecraft.LoaderInstall.Types (InstalledLoaderProfile(..))
import System.Directory (createDirectoryIfMissing)
import System.FilePath (takeDirectory)

installMetaProfile :: Manager -> MinecraftLayout -> Text -> DownloadOptions -> IO Bool -> (DownloadProgress -> IO ()) -> Text -> Maybe Text -> IO InstalledLoaderProfile
installMetaProfile manager layout minecraftVersion downloadOptions isCancelled onProgress loader maybeLoaderVersion = do
  throwIfCancelled isCancelled
  metadata <- selectLoaderMetadata manager minecraftVersion loader maybeLoaderVersion
  let loaderVersion = loaderMetadataLoaderVersion metadata
  baseResult <- installMinecraftVersionWithOptionsAndProgressAndCancel manager layout minecraftVersion downloadOptions isCancelled onProgress
  throwIfCancelled isCancelled
  loaderProfileUrl <- requireProfileUrl loader minecraftVersion loaderVersion
  rawProfile <- fetchJson manager =<< coreRequest loaderProfileUrl []
  let profile = normalizeLoaderProfile loader minecraftVersion rawProfile
  throwIfCancelled isCancelled
  profileId <- requireProfileId profile
  let target = versionJsonPath layout profileId
  createDirectoryIfMissing True (takeDirectory target)
  BL.writeFile target (encode profile)
  throwIfCancelled isCancelled
  profileResult <-
    installMinecraftInheritedProfileWithOptionsAndProgressAndCancel
      manager
      layout
      minecraftVersion
      profileId
      downloadOptions
      isCancelled
      onProgress
  let result =
        profileResult
          { installDownloadSummary =
              mergeDownloadSummaries
                (installDownloadSummary baseResult)
                (installDownloadSummary profileResult)
          , installPlanGraph =
              combineInstallPlanGraphs
                "minecraft-profile"
                profileId
                [installPlanGraph baseResult, installPlanGraph profileResult]
          }
  pure (InstalledLoaderProfile profileId (Just loaderVersion) result)

requireProfileUrl :: Text -> Text -> Text -> IO String
requireProfileUrl "fabric" minecraftVersion loaderVersion =
  pure $
    "https://meta.fabricmc.net/v2/versions/loader/"
      <> Text.unpack minecraftVersion
      <> "/"
      <> Text.unpack loaderVersion
      <> "/profile/json"
requireProfileUrl "quilt" minecraftVersion loaderVersion =
  pure $
    "https://meta.quiltmc.org/v3/versions/loader/"
      <> Text.unpack minecraftVersion
      <> "/"
      <> Text.unpack loaderVersion
      <> "/profile/json"
requireProfileUrl loader _ _ =
  fail ("loader_profile_fetch_failed: profile JSON is not available for " <> Text.unpack loader)

normalizeLoaderProfile :: Text -> Text -> Value -> Value
normalizeLoaderProfile loader minecraftVersion profile
  | normalizeLoaderName loader `elem` ["fabric", "quilt"] =
      ensureIntermediaryLibrary minecraftVersion profile
  | otherwise = profile

ensureIntermediaryLibrary :: Text -> Value -> Value
ensureIntermediaryLibrary minecraftVersion (Object obj) =
  Object (KeyMap.insert (Key.fromString "libraries") nextLibraries obj)
  where
    libraries =
      case KeyMap.lookup (Key.fromString "libraries") obj of
        Just (Array values) -> toList values
        _ -> mempty
    hasIntermediary =
      any isIntermediaryLibrary libraries
    nextLibraries =
      toJSON $
        if hasIntermediary
          then libraries
          else libraries <> [intermediaryLibrary minecraftVersion]
ensureIntermediaryLibrary _ value = value

intermediaryLibrary :: Text -> Value
intermediaryLibrary minecraftVersion =
  object
    [ "name" .= ("net.fabricmc:intermediary:" <> minecraftVersion)
    , "url" .= ("https://maven.fabricmc.net/" :: Text)
    ]

isIntermediaryLibrary :: Value -> Bool
isIntermediaryLibrary (Object obj) =
  case KeyMap.lookup (Key.fromString "name") obj of
    Just (String name) -> "net.fabricmc:intermediary:" `Text.isPrefixOf` name
    _ -> False
isIntermediaryLibrary _ = False

requireProfileId :: Value -> IO Text
requireProfileId (Object obj) =
  case KeyMap.lookup (Key.fromString "id") obj of
    Just (String value) -> pure value
    _ -> fail "loader profile JSON is missing id"
requireProfileId _ =
  fail "loader profile JSON must be an object"
