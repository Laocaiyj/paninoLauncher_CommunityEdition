{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.LoaderInstall.Names
  ( normalizeLoaderName
  , normalizedLoaderTitle
  , normalizedShaderLoader
  , normalizedShaderTitle
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

normalizeLoaderName :: Text -> Text
normalizeLoaderName =
  Text.toLower . Text.replace "-" "" . Text.replace "_" ""

normalizedLoaderTitle :: Text -> Text
normalizedLoaderTitle value =
  case normalizeLoaderName value of
    "neoforge" -> "neoForge"
    other -> other

normalizedShaderTitle :: Text -> Text
normalizedShaderTitle value =
  case normalizeLoaderName value of
    "iris" -> "iris"
    "oculus" -> "oculus"
    "optifine" -> "optifine"
    other -> other

normalizedShaderLoader :: Maybe Text -> Maybe Text
normalizedShaderLoader Nothing = Nothing
normalizedShaderLoader (Just value)
  | normalizeLoaderName value == "none" = Nothing
  | otherwise = Just (normalizedShaderTitle value)
