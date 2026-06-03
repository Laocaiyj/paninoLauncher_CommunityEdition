{-# LANGUAGE OverloadedStrings #-}

module Property.Lockfile
  ( prop_lockfileFingerprintIgnoresPackageOrder
  ) where

import Panino.Lockfile.Plan (lockfileFingerprintFor)
import Property.Generators
  ( simpleLockfile
  , simplePackage
  )
import Test.QuickCheck
  ( Property
  , property
  )

prop_lockfileFingerprintIgnoresPackageOrder :: Property
prop_lockfileFingerprintIgnoresPackageOrder =
  let packageA = simplePackage "fabric-api"
      packageB = simplePackage "iris"
      lockfileA = simpleLockfile [packageA, packageB]
      lockfileB = simpleLockfile [packageB, packageA]
   in property (lockfileFingerprintFor lockfileA == lockfileFingerprintFor lockfileB)
