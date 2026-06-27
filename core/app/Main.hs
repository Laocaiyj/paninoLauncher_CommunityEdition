{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.Aeson (encode)
import Control.Monad (when)
import qualified Data.Text as Text
import Data.Version (showVersion)
import Panino.Api.Server
  ( ApiServerOptions(..)
  , runApiServer
  )
import Panino.Core
  ( Command(..)
  , InstallOptions(..)
  , LaunchOptions(..)
  , ResolveOptions(..)
  , ServeOptions(..)
  , parseCommand
  , renderCommand
  , selectServeSessionToken
  , sessionTokenString
  )
import Panino.Core.Types
  ( versionIdText
  )
import Panino.Launch.Arguments
  ( LaunchProfile(..)
  , buildJavaArguments
  )
import Panino.Launch.Java
  ( JavaRunResult(..)
  , runJavaProcess
  )
import Panino.Minecraft.Install
  ( InstallResult(..)
  , classpathJars
  , installMinecraftVersion
  , resolveVersionSummaryJson
  )
import Panino.Minecraft.LoaderInstall
  ( LoaderInstallOptions(..)
  , LoaderInstallResult(..)
  , installMinecraftProfile
  )
import Panino.Minecraft.Layout
  ( ensureLayout
  , minecraftRoot
  , mkLayout
  )
import Panino.Minecraft.Manifest
  ( loadVersionJson
  , makeHttpManager
  )
import Panino.Minecraft.ModPreflight (preflightModDependencies)
import Panino.Minecraft.Types (VersionJson(..))
import Paths_panino_core (version)
import System.Environment (getArgs, lookupEnv)
import System.Exit (die, exitWith)

main :: IO ()
main = do
  args <- getArgs
  case parseCommand args of
    Right command ->
      runCommand (showVersion version) command
    Left err ->
      die err

runCommand :: String -> Command -> IO ()
runCommand packageVersion command =
  case command of
    ShowVersion -> putStrLn (renderCommand packageVersion command)
    HealthCheck -> putStrLn (renderCommand packageVersion command)
    ShowHelp -> putStrLn (renderCommand packageVersion command)
    Resolve options -> runResolve options
    Install options -> runInstall options
    PrintArgs options -> runPrintArgs options
    Launch options -> runLaunch options
    Serve options -> runServe options

runResolve :: ResolveOptions -> IO ()
runResolve options = do
  manager <- makeHttpManager
  layout <- mkLayout (resolveGameDir options)
  ensureLayout layout
  versionJson <- loadVersionJson manager layout (Text.pack (resolveVersion options))
  BL8.putStrLn (resolveVersionSummaryJson versionJson)

runInstall :: InstallOptions -> IO ()
runInstall options = do
  manager <- makeHttpManager
  layout <- mkLayout (installGameDir options)
  profileResult <-
    installMinecraftProfile
      manager
      layout
      (Text.pack (installVersion options))
      (installConcurrency options)
      LoaderInstallOptions
        { loaderInstallLoader = Text.pack <$> installLoader options
        , loaderInstallLoaderVersion = Nothing
        , loaderInstallShaderLoader = Text.pack <$> installShaderLoader options
        , loaderInstallShaderVersion = Nothing
        , loaderInstallInstanceName = Nothing
        , loaderInstallJavaExecutable = Nothing
        , loaderInstallExpectedProfileId = Nothing
        }
  let result = loaderInstallResult profileResult
  putStrLn
    ( "installed "
        <> Text.unpack (Text.pack (installVersion options))
        <> " into "
        <> minecraftRoot layout
        <> " with "
        <> show (length (classpathJars layout (installVersionJson result)))
        <> " classpath jars"
    )

runPrintArgs :: LaunchOptions -> IO ()
runPrintArgs options = do
  manager <- makeHttpManager
  layout <- mkLayout (launchGameDir options)
  ensureLayout layout
  versionJson <- loadVersionJson manager layout (Text.pack (launchVersion options))
  let args = buildJavaArguments layout versionJson (classpathJars layout versionJson) (launchProfile options)
  BL8.putStrLn (encode args)

runLaunch :: LaunchOptions -> IO ()
runLaunch options = do
  manager <- makeHttpManager
  layout <- mkLayout (launchGameDir options)
  ensureLayout layout
  versionJson <-
    if launchInstallBefore options
      then installVersionJson <$> installMinecraftVersion manager layout (Text.pack (launchVersion options)) (launchConcurrency options)
      else loadVersionJson manager layout (Text.pack (launchVersion options))
  let javaArgs = buildJavaArguments layout versionJson (classpathJars layout versionJson) (launchProfile options)
  when (usesModLoader versionJson) $
    preflightModDependencies (minecraftRoot layout)
  result <- runJavaProcess (launchJavaPath options) (minecraftRoot layout) javaArgs
  exitWith (javaExitCode result)

runServe :: ServeOptions -> IO ()
runServe options = do
  fileToken <- traverse readFile (serveSessionTokenFile options)
  envToken <- lookupEnv "PANINO_CORE_SESSION_TOKEN"
  token <-
    case selectServeSessionToken fileToken envToken options of
      Right value -> pure value
      Left err -> die err
  runApiServer
    ApiServerOptions
      { apiServerHost = serveHost options
      , apiServerPort = servePort options
      , apiServerSessionToken = Text.pack (sessionTokenString token)
      , apiServerGameDir = serveGameDir options
      }

launchProfile :: LaunchOptions -> LaunchProfile
launchProfile options =
  LaunchProfile
    { profileVersion = Text.pack (launchVersion options)
    , profileMemoryMb = launchMemoryMb options
    , profileJavaPath = launchJavaPath options
    , profileUsername = Text.pack (launchUsername options)
    , profileUuid = Text.pack (launchUuid options)
    , profileAccessToken = Text.pack (launchAccessToken options)
    , profileJvmArgs = []
    , profileJvmTuning = Nothing
    , profileWindowWidth = Nothing
    , profileWindowHeight = Nothing
    }

usesModLoader :: VersionJson -> Bool
usesModLoader versionJson =
  any (`Text.isInfixOf` normalized)
    [ "fabric"
    , "quilt"
    , "forge"
    , "neoforge"
    ]
  where
    normalized =
      Text.toLower (versionIdText (versionId versionJson) <> " " <> versionMainClass versionJson)
