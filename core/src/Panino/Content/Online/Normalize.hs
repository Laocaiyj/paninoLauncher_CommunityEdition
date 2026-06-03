{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Online.Normalize
  ( jsonText
  , loaderFamilies
  , normalizedCategories
  , onlineProjectType
  , queryString
  , relationText
  , releaseTypeText
  , sideSupport
  ) where

import Data.Aeson
  ( ToJSON
  , encode
  )
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import Data.List (nub)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Network.HTTP.Types (renderQuery)

queryString :: [(Text, Maybe Text)] -> String
queryString =
  BS8.unpack
    . renderQuery True
    . map (\(key, value) -> (Text.encodeUtf8 key, Text.encodeUtf8 <$> value))

jsonText :: ToJSON value => value -> Text
jsonText =
  Text.decodeUtf8 . BL.toStrict . encode

onlineProjectType :: Text -> Text
onlineProjectType "resourcepack" = "resourcePack"
onlineProjectType "shader" = "shaderPack"
onlineProjectType "modpack" = "modpack"
onlineProjectType _ = "mod"

loaderFamilies :: [Text] -> [Text]
loaderFamilies values =
  nub (mapMaybe loaderFamily values)

loaderFamily :: Text -> Maybe Text
loaderFamily raw
  | "neoforge" `Text.isInfixOf` value = Just "neoForge"
  | "forge" `Text.isInfixOf` value = Just "forge"
  | "fabric" `Text.isInfixOf` value = Just "fabric"
  | "quilt" `Text.isInfixOf` value = Just "quilt"
  | otherwise = Nothing
  where
    value = Text.toLower raw

normalizedCategories :: Text -> [Text] -> [Text]
normalizedCategories projectType rawValues =
  nub (fallback <> matched)
  where
    sourceText = Text.toLower (Text.unwords rawValues)
    fallback =
      if null matched
        then ["Recommended"]
        else []
    matched =
      case projectType of
        "resourcePack" -> resourcePackCategories sourceText
        "shaderPack" -> shaderPackCategories sourceText
        "modpack" -> modpackCategories sourceText
        _ -> modCategories sourceText

modCategories :: Text -> [Text]
modCategories value =
  concat
    [ ["Recommended" | hasAny ["popular", "featured", "recommend", "essentials"]]
    , ["Performance" | hasAny ["performance", "optimization", "optimisation", "fps", "sodium", "lithium", "memory"]]
    , ["API / Library" | hasAny ["api", "library", "lib", "dependency", "core"]]
    , ["Utility" | hasAny ["utility", "qol", "quality of life", "tweak", "tools", "helper"]]
    , ["World / Map" | hasAny ["world", "worldgen", "biome", "structure", "map", "terrain"]]
    , ["Tech / Magic / Adventure" | hasAny ["technology", "tech", "magic", "adventure", "rpg", "quest", "exploration"]]
    , ["UI / HUD" | hasAny ["ui", "gui", "hud", "menu", "tooltip", "inventory"]]
    , ["Storage / Logistics" | hasAny ["storage", "logistics", "transport", "pipe", "chest", "backpack"]]
    ]
  where
    hasAny = any (`Text.isInfixOf` value)

resourcePackCategories :: Text -> [Text]
resourcePackCategories value =
  concat
    [ ["Recommended" | hasAny ["popular", "featured", "recommend", "vanilla"]]
    , ["Vanilla+" | hasAny ["vanilla", "faithful", "default", "classic"]]
    , ["Realistic" | hasAny ["realistic", "photorealistic", "realism"]]
    , ["UI / Font" | hasAny ["ui", "gui", "font", "menu", "language"]]
    , ["16x" | hasAny ["16x", "16 x"]]
    , ["32x" | hasAny ["32x", "32 x"]]
    , ["64x+" | hasAny ["64x", "128x", "256x", "512x", "1024x"]]
    , ["PBR / Normal Map" | hasAny ["pbr", "normal", "specular", "labpbr"]]
    ]
  where
    hasAny = any (`Text.isInfixOf` value)

shaderPackCategories :: Text -> [Text]
shaderPackCategories value =
  concat
    [ ["Recommended" | hasAny ["popular", "featured", "recommend"]]
    , ["Lightweight" | hasAny ["lightweight", "low", "performance", "potato", "fps"]]
    , ["Balanced" | hasAny ["balanced", "medium", "complementary", "enhanced"]]
    , ["High Quality" | hasAny ["high", "ultra", "cinematic", "realistic", "ray"]]
    , ["Iris Compatible" | hasAny ["iris", "fabric", "quilt"]]
    , ["OptiFine Compatible" | hasAny ["optifine", "optifabric"]]
    ]
  where
    hasAny = any (`Text.isInfixOf` value)

modpackCategories :: Text -> [Text]
modpackCategories value =
  concat
    [ ["Recommended" | hasAny ["popular", "featured", "recommend"]]
    , ["Lightweight Optimization" | hasAny ["lightweight", "optimization", "performance", "fps", "vanilla+"]]
    , ["Tech" | hasAny ["technology", "tech", "factory", "industrial"]]
    , ["Magic" | hasAny ["magic", "spell", "mana"]]
    , ["Adventure / RPG" | hasAny ["adventure", "rpg", "quest", "exploration", "dungeon"]]
    , ["Skyblock / Expert" | hasAny ["skyblock", "expert", "hardcore", "challenge"]]
    ]
  where
    hasAny = any (`Text.isInfixOf` value)

sideSupport :: Maybe Text -> Text
sideSupport (Just "required") = "required"
sideSupport (Just "optional") = "optional"
sideSupport (Just "unsupported") = "unsupported"
sideSupport _ = "unknown"

releaseTypeText :: Text -> Text
releaseTypeText "release" = "release"
releaseTypeText "beta" = "beta"
releaseTypeText "alpha" = "alpha"
releaseTypeText "snapshot" = "snapshot"
releaseTypeText _ = "unknown"

relationText :: Text -> Text
relationText "required" = "required"
relationText "optional" = "optional"
relationText "incompatible" = "incompatible"
relationText "embedded" = "embedded"
relationText _ = "unknown"
