{-# LANGUAGE OverloadedStrings #-}

module Integration.GraphicsTuning
  ( assertGraphicsOptionsTuning
  , assertGraphicsTuningApiHelpers
  , assertGraphicsTuningRecommendations
  ) where

import qualified Data.ByteString.Char8 as BS8
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import Data.Time.Clock
  ( addUTCTime
  , getCurrentTime
  )
import Panino.Api.Routes.GraphicsTuning
  ( readGraphicsTuningForEnvironment
  , writeGraphicsTuningDiagnostics
  , writeGraphicsTuningRollbackEvent
  )
import Panino.Core.Types (gameDirFromPath)
import Panino.Graphics.Tuning.Options
  ( applyOptionsPatch
  , applyOptionsPatchToFile
  , backupOptionsFile
  , buildOptionsPatch
  , buildOptionsPatchForVersion
  , duplicateOptionWarnings
  , graphicsOptionSkippedReason
  , isGraphicsOptionsWritableKey
  , optionValue
  , parseMinecraftOptions
  , renderMinecraftOptions
  , rollbackOptionsFile
  )
import Panino.Graphics.Tuning.Recommend
  ( recommendGraphicsTuning
  )
import Panino.Graphics.Tuning.Types
  ( GraphicsHardwareTier(..)
  , GraphicsTuningProfile(..)
  , GraphicsTuningRequest(..)
  , GraphicsTuningWarning(..)
  , OptionsBackup(..)
  , OptionsPatch(..)
  , OptionsPatchChange(..)
  , ResolvedGraphicsTuning(..)
  , RetinaPolicy(..)
  , defaultGraphicsTuningRequest
  , inferGraphicsHardwareTier
  )
import Panino.Platform.Hardware
  ( hardwareMemoryTier
  , hardwareTierFromChipName
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , getTemporaryDirectory
  , removeDirectoryRecursive
  )
import System.Exit
  ( exitFailure
  )
import System.FilePath ((</>))
import TestSupport
  ( assertEqual
  , catchAny
  , safePathSuffix
  )

graphicsWarningCodes :: ResolvedGraphicsTuning -> [Text.Text]
graphicsWarningCodes =
  map graphicsWarningCode . resolvedGraphicsWarnings

assertGraphicsOptionsTuning :: IO ()
assertGraphicsOptionsTuning = do
  let rawOptions =
        Text.intercalate
          "\r\n"
          [ "renderDistance:24"
          , "simulationDistance:12"
          , "maxFps:260"
          , "unknownPaninoKeeps:this must stay"
          , "renderDistance:32"
          ]
          <> "\r\n"
      parsed = parseMinecraftOptions rawOptions
  assertEqual "graphics options preserve CRLF render" rawOptions (renderMinecraftOptions parsed)
  assertEqual "graphics options last duplicate wins" (Just "32") (optionValue "renderDistance" parsed)
  assertEqual
    "graphics options duplicate warning"
    ["duplicate_options_key"]
    (map graphicsWarningCode (duplicateOptionWarnings parsed))
  assertEqual "graphics hardware tier max" GraphicsHardwareMMaxUltra (inferGraphicsHardwareTier (Just "Apple M3 Max"))
  assertEqual "graphics hardware tier pro" GraphicsHardwareMPro (inferGraphicsHardwareTier (Just "Apple M2 Pro"))
  assertEqual "platform hardware tier pro" GraphicsHardwareMPro (hardwareTierFromChipName (Just "Apple M3 Pro"))
  assertEqual "platform hardware tier max" GraphicsHardwareMMaxUltra (hardwareTierFromChipName (Just "Apple M2 Ultra"))
  assertEqual "platform hardware memory tier 32" "24/32GB" (hardwareMemoryTier (Just (32 * 1024 * 1024 * 1024)))
  assertEqual "graphics whitelist allows render distance" True (isGraphicsOptionsWritableKey "renderDistance")
  assertEqual "graphics whitelist blocks fov" False (isGraphicsOptionsWritableKey "fov")
  assertEqual "graphics old version skips simulation distance" (Just "unsupported_version") (graphicsOptionSkippedReason (Just "1.16.5") "simulationDistance")

  let patch =
        buildOptionsPatch
          (Just "/tmp/options.txt")
          (Map.fromList
            [ ("renderDistance", "16")
            , ("fov", "90")
            , ("mipmapLevels", "4")
            , ("maxFps", "260")
            ])
          parsed
  assertEqual
    "graphics patch statuses"
    [("fov", "skipped"), ("maxFps", "keep"), ("mipmapLevels", "create"), ("renderDistance", "change")]
    [(optionsPatchChangeKey change, optionsPatchChangeStatus change) | change <- optionsPatchChanges patch]
  let oldVersionPatch =
        buildOptionsPatchForVersion
          (Just "1.16.5")
          Nothing
          (Map.fromList [("simulationDistance", "8")])
          parsed
  assertEqual
    "graphics version capability returns skipped reason"
    [("simulationDistance", "skipped", "unsupported_version")]
    [(optionsPatchChangeKey change, optionsPatchChangeStatus change, optionsPatchChangeReason change) | change <- optionsPatchChanges oldVersionPatch]
  let patched = applyOptionsPatch patch parsed
  assertEqual "graphics patch updates last render distance" (Just "16") (optionValue "renderDistance" patched)
  assertEqual "graphics patch keeps unknown options" True ("unknownPaninoKeeps:this must stay" `Text.isInfixOf` renderMinecraftOptions patched)
  assertEqual "graphics patch keeps max fps" (Just "260") (optionValue "maxFps" patched)

  tempDir <- getTemporaryDirectory
  now <- getCurrentTime
  let optionsDir = tempDir </> ("panino-graphics-options-test-" <> safePathSuffix (show now))
      optionsPath = optionsDir </> "options.txt"
  removeDirectoryRecursive optionsDir `catchAny` \_ -> pure ()
  createDirectoryIfMissing True optionsDir
  BS8.writeFile optionsPath "renderDistance:24\nsimulationDistance:12\nmaxFps:260\n"
  backup <- backupOptionsFile now optionsPath
  assertEqual "graphics stable backup created" True (optionsBackupCreated backup && maybe False (not . null) (optionsBackupStablePath backup))
  fileBackup <- applyOptionsPatchToFile (addUTCTime 1 now) optionsPath patch
  assertEqual "graphics apply backup created" True (optionsBackupCreated fileBackup)
  appliedBytes <- BS8.readFile optionsPath
  assertEqual "graphics apply writes render distance" True ("renderDistance:16" `BS8.isInfixOf` appliedBytes)
  case optionsBackupStablePath backup of
    Nothing -> do
      putStrLn "FAIL: graphics rollback stable backup missing"
      exitFailure
    Just stableBackup -> do
      _ <- rollbackOptionsFile (addUTCTime 2 now) optionsPath stableBackup
      restoredBytes <- BS8.readFile optionsPath
      assertEqual "graphics rollback restores stable backup" True ("renderDistance:24" `BS8.isInfixOf` restoredBytes)
  removeDirectoryRecursive optionsDir `catchAny` \_ -> pure ()

assertGraphicsTuningRecommendations :: IO ()
assertGraphicsTuningRecommendations = do
  let currentOptions =
        parseMinecraftOptions $
          Text.intercalate "\n"
            [ "renderDistance:24"
            , "simulationDistance:12"
            , "maxFps:260"
            , "enableVsync:true"
            , "renderClouds:\"true\""
            , "particles:0"
            , "entityDistanceScaling:1.0"
            , "mipmapLevels:4"
            , "graphicsMode:1"
            ]
            <> "\n"
      baseM =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMBase
            , graphicsRequestDisplayScale = Just 2
            , graphicsRequestIsBuiltinDisplay = Just True
            , graphicsRequestRefreshRate = Just 60
            }
          currentOptions
  assertEqual "graphics M base retina uses balanced retina" BalancedRetina (resolvedGraphicsRetinaPolicy baseM)
  assertEqual "graphics M base render conservative" (Just "8") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions baseM))
  assertEqual "graphics M base flags render distance too high" True ("render_distance_too_high" `elem` graphicsWarningCodes baseM)
  assertEqual "graphics M base flags retina pressure" True ("retina_gpu_pressure" `elem` graphicsWarningCodes baseM)

  let proBalanced =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMPro
            , graphicsRequestRefreshRate = Just 120
            }
          currentOptions
  assertEqual "graphics M Pro balanced render" (Just "14") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions proBalanced))
  assertEqual "graphics M Pro balanced fps" (Just "120") (Map.lookup "maxFps" (resolvedGraphicsRecommendedOptions proBalanced))

  let proExternal5k =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMPro
            , graphicsRequestIsBuiltinDisplay = Just False
            , graphicsRequestDisplayWidth = Just 5120
            , graphicsRequestDisplayHeight = Just 2880
            }
          currentOptions
  assertEqual "graphics external 5K lowers render" (Just "12") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions proExternal5k))
  assertEqual "graphics external 5K warns" True ("retina_gpu_pressure" `elem` graphicsWarningCodes proExternal5k)

  let maxClarity =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMMaxUltra
            , graphicsRequestProfile = GraphicsProfileClarity
            , graphicsRequestDisplayScale = Just 2
            , graphicsRequestIsBuiltinDisplay = Just True
            , graphicsRequestRefreshRate = Just 144
            }
          currentOptions
  assertEqual "graphics Max clarity render" (Just "24") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions maxClarity))
  assertEqual "graphics Max high refresh fps" (Just "144") (Map.lookup "maxFps" (resolvedGraphicsRecommendedOptions maxClarity))
  assertEqual "graphics Max high refresh can disable vsync" (Just "false") (Map.lookup "enableVsync" (resolvedGraphicsRecommendedOptions maxClarity))
  assertEqual "graphics clarity maps to Retina quality" RetinaQuality (resolvedGraphicsRetinaPolicy maxClarity)

  let largePack =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMPro
            , graphicsRequestModCount = Just 180
            }
          currentOptions
  assertEqual "graphics large pack lowers render" (Just "10") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions largePack))
  assertEqual "graphics large pack caps simulation" (Just "8") (Map.lookup "simulationDistance" (resolvedGraphicsRecommendedOptions largePack))
  assertEqual "graphics large pack decreases particles" (Just "1") (Map.lookup "particles" (resolvedGraphicsRecommendedOptions largePack))

  let shaderPack =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMMaxUltra
            , graphicsRequestShaderEnabled = True
            , graphicsRequestResourcePackScale = Just "high-128x"
            }
          currentOptions
  assertEqual "graphics shader lowers render" (Just "12") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions shaderPack))
  assertEqual "graphics shader warns" True ("shader_pressure" `elem` graphicsWarningCodes shaderPack)

  let historySnapshot =
        baseM
          { resolvedGraphicsWarnings =
              [ GraphicsTuningWarning
                  { graphicsWarningCode = "low_fps"
                  , graphicsWarningSeverity = "warning"
                  , graphicsWarningMessage = "low fps"
                  , graphicsWarningAction = Just "switchPerformance"
                  }
              ]
          }
      historyAdvice =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMPro
            , graphicsRequestPreviousSnapshot = Just historySnapshot
            }
          currentOptions
  assertEqual "graphics history only recommends" True ("previous_low_fps" `elem` graphicsWarningCodes historyAdvice)
  assertEqual "graphics recommendation is pure dry run" (Just "24") (optionValue "renderDistance" currentOptions)

  let manualOverride =
        recommendGraphicsTuning
          defaultGraphicsTuningRequest
            { graphicsRequestHardwareTier = GraphicsHardwareMBase
            , graphicsRequestProfile = GraphicsProfileManual
            , graphicsRequestManualOverrides = Map.fromList [("renderDistance", "11"), ("maxFps", "75")]
            }
          currentOptions
  assertEqual "graphics manual override render" (Just "11") (Map.lookup "renderDistance" (resolvedGraphicsRecommendedOptions manualOverride))
  assertEqual "graphics manual override fps" (Just "75") (Map.lookup "maxFps" (resolvedGraphicsRecommendedOptions manualOverride))

