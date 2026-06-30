{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.GraphicsTuning
  ( graphicsTuningApplyResponse
  , graphicsTuningResolveResponse
  , graphicsTuningRollbackResponse
  , readGraphicsTuningForEnvironment
  , writeGraphicsTuningDiagnostics
  , writeGraphicsTuningRollbackEvent
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Control.Applicative ((<|>))
import Data.Aeson
  ( FromJSON(..)
  , Value
  , encode
  , object
  , withObject
  , (.:?)
  , (.=)
  )
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Data.Text.Encoding.Error (lenientDecode)
import Data.Time.Clock (getCurrentTime)
import Network.HTTP.Types
  ( status200
  , status400
  )
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Response
  ( apiError
  , apiErrorMessage
  , apiErrorResponse
  , decodeJsonBodyResponse
  , jsonResponse
  )
import Panino.Graphics.Tuning.Options
  ( MinecraftOptions
  , applyOptionsPatchToFile
  , graphicsOptionSkippedReason
  , parseMinecraftOptions
  , rollbackOptionsFile
  )
import Panino.Graphics.Tuning.Recommend (recommendGraphicsTuning)
import Panino.Graphics.Tuning.Types
  ( GraphicsTuningRequest(..)
  , GraphicsTuningWarning(..)
  , GraphicsHardwareTier(..)
  , OptionsBackup(..)
  , OptionsPatch(..)
  , OptionsPatchChange(..)
  , ResolvedGraphicsTuning(..)
  , graphicsRequestGameDirPath
  )
import Panino.Core.Types
  ( GameDir
  , gameDirFromPath
  , gameDirFromText
  , gameDirPath
  )
import Panino.Core.WireText (parseOptionalWireTextField)
import Panino.Platform.Hardware (detectGraphicsHardwareTier)
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  )
import System.FilePath
  ( (</>)
  )

data GraphicsTuningRollbackRequest = GraphicsTuningRollbackRequest
  { rollbackGraphicsGameDir :: Maybe GameDir
  , rollbackGraphicsBackupPath :: Maybe FilePath
  } deriving (Eq, Show)

instance FromJSON GraphicsTuningRollbackRequest where
  parseJSON =
    withObject "GraphicsTuningRollbackRequest" $ \obj ->
      GraphicsTuningRollbackRequest
        <$> parseOptionalWireTextField obj "gameDir" gameDirFromText
        <*> obj .:? "backupPath"

graphicsTuningResolveResponse :: Request -> IO Response
graphicsTuningResolveResponse request =
  decodeJsonBodyResponse request $ \tuningRequest ->
    case graphicsRequestGameDirPath tuningRequest of
      Nothing ->
        pure (apiErrorResponse status400 (apiError "missing_game_dir"))
      Just gameDir -> do
        resolved <- readGraphicsTuningForEnvironment tuningRequest gameDir
        pure (jsonResponse status200 resolved)

graphicsTuningApplyResponse :: Request -> IO Response
graphicsTuningApplyResponse request =
  decodeJsonBodyResponse request $ \tuningRequest ->
    case graphicsRequestGameDirPath tuningRequest of
      Nothing ->
        pure (apiErrorResponse status400 (apiError "missing_game_dir"))
      Just gameDir -> do
        let optionsFile = optionsPath gameDir
        resolved <- readGraphicsTuningForEnvironment tuningRequest gameDir
        now <- getCurrentTime
        applied <- try (applyOptionsPatchToFile now optionsFile (resolvedGraphicsOptionsPatch resolved))
        case applied of
          Left (err :: SomeException) ->
            pure (apiErrorResponse status400 (apiErrorMessage "graphics_tuning_apply_failed" (Text.pack (show err))))
          Right backup -> do
            let resolvedWithBackup = attachBackup backup resolved
            writeGraphicsTuningDiagnostics gameDir resolvedWithBackup backup
            writeGraphicsTuningApplyEvent gameDir resolvedWithBackup backup
            pure $
              jsonResponse status200 $
                object
                  [ "applied" .= True
                  , "backup" .= backup
                  , "tuning" .= resolvedWithBackup
                  ]

graphicsTuningRollbackResponse :: Request -> IO Response
graphicsTuningRollbackResponse request =
  decodeJsonBodyResponse request $ \rollbackRequest ->
    case rollbackGraphicsGameDirPath rollbackRequest of
      Nothing ->
        pure (apiErrorResponse status400 (apiError "missing_game_dir"))
      Just gameDir -> do
        now <- getCurrentTime
        let optionsFile = optionsPath gameDir
            backupFile = maybe (optionsFile <> ".panino-backup") id (rollbackGraphicsBackupPath rollbackRequest)
        rolledBack <- try (rollbackOptionsFile now optionsFile backupFile)
        case rolledBack of
          Left (err :: SomeException) ->
            pure (apiErrorResponse status400 (apiErrorMessage "graphics_tuning_rollback_failed" (Text.pack (show err))))
          Right backup -> do
            writeGraphicsTuningRollbackEvent gameDir backupFile backup
            pure $
              jsonResponse status200 $
                object
                  [ "rolledBack" .= True
                  , "restoredFrom" .= backupFile
                  , "backup" .= backup
                  ]

readGraphicsTuningForEnvironment :: GraphicsTuningRequest -> FilePath -> IO ResolvedGraphicsTuning
readGraphicsTuningForEnvironment request gameDir = do
  let optionsFile = optionsPath gameDir
  optionsExists <- doesFileExist optionsFile
  options <- readMinecraftOptions optionsFile
  hardwareTier <- completeGraphicsHardwareTier request
  let resolved =
        recommendGraphicsTuning
          request
            { graphicsRequestGameDir = gameDirFromPath gameDir
            , graphicsRequestHardwareTier = hardwareTier
            }
          options
  pure $
    if optionsExists
      then resolved
      else allowInitialOptionsFileCreate request optionsFile resolved

completeGraphicsHardwareTier :: GraphicsTuningRequest -> IO GraphicsHardwareTier
completeGraphicsHardwareTier request =
  case graphicsRequestHardwareTier request of
    GraphicsHardwareUnknown -> detectGraphicsHardwareTier
    tier -> pure tier

writeGraphicsTuningDiagnostics :: FilePath -> ResolvedGraphicsTuning -> OptionsBackup -> IO ()
writeGraphicsTuningDiagnostics gameDir resolved backup = do
  let directory = gameDir </> "downloads"
  createDirectoryIfMissing True directory
  BL.writeFile
    (directory </> "graphics-tuning.json")
    ( encode $
        object
          [ "tuning" .= resolved
          , "backup" .= backup
          , "userAction" .= ("applyRecommended" :: Text)
          ]
    )
  writeFile (directory </> "graphics-options-patch.txt") (Text.unpack (renderPatchText resolved backup))

writeGraphicsTuningApplyEvent :: FilePath -> ResolvedGraphicsTuning -> OptionsBackup -> IO ()
writeGraphicsTuningApplyEvent gameDir resolved backup = do
  now <- getCurrentTime
  appendGraphicsTuningEvent gameDir $
    object
      [ "event" .= ("graphics_tuning" :: Text)
      , "action" .= ("applyRecommended" :: Text)
      , "recordedAt" .= now
      , "summary" .= resolvedGraphicsSummary resolved
      , "profile" .= resolvedGraphicsEffectiveProfile resolved
      , "backupPath" .= (optionsBackupTimestampPath backup <|> optionsBackupStablePath backup)
      , "patch" .= resolvedGraphicsOptionsPatch resolved
      , "warnings" .= resolvedGraphicsWarnings resolved
      ]

writeGraphicsTuningRollbackEvent :: FilePath -> FilePath -> OptionsBackup -> IO ()
writeGraphicsTuningRollbackEvent gameDir restoredFrom backup = do
  now <- getCurrentTime
  appendGraphicsTuningEvent gameDir $
    object
      [ "event" .= ("graphics_tuning" :: Text)
      , "action" .= ("rollback" :: Text)
      , "recordedAt" .= now
      , "restoredFrom" .= restoredFrom
      , "backupPath" .= (optionsBackupTimestampPath backup <|> optionsBackupStablePath backup)
      , "backup" .= backup
      ]

appendGraphicsTuningEvent :: FilePath -> Value -> IO ()
appendGraphicsTuningEvent gameDir event = do
  let directory = gameDir </> "downloads"
  createDirectoryIfMissing True directory
  BL.appendFile (directory </> "graphics-tuning-events.jsonl") (encode event <> BL.singleton 10)

rollbackGraphicsGameDirPath :: GraphicsTuningRollbackRequest -> Maybe FilePath
rollbackGraphicsGameDirPath =
  fmap gameDirPath . rollbackGraphicsGameDir

allowInitialOptionsFileCreate :: GraphicsTuningRequest -> FilePath -> ResolvedGraphicsTuning -> ResolvedGraphicsTuning
allowInitialOptionsFileCreate request optionsFile resolved =
  resolved
    { resolvedGraphicsOptionsPatch = patch
    , resolvedGraphicsCanApply = any ((== "create") . optionsPatchChangeStatus) (optionsPatchChanges patch)
    , resolvedGraphicsCanRollback = False
    , resolvedGraphicsBackupPath = Nothing
    , resolvedGraphicsWarnings =
        filter (not . isInitialMissingKeyWarning) (resolvedGraphicsWarnings resolved)
    }
  where
    patch =
      OptionsPatch
        { optionsPatchPath = Just optionsFile
        , optionsPatchChanges =
            [ createChange key value
            | (key, value) <- Map.toList (resolvedGraphicsRecommendedOptions resolved)
            ]
        }
    createChange key value =
      case graphicsOptionSkippedReason (graphicsRequestMinecraftVersion request) key of
        Just reason ->
          OptionsPatchChange
            { optionsPatchChangeKey = key
            , optionsPatchChangeOldValue = Nothing
            , optionsPatchChangeNewValue = Just value
            , optionsPatchChangeReason = reason
            , optionsPatchChangeStatus = "skipped"
            }
        Nothing ->
          OptionsPatchChange
            { optionsPatchChangeKey = key
            , optionsPatchChangeOldValue = Nothing
            , optionsPatchChangeNewValue = Just value
            , optionsPatchChangeReason = "create initial options.txt from graphics tuning recommendation"
            , optionsPatchChangeStatus = "create"
            }

    isInitialMissingKeyWarning warning =
      graphicsWarningCode warning == "options_key_skipped"
        && "missing_key" `Text.isInfixOf` graphicsWarningMessage warning

readMinecraftOptions :: FilePath -> IO MinecraftOptions
readMinecraftOptions path = do
  exists <- doesFileExist path
  if not exists
    then pure (parseMinecraftOptions "")
    else do
      bytes <- BS.readFile path
      pure (parseMinecraftOptions (TextEncoding.decodeUtf8With lenientDecode bytes))

attachBackup :: OptionsBackup -> ResolvedGraphicsTuning -> ResolvedGraphicsTuning
attachBackup backup resolved =
  resolved
    { resolvedGraphicsBackupPath =
        optionsBackupTimestampPath backup
          <|> optionsBackupStablePath backup
          <|> resolvedGraphicsBackupPath resolved
    , resolvedGraphicsCanRollback =
        optionsBackupTimestampPath backup /= Nothing
          || optionsBackupStablePath backup /= Nothing
          || resolvedGraphicsCanRollback resolved
    , resolvedGraphicsRollbackRef =
        Text.pack <$> (optionsBackupTimestampPath backup <|> optionsBackupStablePath backup)
          <|> resolvedGraphicsRollbackRef resolved
    }

renderPatchText :: ResolvedGraphicsTuning -> OptionsBackup -> Text
renderPatchText resolved backup =
  Text.unlines $
    [ "Graphics tuning patch"
    , "backup: " <> maybe "-" Text.pack (optionsBackupTimestampPath backup <|> optionsBackupStablePath backup)
    , "summary: " <> resolvedGraphicsSummary resolved
    , ""
    ]
      <> map renderChange (optionsPatchChanges (resolvedGraphicsOptionsPatch resolved))

renderChange :: OptionsPatchChange -> Text
renderChange change =
  Text.intercalate
    " | "
    [ optionsPatchChangeStatus change
    , optionsPatchChangeKey change
    , "old=" <> maybe "-" id (optionsPatchChangeOldValue change)
    , "new=" <> maybe "-" id (optionsPatchChangeNewValue change)
    , "reason=" <> optionsPatchChangeReason change
    ]

optionsPath :: FilePath -> FilePath
optionsPath gameDir =
  gameDir </> "options.txt"
