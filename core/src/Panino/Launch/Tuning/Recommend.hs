{-# LANGUAGE OverloadedStrings #-}

module Panino.Launch.Tuning.Recommend
  ( inferPackScale
  , recommendJvmTuning
  , recommendedMemoryFor
  , tuningJvmArguments
  ) where

import Data.Int (Int64)
import Data.List
  ( isPrefixOf
  , nub
  )
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Launch.Tuning.Types
  ( JvmTuningAction(..)
  , JvmTuningPolicy(..)
  , JvmTuningRequest(..)
  , JvmTuningWarning(..)
  , MemoryPolicy(..)
  , PackScale(..)
  , ResolvedJvmTuning(..)
  , renderPackScale
  )
import Panino.Performance.Profile.Types
  ( AdaptiveApplyMode(..)
  , PerformanceConfidence(..)
  , estimatedEvidence
  )
import Panino.Runtime.Java.Requirements (fallbackJavaMajorVersion)

recommendJvmTuning :: JvmTuningRequest -> ResolvedJvmTuning
recommendJvmTuning request =
  ResolvedJvmTuning
    { resolvedTuningRequestedPolicy = requestedPolicy
    , resolvedTuningEffectivePolicy = effectivePolicy
    , resolvedTuningMemoryPolicy = memoryPolicy
    , resolvedTuningPackScale = packScale
    , resolvedTuningSystemMemoryMb = systemMemoryMb
    , resolvedTuningRecommendedMemoryMb = recommendedMb
    , resolvedTuningXmsMb = xmsMb
    , resolvedTuningXmxMb = xmxMb
    , resolvedTuningJvmArgs = finalJvmArgs
    , resolvedTuningProfileName = profileName effectivePolicy
    , resolvedTuningSummary = summaryText effectivePolicy javaMajor xmxMb warnings
    , resolvedTuningConfidence = ConfidenceEstimated
    , resolvedTuningEvidence =
        [ estimatedEvidence "source" "static JVM baseline"
        , estimatedEvidence "packScale" (renderPackScale packScale)
        , estimatedEvidence "systemMemoryMb" (maybe "unknown" (Text.pack . show) systemMemoryMb)
        ]
    , resolvedTuningRollbackRef = tuningRequestInstanceId request >>= \ident -> Just ("jvm-" <> ident)
    , resolvedTuningApplyMode = ApplyAsk
    , resolvedTuningWarnings = warnings
    , resolvedTuningActions = actions
    , resolvedTuningPrimaryAction = listToMaybe actions
    , resolvedTuningCanRollback = memoryPolicy == MemoryPolicyCustom || not (null customArgs)
    }
  where
    requestedPolicy = tuningRequestPolicy request
    memoryPolicy =
      if tuningRequestMemoryPolicy request == MemoryPolicyCustom || tuningRequestCustomMemoryMb request /= Nothing
        then MemoryPolicyCustom
        else MemoryPolicyAuto
    systemMemoryMb = bytesToMb <$> tuningRequestSystemMemoryBytes request
    packScale = fromMaybe (inferPackScale request) (tuningRequestPackScale request)
    javaMajor =
      tuningRequestJavaMajorVersion request
        <|> (fallbackJavaMajorVersion <$> tuningRequestMinecraftVersion request)
    effectivePolicy =
      case requestedPolicy of
        JvmTuningExperimentalZgc
          | maybe False supportsZgcJava javaMajor -> JvmTuningExperimentalZgc
          | otherwise -> JvmTuningAuto
        _ -> requestedPolicy
    recommendedMb =
      recommendedMemoryFor systemMemoryMb packScale effectivePolicy
    customMb = tuningRequestCustomMemoryMb request
    xmxMb =
      case (memoryPolicy, customMb) of
        (MemoryPolicyCustom, Just value) -> clampMemoryMb value
        _ -> recommendedMb
    xmsMb =
      if effectivePolicy == JvmTuningLargePack || xmxMb >= 7168
        then 1024
        else 512
    profileArgs = tuningJvmArguments effectivePolicy xmsMb xmxMb
    customArgs = tuningRequestCustomJvmArgs request
    customConflicts = conflictingJvmArgs customArgs
    finalJvmArgs = profileArgs <> filter (not . isConflictingJvmArg) customArgs
    warnings =
      concat
        [ [ unsupportedZgcWarning | requestedPolicy == JvmTuningExperimentalZgc && effectivePolicy /= JvmTuningExperimentalZgc ]
        , [ largePackOnLowMemoryWarning | packScale == PackScaleLargePack && maybe False (<= 8192) systemMemoryMb ]
        , customMemoryWarnings recommendedMb systemMemoryMb customMb
        , nativeMemoryWarnings
        , gcOverheadWarnings
        , [ customJvmArgsWarning customConflicts | not (null customConflicts) ]
        ]
    actions =
      concat
        [ [reduceMemoryAction recommendedMb | hasWarning "memory_too_high" warnings || hasWarning "native_memory_pressure" warnings]
        , [increaseMemoryAction recommendedMb | hasWarning "memory_too_low" warnings]
        , [restoreAutoAction | hasWarning "custom_jvm_args_conflict" warnings]
        , [restoreAutoAction | hasWarning "experimental_zgc_unsupported" warnings || hasWarning "gc_overhead" warnings]
        ]
    nativeMemoryWarnings =
      [ nativeMemoryWarning
      | tuningRequestSawNativeOutOfMemory request
      ]
    gcOverheadWarnings =
      [ gcOverheadWarning
      | tuningRequestSawGcOverhead request
      ]

inferPackScale :: JvmTuningRequest -> PackScale
inferPackScale request
  | tuningRequestModpackIsLarge request = PackScaleLargePack
  | tuningRequestSawHeapOutOfMemory request = PackScaleLargePack
  | maybe False (>= 151) (tuningRequestModCount request) = PackScaleLargePack
  | maybe False (>= 41) (tuningRequestModCount request) = PackScaleMediumPack
  | maybe False (> 0) (tuningRequestShaderPackCount request) = PackScaleMediumPack
  | maybe False (> 10) (tuningRequestResourcePackCount request) = PackScaleMediumPack
  | moddedLoader && tuningRequestModCount request == Nothing = PackScaleMediumPack
  | otherwise = PackScaleVanillaLight
  where
    moddedLoader =
      maybe False (`notElem` ["", "vanilla", "none"]) $
        Text.toLower . Text.strip <$> tuningRequestLoader request

recommendedMemoryFor :: Maybe Int -> PackScale -> JvmTuningPolicy -> Int
recommendedMemoryFor systemMemoryMb packScale policy =
  clampMemoryMb (min (baseMemoryMb tier packScale policy) safetyCap)
  where
    tier = deviceTier systemMemoryMb
    safetyCap = safetyMemoryCapMb systemMemoryMb

tuningJvmArguments :: JvmTuningPolicy -> Int -> Int -> [Text]
tuningJvmArguments policy xmsMb xmxMb =
  [ "-Xms" <> Text.pack (show xmsMb) <> "M"
  , "-Xmx" <> Text.pack (show xmxMb) <> "M"
  ]
    <> case policy of
      JvmTuningExperimentalZgc ->
        [ "-XX:+UseZGC"
        ]
      JvmTuningLowMemory ->
        [ "-XX:+UseG1GC"
        , "-XX:+ParallelRefProcEnabled"
        , "-XX:+DisableExplicitGC"
        , "-XX:MaxGCPauseMillis=120"
        ]
      JvmTuningLargePack ->
        g1Args 100
      JvmTuningBatterySaver ->
        g1Args 120
      JvmTuningAuto ->
        g1Args 80
      JvmTuningCustom ->
        g1Args 80

g1Args :: Int -> [Text]
g1Args maxPauseMs =
  [ "-XX:+UseG1GC"
  , "-XX:+ParallelRefProcEnabled"
  , "-XX:+DisableExplicitGC"
  , "-XX:+UseStringDeduplication"
  , "-XX:MaxGCPauseMillis=" <> Text.pack (show maxPauseMs)
  ]

data DeviceTier
  = Tier8Gb
  | Tier16Gb
  | Tier32Gb
  | Tier64Gb
  deriving (Eq, Show)

deviceTier :: Maybe Int -> DeviceTier
deviceTier Nothing = Tier16Gb
deviceTier (Just totalMb)
  | totalMb <= 8192 = Tier8Gb
  | totalMb <= 16384 = Tier16Gb
  | totalMb <= 32768 = Tier32Gb
  | otherwise = Tier64Gb

baseMemoryMb :: DeviceTier -> PackScale -> JvmTuningPolicy -> Int
baseMemoryMb tier scale policy =
  case policy of
    JvmTuningLargePack -> tableMemory tier PackScaleLargePack Upper
    JvmTuningLowMemory -> tableMemory tier scale Lower
    JvmTuningBatterySaver -> tableMemory tier scale Lower
    _ -> tableMemory tier scale Preferred

data RangePoint = Lower | Preferred | Upper

tableMemory :: DeviceTier -> PackScale -> RangePoint -> Int
tableMemory tier scale point =
  pick point $
    case (tier, scale) of
      (Tier8Gb, PackScaleVanillaLight) -> (3072, 3584, 4096)
      (Tier8Gb, PackScaleMediumPack) -> (4096, 4608, 5120)
      (Tier8Gb, PackScaleLargePack) -> (4096, 5120, 5120)
      (Tier16Gb, PackScaleVanillaLight) -> (4096, 4096, 4096)
      (Tier16Gb, PackScaleMediumPack) -> (5120, 6144, 7168)
      (Tier16Gb, PackScaleLargePack) -> (7168, 8192, 8192)
      (Tier32Gb, PackScaleVanillaLight) -> (4096, 5120, 6144)
      (Tier32Gb, PackScaleMediumPack) -> (6144, 7168, 8192)
      (Tier32Gb, PackScaleLargePack) -> (8192, 10240, 12288)
      (Tier64Gb, PackScaleVanillaLight) -> (6144, 6144, 6144)
      (Tier64Gb, PackScaleMediumPack) -> (8192, 10240, 12288)
      (Tier64Gb, PackScaleLargePack) -> (12288, 16384, 16384)
      (_, PackScaleUnknown) -> (4096, 4096, 4096)
  where
    pick Lower (lower, _, _) = lower
    pick Preferred (_, preferred, _) = preferred
    pick Upper (_, _, upper) = upper

safetyMemoryCapMb :: Maybe Int -> Int
safetyMemoryCapMb Nothing = 16384
safetyMemoryCapMb (Just totalMb) =
  clampMemoryMb (min (totalMb - reservedMb) (totalMb * 3 `div` 4))
  where
    reservedMb = max 4096 (totalMb `div` 4)

clampMemoryMb :: Int -> Int
clampMemoryMb =
  alignTo512 . min 16384 . max 1024

alignTo512 :: Int -> Int
alignTo512 value =
  max 512 (((value + 511) `div` 512) * 512)

bytesToMb :: Int64 -> Int
bytesToMb bytes =
  fromIntegral (bytes `div` (1024 * 1024))

customMemoryWarnings :: Int -> Maybe Int -> Maybe Int -> [JvmTuningWarning]
customMemoryWarnings recommendedMb systemMemoryMb customMb =
  case customMb of
    Nothing -> []
    Just value ->
      concat
        [ [memoryTooLowWarning recommendedMb | value < recommendedMb]
        , [memoryTooHighWarning recommendedMb | value > safetyMemoryCapMb systemMemoryMb]
        ]

conflictingJvmArgs :: [Text] -> [Text]
conflictingJvmArgs =
  nub . filter isConflictingJvmArg

isConflictingJvmArg :: Text -> Bool
isConflictingJvmArg arg =
  any (`isPrefixOf` raw) prefixes
  where
    raw = Text.unpack arg
    prefixes =
      [ "-Xmx"
      , "-Xms"
      , "-XX:+UseG1GC"
      , "-XX:-UseG1GC"
      , "-XX:+UseZGC"
      , "-XX:-UseZGC"
      , "-XX:MaxRAMPercentage"
      , "-XX:InitialRAMPercentage"
      ]

unsupportedZgcWarning :: JvmTuningWarning
unsupportedZgcWarning =
  JvmTuningWarning
    { tuningWarningCode = "experimental_zgc_unsupported"
    , tuningWarningSeverity = "warning"
    , tuningWarningMessage = "Experimental low-pause GC requires a Java runtime that supports ZGC."
    , tuningWarningAction = Just "restoreAuto"
    }

largePackOnLowMemoryWarning :: JvmTuningWarning
largePackOnLowMemoryWarning =
  JvmTuningWarning
    { tuningWarningCode = "large_pack_not_recommended"
    , tuningWarningSeverity = "warning"
    , tuningWarningMessage = "Large modpacks are not recommended on 8 GB Apple Silicon machines."
    , tuningWarningAction = Just "lowMemory"
    }

memoryTooLowWarning :: Int -> JvmTuningWarning
memoryTooLowWarning recommendedMb =
  JvmTuningWarning
    { tuningWarningCode = "memory_too_low"
    , tuningWarningSeverity = "warning"
    , tuningWarningMessage = "This instance should use at least " <> formatMemory recommendedMb <> "."
    , tuningWarningAction = Just "increaseMemory"
    }

memoryTooHighWarning :: Int -> JvmTuningWarning
memoryTooHighWarning recommendedMb =
  JvmTuningWarning
    { tuningWarningCode = "memory_too_high"
    , tuningWarningSeverity = "warning"
    , tuningWarningMessage = "Lower memory to " <> formatMemory recommendedMb <> " so macOS, GPU memory, and cache have room."
    , tuningWarningAction = Just "reduceMemory"
    }

customJvmArgsWarning :: [Text] -> JvmTuningWarning
customJvmArgsWarning conflicts =
  JvmTuningWarning
    { tuningWarningCode = "custom_jvm_args_conflict"
    , tuningWarningSeverity = "warning"
    , tuningWarningMessage = "Custom JVM arguments override Panino tuning and were ignored: " <> Text.intercalate ", " conflicts
    , tuningWarningAction = Just "restoreAuto"
    }

nativeMemoryWarning :: JvmTuningWarning
nativeMemoryWarning =
  JvmTuningWarning
    { tuningWarningCode = "native_memory_pressure"
    , tuningWarningSeverity = "warning"
    , tuningWarningMessage = "The last launch showed native memory pressure; lowering heap can leave more memory for the system and graphics."
    , tuningWarningAction = Just "reduceMemory"
    }

gcOverheadWarning :: JvmTuningWarning
gcOverheadWarning =
  JvmTuningWarning
    { tuningWarningCode = "gc_overhead"
    , tuningWarningSeverity = "warning"
    , tuningWarningMessage = "The last launch spent too much time in GC; use the recommended profile before adding custom JVM arguments."
    , tuningWarningAction = Just "restoreAuto"
    }

reduceMemoryAction :: Int -> JvmTuningAction
reduceMemoryAction memoryMb =
  JvmTuningAction
    { tuningActionId = "reduceMemory"
    , tuningActionTitle = "Lower to " <> formatMemory memoryMb
    , tuningActionMemoryMb = Just memoryMb
    }

increaseMemoryAction :: Int -> JvmTuningAction
increaseMemoryAction memoryMb =
  JvmTuningAction
    { tuningActionId = "increaseMemory"
    , tuningActionTitle = "Increase to " <> formatMemory memoryMb
    , tuningActionMemoryMb = Just memoryMb
    }

restoreAutoAction :: JvmTuningAction
restoreAutoAction =
  JvmTuningAction
    { tuningActionId = "restoreAuto"
    , tuningActionTitle = "Restore automatic tuning"
    , tuningActionMemoryMb = Nothing
    }

hasWarning :: Text -> [JvmTuningWarning] -> Bool
hasWarning code =
  any ((== code) . tuningWarningCode)

profileName :: JvmTuningPolicy -> Text
profileName policy =
  case policy of
    JvmTuningAuto -> "Automatic Recommendation"
    JvmTuningLargePack -> "Large Modpack"
    JvmTuningLowMemory -> "Low Memory Protection"
    JvmTuningBatterySaver -> "Battery Saver"
    JvmTuningExperimentalZgc -> "Experimental Low Pause"
    JvmTuningCustom -> "Custom"

summaryText :: JvmTuningPolicy -> Maybe Int -> Int -> [JvmTuningWarning] -> Text
summaryText policy javaMajor memoryMb warnings =
  profileName policy
    <> " · "
    <> maybe "Java auto" (\major -> "Java " <> Text.pack (show major)) javaMajor
    <> " · "
    <> formatMemory memoryMb
    <> if null warnings then "" else " · Needs attention"

formatMemory :: Int -> Text
formatMemory memoryMb
  | memoryMb `mod` 1024 == 0 = Text.pack (show (memoryMb `div` 1024)) <> " GB"
  | otherwise = Text.pack (show memoryMb) <> " MB"

supportsZgcJava :: Int -> Bool
supportsZgcJava major =
  major >= 17

listToMaybe :: [a] -> Maybe a
listToMaybe [] = Nothing
listToMaybe (value:_) = Just value

(<|>) :: Maybe a -> Maybe a -> Maybe a
(<|>) (Just value) _ = Just value
(<|>) Nothing fallback = fallback
