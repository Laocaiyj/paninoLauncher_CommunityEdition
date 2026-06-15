{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Net.Probe
  ( preferFastestRequests
  , preferFastestUrls
  , recordSourceThroughput
  , recordSourceFailure
  , recordSourceHashMismatch
  , sourceHostKey
  ) where

import Control.Applicative ((<|>))
import Control.Concurrent.Async (mapConcurrently)
import Control.Concurrent.MVar
  ( MVar
  , modifyMVar
  , modifyMVar_
  , newMVar
  , readMVar
  )
import Control.Exception
  ( SomeException
  , try
  )
import Data.List
  ( sortOn
  , stripPrefix
  )
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.Time.Clock
  ( NominalDiffTime
  , UTCTime
  , addUTCTime
  , diffUTCTime
  , getCurrentTime
  )
import Network.HTTP.Client
  ( Manager
  , Request
  , getUri
  , httpNoBody
  , method
  , parseRequest
  , responseStatus
  , responseTimeout
  , responseTimeoutMicro
  )
import Network.HTTP.Types (statusCode)
import System.IO.Unsafe (unsafePerformIO)

data SourceProbe = SourceProbe
  { sourceProbeHealthy :: Bool
  , sourceProbeMicros :: Int
  , sourceProbeBytesPerSecond :: Maybe Int
  , sourceProbeFailures :: Int
  , sourceProbeHashMismatches :: Int
  , sourceProbeCooldownUntil :: Maybe UTCTime
  , sourceProbeAt :: UTCTime
  } deriving (Eq, Show)

{-# NOINLINE sourceProbeCache #-}
-- Process-local source probe cache. Keep the unsafePerformIO boundary isolated
-- here until source probing receives an explicit cache handle.
sourceProbeCache :: MVar (Map String SourceProbe)
sourceProbeCache =
  unsafePerformIO (newMVar Map.empty)

healthyProbeTtl :: NominalDiffTime
healthyProbeTtl = 300

unhealthyProbeTtl :: NominalDiffTime
unhealthyProbeTtl = 60

preferFastestUrls :: Manager -> [String] -> IO [String]
preferFastestUrls _ [] =
  pure []
preferFastestUrls _ [url] =
  pure [url]
preferFastestUrls manager urls = do
  ranked <- mapConcurrently rankUrl (zip [0 :: Int ..] urls)
  let ordered = map rankedUrl (sortOn rankedKey ranked)
  logSelection urls ordered
  pure ordered
  where
    rankUrl (index, url) = do
      probe <- probeSource manager url
      pure RankedUrl
        { rankedIndex = index
        , rankedUrl = url
        , rankedProbe = probe
        }

preferFastestRequests :: Manager -> [Request] -> IO [Request]
preferFastestRequests manager requests = do
  orderedUrls <- preferFastestUrls manager (map (show . getUri) requests)
  pure (map snd (sortOn (\(url, _) -> indexOf url orderedUrls) (zip (map (show . getUri) requests) requests)))

recordSourceFailure :: String -> String -> IO ()
recordSourceFailure url reason = do
  now <- getCurrentTime
  let key = sourceHostKey url
  modifyMVar_ sourceProbeCache $ \cache ->
    let previous = Map.lookup key cache
        failures = maybe 0 sourceProbeFailures previous + 1
        cooldownUntil =
          if failures >= 3
            then Just (addUTCTime (fromIntegral (min 300 (failures * 30))) now)
            else previous >>= sourceProbeCooldownUntil
     in pure $
          Map.insert key SourceProbe
            { sourceProbeHealthy = failures < 3
            , sourceProbeMicros = maybe maxBound sourceProbeMicros previous
            , sourceProbeBytesPerSecond = previous >>= sourceProbeBytesPerSecond
            , sourceProbeFailures = failures
            , sourceProbeHashMismatches = maybe 0 sourceProbeHashMismatches previous
            , sourceProbeCooldownUntil = cooldownUntil
            , sourceProbeAt = now
            }
            cache
  putStrLn ("source_unhealthy " <> key <> ": " <> reason)

recordSourceHashMismatch :: String -> String -> IO ()
recordSourceHashMismatch url reason = do
  now <- getCurrentTime
  let key = sourceHostKey url
      cooldownUntil = addUTCTime 600 now
  modifyMVar_ sourceProbeCache $ \cache ->
    let previous = Map.lookup key cache
        failures = maybe 0 sourceProbeFailures previous + 1
        mismatches = maybe 0 sourceProbeHashMismatches previous + 1
     in pure $
          Map.insert key SourceProbe
            { sourceProbeHealthy = False
            , sourceProbeMicros = maybe maxBound sourceProbeMicros previous
            , sourceProbeBytesPerSecond = previous >>= sourceProbeBytesPerSecond
            , sourceProbeFailures = failures
            , sourceProbeHashMismatches = mismatches
            , sourceProbeCooldownUntil = Just cooldownUntil
            , sourceProbeAt = now
            }
            cache
  putStrLn ("source_hash_mismatch " <> key <> " cooldown_seconds=600: " <> reason)

recordSourceThroughput :: String -> Int64 -> Int64 -> IO ()
recordSourceThroughput url bytes bytesPerSecond = do
  now <- getCurrentTime
  let key = sourceHostKey url
      observed = fromIntegral (max 0 bytesPerSecond)
  modifyMVar sourceProbeCache $ \cache -> do
    let previous = Map.lookup key cache
        smoothed =
          case previous >>= sourceProbeBytesPerSecond of
            Nothing -> observed
            Just old -> max 1 ((old * 3 + observed) `div` 4)
        micros = maybe 0 sourceProbeMicros previous
        probe =
          SourceProbe
            { sourceProbeHealthy = bytes > 0
            , sourceProbeMicros = micros
            , sourceProbeBytesPerSecond = Just smoothed
            , sourceProbeFailures = 0
            , sourceProbeHashMismatches = 0
            , sourceProbeCooldownUntil = Nothing
            , sourceProbeAt = now
            }
    pure (Map.insert key probe cache, ())
  putStrLn ("source_throughput " <> key <> " bytes=" <> show bytes <> " bps=" <> show bytesPerSecond)

data RankedUrl = RankedUrl
  { rankedIndex :: Int
  , rankedUrl :: String
  , rankedProbe :: SourceProbe
  } deriving (Eq, Show)

rankedKey :: RankedUrl -> (Bool, Bool, Int, Int, Int, Int, Int)
rankedKey ranked =
  ( sourceProbeInCooldown (rankedProbe ranked)
  , not (sourceProbeHealthy (rankedProbe ranked))
  , sourceProbeHashMismatches (rankedProbe ranked)
  , sourceProbeFailures (rankedProbe ranked)
  , negate (fromMaybe 0 (sourceProbeBytesPerSecond (rankedProbe ranked)))
  , sourceProbeMicros (rankedProbe ranked)
  , rankedIndex ranked
  )

probeSource :: Manager -> String -> IO SourceProbe
probeSource manager url = do
  now <- getCurrentTime
  let key = sourceHostKey url
  cache <- readMVar sourceProbeCache
  case Map.lookup key cache of
    Just probe | not (probeExpired now probe) ->
      pure probe
    _ -> do
      probe <- runProbe manager url
      modifyMVar_ sourceProbeCache (pure . Map.insert key probe)
      pure probe

probeExpired :: UTCTime -> SourceProbe -> Bool
probeExpired now probe =
  case sourceProbeCooldownUntil probe of
    Just cooldownUntil | now < cooldownUntil -> False
    _ -> diffUTCTime now (sourceProbeAt probe) > ttl
  where
    ttl =
      if sourceProbeHealthy probe
        then healthyProbeTtl
        else unhealthyProbeTtl

sourceProbeInCooldown :: SourceProbe -> Bool
sourceProbeInCooldown probe =
  maybe False (> sourceProbeAt probe) (sourceProbeCooldownUntil probe)

runProbe :: Manager -> String -> IO SourceProbe
runProbe manager url = do
  let key = sourceHostKey url
  cache <- readMVar sourceProbeCache
  let previous = Map.lookup key cache
      cachedThroughput = previous >>= sourceProbeBytesPerSecond
      cachedFailures = maybe 0 sourceProbeFailures previous
      cachedMismatches = maybe 0 sourceProbeHashMismatches previous
      cachedCooldown = previous >>= sourceProbeCooldownUntil
  started <- getCurrentTime
  result <- try $ do
    request <- parseRequest url
    let probeRequest =
          request
            { method = "HEAD"
            , responseTimeout = responseTimeoutMicro 2000000
            }
    response <- httpNoBody probeRequest manager
    pure (statusCode (responseStatus response))
  finished <- getCurrentTime
  let micros = max 0 (round (realToFrac (diffUTCTime finished started) * 1000000 :: Double))
      probe =
        case result of
          Right status ->
            SourceProbe
              { sourceProbeHealthy = status < 500
              , sourceProbeMicros = micros
              , sourceProbeBytesPerSecond = cachedThroughput
              , sourceProbeFailures = if status < 500 then 0 else cachedFailures + 1
              , sourceProbeHashMismatches = cachedMismatches
              , sourceProbeCooldownUntil =
                  if status < 500
                    then cachedCooldown
                    else Just (addUTCTime 120 finished)
              , sourceProbeAt = finished
              }
          Left (_ :: SomeException) ->
            SourceProbe
              { sourceProbeHealthy = False
              , sourceProbeMicros = maxBound
              , sourceProbeBytesPerSecond = cachedThroughput
              , sourceProbeFailures = cachedFailures + 1
              , sourceProbeHashMismatches = cachedMismatches
              , sourceProbeCooldownUntil = Just (addUTCTime 120 finished)
              , sourceProbeAt = finished
              }
  pure probe

sourceHostKey :: String -> String
sourceHostKey url =
  case withScheme "https://" url <|> withScheme "http://" url of
    Just (scheme, rest) -> scheme <> takeWhile (/= '/') rest
    Nothing -> takeWhile (/= '/') url

withScheme :: String -> String -> Maybe (String, String)
withScheme scheme url =
  case stripPrefix scheme url of
    Just rest -> Just (scheme, rest)
    Nothing -> Nothing

indexOf :: Eq a => a -> [a] -> Int
indexOf target =
  go 0
  where
    go _ [] = maxBound
    go index (value:rest)
      | value == target = index
      | otherwise = go (index + 1) rest

logSelection :: [String] -> [String] -> IO ()
logSelection _original ordered =
  case ordered of
    selected:_ ->
      putStrLn ("source_selected " <> sourceHostKey selected <> " from " <> show (length ordered) <> " candidates")
    _ -> pure ()
