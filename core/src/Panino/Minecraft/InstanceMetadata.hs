{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Minecraft.InstanceMetadata
  ( InstanceMetadata(..)
  , metadataPath
  , readInstanceMetadata
  , writeInstanceMetadata
  ) where

import Control.Exception
  ( SomeException
  , catch
  )
import Control.Applicative ((<|>))
import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , eitherDecode'
  , encode
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Aeson.Types ((.!=))
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  )
import System.FilePath
  ( takeDirectory
  , takeFileName
  , (</>)
  )

data InstanceMetadata = InstanceMetadata
  { metadataName :: Maybe Text
  , metadataMinecraftVersion :: Text
  , metadataLaunchVersion :: Text
  , metadataLoader :: Maybe Text
  , metadataLoaderVersion :: Maybe Text
  , metadataShaderLoader :: Maybe Text
  } deriving (Eq, Show)

data InferredLoaderProfile = InferredLoaderProfile
  { inferredMinecraftVersion :: Text
  , inferredLoader :: Text
  , inferredLoaderVersion :: Maybe Text
  } deriving (Eq, Show)

data FallbackVersionProfile = FallbackVersionProfile
  { fallbackProfileInheritsFrom :: Maybe Text
  , fallbackProfileLibraries :: [FallbackLibrary]
  } deriving (Eq, Show)

newtype FallbackLibrary = FallbackLibrary
  { fallbackLibraryName :: Text
  } deriving (Eq, Show)

instance FromJSON FallbackVersionProfile where
  parseJSON =
    withObject "FallbackVersionProfile" $ \obj ->
      FallbackVersionProfile
        <$> obj .:? "inheritsFrom"
        <*> (obj .:? "libraries" .!= [])

instance FromJSON FallbackLibrary where
  parseJSON =
    withObject "FallbackLibrary" $ \obj ->
      FallbackLibrary <$> obj .: "name"

instance FromJSON InstanceMetadata where
  parseJSON =
    withObject "InstanceMetadata" $ \obj ->
      InstanceMetadata
        <$> obj .:? "name"
        <*> obj .: "minecraftVersion"
        <*> obj .: "launchVersion"
        <*> obj .:? "loader"
        <*> obj .:? "loaderVersion"
        <*> obj .:? "shaderLoader"

instance ToJSON InstanceMetadata where
  toJSON metadata =
    object
      [ "name" .= metadataName metadata
      , "minecraftVersion" .= metadataMinecraftVersion metadata
      , "launchVersion" .= metadataLaunchVersion metadata
      , "loader" .= metadataLoader metadata
      , "loaderVersion" .= metadataLoaderVersion metadata
      , "shaderLoader" .= metadataShaderLoader metadata
      ]

metadataPath :: FilePath -> FilePath
metadataPath gameDir =
  gameDir </> ".panino" </> "instance.json"

writeInstanceMetadata :: FilePath -> InstanceMetadata -> IO ()
writeInstanceMetadata gameDir metadata = do
  let path = metadataPath gameDir
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path (encode metadata)

readInstanceMetadata :: FilePath -> Text -> IO InstanceMetadata
readInstanceMetadata gameDir fallbackVersion = do
  let path = metadataPath gameDir
  fallbackMetadata <- fallbackInstanceMetadata gameDir fallbackVersion
  exists <- doesFileExist path
  if exists
    then
      ( do
          bytes <- BL.readFile path
          case eitherDecode' bytes of
            Right metadata -> pure (repairDecodedMetadata fallbackMetadata metadata)
            Left _ -> pure fallbackMetadata
      )
        `catch` \(_ :: SomeException) -> pure fallbackMetadata
    else pure fallbackMetadata

repairDecodedMetadata :: InstanceMetadata -> InstanceMetadata -> InstanceMetadata
repairDecodedMetadata fallbackMetadata metadata
  | shouldUseFallbackProfileInference fallbackMetadata metadata =
      metadata
        { metadataMinecraftVersion = metadataMinecraftVersion fallbackMetadata
        , metadataLoader = metadataLoader metadata <|> metadataLoader fallbackMetadata
        , metadataLoaderVersion = metadataLoaderVersion metadata <|> metadataLoaderVersion fallbackMetadata
        }
  | metadataLoader metadata == Nothing && metadataLoader fallbackMetadata /= Nothing =
      metadata
        { metadataLoader = metadataLoader fallbackMetadata
        , metadataLoaderVersion = metadataLoaderVersion fallbackMetadata
        }
  | otherwise = metadata

