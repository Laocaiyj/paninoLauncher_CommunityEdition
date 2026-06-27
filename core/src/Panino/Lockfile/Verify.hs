{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Verify
  ( verifyIssueBlockedReason
  , verifyLockfile
  ) where

import Data.List (sort)
import qualified Data.Map.Strict as Map
import Data.Maybe
  ( fromMaybe
  , mapMaybe
  )
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.CoreLogic.Determinism
  ( stableSortPackages
  , stableTextSet
  )
import Panino.CoreLogic.Hashing (sha1File)
import Panino.Lockfile.Changeset (packageChange)
import Panino.Lockfile.Plan (buildLockfileTypedPlan)
import Panino.Lockfile.Types
  ( LockfileChangeset(..)
  , LockfileFile(..)
  , LockfileVerifyIssue(..)
  , LockfileVerifyResponse(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , emptyChangeset
  , lockfileFileKey
  , lockfileFileTargetPathFilePath
  , resolvedPackageKey
  , resolvedPackageTargetPathFilePath
  )
import System.Directory
  ( doesDirectoryExist
  , doesFileExist
  , listDirectory
  )
import System.FilePath
  ( takeDirectory
  , (</>)
  )

verifyLockfile :: FilePath -> PaninoLockfile -> IO LockfileVerifyResponse
verifyLockfile gameDir lockfile = do
  fileIssues <- traverse verifyFile (stableSortPackages lockfileFileKey (lockfileFiles lockfile))
  extraIssues <- extraFileIssues gameDir lockfile
  let missingIssues = stableSortPackages verifyIssueKey [issue | Left issue <- fileIssues, verifyIssueKind issue == "missingFile"]
      mismatchIssues = stableSortPackages verifyIssueKey [issue | Left issue <- fileIssues, verifyIssueKind issue == "hashMismatch"]
      manualIssues = manualFileIssues lockfile
      driftIssues =
        stableSortPackages verifyIssueKey $
        [ LockfileVerifyIssue
            { verifyIssueKind = "lockfileDrift"
            , verifyIssuePackageId = Nothing
            , verifyIssueTargetPath = Nothing
            , verifyIssueExpectedSha1 = Nothing
            , verifyIssueActualSha1 = Nothing
            , verifyIssueMessage = "Instance files do not match panino-lock.json."
            }
        | not (null missingIssues) || not (null mismatchIssues) || not (null extraIssues)
        ]
      repairPackages = packagesForIssues lockfile (missingIssues <> mismatchIssues)
      repairChangeset =
        emptyChangeset
          { changesetRepair =
              [ packageChange "repair" package Nothing "Repair missing or mismatched file from lockfile."
              | package <- repairPackages
              ]
          }
      repairPlan =
        if null repairPackages
          then Nothing
          else
            Just $
              buildLockfileTypedPlan
                gameDir
                repairPackages
                (lockfileConstraints lockfile)
                repairChangeset
                []
                []
                []
      status =
        if null missingIssues && null mismatchIssues && null extraIssues && null driftIssues
          then "locked"
          else "drifted"
  pure
    LockfileVerifyResponse
      { verifyResponseStatus = status
      , verifyResponseFingerprint = Just (lockfileFingerprint lockfile)
      , verifyResponseMissingFiles = missingIssues
      , verifyResponseHashMismatches = mismatchIssues
      , verifyResponseExtraFiles = extraIssues
      , verifyResponseManualFiles = manualIssues
      , verifyResponseJavaMismatch = []
      , verifyResponseLoaderMismatch = []
      , verifyResponseLockfileDrift = driftIssues
      , verifyResponseRepairPlan = repairPlan
      }
  where
    verifyFile file = do
      let relativeTarget = lockfileFileTargetPathFilePath file
          target = gameDir </> relativeTarget
          expectedSha1 = Map.lookup "sha1" (lockfileFileHashes file)
      exists <- doesFileExist target
      if not exists
        then
          pure $
            Left $
              LockfileVerifyIssue
                { verifyIssueKind = "missingFile"
                , verifyIssuePackageId = Just (lockfileFilePackageId file)
                , verifyIssueTargetPath = Just relativeTarget
                , verifyIssueExpectedSha1 = expectedSha1
                , verifyIssueActualSha1 = Nothing
                , verifyIssueMessage = "Lockfile-managed file is missing."
                }
        else do
          actualSha1 <- sha1File target
          if maybe False (/= actualSha1) expectedSha1
            then
              pure $
                Left $
                  LockfileVerifyIssue
                    { verifyIssueKind = "hashMismatch"
                    , verifyIssuePackageId = Just (lockfileFilePackageId file)
                    , verifyIssueTargetPath = Just relativeTarget
                    , verifyIssueExpectedSha1 = expectedSha1
                    , verifyIssueActualSha1 = Just actualSha1
                    , verifyIssueMessage = "Lockfile-managed file hash does not match."
                    }
            else pure (Right ())

manualFileIssues :: PaninoLockfile -> [LockfileVerifyIssue]
manualFileIssues lockfile =
  stableSortPackages verifyIssueKey $
  [ LockfileVerifyIssue
      { verifyIssueKind = "manualFile"
      , verifyIssuePackageId = Just (resolvedPackageId package)
      , verifyIssueTargetPath = resolvedPackageTargetPathFilePath package
      , verifyIssueExpectedSha1 = Map.lookup "sha1" (resolvedPackageHashes package)
      , verifyIssueActualSha1 = Nothing
      , verifyIssueMessage = "Manual or local file is tracked by the lockfile."
      }
  | package <- stableSortPackages resolvedPackageKey (lockfilePackages lockfile)
  , packageSource package `elem` ["manual", "local"]
  ]

extraFileIssues :: FilePath -> PaninoLockfile -> IO [LockfileVerifyIssue]
extraFileIssues gameDir lockfile = do
  let managedTargets = map lockfileFileTargetPathFilePath (lockfileFiles lockfile)
      dirs = stableTextSet (map (Text.pack . takeDirectory) managedTargets)
  found <- concat <$> traverse (listFilesUnder gameDir . Text.unpack) dirs
  pure $
    stableSortPackages verifyIssueKey $
    [ LockfileVerifyIssue
        { verifyIssueKind = "extraFile"
        , verifyIssuePackageId = Nothing
        , verifyIssueTargetPath = Just relativePath
        , verifyIssueExpectedSha1 = Nothing
        , verifyIssueActualSha1 = Nothing
        , verifyIssueMessage = "File exists beside lockfile-managed content but is not in the lockfile."
        }
    | relativePath <- found
    , relativePath `notElem` managedTargets
    ]

listFilesUnder :: FilePath -> FilePath -> IO [FilePath]
listFilesUnder gameDir relativeDir
  | null relativeDir || relativeDir == "." = pure []
  | otherwise = do
      let absoluteDir = gameDir </> relativeDir
      exists <- doesDirectoryExist absoluteDir
      if not exists
        then pure []
        else map (relativeDir </>) <$> listFilesRecursive absoluteDir

listFilesRecursive :: FilePath -> IO [FilePath]
listFilesRecursive dir = do
  entries <- sort <$> listDirectory dir
  fmap concat $
    traverse
      ( \entry -> do
          let path = dir </> entry
          isDir <- doesDirectoryExist path
          isFile <- doesFileExist path
          if isDir
            then map (entry </>) <$> listFilesRecursive path
            else pure [entry | isFile]
      )
      entries

packagesForIssues :: PaninoLockfile -> [LockfileVerifyIssue] -> [ResolvedPackage]
packagesForIssues lockfile issues =
  stableSortPackages resolvedPackageKey $
    [ package
    | package <- stableSortPackages resolvedPackageKey (lockfilePackages lockfile)
    , resolvedPackageId package `elem` issuePackageIds
    ]
  where
    issuePackageIds = mapMaybe verifyIssuePackageId issues

verifyIssueBlockedReason :: Text -> LockfileVerifyIssue -> Text
verifyIssueBlockedReason prefix issue =
  Text.intercalate
    ":"
    (prefix : filter (not . Text.null) [fromMaybe "" (verifyIssuePackageId issue), maybe "" Text.pack (verifyIssueTargetPath issue)])

verifyIssueKey :: LockfileVerifyIssue -> Text
verifyIssueKey issue =
  Text.intercalate
    "|"
    [ verifyIssueKind issue
    , fromMaybe "" (verifyIssuePackageId issue)
    , Text.pack (fromMaybe "" (verifyIssueTargetPath issue))
    , fromMaybe "" (verifyIssueExpectedSha1 issue)
    , fromMaybe "" (verifyIssueActualSha1 issue)
    , verifyIssueMessage issue
    ]

packageSource :: ResolvedPackage -> Text
packageSource =
  coordinateSource . resolvedPackageCoordinate
