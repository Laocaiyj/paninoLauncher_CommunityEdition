{-# LANGUAGE OverloadedStrings #-}

module Panino.Core.TypedToml
  ( TomlKey
  , TomlLine
  , TomlValue(..)
  , blankLine
  , renderToml
  , tableArray
  , tomlKey
  , tomlKeyValue
  , tomlPath
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

newtype TomlKey =
  TomlKey [Text]
  deriving (Eq, Show)

data TomlValue
  = TomlString Text
  | TomlInteger Int
  deriving (Eq, Show)

data TomlLine
  = TomlBlankLine
  | TomlKeyValue TomlKey TomlValue
  | TomlTableArray TomlKey
  deriving (Eq, Show)

blankLine :: TomlLine
blankLine =
  TomlBlankLine

tomlKey :: Text -> TomlKey
tomlKey name =
  TomlKey [name]

tomlPath :: Text -> [Text] -> TomlKey
tomlPath first rest =
  TomlKey (first : rest)

tomlKeyValue :: TomlKey -> TomlValue -> TomlLine
tomlKeyValue =
  TomlKeyValue

tableArray :: TomlKey -> TomlLine
tableArray =
  TomlTableArray

renderToml :: [TomlLine] -> Text
renderToml =
  Text.unlines . map renderLine

renderLine :: TomlLine -> Text
renderLine TomlBlankLine =
  ""
renderLine (TomlKeyValue key value) =
  renderKey key <> " = " <> renderValue value
renderLine (TomlTableArray name) =
  "[[" <> renderKey name <> "]]"

renderKey :: TomlKey -> Text
renderKey (TomlKey segments) =
  Text.intercalate "." (map renderKeySegment segments)

renderKeySegment :: Text -> Text
renderKeySegment segment
  | isBareKey segment = segment
  | otherwise = renderQuoted segment

isBareKey :: Text -> Bool
isBareKey value =
  not (Text.null value) && Text.all isBareKeyChar value

isBareKeyChar :: Char -> Bool
isBareKeyChar char =
  (char >= 'a' && char <= 'z')
    || (char >= 'A' && char <= 'Z')
    || (char >= '0' && char <= '9')
    || char == '-'
    || char == '_'

renderValue :: TomlValue -> Text
renderValue (TomlString value) =
  renderQuoted value
renderValue (TomlInteger value) =
  Text.pack (show value)

renderQuoted :: Text -> Text
renderQuoted value =
  "\"" <> Text.concatMap escape value <> "\""

escape :: Char -> Text
escape '"' = "\\\""
escape '\\' = "\\\\"
escape '\n' = "\\n"
escape '\r' = "\\r"
escape '\t' = "\\t"
escape char = Text.singleton char
