{-# LANGUAGE OverloadedStrings #-}

module Integration.Taowa
  ( testTaowaP0
  , testTaowaP1
  ) where

import Control.Concurrent
  ( threadDelay
  )
import Control.Concurrent.STM (newTVarIO)
import Control.Exception (finally)
import Data.Aeson
  ( decode
  , eitherDecode
  , encode
  )
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List
  ( find
  , isInfixOf
  )
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import Integration.Taowa.Lan
  ( testTaowaP1
  )
import Panino.Api.Routes.TaowaMultiplayer (testTaowaFrpProfile)
import Panino.Diagnostics.Types (Diagnostic(..))
import Panino.Multiplayer.Taowa.ConfigStore
  ( buildTaowaFrpProfile
  , findTaowaFrpProfile
  , readTaowaFrpProfiles
  , taowaProfilesPath
  , upsertTaowaFrpProfile
  )
import Panino.Multiplayer.Taowa.Diagnostics
  ( readRedactedTaowaLogTail
  , taowaSessionDiagnosticExportPath
  )
import Panino.Multiplayer.Taowa.FrpcConfig
  ( renderFrpcConfig
  , renderRedactedFrpcConfig
  )
import Panino.Multiplayer.Taowa.Session
  ( clearTaowaSessionHistory
  , listStoredTaowaSessions
  , listTaowaSessions
  , listTaowaSessionsIncludingStored
  , markStaleTaowaSessions
  , startTaowaSession
  , stopTaowaSession
  , taowaSessionJsonPath
  )
import Panino.Multiplayer.Taowa.Types
  ( TaowaFrpProfile(..)
  , TaowaFrpProfilePublic(..)
  , TaowaFrpProfileTestCheck(..)
  , TaowaFrpProfileTestResponse(..)
  , TaowaFrpProfileRequest(..)
  , TaowaSession(..)
  , TaowaSessionHistoryClearRequest(..)
  , TaowaSessionHistoryClearResponse(..)
  , TaowaSessionStartRequest(..)
  , TaowaSessionStatus(..)
  , TaowaTunnelProtocol(..)
  , publicProfile
  , taowaRemoteAddress
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , removeDirectoryRecursive
  )
import System.Exit (ExitCode(..))
import System.FilePath
  ( (</>)
  )
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )
import TestSupport
  ( assertEqual
  , catchAny
  )

