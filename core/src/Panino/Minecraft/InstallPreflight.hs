{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.InstallPreflight
  ( LoaderInstallPreflightDiagnostics(..)
  , LoaderInstallPreflightRequest(..)
  , LoaderInstallPreflightResponse(..)
  , blockedLoaderInstallPreflightResponse
  , loaderInstallPreflight
  , preflightFromInstallRequest
  , writeInstallPreflightDiagnostics
  ) where

import Data.Aeson (encode)
import qualified Data.ByteString.Lazy as BL
import Data.Maybe (listToMaybe)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Minecraft
  ( LoaderMetadataSourceResult(..)
  , contentLoaderMetadataSources
  )
import Panino.Content.Online.Types (ContentLoaderRequest(..))
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Diagnostics.Types (Diagnostic(..))
import qualified Panino.Install.Plan.Types as Plan
import Panino.Minecraft.InstallPreflight.Checks
  ( LoaderPreflightCheck(..)
  , ShaderPreflightCheck(..)
  , emptyLoaderCheck
  , emptyShaderCheck
  , normalizedOptionalLoader
  , normalizedOptionalShader
  )
import Panino.Minecraft.InstallPreflight.Plan (preflightTypedPlan)
import Panino.Minecraft.InstallPreflight.Resolve
  ( resolveLoaderPreflight
  , resolveShaderPreflight
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  )
import Panino.Minecraft.InstallPreflight.Types
  ( LoaderInstallPreflightDiagnostics(..)
  , LoaderInstallPreflightRequest(..)
  , LoaderInstallPreflightResponse(..)
  , preflightFromInstallRequest
  )
import System.Directory (createDirectoryIfMissing)
import System.FilePath ((</>))

loaderInstallPreflight :: Manager -> LoaderInstallPreflightRequest -> IO LoaderInstallPreflightResponse
loaderInstallPreflight manager request = do
  loaderSources <- contentLoaderMetadataSources manager (ContentLoaderRequest (preflightMinecraftVersion request))
  loaderCheck <- resolveLoaderPreflight manager request loaderSources
  shaderCheck <- resolveShaderPreflight manager request
  let warnings = loaderWarnings loaderCheck <> shaderWarnings shaderCheck
      blockedReasons = loaderBlockedReasons loaderCheck <> shaderBlockedReasons shaderCheck
      diagnostics =
        LoaderInstallPreflightDiagnostics
          { preflightDiagnosticsLoaderSources = loaderSources
          , preflightDiagnosticsLoaderProfileUrl = loaderProfileUrlText loaderCheck
          , preflightDiagnosticsInstallerUrl = loaderInstallerUrlText loaderCheck
          , preflightDiagnosticsInstallerProbeStatus = loaderInstallerProbeStatus loaderCheck
          , preflightDiagnosticsShaderProjects = shaderProjects shaderCheck
          }
      structuredDiagnostics =
        map (diagnosticFromBlockedReason "preflight" "minecraft install preflight") blockedReasons
      typedPlan = preflightTypedPlan request loaderCheck shaderCheck warnings blockedReasons structuredDiagnostics
      status
        | not (null (Plan.typedPlanBlockedReasons typedPlan)) = "blocked"
        | not (null (Plan.typedPlanWarnings typedPlan)) = "warning"
        | otherwise = "ok"
  pure
    LoaderInstallPreflightResponse
      { preflightStatus = status
      , preflightResponseMinecraftVersion = preflightMinecraftVersion request
      , preflightResponseLoader = normalizedOptionalLoader (preflightLoader request)
      , preflightResponseLoaderVersion = loaderSelectedVersion loaderCheck
      , preflightResponseLoaderProfileId = loaderProfileId loaderCheck
      , preflightResponseShaderLoader = normalizedOptionalShader (preflightShaderLoader request)
      , preflightResponseShaderVersion = shaderSelectedVersion shaderCheck
      , preflightResponseShaderResolvedLoader = shaderResolvedLoader shaderCheck
      , preflightResponseShaderFallbackFrom = shaderFallbackFrom shaderCheck
      , preflightResponseShaderFallbackTo = shaderFallbackTo shaderCheck
      , preflightResponseInstallerProbeStatus = loaderInstallerProbeStatus loaderCheck
      , preflightResponseShaderProjects = shaderProjects shaderCheck
      , preflightResponseRequiredDependencies = shaderRequiredDependencies shaderCheck
      , preflightResponseJavaRuntime = Nothing
      , preflightResponseWarnings = Plan.typedPlanWarnings typedPlan
      , preflightResponseBlockedReasons = Plan.typedPlanBlockedReasons typedPlan
      , preflightResponseTypedPlan = typedPlan
      , preflightResponseDiagnostics = diagnostics
      , preflightResponseDiagnostic = listToMaybe structuredDiagnostics
      , preflightResponseStructuredDiagnostics = structuredDiagnostics
      }

blockedLoaderInstallPreflightResponse :: LoaderInstallPreflightRequest -> Diagnostic -> LoaderInstallPreflightResponse
blockedLoaderInstallPreflightResponse request diagnostic =
  LoaderInstallPreflightResponse
    { preflightStatus = "blocked"
    , preflightResponseMinecraftVersion = preflightMinecraftVersion request
    , preflightResponseLoader = normalizedOptionalLoader (preflightLoader request)
    , preflightResponseLoaderVersion = Nothing
    , preflightResponseLoaderProfileId = Nothing
    , preflightResponseShaderLoader = normalizedOptionalShader (preflightShaderLoader request)
    , preflightResponseShaderVersion = Nothing
    , preflightResponseShaderResolvedLoader = Nothing
    , preflightResponseShaderFallbackFrom = Nothing
    , preflightResponseShaderFallbackTo = Nothing
    , preflightResponseInstallerProbeStatus = Nothing
    , preflightResponseShaderProjects = []
    , preflightResponseRequiredDependencies = []
    , preflightResponseJavaRuntime = Nothing
    , preflightResponseWarnings = []
    , preflightResponseBlockedReasons = [blockedReason]
    , preflightResponseTypedPlan = typedPlan
    , preflightResponseDiagnostics =
        LoaderInstallPreflightDiagnostics
          { preflightDiagnosticsLoaderSources = []
          , preflightDiagnosticsLoaderProfileUrl = Nothing
          , preflightDiagnosticsInstallerUrl = Nothing
          , preflightDiagnosticsInstallerProbeStatus = Nothing
          , preflightDiagnosticsShaderProjects = []
          }
    , preflightResponseDiagnostic = Just diagnostic
    , preflightResponseStructuredDiagnostics = [diagnostic]
    }
  where
    blockedReason = diagnosticCode diagnostic <> ":" <> diagnosticMessage diagnostic
    typedPlan =
      preflightTypedPlan
        request
        emptyLoaderCheck
        emptyShaderCheck
        []
        [blockedReason]
        [diagnostic]

writeInstallPreflightDiagnostics :: MinecraftLayout -> LoaderInstallPreflightResponse -> IO ()
writeInstallPreflightDiagnostics layout response = do
  let directory = minecraftRoot layout </> "downloads"
  createDirectoryIfMissing True directory
  BL.writeFile (directory </> "install-preflight.json") (encode response)
  writeFile
    (directory </> "shader-install.log")
    (unlines (map Text.unpack (preflightResponseBlockedReasons response <> preflightResponseShaderProjects response)))
  writeFile
    (directory </> "loader-install.log")
    (unlines (map (Text.unpack . sourceLine) (preflightDiagnosticsLoaderSources (preflightResponseDiagnostics response))))
  where
    sourceLine source =
      loaderSourceName source
        <> " ok="
        <> Text.pack (show (loaderSourceOk source))
        <> " versions="
        <> Text.pack (show (loaderSourceVersionCount source))
        <> maybe "" (" selected=" <>) (loaderSourceSelectedVersion source)
        <> maybe "" (" error=" <>) (loaderSourceError source)
