{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Minecraft.LoaderInstall.Shader
  ( ShaderInstallResult(..)
  , ShaderResolution(..)
  , emptyShaderInstallResult
  , installRequestedShader
  , modrinthDownloadJob
  , removeTrackedShaderInstallFiles
  , resolveShaderModrinthProject
  , validateRequestedShaderCompatibility
  ) where

import Control.Exception
  ( SomeException
  , catch
  , displayException
  , throwIO
  , try
  )
import Control.Monad (forM_)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Network.HTTP.Client (Manager)
import Panino.Core.Types
  ( sha1FromText
  , sha1Text
  , urlFromText
  )
import Panino.CoreLogic.Determinism (stableTextSet)
import Panino.Download.Manager
  ( DownloadJob(..)
  , DownloadOptions
  , DownloadProgress
  , DownloadSummary(..)
  , runDownloadJobsWithOptionsAndProgressAndCancel
  )
import Panino.Download.Transfer (throwIfCancelled)
import Panino.Minecraft.InstallPlanGraph
  ( InstallPlanGraph
  , dedupeInstallPlanJobs
  , downloadJobsInstallPlanGraph
  )
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  )
import Panino.Minecraft.LoaderInstall.Names (normalizeLoaderName)
import Panino.Minecraft.Modrinth
  ( ModrinthFile(..)
  , ResolvedModrinthMod(..)
  , resolveModrinthProject
  , resolveModrinthProjectWithVersion
  , safeFileName
  , stableResolvedModrinthMods
  )
import System.Directory
  ( createDirectoryIfMissing
  , removeFile
  )
import System.FilePath ((</>))

data ShaderInstallResult = ShaderInstallResult
  { shaderInstallSummary :: DownloadSummary
  , shaderInstallGraph :: Maybe InstallPlanGraph
  , shaderInstallFiles :: [DownloadJob]
  } deriving (Eq, Show)

data ShaderResolution = ShaderResolution
  { shaderResolutionProject :: Text
  , shaderResolutionVersion :: Text
  , shaderResolutionRequestedLoader :: Text
  , shaderResolutionResolvedLoader :: Text
  , shaderResolutionMods :: [ResolvedModrinthMod]
  } deriving (Eq, Show)

emptyShaderInstallResult :: ShaderInstallResult
emptyShaderInstallResult =
  ShaderInstallResult
    { shaderInstallSummary = emptyDownloadSummary
    , shaderInstallGraph = Nothing
    , shaderInstallFiles = []
    }

validateRequestedShaderCompatibility :: Maybe Text -> Maybe Text -> IO ()
validateRequestedShaderCompatibility maybeLoader maybeShader =
  case normalizeLoaderName <$> maybeShader of
    Nothing -> pure ()
    Just "none" -> pure ()
    Just "iris" ->
      requireShaderLoader "iris" ["fabric", "quilt"] maybeLoader
    Just "oculus" ->
      requireShaderLoader "oculus" ["forge", "neoforge"] maybeLoader
    Just "optifine" ->
      fail "manual_install_required: OptiFine cannot be installed automatically because it has no stable public download API; install it manually after creating a Vanilla instance"
    Just other ->
      fail ("unsupported shader loader: " <> Text.unpack other)

installRequestedShader :: Manager -> MinecraftLayout -> Text -> Maybe Text -> Maybe Text -> Maybe Text -> DownloadOptions -> IO Bool -> (DownloadProgress -> IO ()) -> IO ShaderInstallResult
installRequestedShader manager layout minecraftVersion maybeLoader maybeShader maybeShaderVersion downloadOptions isCancelled onProgress =
  case normalizeLoaderName <$> maybeShader of
    Nothing -> pure emptyShaderInstallResult
    Just "none" -> pure emptyShaderInstallResult
    Just "iris" -> installModrinthShader manager layout minecraftVersion (fromMaybe "fabric" (normalizeLoaderName <$> maybeLoader)) "iris" maybeShaderVersion downloadOptions isCancelled onProgress
    Just "oculus" -> installModrinthShader manager layout minecraftVersion (fromMaybe "forge" (normalizeLoaderName <$> maybeLoader)) "oculus" maybeShaderVersion downloadOptions isCancelled onProgress
    Just "optifine" -> fail "manual_install_required: OptiFine cannot be installed automatically because it has no stable public download API; install it manually after creating a Vanilla instance"
    Just other -> fail ("unsupported shader loader: " <> Text.unpack other)

