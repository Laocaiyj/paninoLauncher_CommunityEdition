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

import Data.Aeson
  ( Value
  , encode
  , object
  , toJSON
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.Foldable (foldl')
import Data.Maybe
  ( isNothing
  )
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.CoreLogic.Determinism
  ( stableSortOnText
  , stableSortPlanNodes
  , stableTextSet
  )
import Panino.Download.Manager (DownloadJob(..))
import Panino.Core.Types
  ( sha1Text
  , urlString
  , urlText
  )
import qualified Panino.Install.Plan.Types as Plan
import Panino.Minecraft.InstallPlanGraph.Typed
  ( combineTypedPlans
  , compactTypedPlanFromLegacyNodes
  , hashText
  , installPlanGraphKey
  , installPlanNodeKey
  , maxFullInstallPlanGraphEdges
  , maxFullInstallPlanGraphNodes
  , typedPlanFromLegacyNodes
  , typedPlanFromTypedNodes
  )
import Panino.Minecraft.InstallPlanGraph.Types
  ( InstallPlanGraph(..)
  , InstallPlanNode(..)
  )
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
    , installPlanNodeUrlCandidates = [urlText (jobUrl job)]
    , installPlanNodeSha1 = sha1Text <$> jobSha1 job
    , installPlanNodeSize = jobSize job
    , installPlanNodeDependencies = []
    , installPlanNodePhase = jobPhase job
    , installPlanNodeRequired = True
    , installPlanNodeBlockedReason = jobBlockedReason job
    }

jobBlockedReason :: DownloadJob -> Maybe Text
jobBlockedReason job
  | null (urlString (jobUrl job)) = Just "missing_url"
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
    <> urlString (jobUrl job)
    <> "|"
    <> jobTargetPath job
    <> "|"
    <> Text.unpack (maybe "" sha1Text (jobSha1 job))
    <> "|"
    <> maybe "" show (jobSize job)
    <> "|"
    <> takeFileName (jobTargetPath job)

jobSortKey :: DownloadJob -> Text
jobSortKey =
  Text.pack . jobFingerprint

mapMaybeText :: (a -> Maybe Text) -> [a] -> [Text]
mapMaybeText selector =
  foldr collect []
  where
    collect value acc =
      case selector value of
        Just item -> item : acc
        Nothing -> acc

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
