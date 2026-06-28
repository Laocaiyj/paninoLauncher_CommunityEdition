{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Minecraft.InstallPreflight.Resolve
  ( resolveLoaderPreflight
  , resolveShaderPreflight
  ) where

import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import Data.Aeson (Value(..))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.List (find)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( listToMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Http
  ( coreRequest
  , fetchJson
  )
import Panino.Content.Online.Minecraft
  ( LoaderMetadataSourceResult(..)
  , preferredLoaderMetadata
  )
import Panino.Content.Online.Types (LoaderMetadata(..))
import Panino.Core.Types (projectIdText)
import Panino.Minecraft.InstallPreflight.Checks
  ( LoaderPreflightCheck(..)
  , ShaderPreflightCheck(..)
  , emptyLoaderCheck
  , emptyShaderCheck
  , normalizedOptionalLoader
  , normalizedOptionalShader
  )
import Panino.Minecraft.InstallPreflight.Probe
  ( probeHttpUrl
  , probeStatusText
  )
import Panino.Minecraft.InstallPreflight.Types (LoaderInstallPreflightRequest(..))
import Panino.Minecraft.LoaderInstall
  ( ModrinthFile(..)
  , ResolvedModrinthMod(..)
  , ShaderResolution(..)
  , normalizeLoaderName
  , resolveModrinthProject
  , resolveShaderModrinthProject
  )

resolveLoaderPreflight :: Manager -> LoaderInstallPreflightRequest -> [LoaderMetadataSourceResult] -> IO LoaderPreflightCheck
resolveLoaderPreflight manager request loaderSources =
  case normalizedOptionalLoader (preflightLoader request) of
    Nothing -> pure emptyLoaderCheck
    Just loader -> do
      let source = find ((== loader) . normalizeLoaderName . loaderSourceName) loaderSources
          sourceWarnings = unselectedLoaderSourceWarnings loader loaderSources
      case source of
        Nothing ->
          pure emptyLoaderCheck { loaderWarnings = sourceWarnings, loaderBlockedReasons = ["loader_metadata_source_failed:" <> loader] }
        Just result
          | not (loaderSourceOk result) ->
              pure emptyLoaderCheck { loaderWarnings = sourceWarnings, loaderBlockedReasons = ["loader_metadata_source_failed:" <> loader] }
          | otherwise ->
              case selectedLoaderMetadata request (loaderSourceVersions result) of
                Nothing ->
                  pure emptyLoaderCheck { loaderWarnings = sourceWarnings, loaderBlockedReasons = ["loader_version_not_found:" <> loader <> " " <> preflightMinecraftVersion request <> maybe "" (" " <>) (preflightLoaderVersion request)] }
                Just metadata ->
                  addLoaderWarnings sourceWarnings <$> resolveLoaderArtifact manager request loader metadata

resolveLoaderArtifact :: Manager -> LoaderInstallPreflightRequest -> Text -> LoaderMetadata -> IO LoaderPreflightCheck
resolveLoaderArtifact manager request loader metadata
  | loader `elem` ["fabric", "quilt"] = do
      let url = loaderProfileUrl loader (preflightMinecraftVersion request) (loaderMetadataLoaderVersion metadata)
      profileResult <- try (fetchJson manager =<< coreRequest (Text.unpack url) [])
      case profileResult of
        Left (err :: SomeException) ->
          pure
            emptyLoaderCheck
              { loaderSelectedVersion = Just (loaderMetadataLoaderVersion metadata)
              , loaderProfileUrlText = Just url
              , loaderBlockedReasons = ["loader_profile_fetch_failed:" <> loader <> " " <> Text.pack (displayException err)]
              }
        Right profile ->
          case validateLoaderProfile profile of
            Left reason ->
              pure
                emptyLoaderCheck
                  { loaderSelectedVersion = Just (loaderMetadataLoaderVersion metadata)
                  , loaderProfileUrlText = Just url
                  , loaderBlockedReasons = ["loader_profile_invalid:" <> loader <> " " <> reason]
                  }
            Right profileId ->
              pure
                emptyLoaderCheck
                  { loaderSelectedVersion = Just (loaderMetadataLoaderVersion metadata)
                  , loaderProfileId = Just profileId
                  , loaderProfileUrlText = Just url
                  }
  | loader `elem` ["forge", "neoforge"] = do
      let url = loaderInstallerUrl loader (preflightMinecraftVersion request) (loaderMetadataLoaderVersion metadata)
          javaMissing = preflightJavaExecutable request == Nothing
      downloadProbe <- probeHttpUrl manager url
      pure
        emptyLoaderCheck
          { loaderSelectedVersion = Just (loaderMetadataLoaderVersion metadata)
          , loaderInstallerUrlText = Just url
          , loaderInstallerProbeStatus = Just (probeStatusText downloadProbe)
          , loaderWarnings =
              [ "loader_installer_java_missing:" <> loader | javaMissing ]
                <> [ "loader_installer_probe_failed:" <> loader <> " " <> reason | Left reason <- [downloadProbe] ]
          }
  | otherwise =
      pure emptyLoaderCheck { loaderBlockedReasons = ["loader_version_not_found:" <> loader] }

resolveShaderPreflight :: Manager -> LoaderInstallPreflightRequest -> IO ShaderPreflightCheck
resolveShaderPreflight manager request =
  case normalizedOptionalShader (preflightShaderLoader request) of
    Nothing -> pure emptyShaderCheck
    Just "optifine" ->
      pure emptyShaderCheck { shaderWarnings = ["manual_install_required:optifine"] }
    Just "iris" ->
      resolveModrinthShader manager request "iris" ["fabric", "quilt"]
    Just "oculus" ->
      resolveModrinthShader manager request "oculus" ["forge", "neoforge"]
    Just shader ->
      pure emptyShaderCheck { shaderBlockedReasons = ["shader_loader_incompatible:" <> shader] }

resolveModrinthShader :: Manager -> LoaderInstallPreflightRequest -> Text -> [Text] -> IO ShaderPreflightCheck
resolveModrinthShader manager request project supportedLoaders =
  case normalizedOptionalLoader (preflightLoader request) of
    Nothing ->
      pure emptyShaderCheck { shaderBlockedReasons = ["shader_loader_incompatible:" <> project <> " requires loader"] }
    Just loader
      | loader `notElem` supportedLoaders ->
          pure emptyShaderCheck { shaderBlockedReasons = ["shader_loader_incompatible:" <> project <> " " <> loader] }
      | otherwise -> do
          outcome <- try (resolveShaderModrinthProject manager (preflightMinecraftVersion request) loader project (preflightShaderVersion request))
          case outcome of
            Right resolution ->
              resolveShaderCompanions manager request resolution
            Left (err :: SomeException) ->
              pure
                emptyShaderCheck
                  { shaderProjects = [project]
                  , shaderBlockedReasons = [shaderPreflightBlockedReason project loader (preflightMinecraftVersion request) err]
                  }

validateLoaderProfile :: Value -> Either Text Text
validateLoaderProfile (Object obj) = do
  profileId <-
    case KeyMap.lookup (Key.fromString "id") obj of
      Just (String value) | not (Text.null value) -> Right value
      _ -> Left "missing_id"
  case KeyMap.lookup (Key.fromString "mainClass") obj of
    Just (String value) | not (Text.null value) -> Right ()
    _ -> Left "missing_mainClass"
  case KeyMap.lookup (Key.fromString "libraries") obj of
    Just (Array values) | not (null values) -> Right ()
    _ -> Left "missing_libraries"
  Right profileId
validateLoaderProfile _ =
  Left "profile_not_object"

loaderProfileUrl :: Text -> Text -> Text -> Text
loaderProfileUrl "fabric" minecraftVersion loaderVersion =
  "https://meta.fabricmc.net/v2/versions/loader/" <> minecraftVersion <> "/" <> loaderVersion <> "/profile/json"
loaderProfileUrl "quilt" minecraftVersion loaderVersion =
  "https://meta.quiltmc.org/v3/versions/loader/" <> minecraftVersion <> "/" <> loaderVersion <> "/profile/json"
loaderProfileUrl loader _ _ =
  "unsupported://" <> loader

loaderInstallerUrl :: Text -> Text -> Text -> Text
loaderInstallerUrl "forge" minecraftVersion loaderVersion =
  let artifactVersion = minecraftVersion <> "-" <> loaderVersion
   in "https://maven.minecraftforge.net/net/minecraftforge/forge/" <> artifactVersion <> "/forge-" <> artifactVersion <> "-installer.jar"
loaderInstallerUrl "neoforge" _ loaderVersion =
  "https://maven.neoforged.net/releases/net/neoforged/neoforge/" <> loaderVersion <> "/neoforge-" <> loaderVersion <> "-installer.jar"
loaderInstallerUrl loader _ _ =
  "unsupported://" <> loader

unselectedLoaderSourceWarnings :: Text -> [LoaderMetadataSourceResult] -> [Text]
unselectedLoaderSourceWarnings selectedLoader =
  mapMaybe sourceWarning
  where
    sourceWarning source
      | normalizeLoaderName (loaderSourceName source) == selectedLoader = Nothing
      | loaderSourceOk source = Nothing
      | otherwise = Just ("loader_metadata_source_failed:" <> loaderSourceName source)

addLoaderWarnings :: [Text] -> LoaderPreflightCheck -> LoaderPreflightCheck
addLoaderWarnings warnings check =
  check { loaderWarnings = loaderWarnings check <> warnings }

selectedLoaderMetadata :: LoaderInstallPreflightRequest -> [LoaderMetadata] -> Maybe LoaderMetadata
selectedLoaderMetadata request versions =
  case preflightLoaderVersion request of
    Just requestedVersion -> listToMaybe (filter ((== requestedVersion) . loaderMetadataLoaderVersion) versions)
    Nothing -> preferredLoaderMetadata versions

resolveShaderCompanions :: Manager -> LoaderInstallPreflightRequest -> ShaderResolution -> IO ShaderPreflightCheck
resolveShaderCompanions manager request resolution = do
  companionOutcome <-
    try
      ( if shaderResolutionProject resolution == "iris" && normalizeLoaderName (shaderResolutionResolvedLoader resolution) == "fabric"
          then resolveModrinthProject manager (preflightMinecraftVersion request) (shaderResolutionResolvedLoader resolution) (map (projectIdText . resolvedModrinthProject) resolved) "fabric-api"
          else pure []
      )
  case companionOutcome of
    Right companions -> do
      let projects = map (projectIdText . resolvedModrinthProject) (resolved <> companions)
      pure
        emptyShaderCheck
          { shaderProjects = projects
          , shaderSelectedVersion = Just (shaderResolutionVersion resolution)
          , shaderResolvedLoader = Just (shaderResolutionResolvedLoader resolution)
          , shaderFallbackFrom = fallbackFrom
          , shaderFallbackTo = fallbackTo
          , shaderRequiredDependencies = filter (/= shaderResolutionProject resolution) projects
          , shaderWarnings = missingShaderSha1Warnings (resolved <> companions)
              <> [ "shader_loader_fallback:"
                    <> shaderResolutionProject resolution
                    <> " "
                    <> shaderResolutionRequestedLoader resolution
                    <> "->"
                    <> shaderResolutionResolvedLoader resolution
                 | fallbackFrom /= Nothing
                 ]
          }
    Left (err :: SomeException) ->
      pure
        emptyShaderCheck
          { shaderProjects = map (projectIdText . resolvedModrinthProject) resolved
          , shaderSelectedVersion = Just (shaderResolutionVersion resolution)
          , shaderResolvedLoader = Just (shaderResolutionResolvedLoader resolution)
          , shaderFallbackFrom = fallbackFrom
          , shaderFallbackTo = fallbackTo
          , shaderBlockedReasons = ["shader_dependency_unresolved:fabric-api " <> Text.pack (displayException err)]
          }
  where
    resolved = shaderResolutionMods resolution
    fallbackFrom =
      if shaderResolutionRequestedLoader resolution == shaderResolutionResolvedLoader resolution
        then Nothing
        else Just (shaderResolutionRequestedLoader resolution)
    fallbackTo =
      if shaderResolutionRequestedLoader resolution == shaderResolutionResolvedLoader resolution
        then Nothing
        else Just (shaderResolutionResolvedLoader resolution)

missingShaderSha1Warnings :: [ResolvedModrinthMod] -> [Text]
missingShaderSha1Warnings =
  mapMaybe missingSha1
  where
    missingSha1 resolved
      | Map.member "sha1" (modrinthFileHashes (resolvedModrinthFile resolved)) = Nothing
      | otherwise = Just ("shader_file_missing_sha1:" <> projectIdText (resolvedModrinthProject resolved))

shaderPreflightBlockedReason :: Text -> Text -> Text -> SomeException -> Text
shaderPreflightBlockedReason project loader minecraftVersion err
  | "dependency" `Text.isInfixOf` lower =
      "shader_dependency_unresolved:" <> project <> " " <> message
  | "shader_release_not_found" `Text.isInfixOf` lower =
      "shader_release_not_found:" <> project <> " " <> minecraftVersion <> " " <> loader
  | otherwise =
      "shader_resolution_failed:" <> project <> " " <> message
  where
    message = Text.pack (displayException err)
    lower = Text.toLower message
