{-# LANGUAGE OverloadedStrings #-}

module Panino.Runtime.Java.Types
  ( JavaManagedResponse(..)
  , JavaManagedRuntime(..)
  , JavaRuntimeCatalogItem(..)
  , JavaRuntimeCleanupResponse(..)
  , JavaRuntimeDeleteResponse(..)
  , JavaRuntimeDownloadSpec(..)
  , JavaRuntimeImportRequest(..)
  , JavaRuntimeInstallRequest(..)
  , JavaRuntimePolicyRecord(..)
  , JavaRuntimeRequirement(..)
  , JavaRuntimeResolveRequest(..)
  , JavaRuntimeResolveResponse(..)
  , JavaRuntimeSelectRequest(..)
  , JavaRuntimeSelectResponse(..)
  , JavaRuntimeVerifyRequest(..)
  ) where

import Control.Applicative ((<|>))
import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Int (Int64)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Panino.Api.Types (DownloadRuntimeOptions(..), mergeDownloadRuntimeOptions)
import qualified Panino.Install.Plan.Types as Plan

data JavaRuntimeRequirement = JavaRuntimeRequirement
  { javaRequirementMinecraftVersion :: Text
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

data JavaManagedRuntime = JavaManagedRuntime
  { managedRuntimeId :: Text
  , managedRuntimeVendor :: Text
  , managedRuntimeProvider :: Text
  , managedRuntimeFeatureVersion :: Int
  , managedRuntimeVersion :: Text
  , managedRuntimeOs :: Text
  , managedRuntimeArch :: Text
  , managedRuntimeImageType :: Text
  , managedRuntimeJavaHome :: FilePath
  , managedRuntimeJavaExecutable :: FilePath
  , managedRuntimeSourceUrl :: Text
  , managedRuntimeSha256 :: Maybe Text
  , managedRuntimeInstalledAt :: UTCTime
  , managedRuntimeLastVerifiedAt :: Maybe UTCTime
  , managedRuntimeDiskUsageBytes :: Maybe Int64
  , managedRuntimeUsedByInstanceCount :: Int
  } deriving (Eq, Show)

instance ToJSON JavaManagedRuntime where
  toJSON runtime =
    object
      [ "id" .= managedRuntimeId runtime
      , "vendor" .= managedRuntimeVendor runtime
      , "provider" .= managedRuntimeProvider runtime
      , "featureVersion" .= managedRuntimeFeatureVersion runtime
      , "version" .= managedRuntimeVersion runtime
      , "os" .= managedRuntimeOs runtime
      , "arch" .= managedRuntimeArch runtime
      , "imageType" .= managedRuntimeImageType runtime
      , "javaHome" .= managedRuntimeJavaHome runtime
      , "javaExecutable" .= managedRuntimeJavaExecutable runtime
      , "sourceUrl" .= managedRuntimeSourceUrl runtime
      , "sha256" .= managedRuntimeSha256 runtime
      , "installedAt" .= managedRuntimeInstalledAt runtime
      , "lastVerifiedAt" .= managedRuntimeLastVerifiedAt runtime
      , "diskUsageBytes" .= managedRuntimeDiskUsageBytes runtime
      , "usedByInstanceCount" .= managedRuntimeUsedByInstanceCount runtime
      ]

instance FromJSON JavaManagedRuntime where
  parseJSON =
    withObject "JavaManagedRuntime" $ \obj ->
      JavaManagedRuntime
        <$> obj .: "id"
        <*> obj .:? "vendor" .!= "temurin"
        <*> obj .:? "provider" .!= "adoptium"
        <*> obj .: "featureVersion"
        <*> obj .:? "version" .!= ""
        <*> obj .:? "os" .!= "mac"
        <*> obj .:? "arch" .!= "aarch64"
        <*> obj .:? "imageType" .!= "jre"
        <*> obj .: "javaHome"
        <*> obj .: "javaExecutable"
        <*> obj .:? "sourceUrl" .!= ""
        <*> obj .:? "sha256"
        <*> obj .: "installedAt"
        <*> obj .:? "lastVerifiedAt"
        <*> obj .:? "diskUsageBytes"
        <*> obj .:? "usedByInstanceCount" .!= 0

data JavaManagedResponse = JavaManagedResponse
  { javaManagedRuntimes :: [JavaManagedRuntime]
  , javaManagedRoot :: FilePath
  } deriving (Eq, Show)

instance ToJSON JavaManagedResponse where
  toJSON response =
    object
      [ "runtimes" .= javaManagedRuntimes response
      , "root" .= javaManagedRoot response
      ]

data JavaRuntimeDownloadSpec = JavaRuntimeDownloadSpec
  { runtimeDownloadProvider :: Text
  , runtimeDownloadVendor :: Text
  , runtimeDownloadFeatureVersion :: Int
  , runtimeDownloadOs :: Text
  , runtimeDownloadArch :: Text
  , runtimeDownloadImageType :: Text
  , runtimeDownloadUrl :: Text
  , runtimeDownloadChecksumUrl :: Maybe Text
  , runtimeDownloadSha256 :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeDownloadSpec where
  parseJSON =
    withObject "JavaRuntimeDownloadSpec" $ \obj ->
      JavaRuntimeDownloadSpec
        <$> obj .:? "provider" .!= "adoptium"
        <*> obj .:? "vendor" .!= "temurin"
        <*> obj .: "featureVersion"
        <*> obj .:? "os" .!= "mac"
        <*> obj .:? "arch" .!= "aarch64"
        <*> obj .:? "imageType" .!= "jre"
        <*> obj .: "url"
        <*> obj .:? "checksumUrl"
        <*> obj .:? "sha256"

instance ToJSON JavaRuntimeDownloadSpec where
  toJSON spec =
    object
      [ "provider" .= runtimeDownloadProvider spec
      , "vendor" .= runtimeDownloadVendor spec
      , "featureVersion" .= runtimeDownloadFeatureVersion spec
      , "os" .= runtimeDownloadOs spec
      , "arch" .= runtimeDownloadArch spec
      , "imageType" .= runtimeDownloadImageType spec
      , "url" .= runtimeDownloadUrl spec
      , "checksumUrl" .= runtimeDownloadChecksumUrl spec
      , "sha256" .= runtimeDownloadSha256 spec
      ]

data JavaRuntimeCatalogItem = JavaRuntimeCatalogItem
  { catalogRuntimeId :: Text
  , catalogRuntimeName :: Text
  , catalogRuntimeProvider :: Text
  , catalogRuntimeVendor :: Text
  , catalogRuntimeFeatureVersion :: Int
  , catalogRuntimeOs :: Text
  , catalogRuntimeArch :: Text
  , catalogRuntimeImageType :: Text
  , catalogRuntimeDownload :: JavaRuntimeDownloadSpec
  , catalogRuntimeStale :: Bool
  , catalogRuntimeCachedAt :: Maybe UTCTime
  , catalogRuntimeWarnings :: [Text]
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeCatalogItem where
  parseJSON =
    withObject "JavaRuntimeCatalogItem" $ \obj ->
      JavaRuntimeCatalogItem
        <$> obj .: "id"
        <*> obj .: "name"
        <*> obj .:? "provider" .!= "adoptium"
        <*> obj .:? "vendor" .!= "temurin"
        <*> obj .: "featureVersion"
        <*> obj .:? "os" .!= "mac"
        <*> obj .:? "arch" .!= "aarch64"
        <*> obj .:? "imageType" .!= "jre"
        <*> obj .: "download"
        <*> obj .:? "stale" .!= False
        <*> obj .:? "cachedAt"
        <*> obj .:? "warnings" .!= []

instance ToJSON JavaRuntimeCatalogItem where
  toJSON item =
    object
      [ "id" .= catalogRuntimeId item
      , "name" .= catalogRuntimeName item
      , "provider" .= catalogRuntimeProvider item
      , "vendor" .= catalogRuntimeVendor item
      , "featureVersion" .= catalogRuntimeFeatureVersion item
      , "os" .= catalogRuntimeOs item
      , "arch" .= catalogRuntimeArch item
      , "imageType" .= catalogRuntimeImageType item
      , "download" .= catalogRuntimeDownload item
      , "stale" .= catalogRuntimeStale item
      , "cachedAt" .= catalogRuntimeCachedAt item
      , "warnings" .= catalogRuntimeWarnings item
      ]

data JavaRuntimeResolveRequest = JavaRuntimeResolveRequest
  { resolveMinecraftVersion :: Text
  , resolveGameDir :: Maybe FilePath
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
  { resolveResponseMinecraftVersion :: Text
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
              , Plan.installNodeSourceUrls = [runtimeDownloadUrl spec]
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
              <> resolveResponseMinecraftVersion response
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

data JavaRuntimeInstallRequest = JavaRuntimeInstallRequest
  { installRuntimeFeatureVersion :: Int
  , installRuntimeProvider :: Text
  , installRuntimeVendor :: Text
  , installRuntimeOs :: Maybe Text
  , installRuntimeArch :: Maybe Text
  , installRuntimeImageType :: Text
  , installRuntimeSetDefault :: Bool
  , installRuntimeDownload :: DownloadRuntimeOptions
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeInstallRequest where
  parseJSON =
    withObject "JavaRuntimeInstallRequest" $ \obj -> do
      legacyConcurrency <- obj .:? "concurrency"
      legacyRetryCount <- obj .:? "retryCount"
      legacyStrategy <- obj .:? "strategy"
      nestedDownload <- obj .:? "download"
      JavaRuntimeInstallRequest
        <$> (obj .: "featureVersion" <|> obj .: "version")
        <*> obj .:? "provider" .!= "adoptium"
        <*> obj .:? "vendor" .!= "temurin"
        <*> obj .:? "os"
        <*> obj .:? "arch"
        <*> obj .:? "imageType" .!= "jre"
        <*> obj .:? "setDefault" .!= False
        <*> pure (mergeDownloadRuntimeOptions legacyConcurrency legacyRetryCount legacyStrategy nestedDownload)

data JavaRuntimePolicyRecord = JavaRuntimePolicyRecord
  { policyRecordScope :: Text
  , policyRecordInstanceId :: Maybe Text
  , policyRecordPolicy :: Text
  , policyRecordPreferredRuntimeId :: Maybe Text
  , policyRecordCustomPath :: Maybe FilePath
  , policyRecordLockPatchVersion :: Bool
  , policyRecordUpdatedAt :: UTCTime
  } deriving (Eq, Show)

instance FromJSON JavaRuntimePolicyRecord where
  parseJSON =
    withObject "JavaRuntimePolicyRecord" $ \obj ->
      JavaRuntimePolicyRecord
        <$> obj .:? "scope" .!= "global"
        <*> obj .:? "instanceId"
        <*> obj .:? "policy" .!= "auto"
        <*> obj .:? "preferredRuntimeId"
        <*> obj .:? "customPath"
        <*> obj .:? "lockPatchVersion" .!= False
        <*> obj .: "updatedAt"

instance ToJSON JavaRuntimePolicyRecord where
  toJSON record =
    object
      [ "scope" .= policyRecordScope record
      , "instanceId" .= policyRecordInstanceId record
      , "policy" .= policyRecordPolicy record
      , "preferredRuntimeId" .= policyRecordPreferredRuntimeId record
      , "customPath" .= policyRecordCustomPath record
      , "lockPatchVersion" .= policyRecordLockPatchVersion record
      , "updatedAt" .= policyRecordUpdatedAt record
      ]

data JavaRuntimeSelectRequest = JavaRuntimeSelectRequest
  { selectRuntimeScope :: Text
  , selectRuntimeInstanceId :: Maybe Text
  , selectRuntimePolicy :: Text
  , selectRuntimePreferredRuntimeId :: Maybe Text
  , selectRuntimeCustomPath :: Maybe FilePath
  , selectRuntimeLockPatchVersion :: Bool
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeSelectRequest where
  parseJSON =
    withObject "JavaRuntimeSelectRequest" $ \obj ->
      JavaRuntimeSelectRequest
        <$> obj .:? "scope" .!= "global"
        <*> obj .:? "instanceId"
        <*> obj .:? "policy" .!= "auto"
        <*> obj .:? "preferredRuntimeId"
        <*> obj .:? "customPath"
        <*> obj .:? "lockPatchVersion" .!= False

data JavaRuntimeSelectResponse = JavaRuntimeSelectResponse
  { selectResponsePolicy :: JavaRuntimePolicyRecord
  , selectResponseMessage :: Text
  } deriving (Eq, Show)

instance ToJSON JavaRuntimeSelectResponse where
  toJSON response =
    object
      [ "policy" .= selectResponsePolicy response
      , "message" .= selectResponseMessage response
      ]

data JavaRuntimeImportRequest = JavaRuntimeImportRequest
  { importRuntimeSourcePath :: FilePath
  , importRuntimeProvider :: Text
  , importRuntimeVendor :: Text
  , importRuntimeFeatureVersion :: Maybe Int
  , importRuntimeOs :: Maybe Text
  , importRuntimeArch :: Maybe Text
  , importRuntimeImageType :: Text
  , importRuntimeSetDefault :: Bool
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeImportRequest where
  parseJSON =
    withObject "JavaRuntimeImportRequest" $ \obj ->
      JavaRuntimeImportRequest
        <$> (obj .: "sourcePath" <|> obj .: "path")
        <*> obj .:? "provider" .!= "local"
        <*> obj .:? "vendor" .!= "local"
        <*> obj .:? "featureVersion"
        <*> obj .:? "os"
        <*> obj .:? "arch"
        <*> obj .:? "imageType" .!= "jre"
        <*> obj .:? "setDefault" .!= False

data JavaRuntimeVerifyRequest = JavaRuntimeVerifyRequest
  { verifyRuntimeId :: Text
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeVerifyRequest where
  parseJSON =
    withObject "JavaRuntimeVerifyRequest" $ \obj ->
      JavaRuntimeVerifyRequest <$> obj .: "id"

data JavaRuntimeDeleteResponse = JavaRuntimeDeleteResponse
  { deleteRuntimeDeleted :: Bool
  , deleteRuntimeId :: Text
  , deleteRuntimeMessage :: Text
  , deleteRuntimeReferences :: [Text]
  } deriving (Eq, Show)

instance ToJSON JavaRuntimeDeleteResponse where
  toJSON response =
    object
      [ "deleted" .= deleteRuntimeDeleted response
      , "id" .= deleteRuntimeId response
      , "message" .= deleteRuntimeMessage response
      , "references" .= deleteRuntimeReferences response
      ]

data JavaRuntimeCleanupResponse = JavaRuntimeCleanupResponse
  { cleanupRuntimeDeletedRuntimeIds :: [Text]
  , cleanupRuntimeDeletedDownloadFiles :: [FilePath]
  , cleanupRuntimeDeletedStagingDirs :: [FilePath]
  , cleanupRuntimeFreedBytes :: Int64
  , cleanupRuntimeKeptRuntimeIds :: [Text]
  , cleanupRuntimeMessage :: Text
  } deriving (Eq, Show)

instance ToJSON JavaRuntimeCleanupResponse where
  toJSON response =
    object
      [ "deletedRuntimeIds" .= cleanupRuntimeDeletedRuntimeIds response
      , "deletedDownloadFiles" .= cleanupRuntimeDeletedDownloadFiles response
      , "deletedStagingDirs" .= cleanupRuntimeDeletedStagingDirs response
      , "freedBytes" .= cleanupRuntimeFreedBytes response
      , "keptRuntimeIds" .= cleanupRuntimeKeptRuntimeIds response
      , "message" .= cleanupRuntimeMessage response
      ]
