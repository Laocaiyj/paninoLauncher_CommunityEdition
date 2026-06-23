{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Types.Download
  ( DownloadRuntimeOptions(..)
  , emptyDownloadRuntimeOptions
  , mergeDownloadRuntimeOptions
  ) where

import Control.Applicative ((<|>))
import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , object
  , withObject
  , (.:?)
  , (.=)
  )
import Data.Text (Text)

data DownloadRuntimeOptions = DownloadRuntimeOptions
  { downloadRuntimeConcurrency :: Maybe Int
  , downloadRuntimeRetryCount :: Maybe Int
  , downloadRuntimeStrategy :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON DownloadRuntimeOptions where
  parseJSON =
    withObject "DownloadRuntimeOptions" $ \objectValue ->
      DownloadRuntimeOptions
        <$> objectValue .:? "concurrency"
        <*> objectValue .:? "retryCount"
        <*> objectValue .:? "strategy"

instance ToJSON DownloadRuntimeOptions where
  toJSON options =
    object
      [ "concurrency" .= downloadRuntimeConcurrency options
      , "retryCount" .= downloadRuntimeRetryCount options
      , "strategy" .= downloadRuntimeStrategy options
      ]

emptyDownloadRuntimeOptions :: DownloadRuntimeOptions
emptyDownloadRuntimeOptions =
  DownloadRuntimeOptions
    { downloadRuntimeConcurrency = Nothing
    , downloadRuntimeRetryCount = Nothing
    , downloadRuntimeStrategy = Nothing
    }

mergeDownloadRuntimeOptions :: Maybe Int -> Maybe Int -> Maybe Text -> Maybe DownloadRuntimeOptions -> DownloadRuntimeOptions
mergeDownloadRuntimeOptions legacyConcurrency legacyRetryCount legacyStrategy nested =
  DownloadRuntimeOptions
    { downloadRuntimeConcurrency =
        (nested >>= downloadRuntimeConcurrency) <|> legacyConcurrency
    , downloadRuntimeRetryCount =
        (nested >>= downloadRuntimeRetryCount) <|> legacyRetryCount
    , downloadRuntimeStrategy =
        (nested >>= downloadRuntimeStrategy) <|> legacyStrategy
    }
