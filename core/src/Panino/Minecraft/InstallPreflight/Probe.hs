{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Minecraft.InstallPreflight.Probe
  ( probeHttpUrl
  , probeStatusText
  ) where

import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , newMVar
  )
import Control.Exception
  ( SomeException
  , displayException
  , try
  )
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock
  ( NominalDiffTime
  , UTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Network.HTTP.Client
  ( Manager
  , Request(method)
  , httpNoBody
  , requestHeaders
  , responseStatus
  )
import Network.HTTP.Types (statusCode)
import Panino.Content.Online.Http (coreRequest)
import Panino.Net.Sources (resolveSourceUrl)
import System.IO.Unsafe (unsafePerformIO)

data InstallerProbeCacheEntry = InstallerProbeCacheEntry
  { installerProbeCachedAt :: UTCTime
  , installerProbeCachedResult :: Either Text Text
  } deriving (Eq, Show)

{-# NOINLINE installerProbeCache #-}
-- Process-local probe cache. Keep the unsafePerformIO boundary isolated here
-- until this cache is moved into ServerState or an explicit preflight handle.
installerProbeCache :: MVar (Map.Map Text InstallerProbeCacheEntry)
installerProbeCache =
  unsafePerformIO (newMVar Map.empty)

probeHttpUrl :: Manager -> Text -> IO (Either Text Text)
probeHttpUrl manager url = do
  resolvedUrl <- resolveSourceUrl (Text.unpack url)
  cachedInstallerProbe (Text.pack resolvedUrl) $ do
    baseRequest <- coreRequest resolvedUrl []
    headProbe <- tryProbe manager "head" baseRequest { method = "HEAD" }
    case headProbe of
      Right status -> pure (Right status)
      Left headErr
        | isRateLimitedProbe headErr ->
            pure (Left ("head:" <> headErr <> ";cooldown:rate_limited"))
        | otherwise -> do
            getProbe <-
              tryProbe
                manager
                "range-get"
                baseRequest
                  { method = "GET"
                  , requestHeaders = ("Range", "bytes=0-0") : requestHeaders baseRequest
                  }
            pure $ case getProbe of
              Right status -> Right (status <> ":head_failed:" <> headErr)
              Left getErr -> Left ("head:" <> headErr <> ";range-get:" <> getErr)

cachedInstallerProbe :: Text -> IO (Either Text Text) -> IO (Either Text Text)
cachedInstallerProbe cacheKey action = do
  now <- getCurrentTime
  cached <-
    modifyMVar installerProbeCache $ \entries ->
      case Map.lookup cacheKey entries of
        Just entry
          | diffUTCTime now (installerProbeCachedAt entry) <= installerProbeTtl (installerProbeCachedResult entry) ->
              pure (entries, Just (installerProbeCachedResult entry))
        _ ->
          pure (entries, Nothing)
  case cached of
    Just result -> pure (markCachedProbe result)
    Nothing -> do
      result <- action
      finished <- getCurrentTime
      modifyMVar installerProbeCache $ \entries ->
        pure
          ( Map.insert
              cacheKey
              InstallerProbeCacheEntry
                { installerProbeCachedAt = finished
                , installerProbeCachedResult = result
                }
              entries
          , ()
          )
      pure result

installerProbeTtl :: Either Text Text -> NominalDiffTime
installerProbeTtl result
  | either isRateLimitedProbe isRateLimitedProbe result = 900
  | either (const False) (const True) result = 900
  | otherwise = 60

markCachedProbe :: Either Text Text -> Either Text Text
markCachedProbe (Right value) = Right ("cached:" <> value)
markCachedProbe (Left value) = Left ("cached:" <> value)

isRateLimitedProbe :: Text -> Bool
isRateLimitedProbe value =
  let lowered = Text.toLower value
   in "429" `Text.isInfixOf` lowered || "too many requests" `Text.isInfixOf` lowered || "rate_limited" `Text.isInfixOf` lowered

tryProbe :: Manager -> Text -> Request -> IO (Either Text Text)
tryProbe manager label request = do
  outcome <- try $ do
    response <- httpNoBody request manager
    let code = statusCode (responseStatus response)
    if code >= 200 && code < 400
      then pure ()
      else fail ("HTTP " <> show code)
  pure $ case outcome of
    Right () -> Right (label <> ":ok")
    Left (err :: SomeException) -> Left (Text.pack (displayException err))

probeStatusText :: Either Text Text -> Text
probeStatusText (Right value) = value
probeStatusText (Left value) = "failed:" <> value
