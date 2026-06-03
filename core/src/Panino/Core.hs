module Panino.Core
  ( Command(..)
  , InstallOptions(..)
  , LaunchOptions(..)
  , ResolveOptions(..)
  , ServeOptions(..)
  , parseCommand
  , renderCommand
  , selectServeSessionToken
  , versionLine
  ) where

import Data.Char (isSpace)
import Text.Read (readMaybe)

data Command
  = ShowVersion
  | HealthCheck
  | ShowHelp
  | Resolve ResolveOptions
  | Install InstallOptions
  | PrintArgs LaunchOptions
  | Launch LaunchOptions
  | Serve ServeOptions
  deriving (Eq, Show)

data ResolveOptions = ResolveOptions
  { resolveVersion :: String
  , resolveGameDir :: Maybe FilePath
  } deriving (Eq, Show)

data InstallOptions = InstallOptions
  { installVersion :: String
  , installGameDir :: Maybe FilePath
  , installConcurrency :: Int
  , installLoader :: Maybe String
  , installShaderLoader :: Maybe String
  } deriving (Eq, Show)

data LaunchOptions = LaunchOptions
  { launchVersion :: String
  , launchGameDir :: Maybe FilePath
  , launchMemoryMb :: Int
  , launchJavaPath :: FilePath
  , launchUsername :: String
  , launchUuid :: String
  , launchAccessToken :: String
  , launchConcurrency :: Int
  , launchInstallBefore :: Bool
  } deriving (Eq, Show)

data ServeOptions = ServeOptions
  { serveHost :: String
  , servePort :: Int
  , serveSessionToken :: Maybe String
  , serveSessionTokenFile :: Maybe FilePath
  , serveGameDir :: Maybe FilePath
  } deriving (Eq, Show)

parseCommand :: [String] -> Either String Command
parseCommand [] = Right ShowVersion
parseCommand ["--version"] = Right ShowVersion
parseCommand ["version"] = Right ShowVersion
parseCommand ["health"] = Right HealthCheck
parseCommand ["--help"] = Right ShowHelp
parseCommand ["help"] = Right ShowHelp
parseCommand ("resolve":args) = Resolve <$> parseResolveOptions args
parseCommand ("install":args) = Install <$> parseInstallOptions args
parseCommand ("args":args) = PrintArgs <$> parseLaunchOptions True args
parseCommand ("jvm-args":args) = PrintArgs <$> parseLaunchOptions True args
parseCommand ("print-args":args) = PrintArgs <$> parseLaunchOptions True args
parseCommand ("launch":args) = Launch <$> parseLaunchOptions False args
parseCommand ("serve":args) = Serve <$> parseServeOptions args
parseCommand args = Left ("unknown command: " <> unwords args)

renderCommand :: String -> Command -> String
renderCommand packageVersion ShowVersion = versionLine packageVersion
renderCommand _ HealthCheck = "ok"
renderCommand _ ShowHelp = unlines
  [ "panino-core"
  , ""
  , "Commands:"
  , "  --version    Print the core version"
  , "  health       Print a local health check response"
  , "  help         Print this help"
  , "  resolve      Fetch and print a Minecraft version summary"
  , "  install      Download and verify a Minecraft version"
  , "  args         Print the Java argument array for a version"
  , "  launch       Install, build arguments, and run Java"
  , "  serve        Start the local HTTP API service"
  , ""
  , "Common flags:"
  , "  --version <id>          Minecraft version, for example 1.20.1"
  , "  --game-dir <path>       Override the Minecraft data directory"
  , "  --concurrency <n>       Download concurrency, default 32"
  , "  --loader <name>         Optional loader for install: fabric, forge, quilt, neoforge"
  , "  --shader-loader <name>  Optional shader loader for install: iris, oculus"
  , "  --memory <mb>           JVM max heap for args/launch, default 4096"
  , "  --java <path>           Java executable for launch, default java"
  , "  --username <name>       Offline placeholder username, default Steve"
  , "  --uuid <uuid>           Offline placeholder UUID"
  , "  --access-token <token>  Offline placeholder access token"
  , "  --no-install            Launch without first running install"
  , "  --host <host>           API bind host for serve, default 127.0.0.1"
  , "  --port <port>           API bind port for serve"
  , "  --session-token <token> API bearer token for serve"
  , "  --session-token-file <path> File containing API bearer token for serve"
  ]
renderCommand _ (Resolve _) = "resolve"
renderCommand _ (Install _) = "install"
renderCommand _ (PrintArgs _) = "args"
renderCommand _ (Launch _) = "launch"
renderCommand _ (Serve _) = "serve"

versionLine :: String -> String
versionLine packageVersion = "panino-core " <> packageVersion

parseResolveOptions :: [String] -> Either String ResolveOptions
parseResolveOptions args = do
  options <- parseFlags args
  version <- requireFlag "--version" options
  pure ResolveOptions
    { resolveVersion = version
    , resolveGameDir = lookupFlag "--game-dir" options
    }

