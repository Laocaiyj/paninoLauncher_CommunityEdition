{-# LANGUAGE OverloadedStrings #-}

module Integration.JavaRuntime.Install
  ( assertAutoJavaPathDownloadsManagedRuntime
  , assertJavaRuntimeInstallWithFakeAdoptium
  ) where

import Control.Concurrent.MVar
  ( modifyMVar_
  , newMVar
  , readMVar
  )
import Control.Concurrent.STM (newTVarIO)
import Control.Exception
  ( SomeException
  , finally
  , try
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List
  ( isInfixOf
  , isSuffixOf
  )
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import Data.Time.Clock (getCurrentTime)
import Integration.LoaderShaderFixtureServer (fakeLoaderShaderPreflightApp)
import Network.HTTP.Types
  ( hContentType
  , status200
  )
import Network.Wai
  ( Application
  , rawPathInfo
  , responseLBS
  )
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.Api.Routes.Minecraft.Common (resolveAutoJavaPath)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types (DownloadRuntimeOptions(..))
import Panino.Content.Local.Java (checkJavaRuntime)
import Panino.Content.Local.Types
  ( JavaCheckRequest(..)
  , JavaCheckResponse(..)
  )
import Panino.Download.Manager (DownloadProgress(..))
import Panino.Events.Bus (newEventBus)
import Panino.Minecraft.Layout (mkLayout)
import Panino.Net.Http (makeHttpManager)
import Panino.Runtime.Java.Install (installJavaRuntime)
import Panino.Runtime.Java.Store
  ( readManagedRuntimes
  , readRuntimePolicies
  )
import Panino.Runtime.Java.Types
  ( JavaManagedRuntime(..)
  , JavaRuntimeInstallRequest(..)
  , JavaRuntimePolicyRecord(..)
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , removeDirectoryRecursive
  )
import System.Environment
  ( setEnv
  , unsetEnv
  )
import System.Exit (exitFailure)
import System.FilePath
  ( (</>)
  , takeDirectory
  )
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )
import TestFixtures (fakeJavaScript)
import TestSupport
  ( assertEqual
  , catchAny
  , createTarGz
  , safePathSuffix
  , sha256Hex
  )

assertJavaRuntimeInstallWithFakeAdoptium :: FilePath -> IO ()
assertJavaRuntimeInstallWithFakeAdoptium tempDir = do
  manager <- makeHttpManager
  now <- getCurrentTime
  let root = tempDir </> ("panino-fake-adoptium-" <> safePathSuffix (show now))
      sourceRoot = root </> "source"
      javaExecutable = sourceRoot </> "Contents" </> "Home" </> "bin" </> "java"
      archivePath = root </> "fake-java.tar.gz"
      appRoot = root </> "app"
  removeDirectoryRecursive root `catchAny` \_ -> pure ()
  createDirectoryIfMissing True (takeDirectory javaExecutable)
  BS8.writeFile javaExecutable (BS8.pack fakeJavaScript)
  _ <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", javaExecutable]) ""
  createTarGz sourceRoot archivePath
  checksum <- sha256Hex archivePath
  archive <- BL.fromStrict <$> BS.readFile archivePath
  let runInstall targetAppRoot shouldSetDefault checksumText =
        withFakeAdoptiumServer archive checksumText $ do
          installJavaRuntime
            manager
            targetAppRoot
            JavaRuntimeInstallRequest
              { installRuntimeFeatureVersion = 21
              , installRuntimeProvider = "adoptium"
              , installRuntimeVendor = "temurin"
              , installRuntimeOs = Just "mac"
              , installRuntimeArch = Just "aarch64"
              , installRuntimeImageType = "jre"
              , installRuntimeSetDefault = shouldSetDefault
              , installRuntimeDownload = DownloadRuntimeOptions (Just 1) (Just 0) Nothing
              }
            (pure False)
            (\_ -> pure ())
  runtime <- runInstall appRoot True (Text.unpack checksum)
  assertEqual "fake Adoptium install writes managed runtime" 21 (managedRuntimeFeatureVersion runtime)
  policies <- readRuntimePolicies appRoot
  assertEqual "setDefault writes global managed runtime policy" [Just (managedRuntimeId runtime)] (map policyRecordPreferredRuntimeId policies)
  leftoverArchive <- doesFileExist (appRoot </> "runtimes" </> "java" </> "downloads" </> "temurin-21-mac-aarch64-jre.tar.gz")
  assertEqual "fake Adoptium install cleans archive" False leftoverArchive
  let mismatchRoot = root </> "mismatch-app"
  result <- try (runInstall mismatchRoot False (replicate 64 '0'))
  case (result :: Either SomeException JavaManagedRuntime) of
    Left _ -> pure ()
    Right _ -> do
      putStrLn "FAIL: fake Adoptium checksum mismatch"
      putStrLn "  expected: exception"
      putStrLn "  actual:   success"
      exitFailure
  mismatchManaged <- doesDirectoryExist (mismatchRoot </> "runtimes" </> "java" </> "managed")
  assertEqual "fake checksum mismatch does not install runtime" False mismatchManaged
  removeDirectoryRecursive root `catchAny` \_ -> pure ()

assertAutoJavaPathDownloadsManagedRuntime :: FilePath -> IO ()
assertAutoJavaPathDownloadsManagedRuntime tempDir = do
  manager <- makeHttpManager
  now <- getCurrentTime
  let root = tempDir </> ("panino-auto-java-path-" <> safePathSuffix (show now))
      gameDir = root </> "minecraft"
      appRoot = takeDirectory gameDir
      sourceRoot = root </> "source"
      javaExecutable = sourceRoot </> "Contents" </> "Home" </> "bin" </> "java"
      archivePath = root </> "fake-java.tar.gz"
      historyPath = root </> "task-history.json"
  removeDirectoryRecursive root `catchAny` \_ -> pure ()
  createDirectoryIfMissing True (takeDirectory javaExecutable)
  BS8.writeFile javaExecutable (BS8.pack fakeJavaScript)
  _ <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", javaExecutable]) ""
  createTarGz sourceRoot archivePath
  checksum <- sha256Hex archivePath
  archive <- BL.fromStrict <$> BS.readFile archivePath
  tasks <- newTVarIO Map.empty
  taskHandles <- newTVarIO Map.empty
  nextTaskId <- newTVarIO 1
  taowaSessions <- newTVarIO Map.empty
  events <- newEventBus
  progressLabels <- newMVar []
  testWithApplication (pure fakeLoaderShaderPreflightApp) $ \minecraftPort ->
    testWithApplication (pure (fakeAdoptiumApp archive (Text.unpack checksum))) $ \javaPort -> do
      let minecraftBase = "http://127.0.0.1:" <> show minecraftPort
          javaBase = "http://127.0.0.1:" <> show javaPort
          state =
            ServerState
              { stateSessionToken = "test-token"
              , stateStartedAt = now
              , stateDefaultGameDir = Just gameDir
              , stateTasks = tasks
              , stateTaskHistoryPath = historyPath
              , stateTaskHandles = taskHandles
              , stateNextTaskId = nextTaskId
              , stateTaowaSessions = taowaSessions
              , stateEvents = events
              , stateHttpManager = manager
              , stateShutdown = pure ()
              }
      withRuntimeSources minecraftBase javaBase $ do
        layout <- mkLayout (Just gameDir)
        resolvedJava <-
          resolveAutoJavaPath
            state
            layout
            "26.1.2"
            (DownloadRuntimeOptions (Just 1) (Just 0) Nothing)
            (pure False)
            (\progress -> modifyMVar_ progressLabels (pure . (progressLabel progress :)))
        resolvedExists <- doesFileExist resolvedJava
        status <- checkJavaRuntime (JavaCheckRequest (Just resolvedJava))
        runtimes <- readManagedRuntimes appRoot
        labels <- readMVar progressLabels
        assertEqual "auto Java path downloads executable" True resolvedExists
        assertEqual "auto Java path returns Java 21" (Just 21) (javaResponseMajorVersion status)
        assertEqual "auto Java path writes managed runtime" [21] (map managedRuntimeFeatureVersion runtimes)
        assertEqual "auto Java path reports Java download progress" True (any ("Java 21 runtime" `isInfixOf`) labels)
  removeDirectoryRecursive root `catchAny` \_ -> pure ()

withFakeAdoptiumServer :: BL.ByteString -> String -> IO a -> IO a
withFakeAdoptiumServer archive checksumText action =
  testWithApplication (pure (fakeAdoptiumApp archive checksumText)) $ \port ->
    withAdoptiumEnv ("http://127.0.0.1:" <> show port) action

fakeAdoptiumApp :: BL.ByteString -> String -> Application
fakeAdoptiumApp archive checksumText request respond = do
  let path = BS8.unpack (rawPathInfo request)
  if ".sha256.txt" `isSuffixOf` path
    then respond (responseLBS status200 [(hContentType, "text/plain")] (BL8.pack checksumText))
    else respond (responseLBS status200 [(hContentType, "application/gzip")] archive)

withAdoptiumEnv :: String -> IO a -> IO a
withAdoptiumEnv base action =
  ( do
      setEnv "PANINO_ADOPTIUM_API_BASE" base
      setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
      action
  )
    `finally` do
      unsetEnv "PANINO_ADOPTIUM_API_BASE"
      unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"

withRuntimeSources :: String -> String -> IO a -> IO a
withRuntimeSources minecraftBase javaBase action =
  ( do
      setEnv "PANINO_MOJANG_META_BASE" minecraftBase
      setEnv "PANINO_ADOPTIUM_API_BASE" javaBase
      setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
      action
  )
    `finally` do
      unsetEnv "PANINO_MOJANG_META_BASE"
      unsetEnv "PANINO_ADOPTIUM_API_BASE"
      unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
