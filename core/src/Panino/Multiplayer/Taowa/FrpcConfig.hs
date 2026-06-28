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
  , tomlKey
  , tomlKeyValue
  , tomlPath
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
    [ tomlKeyValue (tomlKey "serverAddr") (TomlString (taowaProfileServerAddr profile))
    , tomlKeyValue (tomlKey "serverPort") (TomlInteger (taowaProfileServerPort profile))
    ]
      <> authLines token
      <> [ blankLine
         , tableArray (tomlKey "proxies")
         , tomlKeyValue (tomlKey "name") (TomlString (taowaSessionProxyName sessionId))
         , tomlKeyValue (tomlKey "type") (TomlString "tcp")
         , tomlKeyValue (tomlKey "localIP") (TomlString "127.0.0.1")
         , tomlKeyValue (tomlKey "localPort") (TomlInteger localPort)
         , tomlKeyValue (tomlKey "remotePort") (TomlInteger (taowaProfileRemotePort profile))
         ]

authLines :: Maybe Text -> [TomlLine]
authLines maybeToken =
  case Text.strip <$> maybeToken of
    Just token | not (Text.null token) -> [tomlKeyValue (tomlPath "auth" ["token"]) (TomlString token)]
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
