{-# LANGUAGE OverloadedStrings #-}

module Panino.Core.Types
  ( GameDir
  , ProjectId
  , RelativePath
  , Sha1
  , Url
  , VersionId
  , gameDirFromPath
  , gameDirPath
  , projectIdFromText
  , projectIdText
  , relativePathFromFilePath
  , relativePathFilePath
  , sha1FromText
  , sha1Text
  , urlFromString
  , urlFromText
  , urlString
  , urlText
  , versionIdFromText
  , versionIdText
  ) where

import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , withText
  )
import Data.Aeson.Types (Parser)
import Data.String (IsString(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Core.WireText
  ( WireText(..)
  , toWireTextJSON
  )

newtype GameDir =
  GameDir FilePath
  deriving (Eq, Ord)

newtype VersionId =
  VersionId Text
  deriving (Eq, Ord)

newtype ProjectId =
  ProjectId Text
  deriving (Eq, Ord)

newtype Sha1 =
  Sha1 Text
  deriving (Eq, Ord)

newtype Url =
  Url Text
  deriving (Eq, Ord)

newtype RelativePath =
  RelativePath FilePath
  deriving (Eq, Ord)

instance Show GameDir where
  show = gameDirPath

instance Show VersionId where
  show = Text.unpack . versionIdText

instance Show ProjectId where
  show = Text.unpack . projectIdText

instance Show Sha1 where
  show = Text.unpack . sha1Text

instance Show Url where
  show = Text.unpack . urlText

instance Show RelativePath where
  show = relativePathFilePath

instance IsString VersionId where
  fromString = VersionId . Text.pack

instance IsString GameDir where
  fromString = GameDir

instance IsString ProjectId where
  fromString = ProjectId . Text.pack

instance IsString Sha1 where
  fromString = Sha1 . Text.toLower . Text.pack

instance IsString Url where
  fromString = Url . Text.pack

instance IsString RelativePath where
  fromString = RelativePath

gameDirFromPath :: FilePath -> Maybe GameDir
gameDirFromPath path =
  GameDir <$> nonEmptyString path

gameDirPath :: GameDir -> FilePath
gameDirPath (GameDir path) = path

versionIdFromText :: Text -> Maybe VersionId
versionIdFromText value =
  VersionId <$> nonEmptyText value

versionIdText :: VersionId -> Text
versionIdText (VersionId value) = value

projectIdFromText :: Text -> Maybe ProjectId
projectIdFromText value =
  ProjectId <$> nonEmptyText value

projectIdText :: ProjectId -> Text
projectIdText (ProjectId value) = value

sha1FromText :: Text -> Maybe Sha1
sha1FromText value =
  Sha1 . Text.toLower <$> nonEmptyText value

sha1Text :: Sha1 -> Text
sha1Text (Sha1 value) = value

urlFromString :: String -> Url
urlFromString =
  Url . Text.pack

urlFromText :: Text -> Url
urlFromText =
  Url

urlString :: Url -> String
urlString =
  Text.unpack . urlText

urlText :: Url -> Text
urlText (Url value) = value

relativePathFromFilePath :: FilePath -> Maybe RelativePath
relativePathFromFilePath path =
  RelativePath <$> nonEmptyString path

relativePathFilePath :: RelativePath -> FilePath
relativePathFilePath (RelativePath path) = path

instance WireText GameDir where
  wireText = Text.pack . gameDirPath
  parseWireText = fromString . Text.unpack

instance WireText VersionId where
  wireText = versionIdText
  parseWireText = fromString . Text.unpack

instance WireText ProjectId where
  wireText = projectIdText
  parseWireText = fromString . Text.unpack

instance WireText Sha1 where
  wireText = sha1Text
  parseWireText = fromString . Text.unpack

instance WireText Url where
  wireText = urlText
  parseWireText = urlFromText

instance WireText RelativePath where
  wireText = Text.pack . relativePathFilePath
  parseWireText = fromString . Text.unpack

instance ToJSON GameDir where
  toJSON = toWireTextJSON

instance FromJSON GameDir where
  parseJSON =
    withText "GameDir" (parseNonEmpty "GameDir" (gameDirFromPath . Text.unpack))

instance ToJSON VersionId where
  toJSON = toWireTextJSON

instance FromJSON VersionId where
  parseJSON =
    withText "VersionId" (parseNonEmpty "VersionId" versionIdFromText)

instance ToJSON ProjectId where
  toJSON = toWireTextJSON

instance FromJSON ProjectId where
  parseJSON =
    withText "ProjectId" (parseNonEmpty "ProjectId" projectIdFromText)

instance ToJSON Sha1 where
  toJSON = toWireTextJSON

instance FromJSON Sha1 where
  parseJSON =
    withText "Sha1" (parseNonEmpty "Sha1" sha1FromText)

instance ToJSON Url where
  toJSON = toWireTextJSON

instance FromJSON Url where
  parseJSON =
    withText "Url" (pure . urlFromText)

instance ToJSON RelativePath where
  toJSON = toWireTextJSON

instance FromJSON RelativePath where
  parseJSON =
    withText "RelativePath" (parseNonEmpty "RelativePath" (relativePathFromFilePath . Text.unpack))

nonEmptyText :: Text -> Maybe Text
nonEmptyText value =
  let trimmed = Text.strip value
   in if Text.null trimmed then Nothing else Just trimmed

nonEmptyString :: String -> Maybe String
nonEmptyString value =
  let trimmed = Text.unpack (Text.strip (Text.pack value))
   in if null trimmed then Nothing else Just trimmed

parseNonEmpty :: String -> (Text -> Maybe a) -> Text -> Parser a
parseNonEmpty label build value =
  case build value of
    Just parsed -> pure parsed
    Nothing -> fail (label <> " must not be empty")
