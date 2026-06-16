{-# LANGUAGE OverloadedStrings #-}

module Panino.Multiplayer.Taowa.Diagnostics
  ( classifyTaowaFrpcFailure
  , readRedactedTaowaLogTail
  , readTaowaLogTail
  , taowaDiagnosticForCode
  , taowaLanPortNotDetectedDiagnostic
  , taowaLocalPortUnreachableDiagnostic
  , taowaSessionDiagnosticExportPath
  , taowaSessionNotFoundDiagnostic
  , writeTaowaSessionDiagnosticExport
  ) where

import Data.Aeson
  ( encode
  , object
  , (.=)
  )
import Control.Concurrent (threadDelay)
import Control.Exception
  ( SomeException
  , try
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Text.Encoding (decodeUtf8With)
import Data.Text.Encoding.Error (lenientDecode)
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , DiagnosticAction(..)
  , DiagnosticEvidence(..)
  , redactedText
  )
import Panino.Multiplayer.Taowa.Types
  ( TaowaFrpProfilePublic
  , TaowaSession(..)
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , getFileSize
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  )
import System.IO
  ( IOMode(..)
  , SeekMode(..)
  , hSeek
  , withBinaryFile
  )

taowaDiagnosticForCode :: Text -> Text -> Text -> [(Text, Text)] -> Maybe FilePath -> Diagnostic
taowaDiagnosticForCode code phase detail context maybeFilePath =
  Diagnostic
    { diagnosticCode = code
    , diagnosticPhase = phase
    , diagnosticSeverity = severityForTaowaCode code
    , diagnosticTitle = titleForTaowaCode code
    , diagnosticMessage = messageForTaowaCode code
    , diagnosticCause = Text.take 280 (redactedText detail)
    , diagnosticAction = actionForTaowaCode code
    , diagnosticRetryable = retryableForTaowaCode code
    , diagnosticUserVisible = True
    , diagnosticSource = "taowa"
    , diagnosticTaskId = Nothing
    , diagnosticPlanId = Nothing
    , diagnosticPackageId = Nothing
    , diagnosticFilePath = maybeFilePath
    , diagnosticUrlHost = Nothing
    , diagnosticEvidence = evidenceFromContext context
    , diagnosticDeveloperDetail =
        Just $
          Text.strip $
            redactedText $
              Text.unlines $
                [ code <> ": " <> phase
                , detail
                ]
                  <> map (\(key, value) -> key <> "=" <> redactedText value) context
    }

taowaLocalPortUnreachableDiagnostic :: FilePath -> Maybe Int -> Diagnostic
taowaLocalPortUnreachableDiagnostic gameDir maybePort =
  taowaDiagnosticForCode
    "taowa_local_port_unreachable"
    "lan"
    "The selected LAN port is not reachable on 127.0.0.1."
    ( [ ("gameDir", Text.pack gameDir)
      ]
        <> maybe [] (\port -> [("localPort", Text.pack (show port))]) maybePort
    )
    (if null gameDir then Nothing else Just gameDir)

taowaLanPortNotDetectedDiagnostic :: FilePath -> FilePath -> Diagnostic
taowaLanPortNotDetectedDiagnostic gameDir logPath =
  taowaDiagnosticForCode
    "taowa_lan_port_not_detected"
    "lan"
    "Panino did not find a Minecraft LAN port in latest.log before timeout."
    [ ("gameDir", Text.pack gameDir)
    , ("logPath", Text.pack logPath)
    ]
    (Just logPath)

taowaSessionNotFoundDiagnostic :: Text -> Diagnostic
taowaSessionNotFoundDiagnostic sessionId =
  taowaDiagnosticForCode
    "taowa_session_not_found"
    "session"
    ("Taowa session was not found: " <> sessionId)
    [("sessionId", sessionId)]
    Nothing

classifyTaowaFrpcFailure :: Text -> Text -> [(Text, Text)] -> FilePath -> Diagnostic
classifyTaowaFrpcFailure startError logTail context logPath =
  taowaDiagnosticForCode
    code
    "frpc"
    (Text.strip (startError <> "\n" <> logTail))
    (context <> [("frpcLogTail", logTail), ("frpcLogPath", Text.pack logPath)])
    (Just logPath)
  where
    raw = Text.toLower (startError <> "\n" <> logTail)
    code
      | containsAny ["executable was not found", "no such file"] =
          "taowa_frpc_not_found"
      | containsAny ["not executable", "permission denied", "operation not permitted"] =
          "taowa_frpc_not_executable"
      | containsAny ["token", "auth", "authorization"]
          && containsAny ["invalid", "failed", "unauthorized", "reject", "login fail"] =
          "taowa_frp_token_rejected"
      | containsAny ["remote port", "already used", "already in use", "port unavailable", "port conflict", "bind"]
          && containsAny ["port", "bind", "listen"] =
          "taowa_frp_remote_port_conflict"
      | containsAny ["127.0.0.1", "localhost", "local port"]
          && containsAny ["connection refused", "connect failed", "unreachable"] =
          "taowa_local_port_unreachable"
      | otherwise =
          "taowa_frpc_start_failed"
    containsAny needles = any (`Text.isInfixOf` raw) needles

readTaowaLogTail :: FilePath -> IO Text
readTaowaLogTail path = do
  exists <- doesFileExist path
  if not exists
    then pure ""
    else do
      fileSize <- getFileSize path
      let offset = max 0 (fileSize - fromIntegral taowaLogTailBytes)
          bytesToRead = fromIntegral (fileSize - offset)
      content <- readTailBytesWithRetry 5 path offset bytesToRead
      pure (decodeUtf8With lenientDecode content)

readTailBytesWithRetry :: Int -> FilePath -> Integer -> Int -> IO BS.ByteString
readTailBytesWithRetry retries path offset bytesToRead = do
  result <- try (readTailBytes path offset bytesToRead) :: IO (Either SomeException BS.ByteString)
  case result of
    Right content -> pure content
    Left _
      | retries > 0 -> do
          threadDelay 50000
          readTailBytesWithRetry (retries - 1) path offset bytesToRead
      | otherwise -> pure ""

readTailBytes :: FilePath -> Integer -> Int -> IO BS.ByteString
readTailBytes path offset bytesToRead =
  withBinaryFile path ReadMode $ \handle -> do
    hSeek handle AbsoluteSeek offset
    BS.hGet handle bytesToRead

readRedactedTaowaLogTail :: FilePath -> IO Text
readRedactedTaowaLogTail =
  fmap redactedText . readTaowaLogTail

taowaSessionDiagnosticExportPath :: TaowaSession -> FilePath
taowaSessionDiagnosticExportPath session =
  takeDirectory (taowaSessionFrpcLogPath session) </> "diagnostics.json"

writeTaowaSessionDiagnosticExport :: Maybe TaowaFrpProfilePublic -> TaowaSession -> IO ()
writeTaowaSessionDiagnosticExport maybeProfile session = do
  logTail <- readRedactedTaowaLogTail (taowaSessionFrpcLogPath session)
  let path = taowaSessionDiagnosticExportPath session
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path $
    encode $
      object
        [ "kind" .= ("taowa.session" :: Text)
        , "session" .= session
        , "profile" .= maybeProfile
        , "frpcLogPath" .= taowaSessionFrpcLogPath session
        , "frpcLogTail" .= logTail
        , "diagnostics" .= taowaSessionDiagnostics session
        ]

severityForTaowaCode :: Text -> Text
severityForTaowaCode code
  | code == "taowa_lan_port_not_detected" = "warning"
  | otherwise = "error"

retryableForTaowaCode :: Text -> Bool
retryableForTaowaCode code =
  code
    `elem` [ "taowa_lan_port_not_detected"
           , "taowa_local_port_unreachable"
           , "taowa_frpc_start_failed"
           ]

titleForTaowaCode :: Text -> Text
titleForTaowaCode code =
  case code of
    "taowa_profile_disabled" -> "Taowa FRP profile is disabled"
    "taowa_invalid_local_port" -> "LAN port is invalid"
    "taowa_local_port_unreachable" -> "LAN port is not reachable"
    "taowa_lan_port_not_detected" -> "LAN port was not detected"
    "taowa_frpc_not_found" -> "frpc executable was not found"
    "taowa_frpc_missing" -> "frpc executable was not found"
    "taowa_frpc_not_executable" -> "frpc is not executable"
    "taowa_frp_server_unreachable" -> "FRP server is not reachable"
    "taowa_profile_invalid" -> "Taowa FRP profile is invalid"
    "taowa_profile_in_use" -> "Taowa FRP profile is in use"
    "taowa_frpc_start_failed" -> "frpc failed to start"
    "taowa_frp_token_rejected" -> "FRP token was rejected"
    "taowa_frp_remote_port_conflict" -> "FRP remote port is unavailable"
    "taowa_session_stop_failed" -> "Taowa session failed to stop"
    "taowa_session_not_found" -> "Taowa session was not found"
    "taowa_session_stale_after_core_restart" -> "Taowa session needs cleanup after Core restart"
    _ -> Text.replace "_" " " code

messageForTaowaCode :: Text -> Text
messageForTaowaCode code =
  case code of
    "taowa_profile_disabled" -> "Enable the FRP profile before starting Taowa multiplayer."
    "taowa_invalid_local_port" -> "Enter the LAN port shown by Minecraft after opening the world to LAN."
    "taowa_local_port_unreachable" -> "Panino could not connect to the selected LAN port on this Mac."
    "taowa_lan_port_not_detected" -> "Open the world to LAN in Minecraft, then retry detection or enter the port manually."
    "taowa_frpc_not_found" -> "Choose a valid frpc executable from your third-party FRP provider."
    "taowa_frpc_missing" -> "Choose a valid frpc executable from your third-party FRP provider."
    "taowa_frpc_not_executable" -> "Grant execute permission to frpc or choose another executable."
    "taowa_frp_server_unreachable" -> "Panino could not connect to the configured third-party FRP server."
    "taowa_profile_invalid" -> "Review the FRP server address, ports, token, and frpc path."
    "taowa_profile_in_use" -> "Stop the running Taowa tunnel before deleting this FRP profile."
    "taowa_frpc_start_failed" -> "frpc exited before the tunnel became available. Open the frpc log for details."
    "taowa_frp_token_rejected" -> "The third-party FRP server rejected the configured token."
    "taowa_frp_remote_port_conflict" -> "The configured remote port is already used or unavailable on the FRP server."
    "taowa_session_stop_failed" -> "Panino could not stop frpc cleanly. Check the process and retry."
    "taowa_session_not_found" -> "The requested Taowa session is not active in this Core process."
    "taowa_session_stale_after_core_restart" -> "Core restarted and cannot manage the old frpc process handle. Stop any leftover frpc process and start a new session."
    _ -> "Taowa multiplayer failed. Open diagnostics for details."

actionForTaowaCode :: Text -> DiagnosticAction
actionForTaowaCode code =
  case actionSpec of
    (kind, label) ->
      DiagnosticAction
        { diagnosticActionKind = kind
        , diagnosticActionLabel = label
        , diagnosticActionTarget = Nothing
        , diagnosticActionPayload = Nothing
        }
  where
    actionSpec
      | code `elem` ["taowa_frpc_missing", "taowa_frpc_not_executable", "taowa_frp_token_rejected", "taowa_frp_remote_port_conflict", "taowa_profile_disabled"] =
          ("configureTaowaFrp", "Open Taowa FRP settings")
      | code `elem` ["taowa_frpc_not_found", "taowa_frp_server_unreachable", "taowa_profile_invalid", "taowa_profile_in_use"] =
          ("editFrpProfile", "Edit FRP profile")
      | code `elem` ["taowa_invalid_local_port", "taowa_local_port_unreachable", "taowa_lan_port_not_detected"] =
          ("retry", "Retry LAN detection")
      | otherwise =
          ("openDiagnostics", "Open Taowa diagnostics")

evidenceFromContext :: [(Text, Text)] -> [DiagnosticEvidence]
evidenceFromContext context =
  [ let redacted = redactedText value
     in DiagnosticEvidence key redacted (redacted /= value)
  | (key, value) <- context
  ]

taowaLogTailBytes :: Int
taowaLogTailBytes = 8192
