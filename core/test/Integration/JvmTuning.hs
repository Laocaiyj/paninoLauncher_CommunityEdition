{-# LANGUAGE OverloadedStrings #-}

module Integration.JvmTuning
  ( assertJvmTuningRecommendations
  ) where

import Data.Aeson
  ( decode
  , eitherDecode
  , encode
  )
import Data.Int (Int64)
import Data.List (isPrefixOf)
import Data.Text (Text)
import Panino.Api.Types (LaunchRequest(..))
import Panino.Launch.Arguments
  ( LaunchProfile(..)
  , buildJavaArguments
  )
import Panino.Launch.Tuning.Recommend
  ( inferPackScale
  , recommendJvmTuning
  )
import Panino.Launch.Tuning.Types
  ( JvmTuningPolicy(..)
  , JvmTuningRequest(..)
  , JvmTuningWarning(..)
  , PackScale(..)
  , ResolvedJvmTuning(..)
  , defaultJvmTuningRequest
  )
import Panino.Minecraft.Install (classpathJars)
import TestFixtures
  ( testLayout
  , testVersionJson
  )
import TestSupport (assertEqual)

assertJvmTuningRecommendations :: IO ()
assertJvmTuningRecommendations = do
  let large16 =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestSystemMemoryBytes = Just (gbBytes 16)
            , tuningRequestJavaMajorVersion = Just 21
            , tuningRequestModCount = Just 180
            }
  assertEqual "jvm tuning infers large pack" PackScaleLargePack (resolvedTuningPackScale large16)
  assertEqual "16GB large pack recommends 8GB heap" 8192 (resolvedTuningXmxMb large16)
  assertEqual "large pack uses 1GB Xms" 1024 (resolvedTuningXmsMb large16)
  assertEqual "auto tuning uses G1GC" True ("-XX:+UseG1GC" `elem` resolvedTuningJvmArgs large16)

  let lowMemoryLarge =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestSystemMemoryBytes = Just (gbBytes 8)
            , tuningRequestModCount = Just 180
            }
  assertEqual "8GB large pack is capped to 4GB" 4096 (resolvedTuningXmxMb lowMemoryLarge)
  assertEqual "8GB large pack warns" True ("large_pack_not_recommended" `elem` warningCodes lowMemoryLarge)

  let customHigh =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestSystemMemoryBytes = Just (gbBytes 16)
            , tuningRequestCustomMemoryMb = Just 16384
            }
  assertEqual "custom high memory keeps explicit heap" 16384 (resolvedTuningXmxMb customHigh)
  assertEqual "custom high memory warns" True ("memory_too_high" `elem` warningCodes customHigh)

  let customLow =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestSystemMemoryBytes = Just (gbBytes 16)
            , tuningRequestModCount = Just 180
            , tuningRequestCustomMemoryMb = Just 512
            }
  assertEqual "custom low memory is clamped" 1024 (resolvedTuningXmxMb customLow)
  assertEqual "custom low memory warns" True ("memory_too_low" `elem` warningCodes customLow)

  let zgcUnsupported =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestPolicy = JvmTuningExperimentalZgc
            , tuningRequestJavaMajorVersion = Just 8
            }
  assertEqual "ZGC falls back on Java 8" JvmTuningAuto (resolvedTuningEffectivePolicy zgcUnsupported)
  assertEqual "ZGC fallback warns" True ("experimental_zgc_unsupported" `elem` warningCodes zgcUnsupported)

  let zgcSupported =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestPolicy = JvmTuningExperimentalZgc
            , tuningRequestJavaMajorVersion = Just 21
            }
  assertEqual "ZGC remains experimental on Java 21" JvmTuningExperimentalZgc (resolvedTuningEffectivePolicy zgcSupported)
  assertEqual "ZGC profile uses ZGC" True ("-XX:+UseZGC" `elem` resolvedTuningJvmArgs zgcSupported)

  let customConflict =
        recommendJvmTuning
          defaultJvmTuningRequest
            { tuningRequestCustomJvmArgs = ["-Xmx12G", "-Dpanino.test=true", "-XX:+UseZGC"]
            }
  assertEqual "custom conflicting Xmx is removed" False ("-Xmx12G" `elem` resolvedTuningJvmArgs customConflict)
  assertEqual "custom non-conflicting arg is kept" True ("-Dpanino.test=true" `elem` resolvedTuningJvmArgs customConflict)
  assertEqual "custom JVM arg conflict warns" True ("custom_jvm_args_conflict" `elem` warningCodes customConflict)
  let launchArgs =
        buildJavaArguments
          testLayout
          testVersionJson
          (classpathJars testLayout testVersionJson)
          LaunchProfile
            { profileVersion = "1.20.1"
            , profileMemoryMb = 4096
            , profileJavaPath = "java"
            , profileUsername = "Steve"
            , profileUuid = "00000000-0000-0000-0000-000000000000"
            , profileAccessToken = "0"
            , profileJvmArgs = []
            , profileJvmTuning = Just customConflict
            , profileWindowWidth = Nothing
            , profileWindowHeight = Nothing
            }
  assertEqual "effective launch args keep one Xmx" 1 (length (filter ("-Xmx" `isPrefixOf`) launchArgs))
  assertEqual "effective launch args drops conflicting custom ZGC" False ("-XX:+UseZGC" `elem` launchArgs)
  assertEqual
    "launch request parses JVM tuning fields"
    (Right (Just JvmTuningLargePack, ["-Dpanino.test=true"], Just 8192))
    ( (\request -> (launchRequestJvmProfile request, launchRequestCustomJvmArgs request, launchRequestCustomMemoryMb request))
        <$> eitherDecode "{\"version\":\"1.20.1\",\"memoryPolicy\":\"custom\",\"jvmProfile\":\"largePack\",\"customMemoryMb\":8192,\"customJvmArgs\":[\"-Dpanino.test=true\"]}"
    )

  assertEqual
    "jvm tuning json roundtrip"
    (Just large16)
    (decode (encode large16))
  assertEqual
    "jvm tuning medium pack inference"
    PackScaleMediumPack
    (inferPackScale defaultJvmTuningRequest { tuningRequestLoader = Just "fabric" })

gbBytes :: Int64 -> Int64
gbBytes gb =
  gb * 1024 * 1024 * 1024

warningCodes :: ResolvedJvmTuning -> [Text]
warningCodes =
  map tuningWarningCode . resolvedTuningWarnings
