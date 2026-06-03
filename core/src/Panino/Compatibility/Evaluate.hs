{-# LANGUAGE OverloadedStrings #-}

module Panino.Compatibility.Evaluate
  ( compatibilityReportFromInstallPreflight
  , evaluateCompatibility
  ) where

import Data.List
  ( nub
  , sortOn
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Compatibility.Rules
  ( globalCompatibilityDiagnostics
  , packageCompatibilityDiagnostics
  )
import Panino.Compatibility.Types
  ( CompatibilityEvaluateRequest(..)
  , CompatibilityPackageInput(..)
  , CompatibilityPackageReport(..)
  , CompatibilityReport(..)
  , CompatibilityStatus(..)
  , CompatibilityTarget(..)
  )
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , DiagnosticAction(..)
  )
import Panino.Minecraft.InstallPreflight
  ( LoaderInstallPreflightResponse(..)
  )
import Panino.Runtime.Java.Types
  ( JavaRuntimeResolveResponse(..)
  )

evaluateCompatibility :: CompatibilityEvaluateRequest -> CompatibilityReport
evaluateCompatibility request =
  CompatibilityReport
    { compatibilityReportStatus = overallStatus
    , compatibilityReportTarget = compatibilityRequestTarget request
    , compatibilityReportPackageReports = packageReports
    , compatibilityReportGlobalDiagnostics = globalDiagnostics
    , compatibilityReportBlockedReasons = blockedReasonsFor allDiagnostics
    , compatibilityReportWarnings = warningMessages allDiagnostics <> compatibilityRequestWarnings request
    , compatibilityReportActions = uniqueActions allDiagnostics
    , compatibilityReportSummary = reportSummary overallStatus allDiagnostics packageReports
    }
  where
    target = compatibilityRequestTarget request
    installedIds =
      compatibilityRequestInstalledPackageIds request
        <> map compatibilityPackageId (filter compatibilityPackagePresent (compatibilityRequestPackages request))
    globalDiagnostics =
      globalCompatibilityDiagnostics request
        <> missingRequiredDiagnostics (compatibilityRequestMissingRequiredDependencies request)
        <> missingOptionalDiagnostics (compatibilityRequestMissingOptionalDependencies request)
    packageReports =
      map (packageReport target installedIds) (compatibilityRequestPackages request)
    allDiagnostics =
      globalDiagnostics <> concatMap compatibilityPackageReportDiagnostics packageReports
    overallStatus =
      statusFromDiagnostics allDiagnostics

packageReport :: CompatibilityTarget -> [Text] -> CompatibilityPackageInput -> CompatibilityPackageReport
packageReport target installedIds package =
  CompatibilityPackageReport
    { compatibilityPackageReportId = compatibilityPackageId package
    , compatibilityPackageReportName = compatibilityPackageName package
    , compatibilityPackageReportStatus = statusFromDiagnostics diagnostics
    , compatibilityPackageReportDiagnostics = diagnostics
    , compatibilityPackageReportBlockedReasons = blockedReasonsFor diagnostics
    , compatibilityPackageReportWarnings = warningMessages diagnostics
    , compatibilityPackageReportActions = uniqueActions diagnostics
    }
  where
    diagnostics = packageCompatibilityDiagnostics target installedIds package

compatibilityReportFromInstallPreflight :: LoaderInstallPreflightResponse -> CompatibilityReport
compatibilityReportFromInstallPreflight preflight =
  evaluateCompatibility
    CompatibilityEvaluateRequest
      { compatibilityRequestTarget =
          CompatibilityTarget
            { compatibilityTargetMinecraftVersion = Just (preflightResponseMinecraftVersion preflight)
            , compatibilityTargetLoader = preflightResponseLoader preflight
            , compatibilityTargetLoaderVersion = preflightResponseLoaderVersion preflight
            , compatibilityTargetShaderLoader = preflightResponseShaderLoader preflight
            , compatibilityTargetGameDir = Nothing
            , compatibilityTargetJavaMajor = Nothing
            , compatibilityTargetRequiredJavaMajor = resolveResponseRequiredMajorVersion <$> preflightResponseJavaRuntime preflight
            , compatibilityTargetJavaArch = Nothing
            , compatibilityTargetSystemArch = Nothing
            }
      , compatibilityRequestPackages = preflightPackages preflight
      , compatibilityRequestInstalledPackageIds = preflightResponseShaderProjects preflight
      , compatibilityRequestMissingRequiredDependencies = []
      , compatibilityRequestMissingOptionalDependencies = []
      , compatibilityRequestBlockedReasons = preflightResponseBlockedReasons preflight
      , compatibilityRequestWarnings = preflightResponseWarnings preflight
      }

preflightPackages :: LoaderInstallPreflightResponse -> [CompatibilityPackageInput]
preflightPackages preflight =
  loaderPackage <> shaderPackage <> dependencyPackages
  where
    loaderPackage =
      case preflightResponseLoader preflight of
        Nothing -> []
        Just loader ->
          [ CompatibilityPackageInput
              { compatibilityPackageId = loader
              , compatibilityPackageName = loader
              , compatibilityPackageSource = Just "loader"
              , compatibilityPackageKind = "loader"
              , compatibilityPackageMinecraftVersions = [preflightResponseMinecraftVersion preflight]
              , compatibilityPackageLoaders = [loader]
              , compatibilityPackageRequiredDependencies = []
              , compatibilityPackageOptionalDependencies = []
              , compatibilityPackagePresent = True
              , compatibilityPackageMetadataComplete = preflightResponseLoaderVersion preflight /= Nothing
              , compatibilityPackageJavaMajor = Nothing
              }
          ]
    shaderPackage =
      case preflightResponseShaderLoader preflight of
        Nothing -> []
        Just shader ->
          [ CompatibilityPackageInput
              { compatibilityPackageId = shader
              , compatibilityPackageName = shader
              , compatibilityPackageSource = Just "modrinth"
              , compatibilityPackageKind = "mod"
              , compatibilityPackageMinecraftVersions = [preflightResponseMinecraftVersion preflight]
              , compatibilityPackageLoaders = shaderLoaders shader
              , compatibilityPackageRequiredDependencies = preflightResponseRequiredDependencies preflight
              , compatibilityPackageOptionalDependencies = []
              , compatibilityPackagePresent = True
              , compatibilityPackageMetadataComplete = preflightResponseShaderVersion preflight /= Nothing || shader == "optifine"
              , compatibilityPackageJavaMajor = Nothing
              }
          ]
    dependencyPackages =
      [ CompatibilityPackageInput
          { compatibilityPackageId = dependency
          , compatibilityPackageName = dependency
          , compatibilityPackageSource = Just "modrinth"
          , compatibilityPackageKind = "dependency"
          , compatibilityPackageMinecraftVersions = [preflightResponseMinecraftVersion preflight]
          , compatibilityPackageLoaders = maybe [] pure (preflightResponseLoader preflight)
          , compatibilityPackageRequiredDependencies = []
          , compatibilityPackageOptionalDependencies = []
          , compatibilityPackagePresent = dependency `elem` preflightResponseShaderProjects preflight
          , compatibilityPackageMetadataComplete = True
          , compatibilityPackageJavaMajor = Nothing
          }
      | dependency <- preflightResponseRequiredDependencies preflight
      ]

shaderLoaders :: Text -> [Text]
shaderLoaders shader =
  case Text.toLower shader of
    "iris" -> ["fabric", "quilt"]
    "oculus" -> ["forge", "neoforge"]
    _ -> []

statusFromDiagnostics :: [Diagnostic] -> CompatibilityStatus
statusFromDiagnostics diagnostics
  | any isBlocked diagnostics = CompatibilityBlocked
  | any isUnknown diagnostics = CompatibilityUnknown
  | any isWarning diagnostics = CompatibilityWarning
  | otherwise = CompatibilityCompatible

isBlocked :: Diagnostic -> Bool
isBlocked diagnostic =
  diagnosticSeverity diagnostic == "error"
    || diagnosticSeverity diagnostic == terminalSeverity

terminalSeverity :: Text
terminalSeverity =
  Text.pack ['f', 'a', 't', 'a', 'l']

isWarning :: Diagnostic -> Bool
isWarning diagnostic =
  diagnosticSeverity diagnostic == "warning"

isUnknown :: Diagnostic -> Bool
isUnknown diagnostic =
  diagnosticCode diagnostic == "compat_metadata_unknown"

blockedReasonsFor :: [Diagnostic] -> [Text]
blockedReasonsFor diagnostics =
  stableUnique
    [ diagnosticCode diagnostic <> ":" <> diagnosticMessage diagnostic
    | diagnostic <- diagnostics
    , isBlocked diagnostic
    ]

warningMessages :: [Diagnostic] -> [Text]
warningMessages diagnostics =
  stableUnique
    [ diagnosticCode diagnostic <> ":" <> diagnosticMessage diagnostic
    | diagnostic <- diagnostics
    , isWarning diagnostic
    ]

uniqueActions :: [Diagnostic] -> [DiagnosticAction]
uniqueActions diagnostics =
  map snd $
    stableUniquePairs
      [ ( actionKey (diagnosticAction diagnostic)
        , diagnosticAction diagnostic
        )
      | diagnostic <- diagnostics
      ]

actionKey :: DiagnosticAction -> Text
actionKey action =
  Text.intercalate
    "|"
    [ diagnosticActionKind action
    , diagnosticActionLabel action
    , maybe "" id (diagnosticActionTarget action)
    ]

stableUnique :: [Text] -> [Text]
stableUnique =
  map snd . stableUniquePairs . map (\value -> (value, value))

stableUniquePairs :: [(Text, value)] -> [(Text, value)]
stableUniquePairs =
  sortOn fst . dedupe []
  where
    dedupe _ [] = []
    dedupe seen ((key, value):rest)
      | key `elem` seen = dedupe seen rest
      | otherwise = (key, value) : dedupe (key : seen) rest

reportSummary :: CompatibilityStatus -> [Diagnostic] -> [CompatibilityPackageReport] -> Text
reportSummary status diagnostics packageReports =
  case status of
    CompatibilityBlocked ->
      "Blocked by " <> countText (length (blockedReasonsFor diagnostics)) "compatibility issue" <> "."
    CompatibilityUnknown ->
      "Compatibility needs more local metadata before Panino can prove this pack is runnable."
    CompatibilityWarning ->
      "Compatible with " <> countText warningCount "warning" <> " to review."
    CompatibilityCompatible ->
      "Compatible. Core found no blocking compatibility issue."
  where
    warningCount = length (filter ((== CompatibilityWarning) . compatibilityPackageReportStatus) packageReports) + length (warningMessages diagnostics)

countText :: Int -> Text -> Text
countText count singular =
  Text.pack (show count) <> " " <> singular <> if count == 1 then "" else "s"

missingRequiredDiagnostics :: [Text] -> [Diagnostic]
missingRequiredDiagnostics dependencies =
  [ diagnosticFromBlockedReason "compatibility" "compatibility evaluate" ("compat_required_dependency_missing:" <> dependency)
  | dependency <- nub dependencies
  ]

missingOptionalDiagnostics :: [Text] -> [Diagnostic]
missingOptionalDiagnostics dependencies =
  [ (diagnosticFromBlockedReason "compatibility" "compatibility evaluate" ("compat_optional_dependency_missing:" <> dependency))
      { diagnosticSeverity = "warning"
      }
  | dependency <- nub dependencies
  ]
