{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Multiplayer.Taowa.ConfigStore
  ( buildTaowaFrpProfile
  , deleteTaowaFrpProfile
  , findTaowaFrpProfile
  , readTaowaFrpProfiles
  , taowaProfilesPath
  , taowaRoot
  , upsertTaowaFrpProfile
  , validateTaowaFrpProfile
  , writeTaowaFrpProfiles
  ) where

import Control.Exception
  ( throwIO
  )
import Data.Aeson
  ( eitherDecode
  , encode
  )
import qualified Data.ByteString.Lazy as BL
import Data.Char
  ( isAlphaNum
  , toLower
  )
import Data.List (find)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock
  ( getCurrentTime
  )
import Panino.Multiplayer.Taowa.Types
  ( TaowaFrpProfile(..)
  , TaowaFrpProfileRequest(..)
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  )
import System.FilePath
  ( takeDirectory
  , (</>)
  )

taowaRoot :: FilePath -> FilePath
taowaRoot appRoot =
  appRoot </> "taowa"

taowaProfilesPath :: FilePath -> FilePath
taowaProfilesPath appRoot =
  taowaRoot appRoot </> "frp-profiles.json"

readTaowaFrpProfiles :: FilePath -> IO [TaowaFrpProfile]
readTaowaFrpProfiles appRoot = do
  let path = taowaProfilesPath appRoot
  exists <- doesFileExist path
  if not exists
    then pure []
    else do
      decoded <- eitherDecode <$> BL.readFile path
      case decoded of
        Right profiles -> pure profiles
        Left err -> throwIO (userError ("taowa profile store invalid: " <> err))

writeTaowaFrpProfiles :: FilePath -> [TaowaFrpProfile] -> IO ()
writeTaowaFrpProfiles appRoot profiles = do
  let path = taowaProfilesPath appRoot
  createDirectoryIfMissing True (takeDirectory path)
  BL.writeFile path (encode profiles)

findTaowaFrpProfile :: FilePath -> Text -> IO (Maybe TaowaFrpProfile)
findTaowaFrpProfile appRoot profileId =
  find ((== profileId) . taowaProfileId) <$> readTaowaFrpProfiles appRoot

upsertTaowaFrpProfile :: FilePath -> TaowaFrpProfile -> IO TaowaFrpProfile
upsertTaowaFrpProfile appRoot profile = do
  profiles <- readTaowaFrpProfiles appRoot
  let remaining = filter ((/= taowaProfileId profile) . taowaProfileId) profiles
  writeTaowaFrpProfiles appRoot (profile : remaining)
  pure profile

deleteTaowaFrpProfile :: FilePath -> Text -> IO Bool
deleteTaowaFrpProfile appRoot profileId = do
  profiles <- readTaowaFrpProfiles appRoot
  let remaining = filter ((/= profileId) . taowaProfileId) profiles
      deleted = length remaining /= length profiles
  writeTaowaFrpProfiles appRoot remaining
  pure deleted

buildTaowaFrpProfile :: Maybe TaowaFrpProfile -> TaowaFrpProfileRequest -> IO TaowaFrpProfile
buildTaowaFrpProfile existing request = do
  now <- getCurrentTime
  let profileId =
        fromMaybe
          (maybe (defaultProfileId (taowaRequestDisplayName request)) taowaProfileId existing)
          (taowaRequestProfileId request)
      createdAt = maybe now taowaProfileCreatedAt existing
      profile =
        TaowaFrpProfile
          { taowaProfileId = profileId
          , taowaProfileDisplayName = taowaRequestDisplayName request
          , taowaProfileServerAddr = taowaRequestServerAddr request
          , taowaProfileServerPort = taowaRequestServerPort request
          , taowaProfileToken = resolvedToken
          , taowaProfileRemotePort = taowaRequestRemotePort request
          , taowaProfileProtocol = taowaRequestProtocol request
          , taowaProfileFrpcPath = taowaRequestFrpcPath request
          , taowaProfileEnabled = taowaRequestEnabled request
          , taowaProfileCreatedAt = createdAt
          , taowaProfileUpdatedAt = now
          }
  case validateTaowaFrpProfile profile of
    [] -> pure profile
    errors -> throwIO (userError ("invalid taowa profile: " <> Text.unpack (Text.intercalate "; " errors)))
  where
    resolvedToken =
      case taowaRequestToken request of
        Just token
          | Text.null token -> Nothing
          | otherwise -> Just token
        Nothing -> existing >>= taowaProfileToken

validateTaowaFrpProfile :: TaowaFrpProfile -> [Text]
validateTaowaFrpProfile profile =
  concat
    [ ["profileId is required" | Text.null (Text.strip (taowaProfileId profile))]
    , ["displayName is required" | Text.null (Text.strip (taowaProfileDisplayName profile))]
    , ["serverAddr is required" | Text.null (Text.strip (taowaProfileServerAddr profile))]
    , ["serverPort must be 1-65535" | not (validPort (taowaProfileServerPort profile))]
    , ["remotePort must be 1-65535" | not (validPort (taowaProfileRemotePort profile))]
    , ["frpcPath is required" | null (taowaProfileFrpcPath profile)]
    ]

validPort :: Int -> Bool
validPort port =
  port >= 1 && port <= 65535

defaultProfileId :: Text -> Text
defaultProfileId displayName =
  let normalized = Text.pack (collapseDashes (map normalizeChar (Text.unpack displayName)))
   in if Text.null normalized then "default-frp" else normalized

normalizeChar :: Char -> Char
normalizeChar char
  | isAlphaNum char = toLower char
  | otherwise = '-'

collapseDashes :: String -> String
collapseDashes =
  trimDashes . go False
  where
    go _ [] = []
    go previousDash (char:rest)
      | char == '-' =
          if previousDash
            then go True rest
            else '-' : go True rest
      | otherwise = char : go False rest
    trimDashes = reverse . dropWhile (== '-') . reverse . dropWhile (== '-')
