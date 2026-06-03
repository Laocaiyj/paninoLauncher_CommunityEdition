{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Params
  ( decodeBody
  ) where

import Data.Aeson
  ( FromJSON
  , eitherDecode
  )
import Network.Wai
  ( Request
  , strictRequestBody
  )

decodeBody :: FromJSON value => Request -> IO (Either String value)
decodeBody request =
  eitherDecode <$> strictRequestBody request
