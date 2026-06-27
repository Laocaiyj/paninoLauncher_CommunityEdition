{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Content.UpdatePlan
  ( resolveContentUpdatePlan
  ) where

import Control.Applicative ((<|>))
import Data.Maybe (fromMaybe, isNothing)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Routes.Content.Common
import Panino.Api.Types
import Panino.CoreLogic.Determinism (stableSortPackages)
import qualified Panino.Install.Plan.Types as Plan
import System.FilePath ((</>))

resolveContentUpdatePlan :: ContentUpdatePlanRequest -> ContentUpdatePlanResponse
resolveContentUpdatePlan request =
  ContentUpdatePlanResponse
    { contentUpdateAction = if null blockedReasons then "update" else "blocked"
    , contentUpdateMode = updatePlanMode request
    , contentUpdateLockfilePath = updatePlanGameDir request </> "downloads" </> "content-update-lock.json"
    , contentUpdateLockEntries = lockEntries
    , contentUpdateWarnings = warnings
    , contentUpdateBlockedReasons = blockedReasons
    , contentUpdateTypedPlan = typedPlan
    }
  where
    selectedResources =
      stableSortPackages
        contentUpdateResourceKey
        (filter (contentUpdateResourceSelected request) (updatePlanResources request))
    rawWarnings =
      concat
        [ ["no_update_resources" | null (updatePlanResources request)]
        , ["no_update_candidates_selected" | null selectedResources && not (null (updatePlanResources request))]
        , [ "optional_update_dependency_unresolved"
          | resource <- selectedResources
          , dependency <- updateResourceDependencies resource
          , unresolvedOptionalDependency dependency
          ]
        , [ "remove_candidate_present"
          | resource <- selectedResources
          , contentUpdateResourceAction resource == "removeCandidate"
          ]
        ]
    typedPlan =
      Plan.finalizeTypedInstallPlan
        Plan.TypedInstallPlan
          { Plan.typedPlanId = ""
          , Plan.typedPlanFingerprint = ""
          , Plan.typedPlanKind = "update"
          , Plan.typedPlanTitle = "Content update"
          , Plan.typedPlanTargetGameDir = Plan.typedPlanTargetGameDirFromPath (Just (updatePlanGameDir request))
          , Plan.typedPlanSource = Just (updatePlanSource request)
          , Plan.typedPlanStatus = ""
          , Plan.typedPlanSummary = Plan.InstallPlanSummary 0 0 0 0 0 Nothing
          , Plan.typedPlanNodes = dependencyNodes <> resourceNodes
          , Plan.typedPlanEdges = dependencyEdges
          , Plan.typedPlanWarnings = rawWarnings
          , Plan.typedPlanBlockedReasons = []
          , Plan.typedPlanDiagnostics = []
          , Plan.typedPlanRollbackPolicy = "automatic"
          }
    warnings = Plan.typedPlanWarnings typedPlan
    blockedReasons = Plan.typedPlanBlockedReasons typedPlan
    resourceNodes = map contentUpdateResourceNode selectedResources
    dependencyNodes =
      [ contentUpdateDependencyNode resource dependency
      | resource <- selectedResources
      , dependency <- stableSortPackages contentDependencyKey (updateResourceDependencies resource)
      ]
    dependencyEdges =
      [ Plan.InstallPlanEdge
          { Plan.installEdgeFrom = contentUpdateDependencyNodeId resource dependency
          , Plan.installEdgeTo = contentUpdateResourceNodeId resource
          , Plan.installEdgeKind = "requires"
          , Plan.installEdgeRequired = True
          }
      | resource <- selectedResources
      , dependency <- stableSortPackages contentDependencyKey (updateResourceDependencies resource)
      , contentDependencyRequired dependency
      ]
    lockEntries =
      stableSortPackages contentUpdateLockEntryKey
        [ ContentUpdateLockEntry
            { updateLockProjectId = updateResourceProjectId resource
            , updateLockProjectTitle = updateResourceProjectTitle resource
            , updateLockOldReleaseId = updateResourceCurrentReleaseId resource
            , updateLockNewReleaseId = updateResourceRemoteReleaseId resource
            , updateLockOldSha1 = updateResourceCurrentSha1 resource
            , updateLockNewSha1 = updateResourceRemoteSha1 resource
            , updateLockTargetPath = updateResourceCurrentTargetPath resource
            , updateLockBackupPath = Just (updateResourceCurrentTargetPath resource <> ".panino-backup")
            }
        | resource <- selectedResources
        , contentUpdateResourceAction resource `elem` ["replace", "download"]
        ]

contentUpdateResourceKey :: ContentUpdatePlanResource -> Text
contentUpdateResourceKey resource =
  Text.intercalate
    "|"
    [ Text.pack (updateResourceCurrentTargetPath resource)
    , fromMaybe "" (updateResourceProjectId resource)
    , updateResourceProjectTitle resource
    , fromMaybe "" (updateResourceRemoteReleaseId resource)
    , fromMaybe "" (updateResourceRemoteSha1 resource)
    ]

contentUpdateLockEntryKey :: ContentUpdateLockEntry -> Text
contentUpdateLockEntryKey entry =
  Text.intercalate
    "|"
    [ Text.pack (updateLockTargetPath entry)
    , fromMaybe "" (updateLockProjectId entry)
    , fromMaybe "" (updateLockNewReleaseId entry)
    , fromMaybe "" (updateLockNewSha1 entry)
    ]

contentUpdateResourceSelected :: ContentUpdatePlanRequest -> ContentUpdatePlanResource -> Bool
contentUpdateResourceSelected request resource =
  case normalizeLoader (updatePlanMode request) of
    "updateone" -> updateResourceSelected resource == Just True
    "updateselected" -> updateResourceSelected resource == Just True
    "updateallsafe" -> True
    _ -> fromMaybe True (updateResourceSelected resource)

contentUpdateResourceNode :: ContentUpdatePlanResource -> Plan.InstallPlanNode
contentUpdateResourceNode resource =
  Plan.InstallPlanNode
    { Plan.installNodeId = contentUpdateResourceNodeId resource
    , Plan.installNodeKind = "mod"
    , Plan.installNodeAction = contentUpdateResourceAction resource
    , Plan.installNodePhase = "update"
    , Plan.installNodeLabel = updateResourceProjectTitle resource
    , Plan.installNodeTargetPath = Just (updateResourceCurrentTargetPath resource)
    , Plan.installNodeSourceUrls =
        Plan.installNodeSourceUrlsFromTexts
          [ url
          | action `elem` ["replace", "download"]
          , Just url <- [updateResourceRemoteUrl resource]
          ]
    , Plan.installNodeSha1 = Plan.installNodeSha1FromText (updateResourceRemoteSha1 resource <|> updateResourceCurrentSha1 resource)
    , Plan.installNodeSize = updateResourceRemoteSize resource
    , Plan.installNodeRequired = True
    , Plan.installNodeDependsOn =
        [ contentUpdateDependencyNodeId resource dependency
        | dependency <- stableSortPackages contentDependencyKey (updateResourceDependencies resource)
        , contentDependencyRequired dependency
        ]
    , Plan.installNodeVerifications = contentUpdateResourceVerifications resource
    , Plan.installNodeRollback = contentUpdateResourceRollback resource
    , Plan.installNodeBlockedReason = contentUpdateResourceBlockedReason resource
    , Plan.installNodeDiagnostics = []
    }
  where
    action = contentUpdateResourceAction resource

contentUpdateDependencyNode :: ContentUpdatePlanResource -> ContentInstallDependency -> Plan.InstallPlanNode
contentUpdateDependencyNode resource dependency =
  Plan.InstallPlanNode
    { Plan.installNodeId = contentUpdateDependencyNodeId resource dependency
    , Plan.installNodeKind = "mod"
    , Plan.installNodeAction =
        if contentDependencyInstalled dependency == Just True
          then "keep"
          else "verify"
    , Plan.installNodePhase = "dependencies"
    , Plan.installNodeLabel = contentDependencyName dependency
    , Plan.installNodeTargetPath = Nothing
    , Plan.installNodeSourceUrls = []
    , Plan.installNodeSha1 = Plan.installNodeSha1FromText (contentDependencySha1 dependency)
    , Plan.installNodeSize = Nothing
    , Plan.installNodeRequired = contentDependencyRequired dependency
    , Plan.installNodeDependsOn = []
    , Plan.installNodeVerifications =
        [ Plan.InstallVerification
            "dependencyResolved"
            dependencyStatus
            dependencyMessage
        ]
    , Plan.installNodeRollback =
        Plan.InstallPlanRollbackAction
          { Plan.installRollbackAction = "noneWithReason"
          , Plan.installRollbackTargetPath = Nothing
          , Plan.installRollbackBackupPath = Nothing
          , Plan.installRollbackReason = Just "Update dependency nodes describe ordering; file nodes own writes."
          }
    , Plan.installNodeBlockedReason =
        if contentDependencyRequired dependency && contentDependencyInstalled dependency /= Just True
          then Just "update_required_dependency_unresolved"
          else Nothing
    , Plan.installNodeDiagnostics = []
    }
  where
    dependencyStatus
      | contentDependencyInstalled dependency == Just True = "ok"
      | contentDependencyRequired dependency = "error"
      | otherwise = "warning"
    dependencyMessage
      | contentDependencyInstalled dependency == Just True = Nothing
      | contentDependencyRequired dependency = Just ("Required dependency for " <> updateResourceProjectTitle resource <> " is unresolved.")
      | otherwise = Just "Optional update dependency is unresolved."

contentUpdateResourceAction :: ContentUpdatePlanResource -> Text
contentUpdateResourceAction resource
  | isNothing (updateResourceRemoteReleaseId resource) = "removeCandidate"
  | isNothing (updateResourceCurrentReleaseId resource) = "download"
  | updateResourceRemoteSha1 resource /= Nothing
      && updateResourceRemoteSha1 resource == updateResourceCurrentSha1 resource = "keep"
  | otherwise = "replace"

contentUpdateResourceVerifications :: ContentUpdatePlanResource -> [Plan.InstallVerification]
contentUpdateResourceVerifications resource =
  [ Plan.InstallVerification "targetInsideGameDir" "pending" Nothing
  , Plan.InstallVerification
      "urlAllowed"
      (if action `elem` ["replace", "download"] && maybe True (not . isAllowedContentUrl) (updateResourceRemoteUrl resource) then "error" else "ok")
      Nothing
  , Plan.InstallVerification
      "hashKnown"
      (if action `elem` ["replace", "download"] && isNothing (updateResourceRemoteSha1 resource) then "error" else "ok")
      Nothing
  , Plan.InstallVerification
      "existingFileMatched"
      (if isNothing (updateResourceCurrentSha1 resource) then "warning" else "pending")
      (updateResourceCurrentSha1 resource)
  , Plan.InstallVerification
      "backupWritable"
      (if action == "replace" then "pending" else "ok")
      Nothing
  ]
  where
    action = contentUpdateResourceAction resource

contentUpdateResourceRollback :: ContentUpdatePlanResource -> Plan.InstallPlanRollbackAction
contentUpdateResourceRollback resource
  | contentUpdateResourceAction resource == "replace" =
      Plan.InstallPlanRollbackAction
        { Plan.installRollbackAction = "restoreBackup"
        , Plan.installRollbackTargetPath = Just (updateResourceCurrentTargetPath resource)
        , Plan.installRollbackBackupPath = Just (updateResourceCurrentTargetPath resource <> ".panino-backup")
        , Plan.installRollbackReason = Nothing
        }
  | contentUpdateResourceAction resource == "download" =
      Plan.InstallPlanRollbackAction
        { Plan.installRollbackAction = "removeCreatedFile"
        , Plan.installRollbackTargetPath = Just (updateResourceCurrentTargetPath resource)
        , Plan.installRollbackBackupPath = Nothing
        , Plan.installRollbackReason = Nothing
        }
  | otherwise =
      Plan.InstallPlanRollbackAction
        { Plan.installRollbackAction = "noneWithReason"
        , Plan.installRollbackTargetPath = Just (updateResourceCurrentTargetPath resource)
        , Plan.installRollbackBackupPath = Nothing
        , Plan.installRollbackReason = Just "Update plan will not modify this file."
        }

contentUpdateResourceBlockedReason :: ContentUpdatePlanResource -> Maybe Text
contentUpdateResourceBlockedReason resource
  | action `elem` ["replace", "download"] && maybe True (not . isAllowedContentUrl) (updateResourceRemoteUrl resource) = Just "update_download_url_missing"
  | action `elem` ["replace", "download"] && isNothing (updateResourceRemoteSha1 resource) = Just "update_sha1_missing"
  | otherwise = Nothing
  where
    action = contentUpdateResourceAction resource

contentUpdateResourceNodeId :: ContentUpdatePlanResource -> Text
contentUpdateResourceNodeId resource =
  "update-resource-" <> shortContentHash (Text.pack (updateResourceCurrentTargetPath resource) <> fromMaybe "" (updateResourceRemoteReleaseId resource))

contentUpdateDependencyNodeId :: ContentUpdatePlanResource -> ContentInstallDependency -> Text
contentUpdateDependencyNodeId resource dependency =
  "update-dependency-" <> shortContentHash (contentUpdateResourceNodeId resource <> contentDependencyKey dependency)
