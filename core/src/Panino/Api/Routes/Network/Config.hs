{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Network.Config
  ( effectiveNetworkConfigValue
  , proxyConfigured
  ) where

import Data.Aeson
  ( Value
  , object
  , (.=)
  )
import Data.Maybe
  ( listToMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Net.Http (metadataRetryCount)
import Panino.Net.Sources
  ( SourceEndpoint(..)
  , configuredBases
  , defaultSourceEndpoints
  , officialFallbackEnabled
  )
import System.Environment (lookupEnv)

effectiveNetworkConfigValue :: IO Value
effectiveNetworkConfigValue = do
  sourceProfile <- envText "PANINO_SOURCE_PROFILE" "official"
  fallbackEnabled <- officialFallbackEnabled
  retryCount <- metadataRetryCount
  endpoints <- traverse endpointSummary defaultSourceEndpoints
  proxy <- proxySummary
  pure $
    object
      [ "sourceProfile" .= sourceProfile
      , "officialFallback" .= fallbackEnabled
      , "metadataRetryCount" .= retryCount
      , "proxy" .= proxy
      , "endpoints" .= endpoints
      ]

endpointSummary :: SourceEndpoint -> IO Value
endpointSummary endpoint = do
  rawConfigured <- lookupEnv (sourceEnvVar endpoint)
  bases <- configuredBases (sourceEnvVar endpoint)
  pure $
    object
      [ "envVar" .= sourceEnvVar endpoint
      , "officialBase" .= sourceDefaultBase endpoint
      , "configured" .= maybe False (not . null) rawConfigured
      , "effectiveBases" .= bases
      ]

proxySummary :: IO Value
proxySummary = do
  values <- traverse envMaybe proxyEnvKeys
  let configured = mapMaybe id values
      selected = listToMaybe configured
  pure $
    object
      [ "configured" .= maybe False (const True) selected
      , "value" .= fmap redactProxy selected
      , "keys" .= [key | (key, Just _) <- zip proxyEnvKeys values]
      ]

proxyConfigured :: IO Bool
proxyConfigured = do
  values <- traverse lookupEnv proxyEnvKeys
  pure (any (maybe False (not . null)) values)

proxyEnvKeys :: [String]
proxyEnvKeys =
  [ "https_proxy"
  , "http_proxy"
  , "all_proxy"
  , "HTTPS_PROXY"
  , "HTTP_PROXY"
  , "ALL_PROXY"
  ]

envText :: String -> Text -> IO Text
envText key fallback = do
  value <- lookupEnv key
  pure $
    case value of
      Just text | not (null text) -> Text.pack text
      _ -> fallback

envMaybe :: String -> IO (Maybe String)
envMaybe key = do
  value <- lookupEnv key
  pure $
    case value of
      Just text | not (null text) -> Just text
      _ -> Nothing

redactProxy :: String -> String
redactProxy value =
  case breakAtScheme value of
    Nothing -> value
    Just (schemePrefix, authorityAndPath) ->
      case break (== '/') authorityAndPath of
        (authority, path)
          | '@' `elem` authority -> schemePrefix <> "***@" <> drop 1 (dropWhile (/= '@') authority) <> path
          | otherwise -> value

breakAtScheme :: String -> Maybe (String, String)
breakAtScheme value =
  case breakOn "://" value of
    Nothing -> Nothing
    Just (scheme, rest) -> Just (scheme <> "://", rest)

breakOn :: String -> String -> Maybe (String, String)
breakOn needle haystack =
  go "" haystack
  where
    go _ [] = Nothing
    go prefix rest
      | needle `isPrefixOfString` rest = Just (reverse prefix, drop (length needle) rest)
      | otherwise =
          case rest of
            char:remaining -> go (char : prefix) remaining

isPrefixOfString :: String -> String -> Bool
isPrefixOfString [] _ = True
isPrefixOfString _ [] = False
isPrefixOfString (expected:expectedRest) (actual:actualRest) =
  expected == actual && isPrefixOfString expectedRest actualRest
