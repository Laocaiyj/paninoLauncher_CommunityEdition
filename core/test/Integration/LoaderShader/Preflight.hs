{-# LANGUAGE OverloadedStrings #-}

module Integration.LoaderShader.Preflight
  ( assertInstallerProbeRateLimitCooldown
  , assertLoaderShaderPreflightFixtures
  ) where

import Control.Concurrent.MVar
  ( newMVar
  , readMVar
  )
import Control.Exception (finally)
import qualified Data.Text as Text
import Integration.LoaderShaderFixtureServer
  ( fakeLoaderShaderPreflightApp
  , rateLimitedInstallerProbeApp
  )
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.Lockfile.Solver
  ( solveLockfileWithServices
  )
import Panino.Lockfile.Types
  ( LockfileSolveRequest(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , solverResultBlockedReasons
  , solverResultLockfile
  , solverResultStatus
  )
import Panino.Minecraft.InstallPreflight
  ( LoaderInstallPreflightRequest(..)
  , LoaderInstallPreflightResponse(..)
  , loaderInstallPreflight
  )
import Panino.Net.Http
  ( makeHttpManager
  )
import System.Environment
  ( setEnv
  , unsetEnv
  )
import TestFixtures
  ( testLockfileSolveRequest
  )
import TestSupport
  ( assertEqual
  )

assertLoaderShaderPreflightFixtures :: IO ()
assertLoaderShaderPreflightFixtures = do
  manager <- makeHttpManager
  testWithApplication (pure fakeLoaderShaderPreflightApp) $ \port ->
    let base = "http://127.0.0.1:" <> show port
        withSources action =
          ( do
              setEnv "PANINO_MOJANG_META_BASE" base
              setEnv "PANINO_FABRIC_META_BASE" base
              setEnv "PANINO_FABRIC_MAVEN_BASE" base
              setEnv "PANINO_QUILT_META_BASE" base
              setEnv "PANINO_FORGE_FILES_BASE" base
              setEnv "PANINO_FORGE_MAVEN_BASE" base
              setEnv "PANINO_NEOFORGE_MAVEN_BASE" base
              setEnv "PANINO_MODRINTH_API_BASE" base
              setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
              action
          )
            `finally` do
              unsetEnv "PANINO_MOJANG_META_BASE"
              unsetEnv "PANINO_FABRIC_META_BASE"
              unsetEnv "PANINO_FABRIC_MAVEN_BASE"
              unsetEnv "PANINO_QUILT_META_BASE"
              unsetEnv "PANINO_FORGE_FILES_BASE"
              unsetEnv "PANINO_FORGE_MAVEN_BASE"
              unsetEnv "PANINO_NEOFORGE_MAVEN_BASE"
              unsetEnv "PANINO_MODRINTH_API_BASE"
              unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
     in withSources $ do
          let run minecraftVersion loader shader javaExecutable =
                loaderInstallPreflight
                  manager
                  LoaderInstallPreflightRequest
                    { preflightMinecraftVersion = minecraftVersion
                    , preflightLoader = loader
                    , preflightLoaderVersion = Nothing
                    , preflightShaderLoader = shader
                    , preflightShaderVersion = Nothing
                    , preflightGameDir = Nothing
                    , preflightJavaExecutable = javaExecutable
                    , preflightSourceProfile = Nothing
                    }
          fabricOk <- run "26.1.2" (Just "fabric") (Just "iris") (Just "/usr/bin/java")
          assertEqual "Fabric + Iris fixture preflight ok" [] (preflightResponseBlockedReasons fabricOk)
          assertEqual "Fabric fixture selects loader" (Just "0.16.0") (preflightResponseLoaderVersion fabricOk)
          assertEqual "Iris fixture resolves Fabric API companion" True ("fabric-api" `elem` preflightResponseShaderProjects fabricOk)
          lockfilePreflightResult <-
            solveLockfileWithServices
              manager
              ( (testLockfileSolveRequest "/tmp/panino-lockfile-preflight" [] Nothing)
                  { solveRequestMinecraftVersion = Just "26.1.2"
                  , solveRequestLoader = Just "fabric"
                  , solveRequestLoaderVersion = Nothing
                  , solveRequestShaderLoader = Just "iris"
                  }
              )
          let lockfilePreflightPackages =
                maybe [] lockfilePackages (solverResultLockfile lockfilePreflightResult)
              lockfilePreflightPackageIds =
                map resolvedPackageId lockfilePreflightPackages
              lockfilePreflightLoaderVersions =
                [ coordinateVersionId (resolvedPackageCoordinate package)
                | package <- lockfilePreflightPackages
                , resolvedPackageId package == "loader:fabric"
                ]
          assertEqual ("lockfile solver reuses install preflight: " <> show (solverResultBlockedReasons lockfilePreflightResult)) "ready" (solverResultStatus lockfilePreflightResult)
          assertEqual "lockfile solver carries preflight loader version" [Just "0.16.0"] lockfilePreflightLoaderVersions
          assertEqual "lockfile solver carries preflight shader dependency" True ("fabric-api" `elem` lockfilePreflightPackageIds)

          fabricMissing <- run "unsupported" (Just "fabric") Nothing (Just "/usr/bin/java")
          assertEqual "Fabric unsupported fixture blocks" True (any ("loader_version_not_found" `Text.isPrefixOf`) (preflightResponseBlockedReasons fabricMissing))

          quiltOk <- run "26.1.2" (Just "quilt") Nothing (Just "/usr/bin/java")
          assertEqual "Quilt fixture preflight ok" [] (preflightResponseBlockedReasons quiltOk)
          assertEqual "Quilt fixture selects latest stable loader" (Just "0.29.1") (preflightResponseLoaderVersion quiltOk)

          quiltIrisOk <- run "26.1.2" (Just "quilt") (Just "iris") (Just "/usr/bin/java")
          assertEqual
            "Quilt + Iris fixture preflight falls back to Fabric release"
            []
            (preflightResponseBlockedReasons quiltIrisOk)
          assertEqual "Quilt + Iris fixture records resolved shader loader" (Just "fabric") (preflightResponseShaderResolvedLoader quiltIrisOk)
          assertEqual "Quilt + Iris fixture records fallback source" (Just "quilt") (preflightResponseShaderFallbackFrom quiltIrisOk)
          assertEqual "Quilt + Iris fixture records fallback target" (Just "fabric") (preflightResponseShaderFallbackTo quiltIrisOk)
          assertEqual "Quilt + Iris fixture warns about fallback" True (any ("shader_loader_fallback:" `Text.isPrefixOf`) (preflightResponseWarnings quiltIrisOk))

          quiltMissing <- run "unsupported" (Just "quilt") Nothing (Just "/usr/bin/java")
          assertEqual "Quilt unsupported fixture blocks" True (any ("loader_version_not_found" `Text.isPrefixOf`) (preflightResponseBlockedReasons quiltMissing))

          forgeJavaMissing <- run "26.1.2" (Just "forge") Nothing Nothing
          assertEqual "Forge Java missing fixture does not block preflight" [] (preflightResponseBlockedReasons forgeJavaMissing)
          assertEqual "Forge Java missing fixture warns" True (any ("loader_installer_java_missing" `Text.isPrefixOf`) (preflightResponseWarnings forgeJavaMissing))

          forgeDownloadMissing <- run "forge-missing-installer" (Just "forge") Nothing (Just "/usr/bin/java")
          assertEqual "Forge installer HEAD failure does not block when range GET is available" [] (preflightResponseBlockedReasons forgeDownloadMissing)
          assertEqual "Forge installer HEAD failure records probe status" True (maybe False ("range-get:ok" `Text.isPrefixOf`) (preflightResponseInstallerProbeStatus forgeDownloadMissing))

          forgeOculusOk <- run "26.1.2" (Just "forge") (Just "oculus") (Just "/usr/bin/java")
          assertEqual "Forge + Oculus fixture preflight ok" [] (preflightResponseBlockedReasons forgeOculusOk)
          assertEqual "Forge + Oculus fixture resolves Oculus project" True ("oculus" `elem` preflightResponseShaderProjects forgeOculusOk)

          neoForgeOculusOk <- run "26.1.2" (Just "neoforge") (Just "oculus") (Just "/usr/bin/java")
          assertEqual "NeoForge + Oculus fixture preflight ok through Forge release fallback" [] (preflightResponseBlockedReasons neoForgeOculusOk)
          assertEqual "NeoForge + Oculus fixture resolves Oculus project through fallback" True ("oculus" `elem` preflightResponseShaderProjects neoForgeOculusOk)
          assertEqual "NeoForge + Oculus fixture records Forge fallback" (Just "forge") (preflightResponseShaderResolvedLoader neoForgeOculusOk)

          irisWrongLoader <- run "26.1.2" (Just "forge") (Just "iris") (Just "/usr/bin/java")
          assertEqual "Iris with Forge fixture blocks" True (any ("shader_loader_incompatible" `Text.isPrefixOf`) (preflightResponseBlockedReasons irisWrongLoader))

          oculusWrongLoader <- run "26.1.2" (Just "fabric") (Just "oculus") (Just "/usr/bin/java")
          assertEqual "Oculus with Fabric fixture blocks" True (any ("shader_loader_incompatible" `Text.isPrefixOf`) (preflightResponseBlockedReasons oculusWrongLoader))

          optifine <- run "26.1.2" Nothing (Just "optifine") (Just "/usr/bin/java")
          assertEqual "OptiFine fixture manual install does not block preflight" [] (preflightResponseBlockedReasons optifine)
          assertEqual "OptiFine fixture manual install warns" True (any ("manual_install_required" `Text.isPrefixOf`) (preflightResponseWarnings optifine))

          shaderDependencyMissing <- run "bad-dep" (Just "fabric") (Just "iris") (Just "/usr/bin/java")
          assertEqual "Shader dependency fixture blocks" True (any ("shader_dependency_unresolved" `Text.isPrefixOf`) (preflightResponseBlockedReasons shaderDependencyMissing))

assertInstallerProbeRateLimitCooldown :: IO ()
assertInstallerProbeRateLimitCooldown = do
  manager <- makeHttpManager
  headRequests <- newMVar (0 :: Int)
  rangeRequests <- newMVar (0 :: Int)
  testWithApplication (pure (rateLimitedInstallerProbeApp headRequests rangeRequests)) $ \port -> do
    let base = "http://127.0.0.1:" <> show port
        withSources action =
          ( do
              setEnv "PANINO_FABRIC_META_BASE" base
              setEnv "PANINO_QUILT_META_BASE" base
              setEnv "PANINO_FORGE_FILES_BASE" base
              setEnv "PANINO_FORGE_MAVEN_BASE" base
              setEnv "PANINO_NEOFORGE_MAVEN_BASE" base
              setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
              action
          )
            `finally` do
              unsetEnv "PANINO_FABRIC_META_BASE"
              unsetEnv "PANINO_QUILT_META_BASE"
              unsetEnv "PANINO_FORGE_FILES_BASE"
              unsetEnv "PANINO_FORGE_MAVEN_BASE"
              unsetEnv "PANINO_NEOFORGE_MAVEN_BASE"
              unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
        run =
          loaderInstallPreflight
            manager
            LoaderInstallPreflightRequest
              { preflightMinecraftVersion = "26.1.429"
              , preflightLoader = Just "forge"
              , preflightLoaderVersion = Nothing
              , preflightShaderLoader = Nothing
              , preflightShaderVersion = Nothing
              , preflightGameDir = Nothing
              , preflightJavaExecutable = Just "/usr/bin/java"
              , preflightSourceProfile = Nothing
              }
    withSources $ do
      first <- run
      second <- run
      heads <- readMVar headRequests
      ranges <- readMVar rangeRequests
      assertEqual "Forge 429 probe remains non-blocking" [] (preflightResponseBlockedReasons first)
      assertEqual "cached Forge 429 probe remains non-blocking" [] (preflightResponseBlockedReasons second)
      assertEqual "Forge 429 probe does not fall through to range GET" 0 ranges
      assertEqual "Forge 429 probe is cached across repeated preflights" 1 heads
