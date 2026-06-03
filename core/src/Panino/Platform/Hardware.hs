{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Platform.Hardware
  ( HardwareProfile(..)
  , detectGraphicsHardwareTier
  , detectHardwareProfile
  , hardwareMemoryTier
  , hardwareTierFromChipName
  , systemMemoryBytes
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Graphics.Tuning.Types
  ( GraphicsHardwareTier(..)
  , inferGraphicsHardwareTier
  )
import System.Exit (ExitCode(..))
import System.Info (arch)
import System.Process
  ( CreateProcess
  , proc
  , readCreateProcessWithExitCode
  )

data HardwareProfile = HardwareProfile
  { hardwareProfileChipName :: Maybe Text
  , hardwareProfileChipTier :: GraphicsHardwareTier
  , hardwareProfileMemoryBytes :: Maybe Int64
  , hardwareProfileMemoryTier :: Text
  } deriving (Eq, Show)

instance ToJSON HardwareProfile where
  toJSON profile =
    object
      [ "chipName" .= hardwareProfileChipName profile
      , "chipTier" .= hardwareProfileChipTier profile
      , "memoryBytes" .= hardwareProfileMemoryBytes profile
      , "memoryTier" .= hardwareProfileMemoryTier profile
      ]

detectHardwareProfile :: IO HardwareProfile
detectHardwareProfile = do
  chipName <- detectChipName
  memory <- systemMemoryBytes
  pure
    HardwareProfile
      { hardwareProfileChipName = chipName
      , hardwareProfileChipTier = hardwareTierFromChipName chipName
      , hardwareProfileMemoryBytes = memory
      , hardwareProfileMemoryTier = hardwareMemoryTier memory
      }

detectGraphicsHardwareTier :: IO GraphicsHardwareTier
detectGraphicsHardwareTier =
  hardwareProfileChipTier <$> detectHardwareProfile

hardwareTierFromChipName :: Maybe Text -> GraphicsHardwareTier
hardwareTierFromChipName chipName =
  case inferGraphicsHardwareTier chipName of
    GraphicsHardwareUnknown
      | arch == "aarch64" || arch == "arm64" -> GraphicsHardwareMBase
    tier -> tier

hardwareMemoryTier :: Maybe Int64 -> Text
hardwareMemoryTier Nothing = "unknown"
hardwareMemoryTier (Just bytes)
  | gb <= 8 = "8GB"
  | gb <= 16 = "16GB"
  | gb <= 32 = "24/32GB"
  | otherwise = "64GB+"
  where
    gb =
      bytes `div` (1024 * 1024 * 1024)

systemMemoryBytes :: IO (Maybe Int64)
systemMemoryBytes = do
  result <- tryReadProcess (proc "sysctl" ["-n", "hw.memsize"])
  pure (parseInt64 =<< result)

detectChipName :: IO (Maybe Text)
detectChipName = do
  brand <- readSysctlText "machdep.cpu.brand_string"
  case brand of
    Just value -> pure (Just value)
    Nothing -> readSysctlText "hw.model"

readSysctlText :: String -> IO (Maybe Text)
readSysctlText key =
  fmap Text.pack <$> tryReadProcess (proc "sysctl" ["-n", key])

tryReadProcess :: CreateProcess -> IO (Maybe String)
tryReadProcess process = do
  result <- try (readCreateProcessWithExitCode process "")
  pure $ case result of
    Right (ExitSuccess, stdoutText, _) ->
      nonEmpty (trim stdoutText)
    Right _ ->
      Nothing
    Left (_ :: SomeException) ->
      Nothing

parseInt64 :: String -> Maybe Int64
parseInt64 value =
  case reads value of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing

nonEmpty :: String -> Maybe String
nonEmpty value
  | null value = Nothing
  | otherwise = Just value

trim :: String -> String
trim =
  Text.unpack . Text.strip . Text.pack
