{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Local.Types
  ( JavaCheckRequest(..)
  , JavaCheckResponse(..)
  , JavaRuntimeLocalDeleteRequest(..)
  , JavaRuntimeLocalDeleteResponse(..)
  , JavaRuntimeCandidate(..)
  , LocalArchiveImportRequest(..)
  , LocalArchiveRequest(..)
  , LocalResourceImportRequest(..)
  , LocalResourceMetadata(..)
  , LocalResourceMutationRequest(..)
  , LocalResourceMutationResponse(..)
  , LocalResourceScanRequest(..)
  , LocalResourceSummary(..)
  , MinecraftCleanVersionRequest(..)
  , MinecraftVersionStorageAction(..)
  , MinecraftVersionStorageRequest(..)
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Text (Text)
import Data.Time (UTCTime)

newtype JavaCheckRequest = JavaCheckRequest
  { javaCheckPath :: Maybe FilePath
  } deriving (Eq, Show)

instance FromJSON JavaCheckRequest where
  parseJSON =
    withObject "JavaCheckRequest" $ \obj ->
      JavaCheckRequest <$> obj .:? "java"

data JavaCheckResponse = JavaCheckResponse
  { javaResponsePath :: FilePath
  , javaResponseAvailable :: Bool
  , javaResponseSummary :: Text
  , javaResponseVersion :: Maybe Text
  , javaResponseMajorVersion :: Maybe Int
  , javaResponseVendor :: Maybe Text
  , javaResponseArchitecture :: Maybe Text
  , javaResponseExecutablePermission :: Maybe Bool
  , javaResponseRawSummary :: Text
  } deriving (Eq, Show)

instance ToJSON JavaCheckResponse where
  toJSON response =
    object
      [ "path" .= javaResponsePath response
      , "isAvailable" .= javaResponseAvailable response
      , "versionSummary" .= javaResponseSummary response
      , "version" .= javaResponseVersion response
      , "majorVersion" .= javaResponseMajorVersion response
      , "vendor" .= javaResponseVendor response
      , "architecture" .= javaResponseArchitecture response
      , "executablePermission" .= javaResponseExecutablePermission response
      , "rawSummary" .= javaResponseRawSummary response
      ]

data JavaRuntimeCandidate = JavaRuntimeCandidate
  { javaCandidatePath :: FilePath
  , javaCandidateAvailable :: Bool
  , javaCandidateSummary :: Text
  , javaCandidateSource :: Text
  , javaCandidateDeleteTarget :: Maybe FilePath
  } deriving (Eq, Show)

instance ToJSON JavaRuntimeCandidate where
  toJSON candidate =
    object
      [ "path" .= javaCandidatePath candidate
      , "isAvailable" .= javaCandidateAvailable candidate
      , "versionSummary" .= javaCandidateSummary candidate
      , "source" .= javaCandidateSource candidate
      , "canDelete" .= maybe False (const True) (javaCandidateDeleteTarget candidate)
      , "deleteTarget" .= javaCandidateDeleteTarget candidate
      ]

newtype JavaRuntimeLocalDeleteRequest = JavaRuntimeLocalDeleteRequest
  { javaLocalDeletePath :: FilePath
  } deriving (Eq, Show)

instance FromJSON JavaRuntimeLocalDeleteRequest where
  parseJSON =
    withObject "JavaRuntimeLocalDeleteRequest" $ \obj ->
      JavaRuntimeLocalDeleteRequest <$> obj .: "path"

data JavaRuntimeLocalDeleteResponse = JavaRuntimeLocalDeleteResponse
  { javaLocalDeleteDeleted :: Bool
  , javaLocalDeleteResponsePath :: FilePath
  , javaLocalDeleteTargetRoot :: Maybe FilePath
  , javaLocalDeleteMessage :: Text
  } deriving (Eq, Show)

instance ToJSON JavaRuntimeLocalDeleteResponse where
  toJSON response =
    object
      [ "deleted" .= javaLocalDeleteDeleted response
      , "path" .= javaLocalDeleteResponsePath response
      , "targetRoot" .= javaLocalDeleteTargetRoot response
      , "message" .= javaLocalDeleteMessage response
      ]

data LocalResourceScanRequest = LocalResourceScanRequest
  { localResourceGameDir :: FilePath
  , localResourceKind :: Text
  , localResourceLoader :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON LocalResourceScanRequest where
  parseJSON =
    withObject "LocalResourceScanRequest" $ \obj ->
      LocalResourceScanRequest
        <$> obj .: "gameDir"
        <*> obj .: "kind"
        <*> obj .:? "loader"

newtype LocalResourceMutationRequest = LocalResourceMutationRequest
  { localResourcePath :: FilePath
  } deriving (Eq, Show)

instance FromJSON LocalResourceMutationRequest where
  parseJSON =
    withObject "LocalResourceMutationRequest" $ \obj ->
      LocalResourceMutationRequest <$> obj .: "path"

data LocalResourceImportRequest = LocalResourceImportRequest
  { localImportSourcePath :: FilePath
  , localImportGameDir :: FilePath
  , localImportKind :: Text
  } deriving (Eq, Show)

instance FromJSON LocalResourceImportRequest where
  parseJSON =
    withObject "LocalResourceImportRequest" $ \obj ->
      LocalResourceImportRequest
        <$> obj .: "sourcePath"
        <*> obj .: "gameDir"
        <*> obj .: "kind"

data LocalArchiveRequest = LocalArchiveRequest
  { localArchiveSourcePath :: FilePath
  , localArchiveTargetPath :: FilePath
  } deriving (Eq, Show)

instance FromJSON LocalArchiveRequest where
  parseJSON =
    withObject "LocalArchiveRequest" $ \obj ->
      LocalArchiveRequest
        <$> obj .: "sourcePath"
        <*> obj .: "targetPath"

data LocalArchiveImportRequest = LocalArchiveImportRequest
  { localArchiveImportPath :: FilePath
  , localArchiveImportTargetDir :: FilePath
  , localArchiveImportDeleteArchive :: Bool
  } deriving (Eq, Show)

instance FromJSON LocalArchiveImportRequest where
  parseJSON =
    withObject "LocalArchiveImportRequest" $ \obj ->
      LocalArchiveImportRequest
        <$> obj .: "archivePath"
        <*> obj .: "targetDir"
        <*> (maybe False id <$> obj .:? "deleteArchive")

data MinecraftCleanVersionRequest = MinecraftCleanVersionRequest
  { cleanVersionId :: Text
  , cleanVersionGameDir :: FilePath
  } deriving (Eq, Show)

instance FromJSON MinecraftCleanVersionRequest where
  parseJSON =
    withObject "MinecraftCleanVersionRequest" $ \obj ->
      MinecraftCleanVersionRequest
        <$> obj .: "version"
        <*> obj .: "gameDir"

data MinecraftVersionStorageAction
  = VersionStorageDelete
  | VersionStorageArchive
  | VersionStorageRestore
  deriving (Eq, Show)

instance FromJSON MinecraftVersionStorageAction where
  parseJSON value = do
    action <- parseJSON value
    case (action :: Text) of
      "delete" -> pure VersionStorageDelete
      "archive" -> pure VersionStorageArchive
      "restore" -> pure VersionStorageRestore
      other -> fail ("Unsupported Minecraft version storage action: " <> show other)

data MinecraftVersionStorageRequest = MinecraftVersionStorageRequest
  { versionStorageId :: Text
  , versionStorageGameDir :: FilePath
  , versionStorageAction :: MinecraftVersionStorageAction
  } deriving (Eq, Show)

instance FromJSON MinecraftVersionStorageRequest where
  parseJSON =
    withObject "MinecraftVersionStorageRequest" $ \obj ->
      MinecraftVersionStorageRequest
        <$> obj .: "version"
        <*> obj .: "gameDir"
        <*> obj .: "action"

data LocalResourceMetadata = LocalResourceMetadata
  { metadataDisplayName :: Maybe Text
  , metadataVersion :: Maybe Text
  , metadataAuthors :: [Text]
  , metadataSummary :: Maybe Text
  , metadataIconPath :: Maybe FilePath
  , metadataLoaders :: [Text]
  } deriving (Eq, Show)

instance ToJSON LocalResourceMetadata where
  toJSON metadata =
    object
      [ "displayName" .= metadataDisplayName metadata
      , "version" .= metadataVersion metadata
      , "authors" .= metadataAuthors metadata
      , "summary" .= metadataSummary metadata
      , "iconPath" .= metadataIconPath metadata
      , "loaders" .= metadataLoaders metadata
      ]

data LocalResourceSummary = LocalResourceSummary
  { resourceId :: FilePath
  , resourceName :: Text
  , resourcePath :: FilePath
  , resourceEnabled :: Bool
  , resourceConflictMessage :: Maybe Text
  , resourceMetadata :: LocalResourceMetadata
  , resourceFileSizeBytes :: Integer
  , resourceModifiedAt :: Maybe UTCTime
  , resourceSource :: Maybe Text
  , resourceProjectUrl :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON LocalResourceSummary where
  toJSON resource =
    object
      [ "id" .= resourceId resource
      , "name" .= resourceName resource
      , "path" .= resourcePath resource
      , "isEnabled" .= resourceEnabled resource
      , "conflictMessage" .= resourceConflictMessage resource
      , "metadata" .= resourceMetadata resource
      , "fileSizeBytes" .= resourceFileSizeBytes resource
      , "modifiedAt" .= resourceModifiedAt resource
      , "source" .= resourceSource resource
      , "projectURL" .= resourceProjectUrl resource
      ]

data LocalResourceMutationResponse = LocalResourceMutationResponse
  { mutationChanged :: Bool
  , mutationPath :: Maybe FilePath
  , mutationMessage :: Text
  } deriving (Eq, Show)

instance ToJSON LocalResourceMutationResponse where
  toJSON response =
    object
      [ "changed" .= mutationChanged response
      , "path" .= mutationPath response
      , "message" .= mutationMessage response
      ]
