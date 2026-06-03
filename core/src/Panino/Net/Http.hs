{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Net.Http
  ( RequestTimeoutClass(..)
  , applyRequestTimeout
  , applyRequestTimeoutMicros
  , coreRequest
  , coreRequestWithTimeout
  , cacheRoot
  , fetchJson
  , fetchJsonUrl
  , fetchText
  , makeHttpManager
  , metadataRetryCount
  ) where

import Control.Concurrent (threadDelay)
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , modifyMVar_
  , newEmptyMVar
  , newMVar
  , putMVar
  , readMVar
  )
import Control.Exception
  ( SomeException
  , catch
  , throwIO
  , try
  )
import Data.Char (toLower)
import Data.Aeson
  ( FromJSON
  , FromJSON(..)
  , ToJSON(..)
  , eitherDecode
  , encode
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Aeson.Types ((.!=))
import qualified Crypto.Hash.SHA1 as SHA1
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Data.Text.Encoding.Error (lenientDecode)
import Data.Time.Clock
  ( NominalDiffTime
  , UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Data.Time.Clock.POSIX (getPOSIXTime)
import Network.HTTP.Client
  ( Manager
  , Request
  , Response
  , getUri
  , httpLbs
  , method
  , managerConnCount
  , managerIdleConnectionCount
  , managerResponseTimeout
  , managerSetProxy
  , parseRequest
  , proxyEnvironment
  , requestHeaders
  , responseBody
  , responseHeaders
  , responseStatus
  , responseTimeout
  , responseTimeoutMicro
  )
import Network.HTTP.Client.TLS
  ( newTlsManagerWith
  , tlsManagerSettings
  )
import Network.HTTP.Types
  ( HeaderName
  , methodGet
  , statusCode
  )
import Numeric (showHex)
import Panino.Net.Sources
  ( resolveSourceUrls
  )
import Panino.Net.Probe
  ( preferFastestRequests
  , recordSourceFailure
  )
import Data.Word (Word8)
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , getHomeDirectory
  )
import System.Environment (lookupEnv)
import System.FilePath
  ( (</>)
  , takeDirectory
  )
import System.IO.Unsafe (unsafePerformIO)

data CacheMeta = CacheMeta
  { cacheFetchedAt :: UTCTime
  , cacheStatus :: Int
  , cacheETag :: Maybe Text
  , cacheLastModified :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON CacheMeta where
  toJSON meta =
    object
      [ "fetchedAt" .= cacheFetchedAt meta
      , "status" .= cacheStatus meta
      , "etag" .= cacheETag meta
      , "lastModified" .= cacheLastModified meta
      ]

instance FromJSON CacheMeta where
  parseJSON =
    withObject "CacheMeta" $ \obj ->
      CacheMeta
        <$> obj .: "fetchedAt"
        <*> obj .:? "status" .!= 200
        <*> obj .:? "etag"
        <*> obj .:? "lastModified"

data CacheEntry = CacheEntry
  { cacheMetaPath :: FilePath
  , cacheBodyPath :: FilePath
  } deriving (Eq, Show)

type InFlightValue = Either SomeException (Int, BL.ByteString)

{-# NOINLINE inFlightRequests #-}
inFlightRequests :: MVar (Map String (MVar InFlightValue))
inFlightRequests =
  unsafePerformIO (newMVar Map.empty)

metadataCacheTtl :: NominalDiffTime
metadataCacheTtl = 300

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

fetchJsonUrl :: FromJSON value => Manager -> String -> IO value
fetchJsonUrl manager url =
  fetchJson manager =<< coreRequest url []

fetchJson :: FromJSON value => Manager -> Request -> IO value
fetchJson manager request = do
  (status, body) <- fetchBytes manager request
  if status >= 200 && status < 300
    then
      case eitherDecode body of
        Right value -> pure value
        Left err -> fail ("content source JSON parse failed: " <> err)
    else fail ("content source returned HTTP " <> show status <> ": " <> Text.unpack (responseBodyPreview body))

fetchText :: Manager -> Request -> IO Text
fetchText manager request = do
  (status, body) <- fetchBytes manager request
  if status >= 200 && status < 300
    then pure (Text.decodeUtf8 (BL.toStrict body))
    else fail ("content source returned HTTP " <> show status <> ": " <> Text.unpack (responseBodyPreview body))

fetchBytes :: Manager -> Request -> IO (Int, BL.ByteString)
fetchBytes manager originalRequest = do
  requests <- resolveRequests originalRequest
  let primaryRequest = head requests
  if cacheableRequest primaryRequest
    then fetchCachedBytes manager primaryRequest requests
    else do
      (status, _headers, body) <- fetchNetworkBytes manager requests
      pure (status, body)

resolveRequests :: Request -> IO [Request]
resolveRequests request = do
  resolvedUrls <- resolveSourceUrls (show (getUri request))
  traverse (requestForUrl request) resolvedUrls

requestForUrl :: Request -> String -> IO Request
requestForUrl original url = do
  parsed <- parseRequest url
  pure
    parsed
      { requestHeaders = requestHeaders original <> requestHeaders parsed
      , responseTimeout = responseTimeout original
      }

cacheableRequest :: Request -> Bool
cacheableRequest request =
  method request == methodGet

fetchCachedBytes :: Manager -> Request -> [Request] -> IO (Int, BL.ByteString)
fetchCachedBytes manager request requests = do
  let key = requestCacheKey request
  entry <- cacheEntry key
  fresh <- readFreshCache entry
  case fresh of
    Just cached -> do
      putStrLn ("cache_hit " <> key)
      pure cached
    Nothing ->
      joinInFlight key $
        fetchAndStore entry manager request requests

fetchAndStore :: CacheEntry -> Manager -> Request -> [Request] -> IO (Int, BL.ByteString)
fetchAndStore entry manager request requests = do
  stale <- readStaleCache entry
  let conditionalRequest =
        maybe request (addConditionalHeaders request . fst) stale
      conditionalRequests =
        conditionalRequest : drop 1 requests
  networkResult <- try (fetchNetworkBytes manager conditionalRequests)
  case networkResult of
    Right (304, _headers, _) ->
      case stale of
        Just (_meta, cached) -> do
          now <- getCurrentTime
          updateCacheTime entry now
          putStrLn ("cache_revalidated " <> requestCacheKey request)
          pure (200, cached)
        Nothing ->
          fail "content source returned HTTP 304 without a local cache entry"
    Right (status, headers, body)
      | status >= 200 && status < 300 -> do
          writeCache entry status (responseHeaderText "ETag" headers) (responseHeaderText "Last-Modified" headers) body
          putStrLn ("network_fetch " <> requestCacheKey request)
          pure (status, body)
      | retryableStatus status ->
          case stale of
            Just (_meta, cached) -> do
              putStrLn ("cache_stale_http " <> requestCacheKey request <> ": HTTP " <> show status)
              pure (200, cached)
            Nothing ->
              pure (status, body)
      | otherwise ->
          pure (status, body)
    Left err ->
      case stale of
        Just (_meta, cached) -> do
          putStrLn ("cache_stale " <> requestCacheKey request <> ": " <> show (err :: SomeException))
          pure (200, cached)
        Nothing ->
          throwIO (err :: SomeException)

fetchNetworkBytes :: Manager -> [Request] -> IO (Int, [(HeaderName, BS.ByteString)], BL.ByteString)
fetchNetworkBytes manager requests =
  fetchNetworkBytesOrdered manager =<< preferFastestRequests manager requests

fetchNetworkBytesOrdered :: Manager -> [Request] -> IO (Int, [(HeaderName, BS.ByteString)], BL.ByteString)
fetchNetworkBytesOrdered _ [] =
  fail "no HTTP source available"
fetchNetworkBytesOrdered manager [request] =
  fetchSingleNetworkBytes manager request
fetchNetworkBytesOrdered manager (request:fallbacks) =
  (fetchSingleNetworkBytes manager request >>= useOrFallback)
    `catch` \(err :: SomeException) -> do
      recordSourceFailure (show (getUri request)) (show err)
      putStrLn ("source_fallback " <> show (getUri request) <> ": " <> show err)
      fetchNetworkBytesOrdered manager fallbacks
  where
    useOrFallback result@(status, _headers, _body)
      | sourceStatusUsable status = pure result
      | otherwise = do
          let reason = "HTTP " <> show status
          recordSourceFailure (show (getUri request)) reason
          putStrLn ("source_fallback " <> show (getUri request) <> ": " <> reason)
          fetchNetworkBytesOrdered manager fallbacks

fetchSingleNetworkBytes :: Manager -> Request -> IO (Int, [(HeaderName, BS.ByteString)], BL.ByteString)
fetchSingleNetworkBytes manager request = do
  response <- httpLbsWithRetry request manager
  pure (statusCode (responseStatus response), responseHeaders response, responseBody response)

sourceStatusUsable :: Int -> Bool
sourceStatusUsable status =
  status == 304 || (status >= 200 && status < 300)

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

joinInFlight :: String -> IO (Int, BL.ByteString) -> IO (Int, BL.ByteString)
joinInFlight key action = do
  acquired <-
    modifyMVar inFlightRequests $ \requests ->
      case Map.lookup key requests of
        Just waiter -> pure (requests, Left waiter)
        Nothing -> do
          waiter <- newEmptyMVar
          pure (Map.insert key waiter requests, Right waiter)
  case acquired of
    Left waiter -> do
      result <- readMVar waiter
      either throwIO pure result
    Right waiter -> do
      result <- try action
      putMVar waiter result
      modifyMVar_ inFlightRequests (pure . Map.delete key)
      either throwIO pure result

requestCacheKey :: Request -> String
requestCacheKey request =
  BS8.unpack (method request) <> " " <> show (getUri request)

cacheEntry :: String -> IO CacheEntry
cacheEntry key = do
  root <- cacheRoot
  let digest = sha1HexText key
      dir = root </> take 2 digest
  createDirectoryIfMissing True dir
  pure
    CacheEntry
      { cacheMetaPath = dir </> digest <> ".json"
      , cacheBodyPath = dir </> digest <> ".body"
      }

cacheRoot :: IO FilePath
cacheRoot = do
  configured <- lookupEnv "PANINO_HTTP_CACHE_DIR"
  case configured of
    Just configuredPath | not (null configuredPath) -> pure configuredPath
    _ -> do
      home <- getHomeDirectory
      pure (home </> "Library" </> "Application Support" </> "Panino Launcher" </> "cache" </> "http")

readFreshCache :: CacheEntry -> IO (Maybe (Int, BL.ByteString))
readFreshCache entry = do
  stale <- readStaleCache entry
  case stale of
    Nothing -> pure Nothing
    Just (meta, body) -> do
      now <- getCurrentTime
      if diffUTCTime now (cacheFetchedAt meta) <= metadataCacheTtl
        then pure (Just (cacheStatus meta, body))
        else pure Nothing

readStaleCache :: CacheEntry -> IO (Maybe (CacheMeta, BL.ByteString))
readStaleCache entry = do
  metaExists <- doesFileExist (cacheMetaPath entry)
  bodyExists <- doesFileExist (cacheBodyPath entry)
  if not (metaExists && bodyExists)
    then pure Nothing
    else do
      metaResult <- try (BS.readFile (cacheMetaPath entry))
      case metaResult of
        Left (err :: SomeException) -> do
          putStrLn ("cache_read_ignored " <> cacheMetaPath entry <> ": " <> show err)
          pure Nothing
        Right metaBytes ->
          case eitherDecode (BL.fromStrict metaBytes) of
            Left _ -> pure Nothing
            Right meta -> do
              bodyResult <- try (BS.readFile (cacheBodyPath entry))
              case bodyResult of
                Left (err :: SomeException) -> do
                  putStrLn ("cache_read_ignored " <> cacheBodyPath entry <> ": " <> show err)
                  pure Nothing
                Right body ->
                  pure (Just (meta, BL.fromStrict body))

writeCache :: CacheEntry -> Int -> Maybe Text -> Maybe Text -> BL.ByteString -> IO ()
writeCache entry status etag lastModified body = do
  now <- getCurrentTime
  result <-
    try $ do
      createDirectoryIfMissing True (takeDirectory (cacheMetaPath entry))
      BS.writeFile (cacheBodyPath entry) (BL.toStrict body)
      BS.writeFile
        (cacheMetaPath entry)
        ( BL.toStrict $
            encode
              CacheMeta
                { cacheFetchedAt = now
                , cacheStatus = status
                , cacheETag = etag
                , cacheLastModified = lastModified
                }
        )
  case result of
    Right () -> pure ()
    Left (err :: SomeException) ->
      putStrLn ("cache_write_ignored " <> cacheBodyPath entry <> ": " <> show err)

updateCacheTime :: CacheEntry -> UTCTime -> IO ()
updateCacheTime entry now = do
  stale <- readStaleCache entry
  case stale of
    Nothing -> pure ()
    Just (meta, _body) ->
      do
        result <- try (BS.writeFile (cacheMetaPath entry) (BL.toStrict (encode meta { cacheFetchedAt = now })))
        case result of
          Right () -> pure ()
          Left (err :: SomeException) ->
            putStrLn ("cache_touch_ignored " <> cacheMetaPath entry <> ": " <> show err)

addConditionalHeaders :: Request -> CacheMeta -> Request
addConditionalHeaders request meta =
  request
    { requestHeaders =
        conditionalHeaders <> requestHeaders request
    }
  where
    conditionalHeaders =
      [ ("If-None-Match", Text.encodeUtf8 etag)
      | Just etag <- [cacheETag meta]
      ]
        <> [ ("If-Modified-Since", Text.encodeUtf8 modified)
           | Just modified <- [cacheLastModified meta]
           ]

responseHeaderText :: HeaderName -> [(HeaderName, BS.ByteString)] -> Maybe Text
responseHeaderText name headers =
  Text.decodeUtf8With lenientDecode <$> lookup name headers

responseBodyPreview :: BL.ByteString -> Text
responseBodyPreview =
  Text.take 500
    . Text.strip
    . Text.replace "\n" " "
    . Text.decodeUtf8With lenientDecode
    . BL.toStrict

sha1HexText :: String -> String
sha1HexText =
  concatMap byteToHex . BS.unpack . SHA1.hash . BS8.pack

byteToHex :: Word8 -> String
byteToHex byte =
  case showHex byte "" of
    [single] -> ['0', single]
    pair -> pair
