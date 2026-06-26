{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Tasks.History
  ( clearTaskHistoryResponse
  , persistTaskHistory
  , taskHistoryResponse
  ) where

import Control.Concurrent.STM
  ( atomically
  , readTVar
  , readTVarIO
  , writeTVar
  )
import Data.Aeson
  ( FromJSON(..)
  , decode
  , encode
  , object
  , withObject
  , (.:?)
  , (.=)
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import Data.List (sortOn)
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
  ( status200
  , status400
  )
import Network.Wai
  ( Request
  , Response
  , queryString
  , strictRequestBody
  )
import Panino.Api.Response
  ( diagnosticErrorResponse
  , jsonResponse
  )
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( TaskSnapshot(..)
  , TaskState(..)
  )
import qualified Panino.Diagnostics.Classify as Diagnostics

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

persistTaskHistory :: ServerState -> IO ()
persistTaskHistory state = do
  taskMap <- readTVarIO (stateTasks state)
  BL.writeFile (stateTaskHistoryPath state) (encode (Map.elems taskMap))

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
