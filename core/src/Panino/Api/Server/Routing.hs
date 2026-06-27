{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Server.Routing
  ( application
  , route
  ) where

import Data.Aeson
  ( object
  , (.=)
  )
import Data.Text (Text)
import qualified Data.Text.Encoding as Text
import Network.HTTP.Types
  ( hAuthorization
  , status401
  , status404
  , status405
  )
import Network.Wai
  ( Application
  , Request
  , Response
  , requestHeaders
  )
import Panino.Api.Response (jsonResponse)
import Panino.Api.Server.RouteTable (routeTable)
import Panino.Api.Server.State
  ( ServerState(..)
  )
import Panino.Api.Server.Router
  ( dispatchRoutes
  , isApiV1Request
  )

application :: ServerState -> Application
application state request respond =
  respond =<< route state request

route :: ServerState -> Request -> IO Response
route state request
  | not (isAuthorized state request) =
      pure (jsonResponse status401 (object ["error" .= ("unauthorized" :: Text)]))
  | otherwise =
      case dispatchRoutes routeTable state request of
        Just response -> response
        Nothing
          | isApiV1Request request ->
              pure (jsonResponse status405 (object ["error" .= ("method_not_allowed" :: Text)]))
          | otherwise ->
              pure (jsonResponse status404 (object ["error" .= ("not_found" :: Text)]))

isAuthorized :: ServerState -> Request -> Bool
isAuthorized state request =
  lookup hAuthorization (requestHeaders request)
    == Just ("Bearer " <> Text.encodeUtf8 (stateSessionToken state))
