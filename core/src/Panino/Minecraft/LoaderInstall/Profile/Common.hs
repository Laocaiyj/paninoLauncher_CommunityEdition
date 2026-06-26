{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.LoaderInstall.Profile.Common
  ( mergeDownloadSummaries
  , selectLoaderMetadata
  ) where

import Data.Maybe
  ( listToMaybe
  , maybeToList
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Content.Online.Minecraft
  ( contentLoaderMetadata
  , preferredLoaderMetadata
  )
import Panino.Content.Online.Types
  ( ContentLoaderRequest(..)
  , LoaderMetadata(..)
  )
import Panino.Download.Manager (DownloadSummary(..))
import Panino.Minecraft.LoaderInstall.Names (normalizeLoaderName)

selectLoaderMetadata :: Manager -> Text -> Text -> Maybe Text -> IO LoaderMetadata
selectLoaderMetadata manager minecraftVersion loader maybeLoaderVersion = do
  metadata <- contentLoaderMetadata manager (ContentLoaderRequest minecraftVersion)
  let matches =
        filter (\item -> normalizeLoaderName (loaderMetadataSource item) == normalizeLoaderName loader) metadata
      selected =
        case maybeLoaderVersion of
          Just requestedVersion -> findLoaderMetadataVersion requestedVersion matches
          Nothing -> preferredLoaderMetadata matches
  case maybeToList selected of
    item:_ -> pure item
    [] ->
      fail
        ( "loader_version_not_found: no "
            <> Text.unpack loader
            <> " loader metadata found for Minecraft "
            <> Text.unpack minecraftVersion
            <> maybe "" ((" version " <>) . Text.unpack) maybeLoaderVersion
        )

findLoaderMetadataVersion :: Text -> [LoaderMetadata] -> Maybe LoaderMetadata
findLoaderMetadataVersion requestedVersion =
  listToMaybe . filter ((== requestedVersion) . loaderMetadataLoaderVersion)

mergeDownloadSummaries :: DownloadSummary -> DownloadSummary -> DownloadSummary
mergeDownloadSummaries lhs rhs =
  DownloadSummary
    { downloadedCount = downloadedCount lhs + downloadedCount rhs
    , skippedCount = skippedCount lhs + skippedCount rhs
    , totalCount = totalCount lhs + totalCount rhs
    }
