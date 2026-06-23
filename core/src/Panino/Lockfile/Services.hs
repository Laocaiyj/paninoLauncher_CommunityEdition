{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Services
  ( ServiceEvidence(..)
  , applyServiceEvidence
  , collectServiceEvidence
  , lockfileSolveCacheGameDir
  ) where

import Control.Applicative ((<|>))
import Network.HTTP.Client (Manager)
import Panino.CoreLogic.Determinism
  ( stableSortPackages
  )
import Panino.Lockfile.Services.Evidence
  ( ServiceEvidence(..)
  , applyServiceEvidence
  , mergeServiceEvidence
  , requestWithServiceEvidence
  )
import Panino.Lockfile.Services.Java
  ( javaRuntimeServiceEvidence
  , lockfileSolveCacheGameDir
  )
import Panino.Lockfile.Services.Online
  ( curseForgeDependencyServiceEvidence
  , modrinthDependencyServiceEvidence
  , onlineRootServiceEvidence
  )
import Panino.Lockfile.Services.Preflight
  ( modpackSourceServiceEvidence
  , performancePackServiceEvidence
  , preflightServiceEvidence
  )
import Panino.Lockfile.Types
  ( LockfileSolveRequest(..)
  , resolvedPackageKey
  )

collectServiceEvidence :: Manager -> LockfileSolveRequest -> IO (ServiceEvidence, LockfileSolveRequest)
collectServiceEvidence manager request = do
  preflight <- preflightServiceEvidence manager request
  modpack <- modpackSourceServiceEvidence request
  performancePack <- performancePackServiceEvidence request
  onlineRoots <- onlineRootServiceEvidence manager (requestWithServiceEvidence request (mergeServiceEvidence [preflight, modpack, performancePack]))
  let dependencyRequest = requestWithServiceEvidence request (mergeServiceEvidence [preflight, modpack, performancePack, onlineRoots])
  modrinthDependencies <- modrinthDependencyServiceEvidence manager dependencyRequest
  curseForgeDependencies <- curseForgeDependencyServiceEvidence manager dependencyRequest
  javaRuntime <- javaRuntimeServiceEvidence manager request
  let evidence = mergeServiceEvidence [preflight, modpack, performancePack, onlineRoots, modrinthDependencies, curseForgeDependencies, javaRuntime]
      augmentedRequest =
        request
          { solveRequestLoaderVersion = solveRequestLoaderVersion request <|> serviceLoaderVersion evidence
          , solveRequestJavaPolicy = serviceJavaPolicy evidence <|> solveRequestJavaPolicy request
          , solveRequestRoots =
              solveRequestRoots request
                <> stableSortPackages resolvedPackageKey (servicePackages evidence)
          }
  pure (evidence, augmentedRequest)
