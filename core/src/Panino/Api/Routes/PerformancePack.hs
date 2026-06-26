{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.PerformancePack
  ( PerformancePackInstallRequest(..)
  , PerformancePackPlan(..)
  , ResolvedPerformancePackPlan(..)
  , buildPerformancePackPlan
  , performancePackInstallResponse
  , performancePackPlanResponse
  , performancePackRollbackResponse
  ) where

import Data.Aeson
  ( object
  , (.=)
  )
import Data.Text (Text)
import Network.HTTP.Types
  ( status200
  , status202
  , status400
  )
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Params (decodeBody)
import Panino.Api.Response (jsonResponse)
import Panino.Api.Routes.PerformancePack.Install (runPerformancePackInstallTask)
import Panino.Api.Routes.PerformancePack.Plan (buildPerformancePackPlan)
import Panino.Api.Routes.PerformancePack.Rollback (performancePackRollbackResponse)
import Panino.Api.Routes.PerformancePack.Types
  ( PerformancePackInstallRequest(..)
  , PerformancePackPlan(..)
  , ResolvedPerformancePackPlan(..)
  , packPlanBlockedReasons
  , packPlanTitle
  , resolvedPerformancePlan
  )
import Panino.Api.Routes.Tasks (startTaskWithGameDirContext)
import Panino.Api.Server.State (ServerState)
import Panino.Api.Types (TaskAccepted(..))

performancePackPlanResponse :: ServerState -> Request -> IO Response
performancePackPlanResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right installRequest -> do
      resolved <- buildPerformancePackPlan state installRequest
      pure (jsonResponse status200 (resolvedPerformancePlan resolved))

performancePackInstallResponse :: ServerState -> Request -> IO Response
performancePackInstallResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right installRequest -> do
      resolved <- buildPerformancePackPlan state installRequest
      let plan = resolvedPerformancePlan resolved
      if not (null (packPlanBlockedReasons plan))
        then
          pure $
            jsonResponse
              status400
              (object ["error" .= ("performance_pack_plan_blocked" :: Text), "plan" .= plan])
        else do
          task <-
            startTaskWithGameDirContext state "performance-pack-install" (packPlanTitle plan) (Just (packInstallGameDir installRequest)) $ \taskSnapshot ->
              runPerformancePackInstallTask state taskSnapshot installRequest resolved
          pure (jsonResponse status202 (TaskAccepted task))
