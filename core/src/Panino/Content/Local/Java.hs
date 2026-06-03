{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Content.Local.Java
  ( checkJavaRuntime
  , deleteJavaRuntimeCandidate
  , scanJavaRuntimes
  ) where

import Control.Applicative ((<|>))
import Control.Exception
  ( SomeException
  , catch
  )
import Control.Monad (guard)
import Data.Char
  ( isDigit
  , toLower
  )
import Data.List
  ( isInfixOf
  , isSuffixOf
  , nubBy
  , sortOn
  )
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , findExecutable
  , getPermissions
  , executable
  , getHomeDirectory
  , listDirectory
  , removeDirectoryRecursive
  )
import System.Exit (ExitCode(..))
import System.FilePath
  ( (</>)
  , normalise
  , takeDirectory
  , takeFileName
  )
import System.Process
  ( proc
  , readCreateProcessWithExitCode
  )
import Panino.Content.Local.Path
  ( nonEmptyOr
  , trimString
  )
import Panino.Content.Local.Types

checkJavaRuntime :: JavaCheckRequest -> IO JavaCheckResponse
checkJavaRuntime request = do
  let javaExecutable = normalizedJavaExecutable (javaCheckPath request)
  canExecute <- executablePermission javaExecutable
  result <-
    (Right <$> readCreateProcessWithExitCode (proc javaExecutable ["-XshowSettings:properties", "-version"]) "")
      `catch` \(err :: SomeException) -> pure (Left err)
  pure $ case result of
    Left err ->
      JavaCheckResponse
        javaExecutable
        False
        (Text.pack ("Java check failed: " <> show err))
        Nothing
        Nothing
        Nothing
        Nothing
        canExecute
        (Text.pack (show err))
    Right (exitCode, stdoutText, stderrText) ->
      let rawOutput = Text.pack (stderrText <> "\n" <> stdoutText)
          combined = firstUsefulLine (Text.unpack rawOutput)
          version = parseJavaVersion rawOutput <|> versionFromSummary combined
          majorVersion = javaMajorVersion =<< version
          vendor = parseJavaProperty "java.vendor" rawOutput
          architecture = parseJavaProperty "os.arch" rawOutput
          summary = javaRuntimeSummary exitCode rawOutput version vendor architecture
       in JavaCheckResponse
            javaExecutable
            (exitCode == ExitSuccess)
            summary
            version
            majorVersion
            vendor
            architecture
            canExecute
            (Text.take 4000 (Text.strip rawOutput))

scanJavaRuntimes :: IO [JavaRuntimeCandidate]
scanJavaRuntimes = do
  home <- getHomeDirectory
  pathJava <- maybe [] pure <$> findExecutable "java"
  javaHomePaths <- javaHomeCandidates
  bundlePaths <-
    concat
      <$> traverse
        jvmBundleCandidates
        [ "/Library/Java/JavaVirtualMachines"
        , home </> "Library/Java/JavaVirtualMachines"
        ]
  let explicitCandidates =
        [ "/opt/homebrew/opt/openjdk/bin/java"
        , "/opt/homebrew/opt/openjdk@21/bin/java"
        , "/opt/homebrew/opt/openjdk@17/bin/java"
        , "/opt/homebrew/opt/openjdk@11/bin/java"
        , "/opt/homebrew/opt/openjdk@8/bin/java"
        , "/usr/local/opt/openjdk/bin/java"
        , "/usr/local/opt/openjdk@21/bin/java"
        , "/usr/local/opt/openjdk@17/bin/java"
        , "/usr/local/opt/openjdk@11/bin/java"
        , "/usr/local/opt/openjdk@8/bin/java"
        , "java"
        ]
      candidates =
        uniquePaths
          ( pathJava
              <> javaHomePaths
              <> bundlePaths
              <> explicitCandidates
          )
  checked <- traverse javaCandidate candidates
  pure (sortOn javaCandidateSort checked)

normalizedJavaExecutable :: Maybe FilePath -> FilePath
normalizedJavaExecutable =
  nonEmptyOr "java" . maybe "" trimString

