{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Solver
  ( diffLockfiles
  , lockfileApplyReadyLockfile
  , lockfileLaunchBlockedReasons
  , lockfileSolveCacheGameDir
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
  , LockfileExplain(..)
  , LockfileSolveRequest(..)
  , LockfileSolveStatus(..)
  , LockfileUpdatePolicy(..)
  , LockfileVerifyResponse(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , SolverResult(..)
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
   in SolverResult
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

lockfileApplyReadyLockfile :: LockfileApplyRequest -> Either Text PaninoLockfile
lockfileApplyReadyLockfile request =
  case solverResultLockfile (applyRequestResult request) of
    Nothing -> Left "lockfile_missing"
    Just lockfile
      | solverResultStatus (applyRequestResult request) /= LockfileSolveReady -> Left "solver_blocked"
      | lockfileFingerprint lockfile /= applyRequestSolverFingerprint request -> Left "solver_fingerprint_mismatch"
      | otherwise -> Right lockfile

lockfileLaunchBlockedReasons :: LockfileVerifyResponse -> [Text]
lockfileLaunchBlockedReasons response =
  stableTextSet $
    map (verifyIssueBlockedReason "lockfile_missing_file") (verifyResponseMissingFiles response)
      <> map (verifyIssueBlockedReason "lockfile_hash_mismatch") (verifyResponseHashMismatches response)
      <> map (verifyIssueBlockedReason "lockfile_java_mismatch") (verifyResponseJavaMismatch response)
      <> map (verifyIssueBlockedReason "lockfile_loader_mismatch") (verifyResponseLoaderMismatch response)
