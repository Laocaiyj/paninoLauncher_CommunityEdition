{-# LANGUAGE OverloadedStrings #-}

module Panino.Runtime.Java.Resolve
  ( resolveJavaRuntime
  , resolveJavaRuntimeForRequirement
  , resolveJavaRuntimeForVersion
  ) where

import Control.Applicative ((<|>))
import Data.List
  ( find
  , sortOn
  )
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Local.Java
  ( checkJavaRuntime
  , scanJavaRuntimes
  )
import Panino.Content.Local.Types
  ( JavaCheckRequest(..)
  , JavaCheckResponse(..)
  , JavaRuntimeCandidate(..)
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout
  , mkLayout
  )
import Panino.Minecraft.Manifest (loadVersionJson)
import Panino.Runtime.Java.Catalog
  ( catalogForRuntime
  , defaultRuntimeArch
  , defaultRuntimeOs
  )
import Panino.Runtime.Java.Requirements (javaRequirementForVersionJson)
import Panino.Runtime.Java.Store
  ( readManagedRuntimes
  , runtimePolicyForInstance
  )
import Panino.Runtime.Java.Types
  ( JavaManagedRuntime(..)
  , JavaRuntimePolicyRecord(..)
  , JavaRuntimeResolveRequest(..)
  , JavaRuntimeResolveResponse(..)
  , JavaRuntimeRequirement(..)
  , catalogRuntimeDownload
  )

resolveJavaRuntime :: Manager -> FilePath -> Maybe MinecraftLayout -> JavaRuntimeResolveRequest -> IO JavaRuntimeResolveResponse
resolveJavaRuntime manager appRoot maybeLayout request = do
  layout <- maybe (mkLayout (resolveGameDir request)) pure maybeLayout
  versionJson <- loadVersionJson manager layout (resolveMinecraftVersion request)
  let requirement = javaRequirementForVersionJson (resolveMinecraftVersion request) versionJson
  resolveJavaRuntimeForRequirement appRoot request requirement

resolveJavaRuntimeForVersion :: Manager -> FilePath -> MinecraftLayout -> Text -> IO JavaRuntimeResolveResponse
resolveJavaRuntimeForVersion manager appRoot layout version = do
  versionJson <- loadVersionJson manager layout version
  let request =
        JavaRuntimeResolveRequest
          { resolveMinecraftVersion = version
          , resolveGameDir = Nothing
          , resolveInstanceId = Nothing
          , resolvePolicy = Just "auto"
          , resolvePreferredRuntimeId = Nothing
          , resolveCustomPath = Nothing
          }
      requirement = javaRequirementForVersionJson version versionJson
  resolveJavaRuntimeForRequirement appRoot request requirement

resolveJavaRuntimeForRequirement :: FilePath -> JavaRuntimeResolveRequest -> JavaRuntimeRequirement -> IO JavaRuntimeResolveResponse
resolveJavaRuntimeForRequirement appRoot request requirement = do
  effectiveRequest <- applyStoredPolicy appRoot request
  let policy = normalizePolicy (resolvePolicy effectiveRequest)
  case policy of
    "custom" ->
      resolveCustomRuntimePath effectiveRequest requirement policy
    "managed" -> do
      managed <- readManagedRuntimes appRoot
      case preferredOrMatchingManaged effectiveRequest requirement managed of
        Just runtime ->
          pure (readyManagedResponse effectiveRequest requirement policy runtime)
        Nothing ->
          pure $
            (baseResponse effectiveRequest requirement policy "incompatible")
              { resolveResponseActions = ["choose_java", "download_java"]
              , resolveResponseBlockingReasons =
                  [ "Selected managed Java runtime does not match Java "
                      <> Text.pack (show (javaRequirementMajorVersion requirement))
                  ]
              }
    "local" -> do
      local <- matchingLocalRuntime requirement
      case local of
        Just status ->
          pure (readyLocalResponse effectiveRequest requirement policy status)
        Nothing ->
          pure $
            (baseResponse effectiveRequest requirement policy "missing")
              { resolveResponseActions = ["choose_java", "download_java"]
              , resolveResponseBlockingReasons =
                  [ "No local Java runtime matches Java "
                      <> Text.pack (show (javaRequirementMajorVersion requirement))
                  ]
              }
    _ -> do
      managed <- readManagedRuntimes appRoot
      case preferredOrExactManaged effectiveRequest requirement managed of
        Just runtime ->
          pure (readyManagedResponse effectiveRequest requirement policy runtime)
        Nothing -> do
          local <- matchingExactLocalRuntime requirement
          case local of
            Just status ->
              pure (readyLocalResponse effectiveRequest requirement policy status)
            Nothing ->
              pure (downloadableResponse effectiveRequest requirement policy)

applyStoredPolicy :: FilePath -> JavaRuntimeResolveRequest -> IO JavaRuntimeResolveRequest
applyStoredPolicy appRoot request
  | hasExplicitPolicy request = pure request
  | otherwise = do
      maybePolicy <- runtimePolicyForInstance appRoot (resolveInstanceId request)
      pure $
        case maybePolicy of
          Nothing -> request
          Just policy -> applyPolicyRecord policy request

hasExplicitPolicy :: JavaRuntimeResolveRequest -> Bool
hasExplicitPolicy request =
  resolvePolicy request /= Nothing
    || resolvePreferredRuntimeId request /= Nothing
    || resolveCustomPath request /= Nothing

applyPolicyRecord :: JavaRuntimePolicyRecord -> JavaRuntimeResolveRequest -> JavaRuntimeResolveRequest
applyPolicyRecord policy request =
  request
    { resolvePolicy = Just (policyRecordPolicy policy)
    , resolvePreferredRuntimeId = policyRecordPreferredRuntimeId policy
    , resolveCustomPath = policyRecordCustomPath policy
    }

resolveCustomRuntimePath :: JavaRuntimeResolveRequest -> JavaRuntimeRequirement -> Text -> IO JavaRuntimeResolveResponse
resolveCustomRuntimePath request requirement policy =
  case resolveCustomPath request of
    Nothing ->
      pure $
        (baseResponse request requirement policy "blocked")
          { resolveResponseBlockingReasons = ["custom Java policy requires a java path"]
          , resolveResponseActions = ["choose_java"]
          }
    Just javaPath -> do
      status <- checkJavaRuntime (JavaCheckRequest (Just javaPath))
      if javaResponseAvailable status && javaMatchesRequirement requirement status
        then pure (readyLocalResponse request requirement policy status)
        else
          pure $
            (baseResponse request requirement policy "incompatible")
              { resolveResponseJavaExecutable = Just javaPath
              , resolveResponseBlockingReasons =
                  [ "Java runtime does not match required Java "
                      <> Text.pack (show (javaRequirementMajorVersion requirement))
                  ]
              , resolveResponseActions = ["choose_java", "download_java"]
              }

preferredOrMatchingManaged :: JavaRuntimeResolveRequest -> JavaRuntimeRequirement -> [JavaManagedRuntime] -> Maybe JavaManagedRuntime
preferredOrMatchingManaged request requirement runtimes =
  preferred <|> matching
  where
    preferred =
      resolvePreferredRuntimeId request >>= \runtimeId ->
        find (\runtime -> managedRuntimeId runtime == runtimeId && managedMatchesRequirement requirement runtime) runtimes
    matching =
      listToMaybe $
        sortOn (managedRuntimeMatchRank requirement) $
          filter (managedMatchesRequirement requirement) runtimes

preferredOrExactManaged :: JavaRuntimeResolveRequest -> JavaRuntimeRequirement -> [JavaManagedRuntime] -> Maybe JavaManagedRuntime
preferredOrExactManaged request requirement runtimes =
  preferred <|> exactMatching
  where
    preferred =
      resolvePreferredRuntimeId request >>= \runtimeId ->
        find (\runtime -> managedRuntimeId runtime == runtimeId && managedMatchesRequirement requirement runtime) runtimes
    exactMatching =
      listToMaybe $
        sortOn managedRuntimeId $
          filter (managedMatchesExactRequirement requirement) runtimes

managedMatchesRequirement :: JavaRuntimeRequirement -> JavaManagedRuntime -> Bool
managedMatchesRequirement requirement runtime =
  javaMajorCompatible (javaRequirementMajorVersion requirement) (managedRuntimeFeatureVersion runtime)
    && normalizeArch (managedRuntimeArch runtime) == normalizeArch defaultRuntimeArch

managedMatchesExactRequirement :: JavaRuntimeRequirement -> JavaManagedRuntime -> Bool
managedMatchesExactRequirement requirement runtime =
  managedRuntimeFeatureVersion runtime == javaRequirementMajorVersion requirement
    && normalizeArch (managedRuntimeArch runtime) == normalizeArch defaultRuntimeArch

managedRuntimeMatchRank :: JavaRuntimeRequirement -> JavaManagedRuntime -> (Bool, Int, Text)
managedRuntimeMatchRank requirement runtime =
  javaMajorMatchRank requirement (managedRuntimeFeatureVersion runtime, managedRuntimeId runtime)

matchingLocalRuntime :: JavaRuntimeRequirement -> IO (Maybe JavaCheckResponse)
matchingLocalRuntime requirement = do
  candidates <- scanJavaRuntimes
  checks <- traverse checkCandidate (filter javaCandidateAvailable candidates)
  pure $
    listToMaybe $
      sortOn (localRuntimeMatchRank requirement) $
        filter (javaMatchesRequirement requirement) checks
  where
    checkCandidate candidate =
      checkJavaRuntime (JavaCheckRequest (Just (javaCandidatePath candidate)))

matchingExactLocalRuntime :: JavaRuntimeRequirement -> IO (Maybe JavaCheckResponse)
matchingExactLocalRuntime requirement = do
  candidates <- scanJavaRuntimes
  checks <- traverse checkCandidate (filter javaCandidateAvailable candidates)
  pure $
    listToMaybe $
      sortOn (Text.pack . javaResponsePath) $
        filter (javaMatchesExactRequirement requirement) checks
  where
    checkCandidate candidate =
      checkJavaRuntime (JavaCheckRequest (Just (javaCandidatePath candidate)))

javaMatchesRequirement :: JavaRuntimeRequirement -> JavaCheckResponse -> Bool
javaMatchesRequirement requirement status =
  javaResponseAvailable status
    && maybe False (javaMajorCompatible (javaRequirementMajorVersion requirement)) (javaResponseMajorVersion status)
    && maybe True ((== normalizeArch defaultRuntimeArch) . normalizeArch) (javaResponseArchitecture status)

javaMatchesExactRequirement :: JavaRuntimeRequirement -> JavaCheckResponse -> Bool
javaMatchesExactRequirement requirement status =
  javaResponseAvailable status
    && javaResponseMajorVersion status == Just (javaRequirementMajorVersion requirement)
    && maybe True ((== normalizeArch defaultRuntimeArch) . normalizeArch) (javaResponseArchitecture status)

localRuntimeMatchRank :: JavaRuntimeRequirement -> JavaCheckResponse -> (Bool, Int, Text)
localRuntimeMatchRank requirement status =
  javaMajorMatchRank requirement (fromMaybe maxBound (javaResponseMajorVersion status), Text.pack (javaResponsePath status))

javaMajorMatchRank :: JavaRuntimeRequirement -> (Int, Text) -> (Bool, Int, Text)
javaMajorMatchRank requirement (actualMajor, tieBreaker) =
  ( actualMajor /= requiredMajor
  , if actualMajor >= requiredMajor then actualMajor - requiredMajor else maxBound
  , tieBreaker
  )
  where
    requiredMajor = javaRequirementMajorVersion requirement

javaMajorCompatible :: Int -> Int -> Bool
javaMajorCompatible required actual
  | required >= 17 = actual >= required
  | otherwise = actual == required

readyManagedResponse :: JavaRuntimeResolveRequest -> JavaRuntimeRequirement -> Text -> JavaManagedRuntime -> JavaRuntimeResolveResponse
readyManagedResponse request requirement policy runtime =
  (baseResponse request requirement policy "ready")
    { resolveResponseSelectedRuntimeId = Just (managedRuntimeId runtime)
    , resolveResponseJavaExecutable = Just (managedRuntimeJavaExecutable runtime)
    }

readyLocalResponse :: JavaRuntimeResolveRequest -> JavaRuntimeRequirement -> Text -> JavaCheckResponse -> JavaRuntimeResolveResponse
readyLocalResponse request requirement policy status =
  (baseResponse request requirement policy "ready")
    { resolveResponseJavaExecutable = Just (javaResponsePath status)
    , resolveResponseWarnings =
        [ "using local Java runtime"
        | policy /= "custom"
        ]
    }

downloadableResponse :: JavaRuntimeResolveRequest -> JavaRuntimeRequirement -> Text -> JavaRuntimeResolveResponse
downloadableResponse request requirement policy =
  (baseResponse request requirement policy "downloadable")
    { resolveResponseDownload = Just (catalogRuntimeDownload catalog)
    , resolveResponseActions = ["download_java"]
    , resolveResponseWarnings =
        [ "Java "
            <> Text.pack (show (javaRequirementMajorVersion requirement))
            <> " is not installed yet."
        ]
    }
  where
    catalog =
      head (catalogForRuntime (javaRequirementMajorVersion requirement) defaultRuntimeOs defaultRuntimeArch "jre")

baseResponse :: JavaRuntimeResolveRequest -> JavaRuntimeRequirement -> Text -> Text -> JavaRuntimeResolveResponse
baseResponse request requirement policy status =
  JavaRuntimeResolveResponse
    { resolveResponseMinecraftVersion = resolveMinecraftVersion request
    , resolveResponseRequiredMajorVersion = javaRequirementMajorVersion requirement
    , resolveResponseRequirementSource = javaRequirementSource requirement
    , resolveResponsePolicy = policy
    , resolveResponseStatus = status
    , resolveResponseSelectedRuntimeId = Nothing
    , resolveResponseJavaExecutable = Nothing
    , resolveResponseDownload = Nothing
    , resolveResponseActions = []
    , resolveResponseWarnings = []
    , resolveResponseBlockingReasons = []
    }

normalizePolicy :: Maybe Text -> Text
normalizePolicy Nothing = "auto"
normalizePolicy (Just value)
  | normalized `elem` ["auto", "managed", "local", "custom"] = normalized
  | otherwise = "auto"
  where
    normalized = Text.toLower (Text.strip value)

normalizeArch :: Text -> Text
normalizeArch value =
  case Text.toLower value of
    "x86_64" -> "x64"
    "amd64" -> "x64"
    "arm64" -> "aarch64"
    other -> other
