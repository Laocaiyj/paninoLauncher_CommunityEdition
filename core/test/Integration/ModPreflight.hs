{-# LANGUAGE OverloadedStrings #-}

module Integration.ModPreflight
  ( assertModPreflight
  ) where

import qualified Data.ByteString.Lazy.Char8 as BL8
import Panino.Minecraft.ModPreflight
  ( MissingModDependency(..)
  , missingFabricDependenciesFromManifests
  , preflightModDependencies
  )
import System.Directory
  ( createDirectoryIfMissing
  , getTemporaryDirectory
  , removeDirectoryRecursive
  )
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
import System.Process
  ( CreateProcess(..)
  , createProcess
  , proc
  , waitForProcess
  )
import TestSupport
  ( assertEqual
  , catchAny
  , removeIfExists
  )

assertModPreflight :: IO ()
assertModPreflight = do
  assertEqual
    "fabric dependency preflight catches missing required mod"
    ( Right
        [ MissingModDependency
            { missingModFile = "iris.jar"
            , missingModId = "iris"
            , missingDependencyId = "sodium"
            }
        ]
    )
    ( missingFabricDependenciesFromManifests
        [ ( "iris.jar"
          , "{\"id\":\"iris\",\"depends\":{\"minecraft\":\">=1.20\",\"fabricloader\":\">=0.14\",\"sodium\":\"*\"}}"
          )
        ]
    )
  assertEqual
    "fabric dependency preflight accepts installed dependency"
    (Right [])
    ( missingFabricDependenciesFromManifests
        [ ( "iris.jar"
          , "{\"id\":\"iris\",\"depends\":{\"sodium\":\"*\"}}"
          )
        , ( "sodium.jar"
          , "{\"id\":\"sodium\"}"
          )
        ]
    )
  assertFabricApiNestedJarPreflight

assertFabricApiNestedJarPreflight :: IO ()
assertFabricApiNestedJarPreflight = do
  tempDir <- getTemporaryDirectory
  let root = tempDir </> "panino-core-nested-preflight-test"
      gameDir = root </> "game"
      modsDir = gameDir </> "mods"
      sodiumDir = root </> "sodium"
      fabricOuterDir = root </> "fabric-api"
      fabricNestedDir = root </> "fabric-block-view-api-v2"
      sodiumJar = modsDir </> "sodium.jar"
      fabricApiJar = modsDir </> "fabric-api.jar"
      nestedJar = fabricOuterDir </> "jars" </> "fabric-block-view-api-v2.jar"
  removeDirectoryRecursive root `catchAny` \_ -> pure ()
  createDirectoryIfMissing True modsDir
  createDirectoryIfMissing True sodiumDir
  createDirectoryIfMissing True (fabricOuterDir </> "jars")
  createDirectoryIfMissing True fabricNestedDir
  BL8.writeFile (sodiumDir </> "fabric.mod.json") "{\"id\":\"sodium\",\"depends\":{\"fabric-block-view-api-v2\":\"*\"}}"
  BL8.writeFile (fabricOuterDir </> "fabric.mod.json") "{\"id\":\"fabric-api\",\"jars\":[{\"file\":\"jars/fabric-block-view-api-v2.jar\"}]}"
  BL8.writeFile (fabricNestedDir </> "fabric.mod.json") "{\"id\":\"fabric-block-view-api-v2\"}"
  zipDirectory fabricNestedDir nestedJar
  zipDirectory sodiumDir sodiumJar
  zipDirectory fabricOuterDir fabricApiJar
  preflightModDependencies gameDir
  removeDirectoryRecursive root `catchAny` \_ -> pure ()

zipDirectory :: FilePath -> FilePath -> IO ()
zipDirectory sourceDir targetJar = do
  removeIfExists targetJar
  (_, _, _, processHandle) <-
    createProcess
      (proc "/usr/bin/zip" ["-q", "-r", targetJar, "."])
        { cwd = Just sourceDir
        }
  exitCode <- waitForProcess processHandle
  assertEqual ("zip " <> targetJar) ExitSuccess exitCode
