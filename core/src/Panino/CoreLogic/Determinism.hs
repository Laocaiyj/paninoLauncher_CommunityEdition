{-# LANGUAGE OverloadedStrings #-}

module Panino.CoreLogic.Determinism
  ( canonicalJson
  , stableFingerprint
  , stableSortDiagnostics
  , stableSortOnText
  , stableSortPackages
  , stableSortPlanEdges
  , stableSortPlanNodes
  , stableTextSet
  ) where

import qualified Crypto.Hash.SHA1 as SHA1
import Data.Aeson
  ( ToJSON(..)
  , Value(..)
  , encode
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.ByteString as BS
import qualified Data.ByteString.Lazy as BL
import Data.Foldable (toList)
import Data.List
  ( foldl'
  , group
  , intersperse
  , sort
  , sortOn
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Word (Word8)
import Numeric (showHex)

stableTextSet :: [Text] -> [Text]
stableTextSet =
  map head . group . sort

stableSortOnText :: (a -> Text) -> [a] -> [a]
stableSortOnText selector =
  sortOn selector

stableSortPackages :: (a -> Text) -> [a] -> [a]
stableSortPackages =
  stableSortOnText

stableSortDiagnostics :: (a -> Text) -> [a] -> [a]
stableSortDiagnostics =
  stableSortOnText

stableSortPlanNodes :: (a -> Text) -> [a] -> [a]
stableSortPlanNodes =
  stableSortOnText

stableSortPlanEdges :: (a -> Text) -> [a] -> [a]
stableSortPlanEdges =
  stableSortOnText

canonicalJson :: Value -> BL.ByteString
canonicalJson value =
  case value of
    Object objectValue ->
      "{" <> commaJoin (map renderPair sortedPairs) <> "}"
      where
        sortedPairs = sortOn (Key.toText . fst) (KeyMap.toList objectValue)
        renderPair (key, item) =
          encode (Key.toText key) <> ":" <> canonicalJson item
    Array arrayValue ->
      "[" <> commaJoin (map canonicalJson (toList arrayValue)) <> "]"
    String textValue ->
      encode textValue
    Number numberValue ->
      encode numberValue
    Bool True ->
      "true"
    Bool False ->
      "false"
    Null ->
      "null"

stableFingerprint :: ToJSON value => value -> Text
stableFingerprint =
  hashLazy . canonicalJson . toJSON

commaJoin :: [BL.ByteString] -> BL.ByteString
commaJoin =
  BL.concat . intersperse ","

hashLazy :: BL.ByteString -> Text
hashLazy =
  Text.pack . concatMap hexByte . BS.unpack . SHA1.finalize . foldl' SHA1.update SHA1.init . BL.toChunks

hexByte :: Word8 -> String
hexByte byte =
  let value = fromEnum byte
      rendered = showHex value ""
   in if value < 16 then '0' : rendered else rendered
