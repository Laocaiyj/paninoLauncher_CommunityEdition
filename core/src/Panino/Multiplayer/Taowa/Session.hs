{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Multiplayer.Taowa.Session
  ( TaowaRuntimeSession(..)
  , clearTaowaSessionHistory
  , listTaowaSessions
  , listTaowaSessionsIncludingStored
  , listStoredTaowaSessions
  , markStaleTaowaSessions
  , startTaowaSession
  , stopTaowaSession
  , taowaSessionDirectory
  , taowaSessionJsonPath
  , taowaSessionsDirectory
  , validTaowaPort
  ) where

import Control.Concurrent.STM
  ( TVar
  , atomically
  , modifyTVar'
  , newTVarIO
  , readTVarIO
  , writeTVar
  )
import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( eitherDecode
  , encode
  )
import qualified Data.ByteString.Lazy as BL
import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Data.Ord (Down(..))
import Data.Time.Clock
  ( UTCTime
  , getCurrentTime
  )
import Data.Time.Format
  ( defaultTimeLocale
  , formatTime
  )
import Panino.Diagnostics.Types (Diagnostic)
import Panino.Multiplayer.Taowa.ConfigStore (taowaRoot)
import Panino.Multiplayer.Taowa.Diagnostics
  ( classifyTaowaFrpcFailure
  , readTaowaLogTail
  , taowaDiagnosticForCode
  , taowaSessionNotFoundDiagnostic
  , writeTaowaSessionDiagnosticExport
  )
import Panino.Multiplayer.Taowa.FrpcConfig (renderFrpcConfig)
import Panino.Multiplayer.Taowa.FrpcProcess
  ( TaowaFrpcProcess
  , startFrpcProcess
  , stopFrpcProcess
  )
import Panino.Multiplayer.Taowa.Types
  ( TaowaFrpProfile(..)
  , TaowaSession(..)
  , TaowaSessionHistoryClearRequest(..)
  , TaowaSessionHistoryClearResponse(..)
  , TaowaSessionStartRequest(..)
  , TaowaSessionStatus(..)
  , publicProfile
  , taowaRemoteAddress
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , listDirectory
  , removeDirectoryRecursive
  )
import System.FilePath
  ( (</>)
  )
import System.Posix.Files
  ( ownerReadMode
  , ownerWriteMode
  , setFileMode
  , unionFileModes
  )

data TaowaRuntimeSession = TaowaRuntimeSession
  { taowaRuntimeSessionSnapshot :: TVar TaowaSession
  , taowaRuntimeSessionProcess :: TaowaFrpcProcess
  }

startTaowaSession
  :: FilePath
  -> TVar (Map Text TaowaRuntimeSession)
  -> TaowaFrpProfile
  -> TaowaSessionStartRequest
  -> IO (Either Diagnostic TaowaSession)
startTaowaSession appRoot registry profile request
  | not (taowaProfileEnabled profile) =
      pure (Left (taowaProfileDisabledDiagnostic profile request))
  | not (validTaowaPort (taowaStartLocalPort request)) =
      pure (Left (taowaInvalidLocalPortDiagnostic profile request))
  | otherwise = do
      startedAt <- getCurrentTime
      let sessionId = newSessionId startedAt profile request
          sessionDir = taowaSessionDirectory appRoot sessionId
          configPath = sessionDir </> "frpc.toml"
          logPath = sessionDir </> "frpc.log"
          startingSession =
            baseSession
              sessionId
              profile
              request
              configPath
              logPath
              TaowaSessionStartingFrpc
              startedAt
      createDirectoryIfMissing True sessionDir
      TextIO.writeFile configPath (renderFrpcConfig profile sessionId (taowaStartLocalPort request))
      setFileMode configPath (ownerReadMode `unionFileModes` ownerWriteMode)
      writeTaowaSessionJson appRoot startingSession
      started <- startFrpcProcess (taowaProfileFrpcPath profile) configPath logPath
      case started of
        Left err -> do
          failedAt <- getCurrentTime
          logTail <- readTaowaLogTail logPath
          let diagnostic =
                classifyTaowaFrpcFailure
                  err
                  logTail
                  (sessionDiagnosticContext profile request)
                  logPath
              failed =
                startingSession
                  { taowaSessionStatus = TaowaSessionFailed
                  , taowaSessionDiagnostics = [diagnostic]
                  , taowaSessionUpdatedAt = failedAt
                  }
          writeTaowaSessionJson appRoot failed
          writeTaowaSessionDiagnosticExport (Just (publicProfile profile)) failed
          pure (Left diagnostic)
        Right process -> do
          runningAt <- getCurrentTime
          snapshot <- newTVarIO startingSession
          let running =
                startingSession
                  { taowaSessionStatus = TaowaSessionRunning
                  , taowaSessionUpdatedAt = runningAt
                  }
              runtime =
                TaowaRuntimeSession
                  { taowaRuntimeSessionSnapshot = snapshot
                  , taowaRuntimeSessionProcess = process
                  }
          atomically $ do
            writeTVar snapshot running
            modifyTVar' registry (Map.insert sessionId runtime)
          writeTaowaSessionJson appRoot running
          writeTaowaSessionDiagnosticExport (Just (publicProfile profile)) running
          pure (Right running)

stopTaowaSession
  :: FilePath
  -> TVar (Map Text TaowaRuntimeSession)
  -> Text
  -> IO (Either Diagnostic TaowaSession)
stopTaowaSession appRoot registry sessionId = do
  maybeRuntime <- Map.lookup sessionId <$> readTVarIO registry
  case maybeRuntime of
    Nothing -> pure (Left (taowaSessionNotFoundDiagnostic sessionId))
    Just runtime -> do
      current <- readTVarIO (taowaRuntimeSessionSnapshot runtime)
      case taowaSessionStatus current of
        TaowaSessionStopped -> pure (Right current)
        _ -> do
          stopResult <- try (stopFrpcProcess (taowaRuntimeSessionProcess runtime))
          stoppedAt <- getCurrentTime
          stopDiagnostics <- stopResultDiagnostics current stopResult
          let stopped =
                current
                  { taowaSessionStatus =
                      case stopResult of
                        Right () -> TaowaSessionStopped
                        Left (_ :: SomeException) -> TaowaSessionFailed
                  , taowaSessionDiagnostics = stopDiagnostics
                  , taowaSessionUpdatedAt = stoppedAt
                  }
          atomically (writeTVar (taowaRuntimeSessionSnapshot runtime) stopped)
          writeTaowaSessionJson appRoot stopped
          writeTaowaSessionDiagnosticExport Nothing stopped
          pure (Right stopped)

listTaowaSessions :: TVar (Map Text TaowaRuntimeSession) -> IO [TaowaSession]
listTaowaSessions registry = do
  sessions <- Map.elems <$> readTVarIO registry
  traverse (readTVarIO . taowaRuntimeSessionSnapshot) sessions

listTaowaSessionsIncludingStored :: FilePath -> TVar (Map Text TaowaRuntimeSession) -> IO [TaowaSession]
listTaowaSessionsIncludingStored appRoot registry = do
  active <- listTaowaSessions registry
  stored <- listStoredTaowaSessions appRoot
  let activeMap = Map.fromList [(taowaSessionId session, session) | session <- active]
      storedMap = Map.fromList [(taowaSessionId session, session) | session <- stored]
  pure (newestFirst (Map.elems (activeMap `Map.union` storedMap)))

listStoredTaowaSessions :: FilePath -> IO [TaowaSession]
listStoredTaowaSessions appRoot = do
  let root = taowaSessionsDirectory appRoot
  exists <- doesDirectoryExist root
  if not exists
    then pure []
    else do
      entries <- listDirectory root
      sessions <- traverse (readStoredSession root) entries
      pure (newestFirst [session | Just session <- sessions])

markStaleTaowaSessions :: FilePath -> IO Int
markStaleTaowaSessions appRoot = do
  sessions <- listStoredTaowaSessions appRoot
  now <- getCurrentTime
  let staleSessions = filter staleAfterRestart sessions
  mapM_ (writeStaleSession now) staleSessions
  pure (length staleSessions)
  where
    writeStaleSession now session = do
      let diagnostic = staleAfterRestartDiagnostic session
          updated =
            session
              { taowaSessionStatus = TaowaSessionFailed
              , taowaSessionDiagnostics = taowaSessionDiagnostics session <> [diagnostic]
              , taowaSessionUpdatedAt = now
              }
      writeTaowaSessionJson appRoot updated
      writeTaowaSessionDiagnosticExport Nothing updated

clearTaowaSessionHistory
  :: FilePath
  -> TVar (Map Text TaowaRuntimeSession)
  -> TaowaSessionHistoryClearRequest
  -> IO TaowaSessionHistoryClearResponse
clearTaowaSessionHistory appRoot registry request = do
  stored <- listStoredTaowaSessions appRoot
  activeIds <- Map.keys <$> readTVarIO registry
  results <- traverse (clearOne activeIds) stored
  let deleted = length [() | ClearedDeleted <- results]
      kept = length [() | ClearedKept <- results]
      skippedActive = length [() | ClearedSkippedActive <- results]
  pure
    TaowaSessionHistoryClearResponse
      { taowaClearDeleted = deleted
      , taowaClearKept = kept
      , taowaClearSkippedActive = skippedActive
      }
  where
    statuses = maybe [TaowaSessionStopped, TaowaSessionFailed] id (taowaClearSessionStatuses request)
    keepActive = taowaClearKeepActive request
    clearOne activeIds session
      | taowaSessionStatus session `notElem` statuses =
          pure ClearedKept
      | keepActive && taowaSessionId session `elem` activeIds =
          pure ClearedSkippedActive
      | otherwise = do
          result <- try (removeDirectoryRecursive (taowaSessionDirectory appRoot (taowaSessionId session))) :: IO (Either SomeException ())
          case result of
            Right () -> pure ClearedDeleted
            Left _ -> pure ClearedKept

taowaSessionDirectory :: FilePath -> Text -> FilePath
taowaSessionDirectory appRoot sessionId =
  taowaSessionsDirectory appRoot </> Text.unpack sessionId

taowaSessionsDirectory :: FilePath -> FilePath
taowaSessionsDirectory appRoot =
  taowaRoot appRoot </> "sessions"

taowaSessionJsonPath :: FilePath -> Text -> FilePath
taowaSessionJsonPath appRoot sessionId =
  taowaSessionDirectory appRoot sessionId </> "session.json"

writeTaowaSessionJson :: FilePath -> TaowaSession -> IO ()
writeTaowaSessionJson appRoot session = do
  let path = taowaSessionJsonPath appRoot (taowaSessionId session)
  createDirectoryIfMissing True (taowaSessionDirectory appRoot (taowaSessionId session))
  BL.writeFile path (encode session)

readStoredSession :: FilePath -> FilePath -> IO (Maybe TaowaSession)
readStoredSession root entry = do
  let path = root </> entry </> "session.json"
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else do
      loaded <- try (BL.readFile path) :: IO (Either SomeException BL.ByteString)
      pure $ case loaded of
        Right bytes ->
          case eitherDecode bytes of
            Right session -> Just session
            Left _ -> Nothing
        Left _ -> Nothing

newestFirst :: [TaowaSession] -> [TaowaSession]
newestFirst =
  sortOn (Down . taowaSessionUpdatedAt)

staleAfterRestart :: TaowaSession -> Bool
staleAfterRestart session =
  taowaSessionStatus session `elem` [TaowaSessionPrepared, TaowaSessionStartingFrpc, TaowaSessionRunning]

staleAfterRestartDiagnostic :: TaowaSession -> Diagnostic
staleAfterRestartDiagnostic session =
  taowaDiagnosticForCode
    "taowa_session_stale_after_core_restart"
    "session"
    "Core restarted while this Taowa session was marked active; the old frpc process handle cannot be managed."
    [ ("sessionId", taowaSessionId session)
    , ("profileId", taowaSessionProfileId session)
    , ("localPort", Text.pack (show (taowaSessionLocalPort session)))
    , ("remoteAddress", taowaSessionRemoteAddress session)
    , ("frpcLogPath", Text.pack (taowaSessionFrpcLogPath session))
    ]
    (Just (taowaSessionFrpcLogPath session))

data ClearResult
  = ClearedDeleted
  | ClearedKept
  | ClearedSkippedActive
  deriving (Eq, Show)

baseSession
  :: Text
  -> TaowaFrpProfile
  -> TaowaSessionStartRequest
  -> FilePath
  -> FilePath
  -> TaowaSessionStatus
  -> UTCTime
  -> TaowaSession
baseSession sessionId profile request configPath logPath status now =
  TaowaSession
    { taowaSessionId = sessionId
    , taowaSessionProfileId = taowaProfileId profile
    , taowaSessionInstanceId = taowaStartInstanceId request
    , taowaSessionGameDir = taowaStartGameDir request
    , taowaSessionLocalPort = taowaStartLocalPort request
    , taowaSessionRemoteAddress = taowaRemoteAddress profile
    , taowaSessionRemotePort = taowaProfileRemotePort profile
    , taowaSessionFrpcConfigPath = configPath
    , taowaSessionFrpcLogPath = logPath
    , taowaSessionStatus = status
    , taowaSessionProcessId = Nothing
    , taowaSessionDiagnostics = []
    , taowaSessionStartedAt = now
    , taowaSessionUpdatedAt = now
    }

newSessionId :: UTCTime -> TaowaFrpProfile -> TaowaSessionStartRequest -> Text
newSessionId now profile request =
  Text.pack $
    formatTime defaultTimeLocale "taowa-%Y%m%d%H%M%S%q-" now
      <> Text.unpack (taowaProfileId profile)
      <> "-"
      <> show (taowaStartLocalPort request)

validTaowaPort :: Int -> Bool
validTaowaPort port =
  port >= 1 && port <= 65535

taowaProfileDisabledDiagnostic :: TaowaFrpProfile -> TaowaSessionStartRequest -> Diagnostic
taowaProfileDisabledDiagnostic profile request =
  taowaDiagnosticForCode
    "taowa_profile_disabled"
    "session"
    "Taowa FRP profile is disabled."
    (sessionDiagnosticContext profile request)
    Nothing

taowaInvalidLocalPortDiagnostic :: TaowaFrpProfile -> TaowaSessionStartRequest -> Diagnostic
taowaInvalidLocalPortDiagnostic profile request =
  taowaDiagnosticForCode
    "taowa_invalid_local_port"
    "lan"
    "localPort must be 1-65535."
    (sessionDiagnosticContext profile request)
    (Just (taowaStartGameDir request))

stopResultDiagnostics :: TaowaSession -> Either SomeException () -> IO [Diagnostic]
stopResultDiagnostics current stopResult =
  case stopResult of
    Right () -> pure (taowaSessionDiagnostics current)
    Left err -> do
      logTail <- readTaowaLogTail (taowaSessionFrpcLogPath current)
      pure
        [ taowaDiagnosticForCode
            "taowa_session_stop_failed"
            "frpc"
            (Text.pack (show err) <> "\n" <> logTail)
            [ ("sessionId", taowaSessionId current)
            , ("profileId", taowaSessionProfileId current)
            , ("localPort", Text.pack (show (taowaSessionLocalPort current)))
            , ("remoteAddress", taowaSessionRemoteAddress current)
            , ("frpcLogTail", logTail)
            , ("frpcLogPath", Text.pack (taowaSessionFrpcLogPath current))
            ]
            (Just (taowaSessionFrpcLogPath current))
        ]

sessionDiagnosticContext :: TaowaFrpProfile -> TaowaSessionStartRequest -> [(Text, Text)]
sessionDiagnosticContext profile request =
  [ ("profileId", taowaProfileId profile)
  , ("instanceId", maybe "" id (taowaStartInstanceId request))
  , ("gameDir", Text.pack (taowaStartGameDir request))
  , ("serverAddr", taowaProfileServerAddr profile)
  , ("serverPort", Text.pack (show (taowaProfileServerPort profile)))
  , ("remotePort", Text.pack (show (taowaProfileRemotePort profile)))
  , ("localPort", Text.pack (show (taowaStartLocalPort request)))
  , ("frpcPath", Text.pack (taowaProfileFrpcPath profile))
  ]
