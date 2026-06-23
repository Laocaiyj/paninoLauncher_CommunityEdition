{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Network.Probe
  ( ProbeReport(..)
  , ProbeTarget(..)
  , fetchJsonProbe
  , selectedAssetObjectUrl
  , selectedClientDownloadUrl
  , selectedLibraryUrl
  , selectedManifestVersionUrl
  , sourceTestValue
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( FromJSON
  , Value
  , eitherDecode
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.List (sortOn)
import qualified Data.Map.Strict as Map
import Data.Maybe (listToMaybe)
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
  , responseStatus
  )
import Network.HTTP.Types.Status (statusCode)
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
  )
import Panino.Net.Sources (resolveSourceUrls)

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

fetchJsonProbe :: FromJSON value => Manager -> ProbeTarget -> IO (ProbeReport, Maybe value)
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
