{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Content.Targets
  ( resolveContentTargets
  ) where

import Data.List (sortOn)
import Data.Ord (Down(..))
import qualified Data.Text as Text
import Panino.Api.Routes.Content.Common
import Panino.Api.Types

resolveContentTargets :: ContentResolveTargetsRequest -> ContentResolveTargetsResponse
resolveContentTargets request =
  ContentResolveTargetsResponse
    { contentResolveCandidates = markedCandidates
    , contentResolveRecommended = recommended
    , contentResolveBlockedReasons = topLevelBlockedReasons
    }
  where
    scoredCandidates =
      sortOn (Down . contentCandidateScore) $
        map (scoreContentTargetCandidate request) (contentResolveInstances request)

    recommendedKey =
      candidateKey <$> firstViable scoredCandidates

    markedCandidates =
      [ candidate { contentCandidateRecommended = Just (candidateKey candidate) == recommendedKey }
      | candidate <- scoredCandidates
      ]

    recommended =
      case recommendedKey of
        Nothing -> Nothing
        Just key ->
          case [candidate | candidate <- markedCandidates, candidateKey candidate == key] of
            candidate:_ -> Just candidate
            [] -> Nothing

    topLevelBlockedReasons =
      concat
        [ ["no_local_instances" | null (contentResolveInstances request)]
        , ["target_subdir_not_allowed" | Text.unpack (contentResolveTargetSubdir request) `notElem` allowedContentSubdirs]
        , ["modpack_requires_import_flow" | normalizeLoader (contentResolveProjectType request) == "modpack"]
        , ["no_matching_local_instance" | not (null (contentResolveInstances request)) && recommendedKey == Nothing]
        ]

firstViable :: [ContentTargetCandidate] -> Maybe ContentTargetCandidate
firstViable [] = Nothing
firstViable (candidate:candidates)
  | null (contentCandidateBlockedReasons candidate) = Just candidate
  | otherwise = firstViable candidates

candidateKey :: ContentTargetCandidate -> String
candidateKey candidate =
  contentCandidateGameDir candidate <> "\0" <> Text.unpack (contentCandidateName candidate)

scoreContentTargetCandidate :: ContentResolveTargetsRequest -> ContentTargetInstance -> ContentTargetCandidate
scoreContentTargetCandidate request instanceValue =
  ContentTargetCandidate
    { contentCandidateInstanceId = contentTargetInstanceId instanceValue
    , contentCandidateName = contentTargetInstanceName instanceValue
    , contentCandidateGameDir = contentTargetInstanceGameDir instanceValue
    , contentCandidateMinecraftVersion = contentTargetInstanceMinecraftVersion instanceValue
    , contentCandidateLoader = contentTargetInstanceLoader instanceValue
    , contentCandidateScore = score
    , contentCandidateReasons = reasons
    , contentCandidateBlockedReasons = blockedReasons
    , contentCandidateRecommended = False
    }
  where
    targetSubdir = Text.unpack (contentResolveTargetSubdir request)
    projectType = normalizeLoader (contentResolveProjectType request)
    versionAllowed =
      null (contentResolveGameVersions request)
        || matchesAnyMinecraftVersion
          (contentResolveGameVersions request)
          (contentTargetInstanceMinecraftVersion instanceValue)
    loaderAllowed =
      contentTargetLoaderCompatible
        targetSubdir
        (contentResolveLoaders request)
        (contentTargetInstanceLoader instanceValue)
    score =
      sum
        [ if versionAllowed then 70 else 0
        , if loaderAllowed then 25 else 0
        , if not (null (contentTargetInstanceGameDir instanceValue)) then 5 else 0
        , if projectType /= "modpack" then 0 else -100
        ]
    reasons =
      concat
        [ ["minecraft_version_match" | versionAllowed]
        , ["loader_match" | loaderAllowed && targetSubdir /= "resourcepacks"]
        , ["resource_pack_version_scoped" | targetSubdir == "resourcepacks" && versionAllowed]
        ]
    blockedReasons =
      concat
        [ ["target_subdir_not_allowed" | targetSubdir `notElem` allowedContentSubdirs]
        , ["modpack_requires_import_flow" | projectType == "modpack"]
        , ["minecraft_version_mismatch" | not versionAllowed]
        , ["loader_required_for_mod" | targetSubdir == "mods" && null (contentResolveLoaders request)]
        , ["loader_mismatch" | targetSubdir == "mods" && not loaderAllowed && not (null (contentResolveLoaders request))]
        , ["shader_loader_mismatch" | targetSubdir == "shaderpacks" && not loaderAllowed]
        , ["game_dir_required" | null (contentTargetInstanceGameDir instanceValue)]
        ]
