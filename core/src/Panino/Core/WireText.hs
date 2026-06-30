module Panino.Core.WireText
  ( WireText(..)
  , parseOptionalWireTextField
  , parseWireTextJSON
  , parseWireTextMaybeJSON
  , toWireTextJSON
  ) where

import Data.Aeson
  ( FromJSON(..)
  , Object
  , ToJSON(..)
  , Value
  , (.:?)
  )
import Data.Aeson.Key (Key)
import Data.Aeson.Types (Parser)
import Data.Text (Text)

class WireText a where
  wireText :: a -> Text
  parseWireText :: Text -> a

toWireTextJSON :: WireText a => a -> Value
toWireTextJSON =
  toJSON . wireText

parseWireTextJSON :: WireText a => Value -> Parser a
parseWireTextJSON value =
  parseWireText <$> (parseJSON value :: Parser Text)

parseWireTextMaybeJSON :: String -> (Text -> Maybe a) -> Value -> Parser a
parseWireTextMaybeJSON label build value = do
  raw <- parseJSON value
  case build raw of
    Just parsed -> pure parsed
    Nothing -> fail (label <> " must not be empty")

parseOptionalWireTextField :: Object -> Key -> (Text -> Maybe a) -> Parser (Maybe a)
parseOptionalWireTextField objectValue key build = do
  raw <- objectValue .:? key
  pure (raw >>= build)
