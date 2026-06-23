{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.InstallPreflight.Types
  ( LoaderInstallPreflightDiagnostics(..)
  , LoaderInstallPreflightRequest(..)
  , LoaderInstallPreflightResponse(..)
  , preflightFromInstallRequest
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Text (Text)
import Panino.Api.Types (InstallRequest(..))
import Panino.Content.Online.Minecraft (LoaderMetadataSourceResult)
import Panino.Diagnostics.Types (Diagnostic)
import qualified Panino.Install.Plan.Types as Plan
import Panino.Runtime.Java.Types (JavaRuntimeResolveResponse)

data LoaderInstallPreflightRequest = LoaderInstallPreflightRequest
  { preflightMinecraftVersion :: Text
  , preflightLoader :: Maybe Text
  , preflightLoaderVersion :: Maybe Text
  , preflightShaderLoader :: Maybe Text
  , preflightShaderVersion :: Maybe Text
  , preflightGameDir :: Maybe FilePath
  , preflightJavaExecutable :: Maybe FilePath
  , preflightSourceProfile :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON LoaderInstallPreflightRequest where
  parseJSON =
    withObject "LoaderInstallPreflightRequest" $ \obj ->
      LoaderInstallPreflightRequest
        <$> (obj .:? "minecraftVersion" >>= maybe (obj .: "version") pure)
        <*> obj .:? "loader"
        <*> obj .:? "loaderVersion"
        <*> obj .:? "shaderLoader"
        <*> obj .:? "shaderVersion"
        <*> obj .:? "gameDir"
        <*> obj .:? "javaExecutable"
        <*> obj .:? "sourceProfile"

instance ToJSON LoaderInstallPreflightRequest where
  toJSON request =
    object
      [ "minecraftVersion" .= preflightMinecraftVersion request
      , "loader" .= preflightLoader request
      , "loaderVersion" .= preflightLoaderVersion request
      , "shaderLoader" .= preflightShaderLoader request
      , "shaderVersion" .= preflightShaderVersion request
      , "gameDir" .= preflightGameDir request
      , "javaExecutable" .= preflightJavaExecutable request
      , "sourceProfile" .= preflightSourceProfile request
      ]

data LoaderInstallPreflightDiagnostics = LoaderInstallPreflightDiagnostics
  { preflightDiagnosticsLoaderSources :: [LoaderMetadataSourceResult]
  , preflightDiagnosticsLoaderProfileUrl :: Maybe Text
  , preflightDiagnosticsInstallerUrl :: Maybe Text
  , preflightDiagnosticsInstallerProbeStatus :: Maybe Text
  , preflightDiagnosticsShaderProjects :: [Text]
  } deriving (Eq, Show)

instance ToJSON LoaderInstallPreflightDiagnostics where
  toJSON diagnostics =
    object
      [ "loaderSources" .= preflightDiagnosticsLoaderSources diagnostics
      , "loaderProfileUrl" .= preflightDiagnosticsLoaderProfileUrl diagnostics
      , "installerUrl" .= preflightDiagnosticsInstallerUrl diagnostics
      , "installerProbeStatus" .= preflightDiagnosticsInstallerProbeStatus diagnostics
      , "shaderProjects" .= preflightDiagnosticsShaderProjects diagnostics
      ]

data LoaderInstallPreflightResponse = LoaderInstallPreflightResponse
  { preflightStatus :: Text
  , preflightResponseMinecraftVersion :: Text
  , preflightResponseLoader :: Maybe Text
  , preflightResponseLoaderVersion :: Maybe Text
  , preflightResponseLoaderProfileId :: Maybe Text
  , preflightResponseShaderLoader :: Maybe Text
  , preflightResponseShaderVersion :: Maybe Text
  , preflightResponseShaderResolvedLoader :: Maybe Text
  , preflightResponseShaderFallbackFrom :: Maybe Text
  , preflightResponseShaderFallbackTo :: Maybe Text
  , preflightResponseInstallerProbeStatus :: Maybe Text
  , preflightResponseShaderProjects :: [Text]
  , preflightResponseRequiredDependencies :: [Text]
  , preflightResponseJavaRuntime :: Maybe JavaRuntimeResolveResponse
  , preflightResponseWarnings :: [Text]
  , preflightResponseBlockedReasons :: [Text]
  , preflightResponseTypedPlan :: Plan.TypedInstallPlan
  , preflightResponseDiagnostics :: LoaderInstallPreflightDiagnostics
  , preflightResponseDiagnostic :: Maybe Diagnostic
  , preflightResponseStructuredDiagnostics :: [Diagnostic]
  } deriving (Eq, Show)

instance ToJSON LoaderInstallPreflightResponse where
  toJSON response =
    object
      [ "status" .= preflightStatus response
      , "minecraftVersion" .= preflightResponseMinecraftVersion response
      , "loader" .= preflightResponseLoader response
      , "loaderVersion" .= preflightResponseLoaderVersion response
      , "loaderProfileId" .= preflightResponseLoaderProfileId response
      , "shaderLoader" .= preflightResponseShaderLoader response
      , "shaderVersion" .= preflightResponseShaderVersion response
      , "shaderResolvedLoader" .= preflightResponseShaderResolvedLoader response
      , "shaderFallbackFrom" .= preflightResponseShaderFallbackFrom response
      , "shaderFallbackTo" .= preflightResponseShaderFallbackTo response
      , "installerProbeStatus" .= preflightResponseInstallerProbeStatus response
      , "shaderProjects" .= preflightResponseShaderProjects response
      , "requiredDependencies" .= preflightResponseRequiredDependencies response
      , "javaRuntime" .= preflightResponseJavaRuntime response
      , "warnings" .= preflightResponseWarnings response
      , "blockedReasons" .= preflightResponseBlockedReasons response
      , "typedPlan" .= preflightResponseTypedPlan response
      , "diagnostics" .= preflightResponseDiagnostics response
      , "diagnostic" .= preflightResponseDiagnostic response
      , "structuredDiagnostics" .= preflightResponseStructuredDiagnostics response
      ]

preflightFromInstallRequest :: InstallRequest -> Maybe FilePath -> LoaderInstallPreflightRequest
preflightFromInstallRequest request javaExecutable =
  LoaderInstallPreflightRequest
    { preflightMinecraftVersion = installRequestVersion request
    , preflightLoader = installRequestLoader request
    , preflightLoaderVersion = installRequestLoaderVersion request
    , preflightShaderLoader = installRequestShaderLoader request
    , preflightShaderVersion = installRequestShaderVersion request
    , preflightGameDir = installRequestGameDir request
    , preflightJavaExecutable = javaExecutable
    , preflightSourceProfile = Nothing
    }
