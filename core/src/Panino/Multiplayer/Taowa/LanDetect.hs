{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Multiplayer.Taowa.LanDetect
  ( detectLanPortFromLog
  , taowaLatestLogPath
  , validateLocalPort
  , validateManualLanPort
  , watchLanPort
  ) where

import Control.Concurrent (threadDelay)
import Control.Exception
  ( SomeException
  , bracket
  , try
  )
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Char (isDigit)
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Text.Encoding (decodeUtf8With)
import Data.Text.Encoding.Error (lenientDecode)
import Data.Time.Clock
  ( addUTCTime
  , getCurrentTime
  )
import Network.Socket
  ( Family(AF_INET)
  , SockAddr(SockAddrInet)
  , Socket
  , SocketType(Stream)
  , close
  , connect
  , defaultProtocol
  , socket
  , tupleToHostAddress
  , withSocketsDo
  )
import Panino.Diagnostics.Types (Diagnostic)
import Panino.Multiplayer.Taowa.Diagnostics
  ( taowaDiagnosticForCode
  , taowaLanPortNotDetectedDiagnostic
  , taowaLocalPortUnreachableDiagnostic
  )
import Panino.Multiplayer.Taowa.Types
  ( TaowaLanDetectRequest(..)
  , TaowaLanDetectStatus(..)
  , TaowaLanEvidence(..)
  , TaowaLanPortDetection(..)
  , TaowaLanValidatePortRequest(..)
  )
import System.Directory
  ( doesFileExist
  , getFileSize
  )
import System.FilePath ((</>))
import System.Timeout (timeout)

detectLanPortFromLog :: ByteString -> [TaowaLanEvidence]
detectLanPortFromLog =
  mapMaybe evidenceFromLine . Text.lines . decodeUtf8With lenientDecode

taowaLatestLogPath :: FilePath -> FilePath
taowaLatestLogPath gameDir =
  gameDir </> "logs" </> "latest.log"

watchLanPort :: TaowaLanDetectRequest -> IO TaowaLanPortDetection
watchLanPort request = do
  startedAt <- getCurrentTime
  let gameDir = taowaLanDetectGameDir request
      logPath = taowaLatestLogPath gameDir
      timeoutSeconds = clampTimeoutSeconds (fromMaybe 45 (taowaLanDetectTimeoutSeconds request))
      deadline = addUTCTime (fromIntegral timeoutSeconds) startedAt
  initialOffset <- currentFileSizeOrZero logPath
  loop logPath gameDir deadline initialOffset []
  where
    loop logPath gameDir deadline offset accumulated = do
      now <- getCurrentTime
      if now >= deadline
        then timeoutDetection logPath gameDir accumulated
        else do
          exists <- doesFileExist logPath
          if not exists
            then do
              threadDelay pollDelayMicros
              loop logPath gameDir deadline 0 accumulated
            else do
              size <- getFileSize logPath
              chunk <-
                if size > offset
                  then readFileSlice logPath offset
                  else pure BS.empty
              let detectedEvidence = detectLanPortFromLog chunk
                  nextAccumulated = accumulated <> detectedEvidence
              maybeDetected <- firstReachablePort (reverse detectedEvidence)
              case maybeDetected of
                Just (port, evidence) ->
                  pure (detectedResponse logPath gameDir port [evidence])
                Nothing -> do
                  threadDelay pollDelayMicros
                  loop logPath gameDir deadline size nextAccumulated

    timeoutDetection logPath gameDir accumulated = do
      tailEvidence <- recentLogEvidence logPath
      maybeDetected <- firstReachablePort (reverse tailEvidence)
      let evidence =
            accumulated
              <> tailEvidence
              <> [ TaowaLanEvidence
                    { taowaLanEvidenceKind = "manual_required"
                    , taowaLanEvidenceMessage = "LAN port was not detected before timeout; ask the user to enter the Minecraft LAN port manually."
                    , taowaLanEvidencePort = Nothing
                    }
                 ]
      case maybeDetected of
        Just (port, match) ->
          pure (detectedResponse logPath gameDir port [match])
        Nothing ->
          pure (manualRequiredResponse logPath gameDir evidence)

    detectedResponse logPath gameDir port evidence =
      TaowaLanPortDetection
        { taowaLanInstanceId = taowaLanDetectInstanceId request
        , taowaLanGameDir = gameDir
        , taowaLanLogPath = logPath
        , taowaLanStatus = TaowaLanDetected
        , taowaLanDetectedPort = Just port
        , taowaLanEvidence = evidence
        , taowaLanDiagnostics = []
        }

    manualRequiredResponse logPath gameDir evidence =
      TaowaLanPortDetection
        { taowaLanInstanceId = taowaLanDetectInstanceId request
        , taowaLanGameDir = gameDir
        , taowaLanLogPath = logPath
        , taowaLanStatus = TaowaLanManualRequired
        , taowaLanDetectedPort = Nothing
        , taowaLanEvidence = evidence
        , taowaLanDiagnostics = [taowaLanPortNotDetectedDiagnostic gameDir logPath]
        }

validateManualLanPort :: TaowaLanValidatePortRequest -> IO TaowaLanPortDetection
validateManualLanPort request = do
  reachable <- validateLocalPort (taowaValidateLocalPort request)
  let gameDir = fromMaybe "" (taowaValidateGameDir request)
      logPath = maybe "" taowaLatestLogPath (taowaValidateGameDir request)
      evidence =
        [ TaowaLanEvidence
            { taowaLanEvidenceKind = if reachable then "manual_port_reachable" else "manual_port_unreachable"
            , taowaLanEvidenceMessage =
                if reachable
                  then "Manual LAN port is reachable on 127.0.0.1."
                  else "Manual LAN port is not reachable on 127.0.0.1."
            , taowaLanEvidencePort = Just (taowaValidateLocalPort request)
            }
        ]
  pure
    TaowaLanPortDetection
      { taowaLanInstanceId = taowaValidateInstanceId request
      , taowaLanGameDir = gameDir
      , taowaLanLogPath = logPath
      , taowaLanStatus =
          if reachable
            then TaowaLanDetected
            else TaowaLanManualRequired
      , taowaLanDetectedPort =
          if reachable
            then Just (taowaValidateLocalPort request)
            else Nothing
      , taowaLanEvidence = evidence
      , taowaLanDiagnostics =
          if reachable
            then []
            else [manualPortDiagnostic gameDir (taowaValidateLocalPort request)]
      }

manualPortDiagnostic :: FilePath -> Int -> Diagnostic
manualPortDiagnostic gameDir port
  | validPort port =
      taowaLocalPortUnreachableDiagnostic gameDir (Just port)
  | otherwise =
      taowaDiagnosticForCode
        "taowa_invalid_local_port"
        "lan"
        "Manual LAN port must be 1-65535."
        [ ("gameDir", Text.pack gameDir)
        , ("localPort", Text.pack (show port))
        ]
        (if null gameDir then Nothing else Just gameDir)

validateLocalPort :: Int -> IO Bool
validateLocalPort port
  | not (validPort port) = pure False
  | otherwise = do
      result <- timeout connectTimeoutMicros (try connectLocalhost :: IO (Either SomeException ()))
      pure (maybe False (either (const False) (const True)) result)
  where
    connectLocalhost =
      withSocketsDo $
        bracket open close $ \sock ->
          connect sock (SockAddrInet (fromIntegral port) (tupleToHostAddress (127, 0, 0, 1)))
    open :: IO Socket
    open = socket AF_INET Stream defaultProtocol

firstReachablePort :: [TaowaLanEvidence] -> IO (Maybe (Int, TaowaLanEvidence))
firstReachablePort evidence =
  case [(port, item) | item <- evidence, Just port <- [taowaLanEvidencePort item], validPort port] of
    [] -> pure Nothing
    (port, item):rest -> do
      reachable <- validateLocalPort port
      if reachable
        then pure (Just (port, item))
        else firstReachablePort [nextItem | (_, nextItem) <- rest]

evidenceFromLine :: Text -> Maybe TaowaLanEvidence
evidenceFromLine line =
  case mapMaybe (`portAfterMarker` line) lanPortMarkers of
    [] -> Nothing
    (marker, port):_ ->
      Just
        TaowaLanEvidence
          { taowaLanEvidenceKind = "log_line"
          , taowaLanEvidenceMessage = Text.strip line <> " [" <> marker <> "]"
          , taowaLanEvidencePort = Just port
          }

portAfterMarker :: (Text, Text) -> Text -> Maybe (Text, Int)
portAfterMarker (markerName, marker) line = do
  afterMarker <- markerSuffix marker (Text.toLower line)
  port <- parsePort (Text.unpack (Text.dropWhile (not . isDigit) afterMarker))
  pure (markerName, port)

markerSuffix :: Text -> Text -> Maybe Text
markerSuffix marker line =
  case Text.breakOn marker line of
    (_, rest)
      | Text.null rest -> Nothing
      | otherwise -> Just (Text.drop (Text.length marker) rest)

parsePort :: String -> Maybe Int
parsePort value =
  case span isDigit value of
    ("", _) -> Nothing
    (digits, _) ->
      let port = read digits
       in if validPort port then Just port else Nothing

recentLogEvidence :: FilePath -> IO [TaowaLanEvidence]
recentLogEvidence logPath = do
  exists <- doesFileExist logPath
  if not exists
    then
      pure
        [ TaowaLanEvidence
            { taowaLanEvidenceKind = "log_not_found"
            , taowaLanEvidenceMessage = "Minecraft latest.log was not found."
            , taowaLanEvidencePort = Nothing
            }
        ]
    else do
      content <- BS.readFile logPath
      let lengthBytes = BS.length content
          start = max 0 (lengthBytes - recentTailBytes)
      pure (detectLanPortFromLog (BS.drop start content))

readFileSlice :: FilePath -> Integer -> IO ByteString
readFileSlice path offset = do
  content <- BS.readFile path
  pure (BS.drop (fromIntegral offset) content)

currentFileSizeOrZero :: FilePath -> IO Integer
currentFileSizeOrZero path = do
  exists <- doesFileExist path
  if exists then getFileSize path else pure 0

validPort :: Int -> Bool
validPort port =
  port >= 1 && port <= 65535

clampTimeoutSeconds :: Int -> Int
clampTimeoutSeconds seconds =
  max 1 (min 60 seconds)

lanPortMarkers :: [(Text, Text)]
lanPortMarkers =
  [ ("started_serving_on", "started serving on ")
  , ("started_lan_server_on_port", "started lan server on port ")
  , ("local_game_hosted_on_port", "local game hosted on port ")
  ]

pollDelayMicros :: Int
pollDelayMicros = 500000

connectTimeoutMicros :: Int
connectTimeoutMicros = 500000

recentTailBytes :: Int
recentTailBytes = 65536
