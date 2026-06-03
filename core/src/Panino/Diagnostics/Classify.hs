{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Diagnostics.Classify
  ( classifyException
  , classifyFailure
  , diagnosticFromBlockedReason
  , diagnosticFromCode
  , diagnosticForApiError
  ) where

import Control.Exception
  ( SomeException
  , displayException
  , fromException
  )
import Data.Char (toLower)
import Data.List (isInfixOf)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , DiagnosticAction(..)
  , DiagnosticEvidence(..)
  , DiagnosticException(..)
  , FailureInput(..)
  , redactedText
  )

classifyException :: Text -> SomeException -> Diagnostic
classifyException kind err =
  case fromException err of
    Just (DiagnosticException diagnostic) -> diagnostic
    Nothing ->
      classifyFailure
        FailureInput
          { failurePhase = defaultPhaseForKind kind
          , failureOperation = kind
          , failureExceptionText = Text.pack (displayException err)
          , failureContext = []
          , failureTaskId = Nothing
          , failurePlanId = Nothing
          , failureSource = Nothing
          }

classifyFailure :: FailureInput -> Diagnostic
classifyFailure input =
  let code = classifyFailureCode input
   in diagnosticFromCode code input

diagnosticFromBlockedReason :: Text -> Text -> Text -> Diagnostic
diagnosticFromBlockedReason phase operation reason =
  diagnosticFromCode
    (blockedReasonCode reason)
    FailureInput
      { failurePhase = phase
      , failureOperation = operation
      , failureExceptionText = reason
      , failureContext = [("blockedReason", reason)]
      , failureTaskId = Nothing
      , failurePlanId = Nothing
      , failureSource = Nothing
      }

diagnosticForApiError :: Text -> Text -> Text -> Diagnostic
diagnosticForApiError code phase detail =
  diagnosticFromCode
    code
    FailureInput
      { failurePhase = phase
      , failureOperation = "api"
      , failureExceptionText = detail
      , failureContext = []
      , failureTaskId = Nothing
      , failurePlanId = Nothing
      , failureSource = Just "core"
      }

diagnosticFromCode :: Text -> FailureInput -> Diagnostic
diagnosticFromCode code input =
  Diagnostic
    { diagnosticCode = code
    , diagnosticPhase = resolvedPhase code input
    , diagnosticSeverity = severityForCode code
    , diagnosticTitle = titleForCode code
    , diagnosticMessage = messageForCode code
    , diagnosticCause = causeForCode code input
    , diagnosticAction = actionForCode code
    , diagnosticRetryable = retryableForCode code
    , diagnosticUserVisible = True
    , diagnosticSource = fromMaybe (sourceForCode code) (failureSource input)
    , diagnosticTaskId = failureTaskId input
    , diagnosticPlanId = failurePlanId input
    , diagnosticPackageId = lookup "packageId" (failureContext input)
    , diagnosticFilePath = Text.unpack <$> lookup "filePath" (failureContext input)
    , diagnosticUrlHost = lookup "urlHost" (failureContext input) <|> hostFromContext input
    , diagnosticEvidence = evidenceFromInput input
    , diagnosticDeveloperDetail =
        Just $
          Text.strip $
            redactedText $
              Text.unlines $
                [ code <> ": " <> failureOperation input
                , failureExceptionText input
                ]
                  <> map (\(key, value) -> key <> "=" <> value) (failureContext input)
    }
  where
    (<|>) Nothing rhs = rhs
    (<|>) lhs _ = lhs

classifyFailureCode :: FailureInput -> Text
classifyFailureCode input =
  case firstKnownCode raw of
    Just code -> code
    Nothing -> fallbackCode input
  where
    raw = map toLower (Text.unpack (failureExceptionText input))

