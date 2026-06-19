{-# LANGUAGE OverloadedStrings #-}

module Integration.DownloadManager
  ( assertDownloadCancellation
  , assertDownloadConcurrencyOptions
  , assertDownloadProgressCompletion
  , assertDownloadProgressWaitsForUnknownTailJobs
  , assertDownloadRejects404
  , assertDownloadRetryOptions
  , assertMultipartDownload
  , assertMultipartRangeGetFallback
  , assertMultipartRangeIgnoredFallsBack
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar
  ( modifyMVar
  , modifyMVar_
  , newMVar
  , readMVar
  )
import Control.Exception
  ( SomeException
  , fromException
  , try
  )
import Control.Monad (when)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as Builder
import qualified Data.ByteString.Char8 as BS8
import Integration.DownloadManager.Multipart
  ( assertMultipartDownload
  , assertMultipartRangeGetFallback
  , assertMultipartRangeIgnoredFallsBack
  )
import Integration.DownloadManager.Progress
  ( assertDownloadProgressCompletion
  , assertDownloadProgressWaitsForUnknownTailJobs
  )
import Network.HTTP.Types
  ( status200
  , status404
  , status503
  )
import Network.Wai
  ( responseLBS
  , responseStream
  )
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.Download.Manager
  ( DownloadException(..)
  , DownloadJob(..)
  , DownloadProgress(..)
  , DownloadSummary(..)
  , downloadOptionsWithOverrides
  , downloadSingle
  , runDownloadJobsWithOptionsAndProgressAndCancel
  , runDownloadJobsWithProgressAndCancel
  )
import Panino.Net.Http (makeHttpManager)
import System.Directory
  ( doesFileExist
  , getFileSize
  )
import System.Exit (exitFailure)
import System.FilePath
  ( (</>)
  , (<.>)
  )
import TestSupport
  ( assertEqual
  , removeIfExists
  )

assertDownloadRejects404 :: FilePath -> IO ()
assertDownloadRejects404 tempDir = do
  manager <- makeHttpManager
  let target = tempDir </> "panino-core-download-404-test.jar"
      part = target <.> "part"
  removeIfExists target
  removeIfExists part
  testWithApplication
    ( pure $ \_ respond ->
        respond (responseLBS status404 [] "missing")
    )
    $ \port -> do
      result <-
        try
          ( do
              _ <-
                downloadSingle manager DownloadJob
                  { jobLabel = "404-test"
                  , jobUrl = "http://127.0.0.1:" <> show port <> "/missing.jar"
                  , jobTargetPath = target
                  , jobSha1 = Nothing
                  , jobSize = Nothing
                  }
              pure ()
          )
      case (result :: Either SomeException ()) of
        Left _ -> pure ()
        Right _ -> do
          putStrLn "FAIL: download rejects 404"
          putStrLn "  expected: exception"
          putStrLn "  actual:   success"
          exitFailure
      targetExists <- doesFileExist target
      partExists <- doesFileExist part
      assertEqual "download 404 does not write target" False targetExists
      assertEqual "download 404 does not write part" False partExists

assertDownloadRetryOptions :: FilePath -> IO ()
assertDownloadRetryOptions tempDir = do
  manager <- makeHttpManager
  attempts <- newMVar (0 :: Int)
  let target = tempDir </> "panino-core-retry-test.bin"
      part = target <.> "part"
      payload = "ok"
      baseJob =
        DownloadJob
          { jobLabel = "retry-test"
          , jobUrl = ""
          , jobTargetPath = target
          , jobSha1 = Nothing
          , jobSize = Just 2
          }
  removeIfExists target
  removeIfExists part
  testWithApplication
    ( pure $ \_ respond -> do
        count <- modifyMVar attempts $ \current -> do
          let next = current + 1
          pure (next, next)
        if count == 1
          then respond (responseLBS status503 [] "try again")
          else respond (responseLBS status200 [("Content-Length", "2")] payload)
    )
    $ \port -> do
      let job = baseJob { jobUrl = "http://127.0.0.1:" <> show port <> "/retry.bin" }
      summary <-
        runDownloadJobsWithOptionsAndProgressAndCancel
          manager
          (downloadOptionsWithOverrides (Just 1) (Just 1))
          (pure False)
          [job]
          (\_ -> pure ())
      assertEqual "download retry options checked files" 1 (totalCount summary)
      assertEqual "download retry options retried once" 2 =<< readMVar attempts
      targetExists <- doesFileExist target
      assertEqual "download retry options writes target" True targetExists

assertDownloadConcurrencyOptions :: FilePath -> IO ()
assertDownloadConcurrencyOptions tempDir = do
  manager <- makeHttpManager
  let payload = BS.replicate 4096 65
      expectedSize = fromIntegral (BS.length payload)
      makeJobs port label =
        [ DownloadJob
            { jobLabel = label <> "-" <> show index
            , jobUrl = "http://127.0.0.1:" <> show port <> "/" <> label <> "/" <> show index <> ".bin"
            , jobTargetPath = tempDir </> ("panino-core-" <> label <> "-" <> show index <> ".bin")
            , jobSha1 = Nothing
            , jobSize = Just expectedSize
            }
        | index <- [1 :: Int .. 8]
        ]
      cleanup jobs = mapM_ (\job -> removeIfExists (jobTargetPath job) >> removeIfExists (jobTargetPath job <.> "part")) jobs
  testWithApplication
    ( pure $ \_ respond ->
        respond
          ( responseStream
              status200
              [("Content-Length", BS8.pack (show expectedSize))]
              $ \send flush -> do
                send (Builder.byteString (BS.take 1024 payload))
                flush
                threadDelay 30000
                send (Builder.byteString (BS.drop 1024 payload))
                flush
          )
    )
    $ \port -> do
      let runWith requested label = do
            maxActive <- newMVar (0 :: Int)
            let jobs = makeJobs port label
            cleanup jobs
            _ <-
              runDownloadJobsWithOptionsAndProgressAndCancel
                manager
                (downloadOptionsWithOverrides (Just requested) (Just 0))
                (pure False)
                jobs
                (\progress -> modifyMVar_ maxActive (pure . max (progressActiveWorkers progress)))
            readMVar maxActive
      oneWorkerMax <- runWith 1 "concurrency-one"
      eightWorkerMax <- runWith 8 "concurrency-eight"
      assertEqual "download concurrency 1 keeps one active worker" True (oneWorkerMax <= 1)
      assertEqual "download concurrency 8 uses multiple active workers" True (eightWorkerMax > 1)

assertDownloadCancellation :: FilePath -> IO ()
assertDownloadCancellation tempDir = do
  manager <- makeHttpManager
  cancelFlag <- newMVar False
  let chunk = BS.replicate 65536 65
      chunkCount = 64
      expectedSize = fromIntegral (BS.length chunk * chunkCount)
      target = tempDir </> "panino-core-cancel-test.bin"
      part = target <.> "part"
  removeIfExists target
  removeIfExists part
  testWithApplication
    ( pure $ \_ respond ->
        respond
          ( responseStream
              status200
              [("Content-Length", BS8.pack (show expectedSize))]
              $ \send flush -> do
                let loop 0 = pure ()
                    loop remaining = do
                      send (Builder.byteString chunk)
                      flush
                      threadDelay 10000
                      loop (remaining - 1)
                loop chunkCount
          )
    )
    $ \port -> do
      let job =
            DownloadJob
              { jobLabel = "cancel-test"
              , jobUrl = "http://127.0.0.1:" <> show port <> "/cancel.bin"
              , jobTargetPath = target
              , jobSha1 = Nothing
              , jobSize = Just expectedSize
              }
      result <-
        try
          ( do
              _ <-
                runDownloadJobsWithProgressAndCancel
                  manager
                  1
                  (readMVar cancelFlag)
                  [job]
                  $ \progress ->
                    when (progressCompletedBytes progress > 0) $
                      modifyMVar_ cancelFlag (const (pure True))
              pure ()
          )
      case (result :: Either SomeException ()) of
        Left err ->
          case fromException err of
            Just DownloadCancelled -> pure ()
            _ -> do
              putStrLn "FAIL: cancelled download raises DownloadCancelled"
              putStrLn ("  actual: " <> show err)
              exitFailure
        Right _ -> do
          putStrLn "FAIL: cancelled download stops"
          putStrLn "  expected: DownloadCancelled"
          putStrLn "  actual:   success"
          exitFailure
      threadDelay 100000
      targetExists <- doesFileExist target
      assertEqual "cancelled download does not write final target" False targetExists
      partExists <- doesFileExist part
      when partExists $ do
        partSize <- fromIntegral <$> getFileSize part
        assertEqual "cancelled download leaves incomplete part" True (partSize < expectedSize)
