{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.InstallPlan
  ( installPlanResolveResponse
  ) where

import Data.Aeson
  ( FromJSON
  , Value
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Aeson.Types
  ( Parser
  , (.!=)
  , parseEither
  , parseJSON
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
import Panino.Api.Routes.Content
  ( buildContentInstallPlan
  , resolveContentUpdatePlan
  )
import Panino.Api.Routes.Minecraft
  ( installPreflightForRequest
  )
import Panino.Api.Routes.PerformancePack
  ( PerformancePackPlan(..)
  , ResolvedPerformancePackPlan(..)
  , buildPerformancePackPlan
  )
import Panino.Api.Server.State (ServerState)
import Panino.Api.Types
  ( ContentInstallPlanResponse(..)
  , ContentUpdatePlanResponse(..)
  )
import Panino.Content.Configuration.Preflight
  ( modpackPreflight
  )
import Panino.Content.Configuration.Types
  ( ModpackPreflightResponse(..)
  )
import qualified Panino.Install.Plan.Types as Plan
import Panino.Minecraft.InstallPreflight
  ( LoaderInstallPreflightResponse(..)
  )

data InstallPlanResolveRequest = InstallPlanResolveRequest
  { resolvePlanKind :: Text
  , resolvePlanPayload :: Value
  } deriving (Eq, Show)

instance FromJSON InstallPlanResolveRequest where
  parseJSON =
    withObject "InstallPlanResolveRequest" $ \obj ->
      InstallPlanResolveRequest
        <$> obj .: "kind"
        <*> obj .:? "payload" .!= object []

installPlanResolveResponse :: ServerState -> Request -> IO Response
installPlanResolveResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right resolveRequest -> do
      resolved <- resolveTypedPlan state resolveRequest
      case resolved of
        Left err ->
          pure (jsonResponse status400 (object ["error" .= ("install_plan_resolve_failed" :: Text), "message" .= err]))
        Right plan ->
          pure (jsonResponse status200 (installPlanResolvePayload resolveRequest plan))

resolveTypedPlan :: ServerState -> InstallPlanResolveRequest -> IO (Either Text Plan.TypedInstallPlan)
resolveTypedPlan state request =
  case normalizeKind (resolvePlanKind request) of
    "content" ->
      parsePayload "ContentInstallRequest" (resolvePlanPayload request) >>= traverse (fmap contentPlanTypedPlan . buildContentInstallPlan state)
    "update" -> do
      parsed <- parsePayload "ContentUpdatePlanRequest" (resolvePlanPayload request)
      pure (contentUpdateTypedPlan . resolveContentUpdatePlan <$> parsed)
    "modpack" ->
      parsePayload "ModpackPreflightRequest" (resolvePlanPayload request) >>= traverse (fmap modpackPreflightTypedPlan . modpackPreflight)
    "minecraft" ->
      parsePayload "InstallRequest" (resolvePlanPayload request) >>= traverse (fmap preflightResponseTypedPlan . installPreflightForRequest state)
    "minecraftprofile" ->
      parsePayload "InstallRequest" (resolvePlanPayload request) >>= traverse (fmap preflightResponseTypedPlan . installPreflightForRequest state)
    "install" ->
      parsePayload "InstallRequest" (resolvePlanPayload request) >>= traverse (fmap preflightResponseTypedPlan . installPreflightForRequest state)
    "performancepack" ->
      parsePayload "PerformancePackInstallRequest" (resolvePlanPayload request) >>= traverse (fmap (packPlanTypedPlan . resolvedPerformancePlan) . buildPerformancePackPlan state)
    unsupported ->
      pure (Left ("unsupported_install_plan_kind:" <> unsupported))

installPlanResolvePayload :: InstallPlanResolveRequest -> Plan.TypedInstallPlan -> Value
installPlanResolvePayload request plan =
  object
    [ "kind" .= resolvePlanKind request
    , "typedPlan" .= plan
    , "warnings" .= Plan.typedPlanWarnings plan
    , "blockedReasons" .= Plan.typedPlanBlockedReasons plan
    ]

parsePayload :: FromJSON a => String -> Value -> IO (Either Text a)
parsePayload label payload =
  pure $
    case parseEither (parseJSONWithLabel label) payload of
      Left err -> Left (Text.pack err)
      Right value -> Right value

parseJSONWithLabel :: FromJSON a => String -> Value -> Parser a
parseJSONWithLabel _ =
  parseJSON

normalizeKind :: Text -> Text
normalizeKind =
  Text.filter (/= '-') . Text.filter (/= '_') . Text.toLower
