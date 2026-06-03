{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Local.Import
  ( importLocalResource
  ) where

import System.Directory
  ( copyFile
  , createDirectoryIfMissing
  )
import System.FilePath
  ( takeFileName
  , (</>)
  )
import Panino.Content.Local.Path
  ( removePathIfExists
  , resourceFolderName
  )
import Panino.Content.Local.Types

importLocalResource :: LocalResourceImportRequest -> IO LocalResourceMutationResponse
importLocalResource request = do
  let destinationFolder =
        localImportGameDir request </> resourceFolderName (localImportKind request)
      destinationPath = destinationFolder </> takeFileName (localImportSourcePath request)
  createDirectoryIfMissing True destinationFolder
  removePathIfExists destinationPath
  copyFile (localImportSourcePath request) destinationPath
  pure
    LocalResourceMutationResponse
      { mutationChanged = True
      , mutationPath = Just destinationPath
      , mutationMessage = "Resource imported"
      }
