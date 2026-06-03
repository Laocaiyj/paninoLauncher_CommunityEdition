{-# LANGUAGE OverloadedStrings #-}

module Panino.Compatibility.Rules
  ( compatibilityDiagnostic
  , globalCompatibilityDiagnostics
  , normalizeArch
  , normalizeLoader
  , packageCompatibilityDiagnostics
  , packageIdentityTexts
  ) where

import Data.List
  ( nub
  , sort
  , sortOn
  )
import Data.Maybe
  ( catMaybes
  , fromMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Compatibility.Types
  ( CompatibilityEvaluateRequest(..)
  , CompatibilityPackageInput(..)
  , CompatibilityTarget(..)
  )
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , DiagnosticAction(..)
  , DiagnosticEvidence(..)
  )

globalCompatibilityDiagnostics :: CompatibilityEvaluateRequest -> [Diagnostic]
globalCompatibilityDiagnostics request =
  explicitBlockedDiagnostics
    <> javaMajorDiagnostics
    <> javaArchDiagnostics
    <> shaderTargetDiagnostics
    <> optifineModernPerformanceDiagnostics
    <> explicitWarningDiagnostics
  where
    target = compatibilityRequestTarget request
    explicitBlockedDiagnostics =
      [ compatibilityDiagnostic
          "compat_explicit_blocked_reason"
          ("Compatibility input reported a blocked reason: " <> reason)
          "blocked"
          Nothing
          [DiagnosticEvidence "reason" reason False]
      | reason <- compatibilityRequestBlockedReasons request
      ]
    explicitWarningDiagnostics =
      [ compatibilityDiagnostic
          "compat_explicit_warning"
          ("Compatibility input reported a warning: " <> warning)
          "warning"
          Nothing
          [DiagnosticEvidence "warning" warning False]
      | warning <- compatibilityRequestWarnings request
      ]
    javaMajorDiagnostics =
      case (compatibilityTargetJavaMajor target, compatibilityTargetRequiredJavaMajor target) of
        (Just selectedMajor, Just requiredMajor)
          | selectedMajor < requiredMajor ->
              [ compatibilityDiagnostic
                  "compat_java_major_mismatch"
                  ( "Java "
                      <> Text.pack (show selectedMajor)
                      <> " is lower than required Java "
                      <> Text.pack (show requiredMajor)
                  )
                  "blocked"
                  Nothing
                  [ DiagnosticEvidence "selectedJavaMajor" (Text.pack (show selectedMajor)) False
                  , DiagnosticEvidence "requiredJavaMajor" (Text.pack (show requiredMajor)) False
                  ]
              ]
        _ -> []
    javaArchDiagnostics =
      case (normalizeArch <$> compatibilityTargetJavaArch target, normalizeArch <$> compatibilityTargetSystemArch target) of
        (Just javaArch, Just systemArch)
          | javaArch /= systemArch ->
              [ compatibilityDiagnostic
                  "compat_java_arch_mismatch"
                  ("Java runtime architecture " <> javaArch <> " does not match system architecture " <> systemArch)
                  "blocked"
                  Nothing
                  [ DiagnosticEvidence "javaArch" javaArch False
                  , DiagnosticEvidence "systemArch" systemArch False
                  ]
              ]
        _ -> []
    shaderTargetDiagnostics =
      case normalizeLoader <$> compatibilityTargetShaderLoader target of
        Just "iris"
          | normalizedTargetLoader target `notElem` map Just ["fabric", "quilt"] ->
              [shaderLoaderDiagnostic "iris" "Fabric or Quilt"]
        Just "oculus"
          | normalizedTargetLoader target `notElem` map Just ["forge", "neoforge"] ->
              [shaderLoaderDiagnostic "oculus" "Forge or NeoForge"]
        _ -> []
    shaderLoaderDiagnostic shader expectedLoader =
      compatibilityDiagnostic
        "compat_shader_loader_mismatch"
        (shader <> " requires " <> expectedLoader <> ".")
        "blocked"
        Nothing
        [ DiagnosticEvidence "shaderLoader" shader False
        , DiagnosticEvidence "loader" (fromMaybe "vanilla" (normalizedTargetLoader target)) False
        ]
    optifineModernPerformanceDiagnostics =
      [ compatibilityDiagnostic
          "compat_optifine_modern_performance_risk"
          "OptiFine is mixed with a modern performance or shader package and needs manual review."
          "warning"
          Nothing
          [DiagnosticEvidence "packages" (Text.intercalate "," selectedIds) False]
      | "optifine" `elem` selectedIds
      , any (`elem` selectedIds) modernPerformanceIds
      ]
    selectedIds = packageIdentityTexts (compatibilityRequestPackages request) <> map normalizePackageId (compatibilityRequestInstalledPackageIds request)

packageCompatibilityDiagnostics :: CompatibilityTarget -> [Text] -> CompatibilityPackageInput -> [Diagnostic]
packageCompatibilityDiagnostics target installedIds package =
  metadataDiagnostics
    <> minecraftVersionDiagnostics
    <> loaderDiagnostics
    <> packageJavaDiagnostics
    <> dependencyDiagnostics
    <> optionalDependencyDiagnostics
    <> shaderPackageDiagnostics
  where
    packageId = Just (compatibilityPackageId package)
    metadataDiagnostics =
      [ compatibilityDiagnostic
          "compat_metadata_unknown"
          "Local file metadata is incomplete, so compatibility cannot be proven."
          "unknown"
          packageId
          [DiagnosticEvidence "packageId" (compatibilityPackageId package) False]
      | not (compatibilityPackageMetadataComplete package)
      ]
    minecraftVersionDiagnostics =
      case compatibilityTargetMinecraftVersion target of
        Just version
          | not (null compatibleVersions) && version `notElem` compatibleVersions ->
              [ compatibilityDiagnostic
                  "compat_minecraft_version_mismatch"
                  (compatibilityPackageName package <> " does not list Minecraft " <> version <> " as compatible.")
                  "blocked"
                  packageId
                  [ DiagnosticEvidence "targetMinecraftVersion" version False
                  , DiagnosticEvidence "packageMinecraftVersions" (Text.intercalate "," compatibleVersions) False
                  ]
              ]
        _ -> []
    loaderDiagnostics =
      case normalizedTargetLoader target of
        Just loader
          | not (null compatibleLoaders) && loader `notElem` compatibleLoaders ->
              [ loaderMismatchDiagnostic loader ]
        Nothing
          | not (null compatibleLoaders) ->
              [ loaderMismatchDiagnostic "vanilla" ]
        _ -> []
    loaderMismatchDiagnostic loader =
      compatibilityDiagnostic
        "compat_loader_family_mismatch"
        (compatibilityPackageName package <> " is not compatible with loader " <> loader <> ".")
        "blocked"
        packageId
        [ DiagnosticEvidence "targetLoader" loader False
        , DiagnosticEvidence "packageLoaders" (Text.intercalate "," compatibleLoaders) False
        ]
    packageJavaDiagnostics =
      case (compatibilityPackageJavaMajor package, compatibilityTargetJavaMajor target) of
        (Just requiredMajor, Just selectedMajor)
          | selectedMajor < requiredMajor ->
              [ compatibilityDiagnostic
                  "compat_java_major_mismatch"
                  (compatibilityPackageName package <> " requires Java " <> Text.pack (show requiredMajor) <> ".")
                  "blocked"
                  packageId
                  [ DiagnosticEvidence "selectedJavaMajor" (Text.pack (show selectedMajor)) False
                  , DiagnosticEvidence "requiredJavaMajor" (Text.pack (show requiredMajor)) False
                  ]
              ]
        _ -> []
    dependencyDiagnostics =
      [ compatibilityDiagnostic
          "compat_required_dependency_missing"
          (compatibilityPackageName package <> " requires missing dependency " <> dependency <> ".")
          "blocked"
          packageId
          [ DiagnosticEvidence "dependency" dependency False
          , DiagnosticEvidence "packageId" (compatibilityPackageId package) False
          ]
      | dependency <- compatibilityPackageRequiredDependencies package
      , normalizePackageId dependency `notElem` normalizedInstalledIds
      ]
    optionalDependencyDiagnostics =
      [ compatibilityDiagnostic
          "compat_optional_dependency_missing"
          (compatibilityPackageName package <> " can use optional dependency " <> dependency <> ".")
          "warning"
          packageId
          [ DiagnosticEvidence "dependency" dependency False
          , DiagnosticEvidence "packageId" (compatibilityPackageId package) False
          ]
      | dependency <- compatibilityPackageOptionalDependencies package
      , normalizePackageId dependency `notElem` normalizedInstalledIds
      ]
    shaderPackageDiagnostics =
      case normalizePackageId (compatibilityPackageId package) of
        "iris"
          | normalizedTargetLoader target `notElem` map Just ["fabric", "quilt"] ->
              [shaderPackageDiagnostic "iris" "Fabric or Quilt"]
        "oculus"
          | normalizedTargetLoader target `notElem` map Just ["forge", "neoforge"] ->
              [shaderPackageDiagnostic "oculus" "Forge or NeoForge"]
        _ -> []
    shaderPackageDiagnostic shader expectedLoader =
      compatibilityDiagnostic
        "compat_shader_loader_mismatch"
        (shader <> " requires " <> expectedLoader <> ".")
        "blocked"
        packageId
        [ DiagnosticEvidence "packageId" (compatibilityPackageId package) False
        , DiagnosticEvidence "loader" (fromMaybe "vanilla" (normalizedTargetLoader target)) False
        ]
    compatibleVersions = filter (not . Text.null) (compatibilityPackageMinecraftVersions package)
    compatibleLoaders = sort (nub (map normalizeLoader (compatibilityPackageLoaders package)))
    normalizedInstalledIds = map normalizePackageId installedIds <> packageIdentityTexts [package | compatibilityPackagePresent package]

compatibilityDiagnostic :: Text -> Text -> Text -> Maybe Text -> [DiagnosticEvidence] -> Diagnostic
compatibilityDiagnostic code message severity maybePackageId evidence =
  (diagnosticFromBlockedReason "compatibility" "compatibility evaluate" (code <> ":" <> message))
    { diagnosticCode = code
    , diagnosticPhase = "compatibility"
    , diagnosticSeverity = diagnosticSeverityFor severity
    , diagnosticMessage = message
    , diagnosticCause = message
    , diagnosticAction = actionForCompatibilityCode code
    , diagnosticSource = "compatibility"
    , diagnosticPackageId = maybePackageId
    , diagnosticEvidence = sortOn diagnosticEvidenceKeyForCompatibility evidence
    }

diagnosticEvidenceKeyForCompatibility :: DiagnosticEvidence -> Text
diagnosticEvidenceKeyForCompatibility evidence =
  Text.intercalate
    "|"
    [ diagnosticEvidenceKey evidence
    , diagnosticEvidenceValue evidence
    , if diagnosticEvidenceRedacted evidence then "redacted" else "visible"
    ]

packageIdentityTexts :: [CompatibilityPackageInput] -> [Text]
packageIdentityTexts packages =
  sort $
    nub $
      filter
        (not . Text.null)
        ( concatMap
            (\package -> map normalizePackageId (catMaybes [Just (compatibilityPackageId package), Just (compatibilityPackageName package)]))
            packages
        )

normalizeLoader :: Text -> Text
normalizeLoader value =
  case normalizeToken value of
    "none" -> "vanilla"
    "original" -> "vanilla"
    "neoforge" -> "neoforge"
    "neo_forge" -> "neoforge"
    "neo-forge" -> "neoforge"
    other -> other

normalizeArch :: Text -> Text
normalizeArch value =
  case normalizeToken value of
    "arm64" -> "aarch64"
    "x86_64" -> "x64"
    "amd64" -> "x64"
    other -> other

normalizePackageId :: Text -> Text
normalizePackageId =
  normalizeToken . Text.replace ".jar" ""

normalizeToken :: Text -> Text
normalizeToken =
  Text.toLower . Text.strip

normalizedTargetLoader :: CompatibilityTarget -> Maybe Text
normalizedTargetLoader target =
  case normalizeLoader <$> compatibilityTargetLoader target of
    Just "vanilla" -> Nothing
    Just "" -> Nothing
    other -> other

diagnosticSeverityFor :: Text -> Text
diagnosticSeverityFor severity =
  case Text.toLower severity of
    "blocked" -> "error"
    "unknown" -> "warning"
    "warning" -> "warning"
    "info" -> "info"
    other -> other

actionForCompatibilityCode :: Text -> DiagnosticAction
actionForCompatibilityCode code =
  case code of
    "compat_minecraft_version_mismatch" -> action "switchVersion" "Switch Minecraft version"
    "compat_loader_family_mismatch" -> action "switchLoader" "Switch loader"
    "compat_shader_loader_mismatch" -> action "switchLoader" "Switch shader or loader"
    "compat_java_major_mismatch" -> action "installJava" "Install matching Java"
    "compat_java_arch_mismatch" -> action "installJava" "Install matching Java"
    "compat_required_dependency_missing" -> action "repairInstance" "Install required dependency"
    "compat_optional_dependency_missing" -> action "openDiagnostics" "Review optional dependency"
    "compat_optifine_modern_performance_risk" -> action "manualInstall" "Review performance mods"
    "compat_metadata_unknown" -> action "openDiagnostics" "Inspect local metadata"
    _ -> action "openDiagnostics" "Open diagnostics"
  where
    action kind label =
      DiagnosticAction
        { diagnosticActionKind = kind
        , diagnosticActionLabel = label
        , diagnosticActionTarget = Nothing
        , diagnosticActionPayload = Nothing
        }

modernPerformanceIds :: [Text]
modernPerformanceIds =
  [ "sodium"
  , "iris"
  , "lithium"
  , "starlight"
  , "indium"
  , "embeddium"
  , "oculus"
  , "modernfix"
  ]
