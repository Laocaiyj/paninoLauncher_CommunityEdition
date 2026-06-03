{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Panino.Performance.Pack
  ( PerformanceModEntry(..)
  , PerformancePackRecommendation(..)
  , performanceModFileNames
  , recommendPerformancePack
  ) where

import Control.Exception
  ( SomeException
  , try
  )
import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.List (sortOn)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import qualified Data.Text as Text
import System.Directory
  ( doesDirectoryExist
  , listDirectory
  )
import System.FilePath
  ( takeExtension
  , (</>)
  )

data PerformancePackRecommendation = PerformancePackRecommendation
  { performanceRecommendationStatus :: Text
  , performanceRecommendationTitle :: Text
  , performanceRecommendationDetail :: Text
  , performanceRecommendationLoader :: Maybe Text
  , performanceRecommendationMinecraftVersion :: Maybe Text
  , performanceRecommendationInstallAutomatically :: Bool
  , performanceRecommendationInstallable :: [PerformanceModEntry]
  , performanceRecommendationExisting :: [PerformanceModEntry]
  , performanceRecommendationConflicts :: [PerformanceModEntry]
  , performanceRecommendationSkippedReasons :: [Text]
  } deriving (Eq, Show)

instance ToJSON PerformancePackRecommendation where
  toJSON recommendation =
    object
      [ "status" .= performanceRecommendationStatus recommendation
      , "title" .= performanceRecommendationTitle recommendation
      , "detail" .= performanceRecommendationDetail recommendation
      , "loader" .= performanceRecommendationLoader recommendation
      , "minecraftVersion" .= performanceRecommendationMinecraftVersion recommendation
      , "installAutomatically" .= performanceRecommendationInstallAutomatically recommendation
      , "installable" .= performanceRecommendationInstallable recommendation
      , "existing" .= performanceRecommendationExisting recommendation
      , "conflicts" .= performanceRecommendationConflicts recommendation
      , "skippedReasons" .= performanceRecommendationSkippedReasons recommendation
      ]

data PerformanceModEntry = PerformanceModEntry
  { performanceModId :: Text
  , performanceModTitle :: Text
  , performanceModRole :: Text
  , performanceModOptional :: Bool
  , performanceModStatus :: Text
  , performanceModReason :: Text
  } deriving (Eq, Show)

instance ToJSON PerformanceModEntry where
  toJSON entry =
    object
      [ "id" .= performanceModId entry
      , "title" .= performanceModTitle entry
      , "role" .= performanceModRole entry
      , "optional" .= performanceModOptional entry
      , "status" .= performanceModStatus entry
      , "reason" .= performanceModReason entry
      ]

recommendPerformancePack :: Maybe Text -> Maybe Text -> Maybe Int -> [Text] -> PerformancePackRecommendation
recommendPerformancePack loader minecraftVersion modCount modFiles =
  case normalizeLoader <$> loader of
    Just "fabric" -> recommendationFor "Fabric" fabricPack
    Just "quilt" -> recommendationFor "Quilt" fabricPack
    Just "forge" -> recommendationFor "Forge" forgePack
    Just "neoforge" -> recommendationFor "NeoForge" forgePack
    Just "vanilla" -> noLoaderRecommendation loader minecraftVersion modFiles
    Just value ->
      unsupportedRecommendation loader minecraftVersion ("No safe performance-pack recipe for loader " <> value <> ".")
    Nothing ->
      noLoaderRecommendation loader minecraftVersion modFiles
  where
    conflicts = conflictEntries modFiles
    recommendationFor loaderName pack =
      let existingEntries = markExisting pack modFiles
          installableEntries = markInstallable pack modFiles conflicts
          skipped = skippedReasons conflicts
          effectiveModCount = fromMaybe (length modFiles) modCount
          status =
            if not (null conflicts)
              then "needsReview"
              else if effectiveModCount >= 10 || not (null installableEntries)
                then "recommended"
                else "optional"
       in PerformancePackRecommendation
            { performanceRecommendationStatus = status
            , performanceRecommendationTitle = "Recommend " <> loaderName <> " smoother pack"
            , performanceRecommendationDetail =
                "Panino can show matched performance mods for this loader, but will not install them silently."
            , performanceRecommendationLoader = loader
            , performanceRecommendationMinecraftVersion = minecraftVersion
            , performanceRecommendationInstallAutomatically = False
            , performanceRecommendationInstallable = installableEntries
            , performanceRecommendationExisting = existingEntries
            , performanceRecommendationConflicts = conflicts
            , performanceRecommendationSkippedReasons = skipped
            }

performanceModFileNames :: Maybe FilePath -> IO [Text]
performanceModFileNames Nothing =
  pure []
performanceModFileNames (Just gameDir) = do
  let modsDir = gameDir </> "mods"
  exists <- doesDirectoryExist modsDir
  if not exists
    then pure []
    else do
      result <- try (sortOn id <$> listDirectory modsDir)
      pure $ case result of
        Right entries ->
          [ Text.pack entry
          | entry <- entries
          , takeExtension entry == ".jar"
          ]
        Left (_ :: SomeException) -> []

fabricPack :: [PerformanceModEntry]
fabricPack =
  [ modEntry "sodium" "Sodium" "renderer" False
  , modEntry "lithium" "Lithium" "game logic" False
  , modEntry "ferritecore" "FerriteCore" "memory" False
  , modEntry "immediatelyfast" "ImmediatelyFast" "UI and rendering" False
  , modEntry "entityculling" "EntityCulling" "entity rendering" False
  , modEntry "dynamicfps" "Dynamic FPS" "background load" False
  , modEntry "iris" "Iris" "shader support" True
  , modEntry "modmenu" "Mod Menu" "mod settings" True
  ]

forgePack :: [PerformanceModEntry]
forgePack =
  [ modEntry "embeddium" "Embeddium" "renderer" False
  , modEntry "modernfix" "ModernFix" "loading and memory" False
  , modEntry "ferritecore" "FerriteCore" "memory" False
  , modEntry "entityculling" "EntityCulling" "entity rendering" False
  , modEntry "immediatelyfast" "ImmediatelyFast" "UI and rendering" False
  , modEntry "oculus" "Oculus" "shader support" True
  ]

modEntry :: Text -> Text -> Text -> Bool -> PerformanceModEntry
modEntry modId title role optional =
  PerformanceModEntry
    { performanceModId = modId
    , performanceModTitle = title
    , performanceModRole = role
    , performanceModOptional = optional
    , performanceModStatus = "available"
    , performanceModReason = "Matches this loader family; exact file matching happens before install."
    }

markExisting :: [PerformanceModEntry] -> [Text] -> [PerformanceModEntry]
markExisting pack modFiles =
  [ entry
      { performanceModStatus = "existing"
      , performanceModReason = "A matching mod file already exists in the instance."
      }
  | entry <- pack
  , modExists entry modFiles
  ]

markInstallable :: [PerformanceModEntry] -> [Text] -> [PerformanceModEntry] -> [PerformanceModEntry]
markInstallable pack modFiles conflicts =
  [ entry
  | entry <- pack
  , not (modExists entry modFiles)
  , not (blocksInstall entry conflicts)
  ]

blocksInstall :: PerformanceModEntry -> [PerformanceModEntry] -> Bool
blocksInstall entry conflicts =
  performanceModId entry `elem` ["sodium", "embeddium", "iris", "oculus"] && not (null conflicts)

conflictEntries :: [Text] -> [PerformanceModEntry]
conflictEntries modFiles =
  [ PerformanceModEntry
      { performanceModId = "optifine"
      , performanceModTitle = "OptiFine"
      , performanceModRole = "legacy renderer"
      , performanceModOptional = False
      , performanceModStatus = "conflict"
      , performanceModReason = "OptiFine can conflict with modern loader performance packs; Panino will only show a compatibility warning."
      }
  | any (Text.isInfixOf "optifine" . normalizeFileName) modFiles
  ]

skippedReasons :: [PerformanceModEntry] -> [Text]
skippedReasons conflicts =
  [ "OptiFine detected; renderer and shader performance mods require manual review."
  | not (null conflicts)
  ]

noLoaderRecommendation :: Maybe Text -> Maybe Text -> [Text] -> PerformancePackRecommendation
noLoaderRecommendation loader minecraftVersion modFiles =
  PerformancePackRecommendation
    { performanceRecommendationStatus = "optional"
    , performanceRecommendationTitle = "Keep vanilla first"
    , performanceRecommendationDetail =
        "No mod loader is selected. Panino will not install a performance pack into a vanilla instance."
    , performanceRecommendationLoader = loader
    , performanceRecommendationMinecraftVersion = minecraftVersion
    , performanceRecommendationInstallAutomatically = False
    , performanceRecommendationInstallable = []
    , performanceRecommendationExisting = []
    , performanceRecommendationConflicts = conflictEntries modFiles
    , performanceRecommendationSkippedReasons =
        "Select Fabric, Quilt, Forge, or NeoForge before installing performance mods." : skippedReasons (conflictEntries modFiles)
    }

unsupportedRecommendation :: Maybe Text -> Maybe Text -> Text -> PerformancePackRecommendation
unsupportedRecommendation loader minecraftVersion reason =
  PerformancePackRecommendation
    { performanceRecommendationStatus = "unsupported"
    , performanceRecommendationTitle = "No automatic performance pack"
    , performanceRecommendationDetail = reason
    , performanceRecommendationLoader = loader
    , performanceRecommendationMinecraftVersion = minecraftVersion
    , performanceRecommendationInstallAutomatically = False
    , performanceRecommendationInstallable = []
    , performanceRecommendationExisting = []
    , performanceRecommendationConflicts = []
    , performanceRecommendationSkippedReasons = [reason]
    }

modExists :: PerformanceModEntry -> [Text] -> Bool
modExists entry modFiles =
  any (matchesEntry entry) modFiles

matchesEntry :: PerformanceModEntry -> Text -> Bool
matchesEntry entry fileName =
  let normalized = normalizeFileName fileName
      compactTitle = Text.filter (/= ' ') (Text.toLower (performanceModTitle entry))
   in Text.isInfixOf (performanceModId entry) normalized
        || Text.isInfixOf compactTitle normalized

normalizeLoader :: Text -> Text
normalizeLoader =
  Text.toLower . Text.strip

normalizeFileName :: Text -> Text
normalizeFileName =
  Text.toLower . Text.strip
