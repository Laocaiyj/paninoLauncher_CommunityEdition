{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.LaunchTuning
  ( launchTuningApplyResponse
  , launchTuningResolveResponse
  , systemMemoryBytes
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( object
  , (.=)
  )
import Data.Int (Int64)
import Data.Text (Text)
import Network.HTTP.Types
  ( status200
  , status400
  )
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Params (decodeBody)
import Panino.Api.Response (jsonResponse)
import Panino.Launch.Tuning.Recommend (recommendJvmTuning)
import Panino.Launch.Tuning.Types
  ( JvmTuningApplyRequest(..)
  , JvmTuningApplyResponse(..)
  , JvmTuningRequest(..)
  )
import System.Exit (ExitCode(..))
import System.Process
  ( CreateProcess
  , proc
  , readCreateProcessWithExitCode
  )

launchTuningResolveResponse :: Request -> IO Response
launchTuningResolveResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right tuningRequest ->
      jsonResponse status200 . recommendJvmTuning <$> completeSystemMemory tuningRequest

launchTuningApplyResponse :: Request -> IO Response
launchTuningApplyResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right applyRequest -> do
      completed <- completeSystemMemory (applyTuningRequest applyRequest)
      let tuning = recommendJvmTuning completed
          response =
            JvmTuningApplyResponse
              { applyResponseScope = applyTuningScope applyRequest
              , applyResponseInstanceId = applyTuningInstanceId applyRequest
              , applyResponsePersistence = "client"
              , applyResponseTuning = tuning
              }
      pure (jsonResponse status200 response)

completeSystemMemory :: JvmTuningRequest -> IO JvmTuningRequest
completeSystemMemory request =
  case tuningRequestSystemMemoryBytes request of
    Just _ -> pure request
    Nothing -> do
      memory <- systemMemoryBytes
      pure request { tuningRequestSystemMemoryBytes = memory }

systemMemoryBytes :: IO (Maybe Int64)
systemMemoryBytes = do
  result <- tryReadProcess (proc "sysctl" ["-n", "hw.memsize"])
  pure (parseInt64 =<< result)

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

trim :: String -> String
trim =
  reverse . dropWhile (`elem` ['\n', '\r', ' ', '\t']) . reverse . dropWhile (`elem` ['\n', '\r', ' ', '\t'])
