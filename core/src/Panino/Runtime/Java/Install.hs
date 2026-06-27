{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Runtime.Java.Install
  ( importJavaRuntime
  , installJavaRuntime
  ) where

import Control.Applicative ((<|>))
import Control.Exception
  ( SomeException
  , catch
  , onException
  , throwIO
  )
import Control.Monad
  ( unless
  , void
  , when
  )
import Data.Char
  ( toLower
  )
import Data.List (isInfixOf)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Local.Java (checkJavaRuntime)
import Panino.Content.Local.Path (removePathIfExists)
import Panino.Content.Local.Types
  ( JavaCheckRequest(..)
  , JavaCheckResponse(..)
  )
import Panino.Core.Types
  ( urlFromText
  )
import Panino.Download.Manager
  ( DownloadJob(..)
  , DownloadProgress
  , runDownloadJobsWithOptionsAndProgressAndCancel
  )
import Panino.Net.Http
  ( RequestTimeoutClass(..)
  , coreRequestWithTimeout
  , fetchJson
  )
import Panino.Runtime.Java.Catalog
  ( defaultRuntimeArch
  , defaultRuntimeOs
  , runtimeDownloadSpecForProvider
  )
import Panino.Runtime.Java.Install.Archive
  ( archiveExtension
  , copyOrExtractImportSource
  , ensureSafeRuntimePath
  , extractArchive
  , findJavaExecutable
  , runProcessChecked
  , sanitizeRuntimeId
  , takeSafeSourceName
  , validateExtractedTree
  )
import Panino.Runtime.Java.Install.Checksum
  ( fetchRuntimeSha256
  , verifySha256
  )
import Panino.Runtime.Java.Install.Mojang
  ( MojangRuntimeFile(..)
  , MojangRuntimeManifest(..)
  , chmodMojangExecutable
  , mojangDownloadJobs
  )
import Panino.Runtime.Java.Install.Options
  ( downloadOptionsFromRuntime
  , javaMajorCompatible
  , normalizeProvider
  , runtimeArchCompatible
  )
import Panino.Runtime.Java.Store
  ( managedJavaRoot
  , managedRuntimeDirectory
  , selectJavaRuntimePolicy
  , upsertManagedRuntime
  )
import Panino.Runtime.Java.Types
  ( JavaManagedRuntime(..)
  , JavaRuntimeDownloadSpec(..)
  , JavaRuntimeImportRequest(..)
  , JavaRuntimeInstallRequest(..)
  , JavaRuntimeSelectRequest(..)
  )
import System.Directory
  ( createDirectoryIfMissing
  , renameDirectory
  )
import System.FilePath
  ( makeRelative
  , takeDirectory
  , (</>)
  )
import Data.Time.Clock (getCurrentTime)

installJavaRuntime :: Manager -> FilePath -> JavaRuntimeInstallRequest -> IO Bool -> (DownloadProgress -> IO ()) -> IO JavaManagedRuntime
installJavaRuntime manager appRoot request isCancelled onProgress = do
  let runtimeOs = fromMaybe defaultRuntimeOs (installRuntimeOs request)
      runtimeArch = fromMaybe defaultRuntimeArch (installRuntimeArch request)
      imageType = installRuntimeImageType request
  spec <-
    runtimeDownloadSpecForProvider
      manager
      (installRuntimeProvider request)
      (installRuntimeFeatureVersion request)
      runtimeOs
      runtimeArch
      imageType
  if normalizeProvider (runtimeDownloadProvider spec) == "mojang"
    then installMojangRuntime manager appRoot request spec isCancelled onProgress
    else do
      (resolvedRequest, resolvedSpec, sha256, archivePath) <-
        downloadRuntimeWithFallback manager appRoot request spec isCancelled onProgress
      verifySha256 archivePath sha256
      runtime <- installArchive appRoot resolvedRequest resolvedSpec sha256 archivePath
      removePathIfExists archivePath
      pure runtime

importJavaRuntime :: FilePath -> JavaRuntimeImportRequest -> IO JavaManagedRuntime
importJavaRuntime appRoot request = do
  let stagingRoot = managedJavaRoot appRoot </> "staging"
      sourceName = Text.pack (takeSafeSourceName (importRuntimeSourcePath request))
      staging = stagingRoot </> Text.unpack (sanitizeRuntimeId ("import-" <> sourceName))
      runtimeOs = fromMaybe defaultRuntimeOs (importRuntimeOs request)
      runtimeArch = fromMaybe defaultRuntimeArch (importRuntimeArch request)
  removePathIfExists staging
  createDirectoryIfMissing True staging
  (do
      copyOrExtractImportSource (importRuntimeSourcePath request) staging
      validateExtractedTree staging
      runtime <-
        finalizeStagedRuntime
          appRoot
          (importRuntimeProvider request)
          (importRuntimeVendor request)
          (importRuntimeFeatureVersion request)
          runtimeOs
          runtimeArch
          (importRuntimeImageType request)
          (Text.pack (importRuntimeSourcePath request))
          Nothing
          staging
      applyDefaultRuntimeSelection appRoot (importRuntimeSetDefault request) runtime
    )
    `onException` removePathIfExists staging

downloadRuntimeWithFallback :: Manager -> FilePath -> JavaRuntimeInstallRequest -> JavaRuntimeDownloadSpec -> IO Bool -> (DownloadProgress -> IO ()) -> IO (JavaRuntimeInstallRequest, JavaRuntimeDownloadSpec, Text, FilePath)
downloadRuntimeWithFallback manager appRoot request spec isCancelled onProgress =
  attempt request spec `catch` \(err :: SomeException) ->
    if canFallbackToJdk request err
      then do
        let fallbackRequest = request { installRuntimeImageType = "jdk" }
        fallbackSpec <-
          runtimeDownloadSpecForProvider
            manager
            (installRuntimeProvider fallbackRequest)
            (installRuntimeFeatureVersion fallbackRequest)
            (fromMaybe defaultRuntimeOs (installRuntimeOs fallbackRequest))
            (fromMaybe defaultRuntimeArch (installRuntimeArch fallbackRequest))
            "jdk"
        attempt fallbackRequest fallbackSpec
      else throwIO err
  where
    attempt currentRequest currentSpec = do
      sha256 <- fetchRuntimeSha256 manager currentSpec
      archivePath <- downloadRuntimeArchive manager appRoot currentRequest currentSpec sha256 isCancelled onProgress
      pure (currentRequest, currentSpec, sha256, archivePath)

canFallbackToJdk :: JavaRuntimeInstallRequest -> SomeException -> Bool
canFallbackToJdk request err =
  installRuntimeImageType request == "jre" && runtimeNotFound err

runtimeNotFound :: SomeException -> Bool
runtimeNotFound err =
  "404" `isInfixOf` message || "not found" `isInfixOf` message
  where
    message = map toLower (show err)

downloadRuntimeArchive :: Manager -> FilePath -> JavaRuntimeInstallRequest -> JavaRuntimeDownloadSpec -> Text -> IO Bool -> (DownloadProgress -> IO ()) -> IO FilePath
downloadRuntimeArchive manager appRoot request spec sha256 isCancelled onProgress = do
  let downloadsDir = managedJavaRoot appRoot </> "downloads"
      archiveName =
        Text.unpack $
          Text.intercalate
            "-"
            [ runtimeDownloadVendor spec
            , Text.pack (show (runtimeDownloadFeatureVersion spec))
            , runtimeDownloadOs spec
            , runtimeDownloadArch spec
            , runtimeDownloadImageType spec
            ]
            <> archiveExtension (runtimeDownloadUrl spec)
      archivePath = downloadsDir </> archiveName
      options = downloadOptionsFromRuntime (installRuntimeDownload request)
  createDirectoryIfMissing True downloadsDir
  _ <-
    runDownloadJobsWithOptionsAndProgressAndCancel
      manager
      options
      isCancelled
      [ DownloadJob
          { jobLabel = "Java " <> show (runtimeDownloadFeatureVersion spec) <> " runtime"
          , jobUrl = urlFromText (runtimeDownloadUrl spec)
          , jobTargetPath = archivePath
          , jobSha1 = Nothing
          , jobSize = Nothing
          }
      ]
      onProgress
  verifySha256 archivePath sha256
  pure archivePath

installArchive :: FilePath -> JavaRuntimeInstallRequest -> JavaRuntimeDownloadSpec -> Text -> FilePath -> IO JavaManagedRuntime
installArchive appRoot request spec sha256 archivePath = do
  let stagingRoot = managedJavaRoot appRoot </> "staging"
      staging = stagingRoot </> Text.unpack (sanitizeRuntimeId (runtimeDownloadVendor spec <> "-" <> Text.pack (show (runtimeDownloadFeatureVersion spec))))
  removePathIfExists staging
  createDirectoryIfMissing True staging
  (do
      extractArchive archivePath staging
      validateExtractedTree staging
      runtime <-
        finalizeStagedRuntime
          appRoot
          (runtimeDownloadProvider spec)
          (runtimeDownloadVendor spec)
          (Just (installRuntimeFeatureVersion request))
          (runtimeDownloadOs spec)
          (runtimeDownloadArch spec)
          (runtimeDownloadImageType spec)
          (runtimeDownloadUrl spec)
          (Just sha256)
          staging
      applyDefaultRuntimeSelection appRoot (installRuntimeSetDefault request) runtime
    )
    `onException` removePathIfExists staging

installMojangRuntime :: Manager -> FilePath -> JavaRuntimeInstallRequest -> JavaRuntimeDownloadSpec -> IO Bool -> (DownloadProgress -> IO ()) -> IO JavaManagedRuntime
installMojangRuntime manager appRoot request spec isCancelled onProgress = do
  manifest <- fetchJson manager =<< coreRequestWithTimeout LongMetadata (Text.unpack (runtimeDownloadUrl spec)) []
  let stagingRoot = managedJavaRoot appRoot </> "staging"
      staging =
        stagingRoot
          </> Text.unpack
            ( sanitizeRuntimeId
                ( "mojang-"
                    <> Text.pack (show (installRuntimeFeatureVersion request))
                    <> "-"
                    <> runtimeDownloadOs spec
                    <> "-"
                    <> runtimeDownloadArch spec
                )
            )
      options = downloadOptionsFromRuntime (installRuntimeDownload request)
      entries = mojangManifestFiles manifest
      directories = [path | (path, file) <- entries, mojangFileType file == "directory"]
      files = [(path, file) | (path, file) <- entries, mojangFileType file == "file"]
  removePathIfExists staging
  createDirectoryIfMissing True staging
  (do
      mapM_ ensureSafeRuntimePath (directories <> map fst files)
      mapM_ (createDirectoryIfMissing True . (staging </>)) directories
      mapM_ (createDirectoryIfMissing True . takeDirectory . (staging </>) . fst) files
      _ <-
        runDownloadJobsWithOptionsAndProgressAndCancel
          manager
          options
          isCancelled
          (mojangDownloadJobs staging files)
          onProgress
      mapM_ (chmodMojangExecutable staging) files
      validateExtractedTree staging
      runtime <-
        finalizeStagedRuntime
          appRoot
          "mojang"
          "mojang"
          (Just (installRuntimeFeatureVersion request))
          (runtimeDownloadOs spec)
          (runtimeDownloadArch spec)
          (runtimeDownloadImageType spec)
          (runtimeDownloadUrl spec)
          Nothing
          staging
      applyDefaultRuntimeSelection appRoot (installRuntimeSetDefault request) runtime
    )
    `onException` removePathIfExists staging

applyDefaultRuntimeSelection :: FilePath -> Bool -> JavaManagedRuntime -> IO JavaManagedRuntime
applyDefaultRuntimeSelection appRoot shouldSetDefault runtime = do
  when shouldSetDefault $
    void $
      selectJavaRuntimePolicy appRoot JavaRuntimeSelectRequest
        { selectRuntimeScope = "global"
        , selectRuntimeInstanceId = Nothing
        , selectRuntimePolicy = "managed"
        , selectRuntimePreferredRuntimeId = Just (managedRuntimeId runtime)
        , selectRuntimeCustomPath = Nothing
        , selectRuntimeLockPatchVersion = False
        }
  pure runtime

finalizeStagedRuntime :: FilePath -> Text -> Text -> Maybe Int -> Text -> Text -> Text -> Text -> Maybe Text -> FilePath -> IO JavaManagedRuntime
finalizeStagedRuntime appRoot provider vendor maybeFeatureVersion runtimeOs runtimeArch imageType sourceUrl sha256 staging = do
  javaExecutable <- maybe (fail "java_runtime_extract_failed: extracted runtime does not contain bin/java") pure =<< findJavaExecutable staging
  runProcessChecked "/bin/chmod" ["+x", javaExecutable] "java_runtime_permission_denied"
  status <- checkJavaRuntime (JavaCheckRequest (Just javaExecutable))
  unless (javaResponseAvailable status) $
    fail ("java_runtime_incompatible: " <> Text.unpack (javaResponseSummary status))
  featureVersion <-
    maybe
      (fail "java_runtime_incompatible: Java major version could not be detected")
      pure
      (maybeFeatureVersion <|> javaResponseMajorVersion status)
  unless (maybe False (javaMajorCompatible featureVersion) (javaResponseMajorVersion status)) $
    fail ("java_runtime_incompatible: expected Java " <> show featureVersion)
  unless (maybe False (runtimeArchCompatible runtimeArch) (javaResponseArchitecture status)) $
    fail
      ( "java_runtime_arch_mismatch: expected "
          <> Text.unpack runtimeArch
          <> ", got "
          <> Text.unpack (fromMaybe "unknown" (javaResponseArchitecture status))
      )
  let versionText = fromMaybe (Text.pack (show featureVersion)) (javaResponseVersion status)
      runtimeId =
        sanitizeRuntimeId $
          Text.intercalate
            "-"
            [ vendor
            , versionText
            , runtimeOs
            , runtimeArch
            , imageType
            ]
      target = managedRuntimeDirectory appRoot runtimeId
      relativeJava = makeRelative staging javaExecutable
      targetJavaExecutable = target </> relativeJava
      javaHome = takeDirectory (takeDirectory targetJavaExecutable)
  removePathIfExists target
  createDirectoryIfMissing True (takeDirectory target)
  renameDirectory staging target
  now <- getCurrentTime
  upsertManagedRuntime appRoot JavaManagedRuntime
    { managedRuntimeId = runtimeId
    , managedRuntimeVendor = vendor
    , managedRuntimeProvider = provider
    , managedRuntimeFeatureVersion = featureVersion
    , managedRuntimeVersion = versionText
    , managedRuntimeOs = runtimeOs
    , managedRuntimeArch = runtimeArch
    , managedRuntimeImageType = imageType
    , managedRuntimeJavaHome = javaHome
    , managedRuntimeJavaExecutable = targetJavaExecutable
    , managedRuntimeSourceUrl = sourceUrl
    , managedRuntimeSha256 = sha256
    , managedRuntimeInstalledAt = now
    , managedRuntimeLastVerifiedAt = Just now
    , managedRuntimeDiskUsageBytes = Nothing
    , managedRuntimeUsedByInstanceCount = 0
    }
