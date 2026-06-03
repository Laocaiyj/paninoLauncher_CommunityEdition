{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Online.Errors
  ( recover
  , requireCurseForgeApiKey
  ) where

import Control.Exception
  ( SomeException
  , catch
  )
import Data.Text (Text)
import qualified Data.Text as Text

requireCurseForgeApiKey :: Maybe Text -> IO Text
requireCurseForgeApiKey (Just value)
  | not (Text.null (Text.strip value)) = pure (Text.strip value)
requireCurseForgeApiKey _ =
  fail "curseforge_api_key_required"

recover :: value -> IO value -> IO value
recover fallback action =
  action `catchAny` const (pure fallback)

catchAny :: IO value -> (SomeException -> IO value) -> IO value
catchAny = catch
