{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Content.InstallPlan.Typed
  ( contentTypedInstallPlan
  ) where

import Data.List
  ( find
  , isPrefixOf
  )
import Data.Maybe
  ( fromMaybe
  , isNothing
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Routes.Content.Common
  ( contentDependencyKey
  , contentFileKey
  , isAllowedContentUrl
  , isCurseForgeRequest
  , normalizeLookupText
  , shortContentHash
  )
import Panino.Api.Types
  ( ContentInstallDependency(..)
  , ContentInstallFile(..)
  , ContentInstallPlanFile(..)
  , ContentInstallRequest(..)
  )
import Panino.CoreLogic.Determinism (stableSortPackages)
import qualified Panino.Install.Plan.Types as Plan

contentTypedInstallPlan :: ContentInstallRequest -> FilePath -> [ContentInstallFile] -> [ContentInstallPlanFile] -> [ContentInstallDependency] -> [Text] -> [Text] -> Plan.TypedInstallPlan
contentTypedInstallPlan request targetDir sourceFiles plannedFiles dependencies warnings blockedReasons =
  Plan.finalizeTypedInstallPlan
    Plan.TypedInstallPlan
      { Plan.typedPlanId = ""
      , Plan.typedPlanFingerprint = ""
      , Plan.typedPlanKind = "content"
      , Plan.typedPlanTitle = contentInstallProjectTitle request
      , Plan.typedPlanTargetGameDir = contentInstallGameDir request
      , Plan.typedPlanSource = Just (contentInstallSource request)
      , Plan.typedPlanStatus = ""
      , Plan.typedPlanSummary = Plan.InstallPlanSummary 0 0 0 0 0 Nothing
      , Plan.typedPlanNodes = dependencyNodes <> fileNodes
      , Plan.typedPlanEdges = dependencyEdges
      , Plan.typedPlanWarnings = warnings
      , Plan.typedPlanBlockedReasons = blockedReasons
      , Plan.typedPlanDiagnostics = []
      , Plan.typedPlanRollbackPolicy = "automatic"
      }
  where
    pairs = stableSortPackages contentPlanPairKey (zip sourceFiles plannedFiles)
    primaryFileKeys = map contentFileKey (contentInstallFiles request)
    primaryFileIds =
      [ contentFileNodeId plannedFile
      | (sourceFile, plannedFile) <- pairs
      , contentFileKey sourceFile `elem` primaryFileKeys
      ]
    requiredDependencyIds =
      [ contentDependencyNodeId dependency
      | dependency <- stableSortPackages contentDependencyKey dependencies
      , contentDependencyRequired dependency
      ]
    fileNodes =
      [ contentFileTypedNode request targetDir (contentFileKey sourceFile `elem` primaryFileKeys) sourceFile plannedFile requiredDependencyIds
      | (sourceFile, plannedFile) <- pairs
      ]
    dependencyNodes =
      [ contentDependencyTypedNode request pairs dependency
      | dependency <- stableSortPackages contentDependencyKey dependencies
      ]
    dependencyEdges =
      [ Plan.InstallPlanEdge
          { Plan.installEdgeFrom = requiredDependencyId
          , Plan.installEdgeTo = primaryFileId
          , Plan.installEdgeKind = "requires"
          , Plan.installEdgeRequired = True
          }
      | requiredDependencyId <- requiredDependencyIds
      , primaryFileId <- primaryFileIds
      ]

contentFileTypedNode :: ContentInstallRequest -> FilePath -> Bool -> ContentInstallFile -> ContentInstallPlanFile -> [Text] -> Plan.InstallPlanNode
contentFileTypedNode request targetDir isPrimaryFile sourceFile plannedFile requiredDependencyIds =
  Plan.InstallPlanNode
    { Plan.installNodeId = contentFileNodeId plannedFile
    , Plan.installNodeKind = contentKindForTargetSubdir (contentInstallTargetSubdir request)
    , Plan.installNodeAction = contentPlanFileAction plannedFile
    , Plan.installNodePhase = "content"
    , Plan.installNodeLabel = contentPlanFileName plannedFile
    , Plan.installNodeTargetPath = Just (contentPlanTargetPath plannedFile)
    , Plan.installNodeSourceUrls = [contentFileUrl sourceFile | contentPlanFileAction plannedFile /= "keep"]
    , Plan.installNodeSha1 = contentPlanFileSha1 plannedFile
    , Plan.installNodeSize = contentPlanFileSize plannedFile
    , Plan.installNodeRequired = True
    , Plan.installNodeDependsOn =
        if isPrimaryFile
          then requiredDependencyIds
          else []
    , Plan.installNodeVerifications = contentFileVerifications targetDir sourceFile plannedFile
    , Plan.installNodeRollback = contentFileRollback plannedFile
    , Plan.installNodeBlockedReason = contentFileBlockedReason sourceFile plannedFile
    , Plan.installNodeDiagnostics = []
    }

contentDependencyTypedNode :: ContentInstallRequest -> [(ContentInstallFile, ContentInstallPlanFile)] -> ContentInstallDependency -> Plan.InstallPlanNode
contentDependencyTypedNode request pairs dependency =
  Plan.InstallPlanNode
    { Plan.installNodeId = contentDependencyNodeId dependency
    , Plan.installNodeKind = "mod"
    , Plan.installNodeAction = dependencyNodeAction
    , Plan.installNodePhase = "dependencies"
    , Plan.installNodeLabel = contentDependencyName dependency
    , Plan.installNodeTargetPath = contentPlanTargetPath <$> matchingPlannedFile
    , Plan.installNodeSourceUrls = []
    , Plan.installNodeSha1 = contentDependencySha1 dependency
    , Plan.installNodeSize = matchingPlannedFile >>= contentPlanFileSize
    , Plan.installNodeRequired = contentDependencyRequired dependency
    , Plan.installNodeDependsOn = []
    , Plan.installNodeVerifications =
        [ Plan.InstallVerification
            "dependencyResolved"
            dependencyVerificationStatus
            dependencyVerificationMessage
        ]
    , Plan.installNodeRollback =
        Plan.InstallPlanRollbackAction
          { Plan.installRollbackAction = "noneWithReason"
          , Plan.installRollbackTargetPath = contentPlanTargetPath <$> matchingPlannedFile
          , Plan.installRollbackBackupPath = Nothing
          , Plan.installRollbackReason = Just "Dependency nodes describe ordering; file nodes own writes and rollback."
          }
    , Plan.installNodeBlockedReason = dependencyBlockedReason
    , Plan.installNodeDiagnostics = []
    }
  where
    matchingPlannedFile =
      snd <$> find (dependencyMatchesPlannedFile dependency) pairs
    dependencyNodeAction
      | contentDependencyInstalled dependency == Just True = "keep"
      | contentDependencyRequired dependency = "verify"
      | otherwise = "skip"
    dependencyVerificationStatus
      | contentDependencyInstalled dependency == Just True = "ok"
      | contentDependencyRequired dependency = "error"
      | otherwise = "warning"
    dependencyVerificationMessage
      | contentDependencyInstalled dependency == Just True = Nothing
      | contentDependencyRequired dependency = Just "Required dependency is not resolved."
      | otherwise = Just "Optional dependency is not resolved; it will not block install."
    dependencyBlockedReason
      | not (contentDependencyRequired dependency) = Nothing
      | contentDependencyInstalled dependency == Just True = Nothing
      | isCurseForgeRequest request = Just "curseforge_required_dependency_unresolved"
      | contentDependencyInstalled dependency == Just False = Just "missing_required_dependency"
      | otherwise = Just "required_dependency_unresolved"

contentPlanPairKey :: (ContentInstallFile, ContentInstallPlanFile) -> Text
contentPlanPairKey (sourceFile, plannedFile) =
  Text.intercalate
    "|"
    [ contentFileKey sourceFile
    , contentPlanFileName plannedFile
    , Text.pack (contentPlanTargetPath plannedFile)
    , fromMaybe "" (contentPlanFileSha1 plannedFile)
    ]

dependencyMatchesPlannedFile :: ContentInstallDependency -> (ContentInstallFile, ContentInstallPlanFile) -> Bool
dependencyMatchesPlannedFile dependency (sourceFile, plannedFile) =
  maybe False ((==) (Text.toLower <$> contentDependencySha1 dependency) . Just . Text.toLower) (contentFileSha1 sourceFile)
    || maybe False ((`Text.isInfixOf` normalizeLookupText (contentPlanFileName plannedFile)) . normalizeLookupText) (contentDependencyProjectId dependency)
    || normalizeLookupText (contentDependencyName dependency) `Text.isInfixOf` normalizeLookupText (contentPlanFileName plannedFile)

contentFileVerifications :: FilePath -> ContentInstallFile -> ContentInstallPlanFile -> [Plan.InstallVerification]
contentFileVerifications targetDir sourceFile plannedFile =
  [ Plan.InstallVerification
      "targetInsideGameDir"
      (if targetDir `isPrefixOf` contentPlanTargetPath plannedFile then "ok" else "error")
      Nothing
  , Plan.InstallVerification
      "urlAllowed"
      (if contentPlanFileAction plannedFile == "keep" || isAllowedContentUrl (contentFileUrl sourceFile) then "ok" else "error")
      Nothing
  , Plan.InstallVerification
      "hashKnown"
      (if isNothing (contentPlanFileSha1 plannedFile) then "warning" else "ok")
      Nothing
  , Plan.InstallVerification
      "sizeKnown"
      (if isNothing (contentPlanFileSize plannedFile) then "warning" else "ok")
      Nothing
  , Plan.InstallVerification
      "existingFileMatched"
      (if contentPlanFileAction plannedFile == "keep" then "ok" else "pending")
      Nothing
  , Plan.InstallVerification
      "backupWritable"
      (if contentPlanFileAction plannedFile == "replace" then "pending" else "ok")
      Nothing
  ]

contentFileRollback :: ContentInstallPlanFile -> Plan.InstallPlanRollbackAction
contentFileRollback plannedFile
  | contentPlanFileAction plannedFile == "replace" =
      Plan.InstallPlanRollbackAction
        { Plan.installRollbackAction = "restoreBackup"
        , Plan.installRollbackTargetPath = Just (contentPlanTargetPath plannedFile)
        , Plan.installRollbackBackupPath = Just (contentPlanTargetPath plannedFile <> ".panino-backup")
        , Plan.installRollbackReason = Nothing
        }
  | contentPlanFileAction plannedFile == "download" =
      Plan.InstallPlanRollbackAction
        { Plan.installRollbackAction = "removeCreatedFile"
        , Plan.installRollbackTargetPath = Just (contentPlanTargetPath plannedFile)
        , Plan.installRollbackBackupPath = Nothing
        , Plan.installRollbackReason = Nothing
        }
  | otherwise =
      Plan.InstallPlanRollbackAction
        { Plan.installRollbackAction = "noneWithReason"
        , Plan.installRollbackTargetPath = Just (contentPlanTargetPath plannedFile)
        , Plan.installRollbackBackupPath = Nothing
        , Plan.installRollbackReason = Just "Existing matching file is kept."
        }

contentFileBlockedReason :: ContentInstallFile -> ContentInstallPlanFile -> Maybe Text
contentFileBlockedReason sourceFile plannedFile
  | contentPlanFileAction plannedFile /= "keep" && not (isAllowedContentUrl (contentFileUrl sourceFile)) = Just "file_url_not_http"
  | otherwise = Nothing

contentKindForTargetSubdir :: Text -> Text
contentKindForTargetSubdir "mods" = "mod"
contentKindForTargetSubdir "resourcepacks" = "resourcePack"
contentKindForTargetSubdir "shaderpacks" = "shaderPack"
contentKindForTargetSubdir _ = "overrideFile"

contentFileNodeId :: ContentInstallPlanFile -> Text
contentFileNodeId plannedFile =
  "content-file-" <> shortContentHash (Text.pack (contentPlanTargetPath plannedFile))

contentDependencyNodeId :: ContentInstallDependency -> Text
contentDependencyNodeId dependency =
  "content-dependency-" <> shortContentHash (contentDependencyKey dependency)
