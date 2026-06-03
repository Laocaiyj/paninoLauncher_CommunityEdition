{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Content.Local.Scan
  ( scanLocalResources
  ) where

import Control.Exception
  ( SomeException
  , catch
  )
import Data.List (sortOn)
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory
  ( createDirectoryIfMissing
  , getFileSize
  , getModificationTime
  , listDirectory
  )
import System.FilePath
  ( dropExtension
  , takeExtension
  , takeFileName
  , (</>)
  )
import Panino.Content.Local.Conflict
  ( conflictHint
  , inferredSource
  )
import Panino.Content.Local.Metadata (metadataFor)
import Panino.Content.Local.Path
  ( lowerFileName
  , resourceFolderName
  , supportedResourceFile
  )
import Panino.Content.Local.Types

scanLocalResources :: LocalResourceScanRequest -> IO [LocalResourceSummary]
scanLocalResources request = do
  let folder = localResourceGameDir request </> resourceFolderName (localResourceKind request)
  createDirectoryIfMissing True folder
  names <- listDirectory folder
  let paths = sortOn lowerFileName [folder </> name | name <- names, supportedResourceFile name]
  traverse
    (resourceSummary (localResourceKind request) (localResourceLoader request))
    paths

resourceSummary :: Text -> Maybe Text -> FilePath -> IO LocalResourceSummary
resourceSummary kind selectedLoader path = do
  let enabled = takeExtension path /= ".disabled"
      name = if enabled then takeFileName path else takeFileName (dropExtension path)
  metadata <- metadataFor kind path
  size <- getFileSize path
  modified <- (Just <$> getModificationTime path) `catch` \(_ :: SomeException) -> pure Nothing
  pure
    LocalResourceSummary
      { resourceId = path
      , resourceName = Text.pack name
      , resourcePath = path
      , resourceEnabled = enabled
      , resourceConflictMessage = conflictHint kind selectedLoader name metadata
      , resourceMetadata = metadata
      , resourceFileSizeBytes = size
      , resourceModifiedAt = modified
      , resourceSource = inferredSource name
      , resourceProjectUrl = Nothing
      }
