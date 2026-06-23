{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Solver.Conflicts
  ( conflictBlockedReason
  , detectConflicts
  , detectPackageBlockedReasons
  ) where

import Data.List
  ( groupBy
  , sortOn
  )
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( catMaybes
  , fromMaybe
  , isJust
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.CoreLogic.Determinism
  ( stableSortPackages
  , stableTextSet
  )
import Panino.Diagnostics.Classify (diagnosticFromBlockedReason)
import Panino.Lockfile.Normalize
  ( javaMajorFromPolicy
  , normalizeLoader
  , targetPathSafe
  )
import Panino.Lockfile.Types
  ( LockfileSolveRequest(..)
  , PackageConstraint(..)
  , PackageCoordinate(..)
  , ResolvedPackage(..)
  , SolverConflict(..)
  )
import System.FilePath (normalise)

detectConflicts :: LockfileSolveRequest -> [ResolvedPackage] -> [PackageConstraint] -> [SolverConflict]
detectConflicts request packages constraints =
  stableSortPackages solverConflictId $
    pathHashConflicts packages
      <> projectReleaseConflicts packages
      <> duplicateModConflicts packages
      <> compatibilityConflicts request packages
      <> dependencyConflicts packages constraints
      <> targetDirectoryConflicts packages

detectPackageBlockedReasons :: [ResolvedPackage] -> [Text]
detectPackageBlockedReasons packages =
  concatMap packageBlocked packages
  where
    packageBlocked package =
      let source = coordinateSource (resolvedPackageCoordinate package)
          hasTarget = isJust (resolvedPackageTargetPath package)
          hasSha1 = Map.member "sha1" (resolvedPackageHashes package)
          hasUrl = not (null (resolvedPackageDownloadUrls package))
          manualSource = source `elem` ["manual", "local"]
       in [ "unsafe_target_path:" <> resolvedPackageId package
          | maybe False (not . targetPathSafe) (resolvedPackageTargetPath package)
          ]
            <> [ "solver_source_unavailable:" <> resolvedPackageId package
               | hasTarget && not manualSource && not hasUrl
               ]
            <> [ "solver_hash_missing:" <> resolvedPackageId package
               | hasTarget && hasUrl && not hasSha1
               ]

pathHashConflicts :: [ResolvedPackage] -> [SolverConflict]
pathHashConflicts packages =
  [ solverConflict
      "solver_conflict"
      ("path-hash-" <> Text.pack (show index))
      "Target path conflict"
      ("Different hashes are locked for " <> Text.pack targetPath)
      (map resolvedPackageId grouped)
      [targetPath]
  | (index, grouped) <- zip [(1 :: Int)..] (groupOn (fromMaybe "" . resolvedPackageTargetPath) packages)
  , let targetPath = fromMaybe "" (resolvedPackageTargetPath (head grouped))
  , not (null targetPath)
  , distinctSha1 grouped > 1
  ]

projectReleaseConflicts :: [ResolvedPackage] -> [SolverConflict]
projectReleaseConflicts packages =
  [ solverConflict
      "solver_conflict"
      ("project-release-" <> Text.pack (show index))
      "Project version conflict"
      ("Multiple releases are selected for project " <> projectKey)
      (map resolvedPackageId grouped)
      (mapMaybe resolvedPackageTargetPath grouped)
  | (index, grouped) <- zip [(1 :: Int)..] (groupOn projectKeyFor packages)
  , let projectKey = projectKeyFor (head grouped)
  , not (Text.null projectKey)
  , length (stableTextSet (mapMaybe (coordinateVersionId . resolvedPackageCoordinate) grouped)) > 1
  ]

duplicateModConflicts :: [ResolvedPackage] -> [SolverConflict]
duplicateModConflicts packages =
  [ solverConflict
      "solver_duplicate_mod_id"
      ("duplicate-mod-" <> Text.pack (show index))
      "Duplicate mod"
      ("Multiple jars appear to provide " <> modKey)
      (map resolvedPackageId grouped)
      (mapMaybe resolvedPackageTargetPath grouped)
  | (index, grouped) <- zip [(1 :: Int)..] (groupOn modKeyFor (filter ((== "mod") . coordinateKind . resolvedPackageCoordinate) packages))
  , let modKey = modKeyFor (head grouped)
  , not (Text.null modKey)
  , length grouped > 1
  ]

compatibilityConflicts :: LockfileSolveRequest -> [ResolvedPackage] -> [SolverConflict]
compatibilityConflicts request packages =
  concatMap packageCompatibility packages
  where
    packageCompatibility package =
      [ solverConflict
          "solver_no_candidate"
          ("minecraft-version-" <> resolvedPackageId package)
          "Minecraft version mismatch"
          (resolvedPackageDisplayName package <> " does not support Minecraft " <> minecraftVersion)
          [resolvedPackageId package]
          (maybe [] (: []) (resolvedPackageTargetPath package))
      | Just minecraftVersion <- [solveRequestMinecraftVersion request]
      , not (null (resolvedPackageGameVersions package))
      , minecraftVersion `notElem` resolvedPackageGameVersions package
      ]
        <> [ solverConflict
              "solver_no_candidate"
              ("loader-" <> resolvedPackageId package)
              "Loader mismatch"
              (resolvedPackageDisplayName package <> " does not support loader " <> loader)
              [resolvedPackageId package]
              (maybe [] (: []) (resolvedPackageTargetPath package))
           | Just loader <- [normalizeLoader <$> solveRequestLoader request]
           , not (null (resolvedPackageLoaders package))
           , loader `notElem` resolvedPackageLoaders package
           ]
        <> [ solverConflict
              "solver_no_candidate"
              ("java-major-" <> resolvedPackageId package)
              "Java version mismatch"
              (resolvedPackageDisplayName package <> " requires Java " <> Text.pack (show requiredMajor) <> ", but the solve request is fixed to Java " <> Text.pack (show selectedMajor))
              [resolvedPackageId package]
              (maybe [] (: []) (resolvedPackageTargetPath package))
           | Just selectedMajor <- [javaMajorFromPolicy (solveRequestJavaPolicy request)]
           , Just requiredMajor <- [resolvedPackageJavaMajor package]
           , selectedMajor < requiredMajor
           ]

dependencyConflicts :: [ResolvedPackage] -> [PackageConstraint] -> [SolverConflict]
dependencyConflicts packages constraints =
  [ solverConflict
      "solver_conflict"
      ("incompatible-" <> constraintId constraint)
      "Incompatible dependency"
      (constraintReason constraint)
      (catMaybes [constraintSourcePackage constraint, constraintTargetPackageId constraint])
      []
  | constraint <- constraints
  , constraintRelation constraint `elem` ["incompatible", "conflicts"]
  , maybe False (`elem` selectedIds) (constraintSourcePackage constraint)
  , maybe False (`elem` selectedIds) (constraintTargetPackageId constraint)
  ]
  where
    selectedIds = map resolvedPackageId packages

targetDirectoryConflicts :: [ResolvedPackage] -> [SolverConflict]
targetDirectoryConflicts packages =
  concatMap checkPackage packages
  where
    checkPackage package =
      case resolvedPackageTargetPath package of
        Nothing -> []
        Just targetPath
          | coordinateKind (resolvedPackageCoordinate package) == "resourcePack" && not ("resourcepacks/" `isPrefixPath` targetPath) ->
              [wrongDir package "resourcepacks"]
          | coordinateKind (resolvedPackageCoordinate package) == "shaderPack" && not ("shaderpacks/" `isPrefixPath` targetPath) ->
              [wrongDir package "shaderpacks"]
          | coordinateKind (resolvedPackageCoordinate package) == "mod" && not ("mods/" `isPrefixPath` targetPath) ->
              [wrongDir package "mods"]
          | otherwise -> []
    wrongDir package expected =
      solverConflict
        "solver_conflict"
        ("target-dir-" <> resolvedPackageId package)
        "Target directory mismatch"
        (resolvedPackageDisplayName package <> " must be installed under " <> expected)
        [resolvedPackageId package]
        (maybe [] (: []) (resolvedPackageTargetPath package))

solverConflict :: Text -> Text -> Text -> Text -> [Text] -> [FilePath] -> SolverConflict
solverConflict code conflictId title message packageIds filePaths =
  SolverConflict
    { solverConflictId = conflictId
    , solverConflictCode = code
    , solverConflictTitle = title
    , solverConflictMessage = message
    , solverConflictPackageIds = stableTextSet packageIds
    , solverConflictFilePaths = map Text.unpack (stableTextSet (map Text.pack filePaths))
    , solverConflictDiagnostic = Just (diagnosticFromBlockedReason "solve" "lockfile solver" (code <> ":" <> message))
    }

conflictBlockedReason :: SolverConflict -> Text
conflictBlockedReason conflict =
  solverConflictCode conflict <> ":" <> solverConflictId conflict

distinctSha1 :: [ResolvedPackage] -> Int
distinctSha1 =
  length . stableTextSet . mapMaybe (Map.lookup "sha1" . resolvedPackageHashes)

projectKeyFor :: ResolvedPackage -> Text
projectKeyFor package =
  Text.intercalate
    ":"
    [ coordinateSource (resolvedPackageCoordinate package)
    , fromMaybe "" (coordinateProjectId (resolvedPackageCoordinate package))
    ]

modKeyFor :: ResolvedPackage -> Text
modKeyFor package =
  Text.toLower $
    fromMaybe
      (resolvedPackageDisplayName package)
      (coordinateSlug (resolvedPackageCoordinate package))

groupOn :: Ord key => (value -> key) -> [value] -> [[value]]
groupOn selector =
  filter (not . null) . groupBy (\left right -> selector left == selector right) . sortOn selector

isPrefixPath :: FilePath -> FilePath -> Bool
isPrefixPath prefix path =
  Text.pack prefix `Text.isPrefixOf` Text.pack (normalise path)
