{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.PerformancePack.Rollback
  ( performancePackRollbackResponse
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( eitherDecode
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
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
import Panino.Api.Routes.PerformancePack.Types
  ( PerformancePackLockfile(..)
  , PerformancePackPlanFile(..)
  , PerformancePackRollbackRequest(..)
  , PerformancePackRollbackResult(..)
  , packRollbackGameDirPath
  )
import System.Directory
  ( doesFileExist
  , removeFile
  )
import System.FilePath
  ( takeDirectory
  , (</>)
  )

performancePackRollbackResponse :: Request -> IO Response
performancePackRollbackResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right rollbackRequest -> do
      let lockfilePath = fromMaybe (packRollbackGameDirPath rollbackRequest </> "downloads" </> "performance-pack-lock.json") (packRollbackLockfilePath rollbackRequest)
      lockfileResult <- try (BL.readFile lockfilePath)
      case lockfileResult of
        Left (err :: SomeException) ->
          pure $
            jsonResponse
              status400
              (object ["error" .= ("performance_pack_lockfile_missing" :: Text), "message" .= show err])
        Right contents ->
          case eitherDecode contents of
            Left err ->
              pure $
                jsonResponse
                  status400
                  (object ["error" .= ("performance_pack_lockfile_invalid" :: Text), "message" .= err])
            Right lockfile -> do
              result <- rollbackPerformancePackFiles rollbackRequest lockfilePath lockfile
              pure (jsonResponse status200 result)

rollbackPerformancePackFiles :: PerformancePackRollbackRequest -> FilePath -> PerformancePackLockfile -> IO PerformancePackRollbackResult
rollbackPerformancePackFiles request lockfilePath lockfile = do
  outcomes <- traverse (rollbackPerformancePackFile request) (performancePackLockfileFiles lockfile)
  let removed = [path | RollbackRemoved path <- outcomes]
      missing = [path | RollbackMissing path <- outcomes]
      skipped = [reason | RollbackSkipped reason <- outcomes]
      rolledBack = not (null removed) && null skipped
  pure
    PerformancePackRollbackResult
      { packRollbackResultRolledBack = rolledBack
      , packRollbackResultRemoved = removed
      , packRollbackResultMissing = missing
      , packRollbackResultSkipped = skipped
      , packRollbackResultLockfilePath = lockfilePath
      }

data RollbackOutcome
  = RollbackRemoved FilePath
  | RollbackMissing FilePath
  | RollbackSkipped Text
  deriving (Eq, Show)

rollbackPerformancePackFile :: PerformancePackRollbackRequest -> PerformancePackPlanFile -> IO RollbackOutcome
rollbackPerformancePackFile request file =
  if not (isSafePerformancePackTarget (packRollbackGameDirPath request) targetPath)
    then pure (RollbackSkipped ("Skipped non-mods path: " <> Text.pack targetPath))
    else do
      exists <- doesFileExist targetPath
      if not exists
        then pure (RollbackMissing targetPath)
        else do
          result <- try (removeFile targetPath)
          pure $ case result of
            Right () -> RollbackRemoved targetPath
            Left (err :: SomeException) -> RollbackSkipped ("Could not remove " <> Text.pack targetPath <> ": " <> Text.pack (show err))
  where
    targetPath = packPlanFileTargetPath file

isSafePerformancePackTarget :: FilePath -> FilePath -> Bool
isSafePerformancePackTarget gameDir targetPath =
  takeDirectory targetPath == gameDir </> "mods"
