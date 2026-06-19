{-# LANGUAGE OverloadedStrings #-}

module Integration.DownloadManager.Progress
  ( assertDownloadProgressCompletion
  , assertDownloadProgressWaitsForUnknownTailJobs
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar
  ( modifyMVar_
  , newMVar
  , readMVar
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as Builder
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import Network.HTTP.Types
  ( status200
  , status404
  )
import Network.Wai
  ( rawPathInfo
  , responseLBS
  , responseStream
  )
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.Download.Manager
  ( DownloadJob(..)
  , DownloadProgress(..)
  , downloadOptionsWithOverrides
  , runDownloadJobsWithOptionsAndProgressAndCancel
  )
import Panino.Net.Http (makeHttpManager)
import System.Directory (doesFileExist)
import System.FilePath
  ( (</>)
  , (<.>)
  )
import TestSupport
  ( assertEqual
  , removeIfExists
  )

assertDownloadProgressCompletion :: FilePath -> IO ()
assertDownloadProgressCompletion tempDir = do
  manager <- makeHttpManager
  events <- newMVar []
  let target = tempDir </> "panino-core-progress-test.bin"
      part = target <.> "part"
      payload = BS.replicate 8192 80
      expectedSize = fromIntegral (BS.length payload)
      job =
        DownloadJob
          { jobLabel = "progress-test"
          , jobUrl = ""
          , jobTargetPath = target
          , jobSha1 = Nothing
          , jobSize = Just expectedSize
          }
  removeIfExists target
  removeIfExists part
  testWithApplication
    ( pure $ \_ respond ->
        respond
          ( responseLBS
              status200
              [("Content-Length", BS8.pack (show expectedSize))]
              (BL.fromStrict payload)
          )
    )
    $ \port -> do
      let downloadJob = job { jobUrl = "http://127.0.0.1:" <> show port <> "/progress.bin" }
      _ <-
        runDownloadJobsWithOptionsAndProgressAndCancel
          manager
          (downloadOptionsWithOverrides (Just 1) (Just 0))
          (pure False)
          [downloadJob]
          (\progress -> modifyMVar_ events (pure . (progress :)))
      snapshots <- reverse <$> readMVar events
      let percentages = [value | DownloadProgress { progressPercent = Just value } <- snapshots]
      assertEqual "download progress starts at 0" (Just 0) (roundedHead percentages)
      assertEqual "download progress ends at 100" (Just 100) (roundedLast percentages)
      assertEqual "download progress terminal jobs" (Just (1, 1)) (terminalJobs snapshots)
      targetExists <- doesFileExist target
      assertEqual "download progress writes target" True targetExists

assertDownloadProgressWaitsForUnknownTailJobs :: FilePath -> IO ()
assertDownloadProgressWaitsForUnknownTailJobs tempDir = do
  manager <- makeHttpManager
  events <- newMVar []
  let knownPayload = BS.replicate 8192 81
      unknownPayload = "tail"
      expectedSize = fromIntegral (BS.length knownPayload)
      knownTarget = tempDir </> "panino-core-progress-known-tail-test.bin"
      unknownTarget = tempDir </> "panino-core-progress-unknown-tail-test.bin"
      knownJob port =
        DownloadJob
          { jobLabel = "known-tail-test"
          , jobUrl = "http://127.0.0.1:" <> show port <> "/known.bin"
          , jobTargetPath = knownTarget
          , jobSha1 = Nothing
          , jobSize = Just expectedSize
          }
      unknownJob port =
        DownloadJob
          { jobLabel = "unknown-tail-test"
          , jobUrl = "http://127.0.0.1:" <> show port <> "/unknown.bin"
          , jobTargetPath = unknownTarget
          , jobSha1 = Nothing
          , jobSize = Nothing
          }
  removeIfExists knownTarget
  removeIfExists (knownTarget <.> "part")
  removeIfExists unknownTarget
  removeIfExists (unknownTarget <.> "part")
  testWithApplication
    ( pure $ \request respond ->
        case rawPathInfo request of
          "/known.bin" ->
            respond
              ( responseStream
                  status200
                  [("Content-Length", BS8.pack (show expectedSize))]
                  $ \send flush -> do
                    send (Builder.byteString (BS.take 4096 knownPayload))
                    flush
                    threadDelay 300000
                    send (Builder.byteString (BS.drop 4096 knownPayload))
                    flush
              )
          "/unknown.bin" ->
            respond (responseLBS status200 [] (BL.fromStrict unknownPayload))
          _ ->
            respond (responseLBS status404 [] "not found")
    )
    $ \port -> do
      _ <-
        runDownloadJobsWithOptionsAndProgressAndCancel
          manager
          (downloadOptionsWithOverrides (Just 1) (Just 0))
          (pure False)
          [knownJob port, unknownJob port]
          (\progress -> modifyMVar_ events (pure . (progress :)))
      snapshots <- reverse <$> readMVar events
      let tailSnapshots =
            [ progress
            | progress <- snapshots
            , progressCompletedJobs progress < progressTotalJobs progress
            , progressTotalBytes progress > 0
            , progressCompletedBytes progress == progressTotalBytes progress
            ]
          cappedTail =
            [ progress
            | progress@DownloadProgress { progressPercent = Just percent } <- tailSnapshots
            , percent < 100
            , round percent < (100 :: Int)
            , progressEtaSeconds progress == Nothing
            ]
      assertEqual "download progress keeps tail below 100 before all jobs finish" True (not (null cappedTail))
      assertEqual "download progress tail still reaches terminal jobs" (Just (2, 2)) (terminalJobs snapshots)
      assertEqual "download progress tail terminal reaches 100" (Just 100) (roundedLast [value | DownloadProgress { progressPercent = Just value } <- snapshots])

roundedHead :: [Double] -> Maybe Int
roundedHead values =
  case values of
    value:_ -> Just (round value)
    [] -> Nothing

roundedLast :: [Double] -> Maybe Int
roundedLast values =
  case reverse values of
    value:_ -> Just (round value)
    [] -> Nothing

terminalJobs :: [DownloadProgress] -> Maybe (Int, Int)
terminalJobs snapshots =
  case reverse snapshots of
    progress:_ -> Just (progressCompletedJobs progress, progressTotalJobs progress)
    [] -> Nothing
