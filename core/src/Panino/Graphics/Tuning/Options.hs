{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Graphics.Tuning.Options
  ( MinecraftOptionLine(..)
  , MinecraftOptions(..)
  , applyOptionsPatch
  , applyOptionsPatchToFile
  , backupOptionsFile
  , buildOptionsPatch
  , buildOptionsPatchForVersion
  , duplicateOptionWarnings
  , graphicsOptionSkippedReason
  , graphicsOptionsWritableKeys
  , isGraphicsOptionsWritableKey
  , optionValue
  , optionsMap
  , parseMinecraftOptions
  , renderMinecraftOptions
  , rollbackOptionsFile
  ) where

import Control.Exception
  ( SomeException
  , throwIO
  , try
  )
import Control.Monad (when)
import qualified Data.ByteString as BS
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Text.Encoding.Error (lenientDecode)
import Data.Time.Clock (UTCTime)
import Data.Time.Format
  ( defaultTimeLocale
  , formatTime
  )
import Panino.Graphics.Tuning.Types
  ( GraphicsTuningWarning(..)
  , OptionsBackup(..)
  , OptionsPatch(..)
  , OptionsPatchChange(..)
  )
import System.Directory
  ( copyFile
  , createDirectoryIfMissing
  , doesFileExist
  , removeFile
  , renameFile
  )
import System.FilePath
  ( takeDirectory
  )
import System.IO
  ( Handle
  , hClose
  , openTempFile
  )

data MinecraftOptionLine
  = MinecraftOptionEntry Text Text
  | MinecraftOptionRaw Text
  deriving (Eq, Show)

data MinecraftOptions = MinecraftOptions
  { minecraftOptionsLines :: [MinecraftOptionLine]
  , minecraftOptionsLineEnding :: Text
  , minecraftOptionsTrailingNewline :: Bool
  } deriving (Eq, Show)

parseMinecraftOptions :: Text -> MinecraftOptions
parseMinecraftOptions raw =
  MinecraftOptions
    { minecraftOptionsLines = map parseLine logicalLines
    , minecraftOptionsLineEnding = lineEnding
    , minecraftOptionsTrailingNewline = trailingNewline
    }
  where
    lineEnding =
      if "\r\n" `Text.isInfixOf` raw then "\r\n" else "\n"
    trailingNewline =
      "\n" `Text.isSuffixOf` raw
    splitLines =
      if Text.null raw then [] else Text.splitOn "\n" raw
    logicalLines =
      map stripCarriageReturn $
        if trailingNewline && not (null splitLines)
          then init splitLines
          else splitLines

renderMinecraftOptions :: MinecraftOptions -> Text
renderMinecraftOptions options =
  body <> if minecraftOptionsTrailingNewline options && not (null renderedLines) then minecraftOptionsLineEnding options else ""
  where
    renderedLines =
      map renderLine (minecraftOptionsLines options)
    body =
      Text.intercalate (minecraftOptionsLineEnding options) renderedLines

optionValue :: Text -> MinecraftOptions -> Maybe Text
optionValue key options =
  lastMaybe
    [ value
    | MinecraftOptionEntry optionKey value <- minecraftOptionsLines options
    , optionKey == key
    ]

optionsMap :: MinecraftOptions -> Map Text Text
optionsMap options =
  Map.fromList
    [ (key, value)
    | MinecraftOptionEntry key value <- minecraftOptionsLines options
    ]

duplicateOptionWarnings :: MinecraftOptions -> [GraphicsTuningWarning]
duplicateOptionWarnings options =
  [ GraphicsTuningWarning
      { graphicsWarningCode = "duplicate_options_key"
      , graphicsWarningSeverity = "warning"
      , graphicsWarningMessage = "options.txt contains duplicate key: " <> key <> ". Panino will use the last value."
      , graphicsWarningAction = Just "reviewOptions"
      }
  | (key, count) <- Map.toList counts
  , count > (1 :: Int)
  ]
  where
    counts =
      Map.fromListWith (+)
        [ (key, 1 :: Int)
        | MinecraftOptionEntry key _ <- minecraftOptionsLines options
        ]

graphicsOptionsWritableKeys :: Set Text
graphicsOptionsWritableKeys =
  Set.fromList
    [ "renderDistance"
    , "simulationDistance"
    , "maxFps"
    , "enableVsync"
    , "renderClouds"
    , "particles"
    , "entityDistanceScaling"
    , "mipmapLevels"
    , "graphicsMode"
    , "fullscreenResolution"
    ]

isGraphicsOptionsWritableKey :: Text -> Bool
isGraphicsOptionsWritableKey key =
  key `Set.member` graphicsOptionsWritableKeys

graphicsOptionSkippedReason :: Maybe Text -> Text -> Maybe Text
graphicsOptionSkippedReason minecraftVersion key
  | not (isGraphicsOptionsWritableKey key) = Just "not_whitelisted"
  | key == "simulationDistance" && maybe False (< (1, 18)) (minecraftMajorMinor =<< minecraftVersion) = Just "unsupported_version"
  | otherwise = Nothing

buildOptionsPatch :: Maybe FilePath -> Map Text Text -> MinecraftOptions -> OptionsPatch
buildOptionsPatch path desired options =
  buildOptionsPatchForVersion Nothing path desired options

buildOptionsPatchForVersion :: Maybe Text -> Maybe FilePath -> Map Text Text -> MinecraftOptions -> OptionsPatch
buildOptionsPatchForVersion minecraftVersion path desired options =
  OptionsPatch
    { optionsPatchPath = path
    , optionsPatchChanges =
        [ patchChange key newValue
        | (key, newValue) <- Map.toList desired
        ]
    }
  where
    patchChange key newValue =
      case optionValue key options of
        _
          | Just reason <- graphicsOptionSkippedReason minecraftVersion key ->
              skipped key Nothing (Just newValue) reason
        Nothing ->
          OptionsPatchChange
            { optionsPatchChangeKey = key
            , optionsPatchChangeOldValue = Nothing
            , optionsPatchChangeNewValue = Just newValue
            , optionsPatchChangeReason = "create missing graphics tuning option"
            , optionsPatchChangeStatus = "create"
            }
        Just oldValue
          | oldValue == newValue ->
              OptionsPatchChange
                { optionsPatchChangeKey = key
                , optionsPatchChangeOldValue = Just oldValue
                , optionsPatchChangeNewValue = Just newValue
                , optionsPatchChangeReason = "already matches graphics tuning recommendation"
                , optionsPatchChangeStatus = "keep"
                }
        Just oldValue ->
          OptionsPatchChange
            { optionsPatchChangeKey = key
            , optionsPatchChangeOldValue = Just oldValue
            , optionsPatchChangeNewValue = Just newValue
            , optionsPatchChangeReason = "graphics tuning recommendation"
            , optionsPatchChangeStatus = "change"
            }

applyOptionsPatch :: OptionsPatch -> MinecraftOptions -> MinecraftOptions
applyOptionsPatch patch options =
  options
    { minecraftOptionsLines =
        foldl applyChange (minecraftOptionsLines options) (optionsPatchChanges patch)
    }
  where
    applyChange linesForPatch change =
      case (optionsPatchChangeStatus change, optionsPatchChangeNewValue change) of
        ("change", Just newValue) ->
          upsertOptionValue (optionsPatchChangeKey change) newValue linesForPatch
        ("create", Just newValue) ->
          upsertOptionValue (optionsPatchChangeKey change) newValue linesForPatch
        _ ->
          linesForPatch

backupOptionsFile :: UTCTime -> FilePath -> IO OptionsBackup
backupOptionsFile now sourcePath = do
  exists <- doesFileExist sourcePath
  if not exists
    then
      pure OptionsBackup
        { optionsBackupSourcePath = sourcePath
        , optionsBackupStablePath = Nothing
        , optionsBackupTimestampPath = Nothing
        , optionsBackupCreated = False
        , optionsBackupError = Just "options_missing"
        }
    else do
      let stablePath = sourcePath <> ".panino-backup"
          timestampPath = sourcePath <> ".panino-backup-" <> timestampSuffix now
      stableExists <- doesFileExist stablePath
      when (not stableExists) $
        copyFile sourcePath stablePath
      copyFile sourcePath timestampPath
      pure OptionsBackup
        { optionsBackupSourcePath = sourcePath
        , optionsBackupStablePath = Just stablePath
        , optionsBackupTimestampPath = Just timestampPath
        , optionsBackupCreated = True
        , optionsBackupError = Nothing
        }

applyOptionsPatchToFile :: UTCTime -> FilePath -> OptionsPatch -> IO OptionsBackup
applyOptionsPatchToFile now path patch = do
  exists <- doesFileExist path
  bytes <-
    if exists
      then BS.readFile path
      else pure mempty
  let parsed =
        if exists
          then parseMinecraftOptions (TextEncoding.decodeUtf8With lenientDecode bytes)
          else (parseMinecraftOptions "") { minecraftOptionsTrailingNewline = True }
      rendered = renderMinecraftOptions (applyOptionsPatch patch parsed)
  backup <- backupOptionsFile now path
  case (exists, optionsBackupError backup) of
    (False, _) -> do
      writeBytesFileAtomic path (TextEncoding.encodeUtf8 rendered)
      pure backup { optionsBackupError = Nothing }
    (_, Just err) -> fail (Text.unpack err)
    (_, Nothing) -> do
      writeBytesFileAtomic path (TextEncoding.encodeUtf8 rendered)
      pure backup

rollbackOptionsFile :: UTCTime -> FilePath -> FilePath -> IO OptionsBackup
rollbackOptionsFile now optionsPath backupPath = do
  backupExists <- doesFileExist backupPath
  when (not backupExists) $
    fail ("backup file does not exist: " <> backupPath)
  currentBackup <- backupOptionsFile now optionsPath
  backupBytes <- BS.readFile backupPath
  writeBytesFileAtomic optionsPath backupBytes
  pure currentBackup

parseLine :: Text -> MinecraftOptionLine
parseLine line =
  case Text.breakOn ":" line of
    (key, rest)
      | Text.null rest || Text.null key -> MinecraftOptionRaw line
      | otherwise -> MinecraftOptionEntry key (Text.drop 1 rest)

renderLine :: MinecraftOptionLine -> Text
renderLine line =
  case line of
    MinecraftOptionEntry key value -> key <> ":" <> value
    MinecraftOptionRaw raw -> raw

stripCarriageReturn :: Text -> Text
stripCarriageReturn line =
  if "\r" `Text.isSuffixOf` line
    then Text.dropEnd 1 line
    else line

lastMaybe :: [a] -> Maybe a
lastMaybe [] = Nothing
lastMaybe values = Just (last values)

skipped :: Text -> Maybe Text -> Maybe Text -> Text -> OptionsPatchChange
skipped key oldValue newValue reason =
  OptionsPatchChange
    { optionsPatchChangeKey = key
    , optionsPatchChangeOldValue = oldValue
    , optionsPatchChangeNewValue = newValue
    , optionsPatchChangeReason = reason
    , optionsPatchChangeStatus = "skipped"
    }

replaceLastOptionValue :: Text -> Text -> [MinecraftOptionLine] -> [MinecraftOptionLine]
replaceLastOptionValue key newValue linesForPatch =
  snd (foldl replaceFromEnd (False, []) (reverse linesForPatch))
  where
    replaceFromEnd (replaced, acc) line =
      case line of
        MinecraftOptionEntry optionKey _
          | optionKey == key && not replaced ->
              (True, MinecraftOptionEntry optionKey newValue : acc)
        _ ->
          (replaced, line : acc)

upsertOptionValue :: Text -> Text -> [MinecraftOptionLine] -> [MinecraftOptionLine]
upsertOptionValue key newValue linesForPatch
  | any isTargetKey linesForPatch =
      replaceLastOptionValue key newValue linesForPatch
  | otherwise =
      linesForPatch <> [MinecraftOptionEntry key newValue]
  where
    isTargetKey line =
      case line of
        MinecraftOptionEntry optionKey _ -> optionKey == key
        MinecraftOptionRaw _ -> False

timestampSuffix :: UTCTime -> String
timestampSuffix =
  formatTime defaultTimeLocale "%Y%m%d-%H%M%S"

minecraftMajorMinor :: Text -> Maybe (Int, Int)
minecraftMajorMinor version =
  case map readInt (take 2 (Text.splitOn "." version)) of
    [Just major, Just minor] -> Just (major, minor)
    _ -> Nothing

readInt :: Text -> Maybe Int
readInt value =
  case reads (Text.unpack value) of
    [(number, "")] -> Just number
    _ -> Nothing

writeBytesFileAtomic :: FilePath -> BS.ByteString -> IO ()
writeBytesFileAtomic path bytes = do
  let directory = takeDirectory path
  createDirectoryIfMissing True directory
  (tempPath, handle) <- openTempFile directory "options.txt.tmp"
  result <- try $ do
    BS.hPut handle bytes
    hClose handle
    _ <- BS.readFile tempPath
    renameFile tempPath path
  case result of
    Right () -> pure ()
    Left (err :: SomeException) -> do
      closeIfOpen handle
      ignoreIOError (removeFile tempPath)
      throwIO err

closeIfOpen :: Handle -> IO ()
closeIfOpen handle =
  ignoreIOError (hClose handle)

ignoreIOError :: IO () -> IO ()
ignoreIOError action =
  action `catchAny` \_ -> pure ()

catchAny :: IO a -> (SomeException -> IO a) -> IO a
catchAny action handler = do
  result <- try action
  case result of
    Right value -> pure value
    Left err -> handler err
