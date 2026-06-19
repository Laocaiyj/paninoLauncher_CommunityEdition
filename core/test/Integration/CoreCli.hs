{-# LANGUAGE OverloadedStrings #-}

module Integration.CoreCli
  ( assertCoreCli
  ) where

import Panino.Core
  ( Command(..)
  , InstallOptions(..)
  , LaunchOptions(..)
  , ResolveOptions(..)
  , ServeOptions(..)
  , parseCommand
  , renderCommand
  , selectServeSessionToken
  , versionLine
  )
import TestSupport (assertEqual)

assertCoreCli :: IO ()
assertCoreCli = do
  assertEqual "default command" (Right ShowVersion) (parseCommand [])
  assertEqual "version flag" (Right ShowVersion) (parseCommand ["--version"])
  assertEqual "health command" (Right HealthCheck) (parseCommand ["health"])
  assertEqual "unknown command" (Left "unknown command: nope") (parseCommand ["nope"])
  assertEqual
    "resolve command"
    (Right (Resolve (ResolveOptions "1.20.1" Nothing)))
    (parseCommand ["resolve", "--version", "1.20.1"])
  assertEqual
    "install command"
    (Right (Install (InstallOptions "1.20.1" (Just "/tmp/mc") 4 Nothing Nothing)))
    (parseCommand ["install", "--version", "1.20.1", "--game-dir", "/tmp/mc", "--concurrency", "4"])
  assertEqual
    "install loader command"
    (Right (Install (InstallOptions "1.20.1" (Just "/tmp/mc") 4 (Just "fabric") (Just "iris"))))
    (parseCommand ["install", "--version", "1.20.1", "--game-dir", "/tmp/mc", "--concurrency", "4", "--loader", "fabric", "--shader-loader", "iris"])
  assertEqual
    "args command"
    (Right (PrintArgs (LaunchOptions "1.20.1" Nothing 2048 "java" "Steve" "00000000-0000-0000-0000-000000000000" "0" 32 False)))
    (parseCommand ["args", "--version", "1.20.1", "--memory", "2048"])
  assertEqual
    "serve command"
    (Right (Serve (ServeOptions "127.0.0.1" 37123 (Just "dev-token") Nothing (Just "/tmp/mc"))))
    (parseCommand ["serve", "--port", "37123", "--session-token", "dev-token", "--game-dir", "/tmp/mc"])
  assertEqual
    "serve token file command"
    (Right (Serve (ServeOptions "127.0.0.1" 37123 Nothing (Just "/tmp/core-token") Nothing)))
    (parseCommand ["serve", "--port", "37123", "--session-token-file", "/tmp/core-token"])
  let serveOptions = ServeOptions "127.0.0.1" 37123 (Just "legacy-token") (Just "/tmp/core-token") Nothing
  assertEqual "serve token file wins" (Right "file-token") (selectServeSessionToken (Just " file-token\n") (Just "env-token") serveOptions)
  assertEqual "serve token env fallback" (Right "env-token") (selectServeSessionToken Nothing (Just "env-token") serveOptions)
  assertEqual "serve token legacy fallback" (Right "legacy-token") (selectServeSessionToken Nothing Nothing serveOptions)
  assertEqual
    "serve token rejects empty sources"
    (Left "serve requires --session-token-file, PANINO_CORE_SESSION_TOKEN, or --session-token")
    (selectServeSessionToken (Just "\n") (Just " ") (ServeOptions "127.0.0.1" 37123 (Just "") Nothing Nothing))
  assertEqual "version line" "panino-core 0.1.0.0" (versionLine "0.1.0.0")
  assertEqual "health output" "ok" (renderCommand "0.1.0.0" HealthCheck)
