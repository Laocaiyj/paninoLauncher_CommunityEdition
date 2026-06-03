{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Minecraft.ModPreflight
  ( MissingModDependency(..)
  , missingFabricDependenciesFromManifests
  , preflightModDependencies
  ) where

import Control.Exception
  ( SomeException
  , catch
  , finally
  )
import Control.Monad (when)
import Data.Aeson
  ( FromJSON(..)
  , Value(..)
  , eitherDecode
  , withObject
  , (.:)
  , (.:?)
  )
import Data.Aeson.Types
  ( Parser
  , (.!=)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString.Lazy as BL
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List (sortOn)
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory
  ( doesDirectoryExist
  , getTemporaryDirectory
  , listDirectory
  , removeFile
  )
import System.Exit (ExitCode(..))
import System.FilePath
  ( takeExtension
  , takeFileName
  , (</>)
  )
import System.IO
  ( IOMode(..)
  , hClose
  , openBinaryTempFile
  , withBinaryFile
  )
import System.Process
  ( CreateProcess(..)
  , StdStream(..)
  , createProcess
  , proc
  , readProcessWithExitCode
  , waitForProcess
  )

data MissingModDependency = MissingModDependency
  { missingModFile :: FilePath
  , missingModId :: Text
  , missingDependencyId :: Text
  } deriving (Eq, Show)

data FabricModMetadata = FabricModMetadata
  { fabricModId :: Text
  , fabricModDepends :: [Text]
  , fabricModJars :: [Text]
  } deriving (Eq, Show)

instance FromJSON FabricModMetadata where
  parseJSON =
    withObject "FabricModMetadata" $ \obj -> do
      dependsValue <- obj .:? "depends"
      jars <- obj .:? "jars" .!= []
      FabricModMetadata
        <$> obj .: "id"
        <*> parseDepends dependsValue
        <*> pure (map fabricJarFile jars)

data FabricJarReference = FabricJarReference
  { fabricJarFile :: Text
  } deriving (Eq, Show)

instance FromJSON FabricJarReference where
  parseJSON =
    withObject "FabricJarReference" $ \obj ->
      FabricJarReference
        <$> obj .: "file"

parseDepends :: Maybe Value -> Parser [Text]
parseDepends Nothing =
  pure []
parseDepends (Just (Object deps)) =
  pure (map Key.toText (KeyMap.keys deps))
parseDepends (Just _) =
  pure []

preflightModDependencies :: FilePath -> IO ()
preflightModDependencies gameDir = do
  manifests <- readFabricManifests gameDir
  case missingFabricDependenciesFromManifests manifests of
    Left err ->
      fail err
    Right missing -> do
      when (not (null missing)) $
        fail ("required mod dependencies are missing before launch: " <> renderMissingDependencies missing)

missingFabricDependenciesFromManifests :: [(FilePath, BL.ByteString)] -> Either String [MissingModDependency]
missingFabricDependenciesFromManifests manifests = do
  parsed <- traverse parseManifest manifests
  let installedIds = map (normalizeModId . fabricModId . snd) parsed
  pure
    [ MissingModDependency
        { missingModFile = filePath
        , missingModId = fabricModId metadata
        , missingDependencyId = dependency
        }
    | (filePath, metadata) <- parsed
    , dependency <- fabricModDepends metadata
    , let normalized = normalizeModId dependency
    , normalized `notElem` builtInDependencyIds
    , normalized `notElem` installedIds
    ]
  where
    parseManifest (filePath, bytes) =
      case eitherDecode bytes of
        Right metadata -> Right (filePath, metadata)
        Left err -> Left ("mod metadata parse failed for " <> filePath <> ": " <> err)

readFabricManifests :: FilePath -> IO [(FilePath, BL.ByteString)]
readFabricManifests gameDir = do
  let modsDir = gameDir </> "mods"
  exists <- doesDirectoryExist modsDir
  if not exists
    then pure []
    else do
      entries <- sortOn id <$> listDirectory modsDir `catch` \(_ :: SomeException) -> pure []
      fmap concat $
        traverse
          (\entry -> readFabricManifestsFromJar (modsDir </> entry))
          [entry | entry <- entries, takeExtension entry == ".jar"]

readFabricManifestsFromJar :: FilePath -> IO [(FilePath, BL.ByteString)]
readFabricManifestsFromJar jarPath = do
  topLevel <- readTopLevelFabricManifest jarPath jarPath
  nested <- fmap concat $
    traverse
      (readNestedFabricManifest jarPath)
      (topLevelNestedJarEntries topLevel)
  pure (topLevel <> nested)

topLevelNestedJarEntries :: [(FilePath, BL.ByteString)] -> [FilePath]
topLevelNestedJarEntries ((_, bytes) : _) =
  case eitherDecode bytes of
    Right metadata -> map Text.unpack (fabricModJars metadata)
    Left _ -> []
topLevelNestedJarEntries [] =
  []

readTopLevelFabricManifest :: FilePath -> FilePath -> IO [(FilePath, BL.ByteString)]
readTopLevelFabricManifest jarPath displayPath = do
  result <-
    (Just <$> readProcessWithExitCode "/usr/bin/unzip" ["-p", jarPath, "fabric.mod.json"] "")
      `catch` \(_ :: SomeException) -> pure Nothing
  case result of
    Just (ExitSuccess, stdoutText, _stderrText)
      | not (null stdoutText) -> pure [(displayPath, BL8.pack stdoutText)]
    _ -> pure []

readNestedFabricManifest :: FilePath -> FilePath -> IO [(FilePath, BL.ByteString)]
readNestedFabricManifest outerJar nestedEntry =
  withTemporaryJar $ \nestedJarPath -> do
    extracted <- extractZipEntryToFile outerJar nestedEntry nestedJarPath
    if extracted
      then readTopLevelFabricManifest nestedJarPath (outerJar <> "!" <> nestedEntry)
      else pure []

withTemporaryJar :: (FilePath -> IO a) -> IO a
withTemporaryJar action = do
  tempDir <- getTemporaryDirectory
  (path, handle) <- openBinaryTempFile tempDir "panino-nested-mod.jar"
  hClose handle
  action path `finally` (removeFile path `catch` \(_ :: SomeException) -> pure ())

extractZipEntryToFile :: FilePath -> FilePath -> FilePath -> IO Bool
extractZipEntryToFile outerJar entry targetPath =
  withBinaryFile targetPath WriteMode $ \handle -> do
    (_, _, _, processHandle) <-
      createProcess
        (proc "/usr/bin/unzip" ["-p", outerJar, entry])
          { std_in = NoStream
          , std_out = UseHandle handle
          , std_err = NoStream
          }
    exitCode <- waitForProcess processHandle
    pure (exitCode == ExitSuccess)

renderMissingDependencies :: [MissingModDependency] -> String
renderMissingDependencies missing =
  Text.unpack $
    Text.intercalate
      "; "
      [ Text.pack (takeFileName (missingModFile item))
          <> " requires "
          <> missingDependencyId item
      | item <- missing
      ]

normalizeModId :: Text -> Text
normalizeModId =
  Text.toLower . Text.strip

builtInDependencyIds :: [Text]
builtInDependencyIds =
  [ "minecraft"
  , "java"
  , "fabricloader"
  , "quilt_loader"
  , "quiltloader"
  , "forge"
  , "neoforge"
  ]
