{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Types
  ( LockfileApplyRequest(..)
  , LockfileChange(..)
  , LockfileChangeset(..)
  , LockfileDiffRequest(..)
  , LockfileExplain(..)
  , LockfileExplainEntry(..)
  , LockfileFile(..)
  , LockfileSolveRequest(..)
  , LockfileVerifyIssue(..)
  , LockfileVerifyResponse(..)
  , PackageConstraint(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , SolverConflict(..)
  , SolverResult(..)
  , emptyChangeset
  , emptyLockfileExplain
  , lockfileFileKey
  , packageCoordinateKey
  , resolvedPackageKey
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , Value
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time (UTCTime)
import Panino.Diagnostics.Types (Diagnostic)
import Panino.Install.Plan.Types (TypedInstallPlan)

data PackageCoordinate = PackageCoordinate
  { coordinateSource :: Text
  , coordinateProjectId :: Maybe Text
  , coordinateVersionId :: Maybe Text
  , coordinateFileId :: Maybe Text
  , coordinateSlug :: Maybe Text
  , coordinateName :: Maybe Text
  , coordinateKind :: Text
  } deriving (Eq, Show)

instance ToJSON PackageCoordinate where
  toJSON coordinate =
    object
      [ "source" .= coordinateSource coordinate
      , "projectId" .= coordinateProjectId coordinate
      , "versionId" .= coordinateVersionId coordinate
      , "fileId" .= coordinateFileId coordinate
      , "slug" .= coordinateSlug coordinate
      , "name" .= coordinateName coordinate
      , "kind" .= coordinateKind coordinate
      ]

instance FromJSON PackageCoordinate where
  parseJSON =
    withObject "PackageCoordinate" $ \obj ->
      PackageCoordinate
        <$> obj .:? "source" .!= "manual"
        <*> obj .:? "projectId"
        <*> (obj .:? "versionId" >>= maybe (obj .:? "versionID") (pure . Just))
        <*> obj .:? "fileId"
        <*> obj .:? "slug"
        <*> obj .:? "name"
        <*> obj .:? "kind" .!= "mod"

data PackageConstraint = PackageConstraint
  { constraintId :: Text
  , constraintSourcePackage :: Maybe Text
  , constraintTargetPackageId :: Maybe Text
  , constraintTargetKind :: Text
  , constraintRelation :: Text
  , constraintMinecraftVersions :: [Text]
  , constraintLoaders :: [Text]
  , constraintJavaMajor :: Maybe Int
  , constraintSide :: Maybe Text
  , constraintRequired :: Bool
  , constraintReason :: Text
  } deriving (Eq, Show)

instance ToJSON PackageConstraint where
  toJSON constraint =
    object
      [ "constraintId" .= constraintId constraint
      , "sourcePackage" .= constraintSourcePackage constraint
      , "targetPackageId" .= constraintTargetPackageId constraint
      , "targetKind" .= constraintTargetKind constraint
      , "relation" .= constraintRelation constraint
      , "minecraftVersions" .= constraintMinecraftVersions constraint
      , "loaders" .= constraintLoaders constraint
      , "javaMajor" .= constraintJavaMajor constraint
      , "side" .= constraintSide constraint
      , "required" .= constraintRequired constraint
      , "reason" .= constraintReason constraint
      ]

instance FromJSON PackageConstraint where
  parseJSON =
    withObject "PackageConstraint" $ \obj ->
      PackageConstraint
        <$> obj .:? "constraintId" .!= ""
        <*> obj .:? "sourcePackage"
        <*> (obj .:? "targetPackageId" >>= maybe (obj .:? "targetPackage") (pure . Just))
        <*> obj .:? "targetKind" .!= "mod"
        <*> obj .:? "relation" .!= "requires"
        <*> obj .:? "minecraftVersions" .!= []
        <*> obj .:? "loaders" .!= []
        <*> obj .:? "javaMajor"
        <*> obj .:? "side"
        <*> obj .:? "required" .!= True
        <*> obj .:? "reason" .!= ""

data ResolvedPackage = ResolvedPackage
  { resolvedPackageId :: Text
  , resolvedPackageCoordinate :: PackageCoordinate
  , resolvedPackageDisplayName :: Text
  , resolvedPackageVersionName :: Maybe Text
  , resolvedPackageFileName :: Maybe Text
  , resolvedPackageTargetPath :: Maybe FilePath
  , resolvedPackageHashes :: Map Text Text
  , resolvedPackageSize :: Maybe Int64
  , resolvedPackageDownloadUrls :: [Text]
  , resolvedPackageGameVersions :: [Text]
  , resolvedPackageLoaders :: [Text]
  , resolvedPackageJavaMajor :: Maybe Int
  , resolvedPackageSide :: Maybe Text
  , resolvedPackageSelectedBecause :: [Text]
  , resolvedPackageLocked :: Bool
  , resolvedPackagePinReason :: Maybe Text
  , resolvedPackageDependencies :: [PackageConstraint]
  , resolvedPackageConflicts :: [PackageConstraint]
  , resolvedPackageSourceSnapshot :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON ResolvedPackage where
  toJSON package =
    object
      [ "packageId" .= resolvedPackageId package
      , "coordinate" .= resolvedPackageCoordinate package
      , "displayName" .= resolvedPackageDisplayName package
      , "versionName" .= resolvedPackageVersionName package
      , "fileName" .= resolvedPackageFileName package
      , "targetPath" .= resolvedPackageTargetPath package
      , "hashes" .= resolvedPackageHashes package
      , "size" .= resolvedPackageSize package
      , "downloadUrls" .= resolvedPackageDownloadUrls package
      , "gameVersions" .= resolvedPackageGameVersions package
      , "loaders" .= resolvedPackageLoaders package
      , "javaMajor" .= resolvedPackageJavaMajor package
      , "side" .= resolvedPackageSide package
      , "selectedBecause" .= resolvedPackageSelectedBecause package
      , "locked" .= resolvedPackageLocked package
      , "pinReason" .= resolvedPackagePinReason package
      , "dependencies" .= resolvedPackageDependencies package
      , "conflicts" .= resolvedPackageConflicts package
      , "sourceSnapshot" .= resolvedPackageSourceSnapshot package
      ]

instance FromJSON ResolvedPackage where
  parseJSON =
    withObject "ResolvedPackage" $ \obj -> do
      coordinate <- obj .:? "coordinate" .!= PackageCoordinate "manual" Nothing Nothing Nothing Nothing Nothing "mod"
      packageIdValue <-
        obj .:? "packageId" .!= packageCoordinateKey coordinate
      displayNameValue <-
        obj .:? "displayName" .!= fromMaybe packageIdValue (coordinateName coordinate)
      ResolvedPackage
        <$> pure packageIdValue
        <*> pure coordinate
        <*> pure displayNameValue
        <*> obj .:? "versionName"
        <*> obj .:? "fileName"
        <*> obj .:? "targetPath"
        <*> obj .:? "hashes" .!= Map.empty
        <*> obj .:? "size"
        <*> obj .:? "downloadUrls" .!= []
        <*> obj .:? "gameVersions" .!= []
        <*> obj .:? "loaders" .!= []
        <*> obj .:? "javaMajor"
        <*> obj .:? "side"
        <*> obj .:? "selectedBecause" .!= []
        <*> obj .:? "locked" .!= False
        <*> obj .:? "pinReason"
        <*> obj .:? "dependencies" .!= []
        <*> obj .:? "conflicts" .!= []
        <*> obj .:? "sourceSnapshot"

data LockfileFile = LockfileFile
  { lockfileFilePackageId :: Text
  , lockfileFileName :: Text
  , lockfileFileTargetPath :: FilePath
  , lockfileFileHashes :: Map Text Text
  , lockfileFileSize :: Maybe Int64
  , lockfileFileDownloadUrls :: [Text]
  , lockfileFileKind :: Text
  } deriving (Eq, Show)

instance ToJSON LockfileFile where
  toJSON file =
    object
      [ "packageId" .= lockfileFilePackageId file
      , "fileName" .= lockfileFileName file
      , "targetPath" .= lockfileFileTargetPath file
      , "hashes" .= lockfileFileHashes file
      , "size" .= lockfileFileSize file
      , "downloadUrls" .= lockfileFileDownloadUrls file
      , "kind" .= lockfileFileKind file
      ]

instance FromJSON LockfileFile where
  parseJSON =
    withObject "LockfileFile" $ \obj ->
      LockfileFile
        <$> obj .: "packageId"
        <*> obj .:? "fileName" .!= ""
        <*> obj .: "targetPath"
        <*> obj .:? "hashes" .!= Map.empty
        <*> obj .:? "size"
        <*> obj .:? "downloadUrls" .!= []
        <*> obj .:? "kind" .!= "mod"

data PaninoLockfile = PaninoLockfile
  { lockfileVersion :: Int
  , lockfileSolverVersion :: Text
  , lockfileFingerprint :: Text
  , lockfileCreatedAt :: Maybe UTCTime
  , lockfileUpdatedAt :: Maybe UTCTime
  , lockfileTargetGameDir :: Maybe FilePath
  , lockfileMinecraft :: Maybe Text
  , lockfileJava :: Maybe Value
  , lockfileLoader :: Maybe Value
  , lockfileShaderLoader :: Maybe Value
  , lockfileRoots :: [Text]
  , lockfilePackages :: [ResolvedPackage]
  , lockfileFiles :: [LockfileFile]
  , lockfileConstraints :: [PackageConstraint]
  , lockfileOverrides :: [Value]
  , lockfileSourceSnapshots :: [Value]
  , lockfileManualEntries :: [ResolvedPackage]
  , lockfileWarnings :: [Text]
  } deriving (Eq, Show)

instance ToJSON PaninoLockfile where
  toJSON lockfile =
    object
      [ "lockfileVersion" .= lockfileVersion lockfile
      , "solverVersion" .= lockfileSolverVersion lockfile
      , "fingerprint" .= lockfileFingerprint lockfile
      , "createdAt" .= lockfileCreatedAt lockfile
      , "updatedAt" .= lockfileUpdatedAt lockfile
      , "targetGameDir" .= lockfileTargetGameDir lockfile
      , "minecraft" .= lockfileMinecraft lockfile
      , "java" .= lockfileJava lockfile
      , "loader" .= lockfileLoader lockfile
      , "shaderLoader" .= lockfileShaderLoader lockfile
      , "roots" .= lockfileRoots lockfile
      , "packages" .= lockfilePackages lockfile
      , "files" .= lockfileFiles lockfile
      , "constraints" .= lockfileConstraints lockfile
      , "overrides" .= lockfileOverrides lockfile
      , "sourceSnapshots" .= lockfileSourceSnapshots lockfile
      , "manualEntries" .= lockfileManualEntries lockfile
      , "warnings" .= lockfileWarnings lockfile
      ]

instance FromJSON PaninoLockfile where
  parseJSON =
    withObject "PaninoLockfile" $ \obj ->
      PaninoLockfile
        <$> obj .:? "lockfileVersion" .!= 1
        <*> obj .:? "solverVersion" .!= "lockfile-solver-v1"
        <*> obj .:? "fingerprint" .!= ""
        <*> obj .:? "createdAt"
        <*> obj .:? "updatedAt"
        <*> obj .:? "targetGameDir"
        <*> obj .:? "minecraft"
        <*> obj .:? "java"
        <*> obj .:? "loader"
        <*> obj .:? "shaderLoader"
        <*> obj .:? "roots" .!= []
        <*> obj .:? "packages" .!= []
        <*> obj .:? "files" .!= []
        <*> obj .:? "constraints" .!= []
        <*> obj .:? "overrides" .!= []
        <*> obj .:? "sourceSnapshots" .!= []
        <*> obj .:? "manualEntries" .!= []
        <*> obj .:? "warnings" .!= []

data LockfileSolveRequest = LockfileSolveRequest
  { solveRequestMode :: Text
  , solveRequestTargetGameDir :: FilePath
  , solveRequestMinecraftVersion :: Maybe Text
  , solveRequestLoader :: Maybe Text
  , solveRequestLoaderVersion :: Maybe Text
  , solveRequestJavaPolicy :: Maybe Value
  , solveRequestShaderLoader :: Maybe Text
  , solveRequestSourceType :: Maybe Text
  , solveRequestSourcePath :: Maybe FilePath
  , solveRequestIncludePerformancePack :: Bool
  , solveRequestRoots :: [ResolvedPackage]
  , solveRequestExistingLockfile :: Maybe PaninoLockfile
  , solveRequestUpdatePolicy :: Text
  , solveRequestSourcePolicy :: Maybe Text
  , solveRequestCurseForgeApiKey :: Maybe Text
  , solveRequestIncludeOptionalDependencies :: Bool
  , solveRequestSelectedOptionalDependencies :: [Text]
  , solveRequestIgnoredDependencies :: [Text]
  , solveRequestPinnedPackages :: [Text]
  , solveRequestManualPackages :: [ResolvedPackage]
  } deriving (Eq, Show)

instance FromJSON LockfileSolveRequest where
  parseJSON =
    withObject "LockfileSolveRequest" $ \obj ->
      LockfileSolveRequest
        <$> obj .:? "mode" .!= "install"
        <*> obj .: "targetGameDir"
        <*> obj .:? "minecraftVersion"
        <*> obj .:? "loader"
        <*> obj .:? "loaderVersion"
        <*> obj .:? "javaPolicy"
        <*> obj .:? "shaderLoader"
        <*> obj .:? "sourceType"
        <*> obj .:? "sourcePath"
        <*> obj .:? "includePerformancePack" .!= False
        <*> obj .:? "roots" .!= []
        <*> obj .:? "existingLockfile"
        <*> obj .:? "updatePolicy" .!= "keepLocked"
        <*> obj .:? "sourcePolicy"
        <*> obj .:? "curseForgeAPIKey"
        <*> obj .:? "includeOptionalDependencies" .!= False
        <*> obj .:? "selectedOptionalDependencies" .!= []
        <*> obj .:? "ignoredDependencies" .!= []
        <*> obj .:? "pinnedPackages" .!= []
        <*> obj .:? "manualPackages" .!= []

data LockfileChange = LockfileChange
  { lockfileChangeAction :: Text
  , lockfileChangePackageId :: Text
  , lockfileChangeDisplayName :: Text
  , lockfileChangeFromVersionId :: Maybe Text
  , lockfileChangeToVersionId :: Maybe Text
  , lockfileChangeTargetPath :: Maybe FilePath
  , lockfileChangeReason :: Text
  } deriving (Eq, Show)

instance ToJSON LockfileChange where
  toJSON change =
    object
      [ "action" .= lockfileChangeAction change
      , "packageId" .= lockfileChangePackageId change
      , "displayName" .= lockfileChangeDisplayName change
      , "fromVersionId" .= lockfileChangeFromVersionId change
      , "toVersionId" .= lockfileChangeToVersionId change
      , "targetPath" .= lockfileChangeTargetPath change
      , "reason" .= lockfileChangeReason change
      ]

instance FromJSON LockfileChange where
  parseJSON =
    withObject "LockfileChange" $ \obj ->
      LockfileChange
        <$> obj .:? "action" .!= "keep"
        <*> obj .:? "packageId" .!= ""
        <*> obj .:? "displayName" .!= ""
        <*> obj .:? "fromVersionId"
        <*> obj .:? "toVersionId"
        <*> obj .:? "targetPath"
        <*> obj .:? "reason" .!= ""

data LockfileChangeset = LockfileChangeset
  { changesetKeep :: [LockfileChange]
  , changesetAdd :: [LockfileChange]
  , changesetReplace :: [LockfileChange]
  , changesetRemove :: [LockfileChange]
  , changesetRepair :: [LockfileChange]
  , changesetManual :: [LockfileChange]
  , changesetBlocked :: [LockfileChange]
  } deriving (Eq, Show)

instance ToJSON LockfileChangeset where
  toJSON changeset =
    object
      [ "keep" .= changesetKeep changeset
      , "add" .= changesetAdd changeset
      , "replace" .= changesetReplace changeset
      , "remove" .= changesetRemove changeset
      , "repair" .= changesetRepair changeset
      , "manual" .= changesetManual changeset
      , "blocked" .= changesetBlocked changeset
      , "summary" .=
          object
            [ "keep" .= length (changesetKeep changeset)
            , "add" .= length (changesetAdd changeset)
            , "replace" .= length (changesetReplace changeset)
            , "remove" .= length (changesetRemove changeset)
            , "repair" .= length (changesetRepair changeset)
            , "manual" .= length (changesetManual changeset)
            , "blocked" .= length (changesetBlocked changeset)
            ]
      ]

instance FromJSON LockfileChangeset where
  parseJSON =
    withObject "LockfileChangeset" $ \obj ->
      LockfileChangeset
        <$> obj .:? "keep" .!= []
        <*> obj .:? "add" .!= []
        <*> obj .:? "replace" .!= []
        <*> obj .:? "remove" .!= []
        <*> obj .:? "repair" .!= []
        <*> obj .:? "manual" .!= []
        <*> obj .:? "blocked" .!= []

data SolverConflict = SolverConflict
  { solverConflictId :: Text
  , solverConflictCode :: Text
  , solverConflictTitle :: Text
  , solverConflictMessage :: Text
  , solverConflictPackageIds :: [Text]
  , solverConflictFilePaths :: [FilePath]
  , solverConflictDiagnostic :: Maybe Diagnostic
  } deriving (Eq, Show)

instance ToJSON SolverConflict where
  toJSON conflict =
    object
      [ "conflictId" .= solverConflictId conflict
      , "code" .= solverConflictCode conflict
      , "title" .= solverConflictTitle conflict
      , "message" .= solverConflictMessage conflict
      , "packageIds" .= solverConflictPackageIds conflict
      , "filePaths" .= solverConflictFilePaths conflict
      , "diagnostic" .= solverConflictDiagnostic conflict
      ]

instance FromJSON SolverConflict where
  parseJSON =
    withObject "SolverConflict" $ \obj ->
      SolverConflict
        <$> obj .:? "conflictId" .!= ""
        <*> obj .:? "code" .!= "solver_conflict"
        <*> obj .:? "title" .!= "Solver conflict"
        <*> obj .:? "message" .!= ""
        <*> obj .:? "packageIds" .!= []
        <*> obj .:? "filePaths" .!= []
        <*> obj .:? "diagnostic"

data LockfileExplainEntry = LockfileExplainEntry
  { explainEntryPackageId :: Maybe Text
  , explainEntryConstraintId :: Maybe Text
  , explainEntryKind :: Text
  , explainEntryReason :: Text
  , explainEntryRequired :: Bool
  } deriving (Eq, Show)

instance ToJSON LockfileExplainEntry where
  toJSON entry =
    object
      [ "packageId" .= explainEntryPackageId entry
      , "constraintId" .= explainEntryConstraintId entry
      , "kind" .= explainEntryKind entry
      , "reason" .= explainEntryReason entry
      , "required" .= explainEntryRequired entry
      ]

instance FromJSON LockfileExplainEntry where
  parseJSON =
    withObject "LockfileExplainEntry" $ \obj ->
      LockfileExplainEntry
        <$> obj .:? "packageId"
        <*> obj .:? "constraintId"
        <*> obj .:? "kind" .!= "selected"
        <*> obj .:? "reason" .!= ""
        <*> obj .:? "required" .!= True

data LockfileExplain = LockfileExplain
  { explainRootRequests :: [LockfileExplainEntry]
  , explainConstraints :: [LockfileExplainEntry]
  , explainSelectedCandidates :: [LockfileExplainEntry]
  , explainRejectedCandidates :: [LockfileExplainEntry]
  , explainFingerprint :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON LockfileExplain where
  toJSON explain =
    object
      [ "rootRequests" .= explainRootRequests explain
      , "constraints" .= explainConstraints explain
      , "selectedCandidates" .= explainSelectedCandidates explain
      , "rejectedCandidates" .= explainRejectedCandidates explain
      , "lockfileFingerprint" .= explainFingerprint explain
      ]

instance FromJSON LockfileExplain where
  parseJSON =
    withObject "LockfileExplain" $ \obj ->
      LockfileExplain
        <$> obj .:? "rootRequests" .!= []
        <*> obj .:? "constraints" .!= []
        <*> obj .:? "selectedCandidates" .!= []
        <*> obj .:? "rejectedCandidates" .!= []
        <*> obj .:? "lockfileFingerprint"

data SolverResult = SolverResult
  { solverResultStatus :: Text
  , solverResultLockfile :: Maybe PaninoLockfile
  , solverResultTypedPlan :: TypedInstallPlan
  , solverResultChangeset :: LockfileChangeset
  , solverResultWarnings :: [Text]
  , solverResultBlockedReasons :: [Text]
  , solverResultConflicts :: [SolverConflict]
  , solverResultExplain :: LockfileExplain
  , solverResultDiagnostics :: [Diagnostic]
  } deriving (Eq, Show)

instance ToJSON SolverResult where
  toJSON result =
    object
      [ "status" .= solverResultStatus result
      , "lockfile" .= solverResultLockfile result
      , "typedPlan" .= solverResultTypedPlan result
      , "changeset" .= solverResultChangeset result
      , "warnings" .= solverResultWarnings result
      , "blockedReasons" .= solverResultBlockedReasons result
      , "conflicts" .= solverResultConflicts result
      , "explain" .= solverResultExplain result
      , "diagnostics" .= solverResultDiagnostics result
      ]

instance FromJSON SolverResult where
  parseJSON =
    withObject "SolverResult" $ \obj ->
      SolverResult
        <$> obj .:? "status" .!= "blocked"
        <*> obj .:? "lockfile"
        <*> obj .: "typedPlan"
        <*> obj .:? "changeset" .!= emptyChangeset
        <*> obj .:? "warnings" .!= []
        <*> obj .:? "blockedReasons" .!= []
        <*> obj .:? "conflicts" .!= []
        <*> obj .:? "explain" .!= emptyLockfileExplain
        <*> obj .:? "diagnostics" .!= []

data LockfileApplyRequest = LockfileApplyRequest
  { applyRequestTargetGameDir :: FilePath
  , applyRequestSolverFingerprint :: Text
  , applyRequestResult :: SolverResult
  } deriving (Eq, Show)

instance FromJSON LockfileApplyRequest where
  parseJSON =
    withObject "LockfileApplyRequest" $ \obj ->
      LockfileApplyRequest
        <$> obj .: "targetGameDir"
        <*> obj .: "solverFingerprint"
        <*> obj .: "result"

data LockfileDiffRequest = LockfileDiffRequest
  { diffRequestBase :: PaninoLockfile
  , diffRequestTarget :: PaninoLockfile
  } deriving (Eq, Show)

instance FromJSON LockfileDiffRequest where
  parseJSON =
    withObject "LockfileDiffRequest" $ \obj ->
      LockfileDiffRequest
        <$> obj .: "base"
        <*> obj .: "target"

data LockfileVerifyIssue = LockfileVerifyIssue
  { verifyIssueKind :: Text
  , verifyIssuePackageId :: Maybe Text
  , verifyIssueTargetPath :: Maybe FilePath
  , verifyIssueExpectedSha1 :: Maybe Text
  , verifyIssueActualSha1 :: Maybe Text
  , verifyIssueMessage :: Text
  } deriving (Eq, Show)

instance ToJSON LockfileVerifyIssue where
  toJSON issue =
    object
      [ "kind" .= verifyIssueKind issue
      , "packageId" .= verifyIssuePackageId issue
      , "targetPath" .= verifyIssueTargetPath issue
      , "expectedSha1" .= verifyIssueExpectedSha1 issue
      , "actualSha1" .= verifyIssueActualSha1 issue
      , "message" .= verifyIssueMessage issue
      ]

data LockfileVerifyResponse = LockfileVerifyResponse
  { verifyResponseStatus :: Text
  , verifyResponseFingerprint :: Maybe Text
  , verifyResponseMissingFiles :: [LockfileVerifyIssue]
  , verifyResponseHashMismatches :: [LockfileVerifyIssue]
  , verifyResponseExtraFiles :: [LockfileVerifyIssue]
  , verifyResponseManualFiles :: [LockfileVerifyIssue]
  , verifyResponseJavaMismatch :: [LockfileVerifyIssue]
  , verifyResponseLoaderMismatch :: [LockfileVerifyIssue]
  , verifyResponseLockfileDrift :: [LockfileVerifyIssue]
  , verifyResponseRepairPlan :: Maybe TypedInstallPlan
  } deriving (Eq, Show)

instance ToJSON LockfileVerifyResponse where
  toJSON response =
    object
      [ "status" .= verifyResponseStatus response
      , "fingerprint" .= verifyResponseFingerprint response
      , "missingFiles" .= verifyResponseMissingFiles response
      , "hashMismatches" .= verifyResponseHashMismatches response
      , "extraFiles" .= verifyResponseExtraFiles response
      , "manualFiles" .= verifyResponseManualFiles response
      , "javaMismatch" .= verifyResponseJavaMismatch response
      , "loaderMismatch" .= verifyResponseLoaderMismatch response
      , "lockfileDrift" .= verifyResponseLockfileDrift response
      , "repairPlan" .= verifyResponseRepairPlan response
      ]

emptyChangeset :: LockfileChangeset
emptyChangeset =
  LockfileChangeset [] [] [] [] [] [] []

emptyLockfileExplain :: LockfileExplain
emptyLockfileExplain =
  LockfileExplain [] [] [] [] Nothing

packageCoordinateKey :: PackageCoordinate -> Text
packageCoordinateKey coordinate =
  Text.intercalate
    ":"
    [ Text.toLower (coordinateSource coordinate)
    , fromMaybe "" (coordinateProjectId coordinate)
    , fromMaybe "" (coordinateVersionId coordinate)
    , fromMaybe "" (coordinateFileId coordinate)
    , Text.toLower (coordinateKind coordinate)
    ]

resolvedPackageKey :: ResolvedPackage -> Text
resolvedPackageKey package =
  Text.intercalate
    "|"
    [ resolvedPackageId package
    , packageCoordinateKey (resolvedPackageCoordinate package)
    , fromMaybe "" (resolvedPackageFileName package)
    , maybe "" Text.pack (resolvedPackageTargetPath package)
    ]

lockfileFileKey :: LockfileFile -> Text
lockfileFileKey file =
  Text.intercalate
    "|"
    [ lockfileFilePackageId file
    , Text.pack (lockfileFileTargetPath file)
    , Map.findWithDefault "" "sha1" (lockfileFileHashes file)
    ]
