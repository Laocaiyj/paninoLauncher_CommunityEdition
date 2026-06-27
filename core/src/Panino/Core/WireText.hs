module Panino.Core.WireText
  ( WireText(..)
  , parseWireTextJSON
  , toWireTextJSON
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , Value
  )
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