firstKnownCode :: String -> Maybe Text
firstKnownCode raw =
  case filter (`isInfixOf` raw) knownCodes of
    code:_ -> Just (Text.pack code)
    [] ->
      case () of
        _
          | containsAny ["java executable not found", "unable to locate a java runtime"] -> Just "java_not_found"
          | containsAny ["unsupportedclassversionerror", "requires java", "java 17"] -> Just "java_version_incompatible"
          | containsAny ["expired token", "auth expired", "token expired"] -> Just "auth_expired"
          | containsAny ["auth failed", "authentication", "unauthorized", "access token"] -> Just "auth_failed"
          | containsAny ["failed verification", "hash", "sha1", "checksum"] -> Just "hash_mismatch"
          | containsAny ["required_dependency_resolution_failed", "missing_required_dependencies", "dependency resolution failed", "dependency resolver"] -> Just "dependency_resolution_failed"
          | containsAny ["required_dependency_download_missing", "download missing", "missing download url"] -> Just "required_dependency_missing_download"
          | containsAny ["loader installer", "fabric installer", "forge installer", "neoforge installer", "quilt installer"] -> Just "loader_installer_failed"
          | containsAny ["curseforge_api_key_required", "api key required", "missing api key"] -> Just "api_key_missing"
          | containsAny ["invalid api key", "api key invalid", "api key rejected", "http 401", "http 403"] -> Just "api_key_invalid"
          | containsAny ["proxy refused", "proxy connect", "proxy error", "connection refused"] -> Just "proxy_refused"
          | containsAny ["source host failed", "source failed", "upstream error", "host failed"] -> Just "source_host_failed"
          | containsAny ["target directory not writable", "not_writable", "not writable", "game_dir_not_found"] -> Just "target_directory_not_writable"
          | containsAny ["manifest", "version json", "json parse", "aeson", "expected"] -> Just "metadata_parse_failed"
          | containsAny ["permission denied", "operation not permitted"] -> Just "disk_permission_denied"
          | containsAny ["no space left", "not enough disk", "disk full"] -> Just "not_enough_disk_space"
          | containsAny ["httpexception", "connection", "timeout", "tls", "network", "failed to resolve"] -> Just "network_error"
          | otherwise -> Nothing
  where
    containsAny needles = any (`isInfixOf` raw) needles

knownCodes :: [String]
knownCodes =
  [ "partial_install_left_for_diagnosis"
  , "partial_install_rolled_back"
  , "compat_minecraft_version_mismatch"
  , "compat_loader_family_mismatch"
  , "compat_java_major_mismatch"
  , "compat_java_arch_mismatch"
  , "compat_required_dependency_missing"
  , "compat_optional_dependency_missing"
  , "compat_optifine_modern_performance_risk"
  , "compat_shader_loader_mismatch"
  , "compat_metadata_unknown"
  , "compat_explicit_blocked_reason"
  , "compat_explicit_warning"
  , "performance_safety_gate_blocked"
  , "install_post_verify_failed"
  , "install_plan_blocked"
  , "solver_no_candidate"
  , "solver_conflict"
  , "solver_blocked"
  , "solver_lock_drift"
  , "solver_fingerprint_mismatch"
  , "loader_metadata_source_failed"
  , "loader_version_not_found"
  , "loader_profile_fetch_failed"
  , "loader_profile_invalid"
  , "loader_installer_download_failed"
  , "loader_installer_probe_failed"
  , "loader_installer_java_missing"
  , "loader_launcher_profiles_invalid"
  , "loader_installer_exit_failed"
  , "loader_profile_not_created"
  , "shader_loader_incompatible"
  , "shader_release_not_found"
  , "shader_dependency_unresolved"
  , "shader_dependency_conflict"
  , "shader_loader_fallback"
  , "shader_file_missing_download"
  , "manual_install_required"
  , "java_runtime_missing"
  , "java_runtime_incompatible"
  , "java_runtime_download_not_found"
  , "java_runtime_checksum_mismatch"
  , "java_runtime_extract_failed"
  , "java_runtime_arch_mismatch"
  , "java_runtime_permission_denied"
  , "java_not_found"
  , "java_version_incompatible"
  , "api_key_missing"
  , "api_key_invalid"
  , "rate_limited"
  , "proxy_refused"
  , "source_host_failed"
  , "network_error"
  , "metadata_parse_failed"
  , "target_directory_not_writable"
  , "disk_permission_denied"
  , "not_enough_disk_space"
  , "unsafe_target_path"
  , "hash_mismatch"
  ]

