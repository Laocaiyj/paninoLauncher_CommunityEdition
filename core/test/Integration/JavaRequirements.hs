{-# LANGUAGE OverloadedStrings #-}

module Integration.JavaRequirements
  ( assertJavaRequirements
  ) where

import Panino.Minecraft.Types
  ( JavaVersion(..)
  , VersionJson(..)
  )
import Panino.Core.Types (urlText)
import Panino.Runtime.Java.Catalog (runtimeDownloadSpec)
import Panino.Runtime.Java.Requirements
  ( fallbackJavaMajorVersion
  , javaRequirementForVersionJson
  )
import Panino.Runtime.Java.Types
  ( JavaRuntimeDownloadSpec(..)
  , JavaRuntimeRequirement(..)
  )
import TestFixtures (testVersionJson)
import TestSupport (assertEqual)

assertJavaRequirements :: IO ()
assertJavaRequirements = do
  assertEqual
    "java manifest major version wins"
    (21, "manifest", Just "java-runtime-delta")
    ( let requirement =
            javaRequirementForVersionJson
              "1.21.5"
              testVersionJson
                { versionId = "1.21.5"
                , versionJavaVersion = Just (JavaVersion (Just "java-runtime-delta") (Just 21))
                }
       in ( javaRequirementMajorVersion requirement
          , javaRequirementSource requirement
          , javaRequirementComponent requirement
          )
    )
  assertEqual
    "java fallback rules"
    [21, 21, 17, 16, 8, 21]
    (map fallbackJavaMajorVersion ["1.20.5", "1.21.1", "1.20.4", "1.17.1", "1.16.5", "26.2-pre-2"])
  assertEqual
    "adoptium arm64 jre catalog url"
    "https://api.adoptium.net/v3/binary/latest/21/ga/mac/aarch64/jre/hotspot/normal/eclipse"
    (urlText (runtimeDownloadUrl (runtimeDownloadSpec 21 "mac" "aarch64" "jre")))
