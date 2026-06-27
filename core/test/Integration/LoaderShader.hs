{-# LANGUAGE OverloadedStrings #-}

module Integration.LoaderShader
  ( assertInstallerProbeRateLimitCooldown
  , assertLoaderShaderInstallFixtures
  , assertLoaderShaderPreflightFixtures
  , assertTrackedShaderInstallCleanup
  ) where

import Control.Exception
  ( SomeException
  , finally
  , try
  )
import Control.Monad (when)
import Data.List (isInfixOf)
import Integration.LoaderShader.Preflight
  ( assertInstallerProbeRateLimitCooldown
  , assertLoaderShaderPreflightFixtures
  )
import Integration.LoaderShaderFixtureServer
  ( fakeLoaderShaderPreflightApp
  )
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.Download.Manager
  ( downloadOptionsWithOverrides
  )
import Panino.Core.Types
  ( versionIdText
  )
import Panino.Launch.Arguments
  ( LaunchProfile(..)
  , buildJavaArguments
  )
import Panino.Minecraft.Install
  ( InstallResult(..)
  , classpathJars
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  , clientJarPath
  , mkLayout
  , minecraftRoot
  , versionJsonPath
  )
import Panino.Minecraft.LoaderInstall
  ( LoaderInstallOptions(..)
  , LoaderInstallResult(..)
  , installMinecraftProfileWithOptionsAndProgressAndCancel
  , removeTrackedShaderInstallFiles
  )
import Panino.Minecraft.Types
  ( VersionJson(..)
  )
import Panino.Net.Http
  ( makeHttpManager
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , getTemporaryDirectory
  , removeDirectoryRecursive
  )
import System.Environment
  ( setEnv
  , unsetEnv
  )
import System.Exit
  ( ExitCode(..)
  )
import System.FilePath
  ( (</>)
  )
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )
import TestSupport
  ( assertEqual
  , catchAny
  )

assertTrackedShaderInstallCleanup :: FilePath -> IO ()
assertTrackedShaderInstallCleanup tempRoot = do
  let root = tempRoot </> "panino-shader-cleanup"
      trackedIris = "iris-1.0.0.jar"
      trackedSodium = "sodium-fabric-0.7.0+mc1.21.8.jar"
      userJar = "user-mod.jar"
  exists <- doesDirectoryExist root
  when exists (removeDirectoryRecursive root)
  layout <- mkLayout (Just root)
  createDirectoryIfMissing True (minecraftRoot layout </> "mods")
  createDirectoryIfMissing True (minecraftRoot layout </> "downloads")
  writeFile (minecraftRoot layout </> "mods" </> trackedIris) "iris"
  writeFile (minecraftRoot layout </> "mods" </> trackedSodium) "sodium"
  writeFile (minecraftRoot layout </> "mods" </> userJar) "user"
  writeFile
    (minecraftRoot layout </> "downloads" </> "shader-install.log")
    ( unlines
        [ "iris file=iris-1.0.0.jar url=https://cdn.example/iris.jar"
        , "AANobbMI file=sodium-fabric-0.7.0+mc1.21.8.jar url=https://cdn.example/sodium.jar"
        ]
    )
  removeTrackedShaderInstallFiles layout
  trackedIrisExists <- doesFileExist (minecraftRoot layout </> "mods" </> trackedIris)
  trackedSodiumExists <- doesFileExist (minecraftRoot layout </> "mods" </> trackedSodium)
  userJarExists <- doesFileExist (minecraftRoot layout </> "mods" </> userJar)
  assertEqual "tracked shader cleanup removes Iris companion" False trackedIrisExists
  assertEqual "tracked shader cleanup removes Sodium companion" False trackedSodiumExists
  assertEqual "tracked shader cleanup preserves untracked user mod" True userJarExists

