{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Performance.Telemetry.Collect
  ( beginPerformanceSession
  , completePerformanceSession
  , javaGcLogArguments
  , latestLogErrors
  , memoryMetricsFromSamples
  , readPerformanceSession
  , sampleProcessMemory
  , writePerformanceSession
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( eitherDecode
  , encode
  )
import qualified Data.ByteString.Lazy as BL
import Data.Int (Int64)
import Data.List
  ( isInfixOf
  , sort
  )
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock
  ( UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Data.Time.Format
  ( defaultTimeLocale
  , formatTime
  )
import Panino.Performance.Profile.Types
  ( InstanceFingerprint
  , PerformanceProfile
  )
import Panino.Performance.Telemetry.GcLog
  ( gcLogArguments
  , parseGcLogMetrics
  )
import Panino.Performance.Telemetry.Types
  ( GcMetrics
  , LaunchMetrics(..)
  , MemoryMetrics(..)
  , MemorySample(..)
  , PerformanceSession(..)
  , PerformanceSessionStatus(..)
  , emptyGcMetrics
  , emptyMemoryMetrics
  , performanceSessionPath
  , performanceSessionsRoot
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getModificationTime
  , listDirectory
  )
import System.Exit (ExitCode(..))
import System.FilePath
  ( (</>)
  , takeDirectory
  )
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )

beginPerformanceSession
  :: FilePath
  -> InstanceFingerprint
  -> Maybe Text
  -> Maybe Text
  -> Maybe PerformanceProfile
  -> Maybe Text
  -> IO PerformanceSession
beginPerformanceSession gameDir fingerprint baselineProfileId candidateProfileId appliedProfile rollbackRef = do
  now <- getCurrentTime
  let launchSessionId = sessionIdFromTime now
      session =
        PerformanceSession
          { sessionLaunchSessionId = launchSessionId
          , sessionGameDir = gameDir
          , sessionInstanceFingerprint = fingerprint
          , sessionBaselineProfileId = baselineProfileId
          , sessionCandidateProfileId = candidateProfileId
          , sessionStatus = SessionStarted
          , sessionStartedAt = now
          , sessionEndedAt = Nothing
          , sessionLaunchMetrics =
              LaunchMetrics
                { launchTimeToProcessStartMs = Nothing
                , launchTimeToGameLogReadyMs = Nothing
                , launchTimeToMainWindowHintMs = Nothing
                , launchProcessExitCode = Nothing
                , launchCrashReportCreated = False
                , launchLatestLogErrors = []
                }
          , sessionMemoryMetrics = emptyMemoryMetrics
          , sessionGcMetrics = emptyGcMetrics
          , sessionCompanionFrameMetrics = Nothing
          , sessionAppliedProfile = appliedProfile
          , sessionRollbackRef = rollbackRef
          }
  writePerformanceSession session
  pure session

completePerformanceSession
  :: PerformanceSession
  -> ExitCode
  -> Maybe Int64
  -> [MemorySample]
  -> Maybe FilePath
  -> IO PerformanceSession
completePerformanceSession session exitCode systemMemory samples maybeGcLog = do
  now <- getCurrentTime
  errors <- latestLogErrors (sessionGameDir session)
  crash <- crashReportCreated (sessionGameDir session) (sessionStartedAt session)
  gcMetrics <- maybe (pure emptyGcMetrics) readGcMetrics maybeGcLog
  let status =
        case exitCode of
          ExitSuccess -> SessionEnded
          ExitFailure 143 -> SessionKilled
          ExitFailure _ -> SessionCrashed
      launchMetrics =
        LaunchMetrics
          { launchTimeToProcessStartMs = Just 0
          , launchTimeToGameLogReadyMs = Nothing
          , launchTimeToMainWindowHintMs = Nothing
          , launchProcessExitCode = Just (exitCodeValue exitCode)
          , launchCrashReportCreated = crash
          , launchLatestLogErrors = errors
          }
      completed =
        session
          { sessionStatus = status
          , sessionEndedAt = Just now
          , sessionLaunchMetrics = launchMetrics
          , sessionMemoryMetrics = (memoryMetricsFromSamples samples) { memorySystemMemoryBytes = systemMemory }
          , sessionGcMetrics = gcMetrics
          }
  writePerformanceSession completed
  pure completed

writePerformanceSession :: PerformanceSession -> IO ()
writePerformanceSession session = do
  let path = performanceSessionPath (sessionGameDir session) (sessionLaunchSessionId session)
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path (encode session)

readPerformanceSession :: FilePath -> Text -> IO (Either String PerformanceSession)
readPerformanceSession gameDir launchSessionId =
  eitherDecode <$> BL.readFile (performanceSessionPath gameDir launchSessionId)

javaGcLogArguments :: Int -> FilePath -> Text -> IO (Maybe FilePath, [String])
javaGcLogArguments javaMajor gameDir launchSessionId
  | javaMajor >= 8 = do
      let logPath = performanceSessionsRoot gameDir </> Text.unpack launchSessionId </> "gc.log"
      createDirectoryIfMissing True (takeDirectory logPath)
      pure (Just logPath, gcLogArguments javaMajor logPath)
  | otherwise =
      pure (Nothing, [])

sampleProcessMemory :: Int -> Int -> IO (Maybe MemorySample)
sampleProcessMemory pid elapsedMs = do
  result <- try (readCreateProcessWithExitCode (proc "ps" ["-o", "rss=,vsz=", "-p", show pid]) "") :: IO (Either SomeException (ExitCode, String, String))
  pure $ case result of
    Right (ExitSuccess, stdoutText, _) ->
      case mapMaybe parseInt64 (words stdoutText) of
        rssKb:vszKb:_ ->
          Just
            MemorySample
              { memorySampleAtMs = elapsedMs
              , memorySampleResidentBytes = rssKb * 1024
              , memorySampleVirtualBytes = vszKb * 1024
              }
        _ -> Nothing
    _ -> Nothing

memoryMetricsFromSamples :: [MemorySample] -> MemoryMetrics
memoryMetricsFromSamples samples =
  MemoryMetrics
    { memoryPeakResidentBytes =
        case map memorySampleResidentBytes samples of
          [] -> 0
          values -> maximum values
    , memorySampledResidentBytes = map memorySampleResidentBytes samples
    , memorySampledVirtualBytes = map memorySampleVirtualBytes samples
    , memorySystemMemoryBytes = Nothing
    , memoryPressureHint = pressureHint
    , memorySamples = samples
    }
  where
    pressureHint =
      case map memorySampleResidentBytes samples of
        [] -> Nothing
        values
          | maximum values > 12 * 1024 * 1024 * 1024 -> Just "high"
          | maximum values > 8 * 1024 * 1024 * 1024 -> Just "medium"
          | otherwise -> Just "low"

latestLogErrors :: FilePath -> IO [Text]
latestLogErrors gameDir = do
  let path = gameDir </> "logs" </> "latest.log"
  exists <- doesFileExist path
  if not exists
    then pure []
    else do
      result <- try (readFile path) :: IO (Either SomeException String)
      pure $ case result of
        Left _ -> []
        Right content ->
          take 20 $
            map Text.pack $
              filter looksLikeError (lines content)

readGcMetrics :: FilePath -> IO GcMetrics
readGcMetrics path = do
  exists <- doesFileExist path
  if not exists
    then pure emptyGcMetrics
    else do
      result <- try (readFile path) :: IO (Either SomeException String)
      pure $ case result of
        Right content -> parseGcLogMetrics path content
        Left _ -> emptyGcMetrics

crashReportCreated :: FilePath -> UTCTime -> IO Bool
crashReportCreated gameDir startedAt = do
  let directory = gameDir </> "crash-reports"
  exists <- doesDirectoryExist directory
  if not exists
    then pure False
    else do
      result <- try (listDirectory directory) :: IO (Either SomeException [FilePath])
      case result of
        Left _ -> pure False
        Right entries ->
          anyM
            ( \entry -> do
                modified <- try (getModificationTime (directory </> entry)) :: IO (Either SomeException UTCTime)
                pure $ case modified of
                  Right time -> diffUTCTime time startedAt >= 0
                  Left _ -> False
            )
            (sort entries)

looksLikeError :: String -> Bool
looksLikeError line =
  any (`isInfixOf` lowered) ["error", "exception", "fat" <> "al", "crash", "outofmemory"]
  where
    lowered = map toLowerAscii line

toLowerAscii :: Char -> Char
toLowerAscii char
  | char >= 'A' && char <= 'Z' = toEnum (fromEnum char + 32)
  | otherwise = char

exitCodeValue :: ExitCode -> Int
exitCodeValue ExitSuccess = 0
exitCodeValue (ExitFailure code) = code

parseInt64 :: String -> Maybe Int64
parseInt64 value =
  case reads value of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing

sessionIdFromTime :: UTCTime -> Text
sessionIdFromTime =
  Text.pack . ("launch-" <>) . formatTime defaultTimeLocale "%Y%m%dT%H%M%S%QZ"

anyM :: Monad m => (a -> m Bool) -> [a] -> m Bool
anyM _ [] = pure False
anyM predicate (value:values) = do
  matched <- predicate value
  if matched then pure True else anyM predicate values
