{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Solver
  ( LockfileApplyReadiness(..)
  , ReadyLockfile
  , ReadyLockfileApply
  , diffLockfiles
  , lockfileApplyReadyLockfile
  , lockfileApplyReadiness
  , lockfileLaunchBlockedReasons
  , lockfileSolveCacheGameDir
  , readyLockfileApplyLockfile
  , readyLockfileApplyPlan
  , readyLockfileLockfile
  , roomLockRepairPlan
  , roomRequiredLockSubset
  , solveLockfile
  , solveLockfileWithServices
  , verifyLockfile
  ) where

import Data.List (foldl')
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Network.HTTP.Client (Manager)
import Panino.CoreLogic.Determinism
  ( stableSortPackages
  , stableTextSet
  )
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Install.Plan.State
  ( BlockedInstallPlan
  , ExecutableInstallPlan
  , requireExecutableInstallPlan
  )
import Panino.Lockfile.Changeset
  ( buildChangeset
  , diffLockfiles
  , sortChangeset
  )
import Panino.Lockfile.Explain
  ( constraintExplainEntry
  , packageExplainEntry
  , rootExplainEntry
  )
import Panino.Lockfile.Normalize
  ( applyExistingLockPolicy
  , applyPins
  , constraintKey
  , dedupePackages
  , normalizePackage
  , packageAllConstraints
  , selectedUpdatePackageIds
  )
import Panino.Lockfile.Plan
  ( buildLockfileTypedPlan
  , lockfileFingerprintFor
  )
import Panino.Lockfile.Services
  ( applyServiceEvidence
  , collectServiceEvidence
  , lockfileSolveCacheGameDir
  )
import Panino.Lockfile.Solver.Build
  ( buildLockfile
  , explainEntryKey
  , optifineWarnings
  , updateLockfileFingerprint
  )
import Panino.Lockfile.Solver.Conflicts
  ( conflictBlockedReason
  , detectConflicts
  , detectPackageBlockedReasons
  )
import Panino.Lockfile.Solver.Resolve
  ( ResolveState(..)
  , emptyResolveState
  , resolvePackageId
  )
import Panino.Lockfile.Solver.Room
  ( roomLockRepairPlan
  , roomRequiredLockSubset
  )
import Panino.Lockfile.Types
  ( LockfileApplyRequest(..)
  , LockfileApplyRejection(..)
  , LockfileExplain(..)
  , LockfileSolveRequest(..)
  , LockfileSolveStatus(..)
  , LockfileUpdatePolicy(..)
  , LockfileVerifyResponse(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , SolverReadiness(..)
  , SolverResult(..)
  , blockedSolverResult
  , classifySolverResult
  , readySolverResult
  , readySolverResultLockfile
  , readySolverResultPlan
  , resolvedPackageKey
  , solveRequestTargetGameDirPath
  )
import Panino.Lockfile.Verify
  ( verifyIssueBlockedReason
  , verifyLockfile
  )

solveLockfile :: LockfileSolveRequest -> SolverResult
solveLockfile request =
  let normalizedRoots =
        stableSortPackages resolvedPackageKey $
          map (applyPins request . normalizePackage (solveRequestTargetGameDirPath request) "root request") (solveRequestRoots request)
      selectedUpdateIds = selectedUpdatePackageIds request normalizedRoots
      normalizedManual =
        stableSortPackages resolvedPackageKey $
          map (applyPins request . normalizePackage (solveRequestTargetGameDirPath request) "manual entry") (solveRequestManualPackages request)
      normalizedExisting =
        stableSortPackages resolvedPackageKey $
          maybe
            []
            ( map
                ( applyExistingLockPolicy request selectedUpdateIds
                    . applyPins request
                    . normalizePackage (solveRequestTargetGameDirPath request) "existing lockfile"
                )
                . lockfilePackages
            )
            (solveRequestExistingLockfile request)
      availablePackages = dedupePackages request (normalizedRoots <> normalizedManual <> normalizedExisting)
      availableMap = Map.fromList [(resolvedPackageId package, package) | package <- availablePackages]
      rootPackageIds = stableTextSet (map resolvedPackageId (normalizedRoots <> normalizedManual) <> existingRootPackageIds normalizedExisting)
      resolvedState = foldl' (resolvePackageId request availableMap) emptyResolveState rootPackageIds
      selectedPackages = stableSortPackages resolvedPackageKey (Map.elems (resolveSelected resolvedState))
      constraints = stableSortPackages constraintKey (concatMap packageAllConstraints selectedPackages)
      warnings = stableTextSet (resolveWarnings resolvedState <> optifineWarnings request selectedPackages)
      conflicts = detectConflicts request selectedPackages constraints
      conflictReasons = map conflictBlockedReason conflicts
      packageBlockedReasons = detectPackageBlockedReasons selectedPackages
      blockedReasons =
        stableTextSet
          ( resolveBlockedReasons resolvedState
              <> conflictReasons
              <> packageBlockedReasons
          )
      diagnostics = map (diagnosticFromBlockedReason "solve" "lockfile solver") blockedReasons
      changeset = sortChangeset (buildChangeset request selectedPackages blockedReasons)
      stagedLockfile = buildLockfile request selectedPackages constraints warnings
      fingerprint = lockfileFingerprintFor stagedLockfile
      lockfile = stagedLockfile { lockfileFingerprint = fingerprint }
      explain =
        LockfileExplain
          { explainRootRequests = stableSortPackages explainEntryKey (map rootExplainEntry normalizedRoots)
          , explainConstraints = stableSortPackages explainEntryKey (map constraintExplainEntry constraints)
          , explainSelectedCandidates = stableSortPackages explainEntryKey (map packageExplainEntry selectedPackages)
          , explainRejectedCandidates = stableSortPackages explainEntryKey (resolveRejected resolvedState)
          , explainFingerprint = Just fingerprint
          }
      typedPlan =
        buildLockfileTypedPlan
          (solveRequestTargetGameDirPath request)
          selectedPackages
          constraints
          changeset
          warnings
          blockedReasons
          diagnostics
      status =
        if null blockedReasons
          then LockfileSolveReady
          else LockfileSolveBlocked
   in canonicalSolverResult
        SolverResult
          { solverResultStatus = status
          , solverResultLockfile = Just lockfile
          , solverResultTypedPlan = typedPlan
          , solverResultChangeset = changeset
          , solverResultWarnings = warnings
          , solverResultBlockedReasons = blockedReasons
          , solverResultConflicts = conflicts
          , solverResultExplain = explain
          , solverResultDiagnostics = diagnostics
          }
  where
    existingRootPackageIds packages
      | solveRequestUpdatePolicy request == LockfileRelock = []
      | otherwise = map resolvedPackageId packages

solveLockfileWithServices :: Manager -> LockfileSolveRequest -> IO SolverResult
solveLockfileWithServices manager request = do
  (evidence, augmentedRequest) <- collectServiceEvidence manager request
  pure (applyServiceEvidence updateLockfileFingerprint evidence (solveLockfile augmentedRequest))

newtype ReadyLockfile =
  ReadyLockfile PaninoLockfile
  deriving (Eq, Show)

readyLockfileLockfile :: ReadyLockfile -> PaninoLockfile
readyLockfileLockfile (ReadyLockfile lockfile) =
  lockfile

data ReadyLockfileApply = ReadyLockfileApply
  { readyLockfileApplyLockfile :: ReadyLockfile
  , readyLockfileApplyPlan :: ExecutableInstallPlan
  } deriving (Eq, Show)

data LockfileApplyReadiness
  = LockfileApplyRejected LockfileApplyRejection
  | LockfileApplyPlanBlocked BlockedInstallPlan
  | LockfileApplyReady ReadyLockfileApply
  deriving (Eq, Show)

lockfileApplyReadiness :: LockfileApplyRequest -> LockfileApplyReadiness
lockfileApplyReadiness request =
  case solverResultLockfile rawResult of
    Nothing -> LockfileApplyRejected LockfileApplyLockfileMissing
    Just lockfile
      | solverResultStatus rawResult /= LockfileSolveReady -> LockfileApplyRejected LockfileApplySolverBlocked
      | lockfileFingerprint lockfile /= applyRequestSolverFingerprint request -> LockfileApplyRejected LockfileApplySolverFingerprintMismatch
      | otherwise ->
          case classifySolverResult rawResult of
            SolverResultReady readyResult ->
              LockfileApplyReady
                ReadyLockfileApply
                  { readyLockfileApplyLockfile = ReadyLockfile (readySolverResultLockfile readyResult)
                  , readyLockfileApplyPlan = readySolverResultPlan readyResult
                  }
            SolverResultBlocked _ ->
              case requireExecutableInstallPlan (solverResultTypedPlan rawResult) of
                Left blockedPlan -> LockfileApplyPlanBlocked blockedPlan
                Right _ -> LockfileApplyRejected LockfileApplySolverBlocked
  where
    rawResult = applyRequestResult request

lockfileApplyReadyLockfile :: LockfileApplyRequest -> Either LockfileApplyRejection ReadyLockfile
lockfileApplyReadyLockfile request =
  case lockfileApplyReadiness request of
    LockfileApplyRejected rejection -> Left rejection
    LockfileApplyPlanBlocked _ -> Left LockfileApplySolverBlocked
    LockfileApplyReady readyApply -> Right (readyLockfileApplyLockfile readyApply)

canonicalSolverResult :: SolverResult -> SolverResult
canonicalSolverResult result =
  case classifySolverResult result of
    SolverResultReady readyResult -> readySolverResult readyResult
    SolverResultBlocked blockedResult -> blockedSolverResult blockedResult

lockfileLaunchBlockedReasons :: LockfileVerifyResponse -> [Text]
lockfileLaunchBlockedReasons response =
  stableTextSet $
    map (verifyIssueBlockedReason "lockfile_missing_file") (verifyResponseMissingFiles response)
      <> map (verifyIssueBlockedReason "lockfile_hash_mismatch") (verifyResponseHashMismatches response)
      <> map (verifyIssueBlockedReason "lockfile_java_mismatch") (verifyResponseJavaMismatch response)
      <> map (verifyIssueBlockedReason "lockfile_loader_mismatch") (verifyResponseLoaderMismatch response)
