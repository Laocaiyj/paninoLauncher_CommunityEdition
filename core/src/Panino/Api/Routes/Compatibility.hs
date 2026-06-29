{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Compatibility
  ( compatibilityEvaluateResponse
  , compatibilityExplainResponse
  ) where

import Control.Applicative ((<|>))
import Network.HTTP.Types
  ( status200
  )
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Response
  ( decodeJsonBodyResponse
  , jsonResponse
  )
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
compatibilityEvaluateResponse state request =
  decodeJsonBodyResponse request $ \evaluateRequest ->
    pure (jsonResponse status200 (evaluateCompatibility (withDefaultGameDir state evaluateRequest)))

compatibilityExplainResponse :: ServerState -> Request -> IO Response
compatibilityExplainResponse state request =
  decodeJsonBodyResponse request $ \evaluateRequest ->
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
