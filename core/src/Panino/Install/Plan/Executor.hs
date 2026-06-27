{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Install.Plan.Executor
  ( InstallNodeResult(..)
  , InstallNodeStatus(..)
  , InstallPlanExecutionResult(..)
  , blockedInstallPlanExecutionResult
  , executeExecutableInstallPlan
  , executeInstallPlan
  , installPlanExecutionBatches
  , installNodeStatusText
  ) where

import Control.Applicative ((<|>))
import Control.Concurrent.Async (mapConcurrently)
import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import Data.Foldable (traverse_)
import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.List (partition)
import Data.Maybe
  ( listToMaybe
  )
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.CoreLogic.Determinism
  ( stableSortPlanNodes
  )
import Panino.Install.Plan.Types
  ( InstallPlanNode(..)
  , InstallVerification(..)
  , TypedInstallPlan(..)
  )
import Panino.Install.Plan.State
  ( BlockedInstallPlan
  , ExecutableInstallPlan
  , InstallPlanReadiness(..)
  , blockedInstallPlanReasons
  , blockedTypedPlan
  , classifyTypedInstallPlan
  , executableTypedPlan
  )
import Panino.Diagnostics.Classify
  ( classifyFailure
  , diagnosticFromBlockedReason
  )
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , FailureInput(..)
  , diagnosticWithFilePath
  , diagnosticWithPlanId
  )

data InstallNodeStatus
  = InstallNodePending
  | InstallNodeBlocked
  | InstallNodeRunning
  | InstallNodeSucceeded
  | InstallNodeSkipped
  | InstallNodeFailed
  | InstallNodeRolledBack
  | InstallNodeRollbackFailed
  deriving (Eq, Show)

installNodeStatusText :: InstallNodeStatus -> Text
installNodeStatusText status =
  case status of
    InstallNodePending -> "pending"
    InstallNodeBlocked -> "blocked"
    InstallNodeRunning -> "running"
    InstallNodeSucceeded -> "succeeded"
    InstallNodeSkipped -> "skipped"
    InstallNodeFailed -> "failed"
    InstallNodeRolledBack -> "rolledBack"
    InstallNodeRollbackFailed -> "rollbackFailed"

instance ToJSON InstallNodeStatus where
  toJSON =
    toJSON . installNodeStatusText

data InstallNodeResult = InstallNodeResult
  { installResultNodeId :: Text
  , installResultNodeKind :: Maybe Text
  , installResultPhase :: Maybe Text
  , installResultTargetPath :: Maybe FilePath
  , installResultStatus :: InstallNodeStatus
  , installResultMessage :: Maybe Text
  , installResultDiagnostic :: Maybe Diagnostic
  } deriving (Eq, Show)

instance ToJSON InstallNodeResult where
  toJSON result =
    object
      [ "nodeId" .= installResultNodeId result
      , "nodeKind" .= installResultNodeKind result
      , "phase" .= installResultPhase result
      , "targetPath" .= installResultTargetPath result
      , "status" .= installResultStatus result
      , "message" .= installResultMessage result
      , "diagnostic" .= installResultDiagnostic result
      ]

data InstallPlanExecutionResult = InstallPlanExecutionResult
  { installExecutionPlanId :: Text
  , installExecutionStatus :: Text
  , installExecutionResults :: [InstallNodeResult]
  , installExecutionCompletedNodeIds :: [Text]
  , installExecutionFailedNodeId :: Maybe Text
  , installExecutionRolledBackNodeIds :: [Text]
  } deriving (Eq, Show)

instance ToJSON InstallPlanExecutionResult where
  toJSON result =
    object
      [ "planId" .= installExecutionPlanId result
      , "status" .= installExecutionStatus result
      , "results" .= installExecutionResults result
      , "completedNodeIds" .= installExecutionCompletedNodeIds result
      , "failedNodeId" .= installExecutionFailedNodeId result
      , "rolledBackNodeIds" .= installExecutionRolledBackNodeIds result
      ]

installPlanExecutionBatches :: ExecutableInstallPlan -> Either [Text] [[InstallPlanNode]]
installPlanExecutionBatches executablePlan
  | not (null duplicateIds) = Left (map ("duplicate_node_id:" <>) duplicateIds)
  | not (null missingDependencies) = Left (map ("missing_dependency:" <>) missingDependencies)
  | otherwise = buildBatches Set.empty nodes []
  where
    plan = executableTypedPlan executablePlan
    nodes = stableSortPlanNodes executionNodeKey (typedPlanNodes plan)
    nodeIds = map installNodeId nodes
    nodeIdSet = Set.fromList nodeIds
    duplicateIds =
      Set.toList $
        snd $
          foldl
            ( \(seen, duplicates) nodeId ->
                if Set.member nodeId seen
                  then (seen, Set.insert nodeId duplicates)
                  else (Set.insert nodeId seen, duplicates)
            )
            (Set.empty, Set.empty)
            nodeIds
    missingDependencies =
      Set.toList $
        Set.fromList
          [ dependency
          | node <- nodes
          , dependency <- installNodeDependsOn node
          , not (Set.member dependency nodeIdSet)
          ]
    buildBatches completed remaining batches
      | null remaining = Right (reverse batches)
      | null ready = Left ["cycle_detected"]
      | otherwise =
          let phase = installNodePhase (head ready)
              (samePhase, otherReady) = partition ((== phase) . installNodePhase) ready
              nextCompleted = foldr (Set.insert . installNodeId) completed samePhase
              nextRemaining = stableSortPlanNodes executionNodeKey (otherReady <> blocked)
           in buildBatches nextCompleted nextRemaining (samePhase : batches)
      where
        (readyUnsorted, blockedUnsorted) =
          partition
            (\node -> all (`Set.member` completed) (installNodeDependsOn node))
            remaining
        ready = stableSortPlanNodes executionNodeKey readyUnsorted
        blocked = stableSortPlanNodes executionNodeKey blockedUnsorted

