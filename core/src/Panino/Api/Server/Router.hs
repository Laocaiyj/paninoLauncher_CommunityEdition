{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Server.Router
  ( RouteSpec
  , Captures
  , PathSegment(..)
  , RouteValidationError(..)
  , capture
  , capturesToList
  , exact
  , rest
  , dynamic
  , dispatchRoutes
  , isApiV1Request
  , validateRoutes
  ) where

import Data.List (stripPrefix)
import Data.Maybe (listToMaybe)
import Data.Text (Text)
import Network.HTTP.Types
  ( Method
  , renderStdMethod
  , parseMethod
  )
import Network.Wai
  ( Request
  , Response
  , pathInfo
  , requestMethod
  )
import Panino.Api.Server.State (ServerState)

data PathSegment
  = Static Text
  | Capture
  | CaptureRest
  deriving (Eq, Show)

newtype Captures =
  Captures [Text]
  deriving (Eq, Show)

data RouteValidationError
  = CaptureRestNotFinal Method [PathSegment]
  | DuplicateRoute Method [PathSegment]
  deriving (Eq, Show)

data RouteSpec =
  RouteSpec Method [PathSegment] (Captures -> ServerState -> Request -> IO Response)

capture :: PathSegment
capture = Capture

rest :: PathSegment
rest = CaptureRest

capturesToList :: Captures -> [Text]
capturesToList (Captures captures) = captures

exact :: Method -> [Text] -> (ServerState -> Request -> IO Response) -> RouteSpec
exact method segments handler =
  RouteSpec (canonicalMethod method) (map Static segments) (\_ state request -> handler state request)

dynamic :: Method -> [PathSegment] -> (Captures -> ServerState -> Request -> IO Response) -> RouteSpec
dynamic method segments handler =
  RouteSpec (canonicalMethod method) segments handler

dispatchRoutes :: [RouteSpec] -> ServerState -> Request -> Maybe (IO Response)
dispatchRoutes routes state request = do
  apiPath <- apiV1Path request
  (handler, captures) <- matchFirst (canonicalMethod (requestMethod request)) apiPath routes
  pure (handler captures state request)

isApiV1Request :: Request -> Bool
isApiV1Request request =
  case apiV1Path request of
    Just _ -> True
    Nothing -> False

apiV1Path :: Request -> Maybe [Text]
apiV1Path request =
  stripPrefix ["api", "v1"] (pathInfo request)

matchFirst
  :: Method
  -> [Text]
  -> [RouteSpec]
  -> Maybe ((Captures -> ServerState -> Request -> IO Response), Captures)
matchFirst method path routes =
  listToMaybe
    [ (handler, captures)
    | RouteSpec expectedMethod pattern handler <- routes
    , expectedMethod == method
    , Just captures <- [matchPattern pattern path]
    ]

matchPattern :: [PathSegment] -> [Text] -> Maybe Captures
matchPattern pattern path =
  Captures <$> go pattern path
  where
    go [] [] = Just []
    go [CaptureRest] remainingPath = Just remainingPath
    go (Static expected:patternRest) (actual:pathRest)
      | expected == actual = go patternRest pathRest
    go (Capture:patternRest) (actual:pathRest) =
      (actual :) <$> go patternRest pathRest
    go _ _ = Nothing

validateRoutes :: [RouteSpec] -> [RouteValidationError]
validateRoutes routes =
  invalidCaptureRestRoutes routes <> duplicateRoutes routes

invalidCaptureRestRoutes :: [RouteSpec] -> [RouteValidationError]
invalidCaptureRestRoutes routes =
  [ CaptureRestNotFinal method pattern
  | RouteSpec method pattern _ <- routes
  , not (captureRestIsFinal pattern)
  ]

captureRestIsFinal :: [PathSegment] -> Bool
captureRestIsFinal [] = True
captureRestIsFinal [CaptureRest] = True
captureRestIsFinal (CaptureRest:_) = False
captureRestIsFinal (_:restPattern) = captureRestIsFinal restPattern

duplicateRoutes :: [RouteSpec] -> [RouteValidationError]
duplicateRoutes [] = []
duplicateRoutes (RouteSpec method pattern _:restRoutes)
  | any (sameRoute method pattern) restRoutes =
      DuplicateRoute method pattern : duplicateRoutes restRoutes
  | otherwise =
      duplicateRoutes restRoutes

sameRoute :: Method -> [PathSegment] -> RouteSpec -> Bool
sameRoute method pattern (RouteSpec otherMethod otherPattern _) =
  method == otherMethod && pattern == otherPattern

canonicalMethod :: Method -> Method
canonicalMethod method =
  case parseMethod method of
    Right parsed -> renderStdMethod parsed
    Left _ -> method
