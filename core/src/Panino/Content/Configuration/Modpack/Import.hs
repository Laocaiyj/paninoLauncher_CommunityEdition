{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Configuration.Modpack.Import
  ( modpackLockEntries
  , removePathIfExists
  , runModpackDownloads
  , writeModpackLockfile
  , writeModpackOverrides
  ) where

import Control.Monad
  ( forM
  , forM_
  , unless
  , when
  )
import Data.Aeson
  ( encode
  , object
  , (.=)
  )
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Configuration.Modpack.Plan (safeRelativePath)
import Panino.Content.Configuration.Types
import Panino.Core.Types
  ( sha1FromText
  , urlFromText
  )
import Panino.CoreLogic.Determinism (stableSortPackages)
import Panino.Download.Manager
  ( DownloadJob(..)
  , downloadOptionsWithOverrides
  , runDownloadJobsWithOptionsAndProgressAndCancel
  )
import qualified Panino.Install.Plan.Types as Plan
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , removeDirectoryRecursive
  , removeFile
  )
import System.Exit (ExitCode(..))
import System.FilePath
  ( normalise
  , takeDirectory
  , (</>)
  )
import System.IO
  ( IOMode(..)
  , withBinaryFile
  )
import System.Process
  ( CreateProcess(..)
  , StdStream(..)
  , createProcess
  , proc
  , waitForProcess
  )

runModpackDownloads :: Manager -> FilePath -> Plan.TypedInstallPlan -> IO ()
runModpackDownloads manager stagingPath plan = do
  jobs <- forM downloadNodes (modpackDownloadJob stagingPath)
  unless (null jobs) $
    runDownloadJobsWithOptionsAndProgressAndCancel
      manager
      (downloadOptionsWithOverrides (Just 4) (Just 0))
      (pure False)
      jobs
      (const (pure ()))
      >> pure ()
  where
    downloadNodes =
      filter ((== "download") . Plan.installNodeAction) (Plan.typedPlanNodes plan)

modpackDownloadJob :: FilePath -> Plan.InstallPlanNode -> IO DownloadJob
modpackDownloadJob stagingPath node =
  case (Plan.installNodeTargetPath node, listToMaybe (Plan.installNodeSourceUrls node)) of
    (Just relativePath, Just url)
      | safeRelativePath relativePath ->
          pure
            DownloadJob
              { jobLabel = Text.unpack (Plan.installNodeLabel node)
              , jobUrl = urlFromText url
              , jobTargetPath = stagingPath </> normalise relativePath
              , jobSha1 = Plan.installNodeSha1 node >>= sha1FromText
              , jobSize = Plan.installNodeSize node
              }
    _ ->
      fail ("modpack download node is incomplete: " <> Text.unpack (Plan.installNodeId node))

writeModpackOverrides :: FilePath -> FilePath -> Plan.TypedInstallPlan -> IO ()
writeModpackOverrides archive stagingPath plan =
  forM_ overrideNodes $ \node ->
    case Plan.installNodeTargetPath node of
      Just relativePath
        | safeRelativePath relativePath ->
            unzipEntryToFile
              archive
              (Text.unpack (Plan.installNodeLabel node))
              (stagingPath </> normalise relativePath)
      _ ->
        fail ("modpack override node has unsafe target path: " <> Text.unpack (Plan.installNodeId node))
  where
    overrideNodes =
      [ node
      | node <- Plan.typedPlanNodes plan
      , Plan.installNodeKind node == "overrideFile"
      , Plan.installNodeAction node `elem` ["write", "replace"]
      ]

unzipEntryToFile :: FilePath -> FilePath -> FilePath -> IO ()
unzipEntryToFile archive entry target = do
  createDirectoryIfMissing True (takeDirectory target)
  withBinaryFile target WriteMode $ \handle -> do
    (_, _, _, processHandle) <-
      createProcess
        (proc "/usr/bin/unzip" ["-p", archive, entry])
          { std_out = UseHandle handle
          }
    exitCode <- waitForProcess processHandle
    case exitCode of
      ExitSuccess -> pure ()
      ExitFailure _ -> fail ("could not extract " <> entry <> " from " <> archive)

writeModpackLockfile :: FilePath -> ModpackImportRequest -> ModpackPreflightResponse -> Plan.TypedInstallPlan -> [ModpackImportLockEntry] -> IO ()
writeModpackLockfile path request preflight plan entries = do
  createDirectoryIfMissing True (takeDirectory path)
  LBS.writeFile
    path
    ( encode
        ( object
            [ "planId" .= Plan.typedPlanId plan
            , "fingerprint" .= Plan.typedPlanFingerprint plan
            , "sourceType" .= modpackImportSourceType request
            , "sourcePath" .= modpackImportSourcePath request
            , "targetGameDir" .= modpackImportTargetGameDir request
            , "name" .= modpackPreflightName preflight
            , "minecraftVersion" .= modpackPreflightMinecraftVersion preflight
            , "loader" .= modpackPreflightLoader preflight
            , "loaderVersion" .= modpackPreflightLoaderVersion preflight
            , "files" .= entries
            ]
        )
    )

modpackLockEntries :: Plan.TypedInstallPlan -> [ModpackImportLockEntry]
modpackLockEntries plan =
  stableSortPackages modpackLockEntryKey
    [ ModpackImportLockEntry
        { modpackLockEntryPath = relativePath
        , modpackLockEntryKind = Plan.installNodeKind node
        , modpackLockEntrySha1 = Plan.installNodeSha1 node
        , modpackLockEntrySize = Plan.installNodeSize node
        , modpackLockEntrySource = listToMaybe (Plan.installNodeSourceUrls node)
        }
    | node <- Plan.typedPlanNodes plan
    , Plan.installNodeAction node `elem` ["download", "write", "replace"]
    , Plan.installNodeKind node `notElem` ["directory", "rollbackMarker"]
    , Just relativePath <- [Plan.installNodeTargetPath node]
    , safeRelativePath relativePath
    ]

modpackLockEntryKey :: ModpackImportLockEntry -> Text
modpackLockEntryKey entry =
  Text.intercalate
    "|"
    [ Text.pack (modpackLockEntryPath entry)
    , modpackLockEntryKind entry
    , fromMaybe "" (modpackLockEntrySha1 entry)
    , fromMaybe "" (modpackLockEntrySource entry)
    ]

removePathIfExists :: FilePath -> IO ()
removePathIfExists path = do
  directoryExists <- doesDirectoryExist path
  when directoryExists (removeDirectoryRecursive path)
  fileExists <- doesFileExist path
  when (fileExists && not directoryExists) (removeFile path)