executeInstallPlan :: TypedInstallPlan -> (InstallPlanNode -> IO ()) -> (InstallPlanNode -> IO ()) -> (InstallNodeResult -> IO ()) -> IO InstallPlanExecutionResult
executeInstallPlan plan runNode rollbackNode emitResult =
  case classifyTypedInstallPlan plan of
    InstallPlanBlocked blocked ->
      blockedInstallPlanExecutionResult blocked emitResult
    InstallPlanExecutable executable ->
      executeExecutableInstallPlan executable runNode rollbackNode emitResult

blockedInstallPlanExecutionResult :: BlockedInstallPlan -> (InstallNodeResult -> IO ()) -> IO InstallPlanExecutionResult
blockedInstallPlanExecutionResult blocked emitResult = do
  let plan = blockedTypedPlan blocked
      reasons = blockedInstallPlanReasons blocked
      nodes = stableSortPlanNodes executionNodeKey (typedPlanNodes plan)
      results =
        [ InstallNodeResult
            { installResultNodeId = installNodeId node
            , installResultNodeKind = Just (installNodeKind node)
            , installResultPhase = Just (installNodePhase node)
            , installResultTargetPath = installNodeTargetPath node
            , installResultStatus = InstallNodeBlocked
            , installResultMessage = installNodeBlockedReason node <|> listToMaybe reasons
            , installResultDiagnostic =
                nodeDiagnostic node
                  <|> (diagnosticFromBlockedReason "plan" (installNodeKind node) <$> (installNodeBlockedReason node <|> listToMaybe reasons))
            }
        | node <- nodes
        ]
  traverse_ emitResult results
  pure
    InstallPlanExecutionResult
      { installExecutionPlanId = typedPlanId plan
      , installExecutionStatus = "blocked"
      , installExecutionResults = results
      , installExecutionCompletedNodeIds = []
      , installExecutionFailedNodeId = Nothing
      , installExecutionRolledBackNodeIds = []
      }

