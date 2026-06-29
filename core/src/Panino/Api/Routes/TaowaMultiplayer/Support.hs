{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.TaowaMultiplayer.Support
  ( activeSessionForProfile
  , errorObject
  , errorObjectWithDetection
  , forceProfileId
  , installedCandidate
  , invalidJsonResponse
  , notFoundResponse
  , taowaDiagnosticErrorResponse
  , taowaJson
  , taskCandidate
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( Value
  , object
  , (.=)
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Types
  ( Status
  , status400
  , status404
  )
import Network.Wai (Response)
import Panino.Api.MinecraftStatus (MinecraftInstalledInstance(..))
import Panino.Api.Response (jsonResponse)
import Panino.Api.Server.State
  ( ServerState(..)
  , stateDefaultGameDirPath
  )
import Panino.Api.Types (TaskSnapshot(..))
import Panino.Diagnostics.Types (Diagnostic(..))
import Panino.Minecraft.Layout
  ( minecraftRoot
  , mkLayout
  )
import Panino.Multiplayer.Taowa.Types
  ( TaowaFrpProfileRequest(..)
  , TaowaLanPortDetection(..)
  , TaowaSession(..)
  , TaowaSessionStatus(..)
  )
import System.FilePath (takeDirectory)

activeSessionForProfile :: Text -> TaowaSession -> Bool
activeSessionForProfile profileId session =
  taowaSessionProfileId session == profileId
    && taowaSessionStatus session `elem` [TaowaSessionPrepared, TaowaSessionStartingFrpc, TaowaSessionRunning]

taowaJson :: ServerState -> (FilePath -> IO Response) -> IO Response
taowaJson state action = do
  appRoot <- appSupportRoot state
  result <- try (action appRoot)
  case result of
    Right response -> pure response
    Left (err :: SomeException) ->
      pure (jsonResponse status400 (errorObject "taowa_operation_failed" (Text.pack (show err))))

appSupportRoot :: ServerState -> IO FilePath
appSupportRoot state = do
  layout <- mkLayout (stateDefaultGameDirPath state)
  pure (takeDirectory (minecraftRoot layout))

invalidJsonResponse :: String -> Response
invalidJsonResponse err =
  jsonResponse status400 (errorObject "invalid_json" (Text.pack err))

notFoundResponse :: Text -> Text -> Response
notFoundResponse code message =
  jsonResponse status404 (errorObject code message)

errorObject :: Text -> Text -> Value
errorObject code message =
  object
    [ "error" .= code
    , "message" .= message
    ]

errorObjectWithDetection :: Text -> Text -> TaowaLanPortDetection -> Value
errorObjectWithDetection code message detection =
  object $
    [ "error" .= code
    , "message" .= message
    , "detection" .= detection
    ]
      <> case taowaLanDiagnostics detection of
        diagnostic:_ ->
          [ "diagnostic" .= diagnostic
          , "diagnostics" .= taowaLanDiagnostics detection
          ]
        [] -> []

forceProfileId :: Text -> TaowaFrpProfileRequest -> TaowaFrpProfileRequest
forceProfileId profileId request =
  request { taowaRequestProfileId = Just profileId }

taskCandidate :: TaskSnapshot -> Value
taskCandidate task =
  object
    [ "taskId" .= taskSnapshotId task
    , "gameDir" .= taskSnapshotGameDir task
    , "version" .= taskSnapshotVersion task
    , "state" .= taskSnapshotState task
    , "updatedAt" .= taskSnapshotUpdatedAt task
    ]

installedCandidate :: MinecraftInstalledInstance -> Value
installedCandidate instanceValue =
  object
    [ "versionId" .= installedInstanceVersionId instanceValue
    , "name" .= installedInstanceName instanceValue
    , "gameDir" .= installedInstanceGameDir instanceValue
    ]

taowaDiagnosticErrorResponse :: Status -> Diagnostic -> Response
taowaDiagnosticErrorResponse status diagnostic =
  jsonResponse status $
    object
      [ "error" .= diagnosticCode diagnostic
      , "message" .= diagnosticMessage diagnostic
      , "diagnostic" .= diagnostic
      , "diagnostics" .= [diagnostic]
      ]
