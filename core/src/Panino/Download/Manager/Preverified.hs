{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Download.Manager.Preverified
  ( partitionPreverifiedJobs
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Control.Monad (foldM)
import Panino.Download.Types
  ( DownloadJob(..)
  )
import Panino.Download.VerificationIndex
  ( lookupVerifiedFile
  )
import System.Directory
  ( doesFileExist
  , getFileSize
  )

partitionPreverifiedJobs :: [DownloadJob] -> IO ([DownloadJob], [DownloadJob])
partitionPreverifiedJobs jobs = do
  (verified, pending) <- foldM step ([], []) jobs
  pure (reverse verified, reverse pending)
  where
    step (verified, pending) job = do
      valid <- fastPreverifiedFileIsValid job
      if valid
        then pure (job : verified, pending)
        else pure (verified, job : pending)

fastPreverifiedFileIsValid :: DownloadJob -> IO Bool
fastPreverifiedFileIsValid job = do
  result <- try $ do
    exists <- doesFileExist (jobTargetPath job)
    if not exists
      then pure False
      else do
        sizeOk <-
          case jobSize job of
            Nothing -> pure True
            Just expected -> (== expected) . fromIntegral <$> getFileSize (jobTargetPath job)
        if not sizeOk
          then pure False
          else
            case jobSha1 job of
              Nothing -> pure True
              Just expected -> lookupVerifiedFile (jobTargetPath job) (Just expected)
  case result of
    Right valid -> pure valid
    Left (_ :: SomeException) -> pure False
