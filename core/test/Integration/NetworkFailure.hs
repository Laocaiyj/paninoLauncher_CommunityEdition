{-# LANGUAGE OverloadedStrings #-}

module Integration.NetworkFailure
  ( assertNetworkFailureFixtures
  ) where

import Control.Concurrent (threadDelay)
import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson (Value)
import qualified Data.ByteString.Char8 as BS8
import Network.HTTP.Types
  ( hContentType
  , status200
  , status404
  , status500
  )
import Network.Wai
  ( Request
  , Response
  , ResponseReceived
  , rawPathInfo
  , responseLBS
  )
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.Net.Http
  ( applyRequestTimeoutMicros
  , coreRequest
  , fetchJson
  , makeHttpManager
  )
import TestSupport (assertEqual)

assertNetworkFailureFixtures :: IO ()
assertNetworkFailureFixtures = do
  manager <- makeHttpManager
  testWithApplication (pure fakeNetworkFailureApp) $ \port -> do
    let base = "http://127.0.0.1:" <> show port
        fetchFailure label path timeoutMicros = do
          request <- coreRequest (base <> path) []
          let tuned = applyRequestTimeoutMicros timeoutMicros request
          result <- try (fetchJson manager tuned :: IO Value) :: IO (Either SomeException Value)
          case result of
            Left _ -> pure ()
            Right _ -> assertEqual label True False
    fetchFailure "network fixture timeout fails" "/timeout" 1000
    fetchFailure "network fixture 404 fails" "/missing" 1000000
    fetchFailure "network fixture 500 fails" "/server-error" 1000000
    fetchFailure "network fixture invalid JSON fails" "/invalid-json" 1000000

fakeNetworkFailureApp :: Request -> (Response -> IO ResponseReceived) -> IO ResponseReceived
fakeNetworkFailureApp request respond =
  case BS8.unpack (rawPathInfo request) of
    "/timeout" -> do
      threadDelay 100000
      respond (responseLBS status200 [(hContentType, "application/json")] "{}")
    "/missing" ->
      respond (responseLBS status404 [(hContentType, "text/plain")] "missing")
    "/server-error" ->
      respond (responseLBS status500 [(hContentType, "text/plain")] "server error")
    "/invalid-json" ->
      respond (responseLBS status200 [(hContentType, "application/json")] "{invalid")
    _ ->
      respond (responseLBS status404 [(hContentType, "text/plain")] "missing")
