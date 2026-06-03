{-# LANGUAGE OverloadedStrings #-}

module Property.Diagnostics
  ( prop_diagnosticJsonRoundtrip
  ) where

import Data.Aeson
  ( decode
  , encode
  )
import Panino.Diagnostics.Types (Diagnostic)
import Property.Generators (genDiagnostic)
import Test.QuickCheck
  ( Property
  , forAll
  , (===)
  )

prop_diagnosticJsonRoundtrip :: Property
prop_diagnosticJsonRoundtrip =
  forAll genDiagnostic $ \diagnostic ->
    decode (encode diagnostic) === Just (diagnostic :: Diagnostic)