javaHomeCandidates :: IO [FilePath]
javaHomeCandidates = do
  let javaHomeTool = "/usr/libexec/java_home"
  exists <- doesFileExist javaHomeTool
  if not exists
    then pure []
    else do
      result <-
        (Right <$> readCreateProcessWithExitCode (proc javaHomeTool ["-V"]) "")
          `catch` \(err :: SomeException) -> pure (Left err)
      pure $ case result of
        Left _ -> []
        Right (_, stdoutText, stderrText) ->
          uniquePaths
            ( mapMaybe javaExecutableFromJavaHomeLine (lines (stderrText <> "\n" <> stdoutText))
            )

jvmBundleCandidates :: FilePath -> IO [FilePath]
jvmBundleCandidates root = do
  exists <- doesDirectoryExist root
  if not exists
    then pure []
    else do
      names <- sortOn id <$> listDirectory root
      fmap concat $
        traverse
          ( \name -> do
              let candidateExecutable = root </> name </> "Contents" </> "Home" </> "bin" </> "java"
              existsFile <- doesFileExist candidateExecutable
              pure [candidateExecutable | existsFile]
          )
          names

javaExecutableFromJavaHomeLine :: String -> Maybe FilePath
javaExecutableFromJavaHomeLine line = do
  let stripped = trimString line
      path = dropWhile (/= '/') stripped
  guard (not (null path))
  let candidateExecutable =
        if "bin/java" `isSuffixOf` path
          then path
          else path </> "bin" </> "java"
  pure candidateExecutable

javaCandidate :: FilePath -> IO JavaRuntimeCandidate
javaCandidate path = do
  checked <- checkJavaRuntime (JavaCheckRequest (Just path))
  pure
    JavaRuntimeCandidate
      { javaCandidatePath = javaResponsePath checked
      , javaCandidateAvailable = javaResponseAvailable checked
      , javaCandidateSummary = javaResponseSummary checked
      , javaCandidateSource = javaCandidateSourceFor path
      , javaCandidateDeleteTarget =
          safeJavaRuntimeDeleteTarget (javaResponsePath checked)
            <|> safeJavaRuntimeDeleteTarget path
      }

javaCandidateSort :: JavaRuntimeCandidate -> (Bool, Text, FilePath)
javaCandidateSort candidate =
  ( not (javaCandidateAvailable candidate)
  , javaCandidateSource candidate
  , javaCandidatePath candidate
  )

javaCandidateSourceFor :: FilePath -> Text
javaCandidateSourceFor path
  | path == "java" = "PATH"
  | "/usr/bin/java" `isInfixOf` path = "PATH"
  | "JavaVirtualMachines" `isInfixOf` path = "macOS"
  | "homebrew" `isInfixOf` lower = "Homebrew"
  | "openjdk" `isInfixOf` lower = "OpenJDK"
  | otherwise = "Local"
  where
    lower = map toLower path

deleteJavaRuntimeCandidate :: JavaRuntimeLocalDeleteRequest -> IO JavaRuntimeLocalDeleteResponse
deleteJavaRuntimeCandidate request = do
  let javaExecutable = normalizedJavaExecutable (Just (javaLocalDeletePath request))
      maybeTarget = safeJavaRuntimeDeleteTarget javaExecutable
  case maybeTarget of
    Nothing ->
      pure
        JavaRuntimeLocalDeleteResponse
          { javaLocalDeleteDeleted = False
          , javaLocalDeleteResponsePath = javaExecutable
          , javaLocalDeleteTargetRoot = Nothing
          , javaLocalDeleteMessage =
              "Only self-contained macOS .jdk/.jre bundles can be removed safely. Use the system package manager for PATH, /usr/bin/java or Homebrew Java."
          }
    Just targetRoot -> do
      exists <- doesDirectoryExist targetRoot
      if not exists
        then
          pure
            JavaRuntimeLocalDeleteResponse
              { javaLocalDeleteDeleted = False
              , javaLocalDeleteResponsePath = javaExecutable
              , javaLocalDeleteTargetRoot = Just targetRoot
              , javaLocalDeleteMessage = "Java runtime bundle was not found"
              }
        else
          ( do
              removeDirectoryRecursive targetRoot
              pure
                JavaRuntimeLocalDeleteResponse
                  { javaLocalDeleteDeleted = True
                  , javaLocalDeleteResponsePath = javaExecutable
                  , javaLocalDeleteTargetRoot = Just targetRoot
                  , javaLocalDeleteMessage = "Java runtime bundle deleted"
                  }
          )
            `catch` \(err :: SomeException) ->
              pure
                JavaRuntimeLocalDeleteResponse
                  { javaLocalDeleteDeleted = False
                  , javaLocalDeleteResponsePath = javaExecutable
                  , javaLocalDeleteTargetRoot = Just targetRoot
                  , javaLocalDeleteMessage = Text.pack ("Java runtime delete failed: " <> show err)
                  }

