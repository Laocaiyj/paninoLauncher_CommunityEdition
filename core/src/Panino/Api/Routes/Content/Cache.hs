{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Content.Cache
  ( contentLoadersResponse
  , contentMinecraftInstallStatusResponse
  , contentMinecraftInstalledInstancesResponse
  , contentMinecraftPackageResponse
  , contentMinecraftVersionsResponse
  , contentProjectResponse
  , contentSearchResponse
  ) where

import Control.Exception (SomeException, try)
import Control.Concurrent (forkIO)
import Control.Concurrent.MVar (MVar, modifyMVar, newMVar)
import Control.Monad (void, when)
import Data.Aeson (ToJSON, Value(..), decode, eitherDecode, encode, object, (.=))
import qualified Data.Aeson.Key as AesonKey
import qualified Data.Aeson.KeyMap as AesonKeyMap
import qualified Crypto.Hash.SHA1 as SHA1
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import Data.List (sort, sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import Data.Time.Clock (NominalDiffTime, UTCTime, diffUTCTime, getCurrentTime)
import Data.Word (Word8)
import Network.HTTP.Types (Header, hContentType, status200, status400)
import Network.Wai (Request, Response, responseLBS, strictRequestBody)
import Numeric (showHex)
import Panino.Api.MinecraftStatus (fetchInstalledMinecraftInstances, fetchMinecraftInstallStatus)
import Panino.Api.Params (decodeBody)
import Panino.Api.Response (contentSourceErrorResponse, jsonResponse)
import Panino.Api.Server.State
  ( ServerState(..)
  , stateDefaultGameDirPath
  )
import Panino.Content.Online (contentLoaderMetadata, contentMinecraftPackage, contentMinecraftVersions, contentProject, contentSearch)
import Panino.Content.Online.Types (ContentLoaderRequest(..), ContentProjectRequest(..), ContentSearchRequest(..), MinecraftPackageRequest(..), OnlineSearchPage(..))
import Panino.Perf.Metrics (CacheStatus(..), cacheStatusHeader, cacheStatusText, recordApiMetric)
import System.IO.Unsafe (unsafePerformIO)

data CachedContentResponse = CachedContentResponse
  { cachedContentAt :: UTCTime
  , cachedContentLastAccessedAt :: UTCTime
  , cachedContentBody :: BL.ByteString
  }

contentResponseFreshTtl :: NominalDiffTime
contentResponseFreshTtl = 2

contentResponseStaleTtl :: NominalDiffTime
contentResponseStaleTtl = 600

contentResponseMaxEntries :: Int
contentResponseMaxEntries = 256

{-# NOINLINE contentResponseCache #-}
-- Process-local response cache. Keep the unsafePerformIO boundary isolated here
-- until content route cache ownership moves into ServerState.
contentResponseCache :: MVar (Map Text CachedContentResponse)
contentResponseCache =
  unsafePerformIO (newMVar Map.empty)
contentSearchResponse :: ServerState -> Request -> IO Response
contentSearchResponse state request = do
  body <- strictRequestBody request
  let decoded = eitherDecode body
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right contentRequest ->
      cachedContentJsonResponse
        "content-search"
        (contentSearchCacheKey contentRequest)
        (Just (prefetchSearchResult state contentRequest))
        (annotateSearchPage (contentSearchCacheKey contentRequest) contentRequest <$> contentSearch (stateHttpManager state) contentRequest)

contentProjectResponse :: ServerState -> Request -> IO Response
contentProjectResponse state request = do
  body <- strictRequestBody request
  let decoded = eitherDecode body
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right contentRequest ->
      cachedContentJsonResponse
        "content-project"
        (contentProjectCacheKey contentRequest)
        Nothing
        (contentProject (stateHttpManager state) contentRequest)

cachedContentJsonResponse :: ToJSON value => Text -> Text -> Maybe (value -> IO ()) -> IO value -> IO Response
cachedContentJsonResponse routeName key afterNetwork action = do
  started <- getCurrentTime
  now <- getCurrentTime
  cached <-
    modifyMVar contentResponseCache $ \cache -> do
      let usableCache = Map.filter (cacheUsable now) cache
      case Map.lookup key usableCache of
        Just cachedResponse ->
          let refreshed = cachedResponse { cachedContentLastAccessedAt = now }
           in pure (Map.insert key refreshed usableCache, Just refreshed)
        Nothing ->
          pure (usableCache, Nothing)
  case cached of
    Just cachedResponse | cacheFresh now cachedResponse -> do
      finished <- getCurrentTime
      let body = cachedContentBody cachedResponse
      recordApiMetric routeName key CacheHit (diffUTCTime finished started) (BL.length body)
      pure (jsonBytesResponse CacheHit (diffUTCTime finished started) body)
    _ -> do
      result <- try action
      case result of
        Right value -> do
          let body = encode value
          modifyMVar contentResponseCache $ \cache ->
            pure (insertCachedContent now key body cache, ())
          case afterNetwork of
            Nothing -> pure ()
            Just callback -> void (forkIO (callback value))
          finished <- getCurrentTime
          recordApiMetric routeName key NetworkFetch (diffUTCTime finished started) (BL.length body)
          pure (jsonBytesResponse NetworkFetch (diffUTCTime finished started) body)
        Left err ->
          case cached of
            Just cachedResponse -> do
              finished <- getCurrentTime
              let body = cachedContentBody cachedResponse
              recordApiMetric routeName key StaleHit (diffUTCTime finished started) (BL.length body)
              pure (jsonBytesResponse StaleHit (diffUTCTime finished started) body)
            Nothing -> do
              finished <- getCurrentTime
              recordApiMetric routeName key CacheError (diffUTCTime finished started) 0
              pure (contentSourceErrorResponse (err :: SomeException))

cacheFresh :: UTCTime -> CachedContentResponse -> Bool
cacheFresh now cached =
  diffUTCTime now (cachedContentAt cached) <= contentResponseFreshTtl

cacheUsable :: UTCTime -> CachedContentResponse -> Bool
cacheUsable now cached =
  diffUTCTime now (cachedContentAt cached) <= contentResponseStaleTtl

trimContentCache :: UTCTime -> Map Text CachedContentResponse -> Map Text CachedContentResponse
trimContentCache now cache =
  Map.fromList (take contentResponseMaxEntries sortedFresh)
  where
    freshEntries =
      Map.toList (Map.filter (cacheUsable now) cache)
    sortedFresh =
      sortOn (Down . cachedContentLastAccessedAt . snd) freshEntries

insertCachedContent :: UTCTime -> Text -> BL.ByteString -> Map Text CachedContentResponse -> Map Text CachedContentResponse
insertCachedContent now key body cache =
  trimContentCache now $
    Map.insert key
      CachedContentResponse
        { cachedContentAt = now
        , cachedContentLastAccessedAt = now
        , cachedContentBody = body
        }
      cache

jsonBytesResponse :: CacheStatus -> NominalDiffTime -> BL.ByteString -> Response
jsonBytesResponse cacheStatus duration body =
  responseLBS status200 (contentResponseHeaders cacheStatus duration responseBody) responseBody
  where
    responseBody = bodyWithCacheStatus cacheStatus body

bodyWithCacheStatus :: CacheStatus -> BL.ByteString -> BL.ByteString
bodyWithCacheStatus cacheStatus body =
  case decode body of
    Just (Object obj) ->
      encode
        ( Object
            ( AesonKeyMap.insert
                (AesonKey.fromString "cacheStatus")
                (String (cacheStatusText cacheStatus))
                obj
            )
        )
    _ -> body

contentResponseHeaders :: CacheStatus -> NominalDiffTime -> BL.ByteString -> [Header]
contentResponseHeaders cacheStatus duration body =
  [ (hContentType, "application/json")
  , cacheStatusHeader cacheStatus
  , ("X-Panino-Duration-Ms", BS8.pack (show (durationMillis duration)))
  , ("X-Panino-Response-Bytes", BS8.pack (show (BL.length body)))
  ]

durationMillis :: NominalDiffTime -> Int
durationMillis duration =
  round (realToFrac duration * 1000 :: Double)

warmContentCache :: ToJSON value => Text -> Text -> IO value -> IO ()
warmContentCache routeName key action = do
  now <- getCurrentTime
  cached <-
    modifyMVar contentResponseCache $ \cache -> do
      let usableCache = Map.filter (cacheUsable now) cache
      pure (usableCache, Map.lookup key usableCache)
  case cached of
    Just cachedResponse | cacheFresh now cachedResponse -> pure ()
    _ -> do
      result <- try action
      case result of
        Right value -> do
          let body = encode value
          modifyMVar contentResponseCache $ \cache ->
            pure (insertCachedContent now key body cache, ())
          recordApiMetric routeName key NetworkFetch 0 (BL.length body)
        Left (_ :: SomeException) ->
          pure ()

prefetchSearchResult :: ServerState -> ContentSearchRequest -> OnlineSearchPage -> IO ()
prefetchSearchResult state request page =
  when (contentSearchPrefetch request && nextOffset < pageTotal page) $
    warmContentCache
      "content-search"
      (contentSearchCacheKey nextRequest)
      (contentSearch (stateHttpManager state) nextRequest)
  where
    nextOffset = pageOffset page + pageLimit page
    nextRequest =
      request
        { contentSearchOffset = nextOffset
        , contentSearchPrefetch = False
        }

annotateSearchPage :: Text -> ContentSearchRequest -> OnlineSearchPage -> OnlineSearchPage
annotateSearchPage requestId request page =
  page
    { pageRequestId = Just requestId
    , pageNextPrefetchKey =
        if nextOffset < pageTotal page
          then Just (contentSearchCacheKey nextRequest)
          else Nothing
    }
  where
    nextOffset = pageOffset page + pageLimit page
    nextRequest =
      request
        { contentSearchOffset = nextOffset
        , contentSearchPrefetch = False
        }

timedContentJsonResponse :: ToJSON value => Text -> Text -> IO value -> IO Response
timedContentJsonResponse routeName key action = do
  started <- getCurrentTime
  result <- try action
  finished <- getCurrentTime
  case result of
    Right value -> do
      let body = encode value
      recordApiMetric routeName key NotCacheable (diffUTCTime finished started) (BL.length body)
      pure (jsonBytesResponse NotCacheable (diffUTCTime finished started) body)
    Left err -> do
      recordApiMetric routeName key CacheError (diffUTCTime finished started) 0
      pure (contentSourceErrorResponse (err :: SomeException))

contentMinecraftVersionsResponse :: ServerState -> IO Response
contentMinecraftVersionsResponse state =
  timedContentJsonResponse "content-minecraft-versions" "minecraft-versions" (contentMinecraftVersions (stateHttpManager state))

contentMinecraftInstallStatusResponse :: ServerState -> Request -> IO Response
contentMinecraftInstallStatusResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right statusRequest ->
      jsonResponse status200 <$> fetchMinecraftInstallStatus (stateDefaultGameDirPath state) statusRequest

contentMinecraftInstalledInstancesResponse :: ServerState -> Request -> IO Response
contentMinecraftInstalledInstancesResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right statusRequest ->
      jsonResponse status200 <$> fetchInstalledMinecraftInstances (stateDefaultGameDirPath state) statusRequest

contentMinecraftPackageResponse :: ServerState -> Request -> IO Response
contentMinecraftPackageResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right packageRequest ->
      timedContentJsonResponse
        "content-minecraft-package"
        (minecraftPackageCacheKey packageRequest)
        (contentMinecraftPackage (stateHttpManager state) packageRequest)

contentLoadersResponse :: ServerState -> Request -> IO Response
contentLoadersResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right loaderRequest ->
      timedContentJsonResponse
        "content-loaders"
        (contentLoaderCacheKey loaderRequest)
        (contentLoaderMetadata (stateHttpManager state) loaderRequest)

contentSearchCacheKey :: ContentSearchRequest -> Text
contentSearchCacheKey request =
  Text.intercalate
    "|"
    [ "source=" <> contentSearchSource request
    , "text=" <> normalizeCacheText (contentSearchText request)
    , "types=" <> Text.intercalate "," (sort (contentSearchProjectTypes request))
    , "categories=" <> Text.intercalate "," (sort (contentSearchCategories request))
    , "version=" <> fromMaybe "" (contentSearchGameVersion request)
    , "loaders=" <> Text.intercalate "," (sort (contentSearchLoaders request))
    , "sort=" <> contentSearchSort request
    , "offset=" <> Text.pack (show (contentSearchOffset request))
    , "limit=" <> Text.pack (show (contentSearchLimit request))
    , "curseforge=" <> secretCacheKey (contentSearchCurseForgeApiKey request)
    ]

contentProjectCacheKey :: ContentProjectRequest -> Text
contentProjectCacheKey request =
  Text.intercalate
    "|"
    [ "source=" <> contentProjectSource request
    , "project=" <> contentProjectId request
    , "query=(" <> contentSearchCacheKey (contentProjectQuery request) <> ")"
    , "curseforge=" <> secretCacheKey (contentProjectCurseForgeApiKey request)
    ]

contentLoaderCacheKey :: ContentLoaderRequest -> Text
contentLoaderCacheKey (ContentLoaderRequest minecraftVersion) =
  "minecraftVersion=" <> normalizeCacheText minecraftVersion

minecraftPackageCacheKey :: MinecraftPackageRequest -> Text
minecraftPackageCacheKey request =
  "id=" <> minecraftPackageId request <> "|url=" <> minecraftPackageUrl request

normalizeCacheText :: Text -> Text
normalizeCacheText =
  Text.toLower . Text.strip

secretCacheKey :: Maybe Text -> Text
secretCacheKey Nothing = "none"
secretCacheKey (Just value) =
  "sha1:" <> Text.pack (concatMap byteToHex (BS.unpack (SHA1.hash (Text.encodeUtf8 value))))

byteToHex :: Word8 -> String
byteToHex byte =
  case showHex byte "" of
    [single] -> ['0', single]
    pair -> pair
