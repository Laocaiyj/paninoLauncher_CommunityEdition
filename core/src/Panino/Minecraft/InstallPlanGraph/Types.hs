{-# LANGUAGE OverloadedStrings #-}

module Panino.Minecraft.InstallPlanGraph.Types
  ( InstallPlanGraph(..)
  , InstallPlanNode(..)
  ) where

import Data.Aeson
  ( ToJSON(..)
  , object
  , (.=)
  )
import Data.Int (Int64)
import Data.Text (Text)
import Panino.Core.Types
  ( Sha1
  , Url
  )
import qualified Panino.Install.Plan.Types as Plan

data InstallPlanGraph = InstallPlanGraph
  { installPlanGraphId :: Text
  , installPlanGraphKind :: Text
  , installPlanGraphLabel :: Text
  , installPlanGraphNodes :: [InstallPlanNode]
  , installPlanGraphWarnings :: [Text]
  , installPlanGraphBlockedReasons :: [Text]
  , installPlanGraphTypedPlan :: Plan.TypedInstallPlan
  } deriving (Eq, Show)

instance ToJSON InstallPlanGraph where
  toJSON =
    toJSON . installPlanGraphTypedPlan

data InstallPlanNode = InstallPlanNode
  { installPlanNodeId :: Text
  , installPlanNodeKind :: Text
  , installPlanNodeLabel :: Text
  , installPlanNodeTargetPath :: FilePath
  , installPlanNodeUrlCandidates :: [Url]
  , installPlanNodeSha1 :: Maybe Sha1
  , installPlanNodeSize :: Maybe Int64
  , installPlanNodeDependencies :: [Text]
  , installPlanNodePhase :: Text
  , installPlanNodeRequired :: Bool
  , installPlanNodeBlockedReason :: Maybe Text
  } deriving (Eq, Show)

instance ToJSON InstallPlanNode where
  toJSON node =
    object
      [ "id" .= installPlanNodeId node
      , "kind" .= installPlanNodeKind node
      , "label" .= installPlanNodeLabel node
      , "targetPath" .= installPlanNodeTargetPath node
      , "urlCandidates" .= installPlanNodeUrlCandidates node
      , "sha1" .= installPlanNodeSha1 node
      , "size" .= installPlanNodeSize node
      , "dependencies" .= installPlanNodeDependencies node
      , "phase" .= installPlanNodePhase node
      , "required" .= installPlanNodeRequired node
      , "blockedReason" .= installPlanNodeBlockedReason node
      ]