safeJavaRuntimeDeleteTarget :: FilePath -> Maybe FilePath
safeJavaRuntimeDeleteTarget path = do
  let normalized = normalise path
      suffix = "Contents" </> "Home" </> "bin" </> "java"
      bundleRoot =
        takeDirectory
          (takeDirectory (takeDirectory (takeDirectory normalized)))
      bundleName = map toLower (takeFileName bundleRoot)
  guard (suffix `isSuffixOf` normalized)
  guard ("JavaVirtualMachines" `isInfixOf` normalized)
  guard (".jdk" `isSuffixOf` bundleName || ".jre" `isSuffixOf` bundleName)
  pure bundleRoot

uniquePaths :: [FilePath] -> [FilePath]
uniquePaths =
  nubBy (\lhs rhs -> normalizePath lhs == normalizePath rhs)
    . filter (not . null)
    . map trimString

normalizePath :: FilePath -> FilePath
normalizePath =
  map toLower

firstUsefulLine :: String -> Text
firstUsefulLine =
  fromMaybe "" . listToMaybe . filter isUseful . map (Text.strip . Text.pack) . lines
  where
    isUseful line =
      not (Text.null line)
        && line /= "Property settings:"
        && not (" = " `Text.isInfixOf` line)

javaRuntimeSummary :: ExitCode -> Text -> Maybe Text -> Maybe Text -> Maybe Text -> Text
javaRuntimeSummary exitCode rawOutput version vendor architecture =
  case version of
    Just value ->
      Text.intercalate " · " $
        ["Java " <> value]
          <> maybe [] (\item -> [item]) vendor
          <> maybe [] (\item -> [item]) architecture
    Nothing ->
      let fallback = firstUsefulLine (Text.unpack rawOutput)
       in if Text.null fallback
            then if exitCode == ExitSuccess then "Java available" else "Java unavailable"
            else fallback

executablePermission :: FilePath -> IO (Maybe Bool)
executablePermission path = do
  resolved <-
    if '/' `elem` path
      then pure (Just path)
      else findExecutable path
  case resolved of
    Nothing -> pure Nothing
    Just executablePath -> do
      exists <- doesFileExist executablePath
      if not exists
        then pure Nothing
        else Just . executable <$> getPermissions executablePath

parseJavaProperty :: Text -> Text -> Maybe Text
parseJavaProperty key output =
  listToMaybe
    [ Text.strip (Text.drop (Text.length marker) stripped)
    | line <- Text.lines output
    , let stripped = Text.strip line
          marker = key <> " ="
    , marker `Text.isPrefixOf` stripped
    ]

parseJavaVersion :: Text -> Maybe Text
parseJavaVersion =
  parseJavaProperty "java.version"

versionFromSummary :: Text -> Maybe Text
versionFromSummary summary =
  case Text.breakOn "\"" summary of
    (_, remainder)
      | Text.null remainder -> Nothing
      | otherwise ->
          let afterOpen = Text.drop 1 remainder
              value = Text.takeWhile (/= '"') afterOpen
           in if Text.null value then Nothing else Just value

javaMajorVersion :: Text -> Maybe Int
javaMajorVersion version =
  case Text.splitOn "." (Text.dropWhile (not . isDigit) version) of
    "1" : major : _ -> readIntText major
    major : _ -> readIntText major
    [] -> Nothing

readIntText :: Text -> Maybe Int
readIntText value =
  case reads (Text.unpack (Text.takeWhile isDigit value)) of
    (parsed, _) : _ -> Just parsed
    [] -> Nothing
