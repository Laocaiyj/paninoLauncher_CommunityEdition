{-# LANGUAGE OverloadedStrings #-}

module Integration.MinecraftPlan
  ( assertMinecraftInstallPlanGraph
  ) where

import Data.Aeson
  ( eitherDecode
  , encode
  )
import qualified Data.Text as Text
import Panino.Download.Manager (DownloadJob(..))
import Panino.Install.Plan.Types
  ( InstallPlanNode(..)
  , InstallPlanRollbackAction(..)
  , InstallPlanSummary(..)
  , TypedInstallPlan(..)
  )
import Panino.Minecraft.Install
  ( classpathJars
  , mavenArtifactPath
  )
import Panino.Minecraft.InstallPlanGraph
  ( addInstanceMetadataTypedPlan
  , addLoaderProfileTypedPlan
  , combineInstallPlanGraphs
  , downloadJobsInstallPlanGraph
  , installPlanGraphNodes
  , installPlanGraphTypedPlan
  )
import TestFixtures
  ( testLayout
  , testVersionJson
  )
import TestSupport (assertEqual)

assertMinecraftInstallPlanGraph :: IO ()
assertMinecraftInstallPlanGraph = do
  assertEqual
    "maven artifact path"
    "org/lwjgl/lwjgl/3.3.1/lwjgl-3.3.1.jar"
    (mavenArtifactPath "org.lwjgl:lwjgl:3.3.1" Nothing)
  assertEqual
    "classpath includes loader maven libraries"
    [ "/tmp/mc/libraries/net/fabricmc/fabric-loader/0.19.2/fabric-loader-0.19.2.jar"
    , "/tmp/mc/libraries/org/ow2/asm/asm/9.9/asm-9.9.jar"
    , "/tmp/mc/versions/fabric-loader-0.19.2-1.20.1/fabric-loader-0.19.2-1.20.1.jar"
    ]
    (classpathJars testLayout testVersionJson)
  let planGraph =
        downloadJobsInstallPlanGraph
          "test"
          "dedupe"
          [ DownloadJob "duplicate-a" "https://example.com/a.jar" "/tmp/a.jar" (Just "abc") (Just 10)
          , DownloadJob "duplicate-b" "https://example.com/b.jar" "/tmp/b.jar" (Just "abc") (Just 10)
          ]
  assertEqual "install plan graph dedupes sha1" 1 (length (installPlanGraphNodes planGraph))
  assertEqual "install plan graph exposes typed plan" "test" (typedPlanKind (installPlanGraphTypedPlan planGraph))
  assertEqual "install plan graph json is typed plan" (Right (installPlanGraphTypedPlan planGraph)) (eitherDecode (encode planGraph))
  assertEqual "install plan graph typed summary" 1 (installSummaryDownloadNodes (typedPlanSummary (installPlanGraphTypedPlan planGraph)))

  let assetGraph =
        downloadJobsInstallPlanGraph
          "minecraft"
          "assets"
          [ DownloadJob "asset index 26" "https://example.com/index.json" "/tmp/mc/assets/indexes/26.json" (Just "indexhash") (Just 20)
          , DownloadJob "asset minecraft/sounds/test.ogg" "https://example.com/object" "/tmp/mc/assets/objects/ab/object" (Just "objecthash") (Just 40)
          ]
      assetGraphShuffled =
        downloadJobsInstallPlanGraph
          "minecraft"
          "assets"
          [ DownloadJob "asset minecraft/sounds/test.ogg" "https://example.com/object" "/tmp/mc/assets/objects/ab/object" (Just "objecthash") (Just 40)
          , DownloadJob "asset index 26" "https://example.com/index.json" "/tmp/mc/assets/indexes/26.json" (Just "indexhash") (Just 20)
          ]
      assetPlan = installPlanGraphTypedPlan assetGraph
      assetPlanShuffled = installPlanGraphTypedPlan assetGraphShuffled
      assetIndexIds =
        [ installNodeId node
        | node <- typedPlanNodes assetPlan
        , installNodeKind node == "assetIndex"
        ]
      assetObjectDependsOn =
        concat
          [ installNodeDependsOn node
          | node <- typedPlanNodes assetPlan
          , installNodeKind node == "assetObject"
          ]
  assertEqual "asset objects depend on asset index" True (not (null assetIndexIds) && all (`elem` assetObjectDependsOn) assetIndexIds)
  assertEqual "download job order does not change graph plan id" (typedPlanId assetPlan) (typedPlanId assetPlanShuffled)
  assertEqual "download job order does not change graph node ids" (map installNodeId (typedPlanNodes assetPlan)) (map installNodeId (typedPlanNodes assetPlanShuffled))

  let largeJobs =
        [ DownloadJob
            ("asset minecraft/large/" <> show index <> ".ogg")
            ("https://example.com/assets/" <> show index)
            ("/tmp/mc/assets/objects/large/" <> show index)
            (Just (Text.pack ("sha" <> show index)))
            (Just (fromIntegral index))
        | index <- [1 :: Int .. 600]
        ]
      largeGraph = downloadJobsInstallPlanGraph "minecraft" "large-assets" largeJobs
      largeGraphShuffled = downloadJobsInstallPlanGraph "minecraft" "large-assets" (reverse largeJobs)
      largePlan = installPlanGraphTypedPlan largeGraph
      largePlanShuffled = installPlanGraphTypedPlan largeGraphShuffled
  assertEqual "large install graph keeps legacy node count" 600 (length (installPlanGraphNodes largeGraph))
  assertEqual "large install graph compacts typed nodes" 1 (length (typedPlanNodes largePlan))
  assertEqual "large install graph preserves summary count" 600 (installSummaryTotalNodes (typedPlanSummary largePlan))
  assertEqual "large install graph compact fingerprint is stable" (typedPlanFingerprint largePlan) (typedPlanFingerprint largePlanShuffled)

  let missingHashGraph =
        downloadJobsInstallPlanGraph
          "minecraft"
          "missing-hash"
          [DownloadJob "client jar missing hash" "https://example.com/client.jar" "/tmp/mc/versions/26/client.jar" Nothing (Just 40)]
  assertEqual "required node without sha1 blocks typed plan" ["missing_sha1"] (typedPlanBlockedReasons (installPlanGraphTypedPlan missingHashGraph))

  let loaderGraph = addLoaderProfileTypedPlan testLayout "fabric-loader-0.19.2-26.1.2" (Just "0.19.2") assetGraph
      loaderPlan = installPlanGraphTypedPlan loaderGraph
      loaderProfileIds =
        [ installNodeId node
        | node <- typedPlanNodes loaderPlan
        , installNodeKind node == "loaderProfile"
        ]
      loaderProfileRollbacks =
        [ installRollbackAction (installNodeRollback node)
        | node <- typedPlanNodes loaderPlan
        , installNodeKind node == "loaderProfile"
        ]
      metadataPlan = installPlanGraphTypedPlan (addInstanceMetadataTypedPlan testLayout loaderGraph)
      metadataRollbacks =
        [ installRollbackAction (installNodeRollback node)
        | node <- typedPlanNodes metadataPlan
        , installNodeKind node == "instanceMetadata"
        ]
      shaderGraph =
        downloadJobsInstallPlanGraph
          "minecraft-companion"
          "iris"
          [DownloadJob "modrinth mod iris" "https://example.com/iris.jar" "/tmp/mc/mods/iris.jar" (Just "irishash") (Just 64)]
      combinedProfilePlan =
        installPlanGraphTypedPlan (combineInstallPlanGraphs "minecraft-profile" "fabric-loader-0.19.2-26.1.2" [loaderGraph, shaderGraph])
      combinedStablePlan =
        installPlanGraphTypedPlan (combineInstallPlanGraphs "determinism-test" "stable" [assetGraph, shaderGraph])
      combinedStablePlanShuffled =
        installPlanGraphTypedPlan (combineInstallPlanGraphs "determinism-test" "stable" [shaderGraph, assetGraph])
      shaderDependsOn =
        concat
          [ installNodeDependsOn node
          | node <- typedPlanNodes combinedProfilePlan
          , installNodeKind node == "mod"
          ]
  assertEqual "loader profile typed node is added" True (not (null loaderProfileIds))
  assertEqual "loader profile rollback removes created profile" ["removeCreatedFile"] loaderProfileRollbacks
  assertEqual "metadata rollback removes final commit marker" ["removeCreatedFile"] metadataRollbacks
  assertEqual "shader companion depends on loader profile" True (not (null loaderProfileIds) && all (`elem` shaderDependsOn) loaderProfileIds)
  assertEqual "combined graph order is stable for unordered combines" (typedPlanFingerprint combinedStablePlan) (typedPlanFingerprint combinedStablePlanShuffled)