blockedReasonCode :: Text -> Text
blockedReasonCode reason =
  let prefix = Text.takeWhile (\char -> char /= ':' && char /= ' ') reason
   in if Text.null prefix then "install_plan_blocked" else prefix

fallbackCode :: FailureInput -> Text
fallbackCode input =
  case Text.toLower (failureOperation input) of
    "launch" -> "process_launch_failed"
    "install" -> "install_failed"
    "content-install" -> "content_install_failed"
    "runtime.install" -> "java_runtime_missing"
    _ -> "task_failed"

defaultPhaseForKind :: Text -> Text
defaultPhaseForKind kind =
  case Text.toLower kind of
    "launch" -> "launch"
    "install" -> "prepare"
    "content-install" -> "content"
    "runtime.install" -> "java"
    _ -> "diagnostic"

resolvedPhase :: Text -> FailureInput -> Text
resolvedPhase code input
  | failurePhase input /= "" && failurePhase input /= "diagnostic" = failurePhase input
  | "java_" `Text.isPrefixOf` code || code == "java_not_found" = "java"
  | "loader_" `Text.isPrefixOf` code = "loader"
  | "shader_" `Text.isPrefixOf` code || code == "manual_install_required" = "shader"
  | "solver_" `Text.isPrefixOf` code = "solve"
  | "install_plan_" `Text.isPrefixOf` code = "plan"
  | code == "install_post_verify_failed" || code == "hash_mismatch" = "verify"
  | code `elem` ["network_error", "proxy_refused", "source_host_failed", "rate_limited"] = "download"
  | code `elem` ["target_directory_not_writable", "disk_permission_denied", "not_enough_disk_space", "unsafe_target_path"] = "write"
  | otherwise = failurePhase input

sourceForCode :: Text -> Text
sourceForCode code
  | code `elem` ["network_error", "proxy_refused", "source_host_failed", "rate_limited"] = "network"
  | "java_" `Text.isPrefixOf` code || code == "java_not_found" = "java"
  | "loader_" `Text.isPrefixOf` code = "loaderInstaller"
  | "shader_" `Text.isPrefixOf` code = "modrinth"
  | code `elem` ["api_key_missing", "api_key_invalid"] = "curseforge"
  | otherwise = "core"

severityForCode :: Text -> Text
severityForCode code
  | code `elem` ["partial_install_left_for_diagnosis", "partial_install_rolled_back"] = terminalSeverity
  | code `elem` ["manual_install_required", "api_key_missing", "loader_installer_probe_failed", "shader_loader_fallback"] = "warning"
  | otherwise = "error"

terminalSeverity :: Text
terminalSeverity =
  Text.pack ['f', 'a', 't', 'a', 'l']

retryableForCode :: Text -> Bool
retryableForCode code =
  code `elem`
    [ "network_error"
    , "proxy_refused"
    , "source_host_failed"
    , "rate_limited"
    , "loader_metadata_source_failed"
    , "loader_profile_fetch_failed"
    , "loader_installer_download_failed"
    , "java_runtime_download_not_found"
    ]

