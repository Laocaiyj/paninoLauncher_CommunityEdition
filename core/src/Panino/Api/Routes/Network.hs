{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Network
  ( effectiveNetworkConfigValue
  , effectiveNetworkConfigResponse
  , speedTestResponse
  , speedTestValue
  , sourceTestValue
  , sourceTestResponse
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Control.Applicative ((<|>))
import Control.Monad (when)
import Data.Aeson
  ( FromJSON(..)
  , Value(..)
  , eitherDecode
  , object
  , withObject
  , (.:?)
  , (.!=)
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString as BS
import Data.Int (Int64)
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock
  ( UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Network.HTTP.Client
  ( Manager
  , getUri
  , httpLbs
  , responseBody
  , responseHeaders
  , responseStatus
  , withResponse
  )
import Network.HTTP.Types
  ( HeaderName
  , status200
  , status400
  )
import Network.HTTP.Types.Status (statusCode)
import Network.Wai
  ( Request
  , Response
  , strictRequestBody
  )
import Panino.Api.Response (jsonResponse)
import Panino.Api.Server.State (ServerState(..))
import Panino.Minecraft.Types
  ( AssetIndex(..)
  , AssetObject(..)
  , DownloadInfo(..)
  , Library(..)
  , LibraryDownloads(..)
  , VersionJson(..)
  , VersionManifest(..)
  , VersionSummary(..)
  , isAllowedByRules
  )
import Panino.Net.Http
  ( RequestTimeoutClass(..)
  , coreRequestWithTimeout
  , metadataRetryCount
  )
import Panino.Net.Probe
  ( recordSourceThroughput
  , sourceHostKey
  )
import Panino.Net.Sources
  ( SourceEndpoint(..)
  , configuredBases
  , defaultSourceEndpoints
  , officialFallbackEnabled
  , resolveSourceUrls
  )
import System.Environment (lookupEnv)

data SpeedTestRequest = SpeedTestRequest
  { speedTestCategories :: [Text]
  , speedTestUrls :: [String]
  , speedTestSampleBytes :: Maybe Int64
  } deriving (Eq, Show)

instance FromJSON SpeedTestRequest where
  parseJSON =
    withObject "SpeedTestRequest" $ \value ->
      SpeedTestRequest
        <$> value .:? "categories" .!= []
        <*> value .:? "urls" .!= []
        <*> value .:? "sampleBytes"

data SpeedTestTarget = SpeedTestTarget
  { speedTargetEndpoint :: Text
  , speedTargetUrl :: String
  } deriving (Eq, Show)

data SpeedTestResult = SpeedTestResult
  { speedResultEndpoint :: Text
  , speedResultCandidateUrl :: String
  , speedResultHost :: Text
  , speedResultStatus :: Maybe Int
  , speedResultBytes :: Int64
  , speedResultElapsedMs :: Int
  , speedResultBytesPerSecond :: Int64
  , speedResultRangeSupported :: Bool
  , speedResultUsedProxy :: Bool
  , speedResultError :: Maybe Text
  , speedResultOk :: Bool
  } deriving (Eq, Show)

data ProbeTarget = ProbeTarget
  { probeLabel :: Text
  , probeUrl :: String
  , probeRangeOnly :: Bool
  } deriving (Eq, Show)

data ProbeAttempt = ProbeAttempt
  { attemptUrl :: String
  , attemptStatus :: Maybe Int
  , attemptLatencyMs :: Int
  , attemptOk :: Bool
  , attemptError :: Maybe Text
  } deriving (Eq, Show)

data ProbeReport = ProbeReport
  { reportLabel :: Text
  , reportUrl :: String
  , reportCandidateCount :: Int
  , reportAttempts :: [ProbeAttempt]
  , reportSelectedUrl :: Maybe String
  , reportSelectedIndex :: Maybe Int
  , reportOk :: Bool
  , reportStatus :: Maybe Int
  , reportLatencyMs :: Maybe Int
  , reportError :: Maybe Text
  } deriving (Eq, Show)

effectiveNetworkConfigResponse :: IO Response
effectiveNetworkConfigResponse =
  jsonResponse status200 <$> effectiveNetworkConfigValue

effectiveNetworkConfigValue :: IO Value
effectiveNetworkConfigValue = do
  sourceProfile <- envText "PANINO_SOURCE_PROFILE" "official"
  fallbackEnabled <- officialFallbackEnabled
  retryCount <- metadataRetryCount
  endpoints <- traverse endpointSummary defaultSourceEndpoints
  proxy <- proxySummary
  pure $
    object
      [ "sourceProfile" .= sourceProfile
      , "officialFallback" .= fallbackEnabled
      , "metadataRetryCount" .= retryCount
      , "proxy" .= proxy
      , "endpoints" .= endpoints
      ]

sourceTestResponse :: ServerState -> IO Response
sourceTestResponse state =
  jsonResponse status200 <$> sourceTestValue state

speedTestResponse :: ServerState -> Request -> IO Response
speedTestResponse state request = do
  body <- strictRequestBody request
  case decodeSpeedTestRequest body of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right speedRequest ->
      jsonResponse status200 <$> speedTestValue state speedRequest

speedTestValue :: ServerState -> SpeedTestRequest -> IO Value
speedTestValue state request = do
  generatedAt <- getCurrentTime
  targets <- speedTestTargets (stateHttpManager state) request
  let sampleBytes = clampSpeedSampleBytes (fromMaybe defaultSpeedSampleBytes (speedTestSampleBytes request))
  results <- traverse (runSpeedTestTarget (stateHttpManager state) sampleBytes) targets
  pure $
    object
      [ "ok" .= all speedResultOk results
      , "generatedAt" .= generatedAt
      , "sampleBytes" .= sampleBytes
      , "results" .= map speedResultJson results
      ]

decodeSpeedTestRequest :: BL.ByteString -> Either String SpeedTestRequest
decodeSpeedTestRequest body
  | BL.null body = Right (SpeedTestRequest [] [] Nothing)
  | otherwise = eitherDecode body

speedTestTargets :: Manager -> SpeedTestRequest -> IO [SpeedTestTarget]
speedTestTargets manager request = do
  discovered <- discoverSpeedTargets manager categories
  let customTargets =
        [ SpeedTestTarget ("custom-" <> Text.pack (show index)) url
        | (index, url) <- zip [1 :: Int ..] (speedTestUrls request)
        ]
  pure (discovered <> customTargets)
  where
    categories =
      if null (speedTestCategories request)
        then defaultSpeedCategories
        else speedTestCategories request

discoverSpeedTargets :: Manager -> [Text] -> IO [SpeedTestTarget]
discoverSpeedTargets manager categories = do
  let wants category = category `elem` categories
      manifestUrl = "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
  manifestPair <-
    if any wants ["mojang-manifest", "mojang-asset", "mojang-library", "client-jar"]
      then Just <$> fetchJsonProbe manager (ProbeTarget "Mojang manifest" manifestUrl False)
      else pure Nothing
  let manifest = manifestPair >>= snd
  versionPair <-
    case manifest >>= selectedManifestVersionUrl of
      Just versionUrl | any wants ["mojang-asset", "mojang-library", "client-jar"] ->
        Just <$> fetchJsonProbe manager (ProbeTarget "Mojang version metadata" (Text.unpack versionUrl) False)
      _ -> pure Nothing
  let versionJson = versionPair >>= snd
  assetIndexPair <-
    case versionJson >>= downloadUrl . versionAssetIndex of
      Just assetIndexUrl | wants "mojang-asset" ->
        Just <$> fetchJsonProbe manager (ProbeTarget "Mojang asset index" (Text.unpack assetIndexUrl) False)
      _ -> pure Nothing
  let assetIndex = assetIndexPair >>= snd
      manifestTargets = [SpeedTestTarget "mojang-manifest" manifestUrl | wants "mojang-manifest"]
      assetTargets =
        [SpeedTestTarget "mojang-asset" assetUrl | wants "mojang-asset", Just assetUrl <- [assetIndex >>= selectedAssetObjectUrl]]
      libraryTargets =
        [SpeedTestTarget "mojang-library" targetUrl | wants "mojang-library", Just targetUrl <- [versionJson >>= selectedLibraryUrl]]
      clientTargets =
        [SpeedTestTarget "client-jar" (Text.unpack clientUrl) | wants "client-jar", Just clientUrl <- [versionJson >>= selectedClientDownloadUrl]]
      fabricTargets =
        [SpeedTestTarget "fabric-metadata" "https://meta.fabricmc.net/v2/versions/loader" | wants "fabric-metadata"]
  pure (manifestTargets <> assetTargets <> libraryTargets <> clientTargets <> fabricTargets)

runSpeedTestTarget :: Manager -> Int64 -> SpeedTestTarget -> IO SpeedTestResult
runSpeedTestTarget manager sampleBytes target = do
  candidates <- resolveSourceUrls (speedTargetUrl target)
  proxyUsed <- proxyConfigured
  go proxyUsed candidates Nothing
  where
    go proxyUsed [] previous =
      pure $
        SpeedTestResult
          { speedResultEndpoint = speedTargetEndpoint target
          , speedResultCandidateUrl = speedTargetUrl target
          , speedResultHost = Text.pack (sourceHostKey (speedTargetUrl target))
          , speedResultStatus = Nothing
          , speedResultBytes = 0
          , speedResultElapsedMs = 0
          , speedResultBytesPerSecond = 0
          , speedResultRangeSupported = False
          , speedResultUsedProxy = proxyUsed
          , speedResultError = previous <|> Just "No candidate URL produced a measurable response."
          , speedResultOk = False
          }
    go proxyUsed (candidate:rest) _ = do
      result <- probeSpeedCandidate manager sampleBytes (speedTargetEndpoint target) proxyUsed candidate
      if speedResultOk result
        then pure result
        else go proxyUsed rest (speedResultError result)

probeSpeedCandidate :: Manager -> Int64 -> Text -> Bool -> String -> IO SpeedTestResult
probeSpeedCandidate manager sampleBytes endpoint proxyUsed candidateUrl = do
  start <- getCurrentTime
  result <-
    try $ do
      request <-
        coreRequestWithTimeout
          DownloadTransfer
          candidateUrl
          [("Range", Text.pack ("bytes=0-" <> show (sampleBytes - 1)))]
      withResponse request manager $ \response -> do
        bytes <- readResponseSample sampleBytes (responseBody response)
        pure (show (getUri request), statusCode (responseStatus response), responseHeaders response, bytes)
  end <- getCurrentTime
  let elapsed = max 1 (latencyMs start end)
  case result of
    Right (finalUrl, code, headers, bytes) -> do
      let byteCount = fromIntegral (BS.length bytes)
          rangeSupported = code == 206 || hasContentRange headers
          ok = code >= 200 && code < 300 && byteCount > 0
          throughput = bytesPerSecond byteCount elapsed
      when ok (recordSourceThroughput finalUrl byteCount throughput)
      pure $
        SpeedTestResult
          { speedResultEndpoint = endpoint
          , speedResultCandidateUrl = finalUrl
          , speedResultHost = Text.pack (sourceHostKey finalUrl)
          , speedResultStatus = Just code
          , speedResultBytes = byteCount
          , speedResultElapsedMs = elapsed
          , speedResultBytesPerSecond = throughput
          , speedResultRangeSupported = rangeSupported
          , speedResultUsedProxy = proxyUsed
          , speedResultError = if ok then Nothing else Just (Text.pack ("HTTP " <> show code))
          , speedResultOk = ok
          }
    Left (err :: SomeException) ->
      pure $
        SpeedTestResult
          { speedResultEndpoint = endpoint
          , speedResultCandidateUrl = candidateUrl
          , speedResultHost = Text.pack (sourceHostKey candidateUrl)
          , speedResultStatus = Nothing
          , speedResultBytes = 0
          , speedResultElapsedMs = elapsed
          , speedResultBytesPerSecond = 0
          , speedResultRangeSupported = False
          , speedResultUsedProxy = proxyUsed
          , speedResultError = Just (Text.pack (show err))
          , speedResultOk = False
          }

readResponseSample :: Int64 -> IO BS.ByteString -> IO BS.ByteString
readResponseSample sampleBytes reader =
  go sampleBytes []
  where
    go remaining chunks
      | remaining <= 0 = pure (BS.concat (reverse chunks))
      | otherwise = do
          chunk <- reader
          if BS.null chunk
            then pure (BS.concat (reverse chunks))
            else do
              let clipped = BS.take (fromIntegral remaining) chunk
                  nextRemaining = remaining - fromIntegral (BS.length clipped)
              go nextRemaining (clipped : chunks)

speedResultJson :: SpeedTestResult -> Value
speedResultJson result =
  object
    [ "endpoint" .= speedResultEndpoint result
    , "candidateUrl" .= speedResultCandidateUrl result
    , "host" .= speedResultHost result
    , "status" .= speedResultStatus result
    , "bytes" .= speedResultBytes result
    , "elapsedMs" .= speedResultElapsedMs result
    , "bytesPerSecond" .= speedResultBytesPerSecond result
    , "rangeSupported" .= speedResultRangeSupported result
    , "usedProxy" .= speedResultUsedProxy result
    , "error" .= speedResultError result
    , "ok" .= speedResultOk result
    ]

bytesPerSecond :: Int64 -> Int -> Int64
bytesPerSecond bytes elapsedMs =
  round (fromIntegral bytes * 1000 / max 1 (fromIntegral elapsedMs :: Double))

hasContentRange :: [(HeaderName, BS.ByteString)] -> Bool
hasContentRange headers =
  "Content-Range" `elem` map fst headers

proxyConfigured :: IO Bool
proxyConfigured = do
  values <- traverse lookupEnv proxyEnvKeys
  pure (any (maybe False (not . null)) values)

clampSpeedSampleBytes :: Int64 -> Int64
clampSpeedSampleBytes value =
  min (16 * 1024 * 1024) (max (256 * 1024) value)

defaultSpeedSampleBytes :: Int64
defaultSpeedSampleBytes = 4 * 1024 * 1024

defaultSpeedCategories :: [Text]
defaultSpeedCategories =
  [ "mojang-manifest"
  , "mojang-asset"
  , "mojang-library"
  , "client-jar"
  , "fabric-metadata"
  ]

sourceTestValue :: ServerState -> IO Value
sourceTestValue state = do
  let manager = stateHttpManager state
  generatedAt <- getCurrentTime
  (manifestReport, manifest) <-
    fetchJsonProbe manager $
      ProbeTarget
        "Mojang manifest"
        "https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
        False
  (versionReport, versionJson) <-
    case manifest >>= selectedManifestVersionUrl of
      Just versionUrl ->
        fetchJsonProbe manager $
          ProbeTarget "Mojang version metadata" (Text.unpack versionUrl) False
      Nothing ->
        pure (blockedReport "Mojang version metadata" "manifest:selected-version" "Mojang manifest did not provide a version URL.", Nothing)
  (assetIndexReport, assetIndex) <-
    case versionJson >>= downloadUrl . versionAssetIndex of
      Just assetIndexUrl ->
        fetchJsonProbe manager $
          ProbeTarget "Mojang asset index" (Text.unpack assetIndexUrl) False
      Nothing ->
        pure (blockedReport "Mojang asset index" "version:assetIndex" "Version metadata did not provide an asset index URL.", Nothing)
  (assetReport, _assetBytes) <-
    case assetIndex >>= selectedAssetObjectUrl of
      Just assetUrl ->
        fetchBytesProbe manager $
          ProbeTarget "Mojang asset object" assetUrl True
      Nothing ->
        pure (blockedReport "Mojang asset object" "asset-index:object" "Asset index did not contain a downloadable object.", Nothing)
  (libraryReport, _libraryBytes) <-
    case versionJson >>= selectedLibraryUrl of
      Just selectedLibrary ->
        fetchBytesProbe manager $
          ProbeTarget "Mojang library artifact" selectedLibrary True
      Nothing ->
        pure (blockedReport "Mojang library artifact" "version:libraries" "Version metadata did not contain a library artifact URL for this platform.", Nothing)
  (fabricReport, _fabricBody) <-
    ( fetchJsonProbe manager $
        ProbeTarget "Fabric loader metadata" "https://meta.fabricmc.net/v2/versions/loader" False
    ) :: IO (ProbeReport, Maybe Value)
  let reports =
        [ manifestReport
        , versionReport
        , assetIndexReport
        , assetReport
        , libraryReport
        , fabricReport
        ]
  pure $
    object
      [ "ok" .= all reportOk reports
      , "generatedAt" .= generatedAt
      , "results" .= map reportJson reports
      ]

endpointSummary :: SourceEndpoint -> IO Value
endpointSummary endpoint = do
  rawConfigured <- lookupEnv (sourceEnvVar endpoint)
  bases <- configuredBases (sourceEnvVar endpoint)
  pure $
    object
      [ "envVar" .= sourceEnvVar endpoint
      , "officialBase" .= sourceDefaultBase endpoint
      , "configured" .= maybe False (not . null) rawConfigured
      , "effectiveBases" .= bases
      ]

proxySummary :: IO Value
proxySummary = do
  values <- traverse envMaybe proxyEnvKeys
  let configured = mapMaybe id values
      selected = listToMaybe configured
  pure $
    object
      [ "configured" .= maybe False (const True) selected
      , "value" .= fmap redactProxy selected
      , "keys" .= [key | (key, Just _) <- zip proxyEnvKeys values]
      ]

proxyEnvKeys :: [String]
proxyEnvKeys =
  [ "https_proxy"
  , "http_proxy"
  , "all_proxy"
  , "HTTPS_PROXY"
  , "HTTP_PROXY"
  , "ALL_PROXY"
  ]

envText :: String -> Text -> IO Text
envText key fallback = do
  value <- lookupEnv key
  pure $
    case value of
      Just text | not (null text) -> Text.pack text
      _ -> fallback

envMaybe :: String -> IO (Maybe String)
envMaybe key = do
  value <- lookupEnv key
  pure $
    case value of
      Just text | not (null text) -> Just text
      _ -> Nothing

redactProxy :: String -> String
redactProxy value =
  case breakAtScheme value of
    Nothing -> value
    Just (schemePrefix, authorityAndPath) ->
      case break (== '/') authorityAndPath of
        (authority, path)
          | '@' `elem` authority -> schemePrefix <> "***@" <> drop 1 (dropWhile (/= '@') authority) <> path
          | otherwise -> value

breakAtScheme :: String -> Maybe (String, String)
breakAtScheme value =
  case breakOn "://" value of
    Nothing -> Nothing
    Just (scheme, rest) -> Just (scheme <> "://", rest)

breakOn :: String -> String -> Maybe (String, String)
breakOn needle haystack =
  go "" haystack
  where
    go _ [] = Nothing
    go prefix rest
      | needle `isPrefixOfString` rest = Just (reverse prefix, drop (length needle) rest)
      | otherwise =
          case rest of
            char:remaining -> go (char : prefix) remaining

isPrefixOfString :: String -> String -> Bool
isPrefixOfString [] _ = True
isPrefixOfString _ [] = False
isPrefixOfString (expected:expectedRest) (actual:actualRest) =
  expected == actual && isPrefixOfString expectedRest actualRest

fetchJsonProbe :: forall value. FromJSON value => Manager -> ProbeTarget -> IO (ProbeReport, Maybe value)
fetchJsonProbe manager target =
  fetchProbeWith manager target $ \body ->
    case eitherDecode body of
      Right value -> Right value
      Left err -> Left (Text.pack ("JSON parse failed: " <> err))

fetchBytesProbe :: Manager -> ProbeTarget -> IO (ProbeReport, Maybe BL.ByteString)
fetchBytesProbe manager target =
  fetchProbeWith manager target Right

fetchProbeWith :: Manager -> ProbeTarget -> (BL.ByteString -> Either Text value) -> IO (ProbeReport, Maybe value)
fetchProbeWith manager target validate = do
  candidates <- resolveSourceUrls (probeUrl target)
  go (zip [0 :: Int ..] candidates) [] (length candidates)
  where
    go [] attempts candidateCount =
      pure
        ( ProbeReport
            { reportLabel = probeLabel target
            , reportUrl = probeUrl target
            , reportCandidateCount = candidateCount
            , reportAttempts = attempts
            , reportSelectedUrl = Nothing
            , reportSelectedIndex = Nothing
            , reportOk = False
            , reportStatus = attemptStatus =<< listToMaybe (reverse attempts)
            , reportLatencyMs = attemptLatencyMs <$> listToMaybe (reverse attempts)
            , reportError = Just "No source candidate returned usable data."
            }
        , Nothing
        )
    go ((index, candidateUrl):rest) attempts candidateCount = do
      (attempt, body) <- fetchCandidate manager target candidateUrl validate
      let nextAttempts = attempts <> [attempt]
      case body of
        Just value ->
          pure
            ( ProbeReport
                { reportLabel = probeLabel target
                , reportUrl = probeUrl target
                , reportCandidateCount = candidateCount
                , reportAttempts = nextAttempts
                , reportSelectedUrl = Just candidateUrl
                , reportSelectedIndex = Just index
                , reportOk = True
                , reportStatus = attemptStatus attempt
                , reportLatencyMs = Just (attemptLatencyMs attempt)
                , reportError = Nothing
                }
            , Just value
            )
        Nothing ->
          go rest nextAttempts candidateCount

fetchCandidate :: Manager -> ProbeTarget -> String -> (BL.ByteString -> Either Text value) -> IO (ProbeAttempt, Maybe value)
fetchCandidate manager target candidateUrl validate = do
  start <- getCurrentTime
  result <-
    try $ do
      request <- coreRequestWithTimeout QuickMetadata candidateUrl rangeHeaders
      response <- httpLbs request manager
      let code = statusCode (responseStatus response)
          body = responseBody response
      pure (code, body, show (getUri request))
  end <- getCurrentTime
  let elapsed = latencyMs start end
  case result of
    Left (err :: SomeException) ->
      pure
        ( ProbeAttempt
            { attemptUrl = candidateUrl
            , attemptStatus = Nothing
            , attemptLatencyMs = elapsed
            , attemptOk = False
            , attemptError = Just (Text.pack (show err))
            }
        , Nothing
        )
    Right (code, body, finalUrl)
      | httpOk code ->
          case validate body of
            Right value ->
              pure
                ( ProbeAttempt
                    { attemptUrl = finalUrl
                    , attemptStatus = Just code
                    , attemptLatencyMs = elapsed
                    , attemptOk = True
                    , attemptError = Nothing
                    }
                , Just value
                )
            Left err ->
              pure
                ( ProbeAttempt
                    { attemptUrl = finalUrl
                    , attemptStatus = Just code
                    , attemptLatencyMs = elapsed
                    , attemptOk = False
                    , attemptError = Just err
                    }
                , Nothing
                )
      | otherwise ->
          pure
            ( ProbeAttempt
                { attemptUrl = finalUrl
                , attemptStatus = Just code
                , attemptLatencyMs = elapsed
                , attemptOk = False
                , attemptError = Just (Text.pack ("HTTP " <> show code))
                }
            , Nothing
            )
  where
    rangeHeaders =
      [ ("Range", "bytes=0-0")
      | probeRangeOnly target
      ]

httpOk :: Int -> Bool
httpOk code =
  code >= 200 && code < 300

latencyMs :: UTCTime -> UTCTime -> Int
latencyMs start end =
  floor (realToFrac (diffUTCTime end start) * (1000 :: Double))

blockedReport :: Text -> String -> Text -> ProbeReport
blockedReport label url reason =
  ProbeReport
    { reportLabel = label
    , reportUrl = url
    , reportCandidateCount = 0
    , reportAttempts = []
    , reportSelectedUrl = Nothing
    , reportSelectedIndex = Nothing
    , reportOk = False
    , reportStatus = Nothing
    , reportLatencyMs = Nothing
    , reportError = Just reason
    }

reportJson :: ProbeReport -> Value
reportJson report =
  object
    [ "endpoint" .= reportLabel report
    , "url" .= reportUrl report
    , "candidateCount" .= reportCandidateCount report
    , "selectedUrl" .= reportSelectedUrl report
    , "selectedIndex" .= reportSelectedIndex report
    , "usedFallback" .= maybe False (> 0) (reportSelectedIndex report)
    , "ok" .= reportOk report
    , "status" .= reportStatus report
    , "latencyMs" .= reportLatencyMs report
    , "error" .= reportError report
    , "attempts" .= map attemptJson (reportAttempts report)
    ]

attemptJson :: ProbeAttempt -> Value
attemptJson attempt =
  object
    [ "url" .= attemptUrl attempt
    , "status" .= attemptStatus attempt
    , "latencyMs" .= attemptLatencyMs attempt
    , "ok" .= attemptOk attempt
    , "error" .= attemptError attempt
    ]

selectedManifestVersionUrl :: VersionManifest -> Maybe Text
selectedManifestVersionUrl manifest =
  versionSummaryUrl <$> listToMaybe (manifestVersions manifest)

selectedLibraryUrl :: VersionJson -> Maybe String
selectedLibraryUrl versionJson =
  Text.unpack
    <$> listToMaybe
      [ url
      | library <- versionLibraries versionJson
      , isAllowedByRules (libraryRules library)
      , Just downloads <- [libraryDownloads library]
      , Just artifact <- [libraryArtifact downloads]
      , Just url <- [downloadUrl artifact]
      ]

selectedClientDownloadUrl :: VersionJson -> Maybe Text
selectedClientDownloadUrl versionJson =
  Map.lookup "client" (versionDownloads versionJson) >>= downloadUrl

selectedAssetObjectUrl :: AssetIndex -> Maybe String
selectedAssetObjectUrl assetIndex =
  case sortOn (assetSize . snd) (Map.toList (assetObjects assetIndex)) of
    [] -> Nothing
    (_, asset):_ ->
      let hash = assetHash asset
          prefix = Text.take 2 hash
       in Just $
            Text.unpack $
              "https://resources.download.minecraft.net/"
                <> prefix
                <> "/"
                <> hash
