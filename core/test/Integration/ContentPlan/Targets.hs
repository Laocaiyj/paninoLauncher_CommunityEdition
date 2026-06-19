{-# LANGUAGE OverloadedStrings #-}

module Integration.ContentPlan.Targets
  ( assertContentTargetResolution
  ) where

import Panino.Api.Routes.Content.Targets (resolveContentTargets)
import Panino.Api.Types
  ( ContentResolveTargetsRequest(..)
  , ContentResolveTargetsResponse(..)
  , ContentTargetCandidate(..)
  , ContentTargetInstance(..)
  )
import TestSupport (assertEqual)

assertContentTargetResolution :: IO ()
assertContentTargetResolution = do
  let vanilla =
        ContentTargetInstance
          (Just "vanilla")
          "Vanilla"
          "/tmp/panino-content-targets/vanilla"
          "1.21.7"
          Nothing
      fabric =
        ContentTargetInstance
          (Just "fabric")
          "Fabric"
          "/tmp/panino-content-targets/fabric"
          "1.21.7"
          (Just "fabric")
      forge =
        ContentTargetInstance
          (Just "forge")
          "Forge"
          "/tmp/panino-content-targets/forge"
          "1.21.7"
          (Just "forge")
      targetRequest targetSubdir loaders instances =
        ContentResolveTargetsRequest
          { contentResolveProjectType = "resourcePack"
          , contentResolveProjectTitle = "Test content"
          , contentResolveReleaseId = Just "release"
          , contentResolveTargetSubdir = targetSubdir
          , contentResolveGameVersions = ["1.21.7"]
          , contentResolveLoaders = loaders
          , contentResolveInstances = instances
          }
      resourceResponse = resolveContentTargets (targetRequest "resourcepacks" ["fabric"] [vanilla])
      irisShaderResponse = resolveContentTargets (targetRequest "shaderpacks" ["iris"] [vanilla, fabric, forge])
      metadataFreeShaderResponse = resolveContentTargets (targetRequest "shaderpacks" [] [vanilla])
      modResponse = resolveContentTargets (targetRequest "mods" ["fabric"] [vanilla, fabric])
      blockedFor name response =
        concat
          [ contentCandidateBlockedReasons candidate
          | candidate <- contentResolveCandidates response
          , contentCandidateName candidate == name
          ]
  assertEqual
    "resource pack target resolution ignores loader mismatch"
    (Just [])
    (contentCandidateBlockedReasons <$> contentResolveRecommended resourceResponse)
  assertEqual
    "Iris shader pack recommends Fabric ecosystem target"
    (Just (Just "fabric"))
    (contentCandidateLoader <$> contentResolveRecommended irisShaderResponse)
  assertEqual
    "Iris shader pack still rejects unrelated Vanilla target"
    True
    ("shader_loader_mismatch" `elem` blockedFor "Vanilla" irisShaderResponse)
  assertEqual
    "shader pack without loader metadata remains installable for review"
    (Just [])
    (contentCandidateBlockedReasons <$> contentResolveRecommended metadataFreeShaderResponse)
  assertEqual
    "mod target resolution keeps loader mismatch blocking"
    True
    ("loader_mismatch" `elem` blockedFor "Vanilla" modResponse)
