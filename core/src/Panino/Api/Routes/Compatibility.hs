{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Compatibility
  ( compatibilityEvaluateResponse
  , compatibilityExplainResponse
  ) where

import Control.Applicative ((<|>))
import Data.Aeson
  ( object
  , (.=)
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Types
  ( status200
  , status400
  )
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Params (decodeBody)
import Panino.Api.Response (jsonResponse)
import Panino.Api.Server.State
  ( ServerState(..)
  )
import Panino.Compatibility.Evaluate (evaluateCompatibility)
import Panino.Compatibility.Explain (explainCompatibilityReport)
import Panino.Compatibility.Types
  ( CompatibilityEvaluateRequest(..)
  , CompatibilityTarget(..)
  )

compatibilityEvaluateResponse :: ServerState -> Request -> IO Response
compatibilityEvaluateResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= Text.pack err]))
    Right evaluateRequest ->
      pure (jsonResponse status200 (evaluateCompatibility (withDefaultGameDir state evaluateRequest)))

compatibilityExplainResponse :: ServerState -> Request -> IO Response
compatibilityExplainResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= Text.pack err]))
    Right evaluateRequest ->
      pure $
        jsonResponse
          status200
          (explainCompatibilityReport (evaluateCompatibility (withDefaultGameDir state evaluateRequest)))

withDefaultGameDir :: ServerState -> CompatibilityEvaluateRequest -> CompatibilityEvaluateRequest
withDefaultGameDir state request =
  request
    { compatibilityRequestTarget =
        target
          { compatibilityTargetGameDir =
              compatibilityTargetGameDir target <|> stateDefaultGameDir state
          }
    }
  where
    target = compatibilityRequestTarget request