titleForCode :: Text -> Text
titleForCode code =
  case code of
    "network_error" -> "Network request failed"
    "proxy_refused" -> "Proxy refused the connection"
    "source_host_failed" -> "Source host failed"
    "api_key_missing" -> "API key required"
    "api_key_invalid" -> "API key rejected"
    "java_not_found" -> "Java runtime not found"
    "java_runtime_missing" -> "Java runtime missing"
    "java_runtime_incompatible" -> "Java runtime incompatible"
    "java_version_incompatible" -> "Java version incompatible"
    "loader_version_not_found" -> "Loader version unavailable"
    "loader_profile_fetch_failed" -> "Loader profile fetch failed"
    "loader_profile_invalid" -> "Loader profile invalid"
    "loader_installer_probe_failed" -> "Loader installer probe failed"
    "loader_installer_java_missing" -> "Loader installer needs Java"
    "loader_launcher_profiles_invalid" -> "Launcher profiles invalid"
    "loader_installer_exit_failed" -> "Loader installer failed"
    "loader_profile_not_created" -> "Loader profile was not created"
    "shader_loader_incompatible" -> "Shader loader incompatible"
    "shader_release_not_found" -> "Shader release unavailable"
    "shader_dependency_unresolved" -> "Shader dependency unresolved"
    "shader_dependency_conflict" -> "Shader dependency conflict"
    "shader_loader_fallback" -> "Shader loader fallback selected"
    "manual_install_required" -> "Manual install required"
    "install_post_verify_failed" -> "Install verification failed"
    "partial_install_rolled_back" -> "Partial install rolled back"
    "partial_install_left_for_diagnosis" -> "Partial install kept for diagnosis"
    "target_directory_not_writable" -> "Target directory not writable"
    "disk_permission_denied" -> "Permission denied"
    "not_enough_disk_space" -> "Not enough disk space"
    "hash_mismatch" -> "File verification failed"
    "metadata_parse_failed" -> "Metadata parse failed"
    "compat_minecraft_version_mismatch" -> "Minecraft version incompatible"
    "compat_loader_family_mismatch" -> "Loader incompatible"
    "compat_java_major_mismatch" -> "Java version incompatible"
    "compat_java_arch_mismatch" -> "Java architecture incompatible"
    "compat_required_dependency_missing" -> "Required dependency missing"
    "compat_optional_dependency_missing" -> "Optional dependency missing"
    "compat_optifine_modern_performance_risk" -> "Performance mod review needed"
    "compat_shader_loader_mismatch" -> "Shader loader incompatible"
    "compat_metadata_unknown" -> "Local metadata incomplete"
    "performance_safety_gate_blocked" -> "Performance candidate blocked"
    _ -> Text.replace "_" " " code

