{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.Modrinth
  ( ModrinthFile(..)
  , ModrinthVersion(..)
  , ResolvedModrinthMod(..)
  , resolveModrinthProject
  , resolveModrinthProjectWithVersion
  , safeFileName
  , selectPreferredModrinthVersion
  , stableResolvedModrinthMods
  ) where

import Control.Concurrent.Async (mapConcurrently)
import Control.Monad (when)
import Data.Aeson
  ( FromJSON(..)
  , withObject
  , (.:)
  , (.:?)
  )
import Data.Aeson.Types ((.!=))
import Data.Int (Int64)
import Data.List (sortOn)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  )
import Data.Ord (Down(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Http
  ( coreRequest
  , fetchJson
  )
import Panino.Core.Types
  ( ProjectId
  , Url
  , VersionId
  , projectIdFromText
  , projectIdText
  , urlText
  , versionIdFromText
  , versionIdText
  )
import Panino.CoreLogic.Determinism (stableSortOnText)

data ResolvedModrinthMod = ResolvedModrinthMod
  { resolvedModrinthProject :: ProjectId
  , resolvedModrinthVersion :: VersionId
  , resolvedModrinthFile :: ModrinthFile
  } deriving (Eq, Show)

data ModrinthVisitKey
  = ModrinthVisitProject ProjectId
  | ModrinthVisitVersion VersionId
  deriving (Eq, Ord, Show)

resolveModrinthProject :: Manager -> Text -> Text -> [Text] -> Text -> IO [ResolvedModrinthMod]
resolveModrinthProject manager minecraftVersion loader visited project =
  resolveModrinthProjectWithVersion manager minecraftVersion loader visited project Nothing

resolveModrinthProjectWithVersion :: Manager -> Text -> Text -> [Text] -> Text -> Maybe Text -> IO [ResolvedModrinthMod]
resolveModrinthProjectWithVersion manager minecraftVersion loader visited project maybeVersionId = do
  projectId <- parseProjectId project
  versionId <- traverse parseVersionId maybeVersionId
  visitedKeys <- traverse (fmap ModrinthVisitProject . parseProjectId) visited
  resolveModrinthProjectTyped manager minecraftVersion loader visitedKeys projectId versionId

resolveModrinthProjectTyped :: Manager -> Text -> Text -> [ModrinthVisitKey] -> ProjectId -> Maybe VersionId -> IO [ResolvedModrinthMod]
resolveModrinthProjectTyped manager minecraftVersion loader visited project maybeVersionId
  | ModrinthVisitProject project `elem` visited = pure []
  | otherwise = do
      selectedVersion <-
        case maybeVersionId of
          Just versionId -> do
            version <- modrinthVersionById manager versionId
            if modrinthVersionProjectId version == project
              then pure version
              else fail ("shader_release_not_found: Modrinth release " <> Text.unpack (versionIdText versionId) <> " does not belong to " <> Text.unpack (projectIdText project))
          Nothing -> do
            versions <- modrinthVersions manager project minecraftVersion loader
            case selectPreferredModrinthVersion minecraftVersion loader versions of
              Just version -> pure version
              Nothing ->
                fail
                  ( "shader_release_not_found: no Modrinth "
                      <> Text.unpack (projectIdText project)
                      <> " release found for Minecraft "
                      <> Text.unpack minecraftVersion
                      <> " and loader "
                      <> Text.unpack loader
                  )
      resolveModrinthVersion manager minecraftVersion loader (ModrinthVisitProject project : visited) project selectedVersion

resolveModrinthVersion :: Manager -> Text -> Text -> [ModrinthVisitKey] -> ProjectId -> ModrinthVersion -> IO [ResolvedModrinthMod]
resolveModrinthVersion manager minecraftVersion loader visited project version
  | ModrinthVisitVersion (modrinthVersionId version) `elem` visited = pure []
  | otherwise = do
      when (not (modrinthVersionCompatible minecraftVersion loader version)) $
        fail
          ( "shader_release_not_found: Modrinth "
              <> Text.unpack (projectIdText project)
              <> " release "
              <> Text.unpack (versionIdText (modrinthVersionId version))
              <> " is not compatible with Minecraft "
              <> Text.unpack minecraftVersion
              <> " and loader "
              <> Text.unpack loader
          )
      selectedFile <-
        case preferredFile version of
          Just file -> pure file
          Nothing -> fail ("shader_file_missing_download: Modrinth release has no downloadable file: " <> Text.unpack (projectIdText project))
      let visited' = ModrinthVisitVersion (modrinthVersionId version) : visited
      dependencies <-
        concat
          <$> mapConcurrently
            (resolveRequiredDependency manager minecraftVersion loader visited')
            (requiredDependencies (modrinthVersionDependencies version))
      pure (dependencies <> [ResolvedModrinthMod project (modrinthVersionId version) selectedFile])

resolveRequiredDependency :: Manager -> Text -> Text -> [ModrinthVisitKey] -> ModrinthDependency -> IO [ResolvedModrinthMod]
resolveRequiredDependency manager minecraftVersion loader visited dependency =
  case modrinthDependencyVersionId dependency of
    Just versionId
      | ModrinthVisitVersion versionId `elem` visited -> pure []
      | otherwise -> do
          version <- modrinthVersionById manager versionId
          let project = fromMaybe (modrinthVersionProjectId version) (modrinthDependencyProjectId dependency)
          if modrinthVersionCompatible minecraftVersion loader version
            then resolveModrinthVersion manager minecraftVersion loader visited project version
            else
              case modrinthDependencyProjectId dependency of
                Just projectId ->
                  resolveModrinthProjectTyped manager minecraftVersion loader (ModrinthVisitVersion versionId : visited) projectId Nothing
                Nothing ->
                  fail
                    ( "shader_dependency_unresolved: dependency version "
                        <> Text.unpack (versionIdText versionId)
                        <> " is not compatible with Minecraft "
                        <> Text.unpack minecraftVersion
                        <> " and loader "
                        <> Text.unpack loader
                        <> ", and no project_id was provided"
                    )
    Nothing ->
      case modrinthDependencyProjectId dependency of
        Just project -> resolveModrinthProjectTyped manager minecraftVersion loader visited project Nothing
        Nothing -> fail "shader_dependency_unresolved: Modrinth required dependency is missing project_id and version_id"

requiredDependencies :: [ModrinthDependency] -> [ModrinthDependency]
requiredDependencies =
  stableSortOnText modrinthDependencyKey . filter ((== "required") . Text.toLower . modrinthDependencyType)

stableResolvedModrinthMods :: [ResolvedModrinthMod] -> [ResolvedModrinthMod]
stableResolvedModrinthMods =
  stableSortOnText resolvedModrinthKey . foldr collect []
  where
    collect item acc
      | resolvedModrinthKey item `elem` map resolvedModrinthKey acc = acc
      | otherwise = item : acc

resolvedModrinthKey :: ResolvedModrinthMod -> Text
resolvedModrinthKey item =
  Text.intercalate
    "|"
    [ projectIdText (resolvedModrinthProject item)
    , modrinthFileName file
    , urlText (modrinthFileUrl file)
    , fromMaybe "" (Map.lookup "sha1" (modrinthFileHashes file))
    ]
  where
    file = resolvedModrinthFile item

modrinthVersions :: Manager -> ProjectId -> Text -> Text -> IO [ModrinthVersion]
modrinthVersions manager project minecraftVersion loader = do
  request <-
    coreRequest
      ( "https://api.modrinth.com/v2/project/"
          <> Text.unpack (projectIdText project)
          <> "/version?game_versions=%5B%22"
          <> Text.unpack minecraftVersion
          <> "%22%5D&loaders=%5B%22"
          <> Text.unpack (modrinthLoaderName loader)
          <> "%22%5D"
      )
      []
  fetchJson manager request

modrinthVersionById :: Manager -> VersionId -> IO ModrinthVersion
modrinthVersionById manager versionId =
  fetchJson manager
    =<< coreRequest
      ("https://api.modrinth.com/v2/version/" <> Text.unpack (versionIdText versionId))
      []

modrinthLoaderName :: Text -> Text
modrinthLoaderName "neoforge" = "neoforge"
modrinthLoaderName other = Text.toLower other

data ModrinthVersion = ModrinthVersion
  { modrinthVersionId :: VersionId
  , modrinthVersionProjectId :: ProjectId
  , modrinthVersionGameVersions :: [Text]
  , modrinthVersionLoaders :: [Text]
  , modrinthVersionName :: Text
  , modrinthVersionNumber :: Text
  , modrinthVersionType :: Text
  , modrinthVersionDatePublished :: Maybe Text
  , modrinthVersionFeatured :: Bool
  , modrinthVersionFiles :: [ModrinthFile]
  , modrinthVersionDependencies :: [ModrinthDependency]
  } deriving (Eq, Show)

instance FromJSON ModrinthVersion where
  parseJSON =
    withObject "ModrinthVersion" $ \obj ->
      ModrinthVersion
        <$> obj .: "id"
        <*> obj .: "project_id"
        <*> obj .:? "game_versions" .!= []
        <*> obj .:? "loaders" .!= []
        <*> obj .:? "name" .!= ""
        <*> obj .:? "version_number" .!= ""
        <*> obj .:? "version_type" .!= ""
        <*> obj .:? "date_published"
        <*> obj .:? "featured" .!= False
        <*> obj .:? "files" .!= []
        <*> obj .:? "dependencies" .!= []

data ModrinthDependency = ModrinthDependency
  { modrinthDependencyProjectId :: Maybe ProjectId
  , modrinthDependencyVersionId :: Maybe VersionId
  , modrinthDependencyType :: Text
  } deriving (Eq, Show)

instance FromJSON ModrinthDependency where
  parseJSON =
    withObject "ModrinthDependency" $ \obj ->
      ModrinthDependency
        <$> obj .:? "project_id"
        <*> obj .:? "version_id"
        <*> obj .:? "dependency_type" .!= "required"

data ModrinthFile = ModrinthFile
  { modrinthFileName :: Text
  , modrinthFileUrl :: Url
  , modrinthFilePrimary :: Bool
  , modrinthFileHashes :: Map Text Text
  , modrinthFileSize :: Maybe Int64
  } deriving (Eq, Show)

instance FromJSON ModrinthFile where
  parseJSON =
    withObject "ModrinthFile" $ \obj ->
      ModrinthFile
        <$> obj .: "filename"
        <*> obj .: "url"
        <*> obj .:? "primary" .!= False
        <*> obj .:? "hashes" .!= Map.empty
        <*> obj .:? "size"

preferredFile :: ModrinthVersion -> Maybe ModrinthFile
preferredFile version =
  case filter modrinthFilePrimary files of
    file:_ -> Just file
    [] -> listToMaybe files
  where
    files = stableSortOnText modrinthFileKey (modrinthVersionFiles version)

selectPreferredModrinthVersion :: Text -> Text -> [ModrinthVersion] -> Maybe ModrinthVersion
selectPreferredModrinthVersion minecraftVersion loader versions =
  listToMaybe (sortOn (modrinthVersionSelectionKey minecraftVersion loader) candidates)
  where
    candidates = filter (modrinthVersionCompatible minecraftVersion loader) versions

modrinthVersionSelectionKey :: Text -> Text -> ModrinthVersion -> (Int, Int, Int, Int, Down Text, Text, Text)
modrinthVersionSelectionKey minecraftVersion loader version =
  ( if modrinthVersionSupportsLoader loader version then 0 else 1
  , if modrinthVersionTextMatchesMinecraft minecraftVersion version then 0 else 1
  , modrinthReleaseRank (modrinthVersionType version)
  , if modrinthVersionFeatured version then 0 else 1
  , Down (fromMaybe "" (modrinthVersionDatePublished version))
  , projectIdText (modrinthVersionProjectId version)
  , versionIdText (modrinthVersionId version)
  )

modrinthVersionSupportsMinecraft :: Text -> ModrinthVersion -> Bool
modrinthVersionSupportsMinecraft minecraftVersion version =
  minecraftVersion `elem` modrinthVersionGameVersions version

modrinthVersionSupportsLoader :: Text -> ModrinthVersion -> Bool
modrinthVersionSupportsLoader loader version =
  modrinthLoaderName loader `elem` map Text.toLower (modrinthVersionLoaders version)

modrinthVersionCompatible :: Text -> Text -> ModrinthVersion -> Bool
modrinthVersionCompatible minecraftVersion loader version =
  modrinthVersionSupportsMinecraft minecraftVersion version
    && modrinthVersionSupportsLoader loader version

modrinthVersionTextMatchesMinecraft :: Text -> ModrinthVersion -> Bool
modrinthVersionTextMatchesMinecraft minecraftVersion version =
  any matchesVersionText haystacks
  where
    target = Text.toLower minecraftVersion
    targetMc = "mc" <> target
    haystacks =
      map Text.toLower $
        [ modrinthVersionName version
        , modrinthVersionNumber version
        ]
          <> map modrinthFileName (modrinthVersionFiles version)
    matchesVersionText value =
      targetMc `Text.isInfixOf` value || target `Text.isInfixOf` value

modrinthReleaseRank :: Text -> Int
modrinthReleaseRank value =
  case Text.toLower value of
    "release" -> 0
    "beta" -> 1
    "alpha" -> 2
    _ -> 3

modrinthDependencyKey :: ModrinthDependency -> Text
modrinthDependencyKey dependency =
  Text.intercalate
    "|"
    [ maybe "" projectIdText (modrinthDependencyProjectId dependency)
    , maybe "" versionIdText (modrinthDependencyVersionId dependency)
    , modrinthDependencyType dependency
    ]

modrinthFileKey :: ModrinthFile -> Text
modrinthFileKey file =
  Text.intercalate
    "|"
    [ modrinthFileName file
    , urlText (modrinthFileUrl file)
    , maybe "" (Text.pack . show) (modrinthFileSize file)
    , fromMaybe "" (Map.lookup "sha1" (modrinthFileHashes file))
    ]

parseProjectId :: Text -> IO ProjectId
parseProjectId value =
  maybe (fail "modrinth_project_id_empty") pure (projectIdFromText value)

parseVersionId :: Text -> IO VersionId
parseVersionId value =
  maybe (fail "modrinth_version_id_empty") pure (versionIdFromText value)

safeFileName :: Text -> Text
safeFileName value =
  Text.filter allowed value
  where
    allowed char =
      char == '.'
        || char == '-'
        || char == '_'
        || char == '+'
        || ('a' <= char && char <= 'z')
        || ('A' <= char && char <= 'Z')
        || ('0' <= char && char <= '9')
