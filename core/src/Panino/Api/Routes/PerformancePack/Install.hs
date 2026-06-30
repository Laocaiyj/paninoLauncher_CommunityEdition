{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.PerformancePack.Install
  ( runPerformancePackInstallTask
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( encode
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (getCurrentTime)
import Panino.Api.Routes.PerformancePack.Types
  ( PerformancePackInstallRequest(..)
  , PerformancePackPlan(..)
  , ResolvedPerformanceDownload(..)
  , ResolvedPerformancePackPlan(..)
  , packInstallGameDirPath
  )
import Panino.Api.Routes.Tasks (taskIsCancelled)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( DownloadRuntimeOptions(..)
  , TaskSnapshot
  )
import Panino.Download.Manager
  ( DownloadJob(..)
  , DownloadOptions
  , DownloadSummary(..)
  , downloadOptionsWithOverrides
  , runDownloadJobsWithOptionsAndProgressAndCancel
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , removeFile
  )
import System.FilePath
  ( takeDirectory
  , (</>)
  )

runPerformancePackInstallTask :: ServerState -> TaskSnapshot -> PerformancePackInstallRequest -> ResolvedPerformancePackPlan -> IO Text
runPerformancePackInstallTask state task request resolved = do
  let plan = resolvedPerformancePlan resolved
      jobs = map resolvedPerformanceDownloadJob (resolvedPerformanceDownloads resolved)
  createDirectoryIfMissing True (packInstallGameDirPath request </> "mods")
  before <- traverse targetExisted jobs
  result <-
    try $
      runDownloadJobsWithOptionsAndProgressAndCancel
        (stateHttpManager state)
        (downloadOptionsFromRuntime (packInstallDownload request))
        (taskIsCancelled state task)
        jobs
        (\_ -> pure ())
  case result of
    Right summary -> do
      writePerformancePackLockfile plan
      pure
        ( "installed performance pack with "
            <> Text.pack (show (length jobs))
            <> " planned files and "
            <> Text.pack (show (totalCount summary))
            <> " checked files. Rollback record: "
            <> Text.pack (packPlanLockfilePath plan)
        )
    Left (err :: SomeException) -> do
      rollbackNewFiles before
      fail ("performance pack install failed and new files were rolled back: " <> show err)

targetExisted :: DownloadJob -> IO (DownloadJob, Bool)
targetExisted job = do
  exists <- doesFileExist (jobTargetPath job)
  pure (job, exists)

rollbackNewFiles :: [(DownloadJob, Bool)] -> IO ()
rollbackNewFiles =
  mapM_ removeIfNew
  where
    removeIfNew (job, existedBefore) =
      if existedBefore
        then pure ()
        else do
          result <- try (removeFile (jobTargetPath job))
          case result of
            Right () -> pure ()
            Left (_ :: SomeException) -> pure ()

writePerformancePackLockfile :: PerformancePackPlan -> IO ()
writePerformancePackLockfile plan = do
  now <- getCurrentTime
  createDirectoryIfMissing True (takeDirectory (packPlanLockfilePath plan))
  BL.writeFile
    (packPlanLockfilePath plan)
    ( encode $
        object
          [ "installedAt" .= now
          , "title" .= packPlanTitle plan
          , "files" .= packPlanFiles plan
          , "rollback" .= ("Remove the listed files or restore from backups if a future installer created them." :: Text)
          ]
    )

downloadOptionsFromRuntime :: DownloadRuntimeOptions -> DownloadOptions
downloadOptionsFromRuntime options =
  downloadOptionsWithOverrides (downloadRuntimeConcurrency options) (downloadRuntimeRetryCount options)
