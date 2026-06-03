{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Content.Local.Metadata
  ( metadataFor
  ) where

import Control.Applicative ((<|>))
import Control.Exception
  ( SomeException
  , catch
  )
import Control.Monad (guard)
import Data.Aeson
  ( FromJSON(..)
  , Result(..)
  , Value(..)
  , eitherDecode
  , fromJSON
  , withObject
  , (.:)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as BL
import Data.List (isSuffixOf)
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as Text
import System.Exit (ExitCode(..))
import System.FilePath (takeBaseName)
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )
import Panino.Content.Local.Path (enabledPath)
import Panino.Content.Local.Types

metadataFor :: Text -> FilePath -> IO LocalResourceMetadata
metadataFor kind path
  | kind == "mods" = modMetadata path
  | kind == "resourcePacks" = packMetadata path "resourcepack"
  | kind == "shaderPacks" = shaderMetadata path
  | otherwise = pure emptyMetadata

modMetadata :: FilePath -> IO LocalResourceMetadata
modMetadata path = do
  fabric <- archiveEntry path "fabric.mod.json"
  quilt <- archiveEntry path "quilt.mod.json"
  forge <- archiveEntry path "META-INF/mods.toml"
  pure $
    fromMaybe
      emptyMetadata
      ( (fabric >>= fabricMetadata "fabric")
          <|> (quilt >>= fabricMetadata "quilt")
          <|> (forge >>= forgeMetadata)
      )

packMetadata :: FilePath -> Text -> IO LocalResourceMetadata
packMetadata path loader = do
  mcmeta <- archiveEntry path "pack.mcmeta"
  names <- archiveEntryNames path
  let icon = listToMaybe (filter (Text.isSuffixOf "pack.png" . Text.pack) names)
      fallback =
        LocalResourceMetadata
          { metadataDisplayName = Just (Text.pack (takeBaseName (enabledPath path)))
          , metadataVersion = Nothing
          , metadataAuthors = []
          , metadataSummary = Nothing
          , metadataIconPath = icon
          , metadataLoaders = [loader]
          }
  pure $ fromMaybe fallback (mcmeta >>= packMetadataValue loader icon path)

shaderMetadata :: FilePath -> IO LocalResourceMetadata
shaderMetadata path = do
  propertiesText <- archiveEntry path "shaders.properties"
  names <- archiveEntryNames path
  let icon = listToMaybe (filter (Text.isSuffixOf "pack.png" . Text.pack) names)
  pure
    LocalResourceMetadata
      { metadataDisplayName =
          propertyValue "name" propertiesText
            <|> Just (Text.pack (takeBaseName (enabledPath path)))
      , metadataVersion = propertyValue "version" propertiesText
      , metadataAuthors = maybe [] (: []) (propertyValue "author" propertiesText)
      , metadataSummary = propertyValue "description" propertiesText
      , metadataIconPath = icon
      , metadataLoaders = ["shaderpack"]
      }

fabricMetadata :: Text -> Text -> Maybe LocalResourceMetadata
fabricMetadata loader text =
  case eitherDecode (textToLazyByteString text) of
    Right (Object obj) ->
      Just
        LocalResourceMetadata
          { metadataDisplayName = lookupText "name" obj <|> lookupText "id" obj
          , metadataVersion = lookupText "version" obj
          , metadataAuthors = maybe [] authorValues (lookupValue "authors" obj)
          , metadataSummary = lookupText "description" obj
          , metadataIconPath = Text.unpack <$> lookupText "icon" obj
          , metadataLoaders = [loader]
          }
    _ -> Nothing

forgeMetadata :: Text -> Maybe LocalResourceMetadata
forgeMetadata text =
  Just
    LocalResourceMetadata
      { metadataDisplayName = tomlValue "displayName" text <|> tomlValue "modId" text
      , metadataVersion = tomlValue "version" text
      , metadataAuthors = maybe [] (: []) (tomlValue "authors" text)
      , metadataSummary = tomlValue "description" text
      , metadataIconPath = Text.unpack <$> tomlValue "logoFile" text
      , metadataLoaders = ["forge"]
      }

packMetadataValue :: Text -> Maybe FilePath -> FilePath -> Text -> Maybe LocalResourceMetadata
packMetadataValue loader icon path text =
  case eitherDecode (textToLazyByteString text) of
    Right (Object root) -> do
      Object pack <- lookupValue "pack" root
      pure
        LocalResourceMetadata
          { metadataDisplayName = Just (Text.pack (takeBaseName (enabledPath path)))
          , metadataVersion = lookupValue "pack_format" pack >>= valueText
          , metadataAuthors = []
          , metadataSummary = lookupValue "description" pack >>= descriptionValue
          , metadataIconPath = icon
          , metadataLoaders = [loader]
          }
    _ -> Nothing

archiveEntry :: FilePath -> FilePath -> IO (Maybe Text)
archiveEntry archive name = do
  exact <- runUnzipText ["-p", archive, name]
  if not (Text.null exact)
    then pure (Just exact)
    else do
      names <- archiveEntryNames archive
      case listToMaybe (filter (matchesArchiveEntry name) names) of
        Nothing -> pure Nothing
        Just matched -> do
          nested <- runUnzipText ["-p", archive, matched]
          pure (if Text.null nested then Nothing else Just nested)

archiveEntryNames :: FilePath -> IO [FilePath]
archiveEntryNames archive = do
  text <- runUnzipText ["-Z1", archive]
  pure (map Text.unpack (Text.lines text))

runUnzipText :: [String] -> IO Text
runUnzipText arguments =
  ( do
      (exitCode, stdoutText, _) <- readCreateProcessWithExitCode (proc "/usr/bin/unzip" arguments) ""
      pure $
        if exitCode == ExitSuccess
          then Text.pack stdoutText
          else ""
  )
    `catch` \(_ :: SomeException) -> pure ""

matchesArchiveEntry :: FilePath -> FilePath -> Bool
matchesArchiveEntry name candidate =
  candidate == name || ("/" <> name) `isSuffixOf` candidate

emptyMetadata :: LocalResourceMetadata
emptyMetadata =
  LocalResourceMetadata
    { metadataDisplayName = Nothing
    , metadataVersion = Nothing
    , metadataAuthors = []
    , metadataSummary = Nothing
    , metadataIconPath = Nothing
    , metadataLoaders = []
    }

propertyValue :: Text -> Maybe Text -> Maybe Text
propertyValue key text =
  text
    >>= listToMaybe
      . mapMaybe lineValue
      . Text.lines
  where
    lineValue line = do
      let stripped = Text.strip line
          (lhs, rhs) = Text.breakOn "=" stripped
      guard (Text.strip lhs == key)
      guard (not (Text.null rhs))
      pure (Text.strip (Text.drop 1 rhs))

tomlValue :: Text -> Text -> Maybe Text
tomlValue key text =
  listToMaybe (mapMaybe lineValue (Text.lines text))
  where
    lineValue line = do
      let stripped = Text.strip line
          (lhs, rhs) = Text.breakOn "=" stripped
      guard (not ("#" `Text.isPrefixOf` stripped))
      guard (Text.strip lhs == key)
      guard (not (Text.null rhs))
      pure (stripQuotes (Text.strip (Text.drop 1 rhs)))

descriptionValue :: Value -> Maybe Text
descriptionValue (String text) = Just text
descriptionValue (Number number) = Just (Text.pack (show number))
descriptionValue (Object obj) =
  lookupText "text" obj
    <|> (Text.concat <$> (lookupValue "extra" obj >>= parseJSONMaybe))
descriptionValue value = valueText value

authorValues :: Value -> [Text]
authorValues (String text) = [text]
authorValues value =
  case parseJSONMaybe value of
    Just names -> names
    Nothing -> map unAuthorName (fromMaybe [] (parseJSONMaybe value :: Maybe [AuthorName]))

newtype AuthorName = AuthorName
  { unAuthorName :: Text
  } deriving (Eq, Show)

instance FromJSON AuthorName where
  parseJSON =
    withObject "AuthorName" $ \obj ->
      AuthorName <$> obj .: "name"

parseJSONMaybe :: FromJSON value => Value -> Maybe value
parseJSONMaybe value =
  case fromJSON value of
    Success parsed -> Just parsed
    Error _ -> Nothing

lookupText :: String -> KeyMap.KeyMap Value -> Maybe Text
lookupText key obj =
  lookupValue key obj >>= valueText

lookupValue :: String -> KeyMap.KeyMap Value -> Maybe Value
lookupValue key =
  KeyMap.lookup (Key.fromString key)

valueText :: Value -> Maybe Text
valueText (String text) = Just text
valueText (Number number) = Just (Text.pack (show number))
valueText (Bool True) = Just "true"
valueText (Bool False) = Just "false"
valueText _ = Nothing

stripQuotes :: Text -> Text
stripQuotes value =
  Text.dropAround (== '"') value

textToLazyByteString :: Text -> BL.ByteString
textToLazyByteString =
  BL.fromStrict . Text.encodeUtf8
