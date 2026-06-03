{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Content
  ( contentDownloadJobsFromTypedPlan
  , contentInstallPlanResponse
  , contentInstallResponse
  , contentLoadersResponse
  , contentMinecraftInstallStatusResponse
  , contentMinecraftInstalledInstancesResponse
  , contentMinecraftPackageResponse
  , contentMinecraftVersionsResponse
  , contentProjectResponse
  , contentResolveTargetsResponse
  , contentSearchResponse
  , contentTypedInstallPlan
  , contentUpdatePlanResponse
  , buildContentInstallPlan
  , resolveContentUpdatePlan
  ) where

import Data.Aeson (object, (.=))
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Types (status200, status202, status400)
import Network.Wai (Request, Response)
import Panino.Api.Params (decodeBody)
import Panino.Api.Response (jsonResponse)
import Panino.Api.Routes.Content.Cache
  ( contentLoadersResponse
  , contentMinecraftInstallStatusResponse
  , contentMinecraftInstalledInstancesResponse
  , contentMinecraftPackageResponse
  , contentMinecraftVersionsResponse
  , contentProjectResponse
  , contentSearchResponse
  )
import Panino.Api.Routes.Content.InstallPlan
  ( ContentInstallPlanBundle(..)
  , buildContentInstallPlan
  , buildContentInstallPlanBundle
  , contentTypedInstallPlan
  )
import Panino.Api.Routes.Content.Targets (resolveContentTargets)
import Panino.Api.Routes.Content.Task
  ( contentDownloadJobsFromTypedPlan
  , runContentInstallTask
  )
import Panino.Api.Routes.Content.UpdatePlan (resolveContentUpdatePlan)
import Panino.Api.Routes.Tasks (startTaskWithGameDirContext)
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types

contentInstallPlanResponse :: ServerState -> Request -> IO Response
contentInstallPlanResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right contentRequest ->
      jsonResponse status200 <$> buildContentInstallPlan state contentRequest

contentUpdatePlanResponse :: ServerState -> Request -> IO Response
contentUpdatePlanResponse _ request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right updateRequest ->
      pure (jsonResponse status200 (resolveContentUpdatePlan updateRequest))

contentInstallResponse :: ServerState -> Request -> IO Response
contentInstallResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right contentRequest -> do
      planBundle <- buildContentInstallPlanBundle state contentRequest
      let plan = contentPlanBundleResponse planBundle
      if null (contentPlanBlockedReasons plan)
        then do
          task <-
            startTaskWithGameDirContext state "content-install" (contentInstallProjectTitle contentRequest) (contentInstallGameDir contentRequest) $ \taskSnapshot ->
              runContentInstallTask state taskSnapshot contentRequest planBundle
          pure (jsonResponse status202 (TaskAccepted task))
        else
          pure
            ( jsonResponse
                status400
                ( object
                    [ "error" .= ("install_plan_blocked" :: Text)
                    , "plan" .= plan
                    ]
                )
            )

contentResolveTargetsResponse :: ServerState -> Request -> IO Response
contentResolveTargetsResponse _ request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right targetRequest ->
      pure (jsonResponse status200 (resolveContentTargets targetRequest))
