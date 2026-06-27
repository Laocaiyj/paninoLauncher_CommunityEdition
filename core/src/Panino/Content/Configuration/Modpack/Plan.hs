{-# LANGUAGE OverloadedStrings #-}

module Panino.Content.Configuration.Modpack.Plan
  ( isOverrideArchiveEntry
  , isOverrideArchiveEntryWithPrefix
  , modpackOverrideConflicts
  , modpackPlanSkeleton
  , modpackStagingPath
  , safeRelativePath
  , serverPackIndicators
  , serverPackWarnings
  , stableTextSetCompat
  , unsafePlanTargetReasons
  ) where

import Data.Aeson
  ( object
  , (.=)
  )
import Control.Monad (filterM)
import Data.List (sort)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Content.Configuration.Modpack.Manifest
  ( ModpackPlanFile(..)
  , modpackFileKey
  )
import Panino.CoreLogic.Determinism
  ( stableFingerprint
  , stableSortOnText
  , stableSortPackages
  , stableTextSet
  )
import qualified Panino.Install.Plan.Types as Plan
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  )
import System.FilePath
  ( isRelative
  , normalise
  , splitDirectories
  , (</>)
  )

modpackPlanSkeleton :: Text -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe FilePath -> [ModpackPlanFile] -> [Text] -> [Text] -> [Text] -> [Text] -> Plan.TypedInstallPlan
modpackPlanSkeleton source name minecraftVersion loader loaderVersion targetGameDir files overrides overrideConflicts warnings blockedReasons =
  Plan.finalizeTypedInstallPlan
    Plan.TypedInstallPlan
      { Plan.typedPlanId = ""
      , Plan.typedPlanFingerprint = ""
      , Plan.typedPlanKind = "modpack"
      , Plan.typedPlanTitle = fromMaybe "Imported Modpack" name
      , Plan.typedPlanTargetGameDir = Plan.typedPlanTargetGameDirFromPath targetGameDir
      , Plan.typedPlanSource = Just source
      , Plan.typedPlanStatus = ""
      , Plan.typedPlanSummary = Plan.InstallPlanSummary 0 0 0 0 0 Nothing
      , Plan.typedPlanNodes = directoryNodes <> dependencyNodes <> fileNodes <> overrideNodes <> lockNodes
      , Plan.typedPlanEdges = dependencyEdges <> lockEdges
      , Plan.typedPlanWarnings = warnings
      , Plan.typedPlanBlockedReasons = blockedReasons
      , Plan.typedPlanDiagnostics = []
      , Plan.typedPlanRollbackPolicy = "staging"
      }
  where
    stagingId = "modpack-staging"
    minecraftId = "modpack-minecraft"
    loaderId = "modpack-loader"
    lockId = "modpack-lockfile"
    dependencyIds = stagingId : minecraftId : [loaderId | loader /= Nothing]
    directoryNodes =
      [ Plan.InstallPlanNode
          { Plan.installNodeId = stagingId
          , Plan.installNodeKind = "directory"
          , Plan.installNodeAction = "write"
          , Plan.installNodePhase = "staging"
          , Plan.installNodeLabel = "Create staging directory"
          , Plan.installNodeTargetPath = modpackStagingPath <$> targetGameDir
          , Plan.installNodeSourceUrls = []
          , Plan.installNodeSha1 = Nothing
          , Plan.installNodeSize = Nothing
          , Plan.installNodeRequired = True
          , Plan.installNodeDependsOn = []
          , Plan.installNodeVerifications = [Plan.InstallVerification "targetInsideGameDir" "pending" Nothing]
          , Plan.installNodeRollback =
              Plan.InstallPlanRollbackAction
                { Plan.installRollbackAction = "deleteEmptyDirectory"
                , Plan.installRollbackTargetPath = modpackStagingPath <$> targetGameDir
                , Plan.installRollbackBackupPath = Nothing
                , Plan.installRollbackReason = Nothing
                }
          , Plan.installNodeBlockedReason = firstText ["target_game_dir_required" | targetGameDir == Nothing]
          , Plan.installNodeDiagnostics = []
          }
      ]
    dependencyNodes =
      [ Plan.InstallPlanNode
          { Plan.installNodeId = minecraftId
          , Plan.installNodeKind = "minecraftVersion"
          , Plan.installNodeAction = "verify"
          , Plan.installNodePhase = "metadata"
          , Plan.installNodeLabel = fromMaybe "Minecraft version" minecraftVersion
          , Plan.installNodeTargetPath = targetGameDir
          , Plan.installNodeSourceUrls = []
          , Plan.installNodeSha1 = Nothing
          , Plan.installNodeSize = Nothing
          , Plan.installNodeRequired = True
          , Plan.installNodeDependsOn = [stagingId]
          , Plan.installNodeVerifications =
              [ Plan.InstallVerification "minecraftVersionCompatible" (if minecraftVersion == Nothing then "error" else "ok") minecraftVersion
              ]
          , Plan.installNodeRollback = noModpackRollback "Minecraft version is a prerequisite, not a direct write."
          , Plan.installNodeBlockedReason = firstText ["minecraft_version_missing" | minecraftVersion == Nothing]
          , Plan.installNodeDiagnostics = []
          }
      ]
        <> [ Plan.InstallPlanNode
              { Plan.installNodeId = loaderId
              , Plan.installNodeKind = "loaderProfile"
              , Plan.installNodeAction = "verify"
              , Plan.installNodePhase = "loader"
              , Plan.installNodeLabel = fromMaybe "Mod loader" loader
              , Plan.installNodeTargetPath = targetGameDir
              , Plan.installNodeSourceUrls = []
              , Plan.installNodeSha1 = Nothing
              , Plan.installNodeSize = Nothing
              , Plan.installNodeRequired = True
              , Plan.installNodeDependsOn = [minecraftId]
              , Plan.installNodeVerifications =
                  [ Plan.InstallVerification "loaderCompatible" (if loader == Nothing then "warning" else "ok") loaderVersion
                  ]
              , Plan.installNodeRollback = noModpackRollback "Loader profile is a prerequisite, not a direct write."
              , Plan.installNodeBlockedReason = Nothing
              , Plan.installNodeDiagnostics = []
              }
           | loader /= Nothing
           ]
    sortedFiles = stableSortPackages modpackFileKey files
    sortedOverrides = stableSortOnText id overrides
    sortedOverrideConflicts = stableTextSet overrideConflicts
    fileNodes =
      [ modpackFileNode file dependencyIds
      | file <- sortedFiles
      ]
    overrideNodes =
      [ modpackOverrideNode override dependencyIds (override `elem` sortedOverrideConflicts)
      | override <- sortedOverrides
      ]
    lockNodes =
      [ Plan.InstallPlanNode
          { Plan.installNodeId = lockId
          , Plan.installNodeKind = "rollbackMarker"
          , Plan.installNodeAction = "write"
          , Plan.installNodePhase = "commit"
          , Plan.installNodeLabel = "Write modpack-install-lock.json"
          , Plan.installNodeTargetPath = (</> "modpack-install-lock.json") <$> targetGameDir
          , Plan.installNodeSourceUrls = []
          , Plan.installNodeSha1 = Nothing
          , Plan.installNodeSize = Nothing
          , Plan.installNodeRequired = True
          , Plan.installNodeDependsOn = map Plan.installNodeId (fileNodes <> overrideNodes)
          , Plan.installNodeVerifications = [Plan.InstallVerification "backupWritable" "pending" Nothing]
          , Plan.installNodeRollback = noModpackRollback "Lockfile is written after staging commit."
          , Plan.installNodeBlockedReason = Nothing
          , Plan.installNodeDiagnostics = []
          }
      ]
    dependencyEdges =
      [ Plan.InstallPlanEdge dependencyId nodeId "requires" True
      | node <- fileNodes <> overrideNodes
      , nodeId <- [Plan.installNodeId node]
      , dependencyId <- Plan.installNodeDependsOn node
      ]
    lockEdges =
      [ Plan.InstallPlanEdge (Plan.installNodeId node) lockId "requires" True
      | node <- fileNodes <> overrideNodes
      ]