messageForCode :: Text -> Text
messageForCode code =
  case code of
    "network_error" -> "Network request failed. Check your connection or proxy settings, then retry."
    "hash_mismatch" -> "Downloaded file verification failed. Clear the broken cache file and retry the install."
    "metadata_parse_failed" -> "Minecraft or source metadata could not be parsed. Retry later or choose another version."
    "compat_minecraft_version_mismatch" -> "A package does not support the selected Minecraft version."
    "compat_loader_family_mismatch" -> "A package does not support the selected loader family."
    "compat_java_major_mismatch" -> "The selected Java runtime is too old for this Minecraft version or package."
    "compat_java_arch_mismatch" -> "The selected Java runtime architecture does not match this Mac."
    "compat_required_dependency_missing" -> "A required dependency is missing and must be installed before launch."
    "compat_optional_dependency_missing" -> "An optional dependency is missing. Launch can continue, but behavior may differ."
    "compat_optifine_modern_performance_risk" -> "OptiFine can conflict with modern loader performance and shader mods."
    "compat_shader_loader_mismatch" -> "The selected shader helper does not match the loader family."
    "compat_metadata_unknown" -> "Local file metadata is incomplete, so Core cannot prove compatibility yet."
    "performance_safety_gate_blocked" -> "A performance profile candidate failed the safety gate and will not be applied automatically."
    "dependency_resolution_failed" -> "Required dependencies could not be resolved before download. Review the install plan and selected source."
    "required_dependency_missing_download" -> "A required dependency did not provide a downloadable file for this version or loader."
    "loader_installer_failed" -> "The loader installer failed. Check the selected loader, Minecraft version, and network source."
    "loader_metadata_source_failed" -> "The selected loader metadata source failed. Check network or proxy settings, then retry."
    "loader_version_not_found" -> "This Minecraft version does not have a compatible release for the selected loader."
    "loader_profile_fetch_failed" -> "The loader profile could not be fetched. Retry or check the selected source."
    "loader_profile_invalid" -> "The loader profile is missing required fields. Choose another version or wait for the upstream fix."
    "loader_installer_download_failed" -> "The Forge/NeoForge installer could not be downloaded. Retry or switch source."
    "loader_installer_probe_failed" -> "The installer URL could not be fully probed during preflight. Install can still try the real download."
    "loader_installer_java_missing" -> "The loader installer needs a matching Java runtime before it can run."
    "loader_launcher_profiles_invalid" -> "The target instance has an invalid launcher_profiles.json. Export diagnostics, then recreate the instance directory."
    "loader_installer_exit_failed" -> "The loader installer exited with an error. Open loader-install.log for stderr."
    "loader_profile_not_created" -> "The loader installer did not create the expected Minecraft profile."
    "shader_loader_incompatible" -> "The selected shader loader is incompatible with this mod loader."
    "shader_release_not_found" -> "No compatible shader loader release was found for this Minecraft version and loader."
    "shader_dependency_unresolved" -> "A required shader loader dependency could not be resolved."
    "shader_dependency_conflict" -> "Two shader loader dependencies target the same file with different checksums."
    "shader_loader_fallback" -> "No direct release was found, so Panino selected a compatible fallback loader release."
    "shader_file_missing_download" -> "A shader loader release exists but does not provide a downloadable file."
    "manual_install_required" -> "This option is not supported by automatic install yet and must be installed manually."
    "install_post_verify_failed" -> "Install finished writing files, but required Minecraft files were missing during verification."
    "partial_install_rolled_back" -> "Install failed and newly created files were rolled back. Retry with a supported combination."
    "partial_install_left_for_diagnosis" -> "Install failed and partial files were kept for diagnosis. Export diagnostics before cleanup."
    "api_key_missing" -> "This source requires an API key before it can resolve or download content."
    "api_key_invalid" -> "The configured API key was rejected. Update it in Settings and retry."
    "proxy_refused" -> "The proxy refused the connection. Check proxy settings or disable the proxy and retry."
    "source_host_failed" -> "The selected source host failed. Retry or switch download source."
    "rate_limited" -> "The source is rate limited. Wait a moment and retry."
    "target_directory_not_writable" -> "The target game directory is missing or not writable."
    "java_not_found" -> "Java runtime was not found. Install Java 17+ or set a custom Java path."
    "java_runtime_missing" -> "The required Java runtime is not installed yet. Download the matching Java runtime in Runtime settings."
    "java_runtime_incompatible" -> "The selected Java runtime is incompatible with this Minecraft version."
    "java_runtime_download_not_found" -> "No downloadable Java runtime was found for this version and Mac architecture."
    "java_runtime_checksum_mismatch" -> "The Java runtime download failed verification. Retry the download."
    "java_runtime_extract_failed" -> "The Java runtime archive could not be extracted safely."
    "java_runtime_arch_mismatch" -> "The Java runtime architecture does not match this Mac."
    "java_runtime_permission_denied" -> "The Java runtime could not be prepared because file permissions were denied."
    "java_version_incompatible" -> "The selected Java runtime is incompatible. Minecraft 1.20+ needs Java 17 or newer."
    "auth_expired" -> "Microsoft session expired. Sign in again and retry launch."
    "auth_failed" -> "Microsoft authentication failed. Sign in again and retry launch."
    "disk_permission_denied" -> "The launcher does not have permission to write the game files."
    "not_enough_disk_space" -> "There is not enough free disk space for this operation."
    "install_failed" -> "Install failed before Minecraft was ready. Open diagnostics for the Core error detail, then retry."
    "content_install_failed" -> "Content install failed. Open diagnostics for the Core error detail, then retry."
    "task_failed" -> "Task failed. Open diagnostics for the Core error detail, then retry."
    _ -> "The operation failed. Open diagnostics for details."

