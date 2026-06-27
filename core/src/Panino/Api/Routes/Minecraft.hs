{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.Minecraft
  ( installResponse
  , installPreflightResponse
  , installPreflightForRequest
  , launchResponse
  , requestLayout
  ) where

import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import Data.Aeson
  ( object
  , (.=)
  )
import Data.Text (Text)
import qualified Data.Text as Text
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
import Panino.Api.Response
  ( diagnosticErrorResponse
  , jsonResponse
  )
import Panino.Api.Routes.Minecraft.Common
  ( appSupportRoot
  , missingGameDir
  , requestLayout
  , resolveReadyLoaderInstallerJavaPath
  )
import Panino.Api.Routes.Minecraft.InstallTask (runInstallTask)
import Panino.Api.Routes.Minecraft.LaunchTask (runLaunchTask)
import Panino.Api.Routes.Tasks
  ( startTaskWithGameDirContext
  , startTaskWithGameDirContextAndComponents
  )
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( InstallRequest(..)
  , LaunchRequest(..)
  , TaskAccepted(..)
  , installRequestGameDirPath
  , installRequestVersionText
  , launchRequestGameDirPath
  , launchRequestVersionText
  )
import Panino.Diagnostics.Classify
  ( classifyFailure
  , diagnosticForApiError
  )
import Panino.Diagnostics.Types (FailureInput(..))
import Panino.Minecraft.InstallPreflight
  ( LoaderInstallPreflightResponse(..)
  , blockedLoaderInstallPreflightResponse
  , loaderInstallPreflight
  , preflightFromInstallRequest
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout
  , mkLayout
  )
import Panino.Runtime.Java.Resolve (resolveJavaRuntimeForVersion)
import Panino.Runtime.Java.Types (JavaRuntimeResolveResponse)
import System.FilePath ((</>))

installResponse :: ServerState -> Request -> IO Response
installResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (diagnosticErrorResponse status400 "invalid_json" (diagnosticForApiError "metadata_parse_failed" "prepare" (Text.pack err)))
    Right installRequest
      | missingGameDir (installRequestGameDir installRequest) ->
          pure (diagnosticErrorResponse status400 "game_dir_required" (diagnosticForApiError "target_directory_not_writable" "prepare" "game_dir_required"))
      | otherwise -> do
          preflightOutcome <- try (installPreviewPreflightForRequest state installRequest)
          case preflightOutcome of
            Left (err :: SomeException) ->
              pure (installPreflightBlockedResponse installRequest "install_preflight_failed" (preflightFailureResponse installRequest err))
            Right preflight
              | preflightHasBlockedReasons preflight ->
                  pure (installPreflightBlockedResponse installRequest "install_preflight_blocked" preflight)
              | otherwise -> do
                  task <-
                    startTaskWithGameDirContextAndComponents
                      state
                      "install"
                      (installRequestVersionText installRequest)
                      (installRequestGameDirPath installRequest)
                      (installRequestLoader installRequest)
                      (installRequestShaderLoader installRequest)
                      $ \taskSnapshot ->
                        runInstallTask state taskSnapshot installRequest preflight
                  pure (jsonResponse status202 (TaskAccepted task))

installPreflightResponse :: ServerState -> Request -> IO Response
installPreflightResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (diagnosticErrorResponse status400 "invalid_json" (diagnosticForApiError "metadata_parse_failed" "preflight" (Text.pack err)))
    Right installRequest -> do
      preflightOutcome <- try (installPreviewPreflightForRequest state installRequest)
      let preflight =
            case preflightOutcome of
              Right value -> value
              Left (err :: SomeException) -> preflightFailureResponse installRequest err
      pure (jsonResponse status200 preflight)

installPreviewPreflightForRequest :: ServerState -> InstallRequest -> IO LoaderInstallPreflightResponse
installPreviewPreflightForRequest state installRequest = do
  previewLayout <- resolvePreviewPreflightLayout state
  installPreflightForRequestWithLayout state installRequest (Just previewLayout)

installPreflightForRequest :: ServerState -> InstallRequest -> IO LoaderInstallPreflightResponse
installPreflightForRequest state installRequest = do
  maybeLayout <- resolvePreflightLayout installRequest
  installPreflightForRequestWithLayout state installRequest maybeLayout

installPreflightForRequestWithLayout :: ServerState -> InstallRequest -> Maybe MinecraftLayout -> IO LoaderInstallPreflightResponse
installPreflightForRequestWithLayout state installRequest maybeLayout = do
  installerJava <- resolvePreflightInstallerJava state installRequest maybeLayout
  basePreflight <- loaderInstallPreflight (stateHttpManager state) (preflightFromInstallRequest installRequest installerJava)
  javaRuntime <- resolvePreflightJavaRuntime state installRequest maybeLayout
  pure (basePreflight { preflightResponseJavaRuntime = javaRuntime })

installPreflightBlockedResponse :: InstallRequest -> Text -> LoaderInstallPreflightResponse -> Response
installPreflightBlockedResponse _ errorCode preflight =
  jsonResponse
    status400
    ( object
        [ "error" .= errorCode
        , "blockedReasons" .= preflightResponseBlockedReasons preflight
        , "diagnostic" .= preflightResponseDiagnostic preflight
        , "structuredDiagnostics" .= preflightResponseStructuredDiagnostics preflight
        , "preflight" .= preflight
        ]
    )

preflightFailureResponse :: InstallRequest -> SomeException -> LoaderInstallPreflightResponse
preflightFailureResponse installRequest err =
  blockedLoaderInstallPreflightResponse
    (preflightFromInstallRequest installRequest Nothing)
    diagnostic
  where
    detail = Text.pack (displayException err)
    diagnostic =
      classifyFailure
        FailureInput
          { failurePhase = "preflight"
          , failureOperation = "minecraft install preflight"
          , failureExceptionText = detail
          , failureContext = [("minecraftVersion", installRequestVersionText installRequest)]
          , failureTaskId = Nothing
          , failurePlanId = Nothing
          , failureSource = Just "core"
          }

resolvePreflightLayout :: InstallRequest -> IO (Maybe MinecraftLayout)
resolvePreflightLayout installRequest =
  case installRequestGameDir installRequest of
    Just _ -> Just <$> mkLayout (installRequestGameDirPath installRequest)
    _ -> pure Nothing

resolvePreviewPreflightLayout :: ServerState -> IO MinecraftLayout
resolvePreviewPreflightLayout state = do
  root <- appSupportRoot state
  mkLayout (Just (root </> ".panino" </> "preflight-cache"))

resolvePreflightInstallerJava :: ServerState -> InstallRequest -> Maybe MinecraftLayout -> IO (Maybe FilePath)
resolvePreflightInstallerJava _ _ Nothing =
  pure Nothing
resolvePreflightInstallerJava state installRequest (Just layout) = do
  outcome <-
    try
      ( resolveReadyLoaderInstallerJavaPath
          state
          layout
          (installRequestVersionText installRequest)
          (installRequestLoader installRequest)
      )
  pure $ case outcome of
    Right javaPath -> javaPath
    Left (_ :: SomeException) -> Nothing

resolvePreflightJavaRuntime :: ServerState -> InstallRequest -> Maybe MinecraftLayout -> IO (Maybe JavaRuntimeResolveResponse)
resolvePreflightJavaRuntime _ _ Nothing =
  pure Nothing
resolvePreflightJavaRuntime state installRequest (Just layout) = do
  outcome <- try $ do
    appRoot <- appSupportRoot state
    resolveJavaRuntimeForVersion (stateHttpManager state) appRoot layout (installRequestVersionText installRequest)
  pure $ case outcome of
    Right response -> Just response
    Left (_ :: SomeException) -> Nothing

preflightHasBlockedReasons :: LoaderInstallPreflightResponse -> Bool
preflightHasBlockedReasons =
  not . null . preflightResponseBlockedReasons

launchResponse :: ServerState -> Request -> IO Response
launchResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right launchRequest
      | missingGameDir (launchRequestGameDir launchRequest) ->
          pure (jsonResponse status400 (object ["error" .= ("game_dir_required" :: Text)]))
      | otherwise -> do
          task <-
            startTaskWithGameDirContext state "launch" (launchRequestVersionText launchRequest) (launchRequestGameDirPath launchRequest) $ \taskSnapshot ->
              runLaunchTask state taskSnapshot launchRequest
          pure (jsonResponse status202 (TaskAccepted task))
