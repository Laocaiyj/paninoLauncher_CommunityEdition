module Panino.Core
  ( Command(..)
  , InstallOptions(..)
  , LaunchOptions(..)
  , ResolveOptions(..)
  , ServeOptions(..)
  , SessionToken
  , parseCommand
  , renderCommand
  , selectServeSessionToken
  , sessionTokenFromString
  , sessionTokenString
  , versionLine
  ) where

import Panino.Core.CommandLine
  ( FlagDefinition
  , ParsedFlags
  , firstNonBlank
  , hasFlag
  , lookupFlag
  , parseFlags
  , parseIntFlag
  , requireFlag
  , requireIntFlag
  , switchFlag
  , valueFlag
  )
import Panino.Core.Types
  ( GameDir
  , VersionId
  , gameDirFromPath
  , versionIdFromText
  )
import qualified Data.Text as Text

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
  { resolveVersion :: VersionId
  , resolveGameDir :: Maybe GameDir
  } deriving (Eq, Show)

data InstallOptions = InstallOptions
  { installVersion :: VersionId
  , installGameDir :: Maybe GameDir
  , installConcurrency :: Int
  , installLoader :: Maybe String
  , installShaderLoader :: Maybe String
  } deriving (Eq, Show)

data LaunchOptions = LaunchOptions
  { launchVersion :: VersionId
  , launchGameDir :: Maybe GameDir
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
  , serveSessionToken :: Maybe SessionToken
  , serveSessionTokenFile :: Maybe FilePath
  , serveGameDir :: Maybe GameDir
  } deriving (Eq, Show)

newtype SessionToken =
  SessionToken String
  deriving (Eq)

instance Show SessionToken where
  show _ = "<redacted-session-token>"

sessionTokenString :: SessionToken -> String
sessionTokenString (SessionToken token) = token

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
  options <- parseFlags resolveFlags args
  version <- requireVersionFlag "--version" options
  pure ResolveOptions
    { resolveVersion = version
    , resolveGameDir = optionalGameDirFlag "--game-dir" options
    }

parseInstallOptions :: [String] -> Either String InstallOptions
parseInstallOptions args = do
  options <- parseFlags installFlags args
  version <- requireVersionFlag "--version" options
  concurrency <- parseIntFlag "--concurrency" 32 options
  pure InstallOptions
    { installVersion = version
    , installGameDir = optionalGameDirFlag "--game-dir" options
    , installConcurrency = concurrency
    , installLoader = lookupFlag "--loader" options
    , installShaderLoader = lookupFlag "--shader-loader" options
    }

parseLaunchOptions :: Bool -> [String] -> Either String LaunchOptions
parseLaunchOptions printOnly args = do
  options <- parseFlags launchFlags args
  version <- requireVersionFlag "--version" options
  memoryMb <- parseIntFlag "--memory" 4096 options
  concurrency <- parseIntFlag "--concurrency" 32 options
  pure LaunchOptions
    { launchVersion = version
    , launchGameDir = optionalGameDirFlag "--game-dir" options
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
  options <- parseFlags serveFlags args
  port <- requireIntFlag "--port" options
  pure ServeOptions
    { serveHost = valueOr "127.0.0.1" (lookupFlag "--host" options)
    , servePort = port
    , serveSessionToken = lookupFlag "--session-token" options >>= sessionTokenFromString
    , serveSessionTokenFile = lookupFlag "--session-token-file" options
    , serveGameDir = optionalGameDirFlag "--game-dir" options
    }

selectServeSessionToken :: Maybe String -> Maybe String -> ServeOptions -> Either String SessionToken
selectServeSessionToken fileToken envToken options =
  case firstNonBlank [fileToken, envToken] >>= sessionTokenFromString of
    Just token -> Right token
    Nothing ->
      case serveSessionToken options of
        Just token -> Right token
        Nothing -> Left "serve requires --session-token-file, PANINO_CORE_SESSION_TOKEN, or --session-token"

resolveFlags :: [FlagDefinition]
resolveFlags =
  [ valueFlag "--version"
  , valueFlag "--game-dir"
  ]

installFlags :: [FlagDefinition]
installFlags =
  [ valueFlag "--version"
  , valueFlag "--game-dir"
  , valueFlag "--concurrency"
  , valueFlag "--loader"
  , valueFlag "--shader-loader"
  ]

launchFlags :: [FlagDefinition]
launchFlags =
  [ valueFlag "--version"
  , valueFlag "--game-dir"
  , valueFlag "--memory"
  , valueFlag "--java"
  , valueFlag "--username"
  , valueFlag "--uuid"
  , valueFlag "--access-token"
  , valueFlag "--concurrency"
  , switchFlag "--no-install"
  ]

serveFlags :: [FlagDefinition]
serveFlags =
  [ valueFlag "--host"
  , valueFlag "--port"
  , valueFlag "--session-token"
  , valueFlag "--session-token-file"
  , valueFlag "--game-dir"
  ]

valueOr :: a -> Maybe a -> a
valueOr fallback = maybe fallback id

sessionTokenFromString :: String -> Maybe SessionToken
sessionTokenFromString value =
  SessionToken <$> firstNonBlank [Just value]

requireVersionFlag :: String -> ParsedFlags -> Either String VersionId
requireVersionFlag flag options = do
  raw <- requireFlag flag options
  case versionIdFromText (Text.pack raw) of
    Just version -> Right version
    Nothing -> Left (flag <> " must not be empty")

optionalGameDirFlag :: String -> ParsedFlags -> Maybe GameDir
optionalGameDirFlag flag options =
  lookupFlag flag options >>= gameDirFromPath
