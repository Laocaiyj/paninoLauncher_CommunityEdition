{-# LANGUAGE OverloadedStrings #-}

module Panino.Runtime.Java.Install.Options
  ( downloadOptionsFromRuntime
  , javaMajorCompatible
  , normalizeProvider
  , runtimeArchCompatible
  ) where

import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Types (DownloadRuntimeOptions(..))
import Panino.Download.Manager
  ( DownloadOptions
  , downloadOptionsWithOverrides
  )

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