modpackFileNode :: ModpackPlanFile -> [Text] -> Plan.InstallPlanNode
modpackFileNode file dependencyIds =
  Plan.InstallPlanNode
    { Plan.installNodeId = "modpack-file-" <> Text.take 16 (stableFingerprint (object ["file" .= modpackFileKey file]))
    , Plan.installNodeKind = modpackNodeKindForPath (mrpackFilePath file)
    , Plan.installNodeAction = "download"
    , Plan.installNodePhase = "files"
    , Plan.installNodeLabel = mrpackFilePath file
    , Plan.installNodeTargetPath = Just (Text.unpack (mrpackFilePath file))
    , Plan.installNodeSourceUrls = Plan.installNodeSourceUrlsFromTexts (maybe [] (: []) (mrpackFileUrl file))
    , Plan.installNodeSha1 = Plan.installNodeSha1FromText (mrpackFileSha1 file)
    , Plan.installNodeSize = mrpackFileSize file
    , Plan.installNodeRequired = True
    , Plan.installNodeDependsOn = dependencyIds
    , Plan.installNodeVerifications =
        [ Plan.InstallVerification "urlAllowed" (if maybe False isAllowedModpackUrl (mrpackFileUrl file) then "ok" else "error") Nothing
        , Plan.InstallVerification "hashKnown" (if mrpackFileSha1 file == Nothing then "error" else "ok") Nothing
        , Plan.InstallVerification "sizeKnown" (if mrpackFileSize file == Nothing then "warning" else "ok") Nothing
        ]
    , Plan.installNodeRollback =
        Plan.InstallPlanRollbackAction
          { Plan.installRollbackAction = "removeCreatedFile"
          , Plan.installRollbackTargetPath = Just (Text.unpack (mrpackFilePath file))
          , Plan.installRollbackBackupPath = Nothing
          , Plan.installRollbackReason = Nothing
          }
    , Plan.installNodeBlockedReason =
        if mrpackFileUrl file == Nothing || mrpackFileSha1 file == Nothing
          then Just "modpack_file_download_unresolved"
          else Nothing
    , Plan.installNodeDiagnostics = []
    }

