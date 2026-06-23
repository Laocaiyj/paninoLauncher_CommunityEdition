{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Services.Evidence
  ( ServiceEvidence(..)
  , applyServiceEvidence
  , emptyServiceEvidence
  , mergeServiceEvidence
  , requestWithServiceEvidence
  , serviceBlocked
  ) where

import Data.Aeson (Value)
import Data.Text (Text)
import Panino.CoreLogic.Determinism
  ( stableSortPackages
  , stableTextSet
  )
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Diagnostics.Types (Diagnostic)
import qualified Panino.Install.Plan.Types as Plan
import Panino.Lockfile.Types
  ( LockfileExplain(..)
  , LockfileSolveRequest(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , SolverResult(..)
  , resolvedPackageKey
  )

requestWithServiceEvidence :: LockfileSolveRequest -> ServiceEvidence -> LockfileSolveRequest
requestWithServiceEvidence request evidence =
  request
    { solveRequestRoots =
        solveRequestRoots request
          <> stableSortPackages resolvedPackageKey (servicePackages evidence)
    }

data ServiceEvidence = ServiceEvidence
  { servicePackages :: [ResolvedPackage]
  , serviceWarnings :: [Text]
  , serviceBlockedReasons :: [Text]
  , serviceDiagnostics :: [Diagnostic]
  , serviceLoaderVersion :: Maybe Text
  , serviceJavaPolicy :: Maybe Value
  } deriving (Eq, Show)

emptyServiceEvidence :: ServiceEvidence
emptyServiceEvidence =
  ServiceEvidence [] [] [] [] Nothing Nothing

mergeServiceEvidence :: [ServiceEvidence] -> ServiceEvidence
mergeServiceEvidence evidence =
  ServiceEvidence
    { servicePackages = stableSortPackages resolvedPackageKey (concatMap servicePackages evidence)
    , serviceWarnings = stableTextSet (concatMap serviceWarnings evidence)
    , serviceBlockedReasons = stableTextSet (concatMap serviceBlockedReasons evidence)
    , serviceDiagnostics = concatMap serviceDiagnostics evidence
    , serviceLoaderVersion = firstJust (map serviceLoaderVersion evidence)
    , serviceJavaPolicy = firstJust (map serviceJavaPolicy evidence)
    }

applyServiceEvidence :: (PaninoLockfile -> PaninoLockfile) -> ServiceEvidence -> SolverResult -> SolverResult
applyServiceEvidence updateFingerprint evidence result =
  let warnings = stableTextSet (solverResultWarnings result <> serviceWarnings evidence)
      blockedReasons = stableTextSet (solverResultBlockedReasons result <> serviceBlockedReasons evidence)
      diagnostics =
        serviceDiagnostics evidence
          <> map (diagnosticFromBlockedReason "solve" "lockfile solver") blockedReasons
      typedPlan =
        Plan.finalizeTypedInstallPlan
          (solverResultTypedPlan result)
            { Plan.typedPlanWarnings = warnings
            , Plan.typedPlanBlockedReasons = blockedReasons
            , Plan.typedPlanDiagnostics = diagnostics
            }
      lockfile =
        updateFingerprint
          . (\value -> value { lockfileWarnings = warnings })
          <$> solverResultLockfile result
      fingerprint = lockfileFingerprint <$> lockfile
      explain = (solverResultExplain result) { explainFingerprint = fingerprint }
   in result
        { solverResultStatus = if null blockedReasons then solverResultStatus result else "blocked"
        , solverResultLockfile = lockfile
        , solverResultTypedPlan = typedPlan
        , solverResultWarnings = warnings
        , solverResultBlockedReasons = blockedReasons
        , solverResultExplain = explain
        , solverResultDiagnostics = diagnostics
        }

serviceBlocked :: Text -> ServiceEvidence
serviceBlocked reason =
  emptyServiceEvidence
    { serviceBlockedReasons = [reason]
    , serviceDiagnostics = [diagnosticFromBlockedReason "solve" "lockfile services" reason]
    }

firstJust :: [Maybe value] -> Maybe value
firstJust [] = Nothing
firstJust (Nothing:rest) = firstJust rest
firstJust (Just value:_) = Just value
