{-# LANGUAGE OverloadedStrings #-}

module Integration.ApiJson
  ( assertApiJsonContracts
  ) where

import Data.Aeson
  ( decode
  , eitherDecode
  , encode
  )
import Integration.LoaderShaderFixtureServer
  ( modrinthProjectJson
  )
import Panino.Api.Types
  ( DownloadRuntimeOptions(..)
  , InstallRequest(..)
  , LaunchRequest(..)
  , TaskProgress(..)
  )
import Panino.Content.Online.Modrinth
  ( ModrinthProjectResponse(..)
  )
import TestSupport (assertEqual)

assertApiJsonContracts :: IO ()
assertApiJsonContracts = do
  assertEqual
    "modrinth project endpoint accepts id"
    (Right "sodium")
    (modrinthProjectId <$> eitherDecode modrinthProjectJson)
  assertEqual
    "install request parses nested download runtime options"
    (Right (DownloadRuntimeOptions (Just 7) (Just 2) Nothing))
    (installRequestDownload <$> eitherDecode "{\"version\":\"1.20.1\",\"download\":{\"concurrency\":7,\"retryCount\":2}}")
  assertEqual
    "install request keeps legacy download fields"
    (Right (DownloadRuntimeOptions (Just 4) (Just 1) Nothing))
    (installRequestDownload <$> eitherDecode "{\"version\":\"1.20.1\",\"concurrency\":4,\"retryCount\":1}")
  assertEqual
    "install request parses strategy"
    (Right (DownloadRuntimeOptions (Just 48) (Just 4) (Just "fast")))
    (installRequestDownload <$> eitherDecode "{\"version\":\"1.20.1\",\"download\":{\"concurrency\":48,\"retryCount\":4,\"strategy\":\"fast\"}}")
  assertEqual
    "launch request parses JVM args and window size"
    (Right (["-Dpanino.test=true"], Just 1280, Just 720))
    ( (\request -> (launchRequestJvmArgs request, launchRequestWindowWidth request, launchRequestWindowHeight request))
        <$> eitherDecode "{\"version\":\"1.20.1\",\"jvmArgs\":[\"-Dpanino.test=true\"],\"windowWidth\":1280,\"windowHeight\":720}"
    )
  let progress =
        TaskProgress
          { taskProgressTaskId = "task-1"
          , taskProgressPhaseId = "minecraft"
          , taskProgressPhaseTitle = "Download Minecraft files"
          , taskProgressPhaseIndex = 2
          , taskProgressPhaseCount = 5
          , taskProgressPhasePercent = Just 50
          , taskProgressOverallPercent = Just 40
          , taskProgressCompletedJobs = 4
          , taskProgressTotalJobs = 8
          , taskProgressCompletedBytes = 1024
          , taskProgressTotalBytes = 2048
          , taskProgressSpeedBytesPerSecond = 512
          , taskProgressMovingAverageSpeedBytesPerSecond = 640
          , taskProgressEtaSeconds = Just 2
          , taskProgressCurrentLabel = "libraries/example.jar"
          , taskProgressActiveWorkers = 2
          , taskProgressRetryCount = 1
          , taskProgressSourceHost = Just "https://libraries.minecraft.net"
          , taskProgressHosts = []
          , taskProgressThrottleReason = Just "stable"
          , taskProgressMultipart = Nothing
          }
  assertEqual
    "task progress json roundtrip"
    (Just progress)
    (decode (encode progress))
