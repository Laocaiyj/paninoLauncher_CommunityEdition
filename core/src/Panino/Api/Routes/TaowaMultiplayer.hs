{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.TaowaMultiplayer
  ( taowaFrpProfileCreateResponse
  , taowaFrpProfileDeleteResponse
  , taowaFrpProfileTestResponse
  , taowaFrpProfileUpdateResponse
  , taowaFrpProfilesResponse
  , testTaowaFrpProfile
  , taowaLanDetectResponse
  , taowaLanValidatePortResponse
  , taowaRecommendationsResponse
  , taowaSessionHealthResponse
  , taowaSessionHistoryClearResponse
  , taowaSessionResponse
  , taowaSessionStartResponse
  , taowaSessionLogResponse
  , taowaSessionStopResponse
  , taowaSessionsResponse
  ) where

import Control.Concurrent.STM
  ( readTVarIO
  )
import Control.Applicative ((<|>))
import Data.Aeson
  ( object
  , (.=)
  )
import Data.List
  ( find
  , sortOn
  )
import qualified Data.Map.Strict as Map
import Data.Ord (Down(..))
import Data.Text (Text)
import Data.Time.Clock (getCurrentTime)
import Network.HTTP.Types
  ( status200
  , status400
  , status404
  )
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Params (decodeBody)
import Panino.Api.MinecraftStatus
  ( MinecraftInstalledInstance(..)
  , MinecraftInstallStatusRequest(..)
  , fetchInstalledMinecraftInstances
  )
import Panino.Api.Response (jsonResponse)
import Panino.Api.Routes.TaowaMultiplayer.ProfileTest (testTaowaFrpProfile)
import Panino.Api.Routes.TaowaMultiplayer.Support
  ( activeSessionForProfile
  , errorObjectWithDetection
  , forceProfileId
  , installedCandidate
  , invalidJsonResponse
  , notFoundResponse
  , taowaDiagnosticErrorResponse
  , taowaJson
  , taskCandidate
  )
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( ApiEvent(..)
  , TaskKind(..)
  , TaskSnapshot(..)
  )
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  )
import Panino.Events.Bus (publishEvent)
import Panino.Multiplayer.Taowa.ConfigStore
  ( buildTaowaFrpProfile
  , deleteTaowaFrpProfile
  , findTaowaFrpProfile
  , readTaowaFrpProfiles
  , upsertTaowaFrpProfile
  )
import Panino.Multiplayer.Taowa.Diagnostics
  ( readRedactedTaowaLogTail
  , taowaDiagnosticForCode
  , taowaSessionNotFoundDiagnostic
  )
import Panino.Multiplayer.Taowa.LanDetect
  ( validateLocalPort
  , validateManualLanPort
  , watchLanPort
  )
import Panino.Multiplayer.Taowa.Session
  ( clearTaowaSessionHistory
  , listTaowaSessions
  , listTaowaSessionsIncludingStored
  , startTaowaSession
  , stopTaowaSession
  )
import Panino.Multiplayer.Taowa.Types
  ( TaowaLanDetectRequest
  , TaowaLanDetectStatus(..)
  , TaowaLanPortDetection(..)
  , TaowaLanValidatePortRequest
  , TaowaProfilesResponse(..)
  , TaowaSession(..)
  , TaowaSessionHistoryClearRequest
  , TaowaSessionStartRequest(..)
  , TaowaSessionStatus(..)
  , TaowaSessionsResponse(..)
  , publicProfile
  )

taowaFrpProfilesResponse :: ServerState -> IO Response
taowaFrpProfilesResponse state =
  taowaJson state $ \appRoot -> do
    profiles <- readTaowaFrpProfiles appRoot
    pure (jsonResponse status200 TaowaProfilesResponse { taowaProfiles = map publicProfile profiles })

taowaFrpProfileCreateResponse :: ServerState -> Request -> IO Response
taowaFrpProfileCreateResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right profileRequest ->
      taowaJson state $ \appRoot -> do
        profile <- buildTaowaFrpProfile Nothing profileRequest
        saved <- upsertTaowaFrpProfile appRoot profile
        pure (jsonResponse status200 (publicProfile saved))

taowaFrpProfileUpdateResponse :: ServerState -> [Text] -> Request -> IO Response
taowaFrpProfileUpdateResponse state [profileId] request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right profileRequest ->
      taowaJson state $ \appRoot -> do
        existing <- findTaowaFrpProfile appRoot profileId
        case existing of
          Nothing -> pure (notFoundResponse "taowa_profile_not_found" "FRP profile was not found.")
          Just oldProfile -> do
            profile <- buildTaowaFrpProfile (Just oldProfile) (forceProfileId profileId profileRequest)
            saved <- upsertTaowaFrpProfile appRoot profile
            pure (jsonResponse status200 (publicProfile saved))
taowaFrpProfileUpdateResponse _ _ _ =
  pure (notFoundResponse "not_found" "FRP profile was not found.")