shouldUseFallbackProfileInference :: InstanceMetadata -> InstanceMetadata -> Bool
shouldUseFallbackProfileInference fallbackMetadata metadata =
  metadataLaunchVersion fallbackMetadata == metadataLaunchVersion metadata
    && metadataMinecraftVersion fallbackMetadata /= metadataLaunchVersion fallbackMetadata
    && ( metadataMinecraftVersion metadata == metadataLaunchVersion metadata
          || not (isMinecraftVersionLike (metadataMinecraftVersion metadata))
       )

fallbackInstanceMetadata :: FilePath -> Text -> IO InstanceMetadata
fallbackInstanceMetadata gameDir fallbackVersion = do
  profileInference <- inferProfileFromVersionJson gameDir fallbackVersion
  let inferred = profileInference <|> inferLoaderProfileId fallbackVersion
  pure $
    case inferred of
      Just profile ->
        InstanceMetadata
          { metadataName = inferredFallbackName gameDir
          , metadataMinecraftVersion = inferredMinecraftVersion profile
          , metadataLaunchVersion = fallbackVersion
          , metadataLoader = Just (inferredLoader profile)
          , metadataLoaderVersion = inferredLoaderVersion profile
          , metadataShaderLoader = Nothing
          }
      Nothing ->
        InstanceMetadata
          { metadataName = inferredFallbackName gameDir
          , metadataMinecraftVersion = fallbackVersion
          , metadataLaunchVersion = fallbackVersion
          , metadataLoader = inferLoader fallbackVersion
          , metadataLoaderVersion = Nothing
          , metadataShaderLoader = Nothing
          }

inferredFallbackName :: FilePath -> Maybe Text
inferredFallbackName gameDir =
  let name = Text.pack (takeFileName gameDir)
   in if Text.null name then Nothing else Just name

inferProfileFromVersionJson :: FilePath -> Text -> IO (Maybe InferredLoaderProfile)
inferProfileFromVersionJson gameDir fallbackVersion = do
  let path = fallbackVersionJsonPath gameDir fallbackVersion
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else
      ( do
          decoded <- eitherDecode' <$> BL.readFile path
          pure $ case decoded of
            Right profile -> inferProfileFromParsedJson fallbackVersion profile
            Left _ -> Nothing
      )
        `catch` \(_ :: SomeException) -> pure Nothing

fallbackVersionJsonPath :: FilePath -> Text -> FilePath
fallbackVersionJsonPath gameDir version =
  gameDir </> "versions" </> Text.unpack version </> Text.unpack version <> ".json"

inferProfileFromParsedJson :: Text -> FallbackVersionProfile -> Maybe InferredLoaderProfile
inferProfileFromParsedJson fallbackVersion profile = do
  minecraftVersion <- fallbackProfileInheritsFrom profile <|> (inferredMinecraftVersion <$> inferLoaderProfileId fallbackVersion)
  (loader, loaderVersion) <- inferLoaderFromLibraries minecraftVersion (map fallbackLibraryName (fallbackProfileLibraries profile)) <|> inferLoaderFromProfileId fallbackVersion
  pure
    InferredLoaderProfile
      { inferredMinecraftVersion = minecraftVersion
      , inferredLoader = loader
      , inferredLoaderVersion = loaderVersion
      }

inferLoaderFromLibraries :: Text -> [Text] -> Maybe (Text, Maybe Text)
inferLoaderFromLibraries minecraftVersion libraries =
  firstJust
    [ fmap (\version -> ("quilt", Just version)) (libraryVersionAfter "org.quiltmc:quilt-loader:")
    , fmap (\version -> ("fabric", Just version)) (libraryVersionAfter "net.fabricmc:fabric-loader:")
    , fmap (\version -> ("neoForge", Just version)) (libraryVersionAfter "net.neoforged:neoforge:")
    , fmap (\version -> ("forge", Just version)) forgeLibraryVersion
    ]
  where
    libraryVersionAfter prefix =
      firstJust [nonEmptyText =<< Text.stripPrefix prefix name | name <- libraries]
    forgeLibraryVersion =
      firstJust
        [ nonEmptyText =<< (Text.stripPrefix (minecraftVersion <> "-") =<< Text.stripPrefix "net.minecraftforge:forge:" name)
        | name <- libraries
        ]

