{-# LANGUAGE OverloadedStrings #-}

module Panino.Compatibility.Types
  ( CompatibilityEvaluateRequest(..)
  , CompatibilityPackageInput(..)
  , CompatibilityPackageReport(..)
  , CompatibilityReport(..)
  , CompatibilityStatus(..)
  , CompatibilityTarget(..)
  , compatibilityStatusFromText
  , compatibilityStatusText
  ) where

import Control.Applicative ((<|>))
import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , withText
  , (.:)
  , (.:?)
  , (.!=)
  , (.=)
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Diagnostics.Types
  ( Diagnostic
  , DiagnosticAction
  )

data CompatibilityStatus
  = CompatibilityCompatible
  | CompatibilityWarning
  | CompatibilityBlocked
  | CompatibilityUnknown
  deriving (Eq, Ord, Show)

compatibilityStatusText :: CompatibilityStatus -> Text
compatibilityStatusText status =
  case status of
    CompatibilityCompatible -> "compatible"
    CompatibilityWarning -> "warning"
    CompatibilityBlocked -> "blocked"
    CompatibilityUnknown -> "unknown"

compatibilityStatusFromText :: Text -> CompatibilityStatus
compatibilityStatusFromText value =
  case Text.toLower (Text.strip value) of
    "compatible" -> CompatibilityCompatible
    "ok" -> CompatibilityCompatible
    "ready" -> CompatibilityCompatible
    "warning" -> CompatibilityWarning
    "blocked" -> CompatibilityBlocked
    "unknown" -> CompatibilityUnknown
    _ -> CompatibilityUnknown

instance ToJSON CompatibilityStatus where
  toJSON =
    toJSON . compatibilityStatusText

instance FromJSON CompatibilityStatus where
  parseJSON =
    withText "CompatibilityStatus" (pure . compatibilityStatusFromText)

data CompatibilityTarget = CompatibilityTarget
  { compatibilityTargetMinecraftVersion :: Maybe Text
  , compatibilityTargetLoader :: Maybe Text
  , compatibilityTargetLoaderVersion :: Maybe Text
  , compatibilityTargetShaderLoader :: Maybe Text
  , compatibilityTargetGameDir :: Maybe FilePath
  , compatibilityTargetJavaMajor :: Maybe Int
  , compatibilityTargetRequiredJavaMajor :: Maybe Int
  , compatibilityTargetJavaArch :: Maybe Text
  , compatibilityTargetSystemArch :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON CompatibilityTarget where
  toJSON target =
    object
      [ "minecraftVersion" .= compatibilityTargetMinecraftVersion target
      , "loader" .= compatibilityTargetLoader target
      , "loaderVersion" .= compatibilityTargetLoaderVersion target
      , "shaderLoader" .= compatibilityTargetShaderLoader target
      , "gameDir" .= compatibilityTargetGameDir target
      , "javaMajor" .= compatibilityTargetJavaMajor target
      , "requiredJavaMajor" .= compatibilityTargetRequiredJavaMajor target
      , "javaArch" .= compatibilityTargetJavaArch target
      , "systemArch" .= compatibilityTargetSystemArch target
      ]

instance FromJSON CompatibilityTarget where
  parseJSON =
    withObject "CompatibilityTarget" $ \obj ->
      CompatibilityTarget
        <$> (obj .:? "minecraftVersion" <|> obj .:? "version")
        <*> obj .:? "loader"
        <*> obj .:? "loaderVersion"
        <*> obj .:? "shaderLoader"
        <*> obj .:? "gameDir"
        <*> (obj .:? "javaMajor" <|> obj .:? "selectedJavaMajor")
        <*> (obj .:? "requiredJavaMajor" <|> obj .:? "javaRequirement")
        <*> obj .:? "javaArch"
        <*> obj .:? "systemArch"

data CompatibilityPackageInput = CompatibilityPackageInput
  { compatibilityPackageId :: Text
  , compatibilityPackageName :: Text
  , compatibilityPackageSource :: Maybe Text
  , compatibilityPackageKind :: Text
  , compatibilityPackageMinecraftVersions :: [Text]
  , compatibilityPackageLoaders :: [Text]
  , compatibilityPackageRequiredDependencies :: [Text]
  , compatibilityPackageOptionalDependencies :: [Text]
  , compatibilityPackagePresent :: Bool
  , compatibilityPackageMetadataComplete :: Bool
  , compatibilityPackageJavaMajor :: Maybe Int
  } deriving (Eq, Show)

instance ToJSON CompatibilityPackageInput where
  toJSON package =
    object
      [ "id" .= compatibilityPackageId package
      , "name" .= compatibilityPackageName package
      , "source" .= compatibilityPackageSource package
      , "kind" .= compatibilityPackageKind package
      , "minecraftVersions" .= compatibilityPackageMinecraftVersions package
      , "loaders" .= compatibilityPackageLoaders package
      , "requiredDependencies" .= compatibilityPackageRequiredDependencies package
      , "optionalDependencies" .= compatibilityPackageOptionalDependencies package
      , "present" .= compatibilityPackagePresent package
      , "metadataComplete" .= compatibilityPackageMetadataComplete package
      , "javaMajor" .= compatibilityPackageJavaMajor package
      ]

instance FromJSON CompatibilityPackageInput where
  parseJSON =
    withObject "CompatibilityPackageInput" $ \obj -> do
      ident <- obj .:? "id" .!= ""
      name <- obj .:? "name" .!= ident
      CompatibilityPackageInput
        <$> pure ident
        <*> pure name
        <*> obj .:? "source"
        <*> obj .:? "kind" .!= "mod"
        <*> (obj .:? "minecraftVersions" .!= [] <|> obj .:? "gameVersions" .!= [])
        <*> obj .:? "loaders" .!= []
        <*> obj .:? "requiredDependencies" .!= []
        <*> obj .:? "optionalDependencies" .!= []
        <*> obj .:? "present" .!= True
        <*> obj .:? "metadataComplete" .!= True
        <*> obj .:? "javaMajor"

data CompatibilityPackageReport = CompatibilityPackageReport
  { compatibilityPackageReportId :: Text
  , compatibilityPackageReportName :: Text
  , compatibilityPackageReportStatus :: CompatibilityStatus
  , compatibilityPackageReportDiagnostics :: [Diagnostic]
  , compatibilityPackageReportBlockedReasons :: [Text]
  , compatibilityPackageReportWarnings :: [Text]
  , compatibilityPackageReportActions :: [DiagnosticAction]
  } deriving (Eq, Show)

instance ToJSON CompatibilityPackageReport where
  toJSON report =
    object
      [ "id" .= compatibilityPackageReportId report
      , "name" .= compatibilityPackageReportName report
      , "status" .= compatibilityPackageReportStatus report
      , "diagnostics" .= compatibilityPackageReportDiagnostics report
      , "blockedReasons" .= compatibilityPackageReportBlockedReasons report
      , "warnings" .= compatibilityPackageReportWarnings report
      , "actions" .= compatibilityPackageReportActions report
      ]

instance FromJSON CompatibilityPackageReport where
  parseJSON =
    withObject "CompatibilityPackageReport" $ \obj ->
      CompatibilityPackageReport
        <$> obj .: "id"
        <*> obj .:? "name" .!= ""
        <*> obj .:? "status" .!= CompatibilityUnknown
        <*> obj .:? "diagnostics" .!= []
        <*> obj .:? "blockedReasons" .!= []
        <*> obj .:? "warnings" .!= []
        <*> obj .:? "actions" .!= []

data CompatibilityReport = CompatibilityReport
  { compatibilityReportStatus :: CompatibilityStatus
  , compatibilityReportTarget :: CompatibilityTarget
  , compatibilityReportPackageReports :: [CompatibilityPackageReport]
  , compatibilityReportGlobalDiagnostics :: [Diagnostic]
  , compatibilityReportBlockedReasons :: [Text]
  , compatibilityReportWarnings :: [Text]
  , compatibilityReportActions :: [DiagnosticAction]
  , compatibilityReportSummary :: Text
  } deriving (Eq, Show)

instance ToJSON CompatibilityReport where
  toJSON report =
    object
      [ "status" .= compatibilityReportStatus report
      , "target" .= compatibilityReportTarget report
      , "packageReports" .= compatibilityReportPackageReports report
      , "globalDiagnostics" .= compatibilityReportGlobalDiagnostics report
      , "blockedReasons" .= compatibilityReportBlockedReasons report
      , "warnings" .= compatibilityReportWarnings report
      , "actions" .= compatibilityReportActions report
      , "summary" .= compatibilityReportSummary report
      ]

instance FromJSON CompatibilityReport where
  parseJSON =
    withObject "CompatibilityReport" $ \obj ->
      CompatibilityReport
        <$> obj .:? "status" .!= CompatibilityUnknown
        <*> obj .: "target"
        <*> obj .:? "packageReports" .!= []
        <*> obj .:? "globalDiagnostics" .!= []
        <*> obj .:? "blockedReasons" .!= []
        <*> obj .:? "warnings" .!= []
        <*> obj .:? "actions" .!= []
        <*> obj .:? "summary" .!= ""

data CompatibilityEvaluateRequest = CompatibilityEvaluateRequest
  { compatibilityRequestTarget :: CompatibilityTarget
  , compatibilityRequestPackages :: [CompatibilityPackageInput]
  , compatibilityRequestInstalledPackageIds :: [Text]
  , compatibilityRequestMissingRequiredDependencies :: [Text]
  , compatibilityRequestMissingOptionalDependencies :: [Text]
  , compatibilityRequestBlockedReasons :: [Text]
  , compatibilityRequestWarnings :: [Text]
  } deriving (Eq, Show)

instance ToJSON CompatibilityEvaluateRequest where
  toJSON request =
    object
      [ "target" .= compatibilityRequestTarget request
      , "packages" .= compatibilityRequestPackages request
      , "installedPackageIds" .= compatibilityRequestInstalledPackageIds request
      , "missingRequiredDependencies" .= compatibilityRequestMissingRequiredDependencies request
      , "missingOptionalDependencies" .= compatibilityRequestMissingOptionalDependencies request
      , "blockedReasons" .= compatibilityRequestBlockedReasons request
      , "warnings" .= compatibilityRequestWarnings request
      ]

instance FromJSON CompatibilityEvaluateRequest where
  parseJSON =
    withObject "CompatibilityEvaluateRequest" $ \obj -> do
      maybeTarget <- obj .:? "target"
      target <-
        case maybeTarget of
          Just value -> pure value
          Nothing ->
            CompatibilityTarget
              <$> (obj .:? "minecraftVersion" <|> obj .:? "version")
              <*> obj .:? "loader"
              <*> obj .:? "loaderVersion"
              <*> obj .:? "shaderLoader"
              <*> obj .:? "gameDir"
              <*> (obj .:? "javaMajor" <|> obj .:? "selectedJavaMajor")
              <*> (obj .:? "requiredJavaMajor" <|> obj .:? "javaRequirement")
              <*> obj .:? "javaArch"
              <*> obj .:? "systemArch"
      CompatibilityEvaluateRequest
        <$> pure target
        <*> obj .:? "packages" .!= []
        <*> obj .:? "installedPackageIds" .!= []
        <*> obj .:? "missingRequiredDependencies" .!= []
        <*> obj .:? "missingOptionalDependencies" .!= []
        <*> obj .:? "blockedReasons" .!= []
        <*> obj .:? "warnings" .!= []
