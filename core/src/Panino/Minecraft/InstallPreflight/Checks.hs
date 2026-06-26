{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.InstallPreflight.Checks
  ( LoaderPreflightCheck(..)
  , ShaderPreflightCheck(..)
  , emptyLoaderCheck
  , emptyShaderCheck
  , normalizedOptionalLoader
  , normalizedOptionalShader
  ) where

import Data.Text (Text)
import Panino.Minecraft.LoaderInstall (normalizeLoaderName)

data LoaderPreflightCheck = LoaderPreflightCheck
  { loaderSelectedVersion :: Maybe Text
  , loaderProfileId :: Maybe Text
  , loaderProfileUrlText :: Maybe Text
  , loaderInstallerUrlText :: Maybe Text
  , loaderInstallerProbeStatus :: Maybe Text
  , loaderWarnings :: [Text]
  , loaderBlockedReasons :: [Text]
  } deriving (Eq, Show)

data ShaderPreflightCheck = ShaderPreflightCheck
  { shaderProjects :: [Text]
  , shaderSelectedVersion :: Maybe Text
  , shaderResolvedLoader :: Maybe Text
  , shaderFallbackFrom :: Maybe Text
  , shaderFallbackTo :: Maybe Text
  , shaderRequiredDependencies :: [Text]
  , shaderWarnings :: [Text]
  , shaderBlockedReasons :: [Text]
  } deriving (Eq, Show)

emptyLoaderCheck :: LoaderPreflightCheck
emptyLoaderCheck =
  LoaderPreflightCheck
    { loaderSelectedVersion = Nothing
    , loaderProfileId = Nothing
    , loaderProfileUrlText = Nothing
    , loaderInstallerUrlText = Nothing
    , loaderInstallerProbeStatus = Nothing
    , loaderWarnings = []
    , loaderBlockedReasons = []
    }

emptyShaderCheck :: ShaderPreflightCheck
emptyShaderCheck =
  ShaderPreflightCheck
    { shaderProjects = []
    , shaderSelectedVersion = Nothing
    , shaderResolvedLoader = Nothing
    , shaderFallbackFrom = Nothing
    , shaderFallbackTo = Nothing
    , shaderRequiredDependencies = []
    , shaderWarnings = []
    , shaderBlockedReasons = []
    }

normalizedOptionalLoader :: Maybe Text -> Maybe Text
normalizedOptionalLoader value =
  case normalizeLoaderName <$> value of
    Just "" -> Nothing
    Just "vanilla" -> Nothing
    normalized -> normalized

normalizedOptionalShader :: Maybe Text -> Maybe Text
normalizedOptionalShader value =
  case normalizeLoaderName <$> value of
    Just "" -> Nothing
    Just "none" -> Nothing
    normalized -> normalized
