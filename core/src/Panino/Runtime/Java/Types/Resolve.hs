{-# LANGUAGE OverloadedStrings #-}

module Panino.Runtime.Java.Types.Resolve
  ( JavaRuntimeRequirement(..)
  , JavaRuntimeResolveRequest(..)
  , JavaRuntimeResolveResponse(..)
  ) where

import Control.Applicative ((<|>))
import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Core.Types
  ( GameDir
  , VersionId
  , versionIdText
  )
import qualified Panino.Install.Plan.Types as Plan
import Panino.Runtime.Java.Types.Catalog (JavaRuntimeDownloadSpec(..))

data JavaRuntimeRequirement = JavaRuntimeRequirement
  { javaRequirementMinecraftVersion :: VersionId
  , javaRequirementMajorVersion :: Int
  , javaRequirementComponent :: Maybe Text
  , javaRequirementSource :: Text
  } deriving (Eq, Show)

instance ToJSON JavaRuntimeRequirement where
  toJSON requirement =
    object
      [ "minecraftVersion" .= javaRequirementMinecraftVersion requirement
      , "majorVersion" .= javaRequirementMajorVersion requirement
      , "component" .= javaRequirementComponent requirement
      , "source" .= javaRequirementSource requirement
      ]

data JavaRuntimeResolveRequest = JavaRuntimeResolveRequest
  { resolveMinecraftVersion :: VersionId
  , resolveGameDir :: Maybe GameDir
  , resolveInstanceId :: Maybe Text
  , resolvePolicy :: Maybe Text
  , resolvePreferredRuntimeId :: Maybe Text
  , resolveCustomPath :: Maybe FilePath
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeResolveRequest where
  parseJSON =
    withObject "JavaRuntimeResolveRequest" $ \obj ->
      JavaRuntimeResolveRequest
        <$> (obj .: "minecraftVersion" <|> obj .: "version")
        <*> obj .:? "gameDir"
        <*> obj .:? "instanceId"
        <*> obj .:? "policy"
        <*> obj .:? "preferredRuntimeId"
        <*> (obj .:? "customPath" <|> obj .:? "java")

data JavaRuntimeResolveResponse = JavaRuntimeResolveResponse
  { resolveResponseMinecraftVersion :: VersionId
  , resolveResponseRequiredMajorVersion :: Int
  , resolveResponseRequirementSource :: Text
  , resolveResponsePolicy :: Text
  , resolveResponseStatus :: Text
  , resolveResponseSelectedRuntimeId :: Maybe Text
  , resolveResponseJavaExecutable :: Maybe FilePath
  , resolveResponseDownload :: Maybe JavaRuntimeDownloadSpec
  , resolveResponseActions :: [Text]
  , resolveResponseWarnings :: [Text]
  , resolveResponseBlockingReasons :: [Text]
  } deriving (Eq, Show)

instance ToJSON JavaRuntimeResolveResponse where
  toJSON response =
    object
      [ "minecraftVersion" .= resolveResponseMinecraftVersion response
      , "requiredMajorVersion" .= resolveResponseRequiredMajorVersion response
      , "source" .= resolveResponseRequirementSource response
      , "policy" .= resolveResponsePolicy response
      , "status" .= resolveResponseStatus response
      , "selectedRuntimeId" .= resolveResponseSelectedRuntimeId response
      , "javaExecutable" .= resolveResponseJavaExecutable response
      , "download" .= resolveResponseDownload response
      , "actions" .= resolveResponseActions response
      , "warnings" .= resolveResponseWarnings response
      , "blockingReasons" .= resolveResponseBlockingReasons response
      , "typedPlan" .= javaRuntimeTypedPlan response
      ]

javaRuntimeTypedPlan :: JavaRuntimeResolveResponse -> Plan.TypedInstallPlan
javaRuntimeTypedPlan response =
  Plan.finalizeTypedInstallPlan
    Plan.TypedInstallPlan
      { Plan.typedPlanId = ""
      , Plan.typedPlanFingerprint = ""
      , Plan.typedPlanKind = "javaRuntime"
      , Plan.typedPlanTitle = "Java runtime plan"
      , Plan.typedPlanTargetGameDir = Nothing
      , Plan.typedPlanSource = Just "java"
      , Plan.typedPlanStatus = ""
      , Plan.typedPlanSummary = Plan.InstallPlanSummary (length nodes) downloadCount keepCount 0 writeCount Nothing
      , Plan.typedPlanNodes = nodes
      , Plan.typedPlanEdges = edges
      , Plan.typedPlanWarnings = resolveResponseWarnings response
      , Plan.typedPlanBlockedReasons = resolveResponseBlockingReasons response
      , Plan.typedPlanDiagnostics = []
      , Plan.typedPlanRollbackPolicy = "runtime-store-cleanup"
      }
  where
    nodes = requirementNode : downloadNodes <> selectNodes
    downloadNodes =
      case resolveResponseDownload response of
        Nothing -> []
        Just spec ->
          [ Plan.InstallPlanNode
              { Plan.installNodeId = "java-download"
              , Plan.installNodeKind = "javaRuntime"
              , Plan.installNodeAction = "download"
              , Plan.installNodePhase = "runtime"
              , Plan.installNodeLabel = "Download Java " <> Text.pack (show (runtimeDownloadFeatureVersion spec))
              , Plan.installNodeTargetPath = Nothing
              , Plan.installNodeSourceUrls = Plan.installNodeSourceUrlsFromTexts [runtimeDownloadUrl spec]
              , Plan.installNodeSha1 = Nothing
              , Plan.installNodeSize = Nothing
              , Plan.installNodeRequired = True
              , Plan.installNodeDependsOn = ["java-requirement"]
              , Plan.installNodeVerifications =
                  [ Plan.InstallVerification "sha256" (maybe "warning" (const "ok") (runtimeDownloadSha256 spec)) (runtimeDownloadSha256 spec)
                  ]
              , Plan.installNodeRollback =
                  Plan.InstallPlanRollbackAction
                    { Plan.installRollbackAction = "runtimeStoreCleanup"
                    , Plan.installRollbackTargetPath = Nothing
                    , Plan.installRollbackBackupPath = Nothing
                    , Plan.installRollbackReason = Just "Managed Java runtime files are owned by the runtime store cleanup task."
                    }
              , Plan.installNodeBlockedReason = Nothing
              , Plan.installNodeDiagnostics = []
              }
          ]
    selectNodes =
      case resolveResponseSelectedRuntimeId response of
        Nothing -> []
        Just runtimeId ->
          [ Plan.InstallPlanNode
              { Plan.installNodeId = "java-select"
              , Plan.installNodeKind = "javaRuntimeSelection"
              , Plan.installNodeAction = "keep"
              , Plan.installNodePhase = "runtime"
              , Plan.installNodeLabel = "Use Java runtime " <> runtimeId
              , Plan.installNodeTargetPath = resolveResponseJavaExecutable response
              , Plan.installNodeSourceUrls = []
              , Plan.installNodeSha1 = Nothing
              , Plan.installNodeSize = Nothing
              , Plan.installNodeRequired = True
              , Plan.installNodeDependsOn = ["java-requirement"]
              , Plan.installNodeVerifications = [Plan.InstallVerification "javaCompatible" "ok" (Just runtimeId)]
              , Plan.installNodeRollback = javaNoRollback
              , Plan.installNodeBlockedReason = Nothing
              , Plan.installNodeDiagnostics = []
              }
          ]
    requirementNode =
      Plan.InstallPlanNode
        { Plan.installNodeId = "java-requirement"
        , Plan.installNodeKind = "javaRuntimeRequirement"
        , Plan.installNodeAction = "verify"
        , Plan.installNodePhase = "runtime"
              , Plan.installNodeLabel =
                  "Java "
                    <> Text.pack (show (resolveResponseRequiredMajorVersion response))
                    <> " for Minecraft "
                    <> versionIdText (resolveResponseMinecraftVersion response)
        , Plan.installNodeTargetPath = Nothing
        , Plan.installNodeSourceUrls = []
        , Plan.installNodeSha1 = Nothing
        , Plan.installNodeSize = Nothing
        , Plan.installNodeRequired = True
        , Plan.installNodeDependsOn = []
        , Plan.installNodeVerifications =
            [ Plan.InstallVerification
                "javaRequirement"
                (if null (resolveResponseBlockingReasons response) then "ok" else "error")
                (Just (resolveResponseRequirementSource response))
            ]
        , Plan.installNodeRollback = javaNoRollback
        , Plan.installNodeBlockedReason = listToMaybe (resolveResponseBlockingReasons response)
        , Plan.installNodeDiagnostics = []
        }
    edges =
      [ Plan.InstallPlanEdge "java-requirement" "java-download" "requires" True
      | not (null downloadNodes)
      ]
        <> [ Plan.InstallPlanEdge "java-requirement" "java-select" "requires" True
           | not (null selectNodes)
           ]
    downloadCount = length downloadNodes
    keepCount = length selectNodes
    writeCount = 0

javaNoRollback :: Plan.InstallPlanRollbackAction
javaNoRollback =
  Plan.InstallPlanRollbackAction
    { Plan.installRollbackAction = "none"
    , Plan.installRollbackTargetPath = Nothing
    , Plan.installRollbackBackupPath = Nothing
    , Plan.installRollbackReason = Nothing
    }