assertGraphicsTuningApiHelpers :: IO ()
assertGraphicsTuningApiHelpers = do
  tempDir <- getTemporaryDirectory
  now <- getCurrentTime
  let gameDir = tempDir </> ("panino-graphics-api-test-" <> safePathSuffix (show now))
      optionsPath = gameDir </> "options.txt"
  removeDirectoryRecursive gameDir `catchAny` \_ -> pure ()
  createDirectoryIfMissing True gameDir
  BS8.writeFile optionsPath "renderDistance:24\nsimulationDistance:12\nmaxFps:260\nenableVsync:true\nrenderClouds:\"true\"\nparticles:0\nentityDistanceScaling:1.0\nmipmapLevels:4\ngraphicsMode:1\n"
  resolved <-
    readGraphicsTuningForEnvironment
      defaultGraphicsTuningRequest
        { graphicsRequestGameDir = gameDirFromPath gameDir
        , graphicsRequestHardwareTier = GraphicsHardwareMBase
        , graphicsRequestDisplayScale = Just 2
        , graphicsRequestIsBuiltinDisplay = Just True
        }
      gameDir
  assertEqual "graphics API helper sets patch path" (Just optionsPath) (optionsPatchPath (resolvedGraphicsOptionsPatch resolved))
  assertEqual "graphics API helper recommends changes" True (resolvedGraphicsCanApply resolved)
  beforeApply <- BS8.readFile optionsPath
  assertEqual "graphics API resolve is dry run" True ("renderDistance:24" `BS8.isInfixOf` beforeApply)
  backup <- applyOptionsPatchToFile (addUTCTime 1 now) optionsPath (resolvedGraphicsOptionsPatch resolved)
  let backupPath =
        case optionsBackupTimestampPath backup of
          Just path -> Just path
          Nothing -> optionsBackupStablePath backup
      resolvedWithBackup =
        resolved
          { resolvedGraphicsBackupPath = backupPath
          , resolvedGraphicsCanRollback = backupPath /= Nothing
          }
  writeGraphicsTuningDiagnostics gameDir resolvedWithBackup backup
  appliedBytes <- BS8.readFile optionsPath
  assertEqual "graphics API apply writes options" True ("renderDistance:8" `BS8.isInfixOf` appliedBytes)
  tuningDiagnosticExists <- doesFileExist (gameDir </> "downloads" </> "graphics-tuning.json")
  patchDiagnosticExists <- doesFileExist (gameDir </> "downloads" </> "graphics-options-patch.txt")
  assertEqual "graphics API writes tuning diagnostic" True tuningDiagnosticExists
  assertEqual "graphics API writes patch diagnostic" True patchDiagnosticExists
  tuningDiagnostic <- BS8.readFile (gameDir </> "downloads" </> "graphics-tuning.json")
  patchDiagnostic <- BS8.readFile (gameDir </> "downloads" </> "graphics-options-patch.txt")
  assertEqual "graphics tuning diagnostic includes backup" True ("\"backup\"" `BS8.isInfixOf` tuningDiagnostic)
  assertEqual "graphics patch diagnostic includes change" True ("renderDistance" `BS8.isInfixOf` patchDiagnostic)
  case optionsBackupStablePath backup of
    Nothing -> do
      putStrLn "FAIL: graphics API rollback stable backup missing"
      exitFailure
    Just stableBackup -> do
      rollbackBackup <- rollbackOptionsFile (addUTCTime 2 now) optionsPath stableBackup
      writeGraphicsTuningRollbackEvent gameDir stableBackup rollbackBackup
      restoredBytes <- BS8.readFile optionsPath
      assertEqual "graphics API rollback restores options" True ("renderDistance:24" `BS8.isInfixOf` restoredBytes)
      eventLog <- BS8.readFile (gameDir </> "downloads" </> "graphics-tuning-events.jsonl")
      assertEqual "graphics API rollback writes event log" True ("\"action\":\"rollback\"" `BS8.isInfixOf` eventLog)
  removeDirectoryRecursive gameDir `catchAny` \_ -> pure ()

  let missingGameDir = tempDir </> ("panino-graphics-missing-options-test-" <> safePathSuffix (show now))
      missingOptionsPath = missingGameDir </> "options.txt"
  removeDirectoryRecursive missingGameDir `catchAny` \_ -> pure ()
  createDirectoryIfMissing True missingGameDir
  missingResolved <-
    readGraphicsTuningForEnvironment
      defaultGraphicsTuningRequest
        { graphicsRequestGameDir = gameDirFromPath missingGameDir
        , graphicsRequestHardwareTier = GraphicsHardwareMBase
        }
      missingGameDir
  assertEqual "graphics missing options can create initial file" True (resolvedGraphicsCanApply missingResolved)
  assertEqual
    "graphics missing options patch creates keys"
    True
    (any ((== "create") . optionsPatchChangeStatus) (optionsPatchChanges (resolvedGraphicsOptionsPatch missingResolved)))
  missingBackup <- applyOptionsPatchToFile (addUTCTime 3 now) missingOptionsPath (resolvedGraphicsOptionsPatch missingResolved)
  assertEqual "graphics missing options has no backup error" Nothing (optionsBackupError missingBackup)
  createdOptions <- BS8.readFile missingOptionsPath
  assertEqual "graphics missing options writes initial file" True ("renderDistance:" `BS8.isInfixOf` createdOptions)
  removeDirectoryRecursive missingGameDir `catchAny` \_ -> pure ()