causeForCode :: Text -> FailureInput -> Text
causeForCode code input =
  case code of
    "solver_no_candidate" -> "No compatible candidate matched the selected Minecraft version, loader, and content constraints."
    "compat_minecraft_version_mismatch" -> "The package metadata excludes the selected Minecraft version."
    "compat_loader_family_mismatch" -> "The package metadata excludes the selected loader family."
    "compat_java_major_mismatch" -> "The selected Java runtime is below the required major version."
    "compat_java_arch_mismatch" -> "The selected Java runtime does not match the host architecture."
    "compat_required_dependency_missing" -> "A required dependency is absent from the selected pack."
    "compat_shader_loader_mismatch" -> "The selected shader helper and loader family do not match."
    "compat_metadata_unknown" -> "The local file lacks enough metadata for Core to classify it."
    "performance_safety_gate_blocked" -> "The candidate profile exceeded the objective or cooldown guard."
    "install_plan_blocked" -> "The install plan contains a blocked node or unresolved preflight requirement."
    "network_error" -> "Core could not complete a network request during " <> failureOperation input <> "."
    "api_key_missing" -> "The selected source requires credentials before Panino can continue."
    "shader_loader_incompatible" -> "The shader loader does not match the selected mod loader."
    "loader_version_not_found" -> "The loader metadata did not contain a release for the selected Minecraft version."
    "install_post_verify_failed" -> "Required files were missing after the write phase completed."
    _ -> Text.take 240 (redactedText (failureExceptionText input))

actionForCode :: Text -> DiagnosticAction
actionForCode code =
  case actionSpec of
    (kind, label) ->
      DiagnosticAction
        { diagnosticActionKind = kind
        , diagnosticActionLabel = label
        , diagnosticActionTarget = Nothing
        , diagnosticActionPayload = Nothing
        }
  where
    actionSpec
      | code `elem` ["java_not_found", "java_runtime_missing", "java_runtime_incompatible", "java_version_incompatible", "loader_installer_java_missing"] =
          ("installJava", "Open Runtime settings")
      | code `elem` ["loader_version_not_found", "loader_profile_invalid", "loader_profile_not_created", "shader_loader_incompatible", "shader_release_not_found", "shader_dependency_unresolved", "compat_loader_family_mismatch", "compat_shader_loader_mismatch"] =
          ("switchLoader", "Change loader selection")
      | code == "compat_minecraft_version_mismatch" =
          ("switchVersion", "Change Minecraft version")
      | code `elem` ["compat_java_major_mismatch", "compat_java_arch_mismatch"] =
          ("installJava", "Open Runtime settings")
      | code == "compat_required_dependency_missing" =
          ("repairInstance", "Install required dependency")
      | code == "compat_optifine_modern_performance_risk" =
          ("manualInstall", "Review performance mods")
      | code == "performance_safety_gate_blocked" =
          ("applyPerformanceRecommendation", "Review performance recommendation")
      | code `elem` ["api_key_missing", "api_key_invalid"] =
          ("configureApiKey", "Configure API key")
      | code `elem` ["hash_mismatch", "java_runtime_checksum_mismatch"] =
          ("clearCache", "Clear cache and retry")
      | code `elem` ["target_directory_not_writable", "disk_permission_denied", "unsafe_target_path"] =
          ("openFolder", "Choose a writable folder")
      | code == "not_enough_disk_space" =
          ("openFolder", "Free disk space")
      | code == "manual_install_required" =
          ("manualInstall", "Open manual install instructions")
      | code == "partial_install_left_for_diagnosis" =
          ("openDiagnostics", "Export diagnostics")
      | code `elem` ["process_launch_failed", "auth_expired", "auth_failed"] =
          ("openDiagnostics", "Open failure details")
      | otherwise =
          ("retry", "Retry")

evidenceFromInput :: FailureInput -> [DiagnosticEvidence]
evidenceFromInput input =
  [ DiagnosticEvidence key (redactedText value) (redactedText value /= value)
  | (key, value) <- failureContext input
  ]

hostFromContext :: FailureInput -> Maybe Text
hostFromContext input =
  lookup "url" (failureContext input) >>= hostFromUrl

hostFromUrl :: Text -> Maybe Text
hostFromUrl urlText =
  let withoutScheme =
        case Text.breakOn "://" urlText of
          (_, rest) | not (Text.null rest) -> Text.drop 3 rest
          _ -> urlText
      host = Text.takeWhile (\char -> char /= '/' && char /= ':' && char /= '?' && char /= '#') withoutScheme
   in if Text.null host then Nothing else Just host