taowaFrpProfileDeleteResponse :: ServerState -> [Text] -> IO Response
taowaFrpProfileDeleteResponse state [profileId] =
  taowaJson state $ \appRoot -> do
    activeSessions <- listTaowaSessions (stateTaowaSessions state)
    if any (activeSessionForProfile profileId) activeSessions
      then
        pure $
          taowaDiagnosticErrorResponse status400 $
            taowaDiagnosticForCode
              "taowa_profile_in_use"
              "profile"
              "Stop the running Taowa tunnel before deleting this FRP profile."
              [("profileId", profileId)]
              Nothing
      else do
        deleted <- deleteTaowaFrpProfile appRoot profileId
        pure $
          jsonResponse status200 $
            object
              [ "profileId" .= profileId
              , "deleted" .= deleted
              ]
taowaFrpProfileDeleteResponse _ _ =
  pure (notFoundResponse "not_found" "FRP profile was not found.")

taowaFrpProfileTestResponse :: ServerState -> [Text] -> IO Response
taowaFrpProfileTestResponse state [profileId, "test"] =
  taowaJson state $ \appRoot -> do
    profile <- findTaowaFrpProfile appRoot profileId
    case profile of
      Nothing ->
        pure $
          taowaDiagnosticErrorResponse status404 $
            taowaDiagnosticForCode
              "taowa_profile_invalid"
              "profile"
              "FRP profile was not found."
              [("profileId", profileId)]
              Nothing
      Just found -> do
        testResult <- testTaowaFrpProfile found
        pure (jsonResponse status200 testResult)
taowaFrpProfileTestResponse _ _ =
  pure (notFoundResponse "not_found" "FRP profile was not found.")

taowaLanDetectResponse :: Request -> IO Response
taowaLanDetectResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right (detectRequest :: TaowaLanDetectRequest) -> do
      detection <- watchLanPort detectRequest
      pure (jsonResponse status200 detection)

taowaLanValidatePortResponse :: Request -> IO Response
taowaLanValidatePortResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right (validateRequest :: TaowaLanValidatePortRequest) -> do
      detection <- validateManualLanPort validateRequest
      if taowaLanStatus detection == TaowaLanDetected
        then pure (jsonResponse status200 detection)
        else
          pure $
            jsonResponse status400 $
              errorObjectWithDetection
                "taowa_local_port_unreachable"
                "The selected LAN port is not reachable on 127.0.0.1."
                detection

taowaRecommendationsResponse :: ServerState -> IO Response
taowaRecommendationsResponse state =
  taowaJson state $ \_appRoot -> do
    taskMap <- readTVarIO (stateTasks state)
    installed <-
      fetchInstalledMinecraftInstances
        (stateDefaultGameDir state)
        MinecraftInstallStatusRequest
          { installStatusVersionIds = []
          , installStatusGameDirs = []
          }
    let recentLaunches =
          take 5 $
            sortOn (Down . taskSnapshotUpdatedAt) $
              [ task
              | task <- Map.elems taskMap
              , taskSnapshotKind task == TaskKindLaunch
              , Just gameDir <- [taskSnapshotGameDir task]
              , not (null gameDir)
              ]
        installedCandidates = take 5 installed
        recommendedFromTask = case recentLaunches of
          task:_ -> taskSnapshotGameDir task
          [] -> Nothing
        recommendedFromInstalled = case installedCandidates of
          instanceValue:_ -> Just (installedInstanceGameDir instanceValue)
          [] -> Nothing
        recommendedGameDir = recommendedFromTask <|> recommendedFromInstalled
        source =
          case recommendedFromTask of
            Just _ -> "taskHistory" :: Text
            Nothing ->
              case recommendedFromInstalled of
                Just _ -> "installedInstances"
                Nothing -> "none"
    pure $
      jsonResponse status200 $
        object
          [ "recommendedGameDir" .= recommendedGameDir
          , "source" .= source
          , "recentLaunches" .= map taskCandidate recentLaunches
          , "installedInstances" .= map installedCandidate installedCandidates
          ]

taowaSessionHealthResponse :: ServerState -> [Text] -> IO Response
taowaSessionHealthResponse state [sessionId, "health"] =
  taowaJson state $ \appRoot -> do
    sessions <- listTaowaSessionsIncludingStored appRoot (stateTaowaSessions state)
    activeMap <- readTVarIO (stateTaowaSessions state)
    case find ((== sessionId) . taowaSessionId) sessions of
      Nothing ->
        pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic sessionId))
      Just session -> do
        reachable <- validateLocalPort (taowaSessionLocalPort session)
        let processManaged = Map.member sessionId activeMap
            stale =
              not processManaged
                && taowaSessionStatus session `elem` [TaowaSessionPrepared, TaowaSessionStartingFrpc, TaowaSessionRunning]
        pure $
          jsonResponse status200 $
            object
              [ "session" .= session
              , "localPortReachable" .= reachable
              , "processManaged" .= processManaged
              , "stale" .= stale
              ]
taowaSessionHealthResponse _ _ =
  pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic "unknown"))

taowaSessionHistoryClearResponse :: ServerState -> Request -> IO Response
taowaSessionHistoryClearResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right (clearRequest :: TaowaSessionHistoryClearRequest) ->
      taowaJson state $ \appRoot -> do
        response <- clearTaowaSessionHistory appRoot (stateTaowaSessions state) clearRequest
        pure (jsonResponse status200 response)

