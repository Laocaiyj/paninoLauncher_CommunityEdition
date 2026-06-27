{-# LANGUAGE OverloadedStrings #-}

module Panino.Multiplayer.Taowa.FrpcConfig
  ( renderFrpcConfig
  , renderRedactedFrpcConfig
  , taowaSessionProxyName
  ) where

import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Core.TypedToml
  ( TomlLine
  , TomlValue(..)
  , blankLine
  , renderToml
  , tableArray
  , tomlKeyValue
  )
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
  renderToml $
    [ tomlKeyValue "serverAddr" (TomlString (taowaProfileServerAddr profile))
    , tomlKeyValue "serverPort" (TomlInteger (taowaProfileServerPort profile))
    ]
      <> authLines token
      <> [ blankLine
         , tableArray "proxies"
         , tomlKeyValue "name" (TomlString (taowaSessionProxyName sessionId))
         , tomlKeyValue "type" (TomlString "tcp")
         , tomlKeyValue "localIP" (TomlString "127.0.0.1")
         , tomlKeyValue "localPort" (TomlInteger localPort)
         , tomlKeyValue "remotePort" (TomlInteger (taowaProfileRemotePort profile))
         ]

authLines :: Maybe Text -> [TomlLine]
authLines maybeToken =
  case Text.strip <$> maybeToken of
    Just token | not (Text.null token) -> [tomlKeyValue "auth.token" (TomlString token)]
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
