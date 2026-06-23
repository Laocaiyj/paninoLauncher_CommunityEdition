{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Types.Document
  ( PaninoLockfile(..)
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , Value
  , object
  , withObject
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Text (Text)
import Data.Time (UTCTime)
import Panino.Lockfile.Types.Package
  ( LockfileFile
  , PackageConstraint
  , ResolvedPackage
  )

data PaninoLockfile = PaninoLockfile
  { lockfileVersion :: Int
  , lockfileSolverVersion :: Text
  , lockfileFingerprint :: Text
  , lockfileCreatedAt :: Maybe UTCTime
  , lockfileUpdatedAt :: Maybe UTCTime
  , lockfileTargetGameDir :: Maybe FilePath
  , lockfileMinecraft :: Maybe Text
  , lockfileJava :: Maybe Value
  , lockfileLoader :: Maybe Value
  , lockfileShaderLoader :: Maybe Value
  , lockfileRoots :: [Text]
  , lockfilePackages :: [ResolvedPackage]
  , lockfileFiles :: [LockfileFile]
  , lockfileConstraints :: [PackageConstraint]
  , lockfileOverrides :: [Value]
  , lockfileSourceSnapshots :: [Value]
  , lockfileManualEntries :: [ResolvedPackage]
  , lockfileWarnings :: [Text]
  } deriving (Eq, Show)

instance ToJSON PaninoLockfile where
  toJSON lockfile =
    object
      [ "lockfileVersion" .= lockfileVersion lockfile
      , "solverVersion" .= lockfileSolverVersion lockfile
      , "fingerprint" .= lockfileFingerprint lockfile
      , "createdAt" .= lockfileCreatedAt lockfile
      , "updatedAt" .= lockfileUpdatedAt lockfile
      , "targetGameDir" .= lockfileTargetGameDir lockfile
      , "minecraft" .= lockfileMinecraft lockfile
      , "java" .= lockfileJava lockfile
      , "loader" .= lockfileLoader lockfile
      , "shaderLoader" .= lockfileShaderLoader lockfile
      , "roots" .= lockfileRoots lockfile
      , "packages" .= lockfilePackages lockfile
      , "files" .= lockfileFiles lockfile
      , "constraints" .= lockfileConstraints lockfile
      , "overrides" .= lockfileOverrides lockfile
      , "sourceSnapshots" .= lockfileSourceSnapshots lockfile
      , "manualEntries" .= lockfileManualEntries lockfile
      , "warnings" .= lockfileWarnings lockfile
      ]

instance FromJSON PaninoLockfile where
  parseJSON =
    withObject "PaninoLockfile" $ \obj ->
      PaninoLockfile
        <$> obj .:? "lockfileVersion" .!= 1
        <*> obj .:? "solverVersion" .!= "lockfile-solver-v1"
        <*> obj .:? "fingerprint" .!= ""
        <*> obj .:? "createdAt"
        <*> obj .:? "updatedAt"
        <*> obj .:? "targetGameDir"
        <*> obj .:? "minecraft"
        <*> obj .:? "java"
        <*> obj .:? "loader"
        <*> obj .:? "shaderLoader"
        <*> obj .:? "roots" .!= []
        <*> obj .:? "packages" .!= []
        <*> obj .:? "files" .!= []
        <*> obj .:? "constraints" .!= []
        <*> obj .:? "overrides" .!= []
        <*> obj .:? "sourceSnapshots" .!= []
        <*> obj .:? "manualEntries" .!= []
        <*> obj .:? "warnings" .!= []
