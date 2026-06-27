{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Content.Task
  ( contentDownloadJobsFromTypedPlan
  , runContentInstallTask
  ) where

import Control.Applicative ((<|>))
import Control.Exception (SomeException, catch, throwIO, try)
import Control.Monad (unless, void, when)
import Data.Aeson (encode, object, (.=))
import qualified Data.ByteString.Lazy as BL
import Data.Foldable (traverse_)
import Data.List (elemIndex, find)
import Data.Maybe (fromMaybe, listToMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (getCurrentTime)
import Panino.Api.Routes.Content.InstallPlan (ContentInstallPlanBundle(..))
import Panino.Api.Routes.Tasks (emitTaskProgress, taskIsCancelled)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
import Panino.Core.Types
  ( sha1FromText
  , urlFromText
  )
import Panino.Download.Manager (DownloadHostTelemetry(..), DownloadJob(..), DownloadMultipartTelemetry(..), DownloadOptions, DownloadProgress(..), downloadOptionsWithOverrides, runDownloadJobsWithOptionsAndProgressAndCancel)
import Panino.Install.Plan.Executor (InstallNodeResult(..), InstallNodeStatus(..), InstallPlanExecutionResult(..), executeInstallPlan, installNodeStatusText)
import Panino.Minecraft.InstallPlanGraph (dedupeInstallPlanJobs)
import qualified Panino.Install.Plan.Types as Plan
import System.Directory (createDirectoryIfMissing, doesFileExist, removeFile, renameFile)
import System.FilePath (takeDirectory, (</>))

runContentInstallTask :: ServerState -> TaskSnapshot -> ContentInstallRequest -> ContentInstallPlanBundle -> IO Text
runContentInstallTask state task request planBundle = do
  let plan = contentPlanBundleResponse planBundle
  unless (null (contentPlanBlockedReasons plan)) $
    fail ("install plan blocked: " <> Text.unpack (Text.intercalate ", " (contentPlanBlockedReasons plan)))
  createDirectoryIfMissing True (contentPlanTargetDir plan)
  withContentBackups (contentPlanFiles plan) $ do
    let typedPlan = contentPlanTypedPlan plan
        plannedDownloadCount = length (contentDownloadJobsFromTypedPlan plan)
    createDirectoryIfMissing True (takeDirectory (contentInstallPlanGraphPath request plan))
    BL.writeFile (contentInstallPlanGraphPath request plan) (encode typedPlan)
    putStrLn
      ( "install_plan_graph"
          <> " plan_id="
          <> Text.unpack (Plan.typedPlanId typedPlan)
          <> " nodes="
          <> show (length (Plan.typedPlanNodes typedPlan))
          <> " phase=content"
      )
    execution <-
      executeInstallPlan
        typedPlan
        (runContentPlanNode state task request)
        rollbackContentPlanNode
        (emitContentPlanNodeProgress state task typedPlan)
    let executionPath = contentInstallExecutionPath request plan
        lockfilePath = contentInstallLockfilePath request plan
    writeContentInstallExecution executionPath execution
    unless (installExecutionStatus execution == "succeeded") $
      fail ("install plan execution failed: " <> Text.unpack (installExecutionStatus execution) <> ". Execution: " <> executionPath)
    writeContentInstallLockfile request plan typedPlan execution lockfilePath
    pure
      ( Text.pack
          ( "installed "
              <> Text.unpack (contentInstallProjectTitle request)
              <> " into "
              <> contentPlanTargetDir plan
              <> " with "
              <> show plannedDownloadCount
              <> " checked files"
              <> ". Rollback record: "
              <> lockfilePath
              <> ". Plan: "
              <> contentInstallPlanGraphPath request plan
              <> ". Execution: "
              <> executionPath
          )
      )

runContentPlanNode :: ServerState -> TaskSnapshot -> ContentInstallRequest -> Plan.InstallPlanNode -> IO ()
runContentPlanNode state task request node
  | Plan.installNodeAction node `elem` ["keep", "verify"] = pure ()
  | Plan.installNodeAction node `elem` ["download", "replace"] =
      case downloadJobFromPlanNode node of
        Nothing -> fail ("plan node is missing download data: " <> Text.unpack (Plan.installNodeId node))
        Just job ->
          void $
            runDownloadJobsWithOptionsAndProgressAndCancel
              (stateHttpManager state)
              (downloadOptionsFromRuntime (contentInstallDownload request))
              (taskIsCancelled state task)
              [job]
              (emitDownloadProgress state task)
  | otherwise = pure ()

rollbackContentPlanNode :: Plan.InstallPlanNode -> IO ()
rollbackContentPlanNode node =
  case Plan.installRollbackAction rollback of
    "removeCreatedFile" ->
      traverse_ removeIfExists (Plan.installRollbackTargetPath rollback)
    "restoreBackup" ->
      case (Plan.installRollbackTargetPath rollback, Plan.installRollbackBackupPath rollback) of
        (Just target, Just backup) -> restoreBackup (target, backup)
        _ -> pure ()
    _ -> pure ()
  where
    rollback = Plan.installNodeRollback node

downloadJobFromPlanNode :: Plan.InstallPlanNode -> Maybe DownloadJob
downloadJobFromPlanNode node = do
  targetPath <- Plan.installNodeTargetPath node
  url <- listToMaybe (Plan.installNodeSourceUrls node)
  pure
    DownloadJob
      { jobLabel = Text.unpack (Plan.installNodeLabel node)
      , jobUrl = urlFromText url
      , jobTargetPath = targetPath
      , jobSha1 = Plan.installNodeSha1 node >>= sha1FromText
      , jobSize = Plan.installNodeSize node
      }

emitContentPlanNodeProgress :: ServerState -> TaskSnapshot -> Plan.TypedInstallPlan -> InstallNodeResult -> IO ()
emitContentPlanNodeProgress state task typedPlan result =
  emitTaskProgress state task progress
  where
    nodes = Plan.typedPlanNodes typedPlan
    nodeIds = map Plan.installNodeId nodes
    phaseCount = max 1 (length nodes)
    nodeIndex = fromMaybe 0 (elemIndex (installResultNodeId result) nodeIds)
    phaseIndex = min phaseCount (nodeIndex + 1)
    completedIndex =
      case installResultStatus result of
        InstallNodeRunning -> nodeIndex
        _ -> min phaseCount (nodeIndex + 1)
    currentLabel =
      fromMaybe (installResultNodeId result) $
        Plan.installNodeLabel <$> find ((== installResultNodeId result) . Plan.installNodeId) nodes
    percent =
      Just (fromIntegral completedIndex * 100 / fromIntegral phaseCount)
    progress =
      TaskProgress
        { taskProgressTaskId = taskSnapshotId task
        , taskProgressPhaseId = "install-plan"
        , taskProgressPhaseTitle = "Execute install plan"
        , taskProgressPhaseIndex = phaseIndex
        , taskProgressPhaseCount = phaseCount
        , taskProgressPhasePercent = percent
        , taskProgressOverallPercent = percent
        , taskProgressCompletedJobs = completedIndex
        , taskProgressTotalJobs = phaseCount
        , taskProgressCompletedBytes = 0
        , taskProgressTotalBytes = fromMaybe 0 (Plan.installSummaryEstimatedBytes (Plan.typedPlanSummary typedPlan))
        , taskProgressSpeedBytesPerSecond = 0
        , taskProgressMovingAverageSpeedBytesPerSecond = 0
        , taskProgressEtaSeconds = Nothing
        , taskProgressCurrentLabel = currentLabel <> " " <> installNodeStatusText (installResultStatus result)
        , taskProgressActiveWorkers = if installResultStatus result == InstallNodeRunning then 1 else 0
        , taskProgressRetryCount = 0
        , taskProgressSourceHost = Nothing
        , taskProgressHosts = []
        , taskProgressThrottleReason = Nothing
        , taskProgressMultipart = Nothing
        }

contentInstallPlanGraphPath :: ContentInstallRequest -> ContentInstallPlanResponse -> FilePath
contentInstallPlanGraphPath request plan =
  case contentInstallGameDir request of
    Just gameDir -> gameDir </> "downloads" </> "install-plan-graph.json"
    Nothing -> contentPlanTargetDir plan </> "install-plan-graph.json"

contentInstallExecutionPath :: ContentInstallRequest -> ContentInstallPlanResponse -> FilePath
contentInstallExecutionPath request plan =
  case contentInstallGameDir request of
    Just gameDir -> gameDir </> "downloads" </> "install-plan-execution.json"
    Nothing -> contentPlanTargetDir plan </> "install-plan-execution.json"

contentInstallLockfilePath :: ContentInstallRequest -> ContentInstallPlanResponse -> FilePath
contentInstallLockfilePath request plan =
  case contentInstallGameDir request of
    Just gameDir -> gameDir </> "downloads" </> "content-install-lock.json"
    Nothing -> contentPlanTargetDir plan </> "content-install-lock.json"

writeContentInstallExecution :: FilePath -> InstallPlanExecutionResult -> IO ()
writeContentInstallExecution executionPath execution = do
  createDirectoryIfMissing True (takeDirectory executionPath)
  BL.writeFile executionPath (encode execution)

writeContentInstallLockfile :: ContentInstallRequest -> ContentInstallPlanResponse -> Plan.TypedInstallPlan -> InstallPlanExecutionResult -> FilePath -> IO ()
writeContentInstallLockfile request plan typedPlan execution lockfilePath = do
  now <- getCurrentTime
  createDirectoryIfMissing True (takeDirectory lockfilePath)
  BL.writeFile
    lockfilePath
    ( encode $
        object
          [ "installedAt" .= now
          , "title" .= contentPlanProjectTitle plan
          , "source" .= contentPlanSource plan
          , "projectId" .= contentPlanProjectId plan
          , "releaseId" .= contentPlanReleaseId plan
          , "targetDir" .= contentPlanTargetDir plan
          , "targetSubdir" .= contentInstallTargetSubdir request
          , "planId" .= Plan.typedPlanId typedPlan
          , "fingerprint" .= Plan.typedPlanFingerprint typedPlan
          , "rollbackPolicy" .= Plan.typedPlanRollbackPolicy typedPlan
          , "planPath" .= contentInstallPlanGraphPath request plan
          , "executionPath" .= contentInstallExecutionPath request plan
          , "files" .= contentPlanFiles plan
          , "dependencies" .= contentPlanDependencies plan
          , "execution" .= execution
          , "rollback" .= ("Use this record with the plan and execution file to remove created files or restore backup targets when rollback is supported." :: Text)
          ]
    )

downloadOptionsFromRuntime :: DownloadRuntimeOptions -> DownloadOptions
downloadOptionsFromRuntime options =
  downloadOptionsWithOverrides
    (strategyConcurrency options)
    (strategyRetryCount options)

strategyConcurrency :: DownloadRuntimeOptions -> Maybe Int
strategyConcurrency options =
  case normalizeDownloadStrategy <$> downloadRuntimeStrategy options of
    Just "fast" -> Just (max 48 (fromMaybe 32 (downloadRuntimeConcurrency options)))
    Just "conservative" -> Just (min 12 (fromMaybe 12 (downloadRuntimeConcurrency options)))
    _ -> downloadRuntimeConcurrency options

strategyRetryCount :: DownloadRuntimeOptions -> Maybe Int
strategyRetryCount options =
  case normalizeDownloadStrategy <$> downloadRuntimeStrategy options of
    Just "fast" -> Just (max 4 (fromMaybe 3 (downloadRuntimeRetryCount options)))
    Just "conservative" -> Just (max 2 (fromMaybe 2 (downloadRuntimeRetryCount options)))
    _ -> downloadRuntimeRetryCount options

normalizeDownloadStrategy :: Text -> Text
normalizeDownloadStrategy =
  Text.toLower . Text.replace "-" "" . Text.replace "_" ""

emitDownloadProgress :: ServerState -> TaskSnapshot -> DownloadProgress -> IO ()
emitDownloadProgress state task progress =
  emitTaskProgress
    state
    task
    (taskProgressFromDownload task "content" "Download content" 1 1 progress)

taskProgressFromDownload :: TaskSnapshot -> Text -> Text -> Int -> Int -> DownloadProgress -> TaskProgress
taskProgressFromDownload task phaseId phaseTitle phaseIndex phaseCount progress =
  TaskProgress
    { taskProgressTaskId = taskSnapshotId task
    , taskProgressPhaseId = phaseId
    , taskProgressPhaseTitle = phaseTitle
    , taskProgressPhaseIndex = phaseIndex
    , taskProgressPhaseCount = phaseCount
    , taskProgressPhasePercent = progressPercent progress
    , taskProgressOverallPercent = progressPercent progress
    , taskProgressCompletedJobs = progressCompletedJobs progress
    , taskProgressTotalJobs = progressTotalJobs progress
    , taskProgressCompletedBytes = progressCompletedBytes progress
    , taskProgressTotalBytes = progressTotalBytes progress
    , taskProgressSpeedBytesPerSecond = progressSpeedBytesPerSecond progress
    , taskProgressMovingAverageSpeedBytesPerSecond = progressMovingAverageSpeedBytesPerSecond progress
    , taskProgressEtaSeconds = progressEtaSeconds progress
    , taskProgressCurrentLabel = Text.pack (progressLabel progress)
    , taskProgressActiveWorkers = progressActiveWorkers progress
    , taskProgressRetryCount = progressRetryCount progress
    , taskProgressSourceHost = progressHost progress <|> progressSource progress
    , taskProgressHosts = map taskProgressHostFromDownload (progressHostTelemetry progress)
    , taskProgressThrottleReason = progressThrottleReason progress
    , taskProgressMultipart = taskProgressMultipartFromDownload <$> progressMultipartTelemetry progress
    }

taskProgressHostFromDownload :: DownloadHostTelemetry -> TaskProgressHost
taskProgressHostFromDownload host =
  TaskProgressHost
    { taskProgressHostHost = hostTelemetryHost host
    , taskProgressHostLane = hostTelemetryLane host
    , taskProgressHostActiveConnections = hostTelemetryActiveConnections host
    , taskProgressHostGate = hostTelemetryGate host
    , taskProgressHostMaxGate = hostTelemetryMaxGate host
    , taskProgressHostBytesPerSecond = hostTelemetryBytesPerSecond host
    , taskProgressHostCompletedBytes = hostTelemetryCompletedBytes host
    , taskProgressHostCompletedJobs = hostTelemetryCompletedJobs host
    , taskProgressHostRetryCount = hostTelemetryRetryCount host
    }

taskProgressMultipartFromDownload :: DownloadMultipartTelemetry -> TaskProgressMultipart
taskProgressMultipartFromDownload multipart =
  TaskProgressMultipart
    { taskProgressMultipartLabel = multipartTelemetryLabel multipart
    , taskProgressMultipartCompletedSegments = multipartTelemetryCompletedSegments multipart
    , taskProgressMultipartTotalSegments = multipartTelemetryTotalSegments multipart
    , taskProgressMultipartActiveSegments = multipartTelemetryActiveSegments multipart
    , taskProgressMultipartSegmentBytes = multipartTelemetrySegmentBytes multipart
    , taskProgressMultipartTotalBytes = multipartTelemetryTotalBytes multipart
    , taskProgressMultipartCurrentSegment = multipartTelemetryCurrentSegment multipart
    }

contentDownloadJobsFromTypedPlan :: ContentInstallPlanResponse -> [DownloadJob]
contentDownloadJobsFromTypedPlan plan =
  dedupeInstallPlanJobs $
    [ job
    | node <- Plan.typedPlanNodes (contentPlanTypedPlan plan)
    , Plan.installNodeAction node `elem` ["download", "replace"]
    , Just job <- [downloadJobFromPlanNode node]
    ]

withContentBackups :: [ContentInstallPlanFile] -> IO Text -> IO Text
withContentBackups files action = do
  backups <- traverse backupContentFile (filter ((== "replace") . contentPlanFileAction) files)
  result <- try action
  case result of
    Right value -> do
      traverse_ (removeIfExists . snd) backups
      pure value
    Left err -> do
      traverse_ restoreBackup backups
      throwIO (err :: SomeException)

backupContentFile :: ContentInstallPlanFile -> IO (FilePath, FilePath)
backupContentFile file = do
  let target = contentPlanTargetPath file
      backup = target <> ".panino-backup"
  exists <- doesFileExist target
  if exists
    then do
      removeIfExists backup
      renameFile target backup
      pure (target, backup)
    else pure (target, backup)

restoreBackup :: (FilePath, FilePath) -> IO ()
restoreBackup (target, backup) = do
  backupExists <- doesFileExist backup
  when backupExists $ do
    removeIfExists target
    renameFile backup target

removeIfExists :: FilePath -> IO ()
removeIfExists path =
  removeFile path `catch` \(_ :: SomeException) -> pure ()
