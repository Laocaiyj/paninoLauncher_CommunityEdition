{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.InstallPreflight.Plan
  ( preflightTypedPlan
  ) where

import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Diagnostics.Types (Diagnostic)
import qualified Panino.Install.Plan.Types as Plan
import Panino.Minecraft.InstallPreflight.Checks
  ( LoaderPreflightCheck(..)
  , ShaderPreflightCheck(..)
  , normalizedOptionalLoader
  , normalizedOptionalShader
  )
import Panino.Minecraft.InstallPreflight.Types (LoaderInstallPreflightRequest(..))

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
