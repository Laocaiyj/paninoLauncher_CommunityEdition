{-# LANGUAGE OverloadedStrings #-}

module Integration.CoreTypes
  ( assertCoreTypes
  ) where

import Data.Aeson
  ( eitherDecode
  , encode
  )
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.Either (isLeft)
import Data.Text (Text)
import Panino.Core.TypedToml
  ( TomlValue(..)
  , blankLine
  , renderToml
  , tableArray
  , tomlKeyValue
  )
import Panino.Core.Types
  ( GameDir
  , Sha1
  , Url
  , sha1FromText
  , sha1Text
  , urlFromText
  )
import TestSupport (assertEqual)

assertCoreTypes :: IO ()
assertCoreTypes = do
  let url = urlFromText "https://example.com/file.jar"
  assertEqual "core url json keeps string wire shape" "\"https://example.com/file.jar\"" (BL8.unpack (encode url))
  assertEqual "core url json roundtrip" (Right url) (eitherDecode "\"https://example.com/file.jar\"" :: Either String Url)
  assertEqual "core sha1 constructor normalizes case" (Just "abcdef") (sha1Text <$> sha1FromText "ABCDEF")
  assertEqual "core sha1 json rejects empty text" True (isLeft (eitherDecode "\"\"" :: Either String Sha1))
  assertEqual "core game dir json rejects empty text" True (isLeft (eitherDecode "\"\"" :: Either String GameDir))
  assertEqual
    "core typed toml escapes strings"
    ("serverAddr = \"host\\\"\\\\\\nname\"\nserverPort = 7000\n\n[[proxies]]\n" :: Text)
    ( renderToml
        [ tomlKeyValue "serverAddr" (TomlString "host\"\\\nname")
        , tomlKeyValue "serverPort" (TomlInteger 7000)
        , blankLine
        , tableArray "proxies"
        ]
    )
