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
  ( FromJSON(..)
  , Value
  , decode
  , encode
  , object
  , withObject
  , (.:?)
  , (.=)
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as Builder
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import Data.List
  ( intercalate
  , sortOn
  )
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Data.Time
  ( UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Network.HTTP.Types
  ( hCacheControl
  , hContentType
  , status400
  , status200
  , status202
  , status404
  )
import Network.Wai
  ( Request
  , Response
  , queryString
  , responseStream
  , strictRequestBody
  )
import Panino.Api.Response
  ( diagnosticErrorResponse
  , jsonResponse
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

data TaskHistoryClearRequest = TaskHistoryClearRequest
  { clearStatuses :: Maybe [Text]
  , clearOlderThanDays :: Maybe Int
  , clearKeepFailed :: Maybe Bool
  } deriving (Eq, Show)

instance FromJSON TaskHistoryClearRequest where
  parseJSON =
    withObject "TaskHistoryClearRequest" $ \value ->
      TaskHistoryClearRequest
        <$> value .:? "statuses"
        <*> value .:? "olderThanDays"
        <*> value .:? "keepFailed"

tasksResponse :: ServerState -> IO Response
tasksResponse state = do
  taskMap <- readTVarIO (stateTasks state)
  pure (jsonResponse status200 (object ["tasks" .= Map.elems taskMap]))

taskHistoryResponse :: ServerState -> Request -> IO Response
taskHistoryResponse state request = do
  taskMap <- readTVarIO (stateTasks state)
  let query = queryString request
      statusFilters = queryTextList "status" query
      kindFilters = queryTextList "kind" query
      offset = max 0 (queryInt "offset" 0 query)
      limit = min 200 (max 1 (queryInt "limit" 50 query))
      filtered =
        filter (matchesFilters statusFilters kindFilters) $
          sortOn (Down . taskSnapshotUpdatedAt) (Map.elems taskMap)
      page = take limit (drop offset filtered)
  pure
    ( jsonResponse
        status200
        ( object
            [ "tasks" .= page
            , "totalCount" .= length filtered
            , "offset" .= offset
            , "limit" .= limit
            ]
        )
    )

clearTaskHistoryResponse :: ServerState -> Request -> IO Response
clearTaskHistoryResponse state request = do
  body <- strictRequestBody request
  case decode body of
    Nothing ->
      pure
        ( diagnosticErrorResponse
            status400
            "invalid_clear_request"
            (Diagnostics.diagnosticForApiError "metadata_parse_failed" "diagnostic" "invalid clear task history request JSON")
        )
    Just clearRequest -> do
      now <- getCurrentTime
      let statusFilters = fromMaybe terminalStatusTexts (clearStatuses clearRequest)
          keepFailed = fromMaybe False (clearKeepFailed clearRequest)
          maxAgeDays = clearOlderThanDays clearRequest
          shouldClear task =
            taskStateTextLocal (taskSnapshotState task) `elem` statusFilters
              && maybe True (isOlderThanDays now task) maxAgeDays
              && not (keepFailed && taskSnapshotState task == TaskFailed)
          isActiveClearCandidate task =
            taskSnapshotState task `elem` [TaskQueued, TaskRunning]
              && taskStateTextLocal (taskSnapshotState task) `elem` statusFilters
              && maybe True (isOlderThanDays now task) maxAgeDays
      (deletedCount, keptCount, skippedActiveCount) <- atomically $ do
        taskMap <- readTVar (stateTasks state)
        let tasks = Map.elems taskMap
            skippedActive = length (filter isActiveClearCandidate tasks)
            deleted =
              filter
                (\task -> shouldClear task && taskSnapshotState task `notElem` [TaskQueued, TaskRunning])
                tasks
            remaining =
              Map.filter
                (\task -> not (shouldClear task && taskSnapshotState task `notElem` [TaskQueued, TaskRunning]))
                taskMap
        writeTVar (stateTasks state) remaining
        pure (length deleted, Map.size remaining, skippedActive)
      persistTaskHistory state
      pure
        ( jsonResponse
            status200
            ( object
                [ "deleted" .= deletedCount
                , "kept" .= keptCount
                , "skippedActive" .= skippedActiveCount
                ]
            )
        )

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

matchesFilters :: [Text] -> [Text] -> TaskSnapshot -> Bool
matchesFilters statusFilters kindFilters task =
  statusMatches && kindMatches
  where
    statusMatches =
      null statusFilters
        || taskStateTextLocal (taskSnapshotState task) `elem` statusFilters
    kindMatches =
      null kindFilters
        || taskSnapshotKind task `elem` kindFilters

queryTextList :: BS.ByteString -> [(BS.ByteString, Maybe BS.ByteString)] -> [Text]
queryTextList key query =
  case lookup key query of
    Nothing -> []
    Just Nothing -> []
    Just (Just raw) ->
      filter (not . Text.null) $
        Text.splitOn "," (Text.decodeUtf8 raw)

queryInt :: BS.ByteString -> Int -> [(BS.ByteString, Maybe BS.ByteString)] -> Int
queryInt key fallback query =
  case lookup key query of
    Just (Just raw) ->
      case reads (BS8.unpack raw) of
        (value, _) : _ -> value
        [] -> fallback
    _ -> fallback

terminalStatusTexts :: [Text]
terminalStatusTexts =
  ["succeeded", "failed", "cancelled"]

taskStateTextLocal :: TaskState -> Text
taskStateTextLocal TaskQueued = "queued"
taskStateTextLocal TaskRunning = "running"
taskStateTextLocal TaskSucceeded = "succeeded"
taskStateTextLocal TaskFailed = "failed"
taskStateTextLocal TaskCancelled = "cancelled"

isOlderThanDays :: UTCTime -> TaskSnapshot -> Int -> Bool
isOlderThanDays now task days =
  realToFrac (diffUTCTime now basis) >= (fromIntegral days * 86400 :: Double)
  where
    basis = fromMaybe (taskSnapshotUpdatedAt task) (taskSnapshotFinishedAt task)

persistTaskHistory :: ServerState -> IO ()
persistTaskHistory state = do
  taskMap <- readTVarIO (stateTasks state)
  BL.writeFile (stateTaskHistoryPath state) (encode (Map.elems taskMap))

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