modpackOverrideNode :: Text -> [Text] -> Bool -> Plan.InstallPlanNode
modpackOverrideNode override dependencyIds hasConflict =
  Plan.InstallPlanNode
    { Plan.installNodeId = "modpack-override-" <> Text.take 16 (stableFingerprint (object ["override" .= override]))
    , Plan.installNodeKind = "overrideFile"
    , Plan.installNodeAction = if hasConflict then "replace" else "write"
    , Plan.installNodePhase = "overrides"
    , Plan.installNodeLabel = override
    , Plan.installNodeTargetPath = Just (Text.unpack (dropOverridePrefix override))
    , Plan.installNodeSourceUrls = []
    , Plan.installNodeSha1 = Nothing
    , Plan.installNodeSize = Nothing
    , Plan.installNodeRequired = True
    , Plan.installNodeDependsOn = dependencyIds
    , Plan.installNodeVerifications =
        [ Plan.InstallVerification "targetInsideGameDir" "pending" Nothing
        ]
          <> [ Plan.InstallVerification "backupWritable" "pending" (Just "override_conflict_replace")
             | hasConflict
             ]
    , Plan.installNodeRollback =
        Plan.InstallPlanRollbackAction
          { Plan.installRollbackAction = if hasConflict then "restoreBackup" else "removeCreatedFile"
          , Plan.installRollbackTargetPath = Just (Text.unpack (dropOverridePrefix override))
          , Plan.installRollbackBackupPath = if hasConflict then Just (Text.unpack (dropOverridePrefix override) <> ".panino-backup") else Nothing
          , Plan.installRollbackReason = Nothing
          }
    , Plan.installNodeBlockedReason = Nothing
    , Plan.installNodeDiagnostics = []
    }

modpackNodeKindForPath :: Text -> Text
modpackNodeKindForPath path
  | "mods/" `Text.isPrefixOf` path = "mod"
  | "resourcepacks/" `Text.isPrefixOf` path = "resourcePack"
  | "shaderpacks/" `Text.isPrefixOf` path = "shaderPack"
  | otherwise = "overrideFile"

dropOverridePrefix :: Text -> Text
dropOverridePrefix path =
  fromMaybe path (Text.stripPrefix "overrides/" path)

