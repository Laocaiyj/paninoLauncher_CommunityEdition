{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.Manifest
  ( decodeJsonFile
  , findVersion
  , loadVersionJson
  , makeHttpManager
  , versionManifestUrl
  ) where

import Data.Aeson
  ( FromJSON
  , Value(..)
  , eitherDecode'
  , encode
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Download.Manager
  ( DownloadJob(..)
  , downloadSingle
  )
import Panino.Net.Http
  ( fetchJsonUrl
  , makeHttpManager
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout
  , versionJsonPath
  )
import Panino.Minecraft.Types
  ( VersionJson
  , VersionManifest(..)
  , VersionSummary(..)
  )
import System.Directory (createDirectoryIfMissing)
import System.Directory (doesFileExist)
import System.FilePath (takeDirectory)

versionManifestUrl :: String
versionManifestUrl = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"

findVersion :: Manager -> Text -> IO VersionSummary
findVersion manager requestedVersion = do
  manifest <- fetchJson manager versionManifestUrl
  case filter ((== requestedVersion) . versionSummaryId) (manifestVersions manifest) of
    summary:_ -> pure summary
    [] -> fail ("Minecraft version not found in manifest: " <> Text.unpack requestedVersion)

loadVersionJson :: Manager -> MinecraftLayout -> Text -> IO VersionJson
loadVersionJson manager layout requestedVersion = do
  value <- loadVersionValue manager layout requestedVersion
  decodeJsonBytes (Text.unpack requestedVersion) (encode value)

loadVersionValue :: Manager -> MinecraftLayout -> Text -> IO Value
loadVersionValue manager layout requestedVersion = do
  let target = versionJsonPath layout requestedVersion
  exists <- doesFileExist target
  if exists
    then loadLocalVersionValue manager layout requestedVersion target
    else loadRemoteVersionValue manager layout requestedVersion target

loadRemoteVersionValue :: Manager -> MinecraftLayout -> Text -> FilePath -> IO Value
loadRemoteVersionValue manager _ requestedVersion target = do
  summary <- findVersion manager requestedVersion
  createDirectoryIfMissing True (takeDirectory target)
  _ <- downloadSingle manager DownloadJob
    { jobLabel = "version json " <> Text.unpack requestedVersion
    , jobUrl = Text.unpack (versionSummaryUrl summary)
    , jobTargetPath = target
    , jobSha1 = versionSummarySha1 summary
    , jobSize = Nothing
    }
  decodeJsonFile target

loadLocalVersionValue :: Manager -> MinecraftLayout -> Text -> FilePath -> IO Value
loadLocalVersionValue manager layout requestedVersion target = do
  value <- decodeJsonFile target
  case inheritedVersion value of
    Nothing -> pure value
    Just parent
      | parent == requestedVersion -> fail ("version JSON inherits from itself: " <> Text.unpack requestedVersion)
      | otherwise -> do
          parentValue <- loadVersionValue manager layout parent
          pure (mergeInheritedVersion parentValue value)

inheritedVersion :: Value -> Maybe Text
inheritedVersion (Object obj) =
  case KeyMap.lookup (Key.fromString "inheritsFrom") obj of
    Just (String parent) -> Just parent
    _ -> Nothing
inheritedVersion _ = Nothing

mergeInheritedVersion :: Value -> Value -> Value
mergeInheritedVersion (Object parent) (Object child) =
  Object $
    KeyMap.delete (Key.fromString "inheritsFrom") $
      KeyMap.union
        (mergeKnownFields parent child)
        (KeyMap.union child parent)
  where
    mergeKnownFields base overlay =
      KeyMap.fromList
        [ (Key.fromString "libraries", mergedArray "libraries" base overlay)
        , (Key.fromString "arguments", mergedArguments base overlay)
        ]
mergeInheritedVersion _ child = child

mergedArray :: String -> KeyMap.KeyMap Value -> KeyMap.KeyMap Value -> Value
mergedArray key parent child =
  case (KeyMap.lookup keyName parent, KeyMap.lookup keyName child) of
    (Just (Array parentItems), Just (Array childItems)) -> Array (parentItems <> childItems)
    (Nothing, Just childValue) -> childValue
    (Just parentValue, Nothing) -> parentValue
    _ -> Array mempty
  where
    keyName = Key.fromString key

mergedArguments :: KeyMap.KeyMap Value -> KeyMap.KeyMap Value -> Value
mergedArguments parent child =
  case (KeyMap.lookup keyName parent, KeyMap.lookup keyName child) of
    (Just (Object parentArgs), Just (Object childArgs)) ->
      Object
        ( KeyMap.union
            ( KeyMap.fromList
                [ (Key.fromString "game", mergedArray "game" parentArgs childArgs)
                , (Key.fromString "jvm", mergedArray "jvm" parentArgs childArgs)
                ]
            )
            childArgs
        )
    (Nothing, Just childValue) -> childValue
    (Just parentValue, Nothing) -> parentValue
    _ -> Object mempty
  where
    keyName = Key.fromString "arguments"

fetchJson :: FromJSON a => Manager -> String -> IO a
fetchJson = fetchJsonUrl

decodeJsonFile :: FromJSON a => FilePath -> IO a
decodeJsonFile path = do
  bytes <- BL.readFile path
  decodeJsonBytes path bytes

decodeJsonBytes :: FromJSON a => String -> BL.ByteString -> IO a
decodeJsonBytes label bytes =
  case eitherDecode' bytes of
    Right value -> pure value
    Left err -> fail ("failed to decode JSON from " <> label <> ": " <> err)