taowaSessionResponse :: ServerState -> [Text] -> IO Response
taowaSessionResponse state [sessionId] =
  taowaJson state $ \appRoot -> do
    sessions <- listTaowaSessionsIncludingStored appRoot (stateTaowaSessions state)
    case find ((== sessionId) . taowaSessionId) sessions of
      Nothing ->
        pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic sessionId))
      Just session ->
        pure (jsonResponse status200 session)
taowaSessionResponse _ _ =
  pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic "unknown"))

taowaSessionStartResponse :: ServerState -> Request -> IO Response
taowaSessionStartResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err -> pure (invalidJsonResponse err)
    Right startRequest ->
      taowaJson state $ \appRoot -> do
        profile <- findTaowaFrpProfile appRoot (taowaStartProfileId startRequest)
        case profile of
          Nothing -> pure (notFoundResponse "taowa_profile_not_found" "FRP profile was not found.")
          Just found -> do
            started <- startTaowaSession appRoot (stateTaowaSessions state) found startRequest
            case started of
              Left diagnostic -> do
                emitTaowaSessionFailureEvent state startRequest diagnostic
                pure (taowaDiagnosticErrorResponse status400 diagnostic)
              Right session -> do
                emitTaowaSessionEvent state "taowa.session.started" session "Taowa session started"
                pure (jsonResponse status200 session)

taowaSessionLogResponse :: ServerState -> [Text] -> IO Response
taowaSessionLogResponse state [sessionId, "log"] =
  taowaJson state $ \appRoot -> do
    sessions <- listTaowaSessionsIncludingStored appRoot (stateTaowaSessions state)
    case find ((== sessionId) . taowaSessionId) sessions of
      Nothing ->
        pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic sessionId))
      Just session -> do
        logTail <- readRedactedTaowaLogTail (taowaSessionFrpcLogPath session)
        pure $
          jsonResponse status200 $
            object
              [ "sessionId" .= sessionId
              , "logPath" .= taowaSessionFrpcLogPath session
              , "tail" .= logTail
              ]
taowaSessionLogResponse _ _ =
  pure (taowaDiagnosticErrorResponse status404 (taowaSessionNotFoundDiagnostic "unknown"))

taowaSessionStopResponse :: ServerState -> [Text] -> IO Response
taowaSessionStopResponse state [sessionId, "stop"] =
  taowaJson state $ \appRoot -> do
    stopped <- stopTaowaSession appRoot (stateTaowaSessions state) sessionId
    case stopped of
      Left diagnostic -> pure (taowaDiagnosticErrorResponse status404 diagnostic)
      Right session -> do
        emitTaowaSessionEvent
          state
          (if taowaSessionStatus session == TaowaSessionStopped then "taowa.session.stopped" else "taowa.session.failed")
          session
          (if taowaSessionStatus session == TaowaSessionStopped then "Taowa session stopped" else "Taowa session failed")
        pure (jsonResponse status200 session)
taowaSessionStopResponse _ _ =
  pure (notFoundResponse "not_found" "Taowa session was not found.")

taowaSessionsResponse :: ServerState -> IO Response
taowaSessionsResponse state =
  taowaJson state $ \appRoot -> do
    sessions <- listTaowaSessionsIncludingStored appRoot (stateTaowaSessions state)
    pure (jsonResponse status200 TaowaSessionsResponse { taowaSessions = sessions })

emitTaowaSessionEvent :: ServerState -> Text -> TaowaSession -> Text -> IO ()
emitTaowaSessionEvent state eventType session message = do
  now <- getCurrentTime
  publishEvent
    (stateEvents state)
    ApiEvent
      { apiEventType = eventType
      , apiEventTaskId = Nothing
      , apiEventVersion = Just (taowaSessionId session)
      , apiEventMessage = message
      , apiEventAt = now
      , apiEventPayload =
          object $
            [ "session" .= session
            ]
              <> case taowaSessionDiagnostics session of
                diagnostic:_ ->
                  [ "diagnostic" .= diagnostic
                  , "diagnostics" .= taowaSessionDiagnostics session
                  ]
                [] -> []
      }

emitTaowaSessionFailureEvent :: ServerState -> TaowaSessionStartRequest -> Diagnostic -> IO ()
emitTaowaSessionFailureEvent state request diagnostic = do
  now <- getCurrentTime
  publishEvent
    (stateEvents state)
    ApiEvent
      { apiEventType = "taowa.session.failed"
      , apiEventTaskId = Nothing
      , apiEventVersion = taowaStartInstanceId request
      , apiEventMessage = diagnosticMessage diagnostic
      , apiEventAt = now
      , apiEventPayload =
          object
            [ "profileId" .= taowaStartProfileId request
            , "instanceId" .= taowaStartInstanceId request
            , "gameDir" .= taowaStartGameDir request
            , "localPort" .= taowaStartLocalPort request
            , "diagnostic" .= diagnostic
            , "diagnostics" .= [diagnostic]
            ]
      }