parseInstallOptions :: [String] -> Either String InstallOptions
parseInstallOptions args = do
  options <- parseFlags args
  version <- requireFlag "--version" options
  concurrency <- parseIntFlag "--concurrency" 32 options
  pure InstallOptions
    { installVersion = version
    , installGameDir = lookupFlag "--game-dir" options
    , installConcurrency = concurrency
    , installLoader = lookupFlag "--loader" options
    , installShaderLoader = lookupFlag "--shader-loader" options
    }

parseLaunchOptions :: Bool -> [String] -> Either String LaunchOptions
parseLaunchOptions printOnly args = do
  options <- parseFlags args
  version <- requireFlag "--version" options
  memoryMb <- parseIntFlag "--memory" 4096 options
  concurrency <- parseIntFlag "--concurrency" 32 options
  pure LaunchOptions
    { launchVersion = version
    , launchGameDir = lookupFlag "--game-dir" options
    , launchMemoryMb = memoryMb
    , launchJavaPath = valueOr "java" (lookupFlag "--java" options)
    , launchUsername = valueOr "Steve" (lookupFlag "--username" options)
    , launchUuid = valueOr "00000000-0000-0000-0000-000000000000" (lookupFlag "--uuid" options)
    , launchAccessToken = valueOr "0" (lookupFlag "--access-token" options)
    , launchConcurrency = concurrency
    , launchInstallBefore = not printOnly && not (hasFlag "--no-install" options)
    }

parseServeOptions :: [String] -> Either String ServeOptions
parseServeOptions args = do
  options <- parseFlags args
  port <- requireIntFlag "--port" options
  pure ServeOptions
    { serveHost = valueOr "127.0.0.1" (lookupFlag "--host" options)
    , servePort = port
    , serveSessionToken = lookupFlag "--session-token" options
    , serveSessionTokenFile = lookupFlag "--session-token-file" options
    , serveGameDir = lookupFlag "--game-dir" options
    }

selectServeSessionToken :: Maybe String -> Maybe String -> ServeOptions -> Either String String
selectServeSessionToken fileToken envToken options =
  case firstNonBlank [fileToken, envToken, serveSessionToken options] of
    Just token -> Right token
    Nothing -> Left "serve requires --session-token-file, PANINO_CORE_SESSION_TOKEN, or --session-token"

data FlagValue
  = FlagValue String String
  | BareFlag String
  deriving (Eq, Show)

parseFlags :: [String] -> Either String [FlagValue]
parseFlags [] = Right []
parseFlags [flag]
  | isFlag flag = Right [BareFlag flag]
parseFlags (flag:value:rest)
  | isFlag flag && not (isFlag value) = (FlagValue flag value :) <$> parseFlags rest
parseFlags (flag:rest)
  | isFlag flag = (BareFlag flag :) <$> parseFlags rest
parseFlags (arg:_) = Left ("unexpected argument: " <> arg)

isFlag :: String -> Bool
isFlag ('-':'-':_) = True
isFlag _ = False

lookupFlag :: String -> [FlagValue] -> Maybe String
lookupFlag flag values = go values
  where
    go [] = Nothing
    go (FlagValue key value:rest)
      | key == flag = Just value
      | otherwise = go rest
    go (_:rest) = go rest

hasFlag :: String -> [FlagValue] -> Bool
hasFlag flag = any (== BareFlag flag)

requireFlag :: String -> [FlagValue] -> Either String String
requireFlag flag values =
  case lookupFlag flag values of
    Just value -> Right value
    Nothing -> Left ("missing required flag: " <> flag)

parseIntFlag :: String -> Int -> [FlagValue] -> Either String Int
parseIntFlag flag fallback values =
  case lookupFlag flag values of
    Nothing -> Right fallback
    Just value ->
      case readMaybe value of
        Just parsed
          | parsed > 0 -> Right parsed
        _ -> Left ("invalid integer for " <> flag <> ": " <> value)

requireIntFlag :: String -> [FlagValue] -> Either String Int
requireIntFlag flag values =
  case lookupFlag flag values of
    Nothing -> Left ("missing required flag: " <> flag)
    Just value ->
      case readMaybe value of
        Just parsed
          | parsed > 0 -> Right parsed
        _ -> Left ("invalid integer for " <> flag <> ": " <> value)

valueOr :: a -> Maybe a -> a
valueOr fallback = maybe fallback id

firstNonBlank :: [Maybe String] -> Maybe String
firstNonBlank [] = Nothing
firstNonBlank (Nothing:rest) = firstNonBlank rest
firstNonBlank (Just value:rest) =
  case trim value of
    "" -> firstNonBlank rest
    trimmed -> Just trimmed

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace

dropWhileEnd :: (a -> Bool) -> [a] -> [a]
dropWhileEnd predicate = reverse . dropWhile predicate . reverse
