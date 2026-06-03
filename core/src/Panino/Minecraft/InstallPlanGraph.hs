{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.InstallPlanGraph
  ( InstallPlanGraph(..)
  , InstallPlanNode(..)
  , addLoaderProfileTypedPlan
  , addInstanceMetadataTypedPlan
  , combineInstallPlanGraphs
  , dedupeInstallPlanJobs
  , downloadJobsInstallPlanGraph
  , writeInstallPlanGraph
  ) where

import qualified Crypto.Hash.SHA1 as SHA1
import Data.Aeson
  ( ToJSON(..)
  , Value
  , encode
  , object
  , (.=)
  )
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
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
  ( stableSortOnText
  , stableSortPlanEdges
  , stableSortPlanNodes
  , stableTextSet
  )
import Panino.Download.Manager (DownloadJob(..))
import qualified Panino.Install.Plan.Types as Plan
import Panino.Minecraft.InstanceMetadata (metadataPath)
import Panino.Minecraft.Layout
  ( MinecraftLayout
  , minecraftRoot
  , versionJsonPath
  )
import System.Directory (createDirectoryIfMissing)
import System.FilePath
  ( takeDirectory
  , takeFileName
  )

data InstallPlanGraph = InstallPlanGraph
  { installPlanGraphId :: Text
  , installPlanGraphKind :: Text
  , installPlanGraphLabel :: Text
  , installPlanGraphNodes :: [InstallPlanNode]
  , installPlanGraphWarnings :: [Text]
  , installPlanGraphBlockedReasons :: [Text]
  , installPlanGraphTypedPlan :: Plan.TypedInstallPlan
  } deriving (Eq, Show)

instance ToJSON InstallPlanGraph where
  toJSON =
    toJSON . installPlanGraphTypedPlan

data InstallPlanNode = InstallPlanNode
  { installPlanNodeId :: Text
  , installPlanNodeKind :: Text
  , installPlanNodeLabel :: Text
  , installPlanNodeTargetPath :: FilePath
  , installPlanNodeUrlCandidates :: [Text]
  , installPlanNodeSha1 :: Maybe Text
  , installPlanNodeSize :: Maybe Int64
  , installPlanNodeDependencies :: [Text]
  , installPlanNodePhase :: Text
  , installPlanNodeRequired :: Bool
  , installPlanNodeBlockedReason :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON InstallPlanNode where
  toJSON node =
    object
      [ "id" .= installPlanNodeId node
      , "kind" .= installPlanNodeKind node
      , "label" .= installPlanNodeLabel node
      , "targetPath" .= installPlanNodeTargetPath node
      , "urlCandidates" .= installPlanNodeUrlCandidates node
      , "sha1" .= installPlanNodeSha1 node
      , "size" .= installPlanNodeSize node
      , "dependencies" .= installPlanNodeDependencies node
      , "phase" .= installPlanNodePhase node
      , "required" .= installPlanNodeRequired node
      , "blockedReason" .= installPlanNodeBlockedReason node
      ]

downloadJobsInstallPlanGraph :: Text -> Text -> [DownloadJob] -> InstallPlanGraph
downloadJobsInstallPlanGraph kind label jobs =
  InstallPlanGraph
    { installPlanGraphId = Plan.typedPlanId typedPlan
    , installPlanGraphKind = kind
    , installPlanGraphLabel = label
    , installPlanGraphNodes = nodes
    , installPlanGraphWarnings = warnings
    , installPlanGraphBlockedReasons = blocked
    , installPlanGraphTypedPlan = typedPlan
    }
  where
    dedupedJobs = dedupeInstallPlanJobs jobs
    nodes = stableSortPlanNodes installPlanNodeKey (addImplicitDependencies (map jobNode dedupedJobs))
    warnings = duplicateWarnings jobs dedupedJobs
    blocked = blockedReasons nodes
    typedPlan =
      if length nodes > maxFullInstallPlanGraphNodes
        then compactTypedPlanFromLegacyNodes kind label nodes warnings blocked
        else typedPlanFromLegacyNodes kind label nodes warnings blocked

combineInstallPlanGraphs :: Text -> Text -> [InstallPlanGraph] -> InstallPlanGraph
combineInstallPlanGraphs kind label graphs =
  InstallPlanGraph
    { installPlanGraphId = Plan.typedPlanId typedPlan
    , installPlanGraphKind = kind
    , installPlanGraphLabel = label
    , installPlanGraphNodes = nodes
    , installPlanGraphWarnings = warnings
    , installPlanGraphBlockedReasons = blocked
    , installPlanGraphTypedPlan = typedPlan
    }
  where
    graphsForMerge =
      if kind == "minecraft-profile"
        then graphs
        else stableSortOnText installPlanGraphKey graphs
    nodes = stableSortPlanNodes installPlanNodeKey (concatMap installPlanGraphNodes graphsForMerge)
    warnings = stableTextSet (concatMap installPlanGraphWarnings graphsForMerge)
    blocked = stableTextSet (concatMap installPlanGraphBlockedReasons graphsForMerge)
    typedPlan = combineTypedPlans kind label graphsForMerge warnings blocked

addLoaderProfileTypedPlan :: MinecraftLayout -> Text -> Maybe Text -> InstallPlanGraph -> InstallPlanGraph
addLoaderProfileTypedPlan _ _ Nothing graph = graph
addLoaderProfileTypedPlan layout launchVersion (Just loaderVersion) graph =
  graph
    { installPlanGraphId = Plan.typedPlanId typedPlan
    , installPlanGraphTypedPlan = typedPlan
    }
  where
    existingPlan = installPlanGraphTypedPlan graph
    baseNodes = Plan.typedPlanNodes existingPlan
    baseNodeIds = map Plan.installNodeId baseNodes
    profileNodeId = "loader-profile-" <> hashText (Text.unpack launchVersion <> "|" <> Text.unpack loaderVersion)
    profileNode =
      Plan.InstallPlanNode
        { Plan.installNodeId = profileNodeId
        , Plan.installNodeKind = "loaderProfile"
        , Plan.installNodeAction = "write"
        , Plan.installNodePhase = "loader"
        , Plan.installNodeLabel = launchVersion
        , Plan.installNodeTargetPath = Just (versionJsonPath layout launchVersion)
        , Plan.installNodeSourceUrls = []
        , Plan.installNodeSha1 = Nothing
        , Plan.installNodeSize = Nothing
        , Plan.installNodeRequired = True
        , Plan.installNodeDependsOn = stableTextSet baseNodeIds
        , Plan.installNodeVerifications =
            [ Plan.InstallVerification "dependencyResolved" "ok" (Just "Minecraft base plan must complete before loader profile is usable.")
            , Plan.InstallVerification "loaderCompatible" "ok" (Just loaderVersion)
            ]
        , Plan.installNodeRollback =
            Plan.InstallPlanRollbackAction
              { Plan.installRollbackAction = "removeCreatedFile"
              , Plan.installRollbackTargetPath = Just (versionJsonPath layout launchVersion)
              , Plan.installRollbackBackupPath = Nothing
              , Plan.installRollbackReason = Just "Loader profile JSON is created by the profile install step and can be removed if the install aborts before metadata commit."
              }
        , Plan.installNodeBlockedReason = Nothing
        , Plan.installNodeDiagnostics = []
        }
    profileEdges =
      [ Plan.InstallPlanEdge
          { Plan.installEdgeFrom = dependency
          , Plan.installEdgeTo = profileNodeId
          , Plan.installEdgeKind = "requires"
          , Plan.installEdgeRequired = True
          }
      | dependency <- baseNodeIds
      ]
    typedPlan =
      typedPlanFromTypedNodes
        (Plan.typedPlanKind existingPlan)
        (Plan.typedPlanTitle existingPlan)
        (baseNodes <> [profileNode])
        (Plan.typedPlanEdges existingPlan <> profileEdges)
        (Plan.typedPlanWarnings existingPlan)
        (Plan.typedPlanBlockedReasons existingPlan)

addInstanceMetadataTypedPlan :: MinecraftLayout -> InstallPlanGraph -> InstallPlanGraph
addInstanceMetadataTypedPlan layout graph =
  graph
    { installPlanGraphId = Plan.typedPlanId typedPlan
    , installPlanGraphTypedPlan = typedPlan
    }
  where
    existingPlan = installPlanGraphTypedPlan graph
    baseNodes = Plan.typedPlanNodes existingPlan
    baseNodeIds = map Plan.installNodeId baseNodes
    nodeId = "instance-metadata-" <> hashText (minecraftRoot layout)
    metadataFile = metadataPath (minecraftRoot layout)
    metadataNode =
      Plan.InstallPlanNode
        { Plan.installNodeId = nodeId
        , Plan.installNodeKind = "instanceMetadata"
        , Plan.installNodeAction = "write"
        , Plan.installNodePhase = "verify"
        , Plan.installNodeLabel = ".panino/instance.json"
        , Plan.installNodeTargetPath = Just metadataFile
        , Plan.installNodeSourceUrls = []
        , Plan.installNodeSha1 = Nothing
        , Plan.installNodeSize = Nothing
        , Plan.installNodeRequired = True
        , Plan.installNodeDependsOn = stableTextSet baseNodeIds
        , Plan.installNodeVerifications =
            [ Plan.InstallVerification "postVerifyComplete" "ok" (Just "Instance metadata is committed only after post-verify succeeds.")
            ]
        , Plan.installNodeRollback =
            Plan.InstallPlanRollbackAction
              { Plan.installRollbackAction = "removeCreatedFile"
              , Plan.installRollbackTargetPath = Just metadataFile
              , Plan.installRollbackBackupPath = Nothing
              , Plan.installRollbackReason = Just "Metadata is the final commit marker and should be removed if the transaction fails."
              }
        , Plan.installNodeBlockedReason = Nothing
        , Plan.installNodeDiagnostics = []
        }
    metadataEdges =
      [ Plan.InstallPlanEdge
          { Plan.installEdgeFrom = dependency
          , Plan.installEdgeTo = nodeId
          , Plan.installEdgeKind = "requires"
          , Plan.installEdgeRequired = True
          }
      | dependency <- baseNodeIds
      ]
    typedPlan =
      typedPlanFromTypedNodes
        (Plan.typedPlanKind existingPlan)
        (Plan.typedPlanTitle existingPlan)
        (baseNodes <> [metadataNode])
        (Plan.typedPlanEdges existingPlan <> metadataEdges)
        (Plan.typedPlanWarnings existingPlan)
        (Plan.typedPlanBlockedReasons existingPlan)

dedupeInstallPlanJobs :: [DownloadJob] -> [DownloadJob]
dedupeInstallPlanJobs =
  reverse . collectedJobs . foldl' insertJob (Set.empty, Set.empty, []) . stableSortOnText jobSortKey
  where
    collectedJobs (_, _, jobs) = jobs
    insertJob (targetPaths, hashes, jobs) job
      | jobTargetPath job `Set.member` targetPaths = (targetPaths, hashes, jobs)
      | maybe False (`Set.member` hashes) (jobSha1 job) = (targetPaths, hashes, jobs)
      | otherwise =
          ( Set.insert (jobTargetPath job) targetPaths
          , maybe hashes (`Set.insert` hashes) (jobSha1 job)
          , job : jobs
          )

writeInstallPlanGraph :: FilePath -> InstallPlanGraph -> IO ()
writeInstallPlanGraph target graph = do
  createDirectoryIfMissing True (takeDirectory target)
  BL.writeFile target (encode (installPlanGraphPayload graph))

installPlanGraphPayload :: InstallPlanGraph -> Value
installPlanGraphPayload graph
  | nodeCount > maxFullInstallPlanGraphNodes || edgeCount > maxFullInstallPlanGraphEdges =
      compactInstallPlanGraphPayload graph nodeCount edgeCount
  | otherwise = toJSON graph
  where
    typedPlan = installPlanGraphTypedPlan graph
    nodeCount = length (Plan.typedPlanNodes typedPlan)
    edgeCount = length (Plan.typedPlanEdges typedPlan)

maxFullInstallPlanGraphNodes :: Int
maxFullInstallPlanGraphNodes = 512

maxFullInstallPlanGraphEdges :: Int
maxFullInstallPlanGraphEdges = 1024

compactInstallPlanGraphPayload :: InstallPlanGraph -> Int -> Int -> Value
compactInstallPlanGraphPayload graph nodeCount edgeCount =
  object
    [ "schema" .= ("panino-install-plan-graph-v1" :: Text)
    , "truncated" .= True
    , "truncationReason" .= ("large_install_plan_graph" :: Text)
    , "planId" .= Plan.typedPlanId typedPlan
    , "fingerprint" .= Plan.typedPlanFingerprint typedPlan
    , "planKind" .= Plan.typedPlanKind typedPlan
    , "title" .= Plan.typedPlanTitle typedPlan
    , "targetGameDir" .= Plan.typedPlanTargetGameDir typedPlan
    , "source" .= Plan.typedPlanSource typedPlan
    , "status" .= Plan.typedPlanStatus typedPlan
    , "summary" .= Plan.typedPlanSummary typedPlan
    , "nodeCount" .= nodeCount
    , "edgeCount" .= edgeCount
    , "warnings" .= Plan.typedPlanWarnings typedPlan
    , "blockedReasons" .= Plan.typedPlanBlockedReasons typedPlan
    , "diagnostics" .= Plan.typedPlanDiagnostics typedPlan
    , "omitted" .= object
        [ "nodes" .= nodeCount
        , "edges" .= edgeCount
        ]
    ]
  where
    typedPlan = installPlanGraphTypedPlan graph

jobNode :: DownloadJob -> InstallPlanNode
jobNode job =
  InstallPlanNode
    { installPlanNodeId = "node-" <> Text.take 16 (hashText (jobFingerprint job))
    , installPlanNodeKind = jobKind job
    , installPlanNodeLabel = Text.pack (jobLabel job)
    , installPlanNodeTargetPath = jobTargetPath job
    , installPlanNodeUrlCandidates = [Text.pack (jobUrl job)]
    , installPlanNodeSha1 = jobSha1 job
    , installPlanNodeSize = jobSize job
    , installPlanNodeDependencies = []
    , installPlanNodePhase = jobPhase job
    , installPlanNodeRequired = True
    , installPlanNodeBlockedReason = jobBlockedReason job
    }

jobBlockedReason :: DownloadJob -> Maybe Text
jobBlockedReason job
  | null (jobUrl job) = Just "missing_url"
  | isNothing (jobSha1 job) = Just "missing_sha1"
  | otherwise = Nothing

jobKind :: DownloadJob -> Text
jobKind job
  | "asset index" `Text.isPrefixOf` label = "asset-index"
  | "asset " `Text.isPrefixOf` label = "asset-object"
  | "client jar" `Text.isPrefixOf` label = "client-jar"
  | "library " `Text.isPrefixOf` label = "library"
  | "native " `Text.isPrefixOf` label = "native"
  | "installer" `Text.isInfixOf` label = "loader-installer"
  | "modrinth mod" `Text.isPrefixOf` label = "mod"
  | otherwise = "download"
  where
    label = Text.toLower (Text.pack (jobLabel job))

jobPhase :: DownloadJob -> Text
jobPhase job =
  case jobKind job of
    "asset-index" -> "metadata"
    "asset-object" -> "assets"
    "client-jar" -> "runtime"
    "library" -> "libraries"
    "native" -> "natives"
    "loader-installer" -> "loader"
    "mod" -> "content"
    _ -> "download"

blockedReasons :: [InstallPlanNode] -> [Text]
blockedReasons =
  stableTextSet . mapMaybeText installPlanNodeBlockedReason

duplicateWarnings :: [DownloadJob] -> [DownloadJob] -> [Text]
duplicateWarnings original deduped
  | length original == length deduped = []
  | otherwise =
      [ "Deduped "
          <> Text.pack (show (length original - length deduped))
          <> " duplicate plan node(s) by target path or sha1."
      ]

jobFingerprint :: DownloadJob -> String
jobFingerprint job =
  jobLabel job
    <> "|"
    <> jobUrl job
    <> "|"
    <> jobTargetPath job
    <> "|"
    <> Text.unpack (fromMaybe "" (jobSha1 job))
    <> "|"
    <> maybe "" show (jobSize job)
    <> "|"
    <> takeFileName (jobTargetPath job)

jobSortKey :: DownloadJob -> Text
jobSortKey =
  Text.pack . jobFingerprint

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

mapMaybeText :: (a -> Maybe Text) -> [a] -> [Text]
mapMaybeText selector =
  foldr collect []
  where
    collect value acc =
      case selector value of
        Just item -> item : acc
        Nothing -> acc

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

addImplicitDependencies :: [InstallPlanNode] -> [InstallPlanNode]
addImplicitDependencies nodes =
  map addDependencies nodes
  where
    assetIndexIds =
      [ installPlanNodeId node
      | node <- nodes
      , installPlanNodeKind node == "asset-index"
      ]
    addDependencies node
      | installPlanNodeKind node == "asset-object" && not (null assetIndexIds) =
          node
            { installPlanNodeDependencies =
                stableTextSet (installPlanNodeDependencies node <> assetIndexIds)
            }
      | otherwise = node

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
        , Plan.installNodeSha1 = Just aggregate
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
    , Plan.installNodeSourceUrls = installPlanNodeUrlCandidates node
    , Plan.installNodeSha1 = installPlanNodeSha1 node
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

sourceForKind :: Text -> Maybe Text
sourceForKind "minecraft" = Just "official"
sourceForKind "minecraft-profile" = Just "official"
sourceForKind "minecraft-companion" = Just "modrinth"
sourceForKind "content" = Just "content"
sourceForKind _ = Nothing
