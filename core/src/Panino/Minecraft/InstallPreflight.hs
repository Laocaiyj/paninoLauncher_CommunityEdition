{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Minecraft.InstallPreflight
  ( LoaderInstallPreflightDiagnostics(..)
  , LoaderInstallPreflightRequest(..)
  , LoaderInstallPreflightResponse(..)
  , blockedLoaderInstallPreflightResponse
  , loaderInstallPreflight
  , preflightFromInstallRequest
  , writeInstallPreflightDiagnostics
  ) where

import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import Data.Aeson
  ( Value(..)
  , encode
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as BL
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
  , contentLoaderMetadataSources
  , preferredLoaderMetadata
  )
import Panino.Content.Online.Types
  ( ContentLoaderRequest(..)
  , LoaderMetadata(..)
  )
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Diagnostics.Types (Diagnostic(..))
import qualified Panino.Install.Plan.Types as Plan
import Panino.Minecraft.LoaderInstall
  ( ModrinthFile(..)
  , ResolvedModrinthMod(..)
  , ShaderResolution(..)
  , normalizeLoaderName
  , resolveModrinthProject
  , resolveShaderModrinthProject
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  )
import Panino.Minecraft.InstallPreflight.Probe
  ( probeHttpUrl
  , probeStatusText
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

preflightTypedPlan :: LoaderInstallPreflightRequest -> LoaderPreflightCheck -> ShaderPreflightCheck -> [Text] -> [Text] -> [Diagnostic] -> Plan.TypedInstallPlan
preflightTypedPlan request loaderCheck shaderCheck warnings blockedReasons diagnostics =
  Plan.finalizeTypedInstallPlan
    Plan.TypedInstallPlan
      { Plan.typedPlanId = ""
      , Plan.typedPlanFingerprint = ""
      , Plan.typedPlanKind = "minecraftProfilePreflight"
      , Plan.typedPlanTitle = "Minecraft install preflight"
      , Plan.typedPlanTargetGameDir = preflightGameDir request
      , Plan.typedPlanSource = Just "minecraft"
      , Plan.typedPlanStatus = ""
      , Plan.typedPlanSummary = Plan.InstallPlanSummary 0 0 0 0 0 Nothing
      , Plan.typedPlanNodes = minecraftNode : loaderNodes <> shaderNodes
      , Plan.typedPlanEdges = shaderEdges
      , Plan.typedPlanWarnings = warnings
      , Plan.typedPlanBlockedReasons = blockedReasons
      , Plan.typedPlanDiagnostics = diagnostics
      , Plan.typedPlanRollbackPolicy = "preflight-only"
      }
  where
    minecraftNode =
      preflightNode
        "minecraft-version"
        "minecraftVersion"
        "verify"
        "minecraft"
        ("Minecraft " <> preflightMinecraftVersion request)
        []
        []
        Nothing
        []
    loaderNodes =
      case normalizedOptionalLoader (preflightLoader request) of
        Nothing -> []
        Just loader ->
          [ preflightNode
              "loader-profile"
              "loaderProfile"
              "verify"
              "loader"
              loader
              ["minecraft-version"]
              [ Plan.InstallVerification "loaderCompatible" (if null (loaderBlockedReasons loaderCheck) then "ok" else "error") (loaderSelectedVersion loaderCheck)
              ]
              (listToMaybe (loaderBlockedReasons loaderCheck))
              (map (diagnosticFromBlockedReason "preflight" ("loader " <> loader)) (loaderBlockedReasons loaderCheck))
          ]
    shaderNodes =
      case normalizedOptionalShader (preflightShaderLoader request) of
        Nothing -> []
        Just shader ->
          [ preflightNode
              "shader-loader"
              "mod"
              "verify"
              "shader"
              shader
              (if null loaderNodes then ["minecraft-version"] else ["loader-profile"])
              [ Plan.InstallVerification "shaderCompatible" (if null (shaderBlockedReasons shaderCheck) then "ok" else "error") (Just (Text.intercalate ", " (shaderProjects shaderCheck)))
              ]
              (listToMaybe (shaderBlockedReasons shaderCheck))
              (map (diagnosticFromBlockedReason "preflight" ("shader " <> shader)) (shaderBlockedReasons shaderCheck))
          ]
    shaderEdges =
      [ Plan.InstallPlanEdge "loader-profile" "shader-loader" "requires" True
      | not (null loaderNodes)
      , not (null shaderNodes)
      ]

preflightNode :: Text -> Text -> Text -> Text -> Text -> [Text] -> [Plan.InstallVerification] -> Maybe Text -> [Diagnostic] -> Plan.InstallPlanNode
preflightNode nodeId kind action phase label dependsOn verifications blockedReason diagnostics =
  Plan.InstallPlanNode
    { Plan.installNodeId = nodeId
    , Plan.installNodeKind = kind
    , Plan.installNodeAction = action
    , Plan.installNodePhase = phase
    , Plan.installNodeLabel = label
    , Plan.installNodeTargetPath = Nothing
    , Plan.installNodeSourceUrls = []
    , Plan.installNodeSha1 = Nothing
    , Plan.installNodeSize = Nothing
    , Plan.installNodeRequired = True
    , Plan.installNodeDependsOn = dependsOn
    , Plan.installNodeVerifications = verifications
    , Plan.installNodeRollback =
        Plan.InstallPlanRollbackAction
          { Plan.installRollbackAction = "noneWithReason"
          , Plan.installRollbackTargetPath = Nothing
          , Plan.installRollbackBackupPath = Nothing
          , Plan.installRollbackReason = Just "Preflight verifies compatibility and does not write files."
          }
    , Plan.installNodeBlockedReason = blockedReason
    , Plan.installNodeDiagnostics = diagnostics
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

resolveShaderCompanions :: Manager -> LoaderInstallPreflightRequest -> ShaderResolution -> IO ShaderPreflightCheck
resolveShaderCompanions manager request resolution = do
  companionOutcome <-
    try
      ( if shaderResolutionProject resolution == "iris" && normalizeLoaderName (shaderResolutionResolvedLoader resolution) == "fabric"
          then resolveModrinthProject manager (preflightMinecraftVersion request) (shaderResolutionResolvedLoader resolution) (map resolvedModrinthProject resolved) "fabric-api"
          else pure []
      )
  case companionOutcome of
    Right companions -> do
      let projects = map resolvedModrinthProject (resolved <> companions)
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
          { shaderProjects = map resolvedModrinthProject resolved
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
      | otherwise = Just ("shader_file_missing_sha1:" <> resolvedModrinthProject resolved)

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
