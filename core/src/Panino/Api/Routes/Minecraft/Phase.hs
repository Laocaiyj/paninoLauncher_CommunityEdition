{-# LANGUAGE OverloadedStrings #-}

module Panino.Api.Routes.Minecraft.Phase
  ( MinecraftTaskPhase(..)
  , ProgressPhase
  , fallbackProgressPhase
  , installProgressPhases
  , launchRepairProgressPhases
  , minecraftTaskPhaseId
  , progressPhaseId
  , progressPhaseTitle
  ) where

import Data.Text (Text)
import Panino.Api.Types
  ( TaskPhaseId
  )

data MinecraftTaskPhase
  = MinecraftPhasePrepare
  | MinecraftPhaseMinecraft
  | MinecraftPhaseLoader
  | MinecraftPhaseContent
  | MinecraftPhaseVerify
  | MinecraftPhaseLaunch
  | MinecraftPhaseDownload
  | MinecraftPhaseInstall
  deriving (Eq, Ord, Show)

data ProgressPhase = ProgressPhase MinecraftTaskPhase Text
  deriving (Eq, Show)

minecraftTaskPhaseId :: MinecraftTaskPhase -> TaskPhaseId
minecraftTaskPhaseId phase =
  case phase of
    MinecraftPhasePrepare -> "prepare"
    MinecraftPhaseMinecraft -> "minecraft"
    MinecraftPhaseLoader -> "loader"
    MinecraftPhaseContent -> "content"
    MinecraftPhaseVerify -> "verify"
    MinecraftPhaseLaunch -> "launch"
    MinecraftPhaseDownload -> "download"
    MinecraftPhaseInstall -> "install"

progressPhaseId :: ProgressPhase -> TaskPhaseId
progressPhaseId (ProgressPhase phase _) =
  minecraftTaskPhaseId phase

progressPhaseTitle :: ProgressPhase -> Text
progressPhaseTitle (ProgressPhase _ title) =
  title

installProgressPhases :: [ProgressPhase]
installProgressPhases =
  [ ProgressPhase MinecraftPhasePrepare "Prepare install plan"
  , ProgressPhase MinecraftPhaseMinecraft "Download Minecraft files"
  , ProgressPhase MinecraftPhaseLoader "Install loader files"
  , ProgressPhase MinecraftPhaseContent "Download companion content"
  , ProgressPhase MinecraftPhaseVerify "Verify instance"
  ]

launchRepairProgressPhases :: [ProgressPhase]
launchRepairProgressPhases =
  [ ProgressPhase MinecraftPhaseMinecraft "Repair Minecraft files"
  , ProgressPhase MinecraftPhaseLoader "Repair loader files"
  , ProgressPhase MinecraftPhaseContent "Repair companion content"
  , ProgressPhase MinecraftPhaseVerify "Verify launch files"
  ]

fallbackProgressPhase :: ProgressPhase
fallbackProgressPhase =
  ProgressPhase MinecraftPhaseDownload "Downloading files"
