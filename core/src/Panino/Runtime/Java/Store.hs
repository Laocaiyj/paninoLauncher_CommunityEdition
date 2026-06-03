{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Runtime.Java.Store
  ( cleanupUnusedJavaRuntimes
  , deleteManagedRuntime
  , findManagedRuntime
  , managedJavaRoot
  , managedRuntimeDirectory
  , readManagedRuntimes
  , readRuntimePolicies
  , runtimePolicyForInstance
  , runtimeReferences
  , selectJavaRuntimePolicy
  , upsertManagedRuntime
  , verifyManagedRuntime
  ) where

import Control.Exception
  ( SomeException
  , catch
  )
import Control.Applicative ((<|>))
import Control.Monad (unless, when)
import Data.Aeson
  ( FromJSON
  , eitherDecode
  , encode
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.Int (Int64)
import Data.List
  ( find
  , sortOn
  )
import Data.Maybe (mapMaybe)
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (getCurrentTime)
import Panino.Content.Local.Java (checkJavaRuntime)
import Panino.Content.Local.Types
  ( JavaCheckRequest(..)
  , JavaCheckResponse(..)
  )
import Panino.Runtime.Java.Types
  ( JavaManagedRuntime(..)
  , JavaRuntimeCleanupResponse(..)
  , JavaRuntimeDeleteResponse(..)
  , JavaRuntimePolicyRecord(..)
  , JavaRuntimeSelectRequest(..)
  , JavaRuntimeSelectResponse(..)
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getFileSize
  , listDirectory
  , removeDirectoryRecursive
  , removeFile
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  )

managedJavaRoot :: FilePath -> FilePath
managedJavaRoot appRoot =
  appRoot </> "runtimes" </> "java"

managedRuntimeDirectory :: FilePath -> Text -> FilePath
managedRuntimeDirectory appRoot runtimeId =
  managedJavaRoot appRoot </> "managed" </> Text.unpack runtimeId

managedIndexPath :: FilePath -> FilePath
managedIndexPath appRoot =
  managedJavaRoot appRoot </> "managed-index.json"

runtimePolicyPath :: FilePath -> FilePath
runtimePolicyPath appRoot =
  managedJavaRoot appRoot </> "runtime-policy.json"

readManagedRuntimes :: FilePath -> IO [JavaManagedRuntime]
readManagedRuntimes appRoot = do
  let path = managedIndexPath appRoot
  exists <- doesFileExist path
  runtimes <-
    if not exists
      then rebuildManagedIndex appRoot
      else do
        decoded <- decodeJsonFile path
        case decoded of
          Right loaded -> refreshRuntimeSizes loaded
          Left _ -> rebuildManagedIndex appRoot
  annotateRuntimeUsage appRoot runtimes

upsertManagedRuntime :: FilePath -> JavaManagedRuntime -> IO JavaManagedRuntime
upsertManagedRuntime appRoot runtime = do
  existing <- readManagedRuntimes appRoot
  let runtimes = runtime : filter ((/= managedRuntimeId runtime) . managedRuntimeId) existing
  writeManagedRuntimes appRoot runtimes
  writeRuntimeJson appRoot runtime
  pure runtime

findManagedRuntime :: FilePath -> Text -> IO (Maybe JavaManagedRuntime)
findManagedRuntime appRoot runtimeId =
  find ((== runtimeId) . managedRuntimeId) <$> readManagedRuntimes appRoot

verifyManagedRuntime :: FilePath -> Text -> IO JavaManagedRuntime
verifyManagedRuntime appRoot runtimeId = do
  runtime <- maybe (fail ("managed Java runtime not found: " <> Text.unpack runtimeId)) pure =<< findManagedRuntime appRoot runtimeId
  status <- checkJavaRuntime (JavaCheckRequest (Just (managedRuntimeJavaExecutable runtime)))
  unless (javaResponseAvailable status) $
    fail ("managed Java runtime failed verification: " <> Text.unpack (javaResponseSummary status))
  now <- getCurrentTime
  upsertManagedRuntime appRoot runtime { managedRuntimeLastVerifiedAt = Just now }

deleteManagedRuntime :: FilePath -> Text -> IO JavaRuntimeDeleteResponse
deleteManagedRuntime appRoot runtimeId = do
  runtimes <- readManagedRuntimes appRoot
  refs <- runtimeReferences appRoot runtimeId
  let targetDir = managedRuntimeDirectory appRoot runtimeId
      remaining = filter ((/= runtimeId) . managedRuntimeId) runtimes
      existed = length remaining /= length runtimes
  if not (null refs)
    then
      pure JavaRuntimeDeleteResponse
        { deleteRuntimeDeleted = False
        , deleteRuntimeId = runtimeId
        , deleteRuntimeMessage = "runtime is still selected by " <> Text.intercalate ", " refs
        , deleteRuntimeReferences = refs
        }
    else do
      whenDirectoryExists targetDir (removeDirectoryRecursive targetDir)
      writeManagedRuntimes appRoot remaining
      pure JavaRuntimeDeleteResponse
        { deleteRuntimeDeleted = existed
        , deleteRuntimeId = runtimeId
        , deleteRuntimeMessage =
            if existed then "runtime deleted" else "runtime was not registered"
        , deleteRuntimeReferences = []
        }

readRuntimePolicies :: FilePath -> IO [JavaRuntimePolicyRecord]
readRuntimePolicies appRoot = do
  let path = runtimePolicyPath appRoot
  exists <- doesFileExist path
  if not exists
    then pure []
    else do
      decoded <- decodeJsonFile path
      case decoded of
        Right policies -> pure policies
        Left _ -> pure []

selectJavaRuntimePolicy :: FilePath -> JavaRuntimeSelectRequest -> IO JavaRuntimeSelectResponse
selectJavaRuntimePolicy appRoot request = do
  now <- getCurrentTime
  let scope = normalizePolicyScope (selectRuntimeScope request)
      policy = normalizeRuntimePolicy (selectRuntimePolicy request)
      record =
        JavaRuntimePolicyRecord
          { policyRecordScope = scope
          , policyRecordInstanceId = selectRuntimeInstanceId request
          , policyRecordPolicy = policy
          , policyRecordPreferredRuntimeId =
              if policy == "managed" then selectRuntimePreferredRuntimeId request else Nothing
          , policyRecordCustomPath =
              if policy == "custom" then selectRuntimeCustomPath request else Nothing
          , policyRecordLockPatchVersion = selectRuntimeLockPatchVersion request
          , policyRecordUpdatedAt = now
          }
      matches existing =
        policyRecordScope existing == scope
          && policyRecordInstanceId existing == policyRecordInstanceId record
  policies <- readRuntimePolicies appRoot
  writeRuntimePolicies appRoot (record : filter (not . matches) policies)
  pure JavaRuntimeSelectResponse
    { selectResponsePolicy = record
    , selectResponseMessage = "Java runtime policy saved"
    }

runtimePolicyForInstance :: FilePath -> Maybe Text -> IO (Maybe JavaRuntimePolicyRecord)
runtimePolicyForInstance appRoot maybeInstanceId = do
  policies <- readRuntimePolicies appRoot
  pure (instancePolicy policies <|> globalPolicy policies)
  where
    instancePolicy policies = do
      instanceId <- maybeInstanceId
      find
        ( \policy ->
            policyRecordScope policy == "instance"
              && policyRecordInstanceId policy == Just instanceId
        )
        policies
    globalPolicy =
      find (\policy -> policyRecordScope policy == "global")

runtimeReferences :: FilePath -> Text -> IO [Text]
runtimeReferences appRoot runtimeId = do
  policies <- readRuntimePolicies appRoot
  pure
    [ referenceLabel policy
    | policy <- policies
    , policyRecordPolicy policy == "managed"
    , policyRecordPreferredRuntimeId policy == Just runtimeId
    ]
  where
    referenceLabel policy =
      case policyRecordScope policy of
        "instance" -> "instance:" <> maybe "unknown" id (policyRecordInstanceId policy)
        "global" -> "global"
        other -> other

cleanupUnusedJavaRuntimes :: FilePath -> IO JavaRuntimeCleanupResponse
cleanupUnusedJavaRuntimes appRoot = do
  runtimes <- readManagedRuntimes appRoot
  referencedIds <- referencedRuntimeIds appRoot
  let keepRuntime runtime = managedRuntimeId runtime `elem` referencedIds
      groups = groupRuntimesByKey runtimes
      duplicateDeletes =
        concatMap
          ( \group ->
              case sortOn (Down . managedRuntimeInstalledAt) group of
                [] -> []
                _newest:older -> filter (not . keepRuntime) older
          )
          groups
      deleteIds = map managedRuntimeId duplicateDeletes
      remaining = filter ((`notElem` deleteIds) . managedRuntimeId) runtimes
      keptIds = map managedRuntimeId remaining
  deletedRuntimeBytes <- sum <$> traverse runtimeStoredSize duplicateDeletes
  mapM_ (whenDirectoryExists' . managedRuntimeDirectory appRoot) deleteIds
  writeManagedRuntimes appRoot remaining
  (downloadFiles, downloadBytes) <- cleanRuntimeChildFiles (managedJavaRoot appRoot </> "downloads")
  (stagingDirs, stagingBytes) <- cleanRuntimeChildDirs (managedJavaRoot appRoot </> "staging")
  let totalFreed = deletedRuntimeBytes + downloadBytes + stagingBytes
  pure JavaRuntimeCleanupResponse
    { cleanupRuntimeDeletedRuntimeIds = deleteIds
    , cleanupRuntimeDeletedDownloadFiles = downloadFiles
    , cleanupRuntimeDeletedStagingDirs = stagingDirs
    , cleanupRuntimeFreedBytes = totalFreed
    , cleanupRuntimeKeptRuntimeIds = keptIds
    , cleanupRuntimeMessage =
        "cleaned "
          <> Text.pack (show (length deleteIds))
          <> " runtimes, "
          <> Text.pack (show (length downloadFiles))
          <> " downloads, "
          <> Text.pack (show (length stagingDirs))
          <> " staging directories"
    }

writeManagedRuntimes :: FilePath -> [JavaManagedRuntime] -> IO ()
writeManagedRuntimes appRoot runtimes = do
  let path = managedIndexPath appRoot
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path (encode runtimes)

writeRuntimeJson :: FilePath -> JavaManagedRuntime -> IO ()
writeRuntimeJson appRoot runtime = do
  let path = managedRuntimeDirectory appRoot (managedRuntimeId runtime) </> "runtime.json"
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path (encode runtime)

writeRuntimePolicies :: FilePath -> [JavaRuntimePolicyRecord] -> IO ()
writeRuntimePolicies appRoot policies = do
  let path = runtimePolicyPath appRoot
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path (encode policies)

decodeJsonFile :: FromJSON a => FilePath -> IO (Either String a)
decodeJsonFile path =
  eitherDecode . BL.fromStrict <$> BS.readFile path

rebuildManagedIndex :: FilePath -> IO [JavaManagedRuntime]
rebuildManagedIndex appRoot = do
  let managedRoot = managedJavaRoot appRoot </> "managed"
  exists <- doesDirectoryExist managedRoot
  runtimes <-
    if not exists
      then pure []
      else do
        names <- sortOn id <$> listDirectory managedRoot
        fmap (mapMaybe id) $
          traverse
            ( \name -> do
                let runtimeJson = managedRoot </> name </> "runtime.json"
                fileExists <- doesFileExist runtimeJson
                if not fileExists
                  then pure Nothing
                  else
                    ( either (const Nothing) Just <$> decodeJsonFile runtimeJson )
                      `catch` \(_ :: SomeException) -> pure Nothing
            )
            names
  refreshed <- refreshRuntimeSizes runtimes
  writeManagedRuntimes appRoot refreshed
  pure refreshed

refreshRuntimeSizes :: [JavaManagedRuntime] -> IO [JavaManagedRuntime]
refreshRuntimeSizes =
  traverse $ \runtime -> do
    size <- directorySize (takeDirectory (takeDirectory (managedRuntimeJavaExecutable runtime)))
    pure runtime { managedRuntimeDiskUsageBytes = Just size }

directorySize :: FilePath -> IO Int64
directorySize path = do
  isDir <- doesDirectoryExist path
  isFile <- doesFileExist path
  if isDir
    then do
      names <- sortOn id <$> listDirectory path `catch` \(_ :: SomeException) -> pure []
      sum <$> traverse (directorySize . (path </>)) names
    else
      if isFile
        then fromIntegral <$> getFileSize path
        else pure 0

whenDirectoryExists :: FilePath -> IO () -> IO ()
whenDirectoryExists path action = do
  exists <- doesDirectoryExist path
  when exists action

annotateRuntimeUsage :: FilePath -> [JavaManagedRuntime] -> IO [JavaManagedRuntime]
annotateRuntimeUsage appRoot runtimes = do
  policies <- readRuntimePolicies appRoot
  pure
    [ runtime
        { managedRuntimeUsedByInstanceCount =
            length
              [ ()
              | policy <- policies
              , policyRecordScope policy == "instance"
              , policyRecordPolicy policy == "managed"
              , policyRecordPreferredRuntimeId policy == Just (managedRuntimeId runtime)
              ]
        }
    | runtime <- runtimes
    ]

referencedRuntimeIds :: FilePath -> IO [Text]
referencedRuntimeIds appRoot = do
  policies <- readRuntimePolicies appRoot
  pure
    [ runtimeId
    | policy <- policies
    , policyRecordPolicy policy == "managed"
    , Just runtimeId <- [policyRecordPreferredRuntimeId policy]
    ]

groupRuntimesByKey :: [JavaManagedRuntime] -> [[JavaManagedRuntime]]
groupRuntimesByKey =
  foldr insertGroup []
  where
    insertGroup runtime [] = [[runtime]]
    insertGroup runtime (group:rest)
      | runtimeKey runtime == runtimeKey (head group) = (runtime : group) : rest
      | otherwise = group : insertGroup runtime rest
    runtimeKey runtime =
      ( managedRuntimeFeatureVersion runtime
      , normalizeText (managedRuntimeOs runtime)
      , normalizeText (managedRuntimeArch runtime)
      , normalizeText (managedRuntimeImageType runtime)
      )

runtimeStoredSize :: JavaManagedRuntime -> IO Int64
runtimeStoredSize runtime =
  directorySize (takeDirectory (takeDirectory (managedRuntimeJavaExecutable runtime)))

cleanRuntimeChildFiles :: FilePath -> IO ([FilePath], Int64)
cleanRuntimeChildFiles directory = do
  exists <- doesDirectoryExist directory
  if not exists
    then pure ([], 0)
    else do
      names <- sortOn id <$> listDirectory directory `catch` \(_ :: SomeException) -> pure []
      results <- traverse cleanFile [directory </> name | name <- names]
      pure (foldr collect ([], 0) results)
  where
    cleanFile path = do
      isFile <- doesFileExist path
      if not isFile
        then pure Nothing
        else do
          size <- fromIntegral <$> getFileSize path
          removeFile path `catch` \(_ :: SomeException) -> pure ()
          pure (Just (path, size))
    collect Nothing acc = acc
    collect (Just (path, size)) (paths, total) = (path : paths, total + size)

cleanRuntimeChildDirs :: FilePath -> IO ([FilePath], Int64)
cleanRuntimeChildDirs directory = do
  exists <- doesDirectoryExist directory
  if not exists
    then pure ([], 0)
    else do
      names <- sortOn id <$> listDirectory directory `catch` \(_ :: SomeException) -> pure []
      results <- traverse cleanDir [directory </> name | name <- names]
      pure (foldr collect ([], 0) results)
  where
    cleanDir path = do
      isDir <- doesDirectoryExist path
      if not isDir
        then pure Nothing
        else do
          size <- directorySize path
          removeDirectoryRecursive path `catch` \(_ :: SomeException) -> pure ()
          pure (Just (path, size))
    collect Nothing acc = acc
    collect (Just (path, size)) (paths, total) = (path : paths, total + size)

whenDirectoryExists' :: FilePath -> IO ()
whenDirectoryExists' path =
  whenDirectoryExists path (removeDirectoryRecursive path)

normalizePolicyScope :: Text -> Text
normalizePolicyScope value
  | normalized == "instance" = "instance"
  | otherwise = "global"
  where
    normalized = normalizeText value

normalizeRuntimePolicy :: Text -> Text
normalizeRuntimePolicy value
  | normalized `elem` ["auto", "managed", "local", "custom"] = normalized
  | otherwise = "auto"
  where
    normalized = normalizeText value

normalizeText :: Text -> Text
normalizeText =
  Text.toLower . Text.strip
