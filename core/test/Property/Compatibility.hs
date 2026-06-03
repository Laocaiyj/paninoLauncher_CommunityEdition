{-# LANGUAGE OverloadedStrings #-}

module Property.Compatibility
  ( prop_blockedReportHasCauseAndAction
  , prop_compatibilityJsonRoundtrip
  , prop_javaMajorBelowRequirementBlocks
  , prop_loaderMismatchBlocks
  ) where

import Data.Aeson
  ( decode
  , encode
  )
import qualified Data.Text as Text
import Panino.Compatibility.Evaluate (evaluateCompatibility)
import Panino.Compatibility.Types
  ( CompatibilityEvaluateRequest(..)
  , CompatibilityPackageInput(..)
  , CompatibilityReport
  , CompatibilityStatus(..)
  , CompatibilityTarget(..)
  , compatibilityReportGlobalDiagnostics
  , compatibilityReportPackageReports
  , compatibilityReportStatus
  , compatibilityPackageReportDiagnostics
  )
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , DiagnosticAction(..)
  )
import Property.Generators
  ( genCompatibilityRequest
  )
import Test.QuickCheck
  ( Property
  , forAll
  , property
  , (===)
  )

prop_blockedReportHasCauseAndAction :: Property
prop_blockedReportHasCauseAndAction =
  let report = evaluateCompatibility javaBlockedRequest
      diagnostics = allReportDiagnostics report
   in property $
        compatibilityReportStatus report == CompatibilityBlocked
          && not (null diagnostics)
          && all hasCauseAndAction diagnostics

prop_javaMajorBelowRequirementBlocks :: Property
prop_javaMajorBelowRequirementBlocks =
  property (compatibilityReportStatus (evaluateCompatibility javaBlockedRequest) == CompatibilityBlocked)

prop_loaderMismatchBlocks :: Property
prop_loaderMismatchBlocks =
  property (compatibilityReportStatus (evaluateCompatibility loaderBlockedRequest) == CompatibilityBlocked)

prop_compatibilityJsonRoundtrip :: Property
prop_compatibilityJsonRoundtrip =
  forAll genCompatibilityRequest $ \request ->
    let report = evaluateCompatibility request
     in decode (encode report) === Just (report :: CompatibilityReport)

hasCauseAndAction :: Diagnostic -> Bool
hasCauseAndAction diagnostic =
  not (Text.null (diagnosticCause diagnostic))
    && not (Text.null (diagnosticActionKind (diagnosticAction diagnostic)))

allReportDiagnostics :: CompatibilityReport -> [Diagnostic]
allReportDiagnostics report =
  compatibilityReportGlobalDiagnostics report
    <> concatMap compatibilityPackageReportDiagnostics (compatibilityReportPackageReports report)

javaBlockedRequest :: CompatibilityEvaluateRequest
javaBlockedRequest =
  CompatibilityEvaluateRequest
    { compatibilityRequestTarget =
        CompatibilityTarget
          { compatibilityTargetMinecraftVersion = Just "1.21.7"
          , compatibilityTargetLoader = Just "fabric"
          , compatibilityTargetLoaderVersion = Nothing
          , compatibilityTargetShaderLoader = Nothing
          , compatibilityTargetGameDir = Just "/tmp/panino-test"
          , compatibilityTargetJavaMajor = Just 17
          , compatibilityTargetRequiredJavaMajor = Just 21
          , compatibilityTargetJavaArch = Just "aarch64"
          , compatibilityTargetSystemArch = Just "aarch64"
          }
    , compatibilityRequestPackages = []
    , compatibilityRequestInstalledPackageIds = []
    , compatibilityRequestMissingRequiredDependencies = []
    , compatibilityRequestMissingOptionalDependencies = []
    , compatibilityRequestBlockedReasons = []
    , compatibilityRequestWarnings = []
    }

loaderBlockedRequest :: CompatibilityEvaluateRequest
loaderBlockedRequest =
  javaBlockedRequest
    { compatibilityRequestTarget =
        (compatibilityRequestTarget javaBlockedRequest)
          { compatibilityTargetJavaMajor = Just 21
          , compatibilityTargetRequiredJavaMajor = Just 21
          , compatibilityTargetLoader = Just "forge"
          }
    , compatibilityRequestPackages =
        [ CompatibilityPackageInput
            { compatibilityPackageId = "iris"
            , compatibilityPackageName = "Iris"
            , compatibilityPackageSource = Just "modrinth"
            , compatibilityPackageKind = "mod"
            , compatibilityPackageMinecraftVersions = ["1.21.7"]
            , compatibilityPackageLoaders = ["fabric", "quilt"]
            , compatibilityPackageRequiredDependencies = []
            , compatibilityPackageOptionalDependencies = []
            , compatibilityPackagePresent = True
            , compatibilityPackageMetadataComplete = True
            , compatibilityPackageJavaMajor = Nothing
            }
        ]
    , compatibilityRequestInstalledPackageIds = ["iris"]
    }
