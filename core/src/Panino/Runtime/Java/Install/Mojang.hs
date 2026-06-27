{-# LANGUAGE OverloadedStrings #-}

module Panino.Runtime.Java.Install.Mojang
  ( MojangRuntimeFile(..)
  , MojangRuntimeManifest(..)
  , chmodMojangExecutable
  , mojangDownloadJobs
  ) where

import Data.Aeson
  ( FromJSON(..)
  , Value(..)
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Aeson.Types (Parser)
import Control.Monad (when)
import Data.Int (Int64)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Core.Types
  ( sha1FromText
  , urlFromText
  )
import Panino.Download.Manager (DownloadJob(..))
import Panino.Runtime.Java.Install.Archive (runProcessChecked)
import System.FilePath ((</>))

data MojangRuntimeManifest = MojangRuntimeManifest
  { mojangManifestFiles :: [(FilePath, MojangRuntimeFile)]
  } deriving (Eq, Show)

instance FromJSON MojangRuntimeManifest where
  parseJSON =
    withObject "MojangRuntimeManifest" $ \obj -> do
      filesValue <- obj .: "files"
      case filesValue of
        Object files -> do
          entries <-
            traverse
              ( \(key, value) -> do
                  file <- parseJSON value
                  pure (Text.unpack (Key.toText key), file)
              )
              (KeyMap.toList files)
          pure (MojangRuntimeManifest entries)
        _ -> fail "Mojang runtime manifest files must be an object"

data MojangRuntimeFile = MojangRuntimeFile
  { mojangFileType :: Text
  , mojangFileRawDownload :: Maybe MojangFileDownload
  , mojangFileExecutable :: Bool
  } deriving (Eq, Show)

instance FromJSON MojangRuntimeFile where
  parseJSON =
    withObject "MojangRuntimeFile" $ \obj -> do
      downloads <- (obj .:? "downloads" :: Parser (Maybe Value))
      raw <-
        case downloads of
          Just (Object values) ->
            case KeyMap.lookup (Key.fromText "raw") values of
              Just rawValue -> Just <$> parseJSON rawValue
              Nothing -> pure Nothing
          _ -> pure Nothing
      MojangRuntimeFile
        <$> obj .: "type"
        <*> pure raw
        <*> obj .:? "executable" .!= False

data MojangFileDownload = MojangFileDownload
  { mojangDownloadSha1 :: Text
  , mojangDownloadSize :: Maybe Int64
  , mojangDownloadUrl :: Text
  } deriving (Eq, Show)

instance FromJSON MojangFileDownload where
  parseJSON =
    withObject "MojangFileDownload" $ \obj ->
      MojangFileDownload
        <$> obj .: "sha1"
        <*> obj .:? "size"
        <*> obj .: "url"

mojangDownloadJobs :: FilePath -> [(FilePath, MojangRuntimeFile)] -> [DownloadJob]
mojangDownloadJobs staging =
  mapMaybe jobForFile
  where
    jobForFile (path, file) = do
      download <- mojangFileRawDownload file
      pure DownloadJob
        { jobLabel = path
        , jobUrl = urlFromText (mojangDownloadUrl download)
        , jobTargetPath = staging </> path
        , jobSha1 = sha1FromText (mojangDownloadSha1 download)
        , jobSize = mojangDownloadSize download
        }

chmodMojangExecutable :: FilePath -> (FilePath, MojangRuntimeFile) -> IO ()
chmodMojangExecutable staging (path, file) =
  when (mojangFileExecutable file) $
    runProcessChecked "/bin/chmod" ["+x", staging </> path] "java_runtime_permission_denied"
