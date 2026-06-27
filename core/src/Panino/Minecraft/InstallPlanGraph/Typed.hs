{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.InstallPlanGraph.Typed
  ( combineTypedPlans
  , compactTypedPlanFromLegacyNodes
  , hashText
  , installPlanGraphKey
  , installPlanNodeKey
  , maxFullInstallPlanGraphEdges
  , maxFullInstallPlanGraphNodes
  , typedPlanFromLegacyNodes
  , typedPlanFromTypedNodes
  ) where

import qualified Crypto.Hash.SHA1 as SHA1
import qualified Data.ByteString.Char8 as BS8
import Data.Foldable (foldl')
import Data.Int (Int64)
import Data.Maybe
  ( fromMaybe
  , isNothing
  , listToMaybe
  )
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric (showHex)
import Panino.CoreLogic.Determinism
  ( stableSortPlanEdges
  , stableSortPlanNodes
  , stableTextSet
  )
import qualified Panino.Install.Plan.Types as Plan
import Panino.Minecraft.InstallPlanGraph.Types
  ( InstallPlanGraph(..)
  , InstallPlanNode(..)
  )

maxFullInstallPlanGraphNodes :: Int
maxFullInstallPlanGraphNodes = 512

maxFullInstallPlanGraphEdges :: Int
maxFullInstallPlanGraphEdges = 1024

installPlanGraphKey :: InstallPlanGraph -> Text
installPlanGraphKey graph =
  Text.intercalate
    "|"
    [ installPlanGraphKind graph
    , installPlanGraphLabel graph
    , installPlanGraphId graph
    , Plan.typedPlanFingerprint (installPlanGraphTypedPlan graph)
    ]

installPlanNodeKey :: InstallPlanNode -> Text
installPlanNodeKey node =
  Text.intercalate
    "|"
    [ installPlanNodePhase node
    , installPlanNodeKind node
    , installPlanNodeTargetPathText node
    , fromMaybe "" (installPlanNodeSha1 node)
    , installPlanNodeId node
    ]

installPlanNodeTargetPathText :: InstallPlanNode -> Text
installPlanNodeTargetPathText =
  Text.pack . installPlanNodeTargetPath

hashText :: String -> Text
hashText =
  Text.pack . concatMap hexByte . BS8.unpack . SHA1.hash . BS8.pack

hexByte :: Char -> String
hexByte char =
  let value = fromEnum char
      rendered = showHex value ""
   in if value < 16 then '0' : rendered else rendered

typedPlanFromLegacyNodes :: Text -> Text -> [InstallPlanNode] -> [Text] -> [Text] -> Plan.TypedInstallPlan
typedPlanFromLegacyNodes kind label nodes warnings blocked =
  typedPlanFromTypedNodes
    kind
    label
    (map typedNodeFromLegacy nodes)
    (dependencyEdgesFromLegacy nodes)
    warnings
    blocked

compactTypedPlanFromLegacyNodes :: Text -> Text -> [InstallPlanNode] -> [Text] -> [Text] -> Plan.TypedInstallPlan
compactTypedPlanFromLegacyNodes kind label nodes warnings blocked =
  finalized
    { Plan.typedPlanSummary =
        Plan.InstallPlanSummary
          { Plan.installSummaryTotalNodes = nodeCount
          , Plan.installSummaryDownloadNodes = nodeCount
          , Plan.installSummaryKeepNodes = 0
          , Plan.installSummaryReplaceNodes = 0
          , Plan.installSummaryWriteNodes = 0
          , Plan.installSummaryEstimatedBytes = estimatedBytes
          }
    }
  where
    sortedNodes = stableSortPlanNodes installPlanNodeKey nodes
    nodeCount = length sortedNodes
    estimatedBytes =
      let sizes = installPlanNodeSizes sortedNodes
       in if null sizes then Nothing else Just (sum sizes)
    aggregate = hashText (Text.unpack (Text.intercalate "\n" (map compactNodeFingerprint sortedNodes)))
    compactNode =
      Plan.InstallPlanNode
        { Plan.installNodeId = "download-batch-" <> Text.take 16 aggregate
        , Plan.installNodeKind = "downloadBatch"
        , Plan.installNodeAction = "download"
        , Plan.installNodePhase = "download"
        , Plan.installNodeLabel = label <> " (" <> Text.pack (show nodeCount) <> " files)"
        , Plan.installNodeTargetPath = Nothing
        , Plan.installNodeSourceUrls = []
        , Plan.installNodeSha1 = Plan.installNodeSha1FromText (Just aggregate)
        , Plan.installNodeSize = estimatedBytes
        , Plan.installNodeRequired = True
        , Plan.installNodeDependsOn = []
        , Plan.installNodeVerifications =
            [ Plan.InstallVerification
                "compactGraph"
                "ok"
                (Just ("Collapsed " <> Text.pack (show nodeCount) <> " download nodes into a stable aggregate plan node."))
            ]
        , Plan.installNodeRollback =
            Plan.InstallPlanRollbackAction
              { Plan.installRollbackAction = "noneWithReason"
              , Plan.installRollbackTargetPath = Nothing
              , Plan.installRollbackBackupPath = Nothing
              , Plan.installRollbackReason = Just "Large download graphs are represented as an aggregate plan node; file rollback is handled by install rollback snapshots."
              }
        , Plan.installNodeBlockedReason = listToMaybe blocked
        , Plan.installNodeDiagnostics = []
        }
    finalized = typedPlanFromTypedNodes kind label [compactNode] [] warnings blocked

combineTypedPlans :: Text -> Text -> [InstallPlanGraph] -> [Text] -> [Text] -> Plan.TypedInstallPlan
combineTypedPlans kind label graphs warnings blocked =
  typedPlanFromTypedNodes kind label nodes edges warnings blocked
  where
    plans = map installPlanGraphTypedPlan graphs
    combinedNodes = concatMap Plan.typedPlanNodes plans
    combinedEdges = concatMap Plan.typedPlanEdges plans
    (nodes, extraEdges) =
      case plans of
        basePlan:restPlans
          | kind == "minecraft-profile" ->
              let baseNodes = Plan.typedPlanNodes basePlan
                  shaderNodeIds = map Plan.installNodeId (concatMap Plan.typedPlanNodes restPlans)
                  profileIds =
                    [ Plan.installNodeId node
                    | node <- baseNodes
                    , Plan.installNodeKind node == "loaderProfile"
                    ]
                  dependencyIds =
                    case profileIds of
                      [] -> map Plan.installNodeId baseNodes
                      ids -> ids
                  shaderDependencyEdges =
                    [ Plan.InstallPlanEdge
                        { Plan.installEdgeFrom = dependencyId
                        , Plan.installEdgeTo = shaderNodeId
                        , Plan.installEdgeKind = "requires"
                        , Plan.installEdgeRequired = True
                        }
                    | shaderNodeId <- shaderNodeIds
                    , dependencyId <- dependencyIds
                    ]
                  updateNode node
                    | Plan.installNodeId node `elem` shaderNodeIds =
                        node
                          { Plan.installNodeDependsOn =
                              stableTextSet (Plan.installNodeDependsOn node <> dependencyIds)
                          }
                    | otherwise = node
               in (map updateNode combinedNodes, shaderDependencyEdges)
        _ -> (combinedNodes, [])
    edges = dedupeTypedEdges (combinedEdges <> extraEdges)

typedPlanFromTypedNodes :: Text -> Text -> [Plan.InstallPlanNode] -> [Plan.InstallPlanEdge] -> [Text] -> [Text] -> Plan.TypedInstallPlan
typedPlanFromTypedNodes kind label nodes edges warnings blocked =
  Plan.finalizeTypedInstallPlan
    Plan.TypedInstallPlan
      { Plan.typedPlanId = ""
      , Plan.typedPlanFingerprint = ""
      , Plan.typedPlanKind = kind
      , Plan.typedPlanTitle = label
      , Plan.typedPlanTargetGameDir = Nothing
      , Plan.typedPlanSource = sourceForKind kind
      , Plan.typedPlanStatus = ""
      , Plan.typedPlanSummary = Plan.InstallPlanSummary 0 0 0 0 0 Nothing
      , Plan.typedPlanNodes = nodes
      , Plan.typedPlanEdges = dedupeTypedEdges edges
      , Plan.typedPlanWarnings = warnings
      , Plan.typedPlanBlockedReasons = blocked
      , Plan.typedPlanDiagnostics = []
      , Plan.typedPlanRollbackPolicy = "automatic"
      }

typedNodeFromLegacy :: InstallPlanNode -> Plan.InstallPlanNode
typedNodeFromLegacy node =
  Plan.InstallPlanNode
    { Plan.installNodeId = installPlanNodeId node
    , Plan.installNodeKind = typedNodeKind (installPlanNodeKind node)
    , Plan.installNodeAction = "download"
    , Plan.installNodePhase = installPlanNodePhase node
    , Plan.installNodeLabel = installPlanNodeLabel node
    , Plan.installNodeTargetPath = Just (installPlanNodeTargetPath node)
    , Plan.installNodeSourceUrls = Plan.installNodeSourceUrlsFromTexts (installPlanNodeUrlCandidates node)
    , Plan.installNodeSha1 = Plan.installNodeSha1FromText (installPlanNodeSha1 node)
    , Plan.installNodeSize = installPlanNodeSize node
    , Plan.installNodeRequired = installPlanNodeRequired node
    , Plan.installNodeDependsOn = installPlanNodeDependencies node
    , Plan.installNodeVerifications = legacyNodeVerifications node
    , Plan.installNodeRollback =
        Plan.InstallPlanRollbackAction
          { Plan.installRollbackAction = "removeCreatedFile"
          , Plan.installRollbackTargetPath = Just (installPlanNodeTargetPath node)
          , Plan.installRollbackBackupPath = Nothing
          , Plan.installRollbackReason = Nothing
          }
    , Plan.installNodeBlockedReason = installPlanNodeBlockedReason node
    , Plan.installNodeDiagnostics = []
    }

typedNodeKind :: Text -> Text
typedNodeKind "asset-index" = "assetIndex"
typedNodeKind "asset-object" = "assetObject"
typedNodeKind "client-jar" = "clientJar"
typedNodeKind "loader-installer" = "loaderInstaller"
typedNodeKind other = other

legacyNodeVerifications :: InstallPlanNode -> [Plan.InstallVerification]
legacyNodeVerifications node =
  [ Plan.InstallVerification
      "targetInsideGameDir"
      "pending"
      (Just "The shared typed plan does not yet carry gameDir for this legacy graph.")
  , Plan.InstallVerification
      "urlAllowed"
      (if null (installPlanNodeUrlCandidates node) then "error" else "ok")
      Nothing
  , Plan.InstallVerification
      "hashKnown"
      (if isNothing (installPlanNodeSha1 node) then "error" else "ok")
      Nothing
  , Plan.InstallVerification
      "sizeKnown"
      (if isNothing (installPlanNodeSize node) then "warning" else "ok")
      Nothing
  , Plan.InstallVerification
      "dependencyResolved"
      "ok"
      Nothing
  ]

dependencyEdgesFromLegacy :: [InstallPlanNode] -> [Plan.InstallPlanEdge]
dependencyEdgesFromLegacy nodes =
  stableSortPlanEdges typedEdgeKey
    [ Plan.InstallPlanEdge
        { Plan.installEdgeFrom = dependency
        , Plan.installEdgeTo = installPlanNodeId node
        , Plan.installEdgeKind = "requires"
        , Plan.installEdgeRequired = installPlanNodeRequired node
        }
    | node <- nodes
    , dependency <- installPlanNodeDependencies node
    ]

dedupeTypedEdges :: [Plan.InstallPlanEdge] -> [Plan.InstallPlanEdge]
dedupeTypedEdges =
  stableSortPlanEdges typedEdgeKey . reverse . snd . foldl' insertEdge (Set.empty, [])
  where
    insertEdge (seen, edges) edge
      | key `Set.member` seen = (seen, edges)
      | otherwise = (Set.insert key seen, edge : edges)
      where
        key = typedEdgeKey edge

typedEdgeKey :: Plan.InstallPlanEdge -> Text
typedEdgeKey edge =
  Text.intercalate
    "|"
    [ Plan.installEdgeFrom edge
    , Plan.installEdgeTo edge
    , Plan.installEdgeKind edge
    , if Plan.installEdgeRequired edge then "required" else "optional"
    ]

installPlanNodeSizes :: [InstallPlanNode] -> [Int64]
installPlanNodeSizes =
  foldr collect []
  where
    collect node acc =
      case installPlanNodeSize node of
        Just size -> size : acc
        Nothing -> acc

compactNodeFingerprint :: InstallPlanNode -> Text
compactNodeFingerprint node =
  Text.intercalate
    "|"
    [ installPlanNodeId node
    , installPlanNodeKind node
    , installPlanNodeLabel node
    , installPlanNodeTargetPathText node
    , Text.intercalate "," (installPlanNodeUrlCandidates node)
    , fromMaybe "" (installPlanNodeSha1 node)
    , maybe "" (Text.pack . show) (installPlanNodeSize node)
    , Text.intercalate "," (installPlanNodeDependencies node)
    , fromMaybe "" (installPlanNodeBlockedReason node)
    ]

sourceForKind :: Text -> Maybe Text
sourceForKind "minecraft" = Just "official"
sourceForKind "minecraft-profile" = Just "official"
sourceForKind "minecraft-companion" = Just "modrinth"
sourceForKind "content" = Just "content"
sourceForKind _ = Nothing