executeExecutableInstallPlan :: ExecutableInstallPlan -> (InstallPlanNode -> IO ()) -> (InstallPlanNode -> IO ()) -> (InstallNodeResult -> IO ()) -> IO InstallPlanExecutionResult
executeExecutableInstallPlan executablePlan runNode rollbackNode emitResult =
  case installPlanExecutionBatches executablePlan of
        Left errors -> do
          let result =
                InstallNodeResult
                  { installResultNodeId = "plan"
                  , installResultNodeKind = Just "plan"
                  , installResultPhase = Just "plan"
                  , installResultTargetPath = Nothing
                  , installResultStatus = InstallNodeBlocked
                  , installResultMessage = Just (Text.intercalate ", " errors)
                  , installResultDiagnostic =
                      Just $
                        diagnosticWithPlanId
                          (typedPlanId plan)
                          (diagnosticFromBlockedReason "plan" "install plan" (Text.intercalate ", " errors))
                  }
          emitResult result
          pure
            InstallPlanExecutionResult
              { installExecutionPlanId = typedPlanId plan
              , installExecutionStatus = "blocked"
              , installExecutionResults = [result]
              , installExecutionCompletedNodeIds = []
              , installExecutionFailedNodeId = Nothing
              , installExecutionRolledBackNodeIds = []
              }
        Right batches -> executeBatches batches [] []
  where
    plan = executableTypedPlan executablePlan

    executeBatches [] completed results =
      pure
        InstallPlanExecutionResult
          { installExecutionPlanId = typedPlanId plan
          , installExecutionStatus = "succeeded"
          , installExecutionResults = results
          , installExecutionCompletedNodeIds = map installNodeId completed
          , installExecutionFailedNodeId = Nothing
          , installExecutionRolledBackNodeIds = []
          }
    executeBatches (batch:batches) completed results = do
      runningResults <- traverse (emitNodeStatus InstallNodeRunning Nothing Nothing) batch
      nodeResults <- mapConcurrently executeNode batch
      let nextResults = results <> runningResults <> nodeResults
          succeededNodes =
            [ node
            | (node, result) <- zip batch nodeResults
            , installResultStatus result == InstallNodeSucceeded
                || installResultStatus result == InstallNodeSkipped
            ]
          failedNode =
            fst <$> findFirstFailed (zip batch nodeResults)
      case failedNode of
        Nothing -> executeBatches batches (completed <> succeededNodes) nextResults
        Just node -> do
          skippedResults <-
            traverse
              (emitNodeStatus InstallNodeSkipped (Just ("skipped_after_failure:" <> installNodeId node)) Nothing)
              (concat batches)
          rollbackResults <- traverse rollbackExecutedNode (reverse (completed <> succeededNodes))
          pure
            InstallPlanExecutionResult
              { installExecutionPlanId = typedPlanId plan
              , installExecutionStatus =
                  if any ((== InstallNodeRollbackFailed) . installResultStatus) rollbackResults
                    then "rollbackFailed"
                    else "failed"
              , installExecutionResults = nextResults <> skippedResults <> rollbackResults
              , installExecutionCompletedNodeIds = map installNodeId (completed <> succeededNodes)
              , installExecutionFailedNodeId = Just (installNodeId node)
              , installExecutionRolledBackNodeIds =
                  [ installResultNodeId result
                  | result <- rollbackResults
                  , installResultStatus result == InstallNodeRolledBack
                  ]
              }

    executeNode node
      | Just message <- nodeVerificationError node =
          emitNodeStatus InstallNodeFailed (Just message) (Just (diagnosticForNodeMessage node message)) node
      | installNodeAction node == "skip" =
          emitNodeStatus InstallNodeSkipped Nothing Nothing node
      | otherwise = do
          outcome <- try (runNode node)
          case outcome of
            Right () -> emitNodeStatus InstallNodeSucceeded Nothing Nothing node
            Left (err :: SomeException) ->
              let message = Text.pack (displayException err)
               in emitNodeStatus InstallNodeFailed (Just message) (Just (diagnosticForNodeMessage node message)) node

    rollbackExecutedNode node = do
      outcome <- try (rollbackNode node)
      case outcome of
        Right () -> emitNodeStatus InstallNodeRolledBack Nothing Nothing node
        Left (err :: SomeException) ->
          let message = Text.pack (displayException err)
           in emitNodeStatus InstallNodeRollbackFailed (Just message) (Just (diagnosticForNodeMessage node message)) node

    emitNodeStatus status message diagnostic node = do
      let result =
            InstallNodeResult
              { installResultNodeId = installNodeId node
              , installResultNodeKind = Just (installNodeKind node)
              , installResultPhase = Just (installNodePhase node)
              , installResultTargetPath = installNodeTargetPath node
              , installResultStatus = status
              , installResultMessage = message
              , installResultDiagnostic = diagnostic
              }
      emitResult result
      pure result

    diagnosticForNodeMessage node message =
      let base =
            classifyFailure
              FailureInput
                { failurePhase = installNodePhase node
                , failureOperation = installNodeKind node <> ":" <> installNodeAction node
                , failureExceptionText = message
                , failureContext =
                    [ ("nodeId", installNodeId node)
                    , ("nodeKind", installNodeKind node)
                    ]
                      <> maybe [] (\path -> [("filePath", Text.pack path)]) (installNodeTargetPath node)
                , failureTaskId = Nothing
                , failurePlanId = Just (typedPlanId plan)
                , failureSource = Nothing
                }
          withPlan = diagnosticWithPlanId (typedPlanId plan) base
       in maybe withPlan (`diagnosticWithFilePath` withPlan) (installNodeTargetPath node)

findFirstFailed :: [(InstallPlanNode, InstallNodeResult)] -> Maybe (InstallPlanNode, InstallNodeResult)
findFirstFailed =
  listToMaybe . filter ((== InstallNodeFailed) . installResultStatus . snd)

nodeDiagnostic :: InstallPlanNode -> Maybe Diagnostic
nodeDiagnostic node =
  listToMaybe (installNodeDiagnostics node)

nodeVerificationError :: InstallPlanNode -> Maybe Text
nodeVerificationError node =
  listToMaybe
    [ installVerificationKind verification <> maybe "" ((": " <>) ) (installVerificationMessage verification)
    | verification <- installNodeVerifications node
    , installVerificationStatus verification == "error"
    ]

executionNodeKey :: InstallPlanNode -> Text
executionNodeKey node =
  Text.intercalate
    "|"
    [ phaseRankKey (installNodePhase node)
    , installNodePhase node
    , installNodeId node
    ]

phaseRankKey :: Text -> Text
phaseRankKey phase =
  case phase of
    "staging" -> "00"
    "metadata" -> "10"
    "loader" -> "20"
    "libraries" -> "30"
    "runtime" -> "40"
    "assets" -> "50"
    "natives" -> "60"
    "dependencies" -> "70"
    "content" -> "80"
    "files" -> "90"
    "overrides" -> "91"
    "verify" -> "92"
    "commit" -> "99"
    _ -> "98"
