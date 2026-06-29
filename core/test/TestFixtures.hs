{-# LANGUAGE OverloadedStrings #-}

module TestFixtures
  ( fakeJavaScript
  , fakeJavaSettingsScript
  , testLockfilePackage
  , testLockfileSolveRequest
  , testPackageConstraint
  , testPaninoLockfile
  , testLayout
  , testVersionJson
  , withPackageSlug
  ) where

import qualified Data.Map.Strict as Map
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import Panino.Core.Types
  ( gameDirFromPath
  , projectIdFromText
  , relativePathFromFilePath
  , urlFromText
  , versionIdFromText
  )
import Panino.Lockfile.Types
  ( LockfileFile(..)
  , LockfileSolveRequest(..)
  , PackageConstraint(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , packageHashesFromSha1Text
  )
import Panino.Minecraft.Layout (MinecraftLayout(..))
import Panino.Minecraft.Types
  ( DownloadInfo(..)
  , Library(..)
  , VersionJson(..)
  )

testLayout :: MinecraftLayout
testLayout =
  MinecraftLayout
    { minecraftRoot = "/tmp/mc"
    , versionsDir = "/tmp/mc/versions"
    , librariesDir = "/tmp/mc/libraries"
    , assetsDir = "/tmp/mc/assets"
    , assetIndexesDir = "/tmp/mc/assets/indexes"
    , assetObjectsDir = "/tmp/mc/assets/objects"
    , allNativesDir = "/tmp/mc/natives"
    }

testVersionJson :: VersionJson
testVersionJson =
  VersionJson
    { versionId = "fabric-loader-0.19.2-1.20.1"
    , versionType = Just "release"
    , versionJavaVersion = Nothing
    , versionDownloads = Map.empty
    , versionAssetIndex = emptyDownloadInfo
    , versionLibraries =
        [ Library
            { libraryName = "org.ow2.asm:asm:9.6"
            , libraryDownloads = Nothing
            , libraryUrl = Just "https://libraries.minecraft.net/"
            , libraryRules = []
            , libraryNatives = Map.empty
            }
        , Library
            { libraryName = "net.fabricmc:fabric-loader:0.19.2"
            , libraryDownloads = Nothing
            , libraryUrl = Just "https://maven.fabricmc.net/"
            , libraryRules = []
            , libraryNatives = Map.empty
            }
        , Library
            { libraryName = "org.ow2.asm:asm:9.9"
            , libraryDownloads = Nothing
            , libraryUrl = Just "https://maven.fabricmc.net/"
            , libraryRules = []
            , libraryNatives = Map.empty
            }
        ]
    , versionMainClass = "net.fabricmc.loader.impl.launch.knot.KnotClient"
    , versionArguments = Nothing
    , versionMinecraftArguments = Nothing
    }

emptyDownloadInfo :: DownloadInfo
emptyDownloadInfo =
  DownloadInfo
    { downloadId = Nothing
    , downloadSha1 = Nothing
    , downloadSize = Nothing
    , downloadUrl = Nothing
    , downloadPath = Nothing
    }

fakeJavaScript :: String
fakeJavaScript =
  unlines
    [ "#!/bin/sh"
    , "echo 'java.version = 21.0.0' >&2"
    , "echo 'java.vendor = Panino Test' >&2"
    , "echo 'os.arch = aarch64' >&2"
    , "echo 'openjdk version \"21.0.0\"' >&2"
    , "exit 0"
    ]

fakeJavaSettingsScript :: String
fakeJavaSettingsScript =
  unlines
    [ "#!/bin/sh"
    , "echo 'Property settings:' >&2"
    , "echo '    java.version = 21.0.0' >&2"
    , "echo '    java.vendor = Panino Test' >&2"
    , "echo '    os.arch = aarch64' >&2"
    , "echo 'openjdk version \"21.0.0\"' >&2"
    , "exit 0"
    ]

testLockfileSolveRequest :: FilePath -> [ResolvedPackage] -> Maybe PaninoLockfile -> LockfileSolveRequest
testLockfileSolveRequest gameDir roots existingLockfile =
  LockfileSolveRequest
    { solveRequestMode = "install"
    , solveRequestTargetGameDir = fromMaybe "/tmp/panino-test" (gameDirFromPath gameDir)
    , solveRequestMinecraftVersion = Just "1.21.5"
    , solveRequestLoader = Just "fabric"
    , solveRequestLoaderVersion = Just "0.16.10"
    , solveRequestJavaPolicy = Nothing
    , solveRequestShaderLoader = Just "iris"
    , solveRequestSourceType = Nothing
    , solveRequestSourcePath = Nothing
    , solveRequestIncludePerformancePack = False
    , solveRequestRoots = roots
    , solveRequestExistingLockfile = existingLockfile
    , solveRequestUpdatePolicy = "relock"
    , solveRequestSourcePolicy = Just "modrinth"
    , solveRequestCurseForgeApiKey = Nothing
    , solveRequestIncludeOptionalDependencies = False
    , solveRequestSelectedOptionalDependencies = []
    , solveRequestIgnoredDependencies = []
    , solveRequestPinnedPackages = []
    , solveRequestManualPackages = []
    }

testLockfilePackage :: Text -> Text -> Text -> Text -> FilePath -> Text -> [PackageConstraint] -> ResolvedPackage
testLockfilePackage packageId name releaseIdText fileNameText targetPath sha1 dependencies =
  ResolvedPackage
    { resolvedPackageId = packageId
    , resolvedPackageCoordinate =
        PackageCoordinate
          { coordinateSource = "modrinth"
          , coordinateProjectId = projectIdFromText packageId
          , coordinateVersionId = versionIdFromText releaseIdText
          , coordinateFileId = Just fileNameText
          , coordinateSlug = Just packageId
          , coordinateName = Just name
          , coordinateKind = "mod"
          }
    , resolvedPackageDisplayName = name
    , resolvedPackageVersionName = Just releaseIdText
    , resolvedPackageFileName = Just fileNameText
    , resolvedPackageTargetPath = relativePathFromFilePath targetPath
    , resolvedPackageHashes = packageHashesFromSha1Text sha1
    , resolvedPackageSize = Just 123
    , resolvedPackageDownloadUrls = [urlFromText ("https://cdn.modrinth.example/" <> fileNameText)]
    , resolvedPackageGameVersions = ["1.21.5"]
    , resolvedPackageLoaders = ["fabric"]
    , resolvedPackageJavaMajor = Nothing
    , resolvedPackageSide = Just "client"
    , resolvedPackageSelectedBecause = []
    , resolvedPackageLocked = False
    , resolvedPackagePinReason = Nothing
    , resolvedPackageDependencies = dependencies
    , resolvedPackageConflicts = []
    , resolvedPackageSourceSnapshot = Just "test"
    }

withPackageSlug :: Text -> ResolvedPackage -> ResolvedPackage
withPackageSlug slug package =
  package
    { resolvedPackageCoordinate =
        (resolvedPackageCoordinate package)
          { coordinateSlug = Just slug
          }
    }

testPackageConstraint :: Text -> Text -> Text -> Bool -> PackageConstraint
testPackageConstraint sourcePackage targetPackage relation required =
  PackageConstraint
    { constraintId = sourcePackage <> "-" <> relation <> "-" <> targetPackage
    , constraintSourcePackage = Just sourcePackage
    , constraintTargetPackageId = Just targetPackage
    , constraintTargetKind = "mod"
    , constraintRelation = relation
    , constraintMinecraftVersions = maybe [] (: []) (versionIdFromText "1.21.5")
    , constraintLoaders = ["fabric"]
    , constraintJavaMajor = Nothing
    , constraintSide = Just "client"
    , constraintRequired = required
    , constraintReason = sourcePackage <> " " <> relation <> " " <> targetPackage
    }

testPaninoLockfile :: FilePath -> [ResolvedPackage] -> PaninoLockfile
testPaninoLockfile gameDir packages =
  PaninoLockfile
    { lockfileVersion = 1
    , lockfileSolverVersion = "test"
    , lockfileFingerprint = ""
    , lockfileCreatedAt = Nothing
    , lockfileUpdatedAt = Nothing
    , lockfileTargetGameDir = gameDirFromPath gameDir
    , lockfileMinecraft = Just "1.21.5"
    , lockfileJava = Nothing
    , lockfileLoader = Nothing
    , lockfileShaderLoader = Nothing
    , lockfileRoots = []
    , lockfilePackages = packages
    , lockfileFiles = mapMaybe testLockfileFile packages
    , lockfileConstraints = concatMap resolvedPackageDependencies packages
    , lockfileOverrides = []
    , lockfileSourceSnapshots = []
    , lockfileManualEntries = []
    , lockfileWarnings = []
    }

testLockfileFile :: ResolvedPackage -> Maybe LockfileFile
testLockfileFile package = do
  targetPath <- resolvedPackageTargetPath package
  packageFileName <- resolvedPackageFileName package
  pure
    LockfileFile
      { lockfileFilePackageId = resolvedPackageId package
      , lockfileFileName = packageFileName
      , lockfileFileTargetPath = targetPath
      , lockfileFileHashes = resolvedPackageHashes package
      , lockfileFileSize = resolvedPackageSize package
      , lockfileFileDownloadUrls = resolvedPackageDownloadUrls package
      , lockfileFileKind = coordinateKind (resolvedPackageCoordinate package)
      }
