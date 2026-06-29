{-# LANGUAGE OverloadedStrings #-}

module Panino.Runtime.Java.Requirements
  ( javaRequirementForVersionJson
  , fallbackJavaMajorVersion
  ) where

import Data.Char (isDigit)
import Data.List (stripPrefix)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Core.Types
  ( VersionId
  , versionIdText
  )
import Panino.Minecraft.Types
  ( JavaVersion(..)
  , VersionJson(..)
  )
import Panino.Runtime.Java.Types (JavaRuntimeRequirement(..))

javaRequirementForVersionJson :: VersionId -> VersionJson -> JavaRuntimeRequirement
javaRequirementForVersionJson requestedVersion versionJson =
  case versionJavaVersion versionJson >>= javaVersionMajorVersion of
    Just major ->
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = versionId versionJson
        , javaRequirementMajorVersion = major
        , javaRequirementComponent = versionJavaVersion versionJson >>= javaVersionComponent
        , javaRequirementSource = "manifest"
        }
    Nothing ->
      JavaRuntimeRequirement
        { javaRequirementMinecraftVersion = versionId versionJson
        , javaRequirementMajorVersion = fallbackJavaMajorVersion (versionIdText requestedVersion)
        , javaRequirementComponent = Nothing
        , javaRequirementSource = "fallback"
        }

fallbackJavaMajorVersion :: Text -> Int
fallbackJavaMajorVersion rawVersion
  | major > 1 = 21
  | major == 1 && minor > 20 = 21
  | major == 1 && minor == 20 && patch >= 5 = 21
  | major == 1 && minor >= 18 = 17
  | major == 1 && minor == 17 = 16
  | otherwise = 8
  where
    (major, minor, patch) = parseMinecraftVersion rawVersion

parseMinecraftVersion :: Text -> (Int, Int, Int)
parseMinecraftVersion value =
  case map readIntSafe (take 3 (Text.splitOn "." normalized)) of
    major:minor:patch:_ -> (major, minor, patch)
    major:minor:_ -> (major, minor, 0)
    major:_ -> (major, 0, 0)
    [] -> (1, 0, 0)
  where
    normalized =
      Text.takeWhile (\char -> isDigit char || char == '.') $
        fromMaybe value $
          Text.pack <$> stripPrefix "minecraft-" (Text.unpack value)

readIntSafe :: Text -> Int
readIntSafe text =
  case reads (Text.unpack (Text.takeWhile isDigit text)) of
    (parsed, _):_ -> parsed
    [] -> 0
