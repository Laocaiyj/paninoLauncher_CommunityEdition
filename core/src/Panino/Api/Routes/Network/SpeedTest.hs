{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Network.SpeedTest
  ( SpeedTestRequest(..)
  , decodeSpeedTestRequest
  , speedTestValue
  ) where

import Control.Applicative ((<|>))
import Control.Exception
  ( SomeException
  , try
  )
import Control.Monad (when)
import Data.Aeson
  ( FromJSON(..)
  , Value
  , eitherDecode
  , object
  , withObject
  , (.:?)
  , (.!=)
  , (.=)
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
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
  , responseBody
  , responseHeaders
  , responseStatus
  , withResponse
  )
import Network.HTTP.Types (HeaderName)
import Network.HTTP.Types.Status (statusCode)
import Panino.Api.Routes.Network.Config (proxyConfigured)
import Panino.Api.Routes.Network.Probe
  ( ProbeTarget(..)
  , fetchJsonProbe
  , selectedAssetObjectUrl
  , selectedClientDownloadUrl
  , selectedLibraryUrl
  , selectedManifestVersionUrl
  )
import Panino.Api.Server.State (ServerState(..))
import Panino.Core.Types
  ( urlText
  )
import Panino.Minecraft.Types
  ( DownloadInfo(..)
  , VersionJson(..)
  )
import Panino.Net.Http
  ( RequestTimeoutClass(..)
  , coreRequestWithTimeout
  )
import Panino.Net.Probe
  ( recordSourceThroughput
  , sourceHostKey
  )
import Panino.Net.Sources (resolveSourceUrls)

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
        Just <$> fetchJsonProbe manager (ProbeTarget "Mojang asset index" (Text.unpack (urlText assetIndexUrl)) False)
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

latencyMs :: UTCTime -> UTCTime -> Int
latencyMs start end =
  floor (realToFrac (diffUTCTime end start) * (1000 :: Double))
