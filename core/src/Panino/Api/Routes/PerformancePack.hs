{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.PerformancePack
  ( PerformancePackInstallRequest(..)
  , PerformancePackPlan(..)
  , ResolvedPerformancePackPlan(..)
  , buildPerformancePackPlan
  , performancePackInstallResponse
  , performancePackPlanResponse
  , performancePackRollbackResponse
  ) where

import Control.Applicative ((<|>))
import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( FromJSON(..)
  , ToJSON(..)
  , encode
  , eitherDecode
  , object
  , withObject
  , (.:)
  , (.:?)
  , (.=)
  )
import Data.Aeson.Types ((.!=))
import qualified Data.ByteString.Lazy as BL
import Data.List (find)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Data.Time.Clock (getCurrentTime)
import Network.HTTP.Types
  ( status200
  , status202
  , status400
  )
import Network.Wai
  ( Request
  , Response
  )
import Panino.Api.Params (decodeBody)
import Panino.Api.Response (jsonResponse)
import Panino.Api.Routes.Tasks
  ( startTaskWithGameDirContext
  , taskIsCancelled
  )
import Panino.Api.Server.State (ServerState(..))
import Panino.Api.Types
  ( DownloadRuntimeOptions(..)
  , TaskAccepted(..)
  , TaskSnapshot
  )
import Panino.Content.Online
  ( contentProject
  , contentSearch
  )
import Panino.Content.Online.Types
  ( ContentProjectRequest(..)
  , ContentProjectResponse(..)
  , ContentSearchRequest(..)
  , OnlineFile(..)
  , OnlineProject(..)
  , OnlineRelease(..)
  , OnlineSearchPage(..)
  )
import Panino.Download.Manager
  ( DownloadJob(..)
  , DownloadOptions
  , DownloadSummary(..)
  , downloadOptionsWithOverrides
  , runDownloadJobsWithOptionsAndProgressAndCancel
  )
import Panino.CoreLogic.Determinism
  ( stableFingerprint
  , stableSortPackages
  )
import qualified Panino.Install.Plan.Types as Plan
import Panino.Minecraft.Layout
  ( MinecraftLayout(..)
  , mkLayout
  )
import Panino.Minecraft.LoaderInstall
  ( ResolvedModrinthMod(..)
  , modrinthDownloadJob
  , resolveModrinthProject
  )
import Panino.Performance.Pack
  ( PerformanceModEntry(..)
  , PerformancePackRecommendation(..)
  , performanceModFileNames
  , recommendPerformancePack
  )
import System.Directory
  ( createDirectoryIfMissing
  , doesFileExist
  , removeFile
  )
import System.FilePath
  ( takeDirectory
  , takeFileName
  , (</>)
  )

data PerformancePackInstallRequest = PerformancePackInstallRequest
  { packInstallGameDir :: FilePath
  , packInstallMinecraftVersion :: Text
  , packInstallLoader :: Text
  , packInstallIncludeOptional :: Bool
  , packInstallDownload :: DownloadRuntimeOptions
  , packInstallSource :: Text
  , packInstallCurseForgeAPIKey :: Maybe Text
  } deriving (Eq, Show)

instance FromJSON PerformancePackInstallRequest where
  parseJSON =
    withObject "PerformancePackInstallRequest" $ \obj ->
      PerformancePackInstallRequest
        <$> obj .: "gameDir"
        <*> obj .: "minecraftVersion"
        <*> obj .: "loader"
        <*> obj .:? "includeOptional" .!= False
        <*> obj .:? "download" .!= DownloadRuntimeOptions Nothing Nothing Nothing
        <*> obj .:? "source" .!= "modrinth"
        <*> obj .:? "curseForgeAPIKey"

data PerformancePackPlan = PerformancePackPlan
  { packPlanStatus :: Text
  , packPlanTitle :: Text
  , packPlanGameDir :: FilePath
  , packPlanLockfilePath :: FilePath
  , packPlanFiles :: [PerformancePackPlanFile]
  , packPlanBlockedReasons :: [Text]
  , packPlanSkippedReasons :: [Text]
  , packPlanTypedPlan :: Plan.TypedInstallPlan
  } deriving (Eq, Show)

instance ToJSON PerformancePackPlan where
  toJSON plan =
    object
      [ "status" .= packPlanStatus plan
      , "title" .= packPlanTitle plan
      , "gameDir" .= packPlanGameDir plan
      , "lockfilePath" .= packPlanLockfilePath plan
      , "files" .= packPlanFiles plan
      , "blockedReasons" .= packPlanBlockedReasons plan
      , "skippedReasons" .= packPlanSkippedReasons plan
      , "typedPlan" .= packPlanTypedPlan plan
      ]

data PerformancePackPlanFile = PerformancePackPlanFile
  { packPlanFileSource :: Text
  , packPlanFileProjectId :: Text
  , packPlanFileName :: FilePath
  , packPlanFileTargetPath :: FilePath
  , packPlanFileSha1 :: Maybe Text
  , packPlanFileSize :: Maybe Integer
  } deriving (Eq, Show)

instance ToJSON PerformancePackPlanFile where
  toJSON file =
    object
      [ "source" .= packPlanFileSource file
      , "projectId" .= packPlanFileProjectId file
      , "fileName" .= packPlanFileName file
      , "targetPath" .= packPlanFileTargetPath file
      , "sha1" .= packPlanFileSha1 file
      , "size" .= packPlanFileSize file
      ]

instance FromJSON PerformancePackPlanFile where
  parseJSON =
    withObject "PerformancePackPlanFile" $ \obj ->
      PerformancePackPlanFile
        <$> obj .:? "source" .!= "modrinth"
        <*> obj .: "projectId"
        <*> obj .: "fileName"
        <*> obj .: "targetPath"
        <*> obj .:? "sha1"
        <*> obj .:? "size"

data ResolvedPerformancePackPlan = ResolvedPerformancePackPlan
  { resolvedPerformancePlan :: PerformancePackPlan
  , resolvedPerformanceDownloads :: [ResolvedPerformanceDownload]
  } deriving (Eq, Show)

data ResolvedPerformanceDownload = ResolvedPerformanceDownload
  { resolvedPerformanceDownloadJob :: DownloadJob
  , resolvedPerformanceDownloadFile :: PerformancePackPlanFile
  } deriving (Eq, Show)

newtype PerformancePackLockfile = PerformancePackLockfile
  { performancePackLockfileFiles :: [PerformancePackPlanFile]
  } deriving (Eq, Show)

instance FromJSON PerformancePackLockfile where
  parseJSON =
    withObject "PerformancePackLockfile" $ \obj ->
      PerformancePackLockfile <$> obj .:? "files" .!= []

data PerformancePackRollbackRequest = PerformancePackRollbackRequest
  { packRollbackGameDir :: FilePath
  , packRollbackLockfilePath :: Maybe FilePath
  } deriving (Eq, Show)

instance FromJSON PerformancePackRollbackRequest where
  parseJSON =
    withObject "PerformancePackRollbackRequest" $ \obj ->
      PerformancePackRollbackRequest
        <$> obj .: "gameDir"
        <*> obj .:? "lockfilePath"

data PerformancePackRollbackResult = PerformancePackRollbackResult
  { packRollbackResultRolledBack :: Bool
  , packRollbackResultRemoved :: [FilePath]
  , packRollbackResultMissing :: [FilePath]
  , packRollbackResultSkipped :: [Text]
  , packRollbackResultLockfilePath :: FilePath
  } deriving (Eq, Show)

instance ToJSON PerformancePackRollbackResult where
  toJSON result =
    object
      [ "rolledBack" .= packRollbackResultRolledBack result
      , "removed" .= packRollbackResultRemoved result
      , "missing" .= packRollbackResultMissing result
      , "skipped" .= packRollbackResultSkipped result
      , "lockfilePath" .= packRollbackResultLockfilePath result
      ]

performancePackPlanResponse :: ServerState -> Request -> IO Response
performancePackPlanResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right installRequest -> do
      resolved <- buildPerformancePackPlan state installRequest
      pure (jsonResponse status200 (resolvedPerformancePlan resolved))

performancePackInstallResponse :: ServerState -> Request -> IO Response
performancePackInstallResponse state request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right installRequest -> do
      resolved <- buildPerformancePackPlan state installRequest
      let plan = resolvedPerformancePlan resolved
      if not (null (packPlanBlockedReasons plan))
        then
          pure $
            jsonResponse
              status400
              (object ["error" .= ("performance_pack_plan_blocked" :: Text), "plan" .= plan])
        else do
          task <-
            startTaskWithGameDirContext state "performance-pack-install" (packPlanTitle plan) (Just (packInstallGameDir installRequest)) $ \taskSnapshot ->
              runPerformancePackInstallTask state taskSnapshot installRequest resolved
          pure (jsonResponse status202 (TaskAccepted task))

performancePackRollbackResponse :: Request -> IO Response
performancePackRollbackResponse request = do
  decoded <- decodeBody request
  case decoded of
    Left err ->
      pure (jsonResponse status400 (object ["error" .= ("invalid_json" :: Text), "message" .= err]))
    Right rollbackRequest -> do
      let lockfilePath = fromMaybe (packRollbackGameDir rollbackRequest </> "downloads" </> "performance-pack-lock.json") (packRollbackLockfilePath rollbackRequest)
      lockfileResult <- try (BL.readFile lockfilePath)
      case lockfileResult of
        Left (err :: SomeException) ->
          pure $
            jsonResponse
              status400
              (object ["error" .= ("performance_pack_lockfile_missing" :: Text), "message" .= show err])
        Right contents ->
          case eitherDecode contents of
            Left err ->
              pure $
                jsonResponse
                  status400
                  (object ["error" .= ("performance_pack_lockfile_invalid" :: Text), "message" .= err])
            Right lockfile -> do
              result <- rollbackPerformancePackFiles rollbackRequest lockfilePath lockfile
              pure (jsonResponse status200 result)

buildPerformancePackPlan :: ServerState -> PerformancePackInstallRequest -> IO ResolvedPerformancePackPlan
buildPerformancePackPlan state request = do
  layout <- mkLayout (Just (packInstallGameDir request))
  modFiles <- performanceModFileNames (Just (packInstallGameDir request))
  let recommendation =
        recommendPerformancePack
          (Just (packInstallLoader request))
          (Just (packInstallMinecraftVersion request))
          Nothing
          modFiles
      selected =
        [ entry
        | entry <- performanceRecommendationInstallable recommendation
        , packInstallIncludeOptional request || not (performanceModOptional entry)
        ]
      blocked =
        [ "Resolve OptiFine or renderer conflicts before installing a performance pack."
        | not (null (performanceRecommendationConflicts recommendation))
        ]
          <> sourceBlockedReasons request
      skipped = performanceRecommendationSkippedReasons recommendation
  resolvedDownloads <- fmap concat . sequence $
    [ resolvePerformanceEntry state layout request entry
    | entry <- selected
    , null blocked
    ]
  let downloads = dedupeDownloads resolvedDownloads
      jobs = map resolvedPerformanceDownloadJob downloads
      files = map resolvedPerformanceDownloadFile downloads
      blockedReasons = blocked <> ["No compatible performance pack files found." | null jobs && null blocked]
      typedPlan = performancePackTypedPlan request downloads blockedReasons skipped
      plan =
        PerformancePackPlan
          { packPlanStatus = if null blockedReasons then "ready" else "blocked"
          , packPlanTitle = "Apple Silicon performance pack"
          , packPlanGameDir = packInstallGameDir request
          , packPlanLockfilePath = performancePackLockfilePath layout
          , packPlanFiles = files
          , packPlanBlockedReasons = blockedReasons
          , packPlanSkippedReasons = skipped
          , packPlanTypedPlan = typedPlan
          }
  pure (ResolvedPerformancePackPlan plan downloads)

performancePackTypedPlan :: PerformancePackInstallRequest -> [ResolvedPerformanceDownload] -> [Text] -> [Text] -> Plan.TypedInstallPlan
performancePackTypedPlan request downloads blockedReasons skipped =
  Plan.finalizeTypedInstallPlan
    Plan.TypedInstallPlan
      { Plan.typedPlanId = ""
      , Plan.typedPlanFingerprint = ""
      , Plan.typedPlanKind = "performancePack"
      , Plan.typedPlanTitle = "Apple Silicon performance pack"
      , Plan.typedPlanTargetGameDir = Just (packInstallGameDir request)
      , Plan.typedPlanSource = Just (packInstallSource request)
      , Plan.typedPlanStatus = ""
      , Plan.typedPlanSummary = Plan.InstallPlanSummary 0 0 0 0 0 Nothing
      , Plan.typedPlanNodes =
          map performancePackNode (stableSortPackages performanceDownloadKey downloads)
      , Plan.typedPlanEdges = []
      , Plan.typedPlanWarnings = skipped
      , Plan.typedPlanBlockedReasons = blockedReasons
      , Plan.typedPlanDiagnostics = []
      , Plan.typedPlanRollbackPolicy = "lockfile"
      }

performancePackNode :: ResolvedPerformanceDownload -> Plan.InstallPlanNode
performancePackNode download =
  Plan.InstallPlanNode
    { Plan.installNodeId = "performance-pack-file-" <> Text.take 16 (stableFingerprint (object ["download" .= performanceDownloadKey download]))
    , Plan.installNodeKind = "mod"
    , Plan.installNodeAction = "download"
    , Plan.installNodePhase = "files"
    , Plan.installNodeLabel = Text.pack (packPlanFileName file)
    , Plan.installNodeTargetPath = Just (jobTargetPath job)
    , Plan.installNodeSourceUrls = [Text.pack (jobUrl job)]
    , Plan.installNodeSha1 = jobSha1 job
    , Plan.installNodeSize = jobSize job
    , Plan.installNodeRequired = True
    , Plan.installNodeDependsOn = []
    , Plan.installNodeVerifications =
        [ Plan.InstallVerification "targetInsideGameDir" "pending" Nothing
        , Plan.InstallVerification "hashKnown" (if jobSha1 job == Nothing then "warning" else "ok") Nothing
        ]
    , Plan.installNodeRollback =
        Plan.InstallPlanRollbackAction
          { Plan.installRollbackAction = "removeCreatedFile"
          , Plan.installRollbackTargetPath = Just (jobTargetPath job)
          , Plan.installRollbackBackupPath = Nothing
          , Plan.installRollbackReason = Nothing
          }
    , Plan.installNodeBlockedReason = Nothing
    , Plan.installNodeDiagnostics = []
    }
  where
    job = resolvedPerformanceDownloadJob download
    file = resolvedPerformanceDownloadFile download

sourceBlockedReasons :: PerformancePackInstallRequest -> [Text]
sourceBlockedReasons request =
  case normalizedPackSource request of
    "modrinth" -> []
    "curseforge" ->
      [ "CurseForge matching requires a personal API key in Settings."
      | maybe True Text.null (Text.strip <$> packInstallCurseForgeAPIKey request)
      ]
    source -> ["Unsupported performance pack source: " <> source]

resolvePerformanceEntry :: ServerState -> MinecraftLayout -> PerformancePackInstallRequest -> PerformanceModEntry -> IO [ResolvedPerformanceDownload]
resolvePerformanceEntry state layout request entry =
  case normalizedPackSource request of
    "curseforge" -> resolveCurseForgeProject state layout request entry
    _ -> resolveModrinthPerformanceProject state layout request entry

resolveModrinthPerformanceProject :: ServerState -> MinecraftLayout -> PerformancePackInstallRequest -> PerformanceModEntry -> IO [ResolvedPerformanceDownload]
resolveModrinthPerformanceProject state layout request entry = do
  result <-
    try $
      resolveModrinthProject
        (stateHttpManager state)
        (packInstallMinecraftVersion request)
        (packInstallLoader request)
        []
        (performanceModId entry)
  pure $ case result of
    Right resolved -> map (resolvedDownloadFromModrinth layout) resolved
    Left (_ :: SomeException) -> []

resolvedDownloadFromModrinth :: MinecraftLayout -> ResolvedModrinthMod -> ResolvedPerformanceDownload
resolvedDownloadFromModrinth layout resolved =
  let job = modrinthDownloadJob layout resolved
      planFile =
        PerformancePackPlanFile
          { packPlanFileSource = "modrinth"
          , packPlanFileProjectId = resolvedModrinthProject resolved
          , packPlanFileName = jobLabel job
          , packPlanFileTargetPath = jobTargetPath job
          , packPlanFileSha1 = jobSha1 job
          , packPlanFileSize = fromIntegral <$> jobSize job
          }
   in ResolvedPerformanceDownload job planFile

resolveCurseForgeProject :: ServerState -> MinecraftLayout -> PerformancePackInstallRequest -> PerformanceModEntry -> IO [ResolvedPerformanceDownload]
resolveCurseForgeProject state layout request entry = do
  result <- try $ do
    page <- contentSearch (stateHttpManager state) (performancePackSearchRequest request entry)
    project <- maybe (fail ("curseforge_project_not_found: " <> Text.unpack (performanceModTitle entry))) pure (selectCurseForgeProject entry page)
    response <-
      contentProject
        (stateHttpManager state)
        ContentProjectRequest
          { contentProjectSource = "curseForge"
          , contentProjectId = projectId project
          , contentProjectQuery = performancePackSearchRequest request entry
          , contentProjectCurseForgeApiKey = packInstallCurseForgeAPIKey request
          }
    release <- maybe (fail ("curseforge_release_not_found: " <> Text.unpack (projectTitle project))) pure (contentProjectResponseRecommendedRelease response <|> listToMaybe (contentProjectResponseReleases response))
    file <- maybe (fail ("curseforge_file_not_found: " <> Text.unpack (releaseVersionName release))) pure (preferredPerformanceOnlineFile release)
    downloadUrl <- maybe (fail ("curseforge_file_download_missing: " <> Text.unpack (fileName file))) pure (fileDownloadUrl file)
    let safeFileName = takeFileName (Text.unpack (fileName file))
        job =
          DownloadJob
            { jobLabel = Text.unpack (projectTitle project <> " " <> fileName file)
            , jobUrl = Text.unpack downloadUrl
            , jobTargetPath = minecraftRoot layout </> "mods" </> safeFileName
            , jobSha1 = Map.lookup "sha1" (fileHashes file)
            , jobSize = Just (fileSizeBytes file)
            }
        planFile =
          PerformancePackPlanFile
            { packPlanFileSource = "curseForge"
            , packPlanFileProjectId = projectId project
            , packPlanFileName = safeFileName
            , packPlanFileTargetPath = jobTargetPath job
            , packPlanFileSha1 = jobSha1 job
            , packPlanFileSize = fromIntegral <$> jobSize job
            }
    pure [ResolvedPerformanceDownload job planFile]
  pure $ case result of
    Right resolved -> resolved
    Left (_ :: SomeException) -> []

performancePackSearchRequest :: PerformancePackInstallRequest -> PerformanceModEntry -> ContentSearchRequest
performancePackSearchRequest request entry =
  ContentSearchRequest
    { contentSearchSource = "curseForge"
    , contentSearchText = performanceModTitle entry
    , contentSearchProjectTypes = ["mod"]
    , contentSearchCategories = []
    , contentSearchGameVersion = Just (packInstallMinecraftVersion request)
    , contentSearchLoaders = [packInstallLoader request]
    , contentSearchSort = "downloads"
    , contentSearchOffset = 0
    , contentSearchLimit = 10
    , contentSearchCurseForgeApiKey = packInstallCurseForgeAPIKey request
    , contentSearchPrefetch = False
    }

selectCurseForgeProject :: PerformanceModEntry -> OnlineSearchPage -> Maybe OnlineProject
selectCurseForgeProject entry page =
  find exactMatch (pageProjects page) <|> listToMaybe (pageProjects page)
  where
    wanted = normalizeLookupText (performanceModId entry)
    wantedTitle = normalizeLookupText (performanceModTitle entry)
    exactMatch project =
      normalizeLookupText (projectId project) == wanted
        || maybe False ((== wanted) . normalizeLookupText) (projectSlug project)
        || normalizeLookupText (projectTitle project) == wantedTitle

preferredPerformanceOnlineFile :: OnlineRelease -> Maybe OnlineFile
preferredPerformanceOnlineFile release =
  find filePrimary (releaseFiles release) <|> listToMaybe (releaseFiles release)

runPerformancePackInstallTask :: ServerState -> TaskSnapshot -> PerformancePackInstallRequest -> ResolvedPerformancePackPlan -> IO Text
runPerformancePackInstallTask state task request resolved = do
  let plan = resolvedPerformancePlan resolved
      jobs = map resolvedPerformanceDownloadJob (resolvedPerformanceDownloads resolved)
  createDirectoryIfMissing True (packInstallGameDir request </> "mods")
  before <- traverse targetExisted jobs
  result <-
    try $
      runDownloadJobsWithOptionsAndProgressAndCancel
        (stateHttpManager state)
        (downloadOptionsFromRuntime (packInstallDownload request))
        (taskIsCancelled state task)
        jobs
        (\_ -> pure ())
  case result of
    Right summary -> do
      writePerformancePackLockfile plan
      pure
        ( "installed performance pack with "
            <> Text.pack (show (length jobs))
            <> " planned files and "
            <> Text.pack (show (totalCount summary))
            <> " checked files. Rollback record: "
            <> Text.pack (packPlanLockfilePath plan)
        )
    Left (err :: SomeException) -> do
      rollbackNewFiles before jobs
      fail ("performance pack install failed and new files were rolled back: " <> show err)

targetExisted :: DownloadJob -> IO (DownloadJob, Bool)
targetExisted job =
  do
    exists <- doesFileExist (jobTargetPath job)
    pure (job, exists)

rollbackNewFiles :: [(DownloadJob, Bool)] -> [DownloadJob] -> IO ()
rollbackNewFiles before _ =
  mapM_ removeIfNew before
  where
    removeIfNew (job, existedBefore) =
      if existedBefore
        then pure ()
        else do
          result <- try (removeFile (jobTargetPath job))
          case result of
            Right () -> pure ()
            Left (_ :: SomeException) -> pure ()

writePerformancePackLockfile :: PerformancePackPlan -> IO ()
writePerformancePackLockfile plan = do
  now <- getCurrentTime
  createDirectoryIfMissing True (takeDirectory (packPlanLockfilePath plan))
  BL.writeFile
    (packPlanLockfilePath plan)
    ( encode $
        object
          [ "installedAt" .= now
          , "title" .= packPlanTitle plan
          , "files" .= packPlanFiles plan
          , "rollback" .= ("Remove the listed files or restore from backups if a future installer created them." :: Text)
          ]
    )

performancePackLockfilePath :: MinecraftLayout -> FilePath
performancePackLockfilePath layout =
  minecraftRoot layout </> "downloads" </> "performance-pack-lock.json"

dedupeDownloads :: [ResolvedPerformanceDownload] -> [ResolvedPerformanceDownload]
dedupeDownloads =
  foldr addDownload [] . stableSortPackages performanceDownloadKey
  where
    addDownload download existing
      | any ((== jobTargetPath (resolvedPerformanceDownloadJob download)) . jobTargetPath . resolvedPerformanceDownloadJob) existing = existing
      | otherwise = download : existing

performanceDownloadKey :: ResolvedPerformanceDownload -> Text
performanceDownloadKey download =
  Text.intercalate
    "|"
    [ packPlanFileSource file
    , packPlanFileProjectId file
    , Text.pack (packPlanFileName file)
    , Text.pack (packPlanFileTargetPath file)
    , fromMaybe "" (packPlanFileSha1 file)
    , Text.pack (jobUrl job)
    ]
  where
    job = resolvedPerformanceDownloadJob download
    file = resolvedPerformanceDownloadFile download

downloadOptionsFromRuntime :: DownloadRuntimeOptions -> DownloadOptions
downloadOptionsFromRuntime options =
  downloadOptionsWithOverrides (downloadRuntimeConcurrency options) (downloadRuntimeRetryCount options)

rollbackPerformancePackFiles :: PerformancePackRollbackRequest -> FilePath -> PerformancePackLockfile -> IO PerformancePackRollbackResult
rollbackPerformancePackFiles request lockfilePath lockfile = do
  outcomes <- traverse (rollbackPerformancePackFile request) (performancePackLockfileFiles lockfile)
  let removed = [path | RollbackRemoved path <- outcomes]
      missing = [path | RollbackMissing path <- outcomes]
      skipped = [reason | RollbackSkipped reason <- outcomes]
      rolledBack = not (null removed) && null skipped
  pure
    PerformancePackRollbackResult
      { packRollbackResultRolledBack = rolledBack
      , packRollbackResultRemoved = removed
      , packRollbackResultMissing = missing
      , packRollbackResultSkipped = skipped
      , packRollbackResultLockfilePath = lockfilePath
      }

data RollbackOutcome
  = RollbackRemoved FilePath
  | RollbackMissing FilePath
  | RollbackSkipped Text
  deriving (Eq, Show)

rollbackPerformancePackFile :: PerformancePackRollbackRequest -> PerformancePackPlanFile -> IO RollbackOutcome
rollbackPerformancePackFile request file =
  if not (isSafePerformancePackTarget (packRollbackGameDir request) targetPath)
    then pure (RollbackSkipped ("Skipped non-mods path: " <> Text.pack targetPath))
    else do
      exists <- doesFileExist targetPath
      if not exists
        then pure (RollbackMissing targetPath)
        else do
          result <- try (removeFile targetPath)
          pure $ case result of
            Right () -> RollbackRemoved targetPath
            Left (err :: SomeException) -> RollbackSkipped ("Could not remove " <> Text.pack targetPath <> ": " <> Text.pack (show err))
  where
    targetPath = packPlanFileTargetPath file

isSafePerformancePackTarget :: FilePath -> FilePath -> Bool
isSafePerformancePackTarget gameDir targetPath =
  takeDirectory targetPath == gameDir </> "mods"

normalizedPackSource :: PerformancePackInstallRequest -> Text
normalizedPackSource =
  normalizeLookupText . packInstallSource

normalizeLookupText :: Text -> Text
normalizeLookupText =
  Text.toLower . Text.filter (/= ' ') . Text.replace "-" "" . Text.replace "_" "" . Text.strip
