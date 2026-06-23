{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Diagnostics.EnvironmentContext
  ( EnvironmentReportContext(..)
  , environmentReportContext
  , environmentRequiredJavaMajor
  ) where

import Control.Applicative ((<|>))
import qualified Data.ByteString.Char8 as BS8
import Data.Char (isDigit)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Types.URI (urlDecode)
import Network.Wai
  ( Request
  , queryString
  )
import Panino.Graphics.Tuning.Types
  ( GraphicsHardwareTier(..)
  , GraphicsTuningProfile
  , parseGraphicsHardwareTier
  , parseGraphicsTuningProfile
  )
import Panino.Launch.Tuning.Types
  ( JvmTuningPolicy
  , MemoryPolicy
  , parseJvmTuningPolicy
  , parseMemoryPolicy
  )

data EnvironmentReportContext = EnvironmentReportContext
  { environmentContextGameDir :: Maybe FilePath
  , environmentContextVersion :: Maybe Text
  , environmentContextLoader :: Maybe Text
  , environmentContextLoaderVersion :: Maybe Text
  , environmentContextMemoryMb :: Maybe Int
  , environmentContextMemoryPolicy :: Maybe MemoryPolicy
  , environmentContextJvmProfile :: Maybe JvmTuningPolicy
  , environmentContextModCount :: Maybe Int
  , environmentContextResourcePackCount :: Maybe Int
  , environmentContextResourcePackScale :: Maybe Text
  , environmentContextShaderPackCount :: Maybe Int
  , environmentContextCustomMemoryMb :: Maybe Int
  , environmentContextCustomJvmArgs :: [Text]
  , environmentContextGraphicsProfile :: Maybe GraphicsTuningProfile
  , environmentContextGraphicsHardwareTier :: Maybe GraphicsHardwareTier
  , environmentContextDisplayScale :: Maybe Double
  , environmentContextDisplayWidth :: Maybe Int
  , environmentContextDisplayHeight :: Maybe Int
  , environmentContextRefreshRate :: Maybe Int
  , environmentContextIsBuiltinDisplay :: Maybe Bool
  , environmentContextShaderEnabled :: Bool
  } deriving (Eq, Show)

environmentReportContext :: Request -> EnvironmentReportContext
environmentReportContext request =
  let shaderPackCount = queryInt "shaderPackCount"
   in EnvironmentReportContext
        { environmentContextGameDir = textToString <$> queryText "gameDir"
        , environmentContextVersion = queryText "version" <|> queryText "minecraftVersion"
        , environmentContextLoader = queryText "loader"
        , environmentContextLoaderVersion = queryText "loaderVersion"
        , environmentContextMemoryMb = queryInt "memoryMb" <|> queryInt "configuredMemoryMb"
        , environmentContextMemoryPolicy = queryText "memoryPolicy" >>= parseMemoryPolicy
        , environmentContextJvmProfile =
            (queryText "jvmProfile" <|> queryText "policy") >>= parseJvmTuningPolicy
        , environmentContextModCount = queryInt "modCount"
        , environmentContextResourcePackCount = queryInt "resourcePackCount"
        , environmentContextResourcePackScale = queryText "resourcePackScale"
        , environmentContextShaderPackCount = shaderPackCount
        , environmentContextCustomMemoryMb = queryInt "customMemoryMb"
        , environmentContextCustomJvmArgs = maybe [] Text.words (queryText "customJvmArgs")
        , environmentContextGraphicsProfile =
            (queryText "graphicsProfile" <|> queryText "requestedProfile") >>= parseGraphicsTuningProfile
        , environmentContextGraphicsHardwareTier =
            (queryText "graphicsHardwareTier" <|> queryText "hardwareTier") >>= parseGraphicsHardwareTier
        , environmentContextDisplayScale = queryDouble "displayScale"
        , environmentContextDisplayWidth = queryInt "displayWidth"
        , environmentContextDisplayHeight = queryInt "displayHeight"
        , environmentContextRefreshRate = queryInt "refreshRate"
        , environmentContextIsBuiltinDisplay = queryBool "isBuiltinDisplay"
        , environmentContextShaderEnabled =
            fromMaybe (maybe False (> 0) shaderPackCount) (queryBool "shaderEnabled")
        }
  where
    queryText key = do
      value <- lookup (BS8.pack key) (queryString request)
      Text.strip . Text.pack . BS8.unpack . urlDecode True <$> value
    queryInt key =
      queryText key >>= readIntText
    queryDouble key =
      queryText key >>= readDoubleText
    queryBool key =
      queryText key >>= readBoolText
    textToString = Text.unpack

environmentRequiredJavaMajor :: EnvironmentReportContext -> Maybe Int
environmentRequiredJavaMajor =
  minecraftRequiredJavaMajor . environmentContextVersion

minecraftRequiredJavaMajor :: Maybe Text -> Maybe Int
minecraftRequiredJavaMajor Nothing =
  Nothing
minecraftRequiredJavaMajor (Just version)
  | Just release <- parseReleaseVersion version =
      Just
        ( if release >= (1, 20, 5)
            then 21
            else if release >= (1, 18, 0)
              then 17
              else if release >= (1, 17, 0)
                then 16
                else 8
        )
  | Just snapshotYear <- parseSnapshotYear version =
      Just (if snapshotYear >= 24 then 21 else if snapshotYear >= 21 then 17 else 8)
  | otherwise =
      Nothing

parseReleaseVersion :: Text -> Maybe (Int, Int, Int)
parseReleaseVersion value =
  case map readIntText (Text.splitOn "." value) of
    Just major : Just minor : patchMaybe : _ ->
      Just (major, minor, fromMaybe 0 patchMaybe)
    _ -> Nothing

parseSnapshotYear :: Text -> Maybe Int
parseSnapshotYear value =
  let prefix = Text.takeWhile isDigit value
      suffix = Text.dropWhile isDigit value
   in if Text.toLower (Text.take 1 suffix) == "w"
        then readIntText prefix
        else Nothing

readIntText :: Text -> Maybe Int
readIntText value =
  case reads (Text.unpack (Text.takeWhile isDigit value)) of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing

readDoubleText :: Text -> Maybe Double
readDoubleText value =
  case reads (Text.unpack value) of
    [(parsed, "")] -> Just parsed
    _ -> Nothing

readBoolText :: Text -> Maybe Bool
readBoolText value =
  case Text.toLower (Text.strip value) of
    "true" -> Just True
    "1" -> Just True
    "yes" -> Just True
    "false" -> Just False
    "0" -> Just False
    "no" -> Just False
    _ -> Nothing
