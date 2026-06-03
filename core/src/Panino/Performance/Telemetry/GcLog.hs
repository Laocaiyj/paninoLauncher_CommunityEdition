{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.Telemetry.GcLog
  ( gcLogArguments
  , parseGcLogMetrics
  ) where

import Data.Char
  ( isDigit
  , isSpace
  )
import Data.List
  ( sort
  , tails
  )
import Data.Maybe (mapMaybe)
import qualified Data.Text as Text
import Panino.Performance.Telemetry.Types
  ( GcMetrics(..)
  , emptyGcMetrics
  )

gcLogArguments :: Int -> FilePath -> [String]
gcLogArguments javaMajor logPath
  | javaMajor >= 9 =
      [ "-Xlog:gc*:file=" <> logPath <> ":time,uptime,level,tags:filecount=3,filesize=8M"
      ]
  | javaMajor == 8 =
      [ "-Xloggc:" <> logPath
      , "-XX:+PrintGCDetails"
      , "-XX:+PrintGCDateStamps"
      ]
  | otherwise = []

parseGcLogMetrics :: FilePath -> String -> GcMetrics
parseGcLogMetrics logPath content =
  emptyGcMetrics
    { gcLogEnabled = True
    , gcLogPath = Just logPath
    , gcPauseCount = length pauses
    , gcPauseP50Ms = percentile 0.50 pauses
    , gcPauseP95Ms = percentile 0.95 pauses
    , gcPauseP99Ms = percentile 0.99 pauses
    , gcPauseMaxMs = case pauses of
        [] -> Nothing
        values -> Just (maximum values)
    }
  where
    pauses = sort (mapMaybe pauseMs (lines content))

pauseMs :: String -> Maybe Double
pauseMs line =
  case mapMaybe suffixPauseValue (tails pauseSegment) of
    value:_ -> Just value
    [] -> Nothing
  where
    raw = Text.pack line
    (_, rest) = Text.breakOn "Pause" raw
    pauseSegment =
      if Text.null rest
        then line
        else Text.unpack (Text.drop 5 rest)

suffixPauseValue :: String -> Maybe Double
suffixPauseValue text
  | "ms" `prefix` rest = readDouble numberText
  | "s" `prefix` rest = (* 1000) <$> readDouble numberText
  | otherwise = Nothing
  where
    trimmed = dropWhile isSpace text
    numberText = takeWhile isNumberChar trimmed
    rest = dropWhile isSpace (drop (length numberText) trimmed)

prefix :: String -> String -> Bool
prefix expected actual =
  Text.pack expected `Text.isPrefixOf` Text.pack actual

isNumberChar :: Char -> Bool
isNumberChar char =
  isDigit char || char == '.'

readDouble :: String -> Maybe Double
readDouble value =
  case reads value of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing

percentile :: Double -> [Double] -> Maybe Double
percentile _ [] = Nothing
percentile quantile values =
  Just (values !! index)
  where
    count = length values
    index = max 0 (min (count - 1) (ceiling (quantile * fromIntegral count) - 1))
