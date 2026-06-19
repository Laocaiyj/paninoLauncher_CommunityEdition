{-# LANGUAGE OverloadedStrings #-}

module Integration.ContentPlan.TypedInstall
  ( assertContentTypedInstallPlan
  ) where

import qualified Panino.Api.Routes.Content as ContentRoutes
import Panino.Api.Types
  ( ContentInstallDependency(..)
  , ContentInstallFile(..)
  , ContentInstallPlanFile(..)
  , ContentInstallPlanResponse(..)
  , ContentInstallRequest(..)
  , DownloadRuntimeOptions(..)
  )
import Panino.Download.Manager (DownloadJob(..))
import Panino.Install.Plan.Types
  ( InstallPlanNode(..)
  , InstallPlanRollbackAction(..)
  , TypedInstallPlan(..)
  )
import TestSupport (assertEqual)

assertContentTypedInstallPlan :: IO ()
assertContentTypedInstallPlan = do
  let mainFile =
        ContentInstallFile
          { contentFileName = "sodium.jar"
          , contentFileUrl = "https://cdn.modrinth.com/sodium.jar"
          , contentFileSha1 = Just "mainsha"
          , contentFileSize = Just 10
          , contentFilePrimary = Just True
          }
      dependencyFile =
        ContentInstallFile
          { contentFileName = "fabric-api.jar"
          , contentFileUrl = "https://cdn.modrinth.com/fabric-api.jar"
          , contentFileSha1 = Just "depsha"
          , contentFileSize = Just 20
          , contentFilePrimary = Just True
          }
      mainPlanFile =
        ContentInstallPlanFile
          { contentPlanFileName = "sodium.jar"
          , contentPlanTargetPath = "/tmp/mc/mods/sodium.jar"
          , contentPlanFileSize = Just 10
          , contentPlanFileSha1 = Just "mainsha"
          , contentPlanFileAction = "replace"
          , contentPlanFilePrimary = True
          }
      dependencyPlanFile =
        ContentInstallPlanFile
          { contentPlanFileName = "fabric-api.jar"
          , contentPlanTargetPath = "/tmp/mc/mods/fabric-api.jar"
          , contentPlanFileSize = Just 20
          , contentPlanFileSha1 = Just "depsha"
          , contentPlanFileAction = "download"
          , contentPlanFilePrimary = True
          }
      requiredDependency =
        ContentInstallDependency
          { contentDependencyProjectId = Just "fabric-api"
          , contentDependencyVersionId = Just "dep-version"
          , contentDependencySource = Just "modrinth"
          , contentDependencyName = "Fabric API"
          , contentDependencyRequired = True
          , contentDependencyInstalled = Just True
          , contentDependencySha1 = Just "depsha"
          }
      optionalDependency =
        ContentInstallDependency
          { contentDependencyProjectId = Just "lambdynamiclights"
          , contentDependencyVersionId = Nothing
          , contentDependencySource = Just "modrinth"
          , contentDependencyName = "LambDynamicLights"
          , contentDependencyRequired = False
          , contentDependencyInstalled = Nothing
          , contentDependencySha1 = Nothing
          }
      request =
        ContentInstallRequest
          { contentInstallSource = "modrinth"
          , contentInstallProjectId = Just "sodium"
          , contentInstallProjectTitle = "Sodium"
          , contentInstallProjectType = Just "mod"
          , contentInstallReleaseId = "main-version"
          , contentInstallGameDir = Just "/tmp/mc"
          , contentInstallTargetSubdir = "mods"
          , contentInstallFiles = [mainFile]
          , contentInstallDependencies = [requiredDependency, optionalDependency]
          , contentInstallGameVersions = ["26.1.2"]
          , contentInstallLoaders = ["fabric"]
          , contentInstallInstances = []
          , contentInstallDownload = DownloadRuntimeOptions Nothing Nothing Nothing
          }
      typedPlan =
        ContentRoutes.contentTypedInstallPlan
          request
          "/tmp/mc/mods"
          [mainFile, dependencyFile]
          [mainPlanFile, dependencyPlanFile]
          [requiredDependency, optionalDependency]
          ["optional_dependencies_not_found"]
          []
      typedPlanShuffled =
        ContentRoutes.contentTypedInstallPlan
          request
          "/tmp/mc/mods"
          [dependencyFile, mainFile]
          [dependencyPlanFile, mainPlanFile]
          [optionalDependency, requiredDependency]
          ["optional_dependencies_not_found"]
          []
      response =
        ContentInstallPlanResponse
          { contentPlanAction = "install"
          , contentPlanSource = "modrinth"
          , contentPlanProjectId = Just "sodium"
          , contentPlanProjectTitle = "Sodium"
          , contentPlanReleaseId = "main-version"
          , contentPlanTargetDir = "/tmp/mc/mods"
          , contentPlanFiles = [mainPlanFile, dependencyPlanFile]
          , contentPlanDependencies = [requiredDependency, optionalDependency]
          , contentPlanWarnings = ["optional_dependencies_not_found"]
          , contentPlanBlockedReasons = typedPlanBlockedReasons typedPlan
          , contentPlanTotalSize = Just 30
          , contentPlanTypedPlan = typedPlan
          }
      dependencyNodeIds =
        [ installNodeId node
        | node <- typedPlanNodes typedPlan
        , installNodeLabel node == "Fabric API"
        ]
      mainNodes =
        [ node
        | node <- typedPlanNodes typedPlan
        , installNodeLabel node == "sodium.jar"
        ]
      replaceRollbacks =
        [ installRollbackAction (installNodeRollback node)
        | node <- mainNodes
        ]
      downloadJobs = ContentRoutes.contentDownloadJobsFromTypedPlan response

  assertEqual "content typed plan is ready with optional dependency warning" "ready" (typedPlanStatus typedPlan)
  assertEqual "content typed plan keeps optional warning" ["optional_dependencies_not_found"] (typedPlanWarnings typedPlan)
  assertEqual "content required dependency becomes node" True (not (null dependencyNodeIds))
  assertEqual "content primary file depends on required dependency" True (not (null dependencyNodeIds) && all (`elem` concatMap installNodeDependsOn mainNodes) dependencyNodeIds)
  assertEqual "content dependency edge is present" True (not (null (typedPlanEdges typedPlan)))
  assertEqual "content replace declares restore backup rollback" ["restoreBackup"] replaceRollbacks
  assertEqual "content typed executor downloads dependency before replace file" ["/tmp/mc/mods/fabric-api.jar", "/tmp/mc/mods/sodium.jar"] (map jobTargetPath downloadJobs)
  assertEqual "content typed plan ignores file and dependency input order" (typedPlanFingerprint typedPlan) (typedPlanFingerprint typedPlanShuffled)

  let curseForgeDependency =
        requiredDependency
          { contentDependencySource = Just "curseforge"
          , contentDependencyInstalled = Nothing
          }
      curseForgePlan =
        ContentRoutes.contentTypedInstallPlan
          request { contentInstallSource = "curseforge", contentInstallDependencies = [curseForgeDependency] }
          "/tmp/mc/mods"
          [mainFile]
          [mainPlanFile]
          [curseForgeDependency]
          []
          []
  assertEqual "content CurseForge unresolved required dependency blocks plan" "blocked" (typedPlanStatus curseForgePlan)
  assertEqual "content CurseForge unresolved reason" True ("curseforge_required_dependency_unresolved" `elem` typedPlanBlockedReasons curseForgePlan)
