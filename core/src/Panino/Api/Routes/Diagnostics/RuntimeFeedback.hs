{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Diagnostics.RuntimeFeedback
  ( environmentRuntimeFeedback
  ) where

import Control.Concurrent.STM (readTVarIO)
import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( Value
  , object
  , (.=)
  )
import qualified Data.ByteString as BS
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( catMaybes
  , listToMaybe
  )
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Text.Encoding.Error (lenientDecode)
import qualified Data.Text.Read as TextRead
import Data.Time.Clock (diffUTCTime)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( TaskSnapshot(..)
  , TaskState(..)
  , taskStateText
  )
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.FilePath
  ( (</>)
  , takeExtension
  )

environmentRuntimeFeedback :: ServerState -> Maybe FilePath -> IO Value
environmentRuntimeFeedback state gameDir = do
  latestTask <- latestLaunchTask state gameDir
  let profilePath = (</> "downloads" </> "launch-performance-profile.json") <$> gameDir
      latestLogPath = (</> "logs" </> "latest.log") <$> gameDir
  profilePresent <- maybe (pure False) safeDoesFileExist profilePath
  latestLogTail <- maybe (pure Nothing) readTailText latestLogPath
  latestCrash <- maybe (pure Nothing) latestCrashReport gameDir
  crashTail <- maybe (pure Nothing) (readTailText . fst) latestCrash
  let combined =
        Text.toLower $
          Text.unwords $
            catMaybes
              [ taskRuntimeText <$> latestTask
              , latestLogTail
              , crashTail
              ]
      signals = runtimeSignals latestTask combined
      actions = runtimeActions signals
      status
        | gameDir == Nothing = "unavailable" :: Text
        | null signals = "ok"
        | otherwise = "needs_action"
  pure $
    object
      [ "status" .= status
      , "signals" .= signals
      , "actions" .= actions
      , "lastLaunchState" .= (taskStateText . taskSnapshotState <$> latestTask)
      , "lastLaunchTaskId" .= (taskSnapshotId <$> latestTask)
      , "exitCode" .= (latestTask >>= runtimeExitCode)
      , "durationMs" .= (latestTask >>= runtimeDurationMs)
      , "profilePath" .= profilePath
      , "profilePresent" .= profilePresent
      , "latestLogPath" .= latestLogPath
      , "latestLogPresent" .= maybe False (const True) latestLogTail
      , "crashReportPath" .= (fst <$> latestCrash)
      , "crashReportPresent" .= maybe False (const True) latestCrash
      , "logSummary" .= runtimeSummary signals
      ]

latestLaunchTask :: ServerState -> Maybe FilePath -> IO (Maybe TaskSnapshot)
latestLaunchTask state gameDir = do
  taskMap <- readTVarIO (stateTasks state)
  let matchesGameDir task =
        maybe True (\dir -> taskSnapshotGameDir task == Just dir) gameDir
      tasks =
        filter
          (\task -> taskSnapshotKind task == "launch" && matchesGameDir task)
          (Map.elems taskMap)
  pure (listToMaybe (sortOn (Down . taskSnapshotUpdatedAt) tasks))

latestCrashReport :: FilePath -> IO (Maybe (FilePath, FilePath))
latestCrashReport gameDir = do
  let crashDir = gameDir </> "crash-reports"
  exists <- safeDoesDirectoryExist crashDir
  if not exists
    then pure Nothing
    else do
      result <- try (listDirectory crashDir)
      pure $ case result of
        Right entries ->
          listToMaybe
            [ (crashDir </> entry, entry)
            | entry <- sortOn Down entries
            , takeExtension entry == ".txt"
            ]
        Left (_ :: SomeException) -> Nothing

runtimeSignals :: Maybe TaskSnapshot -> Text -> [Text]
runtimeSignals latestTask combined =
  concat
    [ ["heap_oom" | containsAny ["outofmemoryerror", "java heap space", "heap oom"] combined]
    , ["native_oom" | containsAny ["native memory", "unable to allocate", "os::commit_memory", "mmap failed"] combined]
    , ["gc_overhead" | containsAny ["gc overhead", "gcoverhead"] combined]
    , ["renderer_problem" | containsAny ["opengl", "lwjgl", "glfw", "renderer", "shader", "iris", "sodium", "oculus", "embeddium"] combined]
    , ["quick_exit" | maybe False isQuickFailedLaunch latestTask]
    , ["crash_report" | containsAny ["---- minecraft crash report ----", "crash report"] combined]
    ]

runtimeActions :: [Text] -> [Text]
runtimeActions signals
  | null signals =
      ["Keep automatic performance tuning. If the next launch feels slow, run environment diagnostics again."]
  | otherwise =
      concat
        [ ["Use automatic memory first; do not raise the JVM heap just because Minecraft crashed." | "heap_oom" `elem` signals]
        , ["Lower graphics distance or resource-pack pressure so unified memory keeps room for the GPU." | "native_oom" `elem` signals]
        , ["Restore the automatic JVM profile before adding custom GC or memory flags." | "gc_overhead" `elem` signals]
        , ["Apply recommended graphics settings and relaunch Minecraft before changing advanced video options." | "renderer_problem" `elem` signals]
        , ["Open the latest crash report; fix the first listed mod or renderer error before adding more memory." | "crash_report" `elem` signals]
        , ["If the launch closes within 30 seconds, check Java and loader compatibility before changing performance settings." | "quick_exit" `elem` signals]
        ]

runtimeSummary :: [Text] -> Text
runtimeSummary signals
  | null signals = "No recent launch signal requires a performance change."
  | "heap_oom" `elem` signals = "Last launch looks memory-related. Start with Panino's automatic heap, not a larger manual heap."
  | "renderer_problem" `elem` signals = "Last launch looks graphics or renderer-related. Apply the recommended video settings and restart."
  | "gc_overhead" `elem` signals = "Last launch spent too much effort on garbage collection. Use the automatic JVM profile first."
  | otherwise = "Last launch produced a signal that needs review before further tuning."

taskRuntimeText :: TaskSnapshot -> Text
taskRuntimeText task =
  Text.unwords $
    catMaybes
      [ taskSnapshotMessage task
      , taskSnapshotErrorCode task
      , taskSnapshotErrorDetail task
      ]

runtimeExitCode :: TaskSnapshot -> Maybe Int
runtimeExitCode =
  extractJavaExitCode . taskRuntimeText

runtimeDurationMs :: TaskSnapshot -> Maybe Int
runtimeDurationMs task = do
  finished <- taskSnapshotFinishedAt task
  pure (floor (realToFrac (diffUTCTime finished (taskSnapshotCreatedAt task)) * (1000 :: Double)))

isQuickFailedLaunch :: TaskSnapshot -> Bool
isQuickFailedLaunch task =
  taskSnapshotState task == TaskFailed
    && maybe False (< 30000) (runtimeDurationMs task)

extractJavaExitCode :: Text -> Maybe Int
extractJavaExitCode raw =
  case Text.breakOn marker (Text.toLower raw) of
    (_, rest) | Text.null rest -> Nothing
    (_, rest) ->
      let value = Text.stripStart (Text.drop (Text.length marker) rest)
       in case TextRead.signed TextRead.decimal value of
            Right (code, _) -> Just code
            Left _ -> Nothing
  where
    marker = "java exited with code "

readTailText :: FilePath -> IO (Maybe Text)
readTailText path = do
  result <- try (BS.readFile path)
  pure $ case result of
    Right bytes ->
      let maxBytes = 12000
          start = max 0 (BS.length bytes - maxBytes)
       in Just (TextEncoding.decodeUtf8With lenientDecode (BS.drop start bytes))
    Left (_ :: SomeException) -> Nothing

safeDoesFileExist :: FilePath -> IO Bool
safeDoesFileExist path = do
  result <- try (doesFileExist path)
  pure $ case result of
    Right exists -> exists
    Left (_ :: SomeException) -> False

safeDoesDirectoryExist :: FilePath -> IO Bool
safeDoesDirectoryExist path = do
  result <- try (doesDirectoryExist path)
  pure $ case result of
    Right exists -> exists
    Left (_ :: SomeException) -> False

containsAny :: [Text] -> Text -> Bool
containsAny needles haystack =
  any (`Text.isInfixOf` haystack) needles
