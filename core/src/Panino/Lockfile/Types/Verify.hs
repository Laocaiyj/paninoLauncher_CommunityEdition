{-# LANGUAGE OverloadedStrings #-}

module Panino.Lockfile.Types.Verify
  ( LockfileVerifyIssue(..)
  , LockfileVerifyIssueKind(..)
  , LockfileVerifyResponse(..)
  , LockfileVerifyStatus(..)
  , lockfileVerifyIssueKindFromText
  , lockfileVerifyIssueKindText
  , lockfileVerifyStatusFromText
  , lockfileVerifyStatusText
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.String (IsString(..))
import Data.Text (Text)
import qualified Data.Text as Text
import Panino.Core.WireText
  ( WireText(..)
  , toWireTextJSON
  )
import Panino.Install.Plan.Types (TypedInstallPlan)

data LockfileVerifyIssueKind
  = VerifyIssueMissingFile
  | VerifyIssueHashMismatch
  | VerifyIssueExtraFile
  | VerifyIssueManualFile
  | VerifyIssueLockfileDrift
  | VerifyIssueJavaMismatch
  | VerifyIssueLoaderMismatch
  | VerifyIssueOther Text
  deriving (Eq, Show)

instance IsString LockfileVerifyIssueKind where
  fromString =
    lockfileVerifyIssueKindFromText . Text.pack

lockfileVerifyIssueKindFromText :: Text -> LockfileVerifyIssueKind
lockfileVerifyIssueKindFromText =
  parseWireText

lockfileVerifyIssueKindText :: LockfileVerifyIssueKind -> Text
lockfileVerifyIssueKindText =
  wireText

instance WireText LockfileVerifyIssueKind where
  parseWireText kind
    | kind == "missingFile" = VerifyIssueMissingFile
    | kind == "hashMismatch" = VerifyIssueHashMismatch
    | kind == "extraFile" = VerifyIssueExtraFile
    | kind == "manualFile" = VerifyIssueManualFile
    | kind == "lockfileDrift" = VerifyIssueLockfileDrift
    | kind == "javaMismatch" = VerifyIssueJavaMismatch
    | kind == "loaderMismatch" = VerifyIssueLoaderMismatch
    | otherwise = VerifyIssueOther kind

  wireText kind =
    case kind of
      VerifyIssueMissingFile -> "missingFile"
      VerifyIssueHashMismatch -> "hashMismatch"
      VerifyIssueExtraFile -> "extraFile"
      VerifyIssueManualFile -> "manualFile"
      VerifyIssueLockfileDrift -> "lockfileDrift"
      VerifyIssueJavaMismatch -> "javaMismatch"
      VerifyIssueLoaderMismatch -> "loaderMismatch"
      VerifyIssueOther rawKind -> rawKind

instance ToJSON LockfileVerifyIssueKind where
  toJSON =
    toWireTextJSON

data LockfileVerifyIssue = LockfileVerifyIssue
  { verifyIssueKind :: LockfileVerifyIssueKind
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

data LockfileVerifyStatus
  = LockfileStatusLocked
  | LockfileStatusDrifted
  | LockfileStatusOther Text
  deriving (Eq, Show)

instance IsString LockfileVerifyStatus where
  fromString =
    lockfileVerifyStatusFromText . Text.pack

lockfileVerifyStatusFromText :: Text -> LockfileVerifyStatus
lockfileVerifyStatusFromText =
  parseWireText

lockfileVerifyStatusText :: LockfileVerifyStatus -> Text
lockfileVerifyStatusText =
  wireText

instance WireText LockfileVerifyStatus where
  parseWireText status
    | status == "locked" = LockfileStatusLocked
    | status == "drifted" = LockfileStatusDrifted
    | otherwise = LockfileStatusOther status

  wireText status =
    case status of
      LockfileStatusLocked -> "locked"
      LockfileStatusDrifted -> "drifted"
      LockfileStatusOther rawStatus -> rawStatus

instance ToJSON LockfileVerifyStatus where
  toJSON =
    toWireTextJSON

data LockfileVerifyResponse = LockfileVerifyResponse
  { verifyResponseStatus :: LockfileVerifyStatus
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
