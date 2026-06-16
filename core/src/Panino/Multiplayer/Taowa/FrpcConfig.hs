{-# LANGUAGE OverloadedStrings #-}

module Panino.Multiplayer.Taowa.FrpcConfig
  ( renderFrpcConfig
  , renderRedactedFrpcConfig
  , taowaSessionProxyName
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Multiplayer.Taowa.Types
  ( TaowaFrpProfile(..)
  , redactedToken
  )

renderFrpcConfig :: TaowaFrpProfile -> Text -> Int -> Text
renderFrpcConfig profile sessionId localPort =
  renderFrpcConfigWithToken (taowaProfileToken profile) profile sessionId localPort

renderRedactedFrpcConfig :: TaowaFrpProfile -> Text -> Int -> Text
renderRedactedFrpcConfig profile sessionId localPort =
  renderFrpcConfigWithToken (redactedToken <$> taowaProfileToken profile) profile sessionId localPort

renderFrpcConfigWithToken :: Maybe Text -> TaowaFrpProfile -> Text -> Int -> Text
renderFrpcConfigWithToken token profile sessionId localPort =
  Text.unlines $
    [ "serverAddr = " <> tomlString (taowaProfileServerAddr profile)
    , "serverPort = " <> renderInt (taowaProfileServerPort profile)
    ]
      <> authLines token
      <> [ ""
         , "[[proxies]]"
         , "name = " <> tomlString (taowaSessionProxyName sessionId)
         , "type = \"tcp\""
         , "localIP = \"127.0.0.1\""
         , "localPort = " <> renderInt localPort
         , "remotePort = " <> renderInt (taowaProfileRemotePort profile)
         ]

authLines :: Maybe Text -> [Text]
authLines maybeToken =
  case Text.strip <$> maybeToken of
    Just token | not (Text.null token) -> ["auth.token = " <> tomlString token]
    _ -> []

taowaSessionProxyName :: Text -> Text
taowaSessionProxyName sessionId =
  "panino-taowa-" <> sanitizeName sessionId

sanitizeName :: Text -> Text
sanitizeName =
  Text.map sanitizeChar
  where
    sanitizeChar char
      | char >= 'a' && char <= 'z' = char
      | char >= 'A' && char <= 'Z' = char
      | char >= '0' && char <= '9' = char
      | char == '-' || char == '_' = char
      | otherwise = '-'

tomlString :: Text -> Text
tomlString value =
  "\"" <> Text.concatMap escape value <> "\""
  where
    escape '"' = "\\\""
    escape '\\' = "\\\\"
    escape '\n' = "\\n"
    escape '\r' = "\\r"
    escape '\t' = "\\t"
    escape char = Text.singleton char

renderInt :: Int -> Text
renderInt =
  Text.pack . show
