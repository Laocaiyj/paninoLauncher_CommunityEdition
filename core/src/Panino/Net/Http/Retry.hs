{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Net.Http.Retry
  ( httpLbsWithRetry
  , metadataRetryCount
  , retryableStatus
  ) where

import Control.Concurrent (threadDelay)
import Control.Exception
  ( SomeException
  , throwIO
  , try
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import Data.Time.Clock.POSIX (getPOSIXTime)
import Network.HTTP.Client
  ( Manager
  , Request
  , Response
  , getUri
  , httpLbs
  , responseHeaders
  , responseStatus
  )
import Network.HTTP.Types
  ( HeaderName
  , statusCode
  )
import System.Environment (lookupEnv)

httpLbsWithRetry :: Request -> Manager -> IO (Response BL.ByteString)
httpLbsWithRetry request manager = do
  maxRetries <- metadataRetryCount
  go (maxRetries + 1) 1
  where
    go maxAttempts attempt = do
      result <- try (httpLbs request manager)
      case result of
        Right response
          | attempt < maxAttempts && retryableStatus (statusCode (responseStatus response)) -> do
              putStrLn ("retry " <> show attempt <> "/" <> show maxAttempts <> " for " <> show (getUri request) <> ": HTTP " <> show (statusCode (responseStatus response)))
              threadDelay =<< retryDelay attempt response
              go maxAttempts (attempt + 1)
          | otherwise -> pure response
        Left (err :: SomeException)
          | attempt < maxAttempts -> do
              putStrLn ("retry " <> show attempt <> "/" <> show maxAttempts <> " for " <> show (getUri request) <> ": " <> show err)
              threadDelay =<< addJitter (min 12000000 (400000 * (2 ^ max 0 (attempt - 1))))
              go maxAttempts (attempt + 1)
          | otherwise -> throwIO err

    retryDelay attempt response =
      case (* 1000000) <$> parseRetryAfter response of
        Just delay -> pure delay
        Nothing -> addJitter (min 12000000 (400000 * (2 ^ max 0 (attempt - 1))))

retryableStatus :: Int -> Bool
retryableStatus status =
  status == 408 || status == 429 || status >= 500

metadataRetryCount :: IO Int
metadataRetryCount = do
  configured <- lookupEnv "PANINO_HTTP_RETRY_COUNT"
  pure $
    case configured >>= readMaybeString of
      Just value -> min 10 (max 0 value)
      Nothing -> 3

addJitter :: Int -> IO Int
addJitter baseDelay = do
  now <- getPOSIXTime
  let window = max 1 (baseDelay `div` 4)
      jitter = floor (now * 1000000) `mod` window
  pure (baseDelay + jitter)

parseRetryAfter :: Response body -> Maybe Int
parseRetryAfter response =
  lookup hRetryAfter (responseHeaders response) >>= readMaybeBytes

hRetryAfter :: HeaderName
hRetryAfter = "Retry-After"

readMaybeBytes :: BS.ByteString -> Maybe Int
readMaybeBytes value =
  case reads (BS8.unpack value) of
    (seconds, _) : _ -> Just seconds
    [] -> Nothing

readMaybeString :: String -> Maybe Int
readMaybeString value =
  case reads value of
    (parsed, "") : _ -> Just parsed
    _ -> Nothing
