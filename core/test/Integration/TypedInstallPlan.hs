{-# LANGUAGE OverloadedStrings #-}

module Integration.TypedInstallPlan
  ( assertTypedInstallPlanTypes
  ) where

import Data.Aeson
  ( eitherDecode
  , encode
  , toJSON
  )
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List (isInfixOf)
import Panino.CoreLogic.Determinism (canonicalJson)
import Panino.Diagnostics.Types (Diagnostic(..))
import Panino.Install.Plan.Types
  ( InstallPlanEdge(..)
  , InstallPlanNode(..)
  , InstallPlanRollbackAction(..)
  , InstallPlanSummary(..)
  , InstallVerification(..)
  , TypedInstallPlan(..)
  , finalizeTypedInstallPlan
  )
import TestSupport (assertEqual)

assertTypedInstallPlanTypes :: IO ()
assertTypedInstallPlanTypes = do
  let assetIndexNode =
        InstallPlanNode
          { installNodeId = "asset-index"
          , installNodeKind = "assetIndex"
          , installNodeAction = "download"
          , installNodePhase = "metadata"
          , installNodeLabel = "Asset index"
          , installNodeTargetPath = Just "/tmp/mc/assets/indexes/26.json"
          , installNodeSourceUrls = ["https://example.com/index.json"]
          , installNodeSha1 = Just "abc"
          , installNodeSize = Just 128
          , installNodeRequired = True
          , installNodeDependsOn = []
          , installNodeVerifications =
              [ InstallVerification "hashKnown" "ok" Nothing
              , InstallVerification "urlAllowed" "ok" Nothing
              ]
          , installNodeRollback =
              InstallPlanRollbackAction
                { installRollbackAction = "removeCreatedFile"
                , installRollbackTargetPath = Just "/tmp/mc/assets/indexes/26.json"
                , installRollbackBackupPath = Nothing
                , installRollbackReason = Nothing
                }
          , installNodeBlockedReason = Nothing
          , installNodeDiagnostics = []
          }
      assetObjectNode =
        InstallPlanNode
          { installNodeId = "asset-object"
          , installNodeKind = "assetObject"
          , installNodeAction = "download"
          , installNodePhase = "assets"
          , installNodeLabel = "Asset object"
          , installNodeTargetPath = Just "/tmp/mc/assets/objects/ab/abc"
          , installNodeSourceUrls = ["https://example.com/objects/ab/abc"]
          , installNodeSha1 = Just "abc"
          , installNodeSize = Just 256
          , installNodeRequired = True
          , installNodeDependsOn = ["asset-index"]
          , installNodeVerifications =
              [ InstallVerification "dependencyResolved" "ok" Nothing
              , InstallVerification "sizeKnown" "ok" Nothing
              ]
          , installNodeRollback =
              InstallPlanRollbackAction
                { installRollbackAction = "removeCreatedFile"
                , installRollbackTargetPath = Just "/tmp/mc/assets/objects/ab/abc"
                , installRollbackBackupPath = Nothing
                , installRollbackReason = Nothing
                }
          , installNodeBlockedReason = Nothing
          , installNodeDiagnostics = []
          }
      assetEdge =
        InstallPlanEdge
          { installEdgeFrom = "asset-index"
          , installEdgeTo = "asset-object"
          , installEdgeKind = "requires"
          , installEdgeRequired = True
          }
      optionalEdge =
        InstallPlanEdge
          { installEdgeFrom = "asset-index"
          , installEdgeTo = "asset-object"
          , installEdgeKind = "after"
          , installEdgeRequired = False
          }
      basePlan nodes =
        basePlanWithEdges nodes [assetEdge]
      basePlanWithEdges nodes edges =
        TypedInstallPlan
          { typedPlanId = ""
          , typedPlanFingerprint = ""
          , typedPlanKind = "minecraft"
          , typedPlanTitle = "Minecraft install"
          , typedPlanTargetGameDir = Just "/tmp/mc"
          , typedPlanSource = Just "official"
          , typedPlanStatus = ""
          , typedPlanSummary = InstallPlanSummary 0 0 0 0 0 Nothing
          , typedPlanNodes = nodes
          , typedPlanEdges = edges
          , typedPlanWarnings = []
          , typedPlanBlockedReasons = []
          , typedPlanDiagnostics = []
          , typedPlanRollbackPolicy = "automatic"
          }
      planA = finalizeTypedInstallPlan (basePlan [assetIndexNode, assetObjectNode])
      planB = finalizeTypedInstallPlan (basePlan [assetObjectNode, assetIndexNode])
      blockedPlan =
        finalizeTypedInstallPlan $
          basePlan
            [ assetIndexNode
                { installNodeBlockedReason = Just "missing_url"
                , installNodeSourceUrls = []
                }
            ]
      noisyPlanA =
        finalizeTypedInstallPlan
          (basePlan [assetObjectNode, assetIndexNode])
            { typedPlanWarnings = ["z-warning", "a-warning", "z-warning"]
            , typedPlanBlockedReasons = ["z-blocked", "a-blocked", "z-blocked"]
            }
      noisyPlanB =
        finalizeTypedInstallPlan
          (basePlan [assetIndexNode, assetObjectNode])
            { typedPlanWarnings = ["a-warning", "z-warning"]
            , typedPlanBlockedReasons = ["a-blocked", "z-blocked"]
            }
      edgePlanA = finalizeTypedInstallPlan (basePlanWithEdges [assetIndexNode, assetObjectNode] [optionalEdge, assetEdge])
      edgePlanB = finalizeTypedInstallPlan (basePlanWithEdges [assetObjectNode, assetIndexNode] [assetEdge, optionalEdge])
      stagedPlan = finalizeTypedInstallPlan ((basePlan [assetIndexNode]) {typedPlanStatus = "staged"})

  assertEqual "typed install plan fingerprint ignores node order" (typedPlanFingerprint planA) (typedPlanFingerprint planB)
  assertEqual "typed install plan id ignores node order" (typedPlanId planA) (typedPlanId planB)
  assertEqual "typed install plan canonical json ignores node order" (canonicalJson (toJSON planA)) (canonicalJson (toJSON planB))
  assertEqual "typed install plan fingerprint ignores edge order" (typedPlanFingerprint edgePlanA) (typedPlanFingerprint edgePlanB)
  assertEqual "typed install plan warnings are sorted and deduped" ["a-warning", "z-warning"] (typedPlanWarnings noisyPlanA)
  assertEqual "typed install plan blocked reasons are sorted and deduped" ["a-blocked", "z-blocked"] (typedPlanBlockedReasons noisyPlanA)
  assertEqual "typed install plan diagnostic order is canonical" (map diagnosticCode (typedPlanDiagnostics noisyPlanA)) (map diagnosticCode (typedPlanDiagnostics noisyPlanB))
  assertEqual "typed install plan default status" "ready" (typedPlanStatus planA)
  assertEqual "typed install plan summarizes downloads" (Just 384) (installSummaryEstimatedBytes (typedPlanSummary planA))
  assertEqual "typed install plan json roundtrips" (Right planA) (eitherDecode (encode planA))
  assertContains "typed install plan status stays a JSON string" "\"status\":\"ready\"" (BL8.unpack (encode planA))
  assertEqual "typed install plan unknown status remains typed and serializable" "staged" (typedPlanStatus stagedPlan)
  assertContains "typed install plan unknown status keeps wire string" "\"status\":\"staged\"" (BL8.unpack (encode stagedPlan))
  assertEqual "typed install plan blocked status" "blocked" (typedPlanStatus blockedPlan)
  assertEqual "typed install plan blocked reason" ["missing_url"] (typedPlanBlockedReasons blockedPlan)
  assertEqual "typed install plan blocked diagnostic" True (not (null (typedPlanDiagnostics blockedPlan)))

assertContains :: String -> String -> String -> IO ()
assertContains label expected actual =
  assertEqual label True (expected `isInfixOf` actual)
