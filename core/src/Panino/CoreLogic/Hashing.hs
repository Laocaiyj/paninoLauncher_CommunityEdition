{-# LANGUAGE OverloadedStrings #-}

module Panino.CoreLogic.Hashing
  ( hashLazy
  , sha1File
  ) where

import qualified Crypto.Hash.SHA1 as SHA1
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Word (Word8)
import Numeric (showHex)

sha1File :: FilePath -> IO Text
sha1File path =
  hashLazy <$> BL.readFile path

hashLazy :: BL.ByteString -> Text
hashLazy =
  Text.pack . concatMap hexByte . BS.unpack . SHA1.hash . BL.toStrict

hexByte :: Word8 -> String
hexByte byte =
  let value = fromEnum byte
      rendered = showHex value ""
   in if value < 16 then '0' : rendered else rendered
