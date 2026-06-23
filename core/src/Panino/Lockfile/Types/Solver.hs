{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Types.Solver
  ( LockfileApplyRequest(..)
  , LockfileChange(..)
  , LockfileChangeset(..)
  , LockfileDiffRequest(..)
  , LockfileExplain(..)
  , LockfileExplainEntry(..)
  , LockfileSolveRequest(..)
  , SolverConflict(..)
  , SolverResult(..)
  , emptyChangeset
  , emptyLockfileExplain
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
import Data.Text (Text)
import Panino.Diagnostics.Types (Diagnostic)
import Panino.Install.Plan.Types (TypedInstallPlan)
import Panino.Lockfile.Types.Document (PaninoLockfile)
import Panino.Lockfile.Types.Package (ResolvedPackage)

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

emptyChangeset :: LockfileChangeset
emptyChangeset =
  LockfileChangeset [] [] [] [] [] [] []

emptyLockfileExplain :: LockfileExplain
emptyLockfileExplain =
  LockfileExplain [] [] [] [] Nothing
