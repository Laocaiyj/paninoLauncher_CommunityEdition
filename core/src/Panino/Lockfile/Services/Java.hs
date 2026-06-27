{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Lockfile.Services.Java
  ( javaExecutableFromPolicy
  , javaRuntimeServiceEvidence
  , lockfileSolveCacheGameDir
  ) where

import Control.Applicative ((<|>))
import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import Data.Aeson
  ( Value(Object, String)
  , object
  , (.=)
  )
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.CoreLogic.Hashing (sha1File)
import Panino.Core.Types
  ( projectIdFromText
  , urlFromText
  , versionIdFromText
  )
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Lockfile.Services.Evidence
  ( ServiceEvidence(..)
  , emptyServiceEvidence
  , serviceBlocked
  )
import Panino.Lockfile.Types
  ( LockfileSolveRequest(..)
  , PackageCoordinate(..)
  , ResolvedPackage(..)
  , solveRequestMinecraftVersionText
  , solveRequestTargetGameDirPath
  )
import Panino.Minecraft.Layout
  ( mkLayout
  )
import Panino.Runtime.Java.Resolve
  ( resolveJavaRuntime
  )
import Panino.Runtime.Java.Types
  ( JavaRuntimeDownloadSpec(..)
  , JavaRuntimeResolveRequest(..)
  , JavaRuntimeResolveResponse(..)
  )
import System.Directory
  ( doesFileExist
  )
import System.FilePath
  ( takeDirectory
  , (</>)
  )

javaRuntimeServiceEvidence :: Manager -> LockfileSolveRequest -> IO ServiceEvidence
javaRuntimeServiceEvidence manager request =
  case solveRequestMinecraftVersionText request of
    Nothing -> pure emptyServiceEvidence
    Just minecraftVersion -> do
      let targetGameDir = solveRequestTargetGameDirPath request
          appRoot = takeDirectory targetGameDir
      cacheLayout <- mkLayout (Just (lockfileSolveCacheGameDir targetGameDir))
      outcome <-
        try
          ( resolveJavaRuntime
              manager
              appRoot
              (Just cacheLayout)
              (javaResolveRequest request minecraftVersion)
          )
      case outcome of
        Left (err :: SomeException) ->
          pure (serviceBlocked ("java_runtime_resolve_failed:" <> Text.pack (displayException err)))
        Right response -> do
          javaPolicyValue <- javaRuntimePolicyValue response
          pure
            emptyServiceEvidence
              { servicePackages = [javaRuntimePackage response]
              , serviceWarnings = resolveResponseWarnings response
              , serviceBlockedReasons = javaRuntimeBlockedReasons response
              , serviceDiagnostics =
                  map (diagnosticFromBlockedReason "solve" "java runtime") (javaRuntimeBlockedReasons response)
              , serviceJavaPolicy = Just javaPolicyValue
              }

lockfileSolveCacheGameDir :: FilePath -> FilePath
lockfileSolveCacheGameDir targetGameDir =
  takeDirectory targetGameDir </> ".panino" </> "lockfile-solve-cache"

javaExecutableFromPolicy :: Maybe Value -> Maybe FilePath
javaExecutableFromPolicy (Just (Object obj)) =
  case lookupJavaValue "javaExecutable" obj <|> lookupJavaValue "customPath" obj <|> lookupJavaValue "java" obj <|> lookupJavaValue "path" obj of
    Just (String value) | not (Text.null value) -> Just (Text.unpack value)
    _ -> Nothing
javaExecutableFromPolicy _ =
  Nothing

javaResolveRequest :: LockfileSolveRequest -> Text -> JavaRuntimeResolveRequest
javaResolveRequest request minecraftVersion =
  JavaRuntimeResolveRequest
    { resolveMinecraftVersion = minecraftVersion
    , resolveGameDir = Just (solveRequestTargetGameDirPath request)
    , resolveInstanceId = javaPolicyText "instanceId" request
    , resolvePolicy = javaPolicyText "policy" request
    , resolvePreferredRuntimeId = javaPolicyText "preferredRuntimeId" request
    , resolveCustomPath =
        javaPolicyPath "customPath" request
          <|> javaPolicyPath "java" request
          <|> javaExecutableFromPolicy (solveRequestJavaPolicy request)
    }

javaPolicyText :: Text -> LockfileSolveRequest -> Maybe Text
javaPolicyText key request =
  case solveRequestJavaPolicy request of
    Just (Object obj) ->
      case lookupJavaValue key obj of
        Just (String value) | not (Text.null value) -> Just value
        _ -> Nothing
    _ -> Nothing

javaPolicyPath :: Text -> LockfileSolveRequest -> Maybe FilePath
javaPolicyPath key request =
  Text.unpack <$> javaPolicyText key request

javaRuntimeBlockedReasons :: JavaRuntimeResolveResponse -> [Text]
javaRuntimeBlockedReasons response
  | resolveResponseStatus response `elem` ["blocked", "missing", "incompatible"] =
      if null (resolveResponseBlockingReasons response)
        then ["java_runtime_unavailable:" <> Text.pack (show (resolveResponseRequiredMajorVersion response))]
        else resolveResponseBlockingReasons response
  | otherwise = []

javaRuntimePackage :: JavaRuntimeResolveResponse -> ResolvedPackage
javaRuntimePackage response =
  ResolvedPackage
    { resolvedPackageId = "java:" <> Text.pack (show (resolveResponseRequiredMajorVersion response))
    , resolvedPackageCoordinate =
        PackageCoordinate
          { coordinateSource = "javaRuntime"
          , coordinateProjectId = projectIdFromText javaProjectId
          , coordinateVersionId =
              (versionIdFromText =<< resolveResponseSelectedRuntimeId response)
                <|> (versionIdFromText . Text.pack . show . runtimeDownloadFeatureVersion =<< resolveResponseDownload response)
          , coordinateFileId = runtimeDownloadArch <$> resolveResponseDownload response
          , coordinateSlug = Just javaProjectId
          , coordinateName = Just ("Java " <> Text.pack (show (resolveResponseRequiredMajorVersion response)))
          , coordinateKind = "javaRuntime"
          }
    , resolvedPackageDisplayName = "Java " <> Text.pack (show (resolveResponseRequiredMajorVersion response)) <> " runtime"
    , resolvedPackageVersionName = resolveResponseSelectedRuntimeId response
    , resolvedPackageFileName = Nothing
    , resolvedPackageTargetPath = Nothing
    , resolvedPackageHashes =
        maybe Map.empty
          (\download -> maybe Map.empty (\sha -> Map.singleton "sha256" sha) (runtimeDownloadSha256 download))
          (resolveResponseDownload response)
    , resolvedPackageSize = Nothing
    , resolvedPackageDownloadUrls = maybe [] ((: []) . urlFromText . runtimeDownloadUrl) (resolveResponseDownload response)
    , resolvedPackageGameVersions = [resolveResponseMinecraftVersion response]
    , resolvedPackageLoaders = []
    , resolvedPackageJavaMajor = Just (resolveResponseRequiredMajorVersion response)
    , resolvedPackageSide = Just "client"
    , resolvedPackageSelectedBecause = ["java runtime resolve:" <> resolveResponseStatus response]
    , resolvedPackageLocked = False
    , resolvedPackagePinReason = Nothing
    , resolvedPackageDependencies = []
    , resolvedPackageConflicts = []
    , resolvedPackageSourceSnapshot = Just ("java-runtime:" <> resolveResponseStatus response)
    }
  where
    javaProjectId = "java-" <> Text.pack (show (resolveResponseRequiredMajorVersion response))

javaRuntimePolicyValue :: JavaRuntimeResolveResponse -> IO Value
javaRuntimePolicyValue response = do
  executableSha1 <-
    case resolveResponseJavaExecutable response of
      Nothing -> pure Nothing
      Just path -> do
        exists <- doesFileExist path
        if exists
          then Just <$> sha1File path
          else pure Nothing
  pure $
    object
      [ "resolve" .= response
      , "path" .= resolveResponseJavaExecutable response
      , "executableSha1" .= executableSha1
      ]

lookupJavaValue :: Text -> KeyMap.KeyMap Value -> Maybe Value
lookupJavaValue key obj =
  KeyMap.lookup (Key.fromText key) obj
    <|> ( case KeyMap.lookup (Key.fromString "resolve") obj of
            Just (Object nested) -> KeyMap.lookup (Key.fromText key) nested
            _ -> Nothing
        )
