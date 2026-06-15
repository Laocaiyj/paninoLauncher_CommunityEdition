{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Download.VerificationIndex
  ( flushVerificationIndex
  , lookupVerifiedFile
  , recordVerifiedFile
  ) where

import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , newMVar
  )
import Control.Exception
  ( SomeException
  , catch
  , throwIO
  , try
  )
import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , decode
  , encode
  , object
  , withObject
  , (.:)
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (UTCTime)
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , getFileSize
  , getHomeDirectory
  , getModificationTime
  , removeFile
  , renameFile
  )
import System.Environment (lookupEnv)
import System.FilePath
  ( takeDirectory
  , (</>)
  )
import System.IO
  ( hClose
  , openTempFile
  )
import System.IO.Unsafe (unsafePerformIO)

data VerificationRecord = VerificationRecord
  { recordSize :: Integer
  , recordModifiedAt :: UTCTime
  , recordSha1 :: Text
  } deriving (Eq, Show)

instance ToJSON VerificationRecord where
  toJSON record =
    object
      [ "size" .= recordSize record
      , "modifiedAt" .= recordModifiedAt record
      , "sha1" .= recordSha1 record
      ]

instance FromJSON VerificationRecord where
  parseJSON =
    withObject "VerificationRecord" $ \obj ->
      VerificationRecord
        <$> obj .: "size"
        <*> obj .: "modifiedAt"
        <*> obj .: "sha1"

data VerificationIndexState = VerificationIndexState
  { indexStatePath :: Maybe FilePath
  , indexStateRecords :: Map Text VerificationRecord
  , indexStateDirty :: Bool
  }

{-# NOINLINE verificationIndexLock #-}
-- Process-local verification index lock. Keep the unsafePerformIO boundary
-- isolated here until the download verifier receives an explicit state handle.
verificationIndexLock :: MVar VerificationIndexState
verificationIndexLock =
  unsafePerformIO (newMVar (VerificationIndexState Nothing Map.empty False))

lookupVerifiedFile :: FilePath -> Maybe Text -> IO Bool
lookupVerifiedFile _ Nothing =
  pure False
lookupVerifiedFile path (Just expectedSha1) = do
  indexFallback "lookup" False $ do
    exists <- doesFileExist path
    if not exists
      then pure False
      else do
        records <- withLoadedRecords
        size <- getFileSize path
        modifiedAt <- getModificationTime path
        pure $
          case Map.lookup (Text.pack path) records of
            Just record ->
              recordSize record == size
                && recordModifiedAt record == modifiedAt
                && recordSha1 record == Text.toLower expectedSha1
            Nothing -> False

recordVerifiedFile :: FilePath -> Maybe Text -> IO ()
recordVerifiedFile _ Nothing =
  pure ()
recordVerifiedFile path (Just sha1) = do
  indexFallback "write" () $ do
    exists <- doesFileExist path
    if not exists
      then pure ()
      else do
        size <- getFileSize path
        modifiedAt <- getModificationTime path
        modifyIndexState $ \state -> do
          let records =
                Map.insert
                  (Text.pack path)
                  VerificationRecord
                    { recordSize = size
                    , recordModifiedAt = modifiedAt
                    , recordSha1 = Text.toLower sha1
                    }
                  (indexStateRecords state)
          pure (state { indexStateRecords = records, indexStateDirty = True }, ())

flushVerificationIndex :: IO ()
flushVerificationIndex =
  indexFallback "flush" () $
    modifyMVar verificationIndexLock $ \state -> do
      loaded <- ensureLoadedState state
      if not (indexStateDirty loaded)
        then pure (loaded, ())
        else do
          case indexStatePath loaded of
            Nothing ->
              pure (loaded, ())
            Just path -> do
              result <- try (writeIndexAt path (indexStateRecords loaded))
              case result of
                Right () ->
                  pure (loaded { indexStateDirty = False }, ())
                Left (err :: SomeException) -> do
                  putStrLn ("verification_index_flush_ignored: " <> show err)
                  pure (loaded, ())

withLoadedRecords :: IO (Map Text VerificationRecord)
withLoadedRecords =
  modifyIndexState $ \state ->
    pure (state, indexStateRecords state)

modifyIndexState :: (VerificationIndexState -> IO (VerificationIndexState, a)) -> IO a
modifyIndexState action =
  modifyMVar verificationIndexLock $ \state -> do
    loaded <- ensureLoadedState state
    action loaded

ensureLoadedState :: VerificationIndexState -> IO VerificationIndexState
ensureLoadedState state = do
  path <- indexPath
  if indexStatePath state == Just path
    then pure state
    else do
      records <- readIndexAt path
      pure VerificationIndexState
        { indexStatePath = Just path
        , indexStateRecords = records
        , indexStateDirty = False
        }

readIndexAt :: FilePath -> IO (Map Text VerificationRecord)
readIndexAt path = do
  bytes <- (Just <$> BL.readFile path) `catch` \(_ :: SomeException) -> pure Nothing
  pure (maybe Map.empty (maybe Map.empty id . decode) bytes)

writeIndexAt :: FilePath -> Map Text VerificationRecord -> IO ()
writeIndexAt path records = do
  let directory = takeDirectory path
  createDirectoryIfMissing True directory
  (tempPath, handle) <- openTempFile directory "verification-index.tmp"
  result <- try $ do
    BL.hPut handle (encode records)
    hClose handle
    renameFile tempPath path
  case result of
    Right () -> pure ()
    Left (err :: SomeException) -> do
      hClose handle `catch` \(_ :: SomeException) -> pure ()
      removeFile tempPath `catch` \(_ :: SomeException) -> pure ()
      throwIO err

indexFallback :: String -> a -> IO a -> IO a
indexFallback operation fallback action =
  action `catch` \(err :: SomeException) -> do
    putStrLn ("verification_index_" <> operation <> "_ignored: " <> show err)
    pure fallback

indexPath :: IO FilePath
indexPath = do
  configured <- lookupEnv "PANINO_VERIFICATION_INDEX"
  case configured of
    Just path | not (null path) -> pure path
    _ -> do
      home <- getHomeDirectory
      pure (home </> "Library" </> "Application Support" </> "Panino Launcher" </> "cache" </> "verification-index.json")
