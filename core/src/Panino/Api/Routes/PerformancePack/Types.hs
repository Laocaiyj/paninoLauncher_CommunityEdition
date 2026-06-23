{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.PerformancePack.Types
  ( PerformancePackInstallRequest(..)
  , PerformancePackLockfile(..)
  , PerformancePackPlan(..)
  , PerformancePackPlanFile(..)
  , PerformancePackRollbackRequest(..)
  , PerformancePackRollbackResult(..)
  , ResolvedPerformanceDownload(..)
  , ResolvedPerformancePackPlan(..)
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Text (Text)
import Panino.Api.Types (DownloadRuntimeOptions(..))
import Panino.Download.Manager (DownloadJob)
import qualified Panino.Install.Plan.Types as Plan

data PerformancePackInstallRequest = PerformancePackInstallRequest
  { packInstallGameDir :: FilePath
  , packInstallMinecraftVersion :: Text
  , packInstallLoader :: Text
  , packInstallIncludeOptional :: Bool
  , packInstallDownload :: DownloadRuntimeOptions
  , packInstallSource :: Text
  , packInstallCurseForgeAPIKey :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON PerformancePackInstallRequest where
  parseJSON =
    withObject "PerformancePackInstallRequest" $ \obj ->
      PerformancePackInstallRequest
        <$> obj .: "gameDir"
        <*> obj .: "minecraftVersion"
        <*> obj .: "loader"
        <*> obj .:? "includeOptional" .!= False
        <*> obj .:? "download" .!= DownloadRuntimeOptions Nothing Nothing Nothing
        <*> obj .:? "source" .!= "modrinth"
        <*> obj .:? "curseForgeAPIKey"

data PerformancePackPlan = PerformancePackPlan
  { packPlanStatus :: Text
  , packPlanTitle :: Text
  , packPlanGameDir :: FilePath
  , packPlanLockfilePath :: FilePath
  , packPlanFiles :: [PerformancePackPlanFile]
  , packPlanBlockedReasons :: [Text]
  , packPlanSkippedReasons :: [Text]
  , packPlanTypedPlan :: Plan.TypedInstallPlan
  } deriving (Eq, Show)

instance ToJSON PerformancePackPlan where
  toJSON plan =
    object
      [ "status" .= packPlanStatus plan
      , "title" .= packPlanTitle plan
      , "gameDir" .= packPlanGameDir plan
      , "lockfilePath" .= packPlanLockfilePath plan
      , "files" .= packPlanFiles plan
      , "blockedReasons" .= packPlanBlockedReasons plan
      , "skippedReasons" .= packPlanSkippedReasons plan
      , "typedPlan" .= packPlanTypedPlan plan
      ]

data PerformancePackPlanFile = PerformancePackPlanFile
  { packPlanFileSource :: Text
  , packPlanFileProjectId :: Text
  , packPlanFileName :: FilePath
  , packPlanFileTargetPath :: FilePath
  , packPlanFileSha1 :: Maybe Text
  , packPlanFileSize :: Maybe Integer
  } deriving (Eq, Show)

instance ToJSON PerformancePackPlanFile where
  toJSON file =
    object
      [ "source" .= packPlanFileSource file
      , "projectId" .= packPlanFileProjectId file
      , "fileName" .= packPlanFileName file
      , "targetPath" .= packPlanFileTargetPath file
      , "sha1" .= packPlanFileSha1 file
      , "size" .= packPlanFileSize file
      ]

instance FromJSON PerformancePackPlanFile where
  parseJSON =
    withObject "PerformancePackPlanFile" $ \obj ->
      PerformancePackPlanFile
        <$> obj .:? "source" .!= "modrinth"
        <*> obj .: "projectId"
        <*> obj .: "fileName"
        <*> obj .: "targetPath"
        <*> obj .:? "sha1"
        <*> obj .:? "size"

data ResolvedPerformancePackPlan = ResolvedPerformancePackPlan
  { resolvedPerformancePlan :: PerformancePackPlan
  , resolvedPerformanceDownloads :: [ResolvedPerformanceDownload]
  } deriving (Eq, Show)

data ResolvedPerformanceDownload = ResolvedPerformanceDownload
  { resolvedPerformanceDownloadJob :: DownloadJob
  , resolvedPerformanceDownloadFile :: PerformancePackPlanFile
  } deriving (Eq, Show)

newtype PerformancePackLockfile = PerformancePackLockfile
  { performancePackLockfileFiles :: [PerformancePackPlanFile]
  } deriving (Eq, Show)

instance FromJSON PerformancePackLockfile where
  parseJSON =
    withObject "PerformancePackLockfile" $ \obj ->
      PerformancePackLockfile <$> obj .:? "files" .!= []

data PerformancePackRollbackRequest = PerformancePackRollbackRequest
  { packRollbackGameDir :: FilePath
  , packRollbackLockfilePath :: Maybe FilePath
  } deriving (Eq, Show)

instance FromJSON PerformancePackRollbackRequest where
  parseJSON =
    withObject "PerformancePackRollbackRequest" $ \obj ->
      PerformancePackRollbackRequest
        <$> obj .: "gameDir"
        <*> obj .:? "lockfilePath"

data PerformancePackRollbackResult = PerformancePackRollbackResult
  { packRollbackResultRolledBack :: Bool
  , packRollbackResultRemoved :: [FilePath]
  , packRollbackResultMissing :: [FilePath]
  , packRollbackResultSkipped :: [Text]
  , packRollbackResultLockfilePath :: FilePath
  } deriving (Eq, Show)

instance ToJSON PerformancePackRollbackResult where
  toJSON result =
    object
      [ "rolledBack" .= packRollbackResultRolledBack result
      , "removed" .= packRollbackResultRemoved result
      , "missing" .= packRollbackResultMissing result
      , "skipped" .= packRollbackResultSkipped result
      , "lockfilePath" .= packRollbackResultLockfilePath result
      ]