inferLoaderProfileId :: Text -> Maybe InferredLoaderProfile
inferLoaderProfileId fallbackVersion = do
  (loader, loaderVersion, minecraftVersion) <- inferMetaLoaderProfileId fallbackVersion <|> inferForgeStyleProfileId fallbackVersion
  pure
    InferredLoaderProfile
      { inferredMinecraftVersion = minecraftVersion
      , inferredLoader = loader
      , inferredLoaderVersion = nonEmptyText loaderVersion
      }

inferLoaderFromProfileId :: Text -> Maybe (Text, Maybe Text)
inferLoaderFromProfileId fallbackVersion = do
  profile <- inferLoaderProfileId fallbackVersion
  pure (inferredLoader profile, inferredLoaderVersion profile)

inferMetaLoaderProfileId :: Text -> Maybe (Text, Text, Text)
inferMetaLoaderProfileId profileId =
  inferWithPrefix "quilt" "quilt-loader-" profileId
    <|> inferWithPrefix "fabric" "fabric-loader-" profileId

inferWithPrefix :: Text -> Text -> Text -> Maybe (Text, Text, Text)
inferWithPrefix loader prefix profileId = do
  rest <- Text.stripPrefix prefix profileId
  (loaderVersion, minecraftVersion) <- splitLoaderVersionAndMinecraftVersion rest
  pure (loader, loaderVersion, minecraftVersion)

inferForgeStyleProfileId :: Text -> Maybe (Text, Text, Text)
inferForgeStyleProfileId profileId =
  inferForgeAfterMinecraft "forge" "-forge-" profileId
    <|> inferForgeAfterMinecraft "neoForge" "-neoforge-" profileId

inferForgeAfterMinecraft :: Text -> Text -> Text -> Maybe (Text, Text, Text)
inferForgeAfterMinecraft loader marker profileId = do
  let (minecraftVersion, rest) = Text.breakOn marker profileId
  loaderVersion <- Text.stripPrefix marker rest
  if isMinecraftVersionLike minecraftVersion && not (Text.null loaderVersion)
    then pure (loader, loaderVersion, minecraftVersion)
    else Nothing

splitLoaderVersionAndMinecraftVersion :: Text -> Maybe (Text, Text)
splitLoaderVersionAndMinecraftVersion value =
  firstJust
    [ let loaderVersion = Text.intercalate "-" (take index segments)
          minecraftVersion = Text.intercalate "-" (drop index segments)
       in if not (Text.null loaderVersion) && isMinecraftVersionLike minecraftVersion
            then Just (loaderVersion, minecraftVersion)
            else Nothing
    | index <- reverse [1 .. length segments - 1]
    ]
  where
    segments = Text.splitOn "-" value

inferLoader :: Text -> Maybe Text
inferLoader value
  | "neoforge" `Text.isInfixOf` normalized = Just "neoForge"
  | "fabric" `Text.isInfixOf` normalized = Just "fabric"
  | "quilt" `Text.isInfixOf` normalized = Just "quilt"
  | "forge" `Text.isInfixOf` normalized = Just "forge"
  | otherwise = Nothing
  where
    normalized = Text.toLower value

isMinecraftVersionLike :: Text -> Bool
isMinecraftVersionLike value =
  not (Text.null value)
    && maybe False isDigitText (Text.uncons value)
    && (Text.any (== '.') value || Text.any (== 'w') value)
    && Text.all isMinecraftVersionChar value
  where
    isDigitText (char, _) = char >= '0' && char <= '9'
    isMinecraftVersionChar char =
      (char >= '0' && char <= '9')
        || (char >= 'a' && char <= 'z')
        || (char >= 'A' && char <= 'Z')
        || char == '.'
        || char == '-'
        || char == '_'

nonEmptyText :: Text -> Maybe Text
nonEmptyText value =
  let trimmed = Text.strip value
   in if Text.null trimmed then Nothing else Just trimmed

firstJust :: [Maybe a] -> Maybe a
firstJust [] = Nothing
firstJust (Just value:_) = Just value
firstJust (Nothing:rest) = firstJust rest