testTaowaP0 :: FilePath -> IO ()
testTaowaP0 tempRoot = do
  let root = tempRoot </> "panino-taowa-p0"
      cleanup = removeDirectoryRecursive root `catchAny` \_ -> pure ()
  cleanup
  (do
      createDirectoryIfMissing True root
      let fakeFrpc = root </> "fake-frpc"
      writeFile fakeFrpc $
        unlines
          [ "#!/bin/sh"
          , "if [ \"$1\" = \"--version\" ]; then"
          , "  echo \"fake frpc 0.1\""
          , "  exit 0"
          , "fi"
          , "echo fake frpc started"
          , "echo config=$2"
          , "echo token=secret-token"
          , "trap 'exit 0' TERM INT"
          , "while true; do sleep 1; done"
          ]
      (chmodExit, _, chmodErr) <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", fakeFrpc]) ""
      assertEqual "taowa fake frpc chmod succeeds" ExitSuccess chmodExit
      assertEqual "taowa fake frpc chmod stderr" "" chmodErr

      let request =
            TaowaFrpProfileRequest
              { taowaRequestProfileId = Just "self-frp"
              , taowaRequestDisplayName = "Self FRP"
              , taowaRequestServerAddr = "example.frp.test"
              , taowaRequestServerPort = 7000
              , taowaRequestToken = Just "secret-token"
              , taowaRequestRemotePort = 25565
              , taowaRequestProtocol = TaowaTcp
              , taowaRequestFrpcPath = fakeFrpc
              , taowaRequestEnabled = True
              }
      profile <- buildTaowaFrpProfile Nothing request
      assertEqual "taowa profile json roundtrip" (Just profile) (decode (encode profile))
      let public = publicProfile profile
      assertEqual "taowa public profile redacts token" (Just "se...en") (taowaPublicToken public)
      assertEqual "taowa public profile records token presence" True (taowaPublicHasToken public)
      assertEqual "taowa remote address" "example.frp.test:25565" (taowaRemoteAddress profile)

      _ <- upsertTaowaFrpProfile root profile
      profileStoreExists <- doesFileExist (taowaProfilesPath root)
      assertEqual "taowa profile store is created" True profileStoreExists
      storedProfiles <- readTaowaFrpProfiles root
      assertEqual "taowa profile store roundtrip" [profile] storedProfiles
      storedProfile <- findTaowaFrpProfile root "self-frp"
      assertEqual "taowa profile lookup" (Just profile) storedProfile
      updatedWithoutToken <-
        buildTaowaFrpProfile
          (Just profile)
          request
            { taowaRequestDisplayName = "Self FRP Updated"
            , taowaRequestToken = Nothing
            }
      assertEqual "taowa profile update preserves existing token when omitted" (Just "secret-token") (taowaProfileToken updatedWithoutToken)

      let config = renderFrpcConfig profile "session!one" 34567
          redactedConfig = renderRedactedFrpcConfig profile "session!one" 34567
      assertEqual "taowa frpc config server address" True ("serverAddr = \"example.frp.test\"" `Text.isInfixOf` config)
      assertEqual "taowa frpc config local port" True ("localPort = 34567" `Text.isInfixOf` config)
      assertEqual "taowa frpc config remote port" True ("remotePort = 25565" `Text.isInfixOf` config)
      assertEqual "taowa frpc config includes token before write" True ("secret-token" `Text.isInfixOf` config)
      assertEqual "taowa redacted config hides token" False ("secret-token" `Text.isInfixOf` redactedConfig)
      assertEqual "taowa redacted config keeps token shape" True ("se...en" `Text.isInfixOf` redactedConfig)
      assertEqual "taowa proxy name is sanitized" True ("panino-taowa-session-one" `Text.isInfixOf` config)

      registry <- newTVarIO Map.empty
      let sessionRequest =
            TaowaSessionStartRequest
              { taowaStartProfileId = taowaProfileId profile
              , taowaStartInstanceId = Just "instance-1"
              , taowaStartGameDir = root </> "game"
              , taowaStartLocalPort = 34567
              }
      failedStart <- startTaowaSession root registry (profile { taowaProfileFrpcPath = root </> "missing-frpc" }) sessionRequest
      case failedStart of
        Left diagnostic ->
          assertEqual "taowa missing frpc reports diagnostic code" "taowa_frpc_not_found" (diagnosticCode diagnostic)
        Right unexpected -> do
          _ <- stopTaowaSession root registry (taowaSessionId unexpected)
          assertEqual "taowa missing frpc should not start" True False

      profileTest <- testTaowaFrpProfile (profile { taowaProfileServerAddr = "127.0.0.1", taowaProfileServerPort = 1 })
      assertEqual "taowa profile test runs frpc version check" True ("frpcVersion" `elem` map taowaProfileTestCheckName (taowaProfileTestChecks profileTest))
      assertEqual "taowa profile test reports unreachable FRP server" False (taowaProfileTestOk profileTest)
      assertEqual "taowa profile test includes server diagnostic" ["taowa_frp_server_unreachable"] (map diagnosticCode (taowaProfileTestDiagnostics profileTest))

      started <- startTaowaSession root registry profile sessionRequest
      case started of
        Left diagnostic ->
          assertEqual ("taowa fake frpc starts: " <> Text.unpack (diagnosticMessage diagnostic)) True False
        Right running -> do
          let sessionId = taowaSessionId running
              ensureStopped = do
                _ <- stopTaowaSession root registry sessionId
                pure ()
          (do
              assertEqual "taowa session enters running state" TaowaSessionRunning (taowaSessionStatus running)
              assertEqual "taowa session returns remote address" "example.frp.test:25565" (taowaSessionRemoteAddress running)
              sessionConfigExists <- doesFileExist (taowaSessionFrpcConfigPath running)
              assertEqual "taowa session writes frpc config" True sessionConfigExists
              sessionLogExists <- doesFileExist (taowaSessionFrpcLogPath running)
              assertEqual "taowa session creates frpc log" True sessionLogExists
              sessionConfig <- readFile (taowaSessionFrpcConfigPath running)
              assertEqual "taowa session config uses manual local port" True ("localPort = 34567" `isInfixOf` sessionConfig)
              threadDelay 250000
              listedRunning <- listTaowaSessions registry
              assertEqual "taowa session registry lists running session" [TaowaSessionRunning] (map taowaSessionStatus listedRunning)
              stopped <- stopTaowaSession root registry sessionId
              stoppedSession <-
                case stopped of
                  Left diagnostic -> do
                    assertEqual ("taowa fake frpc stops: " <> Text.unpack (diagnosticMessage diagnostic)) True False
                    pure running
                  Right stoppedSession -> do
                    assertEqual "taowa session enters stopped state" TaowaSessionStopped (taowaSessionStatus stoppedSession)
                    diagnosticExportExists <- doesFileExist (taowaSessionDiagnosticExportPath stoppedSession)
                    assertEqual "taowa session writes diagnostics export" True diagnosticExportExists
                    diagnosticExport <- BL.readFile (taowaSessionDiagnosticExportPath stoppedSession)
                    assertEqual "taowa diagnostics export redacts token" False ("secret-token" `isInfixOf` BL8.unpack diagnosticExport)
                    pure stoppedSession
              sessionLog <- readFile (taowaSessionFrpcLogPath running)
              assertEqual "taowa frpc log records process output" True ("fake frpc started" `isInfixOf` sessionLog)
              redactedLogTail <- readRedactedTaowaLogTail (taowaSessionFrpcLogPath running)
              assertEqual "taowa frpc log tail API redacts token" False ("secret-token" `Text.isInfixOf` redactedLogTail)
              listedStopped <- listTaowaSessions registry
              assertEqual "taowa session registry keeps stopped snapshot" [TaowaSessionStopped] (map taowaSessionStatus listedStopped)
              storedStopped <- listStoredTaowaSessions root
              assertEqual "taowa stored sessions include stopped session" (Just TaowaSessionStopped) (taowaSessionStatus <$> find ((== sessionId) . taowaSessionId) storedStopped)
              listedWithHistory <- listTaowaSessionsIncludingStored root registry
              assertEqual "taowa session list merges runtime and stored history" (Just TaowaSessionStopped) (taowaSessionStatus <$> find ((== sessionId) . taowaSessionId) listedWithHistory)
              sessionBytes <- BL.readFile (taowaSessionJsonPath root sessionId)
              let decodedSession = eitherDecode sessionBytes :: Either String TaowaSession
              assertEqual "taowa stopped session json roundtrip" (Right TaowaSessionStopped) (taowaSessionStatus <$> decodedSession)
              BL.writeFile (taowaSessionJsonPath root sessionId) (encode (stoppedSession { taowaSessionStatus = TaowaSessionRunning, taowaSessionDiagnostics = [] }))
              staleCount <- markStaleTaowaSessions root
              assertEqual "taowa stale sessions are marked after restart" 1 staleCount
              staleSessions <- listStoredTaowaSessions root
              let staleDiagnosticCodes =
                    case find ((== sessionId) . taowaSessionId) staleSessions of
                      Just staleSession -> map diagnosticCode (taowaSessionDiagnostics staleSession)
                      Nothing -> []
              assertEqual "taowa stale session gets diagnostic" ["taowa_session_stale_after_core_restart"] staleDiagnosticCodes
              clearResponse <-
                clearTaowaSessionHistory
                  root
                  registry
                  TaowaSessionHistoryClearRequest
                    { taowaClearSessionStatuses = Just [TaowaSessionFailed]
                    , taowaClearKeepActive = False
                    }
              assertEqual "taowa clear history deletes failed session history" (2, 0, 0) (taowaClearDeleted clearResponse, taowaClearKept clearResponse, taowaClearSkippedActive clearResponse)
              storedAfterClear <- listStoredTaowaSessions root
              assertEqual "taowa stored session history is cleared" [] storedAfterClear
            )
            `finally` ensureStopped
    )
    `finally` cleanup
