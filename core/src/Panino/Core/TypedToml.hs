{-# LANGUAGE OverloadedStrings #-}

module Panino.Core.TypedToml
  ( TomlLine
  , TomlValue(..)
  , blankLine
  , renderToml
  , tableArray
  , tomlKeyValue
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

data TomlValue
  = TomlString Text
  | TomlInteger Int
  deriving (Eq, Show)

data TomlLine
  = TomlBlankLine
  | TomlKeyValue Text TomlValue
  | TomlTableArray Text
  deriving (Eq, Show)

blankLine :: TomlLine
blankLine =
  TomlBlankLine

tomlKeyValue :: Text -> TomlValue -> TomlLine
tomlKeyValue =
  TomlKeyValue

tableArray :: Text -> TomlLine
tableArray =
  TomlTableArray

renderToml :: [TomlLine] -> Text
renderToml =
  Text.unlines . map renderLine

renderLine :: TomlLine -> Text
renderLine TomlBlankLine =
  ""
renderLine (TomlKeyValue key value) =
  key <> " = " <> renderValue value
renderLine (TomlTableArray name) =
  "[[" <> name <> "]]"

renderValue :: TomlValue -> Text
renderValue (TomlString value) =
  "\"" <> Text.concatMap escape value <> "\""
renderValue (TomlInteger value) =
  Text.pack (show value)

escape :: Char -> Text
escape '"' = "\\\""
escape '\\' = "\\\\"
escape '\n' = "\\n"
escape '\r' = "\\r"
escape '\t' = "\\t"
escape char = Text.singleton char
