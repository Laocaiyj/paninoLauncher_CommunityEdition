{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Diagnostics.Probes
  ( DiagnosticsProbeRequest(..)
  , baselineOk
  , checkOk
  , curseForgeProbe
  , decodeProbeRequest
  , directoryBaseline
  , fileDescriptorLimit
  , targetDirectoryProbe
  , valueBool
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( FromJSON(..)
  , Value(..)
  , eitherDecode
  , object
  , withObject
  , (.:?)
  , (.=)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.Int (Int64)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock
  ( UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Network.HTTP.Client
  ( httpNoBody
  , responseStatus
  )
import Network.HTTP.Types.Status (statusCode)
import Panino.Api.Server.State (ServerState(..))
import Panino.Net.Http
  ( RequestTimeoutClass(..)
  , coreRequestWithTimeout
  )
import System.Directory
  ( createDirectoryIfMissing
  , removeFile
  )
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
import System.Process
  ( CreateProcess
  , proc
  , readCreateProcessWithExitCode
  )

data DiagnosticsProbeRequest = DiagnosticsProbeRequest
  { diagnosticsProbeGameDir :: Maybe FilePath
  , diagnosticsProbeCurseForgeApiKey :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON DiagnosticsProbeRequest where
  parseJSON =
    withObject "DiagnosticsProbeRequest" $ \value ->
      DiagnosticsProbeRequest
        <$> value .:? "gameDir"
        <*> value .:? "curseForgeAPIKey"

decodeProbeRequest :: BL.ByteString -> Either String DiagnosticsProbeRequest
decodeProbeRequest body
  | BL.null body = Right (DiagnosticsProbeRequest Nothing Nothing)
  | otherwise = eitherDecode body

targetDirectoryProbe :: Maybe FilePath -> IO Value
targetDirectoryProbe Nothing =
  pure $
    probeCheck
      "target-game-dir"
      "Target game directory"
      "skipped"
      True
      False
      Nothing
      [("detail", String "No gameDir was configured for this probe.")]
targetDirectoryProbe (Just gameDir) = do
  let marker = gameDir </> ".panino-diagnostics-probe"
  result <-
    try $ do
      createDirectoryIfMissing True gameDir
      writeFile marker "ok"
      removeFile marker
  case result of
    Right () ->
      pure $
        probeCheck
          "target-game-dir"
          "Target game directory"
          "writable"
          True
          True
          Nothing
          [("path", String (Text.pack gameDir))]
    Left (err :: SomeException) ->
      pure $
        probeCheck
          "target-game-dir"
          "Target game directory"
          "not_writable"
          False
          True
          (Just (Text.pack (show err)))
          [("path", String (Text.pack gameDir))]

curseForgeProbe :: ServerState -> Maybe Text -> IO Value
curseForgeProbe _ Nothing =
  pure $
    probeCheck
      "curseforge-api"
      "CurseForge API"
      "missing_api_key"
      True
      False
      Nothing
      [("detail", String "No CurseForge API key was supplied; CurseForge remains unavailable until the user provides one.")]
curseForgeProbe state (Just key) = do
  start <- getCurrentTime
  result <-
    try $ do
      request <-
        coreRequestWithTimeout
          QuickMetadata
          "https://api.curseforge.com/v1/categories?gameId=432"
          [("x-api-key", key)]
      response <- httpNoBody request (stateHttpManager state)
      pure (statusCode (responseStatus response))
  end <- getCurrentTime
  let elapsed = latencyMs start end
  case result of
    Right code ->
      pure $
        probeCheck
          "curseforge-api"
          "CurseForge API"
          (if code >= 200 && code < 300 then "authorized" else "rejected")
          (code >= 200 && code < 300)
          True
          Nothing
          [ ("status", Number (fromIntegral code))
          , ("latencyMs", Number (fromIntegral elapsed))
          ]
    Left (err :: SomeException) ->
      pure $
        probeCheck
          "curseforge-api"
          "CurseForge API"
          "request_failed"
          False
          True
          (Just (Text.pack (show err)))
          [("latencyMs", Number (fromIntegral elapsed))]

directoryBaseline :: Maybe FilePath -> IO Value
directoryBaseline Nothing =
  pure $
    object
      [ "gameDir" .= Null
      , "status" .= ("warning" :: Text)
      , "writable" .= False
      , "availableDiskBytes" .= (Nothing :: Maybe Int64)
      , "writeSampleBytes" .= (0 :: Int)
      , "writeBytesPerSecond" .= (0 :: Int64)
      , "cache" .= Null
      , "staging" .= Null
      , "actions" .= ["Choose or create a game directory before running install diagnostics." :: Text]
      ]
directoryBaseline (Just gameDir) = do
  let sampleBytes = 1024 * 1024
      marker = gameDir </> ".panino-environment-write-test"
  availableBytes <- availableDiskBytes gameDir
  cacheCheck <- directoryWriteCheck "cache" (gameDir </> "cache")
  stagingCheck <- directoryWriteCheck "staging" (gameDir </> "downloads")
  start <- getCurrentTime
  result <-
    try $ do
      createDirectoryIfMissing True gameDir
      BS.writeFile marker (BS.replicate sampleBytes 90)
      removeFile marker
  end <- getCurrentTime
  let elapsed = max 1 (latencyMs start end)
  case result of
    Right () ->
      pure $
        object
          [ "gameDir" .= gameDir
          , "status" .= ("ok" :: Text)
          , "writable" .= True
          , "availableDiskBytes" .= availableBytes
          , "writeSampleBytes" .= sampleBytes
          , "writeElapsedMs" .= elapsed
          , "writeBytesPerSecond" .= bytesPerSecond (fromIntegral sampleBytes) elapsed
          , "cache" .= cacheCheck
          , "staging" .= stagingCheck
          , "actions" .= ([] :: [Text])
          ]
    Left (err :: SomeException) ->
      pure $
        object
          [ "gameDir" .= gameDir
          , "status" .= ("blocking" :: Text)
          , "writable" .= False
          , "availableDiskBytes" .= availableBytes
          , "writeSampleBytes" .= sampleBytes
          , "writeElapsedMs" .= elapsed
          , "writeBytesPerSecond" .= (0 :: Int64)
          , "error" .= Text.pack (show err)
          , "cache" .= cacheCheck
          , "staging" .= stagingCheck
          , "actions" .= ["Choose a writable game directory or grant file access permission." :: Text]
          ]

directoryWriteCheck :: Text -> FilePath -> IO Value
directoryWriteCheck checkId path = do
  let marker = path </> ".panino-write-test"
  result <-
    try $ do
      createDirectoryIfMissing True path
      writeFile marker "ok"
      removeFile marker
  case result of
    Right () ->
      pure $
        object
          [ "id" .= checkId
          , "path" .= path
          , "status" .= ("ok" :: Text)
          , "writable" .= True
          , "actions" .= ([] :: [Text])
          ]
    Left (err :: SomeException) ->
      pure $
        object
          [ "id" .= checkId
          , "path" .= path
          , "status" .= ("blocking" :: Text)
          , "writable" .= False
          , "error" .= Text.pack (show err)
          , "actions" .= ["Fix permissions for " <> checkId <> " before installing large packs." :: Text]
          ]

baselineOk :: Value -> Bool
baselineOk (Object value) =
  objectBool "writable" value
    && nestedWritable "cache" value
    && nestedWritable "staging" value
  where
    nestedWritable key objectValue =
      case KeyMap.lookup (Key.fromText key) objectValue of
        Just (Object nested) -> objectBool "writable" nested
        _ -> False
baselineOk _ = False

objectBool :: Text -> KeyMap.KeyMap Value -> Bool
objectBool key value =
  case KeyMap.lookup (Key.fromText key) value of
    Just (Bool result) -> result
    _ -> False

fileDescriptorLimit :: IO (Maybe Int)
fileDescriptorLimit = do
  result <- tryReadProcess (proc "/bin/zsh" ["-lc", "ulimit -n"])
  pure (parseInt =<< result)

availableDiskBytes :: FilePath -> IO (Maybe Int64)
availableDiskBytes path = do
  result <- tryReadProcess (proc "df" ["-k", path])
  pure (parseDfAvailableBytes =<< result)

tryReadProcess :: CreateProcess -> IO (Maybe String)
tryReadProcess process = do
  result <- try (readCreateProcessWithExitCode process "")
  pure $ case result of
    Right (ExitSuccess, stdoutText, _) -> Just (trim stdoutText)
    Right (_, _, stderrText) -> Just (trim stderrText)
    Left (_ :: SomeException) -> Nothing

parseInt64 :: String -> Maybe Int64
parseInt64 value =
  case reads value of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing

parseInt :: String -> Maybe Int
parseInt value =
  case reads value of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing

parseDfAvailableBytes :: String -> Maybe Int64
parseDfAvailableBytes output = do
  row <- listToMaybe (drop 1 (lines output))
  availableKb <- case drop 3 (words row) of
    value : _ -> parseInt64 value
    [] -> Nothing
  pure (availableKb * 1024)

trim :: String -> String
trim =
  reverse . dropWhile (`elem` ['\n', '\r', ' ', '\t']) . reverse . dropWhile (`elem` ['\n', '\r', ' ', '\t'])

bytesPerSecond :: Int64 -> Int -> Int64
bytesPerSecond bytes elapsedMs =
  round (fromIntegral bytes * 1000 / max 1 (fromIntegral elapsedMs :: Double))

probeCheck :: Text -> Text -> Text -> Bool -> Bool -> Maybe Text -> [(Key.Key, Value)] -> Value
probeCheck checkId title status ok required maybeError extra =
  object $
    [ "id" .= checkId
    , "title" .= title
    , "status" .= status
    , "ok" .= ok
    , "required" .= required
    , "error" .= maybeError
    ]
      <> extra

checkOk :: Value -> Bool
checkOk value =
  not (valueBool "required" value) || valueBool "ok" value

valueBool :: Text -> Value -> Bool
valueBool key (Object value) =
  case KeyMap.lookup (Key.fromText key) value of
    Just (Bool result) -> result
    _ -> False
valueBool _ _ = False

latencyMs :: UTCTime -> UTCTime -> Int
latencyMs start end =
  floor (realToFrac (diffUTCTime end start) * (1000 :: Double))
