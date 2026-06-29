{-# LANGUAGE OverloadedStrings #-}

module Integration.ModrinthDependencyResolver
  ( assertModrinthDependencyResolver
  ) where

import Control.Exception (finally)
import qualified Data.ByteString.Char8 as BS8
import Integration.ModrinthDependencyResolver.JavaPolicy
  ( assertLockfileJavaPolicySolves
  )
import Integration.LoaderShaderFixtureServer
  ( curseForgeFilesFixture
  , curseForgeProjectFixture
  , minecraftManifestFixture
  , minecraftVersionFixture
  , modrinthDependencyVersionsJson
  , modrinthIrisVersionsJson
  , modrinthProjectMetadataFixture
  )
import Network.HTTP.Types
  ( hContentType
  , status200
  )
import Network.Wai
  ( rawPathInfo
  , requestHeaderHost
  , responseLBS
  )
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.Content.Online.Modrinth
  ( modrinthRequiredDependencyReleases
  )
import Panino.Content.Online.Types
  ( ContentSearchRequest(..)
  , OnlineDependency(..)
  , OnlineFile(..)
  , OnlineRelease(..)
  , onlineReleaseIdText
  )
import Panino.Lockfile.Solver
  ( solveLockfileWithServices
  )
import Panino.Lockfile.Types
  ( LockfileSolveRequest(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , explainRejectedCandidates
  , packageHashesEmpty
  , solverResultBlockedReasons
  , solverResultExplain
  , solverResultLockfile
  , solverResultStatus
  )
import Panino.Net.Http (makeHttpManager)
import System.Directory
  ( getTemporaryDirectory
  )
import System.Environment
  ( setEnv
  , unsetEnv
  )
import TestFixtures
  ( testLockfilePackage
  , testLockfileSolveRequest
  , testPackageConstraint
  )
import TestSupport (assertEqual)

assertModrinthDependencyResolver :: IO ()
assertModrinthDependencyResolver = do
  manager <- makeHttpManager
  tempDir <- getTemporaryDirectory
  testWithApplication
    ( pure $ \request respond -> do
        let requestBase =
              "http://"
                <> BS8.unpack
                  ( case requestHeaderHost request of
                      Just host -> host
                      Nothing -> "127.0.0.1"
                  )
        respond $
          case BS8.unpack (rawPathInfo request) of
            "/mc/game/version_manifest_v2.json" ->
              responseLBS status200 [(hContentType, "application/json")] (minecraftManifestFixture requestBase)
            "/versions/26.1.2.json" ->
              responseLBS status200 [(hContentType, "application/json")] (minecraftVersionFixture requestBase)
            "/v2/project/iris" ->
              responseLBS status200 [(hContentType, "application/json")] (modrinthProjectMetadataFixture "iris" "Iris")
            "/v2/project/iris/version" ->
              responseLBS status200 [(hContentType, "application/json")] modrinthIrisVersionsJson
            "/v2/project/fabric-api" ->
              responseLBS status200 [(hContentType, "application/json")] (modrinthProjectMetadataFixture "fabric-api" "Fabric API")
            "/v2/project/fabric-api/version" ->
              responseLBS status200 [(hContentType, "application/json")] modrinthDependencyVersionsJson
            "/v1/mods/123" ->
              responseLBS status200 [(hContentType, "application/json")] (curseForgeProjectFixture 123 "Curse Root")
            "/v1/mods/123/files" ->
              responseLBS status200 [(hContentType, "application/json")] (curseForgeFilesFixture 1001 "curse-root.jar" "3333333333333333333333333333333333333333" [456])
            "/v1/mods/456" ->
              responseLBS status200 [(hContentType, "application/json")] (curseForgeProjectFixture 456 "Curse Dependency")
            "/v1/mods/456/files" ->
              responseLBS status200 [(hContentType, "application/json")] (curseForgeFilesFixture 2002 "curse-dependency.jar" "4444444444444444444444444444444444444444" [])
            _ ->
              responseLBS status200 [(hContentType, "application/json")] modrinthDependencyVersionsJson
    )
    $ \port ->
      ( do
          setEnv "PANINO_MODRINTH_API_BASE" ("http://127.0.0.1:" <> show port)
          setEnv "PANINO_CURSEFORGE_API_BASE" ("http://127.0.0.1:" <> show port)
          setEnv "PANINO_MOJANG_META_BASE" ("http://127.0.0.1:" <> show port)
          setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
          releases <- modrinthRequiredDependencyReleases manager dependencyQuery [fabricApiDependency]
          assertEqual "modrinth dependency resolver release" ["fabric-api-version"] (map onlineReleaseIdText releases)
          assertEqual "modrinth dependency resolver file" ["fabric-api-1.0.0.jar"] (concatMap (map fileName . releaseFiles) releases)
          let irisRoot =
                (testLockfilePackage "iris" "Iris" "iris-version" "iris.jar" "mods/iris.jar" "2222222222222222222222222222222222222222" [testPackageConstraint "iris" "fabric-api" "requires" True])
                  { resolvedPackageGameVersions = ["26.1.2"]
                  }
              solverRequest =
                (testLockfileSolveRequest "/tmp/panino-lockfile-modrinth-deps" [irisRoot] Nothing)
                  { solveRequestMinecraftVersion = Just "26.1.2"
                  , solveRequestLoader = Nothing
                  , solveRequestShaderLoader = Nothing
                  }
          solverResult <- solveLockfileWithServices manager solverRequest
          assertEqual "lockfile solver reuses Modrinth dependency resolver" "ready" (solverResultStatus solverResult)
          assertEqual
            "lockfile solver includes resolved Modrinth dependency"
            True
            ( maybe
                False
                (("fabric-api" `elem`) . map resolvedPackageId . lockfilePackages)
                (solverResultLockfile solverResult)
            )
          assertEqual
            "lockfile solver records Java runtime requirement"
            True
            ( maybe
                False
                (("java:21" `elem`) . map resolvedPackageId . lockfilePackages)
                (solverResultLockfile solverResult)
            )
          let modrinthRoot =
                (testLockfilePackage "iris" "Iris" "placeholder" "iris.jar" "mods/iris.jar" "2222222222222222222222222222222222222222" [])
                  { resolvedPackageCoordinate =
                      PackageCoordinate
                        { coordinateSource = "modrinth"
                        , coordinateProjectId = Just "iris"
                        , coordinateVersionId = Nothing
                        , coordinateFileId = Nothing
                        , coordinateSlug = Just "iris"
                        , coordinateName = Just "Iris"
                        , coordinateKind = "mod"
                        }
                  , resolvedPackageVersionName = Nothing
                  , resolvedPackageFileName = Nothing
                  , resolvedPackageTargetPath = Nothing
                  , resolvedPackageHashes = packageHashesEmpty
                  , resolvedPackageDownloadUrls = []
                  , resolvedPackageGameVersions = []
                  , resolvedPackageLoaders = []
                  }
              modrinthRootRequest =
                (testLockfileSolveRequest "/tmp/panino-lockfile-modrinth-root" [modrinthRoot] Nothing)
                  { solveRequestMinecraftVersion = Just "26.1.2"
                  , solveRequestLoader = Nothing
                  , solveRequestShaderLoader = Nothing
                  }
          modrinthRootResult <- solveLockfileWithServices manager modrinthRootRequest
          assertEqual ("lockfile solver resolves Modrinth project root: " <> show (solverResultBlockedReasons modrinthRootResult)) "ready" (solverResultStatus modrinthRootResult)
          assertEqual
            "lockfile solver resolves Modrinth root dependency"
            ["fabric-api", "iris", "java:21"]
            (maybe [] (map resolvedPackageId . lockfilePackages) (solverResultLockfile modrinthRootResult))
          let curseRoot =
                modrinthRoot
                  { resolvedPackageId = "123"
                  , resolvedPackageDisplayName = "Curse Root"
                  , resolvedPackageCoordinate =
                      PackageCoordinate
                        { coordinateSource = "curseforge"
                        , coordinateProjectId = Just "123"
                        , coordinateVersionId = Nothing
                        , coordinateFileId = Nothing
                        , coordinateSlug = Just "curse-root"
                        , coordinateName = Just "Curse Root"
                        , coordinateKind = "mod"
                        }
                  }
              curseRootRequest =
                (testLockfileSolveRequest "/tmp/panino-lockfile-curse-root" [curseRoot] Nothing)
                  { solveRequestMinecraftVersion = Just "26.1.2"
                  , solveRequestLoader = Nothing
                  , solveRequestShaderLoader = Nothing
                  , solveRequestCurseForgeApiKey = Just "test-key"
                  }
          curseRootResult <- solveLockfileWithServices manager curseRootRequest
          assertEqual ("lockfile solver resolves CurseForge project root: " <> show (solverResultBlockedReasons curseRootResult)) "ready" (solverResultStatus curseRootResult)
          assertEqual
            "lockfile solver resolves CurseForge required dependency"
            ["123", "456", "java:21"]
            (maybe [] (map resolvedPackageId . lockfilePackages) (solverResultLockfile curseRootResult))
          performancePackResult <-
            solveLockfileWithServices
              manager
              ( (testLockfileSolveRequest "/tmp/panino-lockfile-performance-pack" [] Nothing)
                  { solveRequestMinecraftVersion = Nothing
                  , solveRequestLoader = Just "fabric"
                  , solveRequestShaderLoader = Nothing
                  , solveRequestIncludePerformancePack = True
                  }
              )
          assertEqual "lockfile solver records performance pack root request" "ready" (solverResultStatus performancePackResult)
          assertEqual
            "lockfile performance pack is a root package"
            True
            ( maybe
                False
                (("performance-pack:fabric" `elem`) . map resolvedPackageId . lockfilePackages)
                (solverResultLockfile performancePackResult)
            )
          assertEqual "lockfile performance pack keeps recommended mods optional" True (not (null (explainRejectedCandidates (solverResultExplain performancePackResult))))
          assertLockfileJavaPolicySolves (solveLockfileWithServices manager) tempDir
      )
        `finally` do
          unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
          unsetEnv "PANINO_MOJANG_META_BASE"
          unsetEnv "PANINO_MODRINTH_API_BASE"
          unsetEnv "PANINO_CURSEFORGE_API_BASE"
  where
    dependencyQuery =
      ContentSearchRequest
        { contentSearchSource = "modrinth"
        , contentSearchText = ""
        , contentSearchProjectTypes = ["mod"]
        , contentSearchCategories = []
        , contentSearchGameVersion = Just "26.1.2"
        , contentSearchLoaders = ["fabric"]
        , contentSearchSort = "downloads"
        , contentSearchOffset = 0
        , contentSearchLimit = 20
        , contentSearchCurseForgeApiKey = Nothing
        , contentSearchPrefetch = False
        }
    fabricApiDependency =
      OnlineDependency
        { dependencyId = "fabric-api:required"
        , dependencyProjectId = Just "fabric-api"
        , dependencyVersionId = Nothing
        , dependencySource = "modrinth"
        , dependencyRelation = "required"
        }
