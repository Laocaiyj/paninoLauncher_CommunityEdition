{-# LANGUAGE OverloadedStrings #-}

module Integration.ContentPlan.Update
  ( assertContentUpdatePlan
  ) where

import qualified Panino.Api.Routes.Content as ContentRoutes
import Panino.Api.Types
  ( ContentInstallDependency(..)
  , ContentUpdateLockEntry(..)
  , ContentUpdatePlanRequest(..)
  , ContentUpdatePlanResource(..)
  , ContentUpdatePlanResponse(..)
  )
import Panino.Install.Plan.Types
  ( InstallPlanNode(..)
  , TypedInstallPlan(..)
  )
import TestSupport (assertEqual)

assertContentUpdatePlan :: IO ()
assertContentUpdatePlan = do
  let requiredDependency =
        ContentInstallDependency
          { contentDependencyProjectId = Just "fabric-api"
          , contentDependencyVersionId = Just "dep-version"
          , contentDependencySource = Just "modrinth"
          , contentDependencyName = "Fabric API"
          , contentDependencyRequired = True
          , contentDependencyInstalled = Just True
          , contentDependencySha1 = Just "depsha"
          }
      updateResource =
        ContentUpdatePlanResource
          { updateResourceProjectId = Just "sodium"
          , updateResourceProjectTitle = "Sodium"
          , updateResourceCurrentReleaseId = Just "old-release"
          , updateResourceCurrentFileName = "sodium-old.jar"
          , updateResourceCurrentSha1 = Just "oldsha"
          , updateResourceCurrentTargetPath = "/tmp/mc/mods/sodium.jar"
          , updateResourceRemoteReleaseId = Just "new-release"
          , updateResourceRemoteFileName = Just "sodium-new.jar"
          , updateResourceRemoteUrl = Just "https://cdn.modrinth.com/sodium-new.jar"
          , updateResourceRemoteSha1 = Just "newsha"
          , updateResourceRemoteSize = Just 42
          , updateResourceSelected = Just True
          , updateResourceDependencies = [requiredDependency]
          }
      removeCandidate =
        ContentUpdatePlanResource
          { updateResourceProjectId = Just "old-mod"
          , updateResourceProjectTitle = "Old Mod"
          , updateResourceCurrentReleaseId = Just "gone-release"
          , updateResourceCurrentFileName = "old-mod.jar"
          , updateResourceCurrentSha1 = Just "oldmodsha"
          , updateResourceCurrentTargetPath = "/tmp/mc/mods/old-mod.jar"
          , updateResourceRemoteReleaseId = Nothing
          , updateResourceRemoteFileName = Nothing
          , updateResourceRemoteUrl = Nothing
          , updateResourceRemoteSha1 = Nothing
          , updateResourceRemoteSize = Nothing
          , updateResourceSelected = Just True
          , updateResourceDependencies = []
          }
      ignoredResource =
        updateResource
          { updateResourceProjectId = Just "ignored"
          , updateResourceProjectTitle = "Ignored"
          , updateResourceCurrentTargetPath = "/tmp/mc/mods/ignored.jar"
          , updateResourceSelected = Just False
          }
      updateRequest =
        ContentUpdatePlanRequest
          { updatePlanMode = "updateSelected"
          , updatePlanGameDir = "/tmp/mc"
          , updatePlanSource = "modrinth"
          , updatePlanResources = [updateResource, removeCandidate, ignoredResource]
          }
      updateResponse = ContentRoutes.resolveContentUpdatePlan updateRequest
      updateResponseShuffled =
        ContentRoutes.resolveContentUpdatePlan
          updateRequest { updatePlanResources = [ignoredResource, removeCandidate, updateResource] }
      updatePlan = contentUpdateTypedPlan updateResponse
      nodeActions =
        [ (installNodeLabel node, installNodeAction node)
        | node <- typedPlanNodes updatePlan
        ]
      lockEntries = contentUpdateLockEntries updateResponse
  assertEqual "update plan action" "update" (contentUpdateAction updateResponse)
  assertEqual "update plan includes replace node" True (("Sodium", "replace") `elem` nodeActions)
  assertEqual "update plan includes remove candidate" True (("Old Mod", "removeCandidate") `elem` nodeActions)
  assertEqual "update plan does not auto-include unselected resource" False (any ((== "Ignored") . fst) nodeActions)
  assertEqual "update plan includes dependency node and edge" True (any ((== "Fabric API") . installNodeLabel) (typedPlanNodes updatePlan) && not (null (typedPlanEdges updatePlan)))
  assertEqual "update lockfile records old and new sha" [(Just "oldsha", Just "newsha", Just "new-release")] (map (\entry -> (updateLockOldSha1 entry, updateLockNewSha1 entry, updateLockNewReleaseId entry)) lockEntries)
  assertEqual "update plan ignores selected resource input order" (typedPlanFingerprint updatePlan) (typedPlanFingerprint (contentUpdateTypedPlan updateResponseShuffled))
  assertEqual "update lock entries ignore selected resource input order" lockEntries (contentUpdateLockEntries updateResponseShuffled)

  let badResource =
        updateResource
          { updateResourceRemoteSha1 = Nothing
          }
      badResponse =
        ContentRoutes.resolveContentUpdatePlan
          updateRequest { updatePlanResources = [badResource] }
  assertEqual "update plan blocks missing remote sha" "blocked" (contentUpdateAction badResponse)
  assertEqual "update plan reports missing sha" True ("update_sha1_missing" `elem` contentUpdateBlockedReasons badResponse)
