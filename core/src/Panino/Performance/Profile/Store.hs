{-# LANGUAGE OverloadedStrings #-}

module Panino.Performance.Profile.Store
  ( applyProfile
  , baselineProfile
  , cooldownPath
  , listRecentSessions
  , profilePath
  , readProfile
  , readProfileCooldown
  , recordProfileCooldown
  , rollbackProfile
  , storeProfile
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( (.:)
  , FromJSON(..)
  , eitherDecode
  , encode
  , object
  , withObject
  , (.=)
  )
import qualified Data.ByteString.Lazy as BL
import Data.List (sortOn)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock
  ( UTCTime
  , addUTCTime
  , getCurrentTime
  )
import Panino.Performance.Profile.Types
  ( InstanceFingerprint
  , PerformanceConfidence(..)
  , PerformanceEvidence
  , PerformanceKnobs(..)
  , PerformanceProfile(..)
  , PerformanceProfileSource(..)
  , ProfileKind(..)
  , estimatedEvidence
  , performanceRoot
  )
import Panino.Performance.Telemetry.Types
  ( PerformanceSession
  , performanceSessionsRoot
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.FilePath
  ( (</>)
  , takeDirectory
  )

newtype ProfileCooldown = ProfileCooldown
  { unProfileCooldown :: UTCTime
  }

instance FromJSON ProfileCooldown where
  parseJSON =
    withObject "ProfileCooldown" $ \obj ->
      ProfileCooldown <$> obj .: "cooldownUntil"

baselineProfile :: FilePath -> InstanceFingerprint -> PerformanceKnobs -> [PerformanceEvidence] -> PerformanceProfile
baselineProfile gameDir fingerprint knobs evidence =
  PerformanceProfile
    { profileId = "baseline-" <> Text.take 12 (stableTextId (Text.pack gameDir <> Text.pack (show knobs)))
    , profileKind = ProfileBaseline
    , profileSource = ProfileSourceStaticBaseline
    , profileInstanceFingerprint = fingerprint
    , profileKnobs = knobs
    , profileConfidence = ConfidenceEstimated
    , profileEvidence =
        if null evidence
          then [estimatedEvidence "source" "static safe baseline"]
          else evidence
    , profileRollbackRef = Nothing
    , profileCooldownUntil = Nothing
    }

storeProfile :: FilePath -> PerformanceProfile -> IO ()
storeProfile gameDir profile = do
  let path = profilePath gameDir (profileId profile)
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path (encode profile)

readProfile :: FilePath -> Text -> IO (Maybe PerformanceProfile)
readProfile gameDir ident = do
  let path = profilePath gameDir ident
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else do
      result <- eitherDecode <$> BL.readFile path
      pure $ case result of
        Right profile -> Just profile
        Left _ -> Nothing

applyProfile :: FilePath -> PerformanceProfile -> IO PerformanceProfile
applyProfile gameDir profile = do
  let applied =
        profile
          { profileRollbackRef = Just ("rollback-" <> profileId profile)
          }
  storeProfile gameDir applied
  BL.writeFile (profilePath gameDir "applied") (encode applied)
  pure applied

rollbackProfile :: FilePath -> Text -> IO (Maybe PerformanceProfile)
rollbackProfile gameDir rollbackRef = do
  current <- readProfile gameDir "applied"
  case current of
    Nothing -> pure Nothing
    Just profile -> do
      _ <- recordProfileCooldown gameDir (profileId profile)
      let restored =
            profile
              { profileKind = ProfileUserOverride
              , profileSource = ProfileSourceUserOverride
              , profileConfidence = ConfidenceMeasuredOnce
              , profileEvidence =
                  estimatedEvidence "rollbackRef" rollbackRef : profileEvidence profile
              }
      storeProfile gameDir restored
      BL.writeFile (profilePath gameDir "user-override") (encode restored)
      pure (Just restored)

recordProfileCooldown :: FilePath -> Text -> IO UTCTime
recordProfileCooldown gameDir ident = do
  now <- getCurrentTime
  let cooldownUntil = addUTCTime 86400 now
      path = cooldownPath gameDir ident
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile
    path
    ( encode $
        object
          [ "profileId" .= ident
          , "cooldownUntil" .= cooldownUntil
          , "reason" .= ("rollback" :: Text)
          ]
    )
  pure cooldownUntil

readProfileCooldown :: FilePath -> Text -> IO (Maybe UTCTime)
readProfileCooldown gameDir ident = do
  let path = cooldownPath gameDir ident
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else do
      now <- getCurrentTime
      result <- eitherDecode <$> BL.readFile path
      pure $ case result of
        Right cooldown ->
          let cooldownUntil = unProfileCooldown cooldown
           in if cooldownUntil > now then Just cooldownUntil else Nothing
        _ -> Nothing

listRecentSessions :: FilePath -> Int -> IO [PerformanceSession]
listRecentSessions gameDir limit = do
  let root = performanceSessionsRoot gameDir
  exists <- doesDirectoryExist root
  if not exists
    then pure []
    else do
      directories <- listDirectory root
      decoded <- traverse (readSessionDirectory root) directories
      pure (take limit (reverse (sortOn sessionKey (mapMaybe id decoded))))

profilePath :: FilePath -> Text -> FilePath
profilePath gameDir ident =
  performanceRoot gameDir </> "profiles" </> Text.unpack ident <> ".json"

cooldownPath :: FilePath -> Text -> FilePath
cooldownPath gameDir ident =
  performanceRoot gameDir </> "experiments" </> "cooldowns" </> Text.unpack ident <> ".json"

readSessionDirectory :: FilePath -> FilePath -> IO (Maybe PerformanceSession)
readSessionDirectory root directory = do
  let path = root </> directory </> "performance-session.json"
  exists <- doesFileExist path
  if not exists
    then pure Nothing
    else do
      result <- try (eitherDecode <$> BL.readFile path) :: IO (Either SomeException (Either String PerformanceSession))
      pure $ case result of
        Right (Right session) -> Just session
        _ -> Nothing

sessionKey :: PerformanceSession -> Text
sessionKey =
  Text.pack . show

stableTextId :: Text -> Text
stableTextId =
  Text.filter (/= '-') . Text.take 32 . Text.pack . show . abs . Text.foldl' hashStep (5381 :: Int)
  where
    hashStep acc char = acc * 33 + fromEnum char