assertLoaderShaderInstallFixtures :: IO ()
assertLoaderShaderInstallFixtures = do
  manager <- makeHttpManager
  tempDir <- getTemporaryDirectory
  testWithApplication (pure fakeLoaderShaderPreflightApp) $ \port -> do
    let base = "http://127.0.0.1:" <> show port
        withSources action =
          ( do
              setEnv "PANINO_MOJANG_META_BASE" base
              setEnv "PANINO_MOJANG_RESOURCES_BASE" base
              setEnv "PANINO_MOJANG_LIBRARIES_BASE" base
              setEnv "PANINO_FABRIC_META_BASE" base
              setEnv "PANINO_FABRIC_MAVEN_BASE" base
              setEnv "PANINO_QUILT_META_BASE" base
              setEnv "PANINO_FORGE_FILES_BASE" base
              setEnv "PANINO_FORGE_MAVEN_BASE" base
              setEnv "PANINO_NEOFORGE_MAVEN_BASE" base
              setEnv "PANINO_MODRINTH_API_BASE" base
              setEnv "PANINO_MODRINTH_CDN_BASE" base
              setEnv "PANINO_DISABLE_OFFICIAL_FALLBACK" "true"
              action
          )
            `finally` do
              unsetEnv "PANINO_MOJANG_META_BASE"
              unsetEnv "PANINO_MOJANG_RESOURCES_BASE"
              unsetEnv "PANINO_MOJANG_LIBRARIES_BASE"
              unsetEnv "PANINO_FABRIC_META_BASE"
              unsetEnv "PANINO_FABRIC_MAVEN_BASE"
              unsetEnv "PANINO_QUILT_META_BASE"
              unsetEnv "PANINO_FORGE_FILES_BASE"
              unsetEnv "PANINO_FORGE_MAVEN_BASE"
              unsetEnv "PANINO_NEOFORGE_MAVEN_BASE"
              unsetEnv "PANINO_MODRINTH_API_BASE"
              unsetEnv "PANINO_MODRINTH_CDN_BASE"
              unsetEnv "PANINO_DISABLE_OFFICIAL_FALLBACK"
    withSources $ do
      let root = tempDir </> "panino-loader-shader-install-fixture"
          fabricRoot = root </> "fabric"
          quiltRoot = root </> "quilt"
      exists <- doesDirectoryExist root
      when exists (removeDirectoryRecursive root `catchAny` \_ -> pure ())
      fabricLayout <- mkLayout (Just fabricRoot)
      fabricResult <-
        installMinecraftProfileWithOptionsAndProgressAndCancel
          manager
          fabricLayout
          "26.1.2"
          (downloadOptionsWithOverrides (Just 2) (Just 0))
          (pure False)
          (\_ -> pure ())
          LoaderInstallOptions
            { loaderInstallLoader = Just "fabric"
            , loaderInstallLoaderVersion = Nothing
            , loaderInstallShaderLoader = Just "iris"
            , loaderInstallShaderVersion = Nothing
            , loaderInstallInstanceName = Just "Fabric Iris Fixture"
            , loaderInstallJavaExecutable = Nothing
            , loaderInstallExpectedProfileId = Just "fabric-loader-0.16.0-26.1.2"
            }
      fabricProfileExists <- doesFileExist (versionJsonPath fabricLayout (loaderInstallProfileVersion fabricResult))
      fabricClientExists <- doesFileExist (clientJarPath fabricLayout "26.1.2")
      irisExists <- doesFileExist (minecraftRoot fabricLayout </> "mods" </> "iris-1.0.0.jar")
      fabricApiExists <- doesFileExist (minecraftRoot fabricLayout </> "mods" </> "fabric-api-1.0.0.jar")
      assertEqual "Fabric fixture install creates loader profile" True fabricProfileExists
      assertEqual "Fabric fixture install keeps base client jar" True fabricClientExists
      assertEqual "Iris fixture install writes shader mod" True irisExists
      assertEqual "Iris fixture install writes Fabric API companion" True fabricApiExists

      quiltLayout <- mkLayout (Just quiltRoot)
      quiltResult <-
        installMinecraftProfileWithOptionsAndProgressAndCancel
          manager
          quiltLayout
          "26.1.2"
          (downloadOptionsWithOverrides (Just 2) (Just 0))
          (pure False)
          (\_ -> pure ())
          LoaderInstallOptions
            { loaderInstallLoader = Just "quilt"
            , loaderInstallLoaderVersion = Nothing
            , loaderInstallShaderLoader = Nothing
            , loaderInstallShaderVersion = Nothing
            , loaderInstallInstanceName = Just "Quilt Fixture"
            , loaderInstallJavaExecutable = Nothing
            , loaderInstallExpectedProfileId = Just "quilt-loader-0.29.1-26.1.2"
            }
      quiltProfileExists <- doesFileExist (versionJsonPath quiltLayout (loaderInstallProfileVersion quiltResult))
      quiltClientExists <- doesFileExist (clientJarPath quiltLayout "26.1.2")
      quiltIntermediaryExists <- doesFileExist (librariesDir quiltLayout </> "net" </> "fabricmc" </> "intermediary" </> "26.1.2" </> "intermediary-26.1.2.jar")
      let quiltVersionJson = installVersionJson (loaderInstallResult quiltResult)
          quiltLaunchArgs =
            buildJavaArguments
              quiltLayout
              quiltVersionJson
              (classpathJars quiltLayout quiltVersionJson)
              LaunchProfile
                { profileVersion = loaderInstallProfileVersion quiltResult
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
      assertEqual "Quilt fixture install creates loader profile" True quiltProfileExists
      assertEqual "Quilt fixture install keeps base client jar" True quiltClientExists
      assertEqual "Quilt fixture install downloads intermediary mappings" True quiltIntermediaryExists
      assertEqual "Quilt fixture launch version is loader profile" "quilt-loader-0.29.1-26.1.2" (versionIdText (versionId quiltVersionJson))
      assertEqual "Quilt fixture launch main class is Quilt KnotClient" "org.quiltmc.loader.impl.launch.knot.KnotClient" (versionMainClass quiltVersionJson)
      assertEqual "Quilt fixture launch args include Quilt main class" True ("org.quiltmc.loader.impl.launch.knot.KnotClient" `elem` quiltLaunchArgs)
      assertEqual "Quilt fixture launch classpath includes loader profile client jar" True (any ("quilt-loader-0.29.1-26.1.2.jar" `isInfixOf`) quiltLaunchArgs)
      assertEqual "Quilt fixture launch classpath includes Quilt loader jar" True (any ("org/quiltmc/quilt-loader/0.29.1/quilt-loader-0.29.1.jar" `isInfixOf`) quiltLaunchArgs)
      assertEqual "Quilt fixture launch classpath includes intermediary mappings" True (any ("net/fabricmc/intermediary/26.1.2/intermediary-26.1.2.jar" `isInfixOf`) quiltLaunchArgs)

      invalidShaderLayout <- mkLayout (Just (root </> "neoforge-iris-invalid"))
      invalidShaderResult <-
        try
          ( installMinecraftProfileWithOptionsAndProgressAndCancel
              manager
              invalidShaderLayout
              "26.1.2"
              (downloadOptionsWithOverrides (Just 2) (Just 0))
              (pure False)
              (\_ -> pure ())
              LoaderInstallOptions
                { loaderInstallLoader = Just "neoforge"
                , loaderInstallLoaderVersion = Nothing
                , loaderInstallShaderLoader = Just "iris"
                , loaderInstallShaderVersion = Nothing
                , loaderInstallInstanceName = Just "Invalid Shader Fixture"
                , loaderInstallJavaExecutable = Nothing
                , loaderInstallExpectedProfileId = Nothing
                }
          ) :: IO (Either SomeException LoaderInstallResult)
      assertEqual
        "NeoForge + Iris fixture is blocked before partial install"
        True
        (either (("shader_loader_incompatible:iris neoforge" `isInfixOf`) . show) (const False) invalidShaderResult)

      quiltIrisLayout <- mkLayout (Just (root </> "quilt-iris"))
      _quiltIrisResult <-
        installMinecraftProfileWithOptionsAndProgressAndCancel
          manager
          quiltIrisLayout
          "26.1.2"
          (downloadOptionsWithOverrides (Just 2) (Just 0))
          (pure False)
          (\_ -> pure ())
          LoaderInstallOptions
            { loaderInstallLoader = Just "quilt"
            , loaderInstallLoaderVersion = Nothing
            , loaderInstallShaderLoader = Just "iris"
            , loaderInstallShaderVersion = Nothing
            , loaderInstallInstanceName = Just "Quilt Iris Fixture"
            , loaderInstallJavaExecutable = Nothing
            , loaderInstallExpectedProfileId = Just "quilt-loader-0.29.1-26.1.2"
            }
      quiltIrisExists <- doesFileExist (minecraftRoot quiltIrisLayout </> "mods" </> "iris-1.0.0.jar")
      quiltIrisFabricApiExists <- doesFileExist (minecraftRoot quiltIrisLayout </> "mods" </> "fabric-api-1.0.0.jar")
      quiltIrisShaderLog <- readFile (minecraftRoot quiltIrisLayout </> "downloads" </> "shader-install.log")
      assertEqual "Quilt Iris fixture install writes fallback Iris mod" True quiltIrisExists
      assertEqual "Quilt Iris fixture install writes fallback Fabric API dependency" True quiltIrisFabricApiExists
      assertEqual "Quilt Iris fixture install records fallback in shader log" True ("fallback=true" `isInfixOf` quiltIrisShaderLog)

      let fakeJava = root </> "fake-java"
      writeFile fakeJava $
        unlines
          [ "#!/bin/sh"
          , "target=\"\""
          , "for arg in \"$@\"; do target=\"$arg\"; done"
          , "test -f \"$target/launcher_profiles.json\" || exit 42"
          , "grep -q '\"profiles\"' \"$target/launcher_profiles.json\" || exit 43"
          , "grep -q '\"lastVersionId\":\"26.1.2\"' \"$target/launcher_profiles.json\" || exit 44"
          , "test -f \"$target/versions/26.1.2/26.1.2.json\" || exit 45"
          , "exit 0"
          ]
      (chmodExit, _, chmodErr) <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", fakeJava]) ""
      assertEqual "fake Java chmod succeeds" ExitSuccess chmodExit
      assertEqual "fake Java chmod stderr" "" chmodErr
      neoforgeLayout <- mkLayout (Just (root </> "neoforge"))
      neoforgeResult <-
        try
          ( installMinecraftProfileWithOptionsAndProgressAndCancel
              manager
              neoforgeLayout
              "26.1.2"
              (downloadOptionsWithOverrides (Just 1) (Just 0))
              (pure False)
              (\_ -> pure ())
              LoaderInstallOptions
                { loaderInstallLoader = Just "neoforge"
                , loaderInstallLoaderVersion = Nothing
                , loaderInstallShaderLoader = Nothing
                , loaderInstallShaderVersion = Nothing
                , loaderInstallInstanceName = Just "NeoForge Missing Profile Fixture"
                , loaderInstallJavaExecutable = Just fakeJava
                , loaderInstallExpectedProfileId = Nothing
                }
          ) :: IO (Either SomeException LoaderInstallResult)
      case neoforgeResult of
        Left err ->
          assertEqual "NeoForge missing profile reports stable error" True ("loader_profile_not_created" `isInfixOf` show err)
        Right _ ->
          assertEqual "NeoForge fixture should fail when installer creates no profile" True False
      neoforgeLauncherProfilesExists <- doesFileExist (minecraftRoot neoforgeLayout </> "launcher_profiles.json")
      neoforgeLauncherProfiles <- readFile (minecraftRoot neoforgeLayout </> "launcher_profiles.json")
      assertEqual "NeoForge fixture prepares launcher_profiles.json before running installer" True neoforgeLauncherProfilesExists
      assertEqual "NeoForge fixture launcher_profiles.json has Panino marker" True ("Panino Launcher" `isInfixOf` neoforgeLauncherProfiles)
      assertEqual "NeoForge fixture launcher_profiles.json selects Panino profile" True ("\"selectedProfile\":\"Panino\"" `isInfixOf` neoforgeLauncherProfiles)
      assertEqual "NeoForge fixture launcher_profiles.json points at base Minecraft" True ("\"lastVersionId\":\"26.1.2\"" `isInfixOf` neoforgeLauncherProfiles)
      neoforgeBaseVersionExists <- doesFileExist (versionJsonPath neoforgeLayout "26.1.2")
      assertEqual "NeoForge fixture prepares vanilla version before running installer" True neoforgeBaseVersionExists

      let fakeWrongProfileJava = root </> "fake-java-wrong-profile"
      writeFile fakeWrongProfileJava $
        unlines
          [ "#!/bin/sh"
          , "target=\"\""
          , "for arg in \"$@\"; do target=\"$arg\"; done"
          , "profile=\"$target/versions/neoforge-26.1.2.1\""
          , "mkdir -p \"$profile\""
          , "cat > \"$profile/neoforge-26.1.2.1.json\" <<'JSON'"
          , "{\"id\":\"neoforge-26.1.2.1\",\"inheritsFrom\":\"wrong-minecraft\",\"mainClass\":\"cpw.mods.bootstrap.BootstrapLauncher\",\"libraries\":[{\"name\":\"net.neoforged:neoforge:26.1.2.1\"}]}"
          , "JSON"
          , "exit 0"
          ]
      (chmodWrongExit, _, chmodWrongErr) <- readCreateProcessWithExitCode (proc "/bin/chmod" ["+x", fakeWrongProfileJava]) ""
      assertEqual "fake wrong-profile Java chmod succeeds" ExitSuccess chmodWrongExit
      assertEqual "fake wrong-profile Java chmod stderr" "" chmodWrongErr
      wrongProfileLayout <- mkLayout (Just (root </> "neoforge-wrong-profile"))
      wrongProfileResult <-
        try
          ( installMinecraftProfileWithOptionsAndProgressAndCancel
              manager
              wrongProfileLayout
              "26.1.2"
              (downloadOptionsWithOverrides (Just 1) (Just 0))
              (pure False)
              (\_ -> pure ())
              LoaderInstallOptions
                { loaderInstallLoader = Just "neoforge"
                , loaderInstallLoaderVersion = Nothing
                , loaderInstallShaderLoader = Nothing
                , loaderInstallShaderVersion = Nothing
                , loaderInstallInstanceName = Just "NeoForge Wrong Profile Fixture"
                , loaderInstallJavaExecutable = Just fakeWrongProfileJava
                , loaderInstallExpectedProfileId = Nothing
                }
          ) :: IO (Either SomeException LoaderInstallResult)
      case wrongProfileResult of
        Left err ->
          assertEqual "NeoForge wrong inherited profile is rejected" True ("loader_profile_not_created" `isInfixOf` show err)
        Right _ ->
          assertEqual "NeoForge fixture should reject wrong inherited profile" True False
