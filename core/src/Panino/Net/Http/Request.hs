{-# LANGUAGE OverloadedStrings #-}

module Panino.Net.Http.Request
  ( RequestTimeoutClass(..)
  , applyRequestTimeout
  , applyRequestTimeoutMicros
  , coreRequest
  , coreRequestWithTimeout
  , makeHttpManager
  ) where

import Data.Char (toLower)
import Data.Text (Text)
import qualified Data.Text.Encoding as Text
import Network.HTTP.Client
  ( Manager
  , Request
  , managerConnCount
  , managerIdleConnectionCount
  , managerResponseTimeout
  , managerSetProxy
  , parseRequest
  , proxyEnvironment
  , requestHeaders
  , responseTimeout
  , responseTimeoutMicro
  )
import Network.HTTP.Client.TLS
  ( newTlsManagerWith
  , tlsManagerSettings
  )
import Network.HTTP.Types (HeaderName)
import System.Environment (lookupEnv)

data RequestTimeoutClass
  = QuickMetadata
  | LongMetadata
  | DownloadTransfer
  | LocalFilesystemScan
  deriving (Eq, Show)

makeHttpManager :: IO Manager
makeHttpManager = do
  strategy <- fmap normalizeStrategy <$> lookupEnv "PANINO_DOWNLOAD_STRATEGY"
  let (connectionCount, idleConnectionCount) =
        case strategy of
          Just "fast" -> (192, 64)
          Just "conservative" -> (64, 16)
          _ -> (128, 32)
  newTlsManagerWith
    (managerSetProxy (proxyEnvironment Nothing) tlsManagerSettings)
      { managerResponseTimeout = responseTimeoutMicro 60000000
      , managerConnCount = connectionCount
      , managerIdleConnectionCount = idleConnectionCount
      }

normalizeStrategy :: String -> String
normalizeStrategy =
  map (\char -> if char == '-' || char == '_' then char else toLower char)

coreRequest :: String -> [(HeaderName, Text)] -> IO Request
coreRequest url =
  coreRequestWithTimeout QuickMetadata url

coreRequestWithTimeout :: RequestTimeoutClass -> String -> [(HeaderName, Text)] -> IO Request
coreRequestWithTimeout timeoutClass url headers = do
  request <- parseRequest url
  pure
    (applyRequestTimeout timeoutClass request)
      { requestHeaders =
          [ ("User-Agent", "PaninoLauncher/0.1 Core")
          ]
            <> map (\(key, value) -> (key, Text.encodeUtf8 value)) headers
            <> requestHeaders request
      }

applyRequestTimeout :: RequestTimeoutClass -> Request -> Request
applyRequestTimeout timeoutClass request =
  request { responseTimeout = responseTimeoutMicro (requestTimeoutMicros timeoutClass) }

applyRequestTimeoutMicros :: Int -> Request -> Request
applyRequestTimeoutMicros micros request =
  request { responseTimeout = responseTimeoutMicro micros }

requestTimeoutMicros :: RequestTimeoutClass -> Int
requestTimeoutMicros QuickMetadata = 15000000
requestTimeoutMicros LongMetadata = 60000000
requestTimeoutMicros DownloadTransfer = 300000000
requestTimeoutMicros LocalFilesystemScan = 30000000
