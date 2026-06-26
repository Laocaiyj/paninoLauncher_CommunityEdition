{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Tasks
  ( cancelTaskResponse
  , clearTaskHistoryResponse
  , emitTaskProgress
  , eventsResponse
  , shutdownResponse
  , startTask
  , startTaskWithGameDir
  , startTaskWithGameDirContext
  , startTaskWithGameDirContextAndComponents
  , taskIsCancelled
  , taskHistoryResponse
  , taskResponse
  , tasksResponse
  ) where

import Control.Concurrent.Async
  ( async
  , cancel
  )
import Control.Concurrent.MVar
  ( newEmptyMVar
  , putMVar
  , readMVar
  )
import Control.Concurrent.STM
  ( atomically
  , modifyTVar'
  , readTChan
  , readTVar
  , readTVarIO
  , writeTVar
  )
import Control.Applicative ((<|>))
import Control.Exception
  ( SomeException
  , finally
  , try
  )
import Control.Monad
  ( forever
  , unless
  , when
  )
import Data.Aeson
  ( Value
  , encode
  , object
  , (.=)
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as Builder
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import Data.List (intercalate)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Data.Time (getCurrentTime)
import Network.HTTP.Types
  ( hCacheControl
  , hContentType
  , status200
  , status202
  , status404
  )
import Network.Wai
  ( Response
  , responseStream
  )
import Panino.Api.Response
  ( diagnosticErrorResponse
  , jsonResponse
  )
import Panino.Api.Routes.Tasks.History
  ( clearTaskHistoryResponse
  , persistTaskHistory
  , taskHistoryResponse
  )
import Panino.Api.Routes.Tasks.Progress
  ( monotonicTaskProgress
  , taskProgressPayload
  , terminalProgress
  )
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( ApiEvent(..)
  , TaskAccepted(..)
  , TaskProgress(..)
  , TaskSnapshot(..)
  , TaskState(..)
  )
import qualified Panino.Diagnostics.Classify as Diagnostics
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , diagnosticWithTaskId
  )
import Panino.Events.Bus
  ( publishEvent
  , subscribeEvents
  )

tasksResponse :: ServerState -> IO Response
tasksResponse state = do
  taskMap <- readTVarIO (stateTasks state)
  pure (jsonResponse status200 (object ["tasks" .= Map.elems taskMap]))

taskResponse :: ServerState -> [Text] -> IO Response
taskResponse state [taskId] = do
  taskMap <- readTVarIO (stateTasks state)
  case Map.lookup taskId taskMap of
    Just task ->
      pure (jsonResponse status200 task)
    Nothing ->
      pure
        ( diagnosticErrorResponse
            status404
            "task_not_found"
            (Diagnostics.diagnosticForApiError "task_not_found" "diagnostic" ("taskId=" <> taskId))
        )
taskResponse _ _ =
  pure
    ( diagnosticErrorResponse
        status404
        "not_found"
        (Diagnostics.diagnosticForApiError "not_found" "diagnostic" "task route not found")
    )

cancelTaskResponse :: ServerState -> [Text] -> IO Response
cancelTaskResponse state [taskId, "cancel"] = do
  taskMap <- readTVarIO (stateTasks state)
  case Map.lookup taskId taskMap of
    Nothing ->
      pure
        ( diagnosticErrorResponse
            status404
            "task_not_found"
            (Diagnostics.diagnosticForApiError "task_not_found" "diagnostic" ("taskId=" <> taskId))
        )
    Just task
      | taskSnapshotState task `elem` [TaskSucceeded, TaskFailed, TaskCancelled] ->
          pure (jsonResponse status200 (TaskAccepted task))
      | otherwise -> do
          setTaskState state task TaskCancelled (Just "Task was cancelled.") Nothing Nothing Nothing
          handleMap <- readTVarIO (stateTaskHandles state)
          case Map.lookup taskId handleMap of
            Just handle -> cancel handle
            Nothing -> pure ()
          updated <- lookupTask state taskId
          pure (jsonResponse status202 (TaskAccepted (fromMaybe task updated)))
cancelTaskResponse _ _ =
  pure
    ( diagnosticErrorResponse
        status404
        "not_found"
        (Diagnostics.diagnosticForApiError "not_found" "diagnostic" "task cancel route not found")
    )

shutdownResponse :: ServerState -> IO Response
shutdownResponse state = do
  now <- getCurrentTime
  publishEvent
    (stateEvents state)
    ApiEvent
      { apiEventType = "core.shutdown"
      , apiEventTaskId = Nothing
      , apiEventVersion = Nothing
      , apiEventMessage = "shutdown requested"
      , apiEventAt = now
      , apiEventPayload = object []
      }
  _ <- async (stateShutdown state)
  pure (jsonResponse status200 (object ["status" .= ("shutting_down" :: Text)]))

eventsResponse :: ServerState -> Response
eventsResponse state =
  responseStream
    status200
    [ (hContentType, "text/event-stream")
    , (hCacheControl, "no-cache")
    ]
    $ \send flush -> do
      now <- getCurrentTime
      sendEvent send
        ApiEvent
          { apiEventType = "events.connected"
          , apiEventTaskId = Nothing
          , apiEventVersion = Nothing
          , apiEventMessage = "connected"
          , apiEventAt = now
          , apiEventPayload = object []
          }
      flush
      channel <- atomically (subscribeEvents (stateEvents state))
      forever $ do
        event <- atomically (readTChan channel)
        sendEvent send event
        flush

startTask :: ServerState -> Text -> Text -> IO Text -> IO TaskSnapshot
startTask state kind versionId =
  startTaskWithGameDir state kind versionId Nothing

startTaskWithGameDir :: ServerState -> Text -> Text -> Maybe FilePath -> IO Text -> IO TaskSnapshot
startTaskWithGameDir state kind versionId gameDir action =
  startTaskWithGameDirContext state kind versionId gameDir (const action)

startTaskWithGameDirContext :: ServerState -> Text -> Text -> Maybe FilePath -> (TaskSnapshot -> IO Text) -> IO TaskSnapshot
startTaskWithGameDirContext state kind versionId gameDir =
  startTaskWithGameDirContextAndComponents state kind versionId gameDir Nothing Nothing

startTaskWithGameDirContextAndComponents :: ServerState -> Text -> Text -> Maybe FilePath -> Maybe Text -> Maybe Text -> (TaskSnapshot -> IO Text) -> IO TaskSnapshot
startTaskWithGameDirContextAndComponents state kind versionId gameDir requestedLoader requestedShaderLoader action = do
  now <- getCurrentTime
  taskId <- nextTaskId state kind
  let task =
        TaskSnapshot
          { taskSnapshotId = taskId
          , taskSnapshotKind = kind
          , taskSnapshotVersion = versionId
          , taskSnapshotGameDir = gameDir
          , taskSnapshotRequestedLoader = requestedLoader
          , taskSnapshotRequestedShaderLoader = requestedShaderLoader
          , taskSnapshotState = TaskQueued
          , taskSnapshotMessage = Just "queued"
          , taskSnapshotErrorCode = Nothing
          , taskSnapshotErrorDetail = Nothing
          , taskSnapshotDiagnostic = Nothing
          , taskSnapshotDiagnostics = []
          , taskSnapshotCreatedAt = now
          , taskSnapshotUpdatedAt = now
          , taskSnapshotFinishedAt = Nothing
          , taskSnapshotProgress = Nothing
          }
  atomically (modifyTVar' (stateTasks state) (Map.insert taskId task))
  emitTaskEvent state "task.queued" task "queued" (object ["state" .= TaskQueued])
  startGate <- newEmptyMVar
  handle <- async (readMVar startGate >> runTask state task (action task))
  atomically (modifyTVar' (stateTaskHandles state) (Map.insert taskId handle))
  putMVar startGate ()
  pure task

emitTaskProgress :: ServerState -> TaskSnapshot -> TaskProgress -> IO ()
emitTaskProgress state task progress = do
  now <- getCurrentTime
  (updated, nextProgress) <- atomically $ do
    taskMap <- readTVar (stateTasks state)
    let current = fromMaybe task (Map.lookup (taskSnapshotId task) taskMap)
        persistedProgress = monotonicTaskProgress (taskSnapshotProgress current) progress
        next =
          current
            { taskSnapshotProgress = Just persistedProgress
            , taskSnapshotMessage = Just (taskProgressCurrentLabel persistedProgress)
            , taskSnapshotUpdatedAt = now
            }
    writeTVar (stateTasks state) (Map.insert (taskSnapshotId task) next taskMap)
    pure (next, persistedProgress)
  emitTaskEvent
    state
    "task.progress"
    updated
    (taskProgressCurrentLabel nextProgress)
    (taskProgressPayload nextProgress)

runTask :: ServerState -> TaskSnapshot -> IO Text -> IO ()
runTask state task action =
  runTaskBody `finally` removeTaskHandle state task
  where
    runTaskBody = do
      cancelledBeforeStart <- taskIsCancelled state task
      unless cancelledBeforeStart $ do
        setTaskState state task TaskRunning (Just "running") Nothing Nothing Nothing
        result <- try action
        cancelledAfterRun <- taskIsCancelled state task
        unless cancelledAfterRun $
          case result of
            Right message ->
              setTaskState state task TaskSucceeded (Just message) Nothing Nothing Nothing
            Left err -> do
              let diagnostic =
                    diagnosticWithTaskId
                      (taskSnapshotId task)
                      (Diagnostics.classifyException (taskSnapshotKind task) (err :: SomeException))
              setTaskState
                state
                task
                TaskFailed
                (Just (diagnosticMessage diagnostic))
                (Just (diagnosticCode diagnostic))
                (diagnosticDeveloperDetail diagnostic)
                (Just diagnostic)

setTaskState :: ServerState -> TaskSnapshot -> TaskState -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe Diagnostic -> IO ()
setTaskState state task taskState message errorCode errorDetail diagnostic = do
  now <- getCurrentTime
  updated <- atomically $ do
    taskMap <- readTVar (stateTasks state)
    let current = fromMaybe task (Map.lookup (taskSnapshotId task) taskMap)
        nextMessage = message <|> (diagnosticMessage <$> diagnostic)
        nextErrorCode = errorCode <|> (diagnosticCode <$> diagnostic)
        nextErrorDetail = errorDetail <|> (diagnosticDeveloperDetail =<< diagnostic)
        nextDiagnostics =
          case diagnostic of
            Just item -> [item]
            Nothing -> taskSnapshotDiagnostics current
        next =
          current
            { taskSnapshotState = taskState
            , taskSnapshotMessage = nextMessage
            , taskSnapshotErrorCode = nextErrorCode
            , taskSnapshotErrorDetail = nextErrorDetail
            , taskSnapshotDiagnostic = diagnostic <|> taskSnapshotDiagnostic current
            , taskSnapshotDiagnostics = nextDiagnostics
            , taskSnapshotUpdatedAt = now
            , taskSnapshotFinishedAt =
                if taskState `elem` [TaskSucceeded, TaskFailed, TaskCancelled]
                  then Just now
                  else taskSnapshotFinishedAt current
            , taskSnapshotProgress = terminalProgress current taskState nextMessage
            }
    writeTVar (stateTasks state) (Map.insert (taskSnapshotId task) next taskMap)
    pure next
  when (isTerminalTaskState taskState) (persistTaskHistory state)
  case diagnostic of
    Just item ->
      emitTaskEvent
        state
        "task.diagnostic"
        updated
        (diagnosticMessage item)
        (object ["diagnostic" .= item])
    Nothing -> pure ()
  emitTaskEvent
    state
    ("task." <> stateEventSuffix taskState)
    updated
    (fromMaybe "" (taskSnapshotMessage updated))
    (taskEventPayload taskState (taskSnapshotErrorCode updated) (taskSnapshotErrorDetail updated) (taskSnapshotDiagnostic updated) (taskSnapshotDiagnostics updated))

taskIsCancelled :: ServerState -> TaskSnapshot -> IO Bool
taskIsCancelled state task = do
  taskMap <- readTVarIO (stateTasks state)
  pure (maybe False ((== TaskCancelled) . taskSnapshotState) (Map.lookup (taskSnapshotId task) taskMap))

lookupTask :: ServerState -> Text -> IO (Maybe TaskSnapshot)
lookupTask state taskId =
  Map.lookup taskId <$> readTVarIO (stateTasks state)

removeTaskHandle :: ServerState -> TaskSnapshot -> IO ()
removeTaskHandle state task =
  atomically (modifyTVar' (stateTaskHandles state) (Map.delete (taskSnapshotId task)))

taskEventPayload :: TaskState -> Maybe Text -> Maybe Text -> Maybe Diagnostic -> [Diagnostic] -> Value
taskEventPayload taskState errorCode errorDetail diagnostic diagnostics =
  object $
    ["state" .= taskState]
      <> maybe [] (\code -> ["errorCode" .= code]) errorCode
      <> maybe [] (\detail -> ["errorDetail" .= detail]) errorDetail
      <> maybe [] (\item -> ["diagnostic" .= item]) diagnostic
      <> if null diagnostics then [] else ["diagnostics" .= diagnostics]

nextTaskId :: ServerState -> Text -> IO Text
nextTaskId state kind =
  atomically $ do
    current <- readTVar (stateNextTaskId state)
    writeTVar (stateNextTaskId state) (current + 1)
    pure (kind <> "-" <> Text.pack (show current))

stateEventSuffix :: TaskState -> Text
stateEventSuffix TaskQueued = "queued"
stateEventSuffix TaskRunning = "started"
stateEventSuffix TaskSucceeded = "succeeded"
stateEventSuffix TaskFailed = "failed"
stateEventSuffix TaskCancelled = "cancelled"

isTerminalTaskState :: TaskState -> Bool
isTerminalTaskState taskState =
  taskState `elem` [TaskSucceeded, TaskFailed, TaskCancelled]

emitTaskEvent :: ServerState -> Text -> TaskSnapshot -> Text -> Value -> IO ()
emitTaskEvent state eventType task message payload = do
  now <- getCurrentTime
  publishEvent
    (stateEvents state)
    ApiEvent
      { apiEventType = eventType
      , apiEventTaskId = Just (taskSnapshotId task)
      , apiEventVersion = Just (taskSnapshotVersion task)
      , apiEventMessage = message
      , apiEventAt = now
      , apiEventPayload = payload
      }

sendEvent :: (Builder.Builder -> IO ()) -> ApiEvent -> IO ()
sendEvent send event = do
  send (Builder.byteString "event: ")
  send (Builder.byteString (Text.encodeUtf8 (apiEventType event)))
  send (Builder.byteString "\n")
  send (Builder.byteString "data: ")
  send (Builder.byteString (oneLineJson (encode event)))
  send (Builder.byteString "\n\n")

oneLineJson :: BL.ByteString -> BS.ByteString
oneLineJson =
  BS8.pack . intercalate "\\n" . lines . BS8.unpack . BL.toStrict
