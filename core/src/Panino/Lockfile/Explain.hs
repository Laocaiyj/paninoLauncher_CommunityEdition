{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Explain
  ( constraintExplainEntry
  , packageExplainEntry
  , rootExplainEntry
  ) where

import Panino.Lockfile.Types
  ( LockfileExplainEntry(..)
  , PackageConstraint(..)
  , ResolvedPackage(..)
  )

rootExplainEntry :: ResolvedPackage -> LockfileExplainEntry
rootExplainEntry package =
  LockfileExplainEntry
    { explainEntryPackageId = Just (resolvedPackageId package)
    , explainEntryConstraintId = Nothing
    , explainEntryKind = "root"
    , explainEntryReason = "Requested by solve roots."
    , explainEntryRequired = True
    }

packageExplainEntry :: ResolvedPackage -> LockfileExplainEntry
packageExplainEntry package =
  LockfileExplainEntry
    { explainEntryPackageId = Just (resolvedPackageId package)
    , explainEntryConstraintId = Nothing
    , explainEntryKind = "selected"
    , explainEntryReason =
        case resolvedPackageSelectedBecause package of
          reason:_ -> reason
          [] -> "Selected by deterministic lockfile solver."
    , explainEntryRequired = True
    }

constraintExplainEntry :: PackageConstraint -> LockfileExplainEntry
constraintExplainEntry constraint =
  LockfileExplainEntry
    { explainEntryPackageId = constraintTargetPackageId constraint
    , explainEntryConstraintId = Just (constraintId constraint)
    , explainEntryKind = constraintRelation constraint
    , explainEntryReason = constraintReason constraint
    , explainEntryRequired = constraintRequired constraint
    }
