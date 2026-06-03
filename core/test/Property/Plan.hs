{-# LANGUAGE OverloadedStrings #-}

module Property.Plan
  ( prop_planFingerprintStableWithInputOrder
  , prop_unsafePathBlocksExecutablePlan
  ) where

import qualified Data.Text as Text
import Panino.Install.Plan.Types
  ( InstallPlanNode(..)
  , InstallPlanRollbackAction(..)
  , installNodeTargetPath
  , typedPlanFingerprint
  , typedPlanNodes
  , typedPlanStatus
  )
import Property.Generators (simpleTypedPlan)
import Test.QuickCheck
  ( Property
  , property
  )

prop_planFingerprintStableWithInputOrder :: Property
prop_planFingerprintStableWithInputOrder =
  let planA = simpleTypedPlan [nodeA, nodeB]
      planB = simpleTypedPlan [nodeB, nodeA]
   in property (typedPlanFingerprint planA == typedPlanFingerprint planB)

prop_unsafePathBlocksExecutablePlan :: Property
prop_unsafePathBlocksExecutablePlan =
  let plan = simpleTypedPlan [unsafeNode]
   in property (typedPlanStatus plan == "blocked" && all safeOrBlocked (typedPlanNodes plan))

nodeA :: InstallPlanNode
nodeA =
  installNode "a" "mods/a.jar" Nothing

nodeB :: InstallPlanNode
nodeB =
  installNode "b" "mods/b.jar" Nothing

unsafeNode :: InstallPlanNode
unsafeNode =
  installNode "unsafe" "../mods/escape.jar" (Just "unsafe_target_path")

safeOrBlocked :: InstallPlanNode -> Bool
safeOrBlocked node =
  case installNodeTargetPath node of
    Just path
      | ".." `elem` splitPathSegments path ->
          installNodeBlockedReason node /= Nothing
    _ -> True

splitPathSegments :: FilePath -> [FilePath]
splitPathSegments value =
  case break (== '/') value of
    (segment, "") -> [segment]
    (segment, rest) -> segment : splitPathSegments (drop 1 rest)

installNode :: String -> FilePath -> Maybe String -> InstallPlanNode
installNode ident target blockedReason =
  InstallPlanNode
    { installNodeId = Text.pack ident
    , installNodeKind = "file"
    , installNodeAction = "download"
    , installNodePhase = "download"
    , installNodeLabel = Text.pack ident
    , installNodeTargetPath = Just target
    , installNodeSourceUrls = ["https://example.invalid/" <> Text.pack ident]
    , installNodeSha1 = Just (Text.pack ident <> "-sha1")
    , installNodeSize = Just 1
    , installNodeRequired = True
    , installNodeDependsOn = []
    , installNodeVerifications = []
    , installNodeRollback =
        InstallPlanRollbackAction
          { installRollbackAction = "removeCreatedFile"
          , installRollbackTargetPath = Just target
          , installRollbackBackupPath = Nothing
          , installRollbackReason = Nothing
          }
    , installNodeBlockedReason = Text.pack <$> blockedReason
    , installNodeDiagnostics = []
    }
