{-# LANGUAGE OverloadedStrings #-}

module Panino.Install.Plan.Types
  ( InstallPlanEdge(..)
  , InstallPlanNode(..)
  , InstallPlanRollbackAction(..)
  , InstallPlanSummary(..)
  , InstallVerification(..)
  , TypedInstallPlan(..)
  , finalizeTypedInstallPlan
  , installPlanFingerprint
  , summarizeInstallPlanNodes
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Aeson.Types ((.!=))
import Data.Int (Int64)
import Data.Maybe
  ( fromMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.CoreLogic.Determinism
  ( stableFingerprint
  , stableSortDiagnostics
  , stableSortPlanEdges
  , stableSortPlanNodes
  , stableTextSet
  )
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , DiagnosticAction(..)
  )

data TypedInstallPlan = TypedInstallPlan
  { typedPlanId :: Text
  , typedPlanFingerprint :: Text
  , typedPlanKind :: Text
  , typedPlanTitle :: Text
  , typedPlanTargetGameDir :: Maybe FilePath
  , typedPlanSource :: Maybe Text
  , typedPlanStatus :: Text
  , typedPlanSummary :: InstallPlanSummary
  , typedPlanNodes :: [InstallPlanNode]
  , typedPlanEdges :: [InstallPlanEdge]
  , typedPlanWarnings :: [Text]
  , typedPlanBlockedReasons :: [Text]
  , typedPlanDiagnostics :: [Diagnostic]
  , typedPlanRollbackPolicy :: Text
  } deriving (Eq, Show)

instance ToJSON TypedInstallPlan where
  toJSON plan =
    object
      [ "planId" .= typedPlanId plan
      , "fingerprint" .= typedPlanFingerprint plan
      , "planKind" .= typedPlanKind plan
      , "title" .= typedPlanTitle plan
      , "targetGameDir" .= typedPlanTargetGameDir plan
      , "source" .= typedPlanSource plan
      , "status" .= typedPlanStatus plan
      , "summary" .= typedPlanSummary plan
      , "nodes" .= typedPlanNodes plan
      , "edges" .= typedPlanEdges plan
      , "warnings" .= typedPlanWarnings plan
      , "blockedReasons" .= typedPlanBlockedReasons plan
      , "diagnostics" .= typedPlanDiagnostics plan
      , "rollbackPolicy" .= typedPlanRollbackPolicy plan
      ]

instance FromJSON TypedInstallPlan where
  parseJSON =
    withObject "TypedInstallPlan" $ \obj ->
      TypedInstallPlan
        <$> obj .:? "planId" .!= ""
        <*> obj .:? "fingerprint" .!= ""
        <*> obj .: "planKind"
        <*> obj .:? "title" .!= ""
        <*> obj .:? "targetGameDir"
        <*> obj .:? "source"
        <*> obj .:? "status" .!= "ready"
        <*> obj .:? "summary" .!= emptyInstallPlanSummary
        <*> obj .:? "nodes" .!= []
        <*> obj .:? "edges" .!= []
        <*> obj .:? "warnings" .!= []
        <*> obj .:? "blockedReasons" .!= []
        <*> obj .:? "diagnostics" .!= []
        <*> obj .:? "rollbackPolicy" .!= "none"

data InstallPlanSummary = InstallPlanSummary
  { installSummaryTotalNodes :: Int
  , installSummaryDownloadNodes :: Int
  , installSummaryKeepNodes :: Int
  , installSummaryReplaceNodes :: Int
  , installSummaryWriteNodes :: Int
  , installSummaryEstimatedBytes :: Maybe Int64
  } deriving (Eq, Show)

instance ToJSON InstallPlanSummary where
  toJSON summary =
    object
      [ "totalNodes" .= installSummaryTotalNodes summary
      , "downloadNodes" .= installSummaryDownloadNodes summary
      , "keepNodes" .= installSummaryKeepNodes summary
      , "replaceNodes" .= installSummaryReplaceNodes summary
      , "writeNodes" .= installSummaryWriteNodes summary
      , "estimatedBytes" .= installSummaryEstimatedBytes summary
      ]

instance FromJSON InstallPlanSummary where
  parseJSON =
    withObject "InstallPlanSummary" $ \obj ->
      InstallPlanSummary
        <$> obj .:? "totalNodes" .!= 0
        <*> obj .:? "downloadNodes" .!= 0
        <*> obj .:? "keepNodes" .!= 0
        <*> obj .:? "replaceNodes" .!= 0
        <*> obj .:? "writeNodes" .!= 0
        <*> obj .:? "estimatedBytes"

data InstallPlanNode = InstallPlanNode
  { installNodeId :: Text
  , installNodeKind :: Text
  , installNodeAction :: Text
  , installNodePhase :: Text
  , installNodeLabel :: Text
  , installNodeTargetPath :: Maybe FilePath
  , installNodeSourceUrls :: [Text]
  , installNodeSha1 :: Maybe Text
  , installNodeSize :: Maybe Int64
  , installNodeRequired :: Bool
  , installNodeDependsOn :: [Text]
  , installNodeVerifications :: [InstallVerification]
  , installNodeRollback :: InstallPlanRollbackAction
  , installNodeBlockedReason :: Maybe Text
  , installNodeDiagnostics :: [Diagnostic]
  } deriving (Eq, Show)

instance ToJSON InstallPlanNode where
  toJSON node =
    object
      [ "id" .= installNodeId node
      , "kind" .= installNodeKind node
      , "action" .= installNodeAction node
      , "phase" .= installNodePhase node
      , "label" .= installNodeLabel node
      , "targetPath" .= installNodeTargetPath node
      , "sourceUrls" .= installNodeSourceUrls node
      , "sha1" .= installNodeSha1 node
      , "size" .= installNodeSize node
      , "required" .= installNodeRequired node
      , "dependsOn" .= installNodeDependsOn node
      , "verifications" .= installNodeVerifications node
      , "rollback" .= installNodeRollback node
      , "blockedReason" .= installNodeBlockedReason node
      , "diagnostics" .= installNodeDiagnostics node
      ]

instance FromJSON InstallPlanNode where
  parseJSON =
    withObject "InstallPlanNode" $ \obj ->
      InstallPlanNode
        <$> obj .: "id"
        <*> obj .: "kind"
        <*> obj .: "action"
        <*> obj .:? "phase" .!= "download"
        <*> obj .:? "label" .!= ""
        <*> obj .:? "targetPath"
        <*> obj .:? "sourceUrls" .!= []
        <*> obj .:? "sha1"
        <*> obj .:? "size"
        <*> obj .:? "required" .!= True
        <*> obj .:? "dependsOn" .!= []
        <*> obj .:? "verifications" .!= []
        <*> obj .:? "rollback" .!= noRollback
        <*> obj .:? "blockedReason"
        <*> obj .:? "diagnostics" .!= []

data InstallPlanEdge = InstallPlanEdge
  { installEdgeFrom :: Text
  , installEdgeTo :: Text
  , installEdgeKind :: Text
  , installEdgeRequired :: Bool
  } deriving (Eq, Show)

instance ToJSON InstallPlanEdge where
  toJSON edge =
    object
      [ "from" .= installEdgeFrom edge
      , "to" .= installEdgeTo edge
      , "kind" .= installEdgeKind edge
      , "required" .= installEdgeRequired edge
      ]

instance FromJSON InstallPlanEdge where
  parseJSON =
    withObject "InstallPlanEdge" $ \obj ->
      InstallPlanEdge
        <$> obj .: "from"
        <*> obj .: "to"
        <*> obj .:? "kind" .!= "dependsOn"
        <*> obj .:? "required" .!= True

data InstallVerification = InstallVerification
  { installVerificationKind :: Text
  , installVerificationStatus :: Text
  , installVerificationMessage :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON InstallVerification where
  toJSON verification =
    object
      [ "kind" .= installVerificationKind verification
      , "status" .= installVerificationStatus verification
      , "message" .= installVerificationMessage verification
      ]

instance FromJSON InstallVerification where
  parseJSON =
    withObject "InstallVerification" $ \obj ->
      InstallVerification
        <$> obj .: "kind"
        <*> obj .:? "status" .!= "pending"
        <*> obj .:? "message"

data InstallPlanRollbackAction = InstallPlanRollbackAction
  { installRollbackAction :: Text
  , installRollbackTargetPath :: Maybe FilePath
  , installRollbackBackupPath :: Maybe FilePath
  , installRollbackReason :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON InstallPlanRollbackAction where
  toJSON rollback =
    object
      [ "action" .= installRollbackAction rollback
      , "targetPath" .= installRollbackTargetPath rollback
      , "backupPath" .= installRollbackBackupPath rollback
      , "reason" .= installRollbackReason rollback
      ]

instance FromJSON InstallPlanRollbackAction where
  parseJSON =
    withObject "InstallPlanRollbackAction" $ \obj ->
      InstallPlanRollbackAction
        <$> obj .:? "action" .!= "noneWithReason"
        <*> obj .:? "targetPath"
        <*> obj .:? "backupPath"
        <*> obj .:? "reason"

finalizeTypedInstallPlan :: TypedInstallPlan -> TypedInstallPlan
finalizeTypedInstallPlan plan =
  let nodes = stableSortPlanNodes nodeFingerprint (normalizeNode <$> typedPlanNodes plan)
      edges = stableSortPlanEdges edgeFingerprint (normalizeEdge <$> typedPlanEdges plan)
      nodeBlockedReasons = mapMaybe installNodeBlockedReason nodes
      blockedReasons = stableTextSet (typedPlanBlockedReasons plan <> nodeBlockedReasons)
      diagnostics =
        stableDiagnostics
          ( typedPlanDiagnostics plan
              <> concatMap installNodeDiagnostics nodes
              <> map (diagnosticFromBlockedReason "plan" (typedPlanKind plan)) blockedReasons
          )
      status =
        if not (null blockedReasons)
          then "blocked"
          else if Text.null (typedPlanStatus plan)
            then "ready"
            else typedPlanStatus plan
      summary = summarizeInstallPlanNodes nodes
      staged =
        plan
          { typedPlanId = ""
          , typedPlanFingerprint = ""
          , typedPlanStatus = status
          , typedPlanSummary = summary
          , typedPlanNodes = nodes
          , typedPlanEdges = edges
          , typedPlanWarnings = stableTextSet (typedPlanWarnings plan)
          , typedPlanBlockedReasons = blockedReasons
          , typedPlanDiagnostics = diagnostics
          }
      fingerprint = installPlanFingerprint staged
   in staged
        { typedPlanFingerprint = fingerprint
        , typedPlanId = typedPlanKind staged <> "-" <> Text.take 16 fingerprint
        }

installPlanFingerprint :: TypedInstallPlan -> Text
installPlanFingerprint plan =
  stableFingerprint $
    object
      [ "fingerprintVersion" .= ("typed-plan-v1" :: Text)
      , "kind" .= typedPlanKind plan
      , "target" .= Text.pack (fromMaybe "" (typedPlanTargetGameDir plan))
      , "source" .= fromMaybe "" (typedPlanSource plan)
      , "rollbackPolicy" .= typedPlanRollbackPolicy plan
      , "status" .= typedPlanStatus plan
      , "warnings" .= stableTextSet (typedPlanWarnings plan)
      , "blockedReasons" .= stableTextSet (typedPlanBlockedReasons plan)
      , "diagnostics" .= map diagnosticFingerprint (stableDiagnostics (typedPlanDiagnostics plan))
      , "nodes" .= map nodeFingerprint (stableSortPlanNodes nodeFingerprint (typedPlanNodes plan))
      , "edges" .= map edgeFingerprint (stableSortPlanEdges edgeFingerprint (typedPlanEdges plan))
      ]

summarizeInstallPlanNodes :: [InstallPlanNode] -> InstallPlanSummary
summarizeInstallPlanNodes nodes =
  InstallPlanSummary
    { installSummaryTotalNodes = length nodes
    , installSummaryDownloadNodes = countAction "download"
    , installSummaryKeepNodes = countAction "keep"
    , installSummaryReplaceNodes = countAction "replace"
    , installSummaryWriteNodes = length (filter ((`elem` ["write", "extract", "patch", "delete"]) . installNodeAction) nodes)
    , installSummaryEstimatedBytes =
        let sizes = mapMaybe installNodeSize (filter ((== "download") . installNodeAction) nodes)
         in if null sizes then Nothing else Just (sum sizes)
    }
  where
    countAction action =
      length (filter ((== action) . installNodeAction) nodes)

emptyInstallPlanSummary :: InstallPlanSummary
emptyInstallPlanSummary =
  InstallPlanSummary
    { installSummaryTotalNodes = 0
    , installSummaryDownloadNodes = 0
    , installSummaryKeepNodes = 0
    , installSummaryReplaceNodes = 0
    , installSummaryWriteNodes = 0
    , installSummaryEstimatedBytes = Nothing
    }

noRollback :: InstallPlanRollbackAction
noRollback =
  InstallPlanRollbackAction
    { installRollbackAction = "noneWithReason"
    , installRollbackTargetPath = Nothing
    , installRollbackBackupPath = Nothing
    , installRollbackReason = Just "No write has happened for this node."
    }

normalizeNode :: InstallPlanNode -> InstallPlanNode
normalizeNode node =
  node
    { installNodeDependsOn = stableTextSet (installNodeDependsOn node)
    , installNodeSourceUrls = stableTextSet (installNodeSourceUrls node)
    , installNodeVerifications = stableSortPlanNodes verificationFingerprint (installNodeVerifications node)
    , installNodeDiagnostics = stableDiagnostics (installNodeDiagnostics node)
    }

normalizeEdge :: InstallPlanEdge -> InstallPlanEdge
normalizeEdge = id

nodeFingerprint :: InstallPlanNode -> Text
nodeFingerprint node =
  Text.intercalate
    "|"
    [ installNodeId node
    , installNodeKind node
    , installNodeAction node
    , installNodePhase node
    , installNodeLabel node
    , Text.pack (fromMaybe "" (installNodeTargetPath node))
    , Text.intercalate "," (stableTextSet (installNodeSourceUrls node))
    , fromMaybe "" (installNodeSha1 node)
    , maybe "" (Text.pack . show) (installNodeSize node)
    , if installNodeRequired node then "required" else "optional"
    , Text.intercalate "," (stableTextSet (installNodeDependsOn node))
    , Text.intercalate "," (map verificationFingerprint (stableSortPlanNodes verificationFingerprint (installNodeVerifications node)))
    , rollbackFingerprint (installNodeRollback node)
    , fromMaybe "" (installNodeBlockedReason node)
    , Text.intercalate "," (map diagnosticFingerprint (stableDiagnostics (installNodeDiagnostics node)))
    ]

edgeFingerprint :: InstallPlanEdge -> Text
edgeFingerprint edge =
  Text.intercalate
    "|"
    [ installEdgeFrom edge
    , installEdgeTo edge
    , installEdgeKind edge
    , if installEdgeRequired edge then "required" else "optional"
    ]

verificationFingerprint :: InstallVerification -> Text
verificationFingerprint verification =
  Text.intercalate
    "|"
    [ installVerificationKind verification
    , installVerificationStatus verification
    , fromMaybe "" (installVerificationMessage verification)
    ]

rollbackFingerprint :: InstallPlanRollbackAction -> Text
rollbackFingerprint rollback =
  Text.intercalate
    "|"
    [ installRollbackAction rollback
    , Text.pack (fromMaybe "" (installRollbackTargetPath rollback))
    , Text.pack (fromMaybe "" (installRollbackBackupPath rollback))
    , fromMaybe "" (installRollbackReason rollback)
    ]

diagnosticFingerprint :: Diagnostic -> Text
diagnosticFingerprint diagnostic =
  Text.intercalate
    "|"
    [ diagnosticCode diagnostic
    , diagnosticPhase diagnostic
    , diagnosticSeverity diagnostic
    , diagnosticSource diagnostic
    , diagnosticMessage diagnostic
    , diagnosticActionKind (diagnosticAction diagnostic)
    , fromMaybe "" (diagnosticActionTarget (diagnosticAction diagnostic))
    , fromMaybe "" (diagnosticPackageId diagnostic)
    ]

stableDiagnostics :: [Diagnostic] -> [Diagnostic]
stableDiagnostics diagnostics =
  foldr insertDiagnostic [] (stableSortDiagnostics diagnosticFingerprint diagnostics)
  where
    insertDiagnostic diagnostic values
      | any ((== diagnosticFingerprint diagnostic) . diagnosticFingerprint) values = values
      | otherwise = diagnostic : values
