{-# LANGUAGE OverloadedStrings #-}

module Integration.LaunchArguments
  ( assertLaunchArgumentRules
  ) where

import Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import Panino.Launch.Arguments
  ( LaunchProfile(..)
  , buildJavaArguments
  , substituteVariables
  )
import Panino.Minecraft.Install (classpathJars)
import Panino.Minecraft.Types
  ( ArgPiece(..)
  , Rule(..)
  , RuleAction(..)
  , VersionArguments(..)
  , VersionJson(..)
  , isAllowedByRules
  )
import TestFixtures
  ( testLayout
  , testVersionJson
  )
import TestSupport (assertEqual)

assertLaunchArgumentRules :: IO ()
assertLaunchArgumentRules = do
  assertEqual
    "variable substitution"
    "hello Steve"
    (substituteVariables (Map.fromList [("name", "Steve")]) "hello ${name}")
  let neoforgeLaunchArgs =
        buildJavaArguments
          testLayout
          testVersionJson
            { versionId = "neoforge-26.1.1.15-beta"
            , versionArguments =
                Just
                  VersionArguments
                    { versionGameArguments = []
                    , versionJvmArguments = [ArgLiteral ["-DlibraryDirectory=${library_directory}"]]
                    }
            }
          (classpathJars testLayout testVersionJson)
          LaunchProfile
            { profileVersion = "neoforge-26.1.1.15-beta"
            , profileMemoryMb = 4096
            , profileJavaPath = "java"
            , profileUsername = "Steve"
            , profileUuid = "00000000-0000-0000-0000-000000000000"
            , profileAccessToken = "0"
            , profileJvmArgs = []
            , profileJvmTuning = Nothing
            , profileWindowWidth = Nothing
            , profileWindowHeight = Nothing
            }
  assertEqual "NeoForge library_directory is substituted" True ("-DlibraryDirectory=/tmp/mc/libraries" `elem` neoforgeLaunchArgs)
  assertEqual "NeoForge library_directory literal is not leaked" False (any ("${library_directory}" `isInfixOf`) neoforgeLaunchArgs)
  assertEqual
    "empty rules allow"
    True
    (isAllowedByRules [])
  assertEqual
    "feature rule false by default"
    False
    (isAllowedByRules [Rule Allow Nothing (Map.fromList [("has_custom_resolution", True)])])
