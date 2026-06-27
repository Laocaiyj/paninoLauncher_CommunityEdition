{-# LANGUAGE OverloadedStrings #-}

module Integration.ApiServerRouting
  ( assertApiServerRouting
  ) where

import Network.HTTP.Types
  ( methodGet
  , status204
  )
import Network.Wai
  ( Request
  , Response
  , responseLBS
  )
import Panino.Api.Server.RouteTable
  ( routeTable
  )
import Panino.Api.Server.Router
  ( Captures
  , PathSegment(..)
  , RouteValidationError(..)
  , dynamic
  , exact
  , rest
  , validateRoutes
  )
import Panino.Api.Server.State
  ( ServerState
  )
import TestSupport
  ( assertEqual
  )

assertApiServerRouting :: IO ()
assertApiServerRouting = do
  assertEqual "production route table is well formed" [] (validateRoutes routeTable)
  assertEqual
    "route validation rejects rest capture before the end"
    True
    (any isRestNotFinal (validateRoutes [dynamic methodGet [Static "bad", rest, Static "tail"] dynamicNoop]))
  assertEqual
    "route validation rejects duplicate route shape"
    True
    (any isDuplicateRoute (validateRoutes [exact methodGet ["same"] exactNoop, exact methodGet ["same"] exactNoop]))

isRestNotFinal :: RouteValidationError -> Bool
isRestNotFinal (CaptureRestNotFinal _ _) = True
isRestNotFinal _ = False

isDuplicateRoute :: RouteValidationError -> Bool
isDuplicateRoute (DuplicateRoute _ _) = True
isDuplicateRoute _ = False

exactNoop :: ServerState -> Request -> IO Response
exactNoop _ _ =
  pure emptyResponse

dynamicNoop :: Captures -> ServerState -> Request -> IO Response
dynamicNoop _ _ _ =
  pure emptyResponse

emptyResponse :: Response
emptyResponse =
  responseLBS status204 [] ""
