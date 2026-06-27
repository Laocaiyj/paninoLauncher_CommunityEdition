{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Types.Package
  ( LockfileFile(..)
  , PackageConstraint(..)
  , PackageCoordinate(..)
  , PackageSource(..)
  , ResolvedPackage(..)
  , coordinateProjectIdText
  , coordinateVersionIdText
  , lockfileFileDownloadUrlTexts
  , lockfileFileKey
  , lockfileFileTargetPathFilePath
  , normalizePackageSource
  , packageCoordinateKey
  , packageSourceFromText
  , packageSourceIsManualLike
  , packageSourceIsOnline
  , packageSourceText
  , resolvedPackageDownloadUrlTexts
  , resolvedPackageKey
  , resolvedPackageTargetPathFilePath
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
import Data.Int (Int64)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe)
import Data.String (IsString(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Core.Types
  ( ProjectId
  , RelativePath
  , Url
  , VersionId
  , projectIdText
  , relativePathFilePath
  , urlText
  , versionIdText
  )
import Panino.Core.WireText
  ( WireText(..)
  , parseWireTextJSON
  , toWireTextJSON
  )

data PackageSource
  = PackageSourceModrinth
  | PackageSourceCurseForge
  | PackageSourceLoaderMeta
  | PackageSourceJavaRuntime
  | PackageSourceLocal
  | PackageSourceManual
  | PackageSourceMojang
  | PackageSourcePanino
  | PackageSourceOther Text
  deriving (Eq, Show)

instance IsString PackageSource where
  fromString =
    packageSourceFromText . Text.pack

packageSourceFromText :: Text -> PackageSource
packageSourceFromText =
  parseWireText

packageSourceText :: PackageSource -> Text
packageSourceText =
  wireText

instance WireText PackageSource where
  parseWireText source =
    case Text.toLower source of
      "modrinth" -> PackageSourceModrinth
      "curseforge" -> PackageSourceCurseForge
      "curse-forge" -> PackageSourceCurseForge
      "loader_meta" -> PackageSourceLoaderMeta
      "loadermeta" -> PackageSourceLoaderMeta
      "java_runtime" -> PackageSourceJavaRuntime
      "javaruntime" -> PackageSourceJavaRuntime
      "local" -> PackageSourceLocal
      "manual" -> PackageSourceManual
      "mojang" -> PackageSourceMojang
      "panino" -> PackageSourcePanino
      _ -> PackageSourceOther source

  wireText source =
    case source of
      PackageSourceModrinth -> "modrinth"
      PackageSourceCurseForge -> "curseforge"
      PackageSourceLoaderMeta -> "loaderMeta"
      PackageSourceJavaRuntime -> "javaRuntime"
      PackageSourceLocal -> "local"
      PackageSourceManual -> "manual"
      PackageSourceMojang -> "mojang"
      PackageSourcePanino -> "panino"
      PackageSourceOther value -> value

normalizePackageSource :: PackageSource -> PackageSource
normalizePackageSource =
  packageSourceFromText . packageSourceText

packageSourceIsManualLike :: PackageSource -> Bool
packageSourceIsManualLike source =
  case normalizePackageSource source of
    PackageSourceManual -> True
    PackageSourceLocal -> True
    _ -> False

packageSourceIsOnline :: PackageSource -> Bool
packageSourceIsOnline source =
  case normalizePackageSource source of
    PackageSourceModrinth -> True
    PackageSourceCurseForge -> True
    _ -> False

instance ToJSON PackageSource where
  toJSON =
    toWireTextJSON

instance FromJSON PackageSource where
  parseJSON =
    parseWireTextJSON

data PackageCoordinate = PackageCoordinate
  { coordinateSource :: PackageSource
  , coordinateProjectId :: Maybe ProjectId
  , coordinateVersionId :: Maybe VersionId
  , coordinateFileId :: Maybe Text
  , coordinateSlug :: Maybe Text
  , coordinateName :: Maybe Text
  , coordinateKind :: Text
  } deriving (Eq, Show)

instance ToJSON PackageCoordinate where
  toJSON coordinate =
    object
      [ "source" .= coordinateSource coordinate
      , "projectId" .= coordinateProjectId coordinate
      , "versionId" .= coordinateVersionId coordinate
      , "fileId" .= coordinateFileId coordinate
      , "slug" .= coordinateSlug coordinate
      , "name" .= coordinateName coordinate
      , "kind" .= coordinateKind coordinate
      ]

instance FromJSON PackageCoordinate where
  parseJSON =
    withObject "PackageCoordinate" $ \obj ->
      PackageCoordinate
        <$> obj .:? "source" .!= "manual"
        <*> obj .:? "projectId"
        <*> (obj .:? "versionId" >>= maybe (obj .:? "versionID") (pure . Just))
        <*> obj .:? "fileId"
        <*> obj .:? "slug"
        <*> obj .:? "name"
        <*> obj .:? "kind" .!= "mod"

data PackageConstraint = PackageConstraint
  { constraintId :: Text
  , constraintSourcePackage :: Maybe Text
  , constraintTargetPackageId :: Maybe Text
  , constraintTargetKind :: Text
  , constraintRelation :: Text
  , constraintMinecraftVersions :: [VersionId]
  , constraintLoaders :: [Text]
  , constraintJavaMajor :: Maybe Int
  , constraintSide :: Maybe Text
  , constraintRequired :: Bool
  , constraintReason :: Text
  } deriving (Eq, Show)

instance ToJSON PackageConstraint where
  toJSON constraint =
    object
      [ "constraintId" .= constraintId constraint
      , "sourcePackage" .= constraintSourcePackage constraint
      , "targetPackageId" .= constraintTargetPackageId constraint
      , "targetKind" .= constraintTargetKind constraint
      , "relation" .= constraintRelation constraint
      , "minecraftVersions" .= constraintMinecraftVersions constraint
      , "loaders" .= constraintLoaders constraint
      , "javaMajor" .= constraintJavaMajor constraint
      , "side" .= constraintSide constraint
      , "required" .= constraintRequired constraint
      , "reason" .= constraintReason constraint
      ]

instance FromJSON PackageConstraint where
  parseJSON =
    withObject "PackageConstraint" $ \obj ->
      PackageConstraint
        <$> obj .:? "constraintId" .!= ""
        <*> obj .:? "sourcePackage"
        <*> (obj .:? "targetPackageId" >>= maybe (obj .:? "targetPackage") (pure . Just))
        <*> obj .:? "targetKind" .!= "mod"
        <*> obj .:? "relation" .!= "requires"
        <*> obj .:? "minecraftVersions" .!= []
        <*> obj .:? "loaders" .!= []
        <*> obj .:? "javaMajor"
        <*> obj .:? "side"
        <*> obj .:? "required" .!= True
        <*> obj .:? "reason" .!= ""

data ResolvedPackage = ResolvedPackage
  { resolvedPackageId :: Text
  , resolvedPackageCoordinate :: PackageCoordinate
  , resolvedPackageDisplayName :: Text
  , resolvedPackageVersionName :: Maybe Text
  , resolvedPackageFileName :: Maybe Text
  , resolvedPackageTargetPath :: Maybe RelativePath
  , resolvedPackageHashes :: Map Text Text
  , resolvedPackageSize :: Maybe Int64
  , resolvedPackageDownloadUrls :: [Url]
  , resolvedPackageGameVersions :: [Text]
  , resolvedPackageLoaders :: [Text]
  , resolvedPackageJavaMajor :: Maybe Int
  , resolvedPackageSide :: Maybe Text
  , resolvedPackageSelectedBecause :: [Text]
  , resolvedPackageLocked :: Bool
  , resolvedPackagePinReason :: Maybe Text
  , resolvedPackageDependencies :: [PackageConstraint]
  , resolvedPackageConflicts :: [PackageConstraint]
  , resolvedPackageSourceSnapshot :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON ResolvedPackage where
  toJSON package =
    object
      [ "packageId" .= resolvedPackageId package
      , "coordinate" .= resolvedPackageCoordinate package
      , "displayName" .= resolvedPackageDisplayName package
      , "versionName" .= resolvedPackageVersionName package
      , "fileName" .= resolvedPackageFileName package
      , "targetPath" .= resolvedPackageTargetPath package
      , "hashes" .= resolvedPackageHashes package
      , "size" .= resolvedPackageSize package
      , "downloadUrls" .= resolvedPackageDownloadUrls package
      , "gameVersions" .= resolvedPackageGameVersions package
      , "loaders" .= resolvedPackageLoaders package
      , "javaMajor" .= resolvedPackageJavaMajor package
      , "side" .= resolvedPackageSide package
      , "selectedBecause" .= resolvedPackageSelectedBecause package
      , "locked" .= resolvedPackageLocked package
      , "pinReason" .= resolvedPackagePinReason package
      , "dependencies" .= resolvedPackageDependencies package
      , "conflicts" .= resolvedPackageConflicts package
      , "sourceSnapshot" .= resolvedPackageSourceSnapshot package
      ]

instance FromJSON ResolvedPackage where
  parseJSON =
    withObject "ResolvedPackage" $ \obj -> do
      coordinate <- obj .:? "coordinate" .!= PackageCoordinate "manual" Nothing Nothing Nothing Nothing Nothing "mod"
      packageIdValue <-
        obj .:? "packageId" .!= packageCoordinateKey coordinate
      displayNameValue <-
        obj .:? "displayName" .!= fromMaybe packageIdValue (coordinateName coordinate)
      ResolvedPackage
        <$> pure packageIdValue
        <*> pure coordinate
        <*> pure displayNameValue
        <*> obj .:? "versionName"
        <*> obj .:? "fileName"
        <*> obj .:? "targetPath"
        <*> obj .:? "hashes" .!= Map.empty
        <*> obj .:? "size"
        <*> obj .:? "downloadUrls" .!= []
        <*> obj .:? "gameVersions" .!= []
        <*> obj .:? "loaders" .!= []
        <*> obj .:? "javaMajor"
        <*> obj .:? "side"
        <*> obj .:? "selectedBecause" .!= []
        <*> obj .:? "locked" .!= False
        <*> obj .:? "pinReason"
        <*> obj .:? "dependencies" .!= []
        <*> obj .:? "conflicts" .!= []
        <*> obj .:? "sourceSnapshot"

data LockfileFile = LockfileFile
  { lockfileFilePackageId :: Text
  , lockfileFileName :: Text
  , lockfileFileTargetPath :: RelativePath
  , lockfileFileHashes :: Map Text Text
  , lockfileFileSize :: Maybe Int64
  , lockfileFileDownloadUrls :: [Url]
  , lockfileFileKind :: Text
  } deriving (Eq, Show)

instance ToJSON LockfileFile where
  toJSON file =
    object
      [ "packageId" .= lockfileFilePackageId file
      , "fileName" .= lockfileFileName file
      , "targetPath" .= lockfileFileTargetPath file
      , "hashes" .= lockfileFileHashes file
      , "size" .= lockfileFileSize file
      , "downloadUrls" .= lockfileFileDownloadUrls file
      , "kind" .= lockfileFileKind file
      ]

instance FromJSON LockfileFile where
  parseJSON =
    withObject "LockfileFile" $ \obj ->
      LockfileFile
        <$> obj .: "packageId"
        <*> obj .:? "fileName" .!= ""
        <*> obj .: "targetPath"
        <*> obj .:? "hashes" .!= Map.empty
        <*> obj .:? "size"
        <*> obj .:? "downloadUrls" .!= []
        <*> obj .:? "kind" .!= "mod"

packageCoordinateKey :: PackageCoordinate -> Text
packageCoordinateKey coordinate =
  Text.intercalate
    ":"
    [ Text.toLower (packageSourceText (coordinateSource coordinate))
    , fromMaybe "" (coordinateProjectIdText coordinate)
    , fromMaybe "" (coordinateVersionIdText coordinate)
    , fromMaybe "" (coordinateFileId coordinate)
    , Text.toLower (coordinateKind coordinate)
    ]

resolvedPackageKey :: ResolvedPackage -> Text
resolvedPackageKey package =
  Text.intercalate
    "|"
    [ resolvedPackageId package
    , packageCoordinateKey (resolvedPackageCoordinate package)
    , fromMaybe "" (resolvedPackageFileName package)
    , maybe "" Text.pack (resolvedPackageTargetPathFilePath package)
    ]

lockfileFileKey :: LockfileFile -> Text
lockfileFileKey file =
  Text.intercalate
    "|"
    [ lockfileFilePackageId file
    , Text.pack (lockfileFileTargetPathFilePath file)
    , Map.findWithDefault "" "sha1" (lockfileFileHashes file)
    ]

coordinateProjectIdText :: PackageCoordinate -> Maybe Text
coordinateProjectIdText =
  fmap projectIdText . coordinateProjectId

coordinateVersionIdText :: PackageCoordinate -> Maybe Text
coordinateVersionIdText =
  fmap versionIdText . coordinateVersionId

resolvedPackageTargetPathFilePath :: ResolvedPackage -> Maybe FilePath
resolvedPackageTargetPathFilePath =
  fmap relativePathFilePath . resolvedPackageTargetPath

resolvedPackageDownloadUrlTexts :: ResolvedPackage -> [Text]
resolvedPackageDownloadUrlTexts =
  map urlText . resolvedPackageDownloadUrls

lockfileFileTargetPathFilePath :: LockfileFile -> FilePath
lockfileFileTargetPathFilePath =
  relativePathFilePath . lockfileFileTargetPath

lockfileFileDownloadUrlTexts :: LockfileFile -> [Text]
lockfileFileDownloadUrlTexts =
  map urlText . lockfileFileDownloadUrls
