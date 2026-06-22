{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.LauncherProfiles
  ( ensureLauncherProfilesJson
  , launcherProfilesJson
  , launcherProfilesPath
  , normalizeLauncherProfilesJson
  ) where

import Data.Aeson
  ( Value(..)
  , decode
  , encode
  , object
  , (.=)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Minecraft.Layout (MinecraftLayout(..))
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  )
import System.FilePath
  ( takeDirectory
  , (</>)
  )

launcherProfilesPath :: MinecraftLayout -> FilePath
launcherProfilesPath layout =
  minecraftRoot layout </> "launcher_profiles.json"

ensureLauncherProfilesJson :: MinecraftLayout -> Text -> IO ()
ensureLauncherProfilesJson layout minecraftVersion = do
  let target = launcherProfilesPath layout
  exists <- doesFileExist target
  if exists
    then ensureLauncherProfilesJsonIsUsable target minecraftVersion
    else do
      createDirectoryIfMissing True (takeDirectory target)
      BL.writeFile target (encode (launcherProfilesJson minecraftVersion))

ensureLauncherProfilesJsonIsUsable :: FilePath -> Text -> IO ()
ensureLauncherProfilesJsonIsUsable target minecraftVersion = do
  raw <- BL.readFile target
  case decode raw :: Maybe Value of
    Just value ->
      case normalizeLauncherProfilesJson minecraftVersion value of
        Just normalized -> BL.writeFile target (encode normalized)
        Nothing -> fail ("loader_launcher_profiles_invalid: launcher_profiles.json must be an object at " <> target)
    Nothing ->
      fail ("loader_launcher_profiles_invalid: failed to decode existing launcher_profiles.json at " <> target)

launcherProfilesJson :: Text -> Value
launcherProfilesJson minecraftVersion =
  case normalizeLauncherProfilesJson minecraftVersion (Object KeyMap.empty) of
    Just value -> value
    Nothing -> Object KeyMap.empty

normalizeLauncherProfilesJson :: Text -> Value -> Maybe Value
normalizeLauncherProfilesJson minecraftVersion (Object obj) =
  Just $
    Object $
      KeyMap.insert (Key.fromString "profiles") (Object profiles) $
        KeyMap.insert (Key.fromString "selectedProfile") (String selectedProfile) $
          KeyMap.insert (Key.fromString "clientToken") (String "panino") $
            KeyMap.insert (Key.fromString "authenticationDatabase") (Object KeyMap.empty) $
              KeyMap.insert (Key.fromString "launcherVersion") launcherVersionValue obj
  where
    existingProfiles =
      case KeyMap.lookup (Key.fromString "profiles") obj of
        Just (Object values) -> values
        _ -> KeyMap.empty
    profiles =
      KeyMap.insert paninoProfileKey (paninoLauncherProfile minecraftVersion) existingProfiles
    selectedProfile =
      case KeyMap.lookup (Key.fromString "selectedProfile") obj of
        Just (String value) | not (Text.null value) -> value
        _ -> paninoProfileId
normalizeLauncherProfilesJson _ _ =
  Nothing

paninoProfileId :: Text
paninoProfileId = "Panino"

paninoProfileKey :: Key.Key
paninoProfileKey =
  Key.fromText paninoProfileId

paninoLauncherProfile :: Text -> Value
paninoLauncherProfile minecraftVersion =
  object
    [ "name" .= paninoProfileId
    , "type" .= ("custom" :: Text)
    , "created" .= ("1970-01-01T00:00:00.000Z" :: Text)
    , "lastUsed" .= ("1970-01-01T00:00:00.000Z" :: Text)
    , "lastVersionId" .= minecraftVersion
    ]

launcherVersionValue :: Value
launcherVersionValue =
  object
    [ "name" .= ("Panino Launcher" :: Text)
    , "format" .= (21 :: Int)
    ]
