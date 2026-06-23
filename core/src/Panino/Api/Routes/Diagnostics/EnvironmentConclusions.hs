{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Diagnostics.EnvironmentConclusions
  ( ReportConclusion(..)
  , compatibilityConclusion
  , conclusionIsOk
  , conclusionNotBlocking
  , javaResolutionConclusion
  , javaArchitectureMatches
  , javaRuleConclusion
  , memoryConclusionWithRecommendation
  ) where

import Data.Char (toLower)
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Routes.Diagnostics.EnvironmentContext
  ( EnvironmentReportContext(..)
  , environmentRequiredJavaMajor
  )
import Panino.Content.Local.Types (JavaCheckResponse(..))
import Panino.Runtime.Java.Types (JavaRuntimeResolveResponse(..))
import System.Info (arch)

data ReportConclusion = ReportConclusion
  { conclusionStatus :: Text
  , conclusionActions :: [Text]
  } deriving (Eq, Show)

javaRuleConclusion :: EnvironmentReportContext -> JavaCheckResponse -> ReportConclusion
javaRuleConclusion context java
  | not (javaResponseAvailable java) =
      ReportConclusion
        "blocking"
        ["Install Java " <> Text.pack (show (fromMaybe 21 requiredMajor)) <> "+ or set a custom Java executable in Settings."]
  | Just required <- requiredMajor
  , maybe True (< required) (javaResponseMajorVersion java) =
      ReportConclusion
        "blocking"
        ["Select a Java " <> Text.pack (show required) <> "+ runtime for this Minecraft version."]
  | javaArchitectureMatches java == Just False =
      ReportConclusion
        "warning"
        ["Use a Java runtime that matches the macOS CPU architecture to avoid Rosetta overhead."]
  | otherwise =
      ReportConclusion "ok" []
  where
    requiredMajor = environmentRequiredJavaMajor context

javaResolutionConclusion :: JavaRuntimeResolveResponse -> ReportConclusion
javaResolutionConclusion response =
  case resolveResponseStatus response of
    "ready" ->
      ReportConclusion "ok" []
    "downloadable" ->
      ReportConclusion
        "blocking"
        ["Download Java " <> Text.pack (show (resolveResponseRequiredMajorVersion response)) <> " before launch."]
    "missing" ->
      ReportConclusion
        "blocking"
        ["Choose or download Java " <> Text.pack (show (resolveResponseRequiredMajorVersion response)) <> "."]
    "incompatible" ->
      ReportConclusion
        "blocking"
        (nonEmptyActions ["Select a matching Java runtime."] (resolveResponseBlockingReasons response))
    "blocked" ->
      ReportConclusion
        "blocking"
        (nonEmptyActions ["Fix Java runtime permissions or provider access."] (resolveResponseBlockingReasons response))
    _ ->
      ReportConclusion "warning" (resolveResponseWarnings response)

nonEmptyActions :: [Text] -> [Text] -> [Text]
nonEmptyActions fallback values
  | null values = fallback
  | otherwise = values

javaArchitectureMatches :: JavaCheckResponse -> Maybe Bool
javaArchitectureMatches java =
  architectureMatches (Text.pack arch) <$> javaResponseArchitecture java

memoryConclusionWithRecommendation :: Maybe Int64 -> Maybe Int -> Int -> ReportConclusion
memoryConclusionWithRecommendation systemBytes configuredMb recommended =
  case configuredMb of
    Nothing ->
      ReportConclusion "warning" ["Set an instance memory value so launch diagnostics can validate it before start."]
    Just configured
      | configured < recommended ->
          ReportConclusion
            "warning"
            ["Increase memory to at least " <> Text.pack (show recommended) <> " MB for this version family."]
      | Just total <- systemMb
      , configured > max recommended (total * 3 `div` 4) ->
          ReportConclusion
            "warning"
            ["Lower the configured memory so macOS and the launcher keep enough free RAM."]
      | otherwise ->
          ReportConclusion "ok" []
  where
    systemMb = fromIntegral . (`div` (1024 * 1024)) <$> systemBytes

compatibilityConclusion :: EnvironmentReportContext -> ReportConclusion
compatibilityConclusion context =
  case environmentContextLoader context of
    Nothing ->
      ReportConclusion "ok" []
    Just loader
      | normalizeLoader loader `elem` supportedLoaders ->
          ReportConclusion "ok" []
      | otherwise ->
          ReportConclusion
            "blocking"
            ["Select a supported loader: Fabric, Quilt, Forge, NeoForge, Iris, Oculus, or Vanilla."]
  where
    supportedLoaders =
      [ "vanilla"
      , "fabric"
      , "quilt"
      , "forge"
      , "neoforge"
      , "iris"
      , "oculus"
      , "none"
      ]

conclusionIsOk :: ReportConclusion -> Bool
conclusionIsOk conclusion =
  conclusionStatus conclusion == "ok"

conclusionNotBlocking :: ReportConclusion -> Bool
conclusionNotBlocking conclusion =
  conclusionStatus conclusion /= "blocking"

architectureMatches :: Text -> Text -> Bool
architectureMatches systemArchitecture javaArchitecture =
  normalized systemArchitecture == normalized javaArchitecture
  where
    normalized raw
      | value `elem` ["aarch64", "arm64"] = "arm64"
      | value `elem` ["x86_64", "amd64"] = "x86_64"
      | otherwise = value
      where
        value = Text.pack (map toLower (Text.unpack raw))

normalizeLoader :: Text -> Text
normalizeLoader =
  Text.toLower . Text.replace "-" "" . Text.replace "_" ""
