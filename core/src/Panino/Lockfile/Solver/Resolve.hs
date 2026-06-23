{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Solver.Resolve
  ( ResolveState(..)
  , emptyResolveState
  , resolvePackageId
  ) where

import Data.List (foldl')
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Lockfile.Explain (constraintExplainEntry)
import Panino.Lockfile.Normalize (packageAllConstraints)
import Panino.Lockfile.Types
  ( LockfileExplainEntry
  , LockfileSolveRequest(..)
  , PackageConstraint(..)
  , ResolvedPackage(..)
  )

data ResolveState = ResolveState
  { resolveSelected :: Map Text ResolvedPackage
  , resolveWarnings :: [Text]
  , resolveBlockedReasons :: [Text]
  , resolveRejected :: [LockfileExplainEntry]
  } deriving (Eq, Show)

emptyResolveState :: ResolveState
emptyResolveState =
  ResolveState Map.empty [] [] []

resolvePackageId :: LockfileSolveRequest -> Map Text ResolvedPackage -> ResolveState -> Text -> ResolveState
resolvePackageId request available state packageId =
  resolvePackageIdWithStack request available [] state packageId

resolvePackageIdWithStack :: LockfileSolveRequest -> Map Text ResolvedPackage -> [Text] -> ResolveState -> Text -> ResolveState
resolvePackageIdWithStack request available stack state packageId
  | packageId `elem` stack =
      state { resolveWarnings = ("solver_cycle_detected:" <> packageId) : resolveWarnings state }
  | Map.member packageId (resolveSelected state) = state
  | otherwise =
      case Map.lookup packageId available of
        Nothing ->
          state { resolveBlockedReasons = ("solver_no_candidate:" <> packageId) : resolveBlockedReasons state }
        Just package ->
          foldl'
            (resolveConstraint request available (packageId : stack))
            state { resolveSelected = Map.insert packageId package (resolveSelected state) }
            (packageAllConstraints package)

resolveConstraint :: LockfileSolveRequest -> Map Text ResolvedPackage -> [Text] -> ResolveState -> PackageConstraint -> ResolveState
resolveConstraint request available stack state constraint =
  case Text.toLower (constraintRelation constraint) of
    "requires" -> requireTarget
    "pins" -> requireTarget
    "optional"
      | optionalSelected constraint -> requireTarget
      | otherwise ->
          state { resolveRejected = constraintExplainEntry constraint : resolveRejected state }
    "incompatible" -> state
    "conflicts" -> state
    "embeds" -> state
    _ -> state
  where
    requireTarget =
      case constraintTargetPackageId constraint of
        Just targetId -> resolvePackageIdWithStack request available stack state targetId
        Nothing
          | constraintRequired constraint ->
              state { resolveBlockedReasons = ("required_dependency_unresolved:" <> constraintId constraint) : resolveBlockedReasons state }
          | otherwise -> state
    optionalSelected constraintValue =
      let targetId = fromMaybe "" (constraintTargetPackageId constraintValue)
          selected =
            solveRequestIncludeOptionalDependencies request
              || constraintId constraintValue `elem` selectedOptionalIds
              || targetId `elem` selectedOptionalIds
       in selected
            && constraintId constraintValue `notElem` ignoredDependencyIds
            && targetId `notElem` ignoredDependencyIds
    selectedOptionalIds =
      solveRequestSelectedOptionalDependencies request
    ignoredDependencyIds =
      solveRequestIgnoredDependencies request
