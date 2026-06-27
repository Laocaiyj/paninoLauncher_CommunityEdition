{-# LANGUAGE OverloadedStrings #-}

module Integration.InstallPlanExecutor
  ( assertInstallPlanExecutor
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar
  ( modifyMVar_
  , newMVar
  , readMVar
  )
import Control.Monad (when)
import Data.Maybe (isJust)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Diagnostics.Types (Diagnostic(..))
import Panino.Install.Plan.Executor
  ( InstallNodeResult(..)
  , InstallNodeStatus(..)
  , InstallPlanExecutionResult(..)
  , blockedInstallPlanExecutionResult
  , executeExecutableInstallPlan
  , installPlanExecutionBatches
  )
import Panino.Install.Plan.State
  ( ExecutableInstallPlan
  , requireExecutableInstallPlan
  )
import Panino.Install.Plan.Types
  ( InstallPlanEdge(..)
  , InstallPlanNode(..)
  , InstallPlanRollbackAction(..)
  , InstallPlanSummary(..)
  , InstallVerification(..)
  , TypedInstallPlan(..)
  , finalizeTypedInstallPlan
  )
import TestSupport (assertEqual)

assertInstallPlanExecutor :: IO ()
assertInstallPlanExecutor = do
  let nodeA = executorTestNode "a" "metadata" [] "download"
      nodeC = executorTestNode "c" "metadata" [] "download"
      nodeB = executorTestNode "b" "content" ["a"] "download"
      nodeAfter = executorTestNode "after" "verify" ["b"] "download"
      plan =
        finalizeTypedInstallPlan
          TypedInstallPlan
            { typedPlanId = ""
            , typedPlanFingerprint = ""
            , typedPlanKind = "test"
            , typedPlanTitle = "Executor test"
            , typedPlanTargetGameDir = Just "/tmp/mc"
            , typedPlanSource = Just "test"
            , typedPlanStatus = ""
            , typedPlanSummary = InstallPlanSummary 0 0 0 0 0 Nothing
            , typedPlanNodes = [nodeA, nodeB, nodeC, nodeAfter]
            , typedPlanEdges =
                [ InstallPlanEdge
                    { installEdgeFrom = "a"
                    , installEdgeTo = "b"
                    , installEdgeKind = "requires"
                    , installEdgeRequired = True
                    }
                , InstallPlanEdge
                    { installEdgeFrom = "b"
                    , installEdgeTo = "after"
                    , installEdgeKind = "requires"
                    , installEdgeRequired = True
                    }
                ]
            , typedPlanWarnings = []
            , typedPlanBlockedReasons = []
            , typedPlanDiagnostics = []
            , typedPlanRollbackPolicy = "automatic"
            }
  executablePlan <- requireTestExecutable plan
  assertEqual "executor batches by dependency and phase" (Right [[nodeA, nodeC], [nodeB], [nodeAfter]]) (installPlanExecutionBatches executablePlan)

  events <- newMVar []
  result <-
    executeExecutableInstallPlan
      executablePlan
      ( \node -> do
          modifyMVar_ events (pure . (<> ["run:" <> installNodeId node]))
          when (installNodeId node == "b") (fail "boom")
      )
      (\node -> modifyMVar_ events (pure . (<> ["rollback:" <> installNodeId node])))
      (\_ -> pure ())
  recordedEvents <- readMVar events
  assertEqual "executor stops on failed node" "failed" (installExecutionStatus result)
  assertEqual "executor records failed node" (Just "b") (installExecutionFailedNodeId result)
  assertEqual "executor rolls back completed nodes in reverse" ["rollback:c", "rollback:a"] (filter ("rollback:" `Text.isPrefixOf`) recordedEvents)
  assertEqual "executor does not run successors after failure" True ("run:b" `elem` recordedEvents && not ("run:after" `elem` recordedEvents))
  assertEqual "executor marks successors skipped after failure" [("after", InstallNodeSkipped)] [(installResultNodeId item, installResultStatus item) | item <- installExecutionResults result, installResultNodeId item == "after"]

  let blockedPlan =
        finalizeTypedInstallPlan
          plan
            { typedPlanBlockedReasons = ["blocked_by_test"]
            }
  blockedResult <-
    case requireExecutableInstallPlan blockedPlan of
      Left blocked -> blockedInstallPlanExecutionResult blocked (\_ -> pure ())
      Right _ -> fail "blocked plan unexpectedly classified as executable"
  assertEqual "executor refuses blocked plan" "blocked" (installExecutionStatus blockedResult)
  assertEqual "executor marks nodes blocked" True (all ((== InstallNodeBlocked) . installResultStatus) (installExecutionResults blockedResult))
  assertEqual "executor blocked nodes include diagnostics" True (all (maybe False ((== "blocked_by_test") . diagnosticCode) . installResultDiagnostic) (installExecutionResults blockedResult))
  assertEqual "executor blocked node result includes kind" True (all ((== Just "test") . installResultNodeKind) (installExecutionResults blockedResult))
  assertEqual "executor blocked node result includes phase" True (all (isJust . installResultPhase) (installExecutionResults blockedResult))

  ranInvalid <- newMVar False
  let invalidPlan =
        finalizeTypedInstallPlan
          plan
            { typedPlanNodes =
                [ nodeA
                    { installNodeVerifications =
                        [InstallVerification "urlAllowed" "error" (Just "bad url")]
                    }
                ]
            , typedPlanEdges = []
            }
  invalidResult <-
    do
      invalidExecutablePlan <- requireTestExecutable invalidPlan
      executeExecutableInstallPlan
        invalidExecutablePlan
        (\_ -> modifyMVar_ ranInvalid (const (pure True)))
        (\_ -> pure ())
        (\_ -> pure ())
  invalidRan <- readMVar ranInvalid
  assertEqual "executor validates node before running" False invalidRan
  assertEqual "executor marks verification error failed" "failed" (installExecutionStatus invalidResult)
  assertEqual "executor failed node includes diagnostic" True (any (maybe False ((== "task_failed") . diagnosticCode) . installResultDiagnostic) (installExecutionResults invalidResult))
  assertEqual "executor failed node result includes kind" True (any ((== Just "test") . installResultNodeKind) (installExecutionResults invalidResult))
  assertEqual "executor failed node result includes phase" True (any ((== Just "metadata") . installResultPhase) (installExecutionResults invalidResult))

  let concurrentPlan =
        finalizeTypedInstallPlan
          plan
            { typedPlanNodes =
                [ executorTestNode "slow" "metadata" [] "download"
                , executorTestNode "fast" "metadata" [] "download"
                ]
            , typedPlanEdges = []
            }
  concurrentExecutablePlan <- requireTestExecutable concurrentPlan
  concurrentResult <-
    executeExecutableInstallPlan
      concurrentExecutablePlan
      ( \node ->
          when (installNodeId node == "fast") (threadDelay 1000)
      )
      (\_ -> pure ())
      (\_ -> pure ())
  assertEqual
    "executor result json is ordered by stable batch order"
    ["fast", "slow"]
    [ installResultNodeId item
    | item <- installExecutionResults concurrentResult
    , installResultStatus item == InstallNodeSucceeded
    ]

requireTestExecutable :: TypedInstallPlan -> IO ExecutableInstallPlan
requireTestExecutable plan =
  case requireExecutableInstallPlan plan of
    Right executablePlan -> pure executablePlan
    Left blocked -> fail ("expected executable install plan, got blocked: " <> Text.unpack (Text.intercalate ", " (typedPlanBlockedReasons blockedPlan)))
      where
        blockedPlan = case requireExecutableInstallPlan plan of
          Left blockedAgain -> blockedTypedPlanFallback blockedAgain
          Right _ -> plan

executorTestNode :: Text -> Text -> [Text] -> Text -> InstallPlanNode
executorTestNode nodeId phase dependencies action =
  InstallPlanNode
    { installNodeId = nodeId
    , installNodeKind = "test"
    , installNodeAction = action
    , installNodePhase = phase
    , installNodeLabel = nodeId
    , installNodeTargetPath = Nothing
    , installNodeSourceUrls = []
    , installNodeSha1 = Just nodeId
    , installNodeSize = Nothing
    , installNodeRequired = True
    , installNodeDependsOn = dependencies
    , installNodeVerifications = []
    , installNodeRollback =
        InstallPlanRollbackAction
          { installRollbackAction = "noneWithReason"
          , installRollbackTargetPath = Nothing
          , installRollbackBackupPath = Nothing
          , installRollbackReason = Just "test"
          }
    , installNodeBlockedReason = Nothing
    , installNodeDiagnostics = []
    }
