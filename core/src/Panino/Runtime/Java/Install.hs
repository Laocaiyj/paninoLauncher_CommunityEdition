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
import Data.Aeson
  ( FromJSON(..)
  , Value(..)
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Aeson.Types (Parser)
import Data.Char
  ( isAlphaNum
  , isHexDigit
  , toLower
  )
import Data.Int (Int64)
import Data.List
  ( isInfixOf
  , isPrefixOf
  , isSuffixOf
  , sortOn
  )
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Api.Types (DownloadRuntimeOptions(..))
import Panino.Content.Local.Java (checkJavaRuntime)
import Panino.Content.Local.Path (removePathIfExists)
import Panino.Content.Local.Types
  ( JavaCheckRequest(..)
  , JavaCheckResponse(..)
  )
import Panino.Download.Manager
  ( DownloadJob(..)
  , DownloadOptions
  , DownloadProgress
  , downloadOptionsWithOverrides
  , runDownloadJobsWithOptionsAndProgressAndCancel
  )
import Panino.Net.Http
  ( RequestTimeoutClass(..)
  , coreRequestWithTimeout
  , fetchJson
  , fetchText
  )
import Panino.Runtime.Java.Catalog
  ( defaultRuntimeArch
  , defaultRuntimeOs
  , runtimeDownloadSpecForProvider
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
  , doesDirectoryExist
  , doesFileExist
  , listDirectory
  , renameDirectory
  )
import System.Exit (ExitCode(..))
import System.FilePath
  ( isAbsolute
  , makeRelative
  , normalise
  , splitDirectories
  , takeDirectory
  , takeFileName
  , (</>)
  )
import System.Posix.Files
  ( getSymbolicLinkStatus
  , isSymbolicLink
  , readSymbolicLink
  )
import System.Process
  ( proc
  , readCreateProcessWithExitCode
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
          , jobUrl = Text.unpack (runtimeDownloadUrl spec)
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

copyOrExtractImportSource :: FilePath -> FilePath -> IO ()
copyOrExtractImportSource sourcePath staging = do
  sourceIsDirectory <- doesDirectoryExist sourcePath
  sourceIsFile <- doesFileExist sourcePath
  if sourceIsDirectory
    then runProcessChecked "/bin/cp" ["-R", sourcePath, staging] "java_runtime_extract_failed"
    else
      if sourceIsFile
        then extractArchive sourcePath staging
        else fail "java_runtime_missing: import source does not exist"

extractArchive :: FilePath -> FilePath -> IO ()
extractArchive archivePath staging
  | ".zip" `isSuffixOf` map toLower archivePath = do
      validateZipNames archivePath
      runProcessChecked "/usr/bin/unzip" ["-q", archivePath, "-d", staging] "java_runtime_extract_failed"
  | otherwise = do
      validateTarNames archivePath
      runProcessChecked "/usr/bin/tar" ["-xzf", archivePath, "-C", staging] "java_runtime_extract_failed"

archiveExtension :: Text -> Text
archiveExtension url
  | ".zip" `Text.isSuffixOf` lowered = ".zip"
  | otherwise = ".tar.gz"
  where
    lowered = Text.toLower url

ensureSafeRuntimePath :: FilePath -> IO ()
ensureSafeRuntimePath path =
  when (unsafeTarEntry path) $
    fail "java_runtime_extract_failed: runtime manifest contains unsafe paths"

mojangDownloadJobs :: FilePath -> [(FilePath, MojangRuntimeFile)] -> [DownloadJob]
mojangDownloadJobs staging =
  mapMaybe jobForFile
  where
    jobForFile (path, file) = do
      download <- mojangFileRawDownload file
      pure DownloadJob
        { jobLabel = path
        , jobUrl = Text.unpack (mojangDownloadUrl download)
        , jobTargetPath = staging </> path
        , jobSha1 = Just (mojangDownloadSha1 download)
        , jobSize = mojangDownloadSize download
        }

chmodMojangExecutable :: FilePath -> (FilePath, MojangRuntimeFile) -> IO ()
chmodMojangExecutable staging (path, file) =
  when (mojangFileExecutable file) $
    runProcessChecked "/bin/chmod" ["+x", staging </> path] "java_runtime_permission_denied"

data MojangRuntimeManifest = MojangRuntimeManifest
  { mojangManifestFiles :: [(FilePath, MojangRuntimeFile)]
  } deriving (Eq, Show)

instance FromJSON MojangRuntimeManifest where
  parseJSON =
    withObject "MojangRuntimeManifest" $ \obj -> do
      filesValue <- obj .: "files"
      case filesValue of
        Object files -> do
          entries <-
            traverse
              ( \(key, value) -> do
                  file <- parseJSON value
                  pure (Text.unpack (Key.toText key), file)
              )
              (KeyMap.toList files)
          pure (MojangRuntimeManifest entries)
        _ -> fail "Mojang runtime manifest files must be an object"

data MojangRuntimeFile = MojangRuntimeFile
  { mojangFileType :: Text
  , mojangFileRawDownload :: Maybe MojangFileDownload
  , mojangFileExecutable :: Bool
  } deriving (Eq, Show)

instance FromJSON MojangRuntimeFile where
  parseJSON =
    withObject "MojangRuntimeFile" $ \obj -> do
      downloads <- (obj .:? "downloads" :: Parser (Maybe Value))
      raw <-
        case downloads of
          Just (Object values) ->
            case KeyMap.lookup (Key.fromText "raw") values of
              Just rawValue -> Just <$> parseJSON rawValue
              Nothing -> pure Nothing
          _ -> pure Nothing
      MojangRuntimeFile
        <$> obj .: "type"
        <*> pure raw
        <*> obj .:? "executable" .!= False

data MojangFileDownload = MojangFileDownload
  { mojangDownloadSha1 :: Text
  , mojangDownloadSize :: Maybe Int64
  , mojangDownloadUrl :: Text
  } deriving (Eq, Show)

instance FromJSON MojangFileDownload where
  parseJSON =
    withObject "MojangFileDownload" $ \obj ->
      MojangFileDownload
        <$> obj .: "sha1"
        <*> obj .:? "size"
        <*> obj .: "url"

fetchRuntimeSha256 :: Manager -> JavaRuntimeDownloadSpec -> IO Text
fetchRuntimeSha256 manager spec =
  case runtimeDownloadSha256 spec of
    Just sha256 -> pure sha256
    Nothing ->
      case runtimeDownloadChecksumUrl spec of
        Nothing -> fail "java_runtime_checksum_missing: provider did not expose checksum URL"
        Just url -> do
          text <- fetchText manager =<< coreRequestWithTimeout LongMetadata (Text.unpack url) []
          maybe
            (fail "java_runtime_checksum_missing: checksum response did not contain SHA-256")
            pure
            (parseSha256 text)

parseSha256 :: Text -> Maybe Text
parseSha256 text =
  listToMaybe
    [ Text.toLower token
    | token <- Text.words text
    , Text.length token == 64
    , Text.all isHexDigit token
    ]

verifySha256 :: FilePath -> Text -> IO ()
verifySha256 path expected = do
  actual <- sha256HexFile path
  unless (Text.toLower expected == Text.toLower actual) $ do
    removePathIfExists path
    fail "java_runtime_checksum_mismatch: downloaded Java archive failed SHA-256 verification"

sha256HexFile :: FilePath -> IO Text
sha256HexFile path = do
  (exitCode, stdoutText, stderrText) <- tryShasum "/usr/bin/shasum" `catch` \(_ :: SomeException) -> tryShasum "shasum"
  case exitCode of
    ExitSuccess -> pure (parseOutput stdoutText)
    ExitFailure _ -> fail ("java_runtime_checksum_failed: " <> stderrText)
  where
    tryShasum command = do
      (exitCode, stdoutText, stderrText) <- readCreateProcessWithExitCode (proc command ["-a", "256", path]) ""
      pure (exitCode, stdoutText, stderrText)
    parseOutput =
      Text.toLower . Text.pack . takeWhile (/= ' ')

validateTarNames :: FilePath -> IO ()
validateTarNames archivePath = do
  (_, stdoutText, _) <- runProcessCheckedCapture "/usr/bin/tar" ["-tzf", archivePath] "java_runtime_extract_failed"
  let entries = filter (not . null) (lines stdoutText)
  when (any unsafeTarEntry entries) $
    fail "java_runtime_extract_failed: archive contains unsafe paths"
  (_, verboseText, _) <- runProcessCheckedCapture "/usr/bin/tar" ["-tzvf", archivePath] "java_runtime_extract_failed"
  validateArchiveSymlinkTargets (mapMaybe tarSymlinkTarget (lines verboseText))

validateZipNames :: FilePath -> IO ()
validateZipNames archivePath = do
  (_, stdoutText, _) <- runProcessCheckedCapture "/usr/bin/unzip" ["-Z", "-1", archivePath] "java_runtime_extract_failed"
  let entries = filter (not . null) (lines stdoutText)
  when (any unsafeTarEntry entries) $
    fail "java_runtime_extract_failed: archive contains unsafe paths"
  (_, listingText, _) <- runProcessCheckedCapture "/usr/bin/unzip" ["-Z", "-l", archivePath] "java_runtime_extract_failed"
  targets <- traverse (zipSymlinkTarget archivePath) (mapMaybe zipSymlinkName (lines listingText))
  validateArchiveSymlinkTargets targets

validateArchiveSymlinkTargets :: [FilePath] -> IO ()
validateArchiveSymlinkTargets targets =
  when (any unsafeTarEntry targets) $
    fail "java_runtime_extract_failed: archive contains unsafe symlink"

tarSymlinkTarget :: String -> Maybe FilePath
tarSymlinkTarget line
  | "l" `isPrefixOf` line = trimStringLocal <$> arrowTarget line
  | otherwise = Nothing

arrowTarget :: String -> Maybe String
arrowTarget [] = Nothing
arrowTarget text@(_:rest)
  | " -> " `isPrefixOf` text = Just (drop 4 text)
  | otherwise = arrowTarget rest

zipSymlinkName :: String -> Maybe FilePath
zipSymlinkName line =
  case words line of
    permissions:_
      | "l" `isPrefixOf` permissions && length fields >= 10 ->
          Just (unwords (drop 9 fields))
    _ -> Nothing
  where
    fields = words line

zipSymlinkTarget :: FilePath -> FilePath -> IO FilePath
zipSymlinkTarget archivePath entry = do
  (_, stdoutText, _) <- runProcessCheckedCapture "/usr/bin/unzip" ["-p", archivePath, entry] "java_runtime_extract_failed"
  pure (trimStringLocal stdoutText)

unsafeTarEntry :: FilePath -> Bool
unsafeTarEntry path =
  isAbsolute path || any (== "..") (splitDirectories (normalise path))

trimStringLocal :: String -> String
trimStringLocal =
  Text.unpack . Text.strip . Text.pack

validateExtractedTree :: FilePath -> IO ()
validateExtractedTree root = do
  exists <- doesDirectoryExist root
  when exists $ do
    names <- sortOn id <$> listDirectory root
    mapM_ (validatePath . (root </>)) names
  where
    validatePath path = do
      status <- getSymbolicLinkStatus path
      symlink <- pure (isSymbolicLink status)
      when symlink $ do
        target <- readSymbolicLink path
        when (unsafeTarEntry target) $
          fail "java_runtime_extract_failed: archive contains unsafe symlink"
      isDir <- if symlink then pure False else doesDirectoryExist path
      when isDir $ do
        names <- sortOn id <$> listDirectory path
        mapM_ (validatePath . (path </>)) names

findJavaExecutable :: FilePath -> IO (Maybe FilePath)
findJavaExecutable root = do
  exists <- doesDirectoryExist root
  if not exists
    then pure Nothing
    else search root
  where
    search path = do
      names <- sortOn id <$> listDirectory path
      let direct = [path </> name | name <- names, name == "java" && "bin" `isSuffixOf` takeDirectory (path </> name)]
      foundFiles <- filterM doesFileExist direct
      case foundFiles of
        first:_ -> pure (Just first)
        [] -> do
          dirs <- filterM doesDirectoryExist [path </> name | name <- names]
          firstJust <$> traverse search dirs

firstJust :: [Maybe a] -> Maybe a
firstJust [] = Nothing
firstJust (Just value:_) = Just value
firstJust (Nothing:rest) = firstJust rest

runProcessChecked :: FilePath -> [String] -> String -> IO ()
runProcessChecked command args errorCode = do
  (exitCode, _, stderrText) <- readCreateProcessWithExitCode (proc command args) ""
  case exitCode of
    ExitSuccess -> pure ()
    ExitFailure _ -> fail (errorCode <> ": " <> stderrText)

runProcessCheckedCapture :: FilePath -> [String] -> String -> IO (ExitCode, String, String)
runProcessCheckedCapture command args errorCode = do
  result@(exitCode, _, stderrText) <- readCreateProcessWithExitCode (proc command args) ""
  case exitCode of
    ExitSuccess -> pure result
    ExitFailure _ -> fail (errorCode <> ": " <> stderrText)

downloadOptionsFromRuntime :: DownloadRuntimeOptions -> DownloadOptions
downloadOptionsFromRuntime options =
  downloadOptionsWithOverrides
    (strategyConcurrency options)
    (strategyRetryCount options)

strategyConcurrency :: DownloadRuntimeOptions -> Maybe Int
strategyConcurrency options =
  case normalizeDownloadStrategy <$> downloadRuntimeStrategy options of
    Just "fast" -> Just (max 48 (fromMaybe 32 (downloadRuntimeConcurrency options)))
    Just "conservative" -> Just (min 12 (fromMaybe 12 (downloadRuntimeConcurrency options)))
    _ -> downloadRuntimeConcurrency options

strategyRetryCount :: DownloadRuntimeOptions -> Maybe Int
strategyRetryCount options =
  case normalizeDownloadStrategy <$> downloadRuntimeStrategy options of
    Just "fast" -> Just (max 4 (fromMaybe 3 (downloadRuntimeRetryCount options)))
    Just "conservative" -> Just (max 2 (fromMaybe 2 (downloadRuntimeRetryCount options)))
    _ -> downloadRuntimeRetryCount options

normalizeDownloadStrategy :: Text -> Text
normalizeDownloadStrategy =
  Text.toLower . Text.replace "-" "" . Text.replace "_" ""

javaMajorCompatible :: Int -> Int -> Bool
javaMajorCompatible required actual
  | required >= 17 = actual >= required
  | otherwise = actual == required

runtimeArchCompatible :: Text -> Text -> Bool
runtimeArchCompatible expected actual =
  normalizeArch expected == normalizeArch actual

normalizeArch :: Text -> Text
normalizeArch value
  | lowered `elem` ["aarch64", "arm64"] = "aarch64"
  | lowered `elem` ["x64", "x86_64", "amd64"] = "x64"
  | otherwise = lowered
  where
    lowered = Text.toLower value

normalizeProvider :: Text -> Text
normalizeProvider =
  Text.toLower . Text.strip

sanitizeRuntimeId :: Text -> Text
sanitizeRuntimeId =
  Text.map sanitizeChar
  where
    sanitizeChar char
      | isAlphaNum char = char
      | char `elem` ("._-+" :: String) = char
      | otherwise = '-'

takeSafeSourceName :: FilePath -> String
takeSafeSourceName path =
  case takeFileName (normalise path) of
    "" -> "runtime"
    name -> name

filterM :: Monad m => (a -> m Bool) -> [a] -> m [a]
filterM predicate =
  foldr
    (\value rest -> do
        keep <- predicate value
        values <- rest
        pure (if keep then value : values else values)
    )
    (pure [])
