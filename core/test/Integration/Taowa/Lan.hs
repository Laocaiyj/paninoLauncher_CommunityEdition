{-# LANGUAGE OverloadedStrings #-}

module Integration.Taowa.Lan
  ( testTaowaP1
  ) where

import Control.Concurrent
  ( forkIO
  , threadDelay
  )
import Control.Concurrent.MVar
  ( newEmptyMVar
  , putMVar
  , readMVar
  )
import Control.Exception (finally)
import Data.Aeson
  ( decode
  , encode
  )
import qualified Data.ByteString.Char8 as BS8
import qualified Data.Text as Text
import Network.HTTP.Types
  ( hContentType
  , status200
  )
import Network.Wai
  ( Request
  , Response
  , ResponseReceived
  , responseLBS
  )
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.Diagnostics.Types (Diagnostic(..))
import Panino.Multiplayer.Taowa.Diagnostics
  ( classifyTaowaFrpcFailure
  )
import Panino.Multiplayer.Taowa.LanDetect
  ( detectLanPortFromLog
  , taowaLatestLogPath
  , validateLocalPort
  , validateManualLanPort
  , watchLanPort
  )
import Panino.Multiplayer.Taowa.Types
  ( TaowaLanDetectRequest(..)
  , TaowaLanDetectStatus(..)
  , TaowaLanValidatePortRequest(..)
  , taowaLanDetectedPort
  , taowaLanDiagnostics
  , taowaLanEvidence
  , taowaLanEvidencePort
  , taowaLanStatus
  )
import System.Directory
  ( createDirectoryIfMissing
  , removeDirectoryRecursive
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  )
import TestSupport
  ( assertEqual
  , catchAny
  , waitForMVar
  )

testTaowaP1 :: FilePath -> IO ()
testTaowaP1 tempRoot = do
  let parserEvidence =
        detectLanPortFromLog $
          BS8.unlines
            [ "[Server thread/INFO]: Started serving on 34567"
            , "[Server thread/INFO]: Started LAN server on port 34568"
            , "[Server thread/INFO]: Local game hosted on port 34569"
            , "[Server thread/INFO]: Started serving on 0"
            , "[Server thread/INFO]: Started LAN server on port 70000"
            ]
  assertEqual "taowa LAN parser supports known log patterns" [Just 34567, Just 34568, Just 34569] (map taowaLanEvidencePort parserEvidence)
  assertEqual "taowa LAN parser ignores invalid ports" [] (detectLanPortFromLog "Started serving on 70000")
  assertEqual "taowa LAN parser JSON roundtrip" (Just parserEvidence) (decode (encode parserEvidence))

  testWithApplication (pure okApplication) $ \port -> do
    reachable <- validateLocalPort port
    assertEqual "taowa LAN local reachable port validates" True reachable
    invalid <- validateLocalPort 0
    assertEqual "taowa LAN invalid port fails validation" False invalid
    manualDetection <-
      validateManualLanPort
        TaowaLanValidatePortRequest
          { taowaValidateInstanceId = Just "manual-instance"
          , taowaValidateGameDir = Just (tempRoot </> "panino-taowa-p1-manual")
          , taowaValidateLocalPort = port
          }
    assertEqual "taowa manual port validation detects reachable port" TaowaLanDetected (taowaLanStatus manualDetection)
    assertEqual "taowa manual port validation returns port" (Just port) (taowaLanDetectedPort manualDetection)

    let root = tempRoot </> "panino-taowa-p1-watch"
        gameDir = root </> "game"
        logPath = taowaLatestLogPath gameDir
        cleanup = removeDirectoryRecursive root `catchAny` \_ -> pure ()
    cleanup
    (do
        createDirectoryIfMissing True (takeDirectory logPath)
        writeFile logPath ""
        result <- newEmptyMVar
        _ <-
          forkIO $
            watchLanPort
              TaowaLanDetectRequest
                { taowaLanDetectInstanceId = Just "watch-instance"
                , taowaLanDetectGameDir = gameDir
                , taowaLanDetectTimeoutSeconds = Just 2
                }
              >>= putMVar result
        threadDelay 600000
        appendFile logPath ("[Server thread/INFO]: Started serving on " <> show port <> "\n")
        detected <- waitForMVar result 150
        assertEqual "taowa LAN watcher returns after log append" True detected
        detection <- readMVar result
        assertEqual "taowa LAN watcher status" TaowaLanDetected (taowaLanStatus detection)
        assertEqual "taowa LAN watcher detected port" (Just port) (taowaLanDetectedPort detection)
        assertEqual "taowa LAN watcher includes evidence" True (not (null (taowaLanEvidence detection)))
      )
      `finally` cleanup

  let timeoutRoot = tempRoot </> "panino-taowa-p1-timeout"
      timeoutGameDir = timeoutRoot </> "game"
  removeDirectoryRecursive timeoutRoot `catchAny` \_ -> pure ()
  timeoutDetection <-
    watchLanPort
      TaowaLanDetectRequest
        { taowaLanDetectInstanceId = Nothing
        , taowaLanDetectGameDir = timeoutGameDir
        , taowaLanDetectTimeoutSeconds = Just 1
        }
  assertEqual "taowa LAN watcher timeout enters manual fallback" TaowaLanManualRequired (taowaLanStatus timeoutDetection)
  assertEqual "taowa LAN watcher timeout does not invent port" Nothing (taowaLanDetectedPort timeoutDetection)
  assertEqual "taowa LAN watcher timeout includes evidence" True (not (null (taowaLanEvidence timeoutDetection)))
  assertEqual "taowa LAN watcher timeout includes diagnostic" ["taowa_lan_port_not_detected"] (map diagnosticCode (taowaLanDiagnostics timeoutDetection))
  removeDirectoryRecursive timeoutRoot `catchAny` \_ -> pure ()

  invalidManualDetection <-
    validateManualLanPort
      TaowaLanValidatePortRequest
        { taowaValidateInstanceId = Just "invalid-manual"
        , taowaValidateGameDir = Just timeoutGameDir
        , taowaValidateLocalPort = 0
        }
  assertEqual "taowa manual invalid port includes diagnostic" ["taowa_invalid_local_port"] (map diagnosticCode (taowaLanDiagnostics invalidManualDetection))

  let tokenDiagnostic =
        classifyTaowaFrpcFailure
          "authorization failed"
          "token=secret-token\nlogin fail: invalid token"
          []
          (timeoutRoot </> "frpc.log")
      portDiagnostic =
        classifyTaowaFrpcFailure
          "start proxy error"
          "remote port already used"
          []
          (timeoutRoot </> "frpc.log")
  assertEqual "taowa frpc token failure classified" "taowa_frp_token_rejected" (diagnosticCode tokenDiagnostic)
  assertEqual "taowa frpc remote port failure classified" "taowa_frp_remote_port_conflict" (diagnosticCode portDiagnostic)
  assertEqual "taowa frpc diagnostic redacts token detail" False (maybe False ("secret-token" `Text.isInfixOf`) (diagnosticDeveloperDetail tokenDiagnostic))

okApplication :: Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived
okApplication _ respond =
  respond (responseLBS status200 [(hContentType, "text/plain")] "ok")
