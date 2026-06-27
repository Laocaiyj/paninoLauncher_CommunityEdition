{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Apply
  ( downloadJobFromLockfileNode
  , rollbackLockfilePlanNode
  , runLockfilePlanNode
  ) where

import Control.Monad
  ( void
  , when
  )
import Data.Foldable
  ( traverse_
  )
import Data.Maybe
  ( listToMaybe
  )
import qualified Data.Text as Text
import Network.HTTP.Client
  ( Manager
  )
import Panino.Download.Manager
  ( DownloadJob(..)
  , downloadSingle
  )
import qualified Panino.Install.Plan.Types as Plan
import System.Directory
  ( doesFileExist
  , removeFile
  )

runLockfilePlanNode :: Manager -> Plan.InstallPlanNode -> IO ()
runLockfilePlanNode manager node
  | Plan.installNodeActionIsNoop (Plan.installNodeAction node) = pure ()
  | Plan.installNodeActionIsDownloadLike (Plan.installNodeAction node) =
      case downloadJobFromLockfileNode node of
        Nothing -> fail ("lockfile plan node is missing download data: " <> Text.unpack (Plan.installNodeId node))
        Just job -> void (downloadSingle manager job)
  | Plan.installNodeAction node == Plan.InstallNodeDelete =
      case Plan.installNodeTargetPath node of
        Nothing -> fail ("lockfile delete node is missing target path: " <> Text.unpack (Plan.installNodeId node))
        Just target -> removeFileIfExists target
  | otherwise =
      fail ("unsupported lockfile plan action: " <> Text.unpack (Plan.installNodeActionText (Plan.installNodeAction node)))

rollbackLockfilePlanNode :: Plan.InstallPlanNode -> IO ()
rollbackLockfilePlanNode node =
  case Plan.installRollbackAction rollback of
    Plan.InstallRollbackRemoveCreatedFile ->
      traverse_ removeFileIfExists (Plan.installRollbackTargetPath rollback)
    _ -> pure ()
  where
    rollback = Plan.installNodeRollback node

downloadJobFromLockfileNode :: Plan.InstallPlanNode -> Maybe DownloadJob
downloadJobFromLockfileNode node = do
  targetPath <- Plan.installNodeTargetPath node
  url <- listToMaybe (Plan.installNodeSourceUrls node)
  pure
    DownloadJob
      { jobLabel = Text.unpack (Plan.installNodeLabel node)
      , jobUrl = url
      , jobTargetPath = targetPath
      , jobSha1 = Plan.installNodeSha1 node
      , jobSize = Plan.installNodeSize node
      }

removeFileIfExists :: FilePath -> IO ()
removeFileIfExists path = do
  exists <- doesFileExist path
  when exists (removeFile path)
