{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Local.Conflict
  ( conflictHint
  , inferredSource
  ) where

import Data.Char (toLower)
import Data.List (isInfixOf)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Content.Local.Path (lowerText)
import Panino.Content.Local.Types

conflictHint :: Text -> Maybe Text -> FilePath -> LocalResourceMetadata -> Maybe Text
conflictHint kind selectedLoader fileName metadata
  | kind /= "mods" = Nothing
  | "forge" `isInfixOf` facts && selected == Just "fabric" =
      Just "Forge mod may not load with Fabric"
  | "fabric" `isInfixOf` facts && selected == Just "forge" =
      Just "Fabric mod may not load with Forge"
  | otherwise = Nothing
  where
    selected = Text.toLower <$> selectedLoader
    facts =
      lowerText
        ( Text.unwords
            ( Text.pack fileName
                : metadataLoaders metadata
            )
        )

inferredSource :: FilePath -> Maybe Text
inferredSource name
  | "modrinth" `isInfixOf` lower = Just "Modrinth"
  | "curseforge" `isInfixOf` lower || "curse" `isInfixOf` lower = Just "CurseForge"
  | otherwise = Nothing
  where
    lower = map toLower name
