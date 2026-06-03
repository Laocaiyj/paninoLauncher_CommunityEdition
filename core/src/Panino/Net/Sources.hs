{-# LANGUAGE OverloadedStrings #-}

module Panino.Net.Sources
  ( SourceEndpoint(..)
  , configuredBases
  , configuredEndpoint
  , defaultSourceEndpoints
  , officialFallbackEnabled
  , resolveSourceUrl
  , resolveSourceUrls
  , sourceUrl
  ) where

import Data.List (isPrefixOf)
import Data.Char (toLower)
import System.Environment (lookupEnv)

data SourceEndpoint = SourceEndpoint
  { sourceEnvVar :: String
  , sourceDefaultBase :: String
  } deriving (Eq, Show)

defaultSourceEndpoints :: [SourceEndpoint]
defaultSourceEndpoints =
  [ SourceEndpoint "PANINO_MOJANG_META_BASE" "https://piston-meta.mojang.com"
  , SourceEndpoint "PANINO_MOJANG_RESOURCES_BASE" "https://resources.download.minecraft.net"
  , SourceEndpoint "PANINO_MOJANG_LIBRARIES_BASE" "https://libraries.minecraft.net"
  , SourceEndpoint "PANINO_ADOPTIUM_API_BASE" "https://api.adoptium.net"
  , SourceEndpoint "PANINO_FABRIC_META_BASE" "https://meta.fabricmc.net"
  , SourceEndpoint "PANINO_FABRIC_MAVEN_BASE" "https://maven.fabricmc.net"
  , SourceEndpoint "PANINO_QUILT_META_BASE" "https://meta.quiltmc.org"
  , SourceEndpoint "PANINO_FORGE_FILES_BASE" "https://files.minecraftforge.net"
  , SourceEndpoint "PANINO_FORGE_MAVEN_BASE" "https://maven.minecraftforge.net"
  , SourceEndpoint "PANINO_NEOFORGE_MAVEN_BASE" "https://maven.neoforged.net/releases"
  , SourceEndpoint "PANINO_MODRINTH_API_BASE" "https://api.modrinth.com"
  , SourceEndpoint "PANINO_MODRINTH_CDN_BASE" "https://cdn.modrinth.com"
  , SourceEndpoint "PANINO_CURSEFORGE_API_BASE" "https://api.curseforge.com"
  ]

sourceUrl :: String -> String -> IO String
sourceUrl envVar path = do
  base <- head <$> configuredBases envVar
  pure (trimTrailingSlash base <> ensureLeadingSlash path)

resolveSourceUrl :: String -> IO String
resolveSourceUrl url = head <$> resolveSourceUrls url

resolveSourceUrls :: String -> IO [String]
resolveSourceUrls url = do
  endpoints <- traverse configuredEndpoint defaultSourceEndpoints
  keepOfficial <- officialFallbackEnabled
  let replacements = replaceFirst endpoints url
  pure
    ( if null replacements
        then [url]
        else dedupe (replacements <> [url | keepOfficial])
    )

configuredEndpoint :: SourceEndpoint -> IO (String, [String])
configuredEndpoint endpoint = do
  bases <- configuredBases (sourceEnvVar endpoint)
  pure (sourceDefaultBase endpoint, bases)

configuredBases :: String -> IO [String]
configuredBases envVar = do
  configured <- lookupEnv envVar
  let values =
        case configured of
          Just raw ->
            [base | Just base <- map nonEmpty (splitComma raw)]
          Nothing -> []
  pure
    ( if null values
        then [defaultBase envVar]
        else map trimTrailingSlash values
    )

defaultBase :: String -> String
defaultBase envVar =
  case [sourceDefaultBase endpoint | endpoint <- defaultSourceEndpoints, sourceEnvVar endpoint == envVar] of
    base:_ -> base
    [] -> ""

officialFallbackEnabled :: IO Bool
officialFallbackEnabled = do
  configured <- lookupEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
  pure
    ( case map toLower <$> configured of
        Just value | value `elem` ["1", "true", "yes", "on"] -> False
        _ -> True
    )

replaceFirst :: [(String, [String])] -> String -> [String]
replaceFirst [] _ = []
replaceFirst ((original, replacements):rest) url
  | original `isPrefixOf` url =
      [ replacement <> drop (length original) url
      | replacement <- replacements
      , replacement /= original
      ]
  | otherwise = replaceFirst rest url

dedupe :: Eq a => [a] -> [a]
dedupe =
  go []
  where
    go _ [] = []
    go seen (value:rest)
      | value `elem` seen = go seen rest
      | otherwise = value : go (value:seen) rest

splitComma :: String -> [String]
splitComma value =
  case break (== ',') value of
    (segment, []) -> [segment]
    (segment, _comma:rest) -> segment : splitComma rest

nonEmpty :: String -> Maybe String
nonEmpty value =
  case trimTrailingSlash value of
    "" -> Nothing
    trimmed -> Just trimmed

trimTrailingSlash :: String -> String
trimTrailingSlash value =
  case reverse value of
    '/':rest -> reverse rest
    _ -> value

ensureLeadingSlash :: String -> String
ensureLeadingSlash "" = ""
ensureLeadingSlash path@('/':_) = path
ensureLeadingSlash path = '/' : path
