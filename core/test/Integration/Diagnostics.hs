{-# LANGUAGE OverloadedStrings #-}

module Integration.Diagnostics
  ( assertStructuredDiagnostics
  ) where

import Data.Aeson (encode)
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.List (isInfixOf)
import qualified Data.Text as Text
import Panino.Diagnostics.Classify
  ( classifyFailure
  , diagnosticFromBlockedReason
  )
import Panino.Diagnostics.Types
  ( Diagnostic(..)
  , DiagnosticAction(..)
  , DiagnosticEvidence(..)
  , FailureInput(..)
  , redactedText
  )
import Panino.Install.Plan.Types (TypedInstallPlan(..))
import Panino.Minecraft.InstallPreflight
  ( LoaderInstallPreflightRequest(..)
  , LoaderInstallPreflightResponse(..)
  , blockedLoaderInstallPreflightResponse
  )
import TestSupport (assertEqual)

assertStructuredDiagnostics :: IO ()
assertStructuredDiagnostics = do
  let input =
        FailureInput
          { failurePhase = "download"
          , failureOperation = "install"
          , failureExceptionText = "HttpException request failed access_token=secret-token"
          , failureContext = [("url", "https://meta.fabricmc.net/v2/versions/loader")]
          , failureTaskId = Just "install-1"
          , failurePlanId = Just "plan-1"
          , failureSource = Nothing
          }
      diagnostic = classifyFailure input
      blockedDiagnostic = diagnosticFromBlockedReason "preflight" "loader" "shader_release_not_found:iris 1.21.5 fabric"
      blockedPreflight =
        blockedLoaderInstallPreflightResponse
          LoaderInstallPreflightRequest
            { preflightMinecraftVersion = "1.21.9"
            , preflightLoader = Just "fabric"
            , preflightLoaderVersion = Nothing
            , preflightShaderLoader = Just "iris"
            , preflightShaderVersion = Nothing
            , preflightGameDir = Just "/tmp/panino-preflight-target"
            , preflightJavaExecutable = Nothing
            , preflightSourceProfile = Nothing
            }
          diagnostic
      redactedSample =
        redactedText $
          Text.unlines
            [ "Authorization: Bearer bearer-secret"
            , "Authorization: Basic basic-secret"
            , "Cookie: sid=cookie-secret"
            , "Set-Cookie: sid=set-cookie-secret"
            , "X-Api-Key: api-key-secret"
            , "X-Auth-Token: auth-token-secret"
            , "X-Ms-Token: ms-secret"
            , "https://example.test/download?sig=url-secret&X-Amz-Signature=aws-secret&AWSAccessKeyId=key-secret"
            , "/Users/sen/Library/Application Support/Panino Launcher"
            , "file:///Users/sen/Downloads/panino.log"
            , "{\"sessionToken\":\"json-secret\",\"clientSecret\":\"client-secret\"}"
            ]
      redactedEvidenceJson =
        BL8.unpack (encode (DiagnosticEvidence "sessionToken" "evidence-secret" False))
  assertEqual "network diagnostic code" "network_error" (diagnosticCode diagnostic)
  assertEqual "diagnostic phase is preserved" "download" (diagnosticPhase diagnostic)
  assertEqual "diagnostic has action" True (not (Text.null (diagnosticActionKind (diagnosticAction diagnostic))))
  assertEqual "diagnostic redacts developer detail" True (maybe False ("<redacted>" `Text.isInfixOf`) (diagnosticDeveloperDetail diagnostic))
  assertEqual "diagnostic redacts Authorization Bearer" False ("bearer-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts Authorization Basic" False ("basic-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts cookies" False ("cookie-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts API key headers" False ("api-key-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts auth token headers" False ("auth-token-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts X-MS headers" False ("ms-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts URL query signatures" False ("url-secret" `Text.isInfixOf` redactedSample || "aws-secret" `Text.isInfixOf` redactedSample || "key-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts local user paths" False ("/Users/sen" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic redacts JSON token fields" False ("json-secret" `Text.isInfixOf` redactedSample || "client-secret" `Text.isInfixOf` redactedSample)
  assertEqual "diagnostic evidence redacts sensitive key values" False ("evidence-secret" `isInfixOf` redactedEvidenceJson)
  assertEqual "diagnostic evidence marks sensitive keys redacted" True ("\"redacted\":true" `isInfixOf` redactedEvidenceJson)
  assertEqual "blocked reason maps code" "shader_release_not_found" (diagnosticCode blockedDiagnostic)
  assertEqual "blocked reason maps action" "switchLoader" (diagnosticActionKind (diagnosticAction blockedDiagnostic))
  assertEqual "preflight exception is blocked response" "blocked" (preflightStatus blockedPreflight)
  assertEqual "preflight exception keeps diagnostic" (Just diagnostic) (preflightResponseDiagnostic blockedPreflight)
  assertEqual "preflight exception typed plan blocked" "blocked" (typedPlanStatus (preflightResponseTypedPlan blockedPreflight))
