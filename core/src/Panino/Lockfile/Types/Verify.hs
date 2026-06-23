{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Types.Verify
  ( LockfileVerifyIssue(..)
  , LockfileVerifyResponse(..)
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.Text (Text)
import Panino.Install.Plan.Types (TypedInstallPlan)

data LockfileVerifyIssue = LockfileVerifyIssue
  { verifyIssueKind :: Text
  , verifyIssuePackageId :: Maybe Text
  , verifyIssueTargetPath :: Maybe FilePath
  , verifyIssueExpectedSha1 :: Maybe Text
  , verifyIssueActualSha1 :: Maybe Text
  , verifyIssueMessage :: Text
  } deriving (Eq, Show)

instance ToJSON LockfileVerifyIssue where
  toJSON issue =
    object
      [ "kind" .= verifyIssueKind issue
      , "packageId" .= verifyIssuePackageId issue
      , "targetPath" .= verifyIssueTargetPath issue
      , "expectedSha1" .= verifyIssueExpectedSha1 issue
      , "actualSha1" .= verifyIssueActualSha1 issue
      , "message" .= verifyIssueMessage issue
      ]

data LockfileVerifyResponse = LockfileVerifyResponse
  { verifyResponseStatus :: Text
  , verifyResponseFingerprint :: Maybe Text
  , verifyResponseMissingFiles :: [LockfileVerifyIssue]
  , verifyResponseHashMismatches :: [LockfileVerifyIssue]
  , verifyResponseExtraFiles :: [LockfileVerifyIssue]
  , verifyResponseManualFiles :: [LockfileVerifyIssue]
  , verifyResponseJavaMismatch :: [LockfileVerifyIssue]
  , verifyResponseLoaderMismatch :: [LockfileVerifyIssue]
  , verifyResponseLockfileDrift :: [LockfileVerifyIssue]
  , verifyResponseRepairPlan :: Maybe TypedInstallPlan
  } deriving (Eq, Show)

instance ToJSON LockfileVerifyResponse where
  toJSON response =
    object
      [ "status" .= verifyResponseStatus response
      , "fingerprint" .= verifyResponseFingerprint response
      , "missingFiles" .= verifyResponseMissingFiles response
      , "hashMismatches" .= verifyResponseHashMismatches response
      , "extraFiles" .= verifyResponseExtraFiles response
      , "manualFiles" .= verifyResponseManualFiles response
      , "javaMismatch" .= verifyResponseJavaMismatch response
      , "loaderMismatch" .= verifyResponseLoaderMismatch response
      , "lockfileDrift" .= verifyResponseLockfileDrift response
      , "repairPlan" .= verifyResponseRepairPlan response
      ]