resolveShaderModrinthProject :: Manager -> Text -> Text -> Text -> Maybe Text -> IO ShaderResolution
resolveShaderModrinthProject manager minecraftVersion loader project maybeShaderVersion =
  case shaderReleaseLoaderCandidates project loader of
    [] ->
      fail ("shader_loader_incompatible:" <> Text.unpack project <> " " <> Text.unpack loader)
    candidates ->
      tryCandidates candidates
  where
    tryCandidates [] =
      fail
        ( "shader_release_not_found: no Modrinth "
            <> Text.unpack project
            <> " release found for Minecraft "
            <> Text.unpack minecraftVersion
            <> " and loader "
            <> Text.unpack loader
        )
    tryCandidates (candidate:rest) = do
      outcome <- try (resolveModrinthProjectWithVersion manager minecraftVersion candidate [] project maybeShaderVersion) :: IO (Either SomeException [ResolvedModrinthMod])
      case outcome of
        Right resolved -> do
          let selectedVersion =
                fromMaybe
                  (fromMaybe project (listToMaybe [versionId | ResolvedModrinthMod itemProject versionId _ <- resolved, itemProject == project]))
                  maybeShaderVersion
          pure
            ShaderResolution
              { shaderResolutionProject = project
              , shaderResolutionVersion = selectedVersion
              , shaderResolutionRequestedLoader = loader
              , shaderResolutionResolvedLoader = candidate
              , shaderResolutionMods = resolved
              }
        Left err
          | shaderReleaseNotFound err && not (null rest) ->
              tryCandidates rest
          | otherwise ->
              throwIO err

modrinthDownloadJob :: MinecraftLayout -> ResolvedModrinthMod -> DownloadJob
modrinthDownloadJob layout resolved =
  DownloadJob
    { jobLabel = "modrinth mod " <> Text.unpack (resolvedModrinthProject resolved)
    , jobUrl = urlFromText (modrinthFileUrl selectedFile)
    , jobTargetPath = minecraftRoot layout </> "mods" </> Text.unpack (safeFileName (modrinthFileName selectedFile))
    , jobSha1 = Map.lookup "sha1" (modrinthFileHashes selectedFile) >>= sha1FromText
    , jobSize = modrinthFileSize selectedFile
    }
  where
    selectedFile = resolvedModrinthFile resolved

removeTrackedShaderInstallFiles :: MinecraftLayout -> IO ()
removeTrackedShaderInstallFiles layout = do
  previous <- readShaderInstallLogFiles layout
  forM_ previous $ \(_, previousFile) ->
    removeShaderFile layout previousFile

installModrinthShader :: Manager -> MinecraftLayout -> Text -> Text -> Text -> Maybe Text -> DownloadOptions -> IO Bool -> (DownloadProgress -> IO ()) -> IO ShaderInstallResult
installModrinthShader manager layout minecraftVersion loader project maybeShaderVersion downloadOptions isCancelled onProgress = do
  throwIfCancelled isCancelled
  resolution <- resolveShaderModrinthProject manager minecraftVersion loader project maybeShaderVersion
  throwIfCancelled isCancelled
  companionMods <- resolveFabricApiCompanion manager minecraftVersion (shaderResolutionResolvedLoader resolution) (map resolvedModrinthProject (shaderResolutionMods resolution))
  throwIfCancelled isCancelled
  createDirectoryIfMissing True (minecraftRoot layout </> "mods")
  let resolved = stableResolvedModrinthMods (shaderResolutionMods resolution <> companionMods)
  let rawJobs = map (modrinthDownloadJob layout) resolved
  validateShaderDownloadJobs rawJobs
  let jobs = dedupeInstallPlanJobs rawJobs
      graph = downloadJobsInstallPlanGraph "minecraft-companion" project jobs
  summary <-
    runDownloadJobsWithOptionsAndProgressAndCancel
      manager
      downloadOptions
      isCancelled
      jobs
      onProgress
  removeStaleShaderFiles layout resolved
  writeShaderInstallLog layout minecraftVersion resolution resolved
  pure
    ShaderInstallResult
      { shaderInstallSummary = summary
      , shaderInstallGraph = Just graph
      , shaderInstallFiles = jobs
      }

requireShaderLoader :: Text -> [Text] -> Maybe Text -> IO ()
requireShaderLoader shader supportedLoaders maybeLoader =
  case normalizeLoaderName <$> maybeLoader of
    Nothing ->
      fail ("shader_loader_incompatible:" <> Text.unpack shader <> " requires loader")
    Just loader
      | loader `elem` supportedLoaders -> pure ()
      | otherwise -> fail ("shader_loader_incompatible:" <> Text.unpack shader <> " " <> Text.unpack loader)

resolveFabricApiCompanion :: Manager -> Text -> Text -> [Text] -> IO [ResolvedModrinthMod]
resolveFabricApiCompanion manager minecraftVersion loader visited
  | normalizeLoaderName loader == "fabric" =
      resolveModrinthProject manager minecraftVersion loader visited "fabric-api"
  | otherwise = pure []

