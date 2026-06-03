{-# LANGUAGE OverloadedStrings #-}

module Property.Performance
  ( prop_performanceSessionJsonRoundtrip
  ) where

import Data.Aeson
  ( decode
  , encode
  )
import Panino.Performance.Telemetry.Types (PerformanceSession)
import Property.Generators (simplePerformanceSession)
import Test.QuickCheck
  ( Property
  , (===)
  )

prop_performanceSessionJsonRoundtrip :: Property
prop_performanceSessionJsonRoundtrip =
  decode (encode simplePerformanceSession) === Just (simplePerformanceSession :: PerformanceSession)