modpackOverrideConflicts :: Maybe FilePath -> [Text] -> IO [Text]
modpackOverrideConflicts Nothing _ =
  pure []
modpackOverrideConflicts (Just targetGameDir) overrides =
  stableSortOnText id <$> filterM hasConflict overrides
  where
    hasConflict override = do
      let target = targetGameDir </> Text.unpack (dropOverridePrefix override)
      fileExists <- doesFileExist target
      directoryExists <- doesDirectoryExist target
      pure (fileExists || directoryExists)

serverPackWarnings :: [Text] -> [Text]
serverPackWarnings indicators =
  [ "server_pack_detected:" <> Text.intercalate "," (take 5 indicators)
  | not (null indicators)
  ]

serverPackIndicators :: Maybe Text -> [Text] -> [Text]
serverPackIndicators overridePrefix names =
  stableTextSetCompat
    [ normalized
    | name <- names
    , candidate <- normalizeArchivePath name : strippedCandidates name
    , let normalized = candidate
    , isServerPackPath normalized
    ]
  where
    strippedCandidates name =
      case overridePrefix >>= (\prefix -> Text.stripPrefix (normalizeArchivePath prefix) (normalizeArchivePath name)) of
        Just stripped -> [stripped]
        Nothing -> []

isServerPackPath :: Text -> Bool
isServerPackPath path =
  path `elem` serverRootFiles
  where
    serverRootFiles =
      [ "server.properties"
      , "eula.txt"
      , "ops.json"
      , "whitelist.json"
      , "banned-ips.json"
      , "banned-players.json"
      , "start.sh"
      , "start.bat"
      , "run.sh"
      , "run.bat"
      , "server.jar"
      ]

normalizeArchivePath :: Text -> Text
normalizeArchivePath =
  Text.toLower . Text.replace "\\" "/"

isOverrideArchiveEntry :: Text -> Bool
isOverrideArchiveEntry =
  isOverrideArchiveEntryWithPrefix "overrides/"

isOverrideArchiveEntryWithPrefix :: Text -> Text -> Bool
isOverrideArchiveEntryWithPrefix prefix path =
  prefix `Text.isPrefixOf` path && not ("/" `Text.isSuffixOf` path)

isAllowedModpackUrl :: Text -> Bool
isAllowedModpackUrl value =
  "https://" `Text.isPrefixOf` Text.toLower value || "http://" `Text.isPrefixOf` Text.toLower value

noModpackRollback :: Text -> Plan.InstallPlanRollbackAction
noModpackRollback reason =
  Plan.InstallPlanRollbackAction
    { Plan.installRollbackAction = "noneWithReason"
    , Plan.installRollbackTargetPath = Nothing
    , Plan.installRollbackBackupPath = Nothing
    , Plan.installRollbackReason = Just reason
    }

firstText :: [Text] -> Maybe Text
firstText [] = Nothing
firstText (value:_) = Just value

modpackStagingPath :: FilePath -> FilePath
modpackStagingPath targetGameDir =
  targetGameDir <> ".panino-modpack-staging"

unsafePlanTargetReasons :: Plan.TypedInstallPlan -> [Text]
unsafePlanTargetReasons plan =
  [ "unsafe_target_path:" <> Plan.installNodeId node
  | node <- Plan.typedPlanNodes plan
  , Plan.installNodeActionIsDownloadLike (Plan.installNodeAction node)
      || Plan.installNodeActionIsWriteLike (Plan.installNodeAction node)
  , Plan.installNodeKind node `notElem` ["directory", "rollbackMarker"]
  , maybe True (not . safeRelativePath) (Plan.installNodeTargetPath node)
  ]

safeRelativePath :: FilePath -> Bool
safeRelativePath path =
  let normalized = normalise path
      originalParts = splitDirectories path
      normalizedParts = splitDirectories normalized
   in not (null path)
        && normalized /= "."
        && isRelative normalized
        && ".." `notElem` originalParts
        && ".." `notElem` normalizedParts

stableTextSetCompat :: [Text] -> [Text]
stableTextSetCompat =
  foldr insertSorted [] . sort
  where
    insertSorted value values
      | value `elem` values = values
      | otherwise = value : values
