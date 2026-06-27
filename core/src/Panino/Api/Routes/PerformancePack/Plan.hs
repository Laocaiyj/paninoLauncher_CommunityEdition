{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Api.Routes.PerformancePack.Plan
  ( buildPerformancePackPlan
  ) where

import Control.Applicative ((<|>))
import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( object
  , (.=)
  )
import Data.List (find)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  , listToMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Api.Routes.PerformancePack.Types
  ( PerformancePackInstallRequest(..)
  , PerformancePackPlan(..)
  , PerformancePackPlanFile(..)
  , ResolvedPerformanceDownload(..)
  , ResolvedPerformancePackPlan(..)
  )
import Panino.Api.Server.State (ServerState(..))
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
import Panino.CoreLogic.Determinism
  ( stableFingerprint
  , stableSortPackages
  )
import Panino.Core.Types
  ( sha1FromText
  , sha1Text
  , urlFromText
  , urlText
  )
import Panino.Download.Manager (DownloadJob(..))
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
import System.FilePath
  ( takeFileName
  , (</>)
  )

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
    , Plan.installNodeSourceUrls = [urlText (jobUrl job)]
    , Plan.installNodeSha1 = sha1Text <$> jobSha1 job
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
          , packPlanFileSha1 = sha1Text <$> jobSha1 job
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
            , jobUrl = urlFromText downloadUrl
            , jobTargetPath = minecraftRoot layout </> "mods" </> safeFileName
            , jobSha1 = Map.lookup "sha1" (fileHashes file) >>= sha1FromText
            , jobSize = Just (fileSizeBytes file)
            }
        planFile =
          PerformancePackPlanFile
            { packPlanFileSource = "curseForge"
            , packPlanFileProjectId = projectId project
            , packPlanFileName = safeFileName
            , packPlanFileTargetPath = jobTargetPath job
            , packPlanFileSha1 = sha1Text <$> jobSha1 job
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
    , urlText (jobUrl job)
    ]
  where
    job = resolvedPerformanceDownloadJob download
    file = resolvedPerformanceDownloadFile download

normalizedPackSource :: PerformancePackInstallRequest -> Text
normalizedPackSource =
  normalizeLookupText . packInstallSource

normalizeLookupText :: Text -> Text
normalizeLookupText =
  Text.toLower . Text.filter (/= ' ') . Text.replace "-" "" . Text.replace "_" "" . Text.strip
