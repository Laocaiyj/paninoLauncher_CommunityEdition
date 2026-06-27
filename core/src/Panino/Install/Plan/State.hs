{-# LANGUAGE OverloadedStrings #-}

module Panino.Install.Plan.State
  ( BlockedInstallPlan
  , ExecutableInstallPlan
  , InstallPlanReadiness(..)
  , blockedInstallPlanReasons
  , blockedTypedPlan
  , classifyTypedInstallPlan
  , executableTypedPlan
  , requireExecutableInstallPlan
  ) where

import Data.Text (Text)
import Panino.CoreLogic.Determinism (stableTextSet)
import Panino.Install.Plan.Types
  ( InstallPlanStatus(..)
  , TypedInstallPlan(..)
  , finalizeTypedInstallPlan
  , installPlanStatusFromText
  , installPlanStatusText
  )

newtype ExecutableInstallPlan =
  ExecutableInstallPlan TypedInstallPlan
  deriving (Eq, Show)

data BlockedInstallPlan = BlockedInstallPlan
  { blockedTypedPlan :: TypedInstallPlan
  , blockedInstallPlanReasons :: [Text]
  } deriving (Eq, Show)

data InstallPlanReadiness
  = InstallPlanExecutable ExecutableInstallPlan
  | InstallPlanBlocked BlockedInstallPlan
  deriving (Eq, Show)

executableTypedPlan :: ExecutableInstallPlan -> TypedInstallPlan
executableTypedPlan (ExecutableInstallPlan plan) =
  plan

requireExecutableInstallPlan :: TypedInstallPlan -> Either BlockedInstallPlan ExecutableInstallPlan
requireExecutableInstallPlan plan =
  case classifyTypedInstallPlan plan of
    InstallPlanExecutable executable -> Right executable
    InstallPlanBlocked blocked -> Left blocked

classifyTypedInstallPlan :: TypedInstallPlan -> InstallPlanReadiness
classifyTypedInstallPlan plan =
  let finalized = finalizeTypedInstallPlan plan
      nonReadyReasons =
        case installPlanStatusFromText (typedPlanStatus finalized) of
          InstallStatusReady -> []
          status -> ["non_executable_status:" <> installPlanStatusText status]
      blockedReasons = stableTextSet (typedPlanBlockedReasons finalized <> nonReadyReasons)
   in if null blockedReasons
        then InstallPlanExecutable (ExecutableInstallPlan finalized)
        else
          InstallPlanBlocked
            ( BlockedInstallPlan
                (finalizeTypedInstallPlan finalized {typedPlanBlockedReasons = blockedReasons})
                blockedReasons
            )