shaderReleaseLoaderCandidates :: Text -> Text -> [Text]
shaderReleaseLoaderCandidates project loader =
  case (normalizeLoaderName project, normalizeLoaderName loader) of
    ("iris", "fabric") -> ["fabric"]
    ("iris", "quilt") -> ["quilt", "fabric"]
    ("oculus", "forge") -> ["forge"]
    ("oculus", "neoforge") -> ["neoforge", "forge"]
    _ -> []

shaderReleaseNotFound :: SomeException -> Bool
shaderReleaseNotFound =
  Text.isInfixOf "shader_release_not_found" . Text.pack . displayException

validateShaderDownloadJobs :: [DownloadJob] -> IO ()
validateShaderDownloadJobs jobs =
  case concatMap pathConflict (Map.toList jobsByTarget) of
    [] -> pure ()
    conflict:_ -> fail (Text.unpack conflict)
  where
    jobsByTarget =
      Map.fromListWith (<>) [(jobTargetPath job, [job]) | job <- jobs]
    pathConflict (targetPath, targetJobs)
      | length targetJobs <= 1 = []
      | length distinctSha1s > 1 =
          [ "shader_dependency_conflict: multiple downloads target "
              <> Text.pack targetPath
              <> " sha1="
              <> Text.intercalate "," distinctSha1s
          ]
      | otherwise = []
      where
        distinctSha1s = stableTextSet (map (maybe "missing" sha1Text . jobSha1) targetJobs)

emptyDownloadSummary :: DownloadSummary
emptyDownloadSummary =
  DownloadSummary
    { downloadedCount = 0
    , skippedCount = 0
    , totalCount = 0
    }

writeShaderInstallLog :: MinecraftLayout -> Text -> ShaderResolution -> [ResolvedModrinthMod] -> IO ()
writeShaderInstallLog layout minecraftVersion resolution resolved = do
  let directory = minecraftRoot layout </> "downloads"
  createDirectoryIfMissing True directory
  writeFile
    (directory </> "shader-install.log")
    ( unlines
        ( [ "minecraftVersion=" <> Text.unpack minecraftVersion
          , "loader=" <> Text.unpack (shaderResolutionResolvedLoader resolution)
          , "requestedLoader=" <> Text.unpack (shaderResolutionRequestedLoader resolution)
          , "shaderProject=" <> Text.unpack (shaderResolutionProject resolution)
          , "fallback="
              <> if shaderResolutionRequestedLoader resolution == shaderResolutionResolvedLoader resolution
                then "false"
                else "true"
          ]
            <> map resolvedLine resolved
        )
    )
  where
    resolvedLine item =
      Text.unpack (resolvedModrinthProject item)
        <> " file="
        <> Text.unpack (modrinthFileName (resolvedModrinthFile item))
        <> maybe "" ((" sha1=" <>) . Text.unpack) (Map.lookup "sha1" (modrinthFileHashes (resolvedModrinthFile item)))
        <> " url="
        <> Text.unpack (modrinthFileUrl (resolvedModrinthFile item))

removeStaleShaderFiles :: MinecraftLayout -> [ResolvedModrinthMod] -> IO ()
removeStaleShaderFiles layout resolved = do
  previous <- readShaderInstallLogFiles layout
  let selected =
        Map.fromList
          [ (resolvedModrinthProject item, modrinthFileName (resolvedModrinthFile item))
          | item <- resolved
          ]
  forM_ previous $ \(project, previousFile) ->
    case Map.lookup project selected of
      Just currentFile | currentFile /= previousFile ->
        removeShaderFile layout previousFile
      _ -> pure ()

readShaderInstallLogFiles :: MinecraftLayout -> IO [(Text, Text)]
readShaderInstallLogFiles layout = do
  result <- try (readFile (minecraftRoot layout </> "downloads" </> "shader-install.log")) :: IO (Either SomeException String)
  pure $ case result of
    Left _ -> []
    Right content -> foldr collect [] (lines content)
  where
    collect line acc =
      case parseShaderLogLine (Text.pack line) of
        Just item -> item : acc
        Nothing -> acc

parseShaderLogLine :: Text -> Maybe (Text, Text)
parseShaderLogLine line = do
  let (project, rest) = Text.breakOn " file=" line
      afterFile = Text.drop (Text.length (" file=" :: Text)) rest
      (fileName, _) = Text.breakOn " url=" afterFile
  if Text.null project || Text.null rest || Text.null fileName
    then Nothing
    else Just (project, fileName)

removeShaderFile :: MinecraftLayout -> Text -> IO ()
removeShaderFile layout fileName =
  removeFile (minecraftRoot layout </> "mods" </> Text.unpack (safeFileName fileName))
    `catch` ignoreRemoveError
  where
    ignoreRemoveError :: SomeException -> IO ()
    ignoreRemoveError _ = pure ()
