{-# LANGUAGE OverloadedStrings #-}

module Integration.DownloadManager.Multipart
  ( assertMultipartDownload
  , assertMultipartRangeGetFallback
  , assertMultipartRangeIgnoredFallsBack
  ) where

import Control.Concurrent.MVar
  ( modifyMVar
  , newMVar
  , readMVar
  )
import Control.Exception (finally)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import Data.List (stripPrefix)
import Network.HTTP.Types
  ( status200
  , status206
  )
import Network.Wai
  ( requestHeaders
  , requestMethod
  , responseLBS
  )
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.Download.Manager
  ( DownloadJob(..)
  , DownloadResult(..)
  , downloadSingle
  )
import Panino.Core.Types (urlFromString)
import Panino.Net.Http (makeHttpManager)
import System.Directory
  ( doesFileExist
  , getFileSize
  )
import System.Environment
  ( setEnv
  , unsetEnv
  )
import System.FilePath
  ( (</>)
  , (<.>)
  )
import TestSupport
  ( assertEqual
  , removeIfExists
  )

assertMultipartDownload :: FilePath -> IO ()
assertMultipartDownload tempDir = do
  manager <- makeHttpManager
  let payload = BS.concat (replicate 1300000 "0123456789abcdef")
      expectedSize = fromIntegral (BS.length payload)
      target = tempDir </> "panino-core-multipart-test.bin"
      part = target <.> "part"
  removeIfExists target
  removeIfExists part
  testWithApplication
    ( pure $ \request respond ->
        case requestMethod request of
          "HEAD" ->
            respond
              ( responseLBS
                  status200
                  [ ("Accept-Ranges", "bytes")
                  , ("Content-Length", BS8.pack (show (BS.length payload)))
                  ]
                  ""
              )
          _ ->
            case parseRange (lookup "Range" (requestHeaders request)) of
              Just (start, end) ->
                let slice = BS.take (end - start + 1) (BS.drop start payload)
                 in respond
                      ( responseLBS
                          status206
                          [ ("Accept-Ranges", "bytes")
                          , ("Content-Length", BS8.pack (show (BS.length slice)))
                          ]
                          (BL.fromStrict slice)
                      )
              Nothing ->
                respond
                  ( responseLBS
                      status200
                      [ ("Accept-Ranges", "bytes")
                      , ("Content-Length", BS8.pack (show (BS.length payload)))
                      ]
                      (BL.fromStrict payload)
                  )
    )
    $ \port ->
      withMultipartMinBytes
        ( do
            let targetUrl = "http://127.0.0.1:" <> show port <> "/file.bin"
                job =
                  DownloadJob
                    { jobLabel = "multipart-test"
                    , jobUrl = urlFromString targetUrl
                    , jobTargetPath = target
                    , jobSha1 = Nothing
                    , jobSize = Just expectedSize
                    }
            result <- downloadSingle manager job
            assertEqual "multipart download result" (Downloaded job) result
            exists <- doesFileExist target
            assertEqual "multipart writes final target" True exists
            actualSize <- fromIntegral <$> getFileSize target
            assertEqual "multipart final size" expectedSize actualSize
        )

assertMultipartRangeGetFallback :: FilePath -> IO ()
assertMultipartRangeGetFallback tempDir = do
  manager <- makeHttpManager
  rangedRequests <- newMVar (0 :: Int)
  let payload = BS.concat (replicate 1024 "range-fallback")
      expectedSize = fromIntegral (BS.length payload)
      target = tempDir </> "panino-core-multipart-range-fallback.bin"
      part = target <.> "part"
  removeIfExists target
  removeIfExists part
  removeIfExists (part <> ".map")
  testWithApplication
    ( pure $ \request respond ->
        case requestMethod request of
          "HEAD" ->
            respond
              ( responseLBS
                  status200
                  [("Content-Length", BS8.pack (show (BS.length payload)))]
                  ""
              )
          _ ->
            case parseRange (lookup "Range" (requestHeaders request)) of
              Just (start, end) -> do
                _ <- modifyMVar rangedRequests $ \current -> let next = current + 1 in pure (next, next)
                let slice = BS.take (end - start + 1) (BS.drop start payload)
                respond
                  ( responseLBS
                      status206
                      [("Content-Length", BS8.pack (show (BS.length slice)))]
                      (BL.fromStrict slice)
                  )
              Nothing ->
                respond
                  ( responseLBS
                      status200
                      [("Content-Length", BS8.pack (show (BS.length payload)))]
                      (BL.fromStrict payload)
                  )
    )
    $ \port ->
      withMultipartMinBytes
        ( do
            let job =
                  DownloadJob
                    { jobLabel = "multipart-range-fallback"
                    , jobUrl = urlFromString ("http://127.0.0.1:" <> show port <> "/range.bin")
                    , jobTargetPath = target
                    , jobSha1 = Nothing
                    , jobSize = Just expectedSize
                    }
            result <- downloadSingle manager job
            assertEqual "multipart range fallback result" (Downloaded job) result
            rangeCount <- readMVar rangedRequests
            assertEqual "multipart range fallback used GET Range" True (rangeCount > 0)
            actualSize <- fromIntegral <$> getFileSize target
            assertEqual "multipart range fallback final size" expectedSize actualSize
            sidecarExists <- doesFileExist (part <> ".map")
            assertEqual "multipart range fallback removes sidecar" False sidecarExists
        )

assertMultipartRangeIgnoredFallsBack :: FilePath -> IO ()
assertMultipartRangeIgnoredFallsBack tempDir = do
  manager <- makeHttpManager
  rangedRequests <- newMVar (0 :: Int)
  fullRequests <- newMVar (0 :: Int)
  let payload = BS.concat (replicate 1024 "range-ignored")
      expectedSize = fromIntegral (BS.length payload)
      target = tempDir </> "panino-core-multipart-range-ignored.bin"
      part = target <.> "part"
  removeIfExists target
  removeIfExists part
  removeIfExists (part <> ".map")
  testWithApplication
    ( pure $ \request respond ->
        case requestMethod request of
          "HEAD" ->
            respond
              ( responseLBS
                  status200
                  [("Content-Length", BS8.pack (show (BS.length payload)))]
                  ""
              )
          _ -> do
            case lookup "Range" (requestHeaders request) of
              Just _ -> do
                _ <- modifyMVar rangedRequests $ \current -> let next = current + 1 in pure (next, next)
                respond (responseLBS status200 [("Content-Length", BS8.pack (show (BS.length payload)))] (BL.fromStrict payload))
              Nothing -> do
                _ <- modifyMVar fullRequests $ \current -> let next = current + 1 in pure (next, next)
                respond (responseLBS status200 [("Content-Length", BS8.pack (show (BS.length payload)))] (BL.fromStrict payload))
    )
    $ \port ->
      withMultipartMinBytes
        ( do
            let job =
                  DownloadJob
                    { jobLabel = "multipart-range-ignored"
                    , jobUrl = urlFromString ("http://127.0.0.1:" <> show port <> "/ignored.bin")
                    , jobTargetPath = target
                    , jobSha1 = Nothing
                    , jobSize = Just expectedSize
                    }
            result <- downloadSingle manager job
            assertEqual "multipart ignored range fallback result" (Downloaded job) result
            assertEqual "multipart ignored range probes once" 1 =<< readMVar rangedRequests
            assertEqual "multipart ignored range falls back to full GET" 1 =<< readMVar fullRequests
            actualSize <- fromIntegral <$> getFileSize target
            assertEqual "multipart ignored range final size" expectedSize actualSize
        )

withMultipartMinBytes :: IO a -> IO a
withMultipartMinBytes action =
  finally
    (setEnv "PANINO_MULTIPART_MIN_BYTES" "1024" >> action)
    (unsetEnv "PANINO_MULTIPART_MIN_BYTES")

parseRange :: Maybe BS.ByteString -> Maybe (Int, Int)
parseRange Nothing = Nothing
parseRange (Just raw) =
  case stripPrefix "bytes=" (BS8.unpack raw) of
    Nothing -> Nothing
    Just value ->
      case break (== '-') value of
        (startText, '-' : endText) -> do
          start <- readMaybeString startText
          end <- readMaybeString endText
          pure (start, end)
        _ -> Nothing

readMaybeString :: String -> Maybe Int
readMaybeString value =
  case reads value of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing
