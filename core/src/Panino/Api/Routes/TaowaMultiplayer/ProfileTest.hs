{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.TaowaMultiplayer.ProfileTest
  ( testTaowaFrpProfile
  ) where

import Control.Exception
  ( SomeException
  , bracket
  , try
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.Socket
  ( AddrInfo(..)
  , SocketType(Stream)
  , close
  , connect
  , defaultHints
  , getAddrInfo
  , socket
  , withSocketsDo
  )
import Panino.Multiplayer.Taowa.Diagnostics (taowaDiagnosticForCode)
import Panino.Multiplayer.Taowa.FrpcProcess (validateFrpcExecutable)
import Panino.Multiplayer.Taowa.Types
  ( TaowaFrpProfile(..)
  , TaowaFrpProfileTestCheck(..)
  , TaowaFrpProfileTestResponse(..)
  )
import System.Exit (ExitCode(..))
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )
import System.Timeout (timeout)

testTaowaFrpProfile :: TaowaFrpProfile -> IO TaowaFrpProfileTestResponse
testTaowaFrpProfile profile = do
  executableResult <- validateFrpcExecutable (taowaProfileFrpcPath profile)
  versionResult <-
    case executableResult of
      Left err -> pure (Left err)
      Right () -> runFrpcVersion (taowaProfileFrpcPath profile)
  serverReachable <- testTcpConnection (taowaProfileServerAddr profile) (taowaProfileServerPort profile)
  let executableCheck =
        case executableResult of
          Right () -> okCheck "frpcExecutable" "frpc executable is present and executable."
          Left err -> failedCheck "frpcExecutable" err
      versionCheck =
        case versionResult of
          Right versionText -> okCheck "frpcVersion" ("frpc --version succeeded: " <> versionText)
          Left err -> failedCheck "frpcVersion" err
      serverCheck =
        if serverReachable
          then okCheck "frpServerTcp" "FRP server TCP port is reachable."
          else failedCheck "frpServerTcp" "FRP server TCP port is not reachable."
      diagnostics =
        concat
          [ case executableResult of
              Right () -> []
              Left err ->
                [ taowaDiagnosticForCode
                    (if "not executable" `Text.isInfixOf` Text.toLower err then "taowa_frpc_not_executable" else "taowa_frpc_not_found")
                    "profile"
                    err
                    (profileContext profile)
                    (Just (taowaProfileFrpcPath profile))
                ]
          , case versionResult of
              Right _ -> []
              Left err
                | executableResult == Right () ->
                    [ taowaDiagnosticForCode
                        "taowa_profile_invalid"
                        "profile"
                        ("frpc --version failed: " <> err)
                        (profileContext profile)
                        (Just (taowaProfileFrpcPath profile))
                    ]
              _ -> []
          , if serverReachable
              then []
              else
                [ taowaDiagnosticForCode
                    "taowa_frp_server_unreachable"
                    "profile"
                    "Panino could not connect to the configured FRP server TCP port."
                    (profileContext profile)
                    Nothing
                ]
          ]
      checks = [executableCheck, versionCheck, serverCheck]
  pure
    TaowaFrpProfileTestResponse
      { taowaProfileTestProfileId = taowaProfileId profile
      , taowaProfileTestOk = all taowaProfileTestCheckOk checks
      , taowaProfileTestChecks = checks
      , taowaProfileTestDiagnostics = diagnostics
      }
  where
    okCheck name message =
      TaowaFrpProfileTestCheck name True message
    failedCheck name message =
      TaowaFrpProfileTestCheck name False message

runFrpcVersion :: FilePath -> IO (Either Text Text)
runFrpcVersion frpcPath = do
  result <-
    timeout 2000000 $
      try (readCreateProcessWithExitCode (proc frpcPath ["--version"]) "") ::
        IO (Maybe (Either SomeException (ExitCode, String, String)))
  case result of
    Just (Right (ExitSuccess, stdoutText, stderrText)) ->
      pure (Right (cleanProcessOutput stdoutText stderrText))
    Just (Right (exitCode, _stdoutText, stderrText)) ->
      pure (Left ("frpc --version exited with " <> Text.pack (show exitCode) <> ": " <> Text.pack stderrText))
    Just (Left err) ->
      pure (Left ("frpc --version failed: " <> Text.pack (show err)))
    Nothing ->
      pure (Left "frpc --version timed out")

testTcpConnection :: Text -> Int -> IO Bool
testTcpConnection host port = do
  result <-
    timeout 2000000 $
      try connectOnce :: IO (Maybe (Either SomeException ()))
  pure (maybe False (either (const False) (const True)) result)
  where
    connectOnce =
      withSocketsDo $ do
        addrs <- getAddrInfo (Just defaultHints { addrSocketType = Stream }) (Just (Text.unpack host)) (Just (show port))
        case addrs of
          [] -> fail "no address found"
          addr:_ ->
            bracket
              (socket (addrFamily addr) (addrSocketType addr) (addrProtocol addr))
              close
              (\sock -> connect sock (addrAddress addr))

cleanProcessOutput :: String -> String -> Text
cleanProcessOutput stdoutText stderrText =
  let value = Text.strip (Text.pack stdoutText <> "\n" <> Text.pack stderrText)
   in if Text.null value then "<no output>" else Text.take 240 value

profileContext :: TaowaFrpProfile -> [(Text, Text)]
profileContext profile =
  [ ("profileId", taowaProfileId profile)
  , ("serverAddr", taowaProfileServerAddr profile)
  , ("serverPort", Text.pack (show (taowaProfileServerPort profile)))
  , ("remotePort", Text.pack (show (taowaProfileRemotePort profile)))
  , ("frpcPath", Text.pack (taowaProfileFrpcPath profile))
  ]
