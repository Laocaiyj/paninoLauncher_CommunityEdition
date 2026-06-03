module Property.Runner
  ( runProperties
  ) where

import qualified Property.Compatibility as Compatibility
import qualified Property.Diagnostics as Diagnostics
import qualified Property.Lockfile as Lockfile
import qualified Property.Performance as Performance
import qualified Property.Plan as Plan
import Test.QuickCheck
  ( Args(..)
  , Result(..)
  , Testable
  , quickCheckWithResult
  , stdArgs
  )

runProperties :: IO ()
runProperties = do
  runProperty "compatibility blocked report has cause and action" Compatibility.prop_blockedReportHasCauseAndAction
  runProperty "compatibility Java major mismatch blocks" Compatibility.prop_javaMajorBelowRequirementBlocks
  runProperty "compatibility loader mismatch blocks" Compatibility.prop_loaderMismatchBlocks
  runProperty "compatibility JSON roundtrip" Compatibility.prop_compatibilityJsonRoundtrip
  runProperty "diagnostic JSON roundtrip" Diagnostics.prop_diagnosticJsonRoundtrip
  runProperty "typed install plan fingerprint stable with input order" Plan.prop_planFingerprintStableWithInputOrder
  runProperty "unsafe target path blocks executable plan" Plan.prop_unsafePathBlocksExecutablePlan
  runProperty "lockfile fingerprint ignores package order" Lockfile.prop_lockfileFingerprintIgnoresPackageOrder
  runProperty "performance session JSON roundtrip" Performance.prop_performanceSessionJsonRoundtrip

runProperty :: Testable prop => String -> prop -> IO ()
runProperty label prop = do
  putStrLn ("[property] " <> label)
  result <- quickCheckWithResult propertyArgs prop
  case result of
    Success {} -> pure ()
    _ -> fail ("Property failed: " <> label)

propertyArgs :: Args
propertyArgs =
  stdArgs { maxSuccess = 100 }
