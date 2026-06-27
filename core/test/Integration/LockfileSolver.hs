{-# LANGUAGE OverloadedStrings #-}

module Integration.LockfileSolver
  ( assertLockfileSolver
  ) where

import Control.Monad (when)
import Data.Aeson
  ( object
  , toJSON
  , (.=)
  )
import qualified Data.ByteString.Char8 as BS8
import Data.List (isPrefixOf)
import Data.Maybe (isJust)
import qualified Data.Text as Text
import Integration.LockfileSolver.Room (assertRoomLockRepair)
import Integration.LockfileSolver.Update (assertLockfileUpdatePolicies)
import Network.HTTP.Types
  ( hContentType
  , status200
  )
import Network.Wai (responseLBS)
import Network.Wai.Handler.Warp (testWithApplication)
import Panino.CoreLogic.Determinism (canonicalJson)
import Panino.Core.Types
  ( gameDirFromPath
  , urlFromText
  )
import Panino.Install.Plan.Executor
  ( InstallPlanExecutionResult(..)
  , InstallPlanExecutionStatus(..)
  , executeExecutableInstallPlan
  )
import Panino.Install.Plan.State (requireExecutableInstallPlan)
import Panino.Install.Plan.Types
  ( TypedInstallPlan(..)
  )
import Panino.Lockfile.Apply
  ( rollbackLockfilePlanNode
  , runLockfilePlanNode
  )
import Panino.Lockfile.Solver
  ( lockfileApplyReadyLockfile
  , lockfileLaunchBlockedReasons
  , lockfileSolveCacheGameDir
  , solveLockfile
  , verifyLockfile
  )
import Panino.Lockfile.Types
  ( LockfileApplyRequest(..)
  , LockfileChangeset(..)
  , LockfileExplain(..)
  , LockfileSolveRequest(..)
  , LockfileVerifyIssue(..)
  , LockfileVerifyResponse(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , SolverConflict(..)
  , SolverResult(..)
  , lockfileChangePackageId
  )
import Panino.Net.Http (makeHttpManager)
import System.Directory
  ( createDirectoryIfMissing
  , doesDirectoryExist
  , getTemporaryDirectory
  , removeDirectoryRecursive
  )
import System.FilePath
  ( (</>)
  , normalise
  , takeDirectory
  )
import TestFixtures
  ( testLockfilePackage
  , testLockfileSolveRequest
  , testPackageConstraint
  , testPaninoLockfile
  , withPackageSlug
  )
import TestSupport (assertEqual)

assertLockfileSolver :: IO ()
assertLockfileSolver = do
  manager <- makeHttpManager
  tempDir <- getTemporaryDirectory
  let gameDir = tempDir </> "panino-lockfile-solver-test"
  gameDirExists <- doesDirectoryExist gameDir
  when gameDirExists (removeDirectoryRecursive gameDir)
  let solveCacheDir = lockfileSolveCacheGameDir gameDir
  assertEqual
    "lockfile solve service cache uses parent-scoped Panino cache"
    (takeDirectory gameDir </> ".panino" </> "lockfile-solve-cache")
    solveCacheDir
  assertEqual
    "lockfile solve service cache stays outside target game dir"
    False
    ((normalise gameDir <> "/") `isPrefixOf` (normalise solveCacheDir <> "/"))
  let fabricApi =
        testLockfilePackage
          "fabric-api"
          "Fabric API"
          "fabric-api-version"
          "fabric-api.jar"
          "mods/fabric-api.jar"
          "a9993e364706816aba3e25717850c26c9cd0d89d"
          []
      sodium =
        testLockfilePackage
          "sodium"
          "Sodium"
          "sodium-version"
          "sodium.jar"
          "mods/sodium.jar"
          "589c22335a381f122d129225f5c0ba3056ed5811"
          []
      iris =
        testLockfilePackage
          "iris"
          "Iris"
          "iris-version"
          "iris.jar"
          "mods/iris.jar"
          "0bbee1b07a248e27c83fc3d5951213c1e8aef20f"
          [ testPackageConstraint "iris" "fabric-api" "requires" True
          , testPackageConstraint "iris" "sodium" "optional" False
          ]
      existingLockfile = testPaninoLockfile gameDir [fabricApi, sodium]
      request = testLockfileSolveRequest gameDir [iris] (Just existingLockfile)
      keepLockedRequest =
        (testLockfileSolveRequest gameDir [iris] (Just existingLockfile))
          { solveRequestUpdatePolicy = "keepLocked" }
      requestShuffled =
        testLockfileSolveRequest
          gameDir
          [iris]
          (Just (testPaninoLockfile gameDir [sodium, fabricApi]))
      rootOrderResult =
        solveLockfile
          (testLockfileSolveRequest gameDir [iris, sodium] (Just (testPaninoLockfile gameDir [fabricApi])))
      rootOrderResultShuffled =
        solveLockfile
          (testLockfileSolveRequest gameDir [sodium, iris] (Just (testPaninoLockfile gameDir [fabricApi])))
      irisNoisyA =
        iris
          { resolvedPackageDownloadUrls = ["https://mirror-b.example/iris.jar", "https://mirror-a.example/iris.jar"]
          , resolvedPackageDependencies = reverse (resolvedPackageDependencies iris)
          , resolvedPackageSelectedBecause = ["z-input", "a-input"]
          }
      irisNoisyB =
        iris
          { resolvedPackageDownloadUrls = ["https://mirror-a.example/iris.jar", "https://mirror-b.example/iris.jar"]
          , resolvedPackageDependencies = resolvedPackageDependencies iris
          , resolvedPackageSelectedBecause = ["a-input", "z-input"]
          }
      noisyResult =
        solveLockfile
          (testLockfileSolveRequest gameDir [irisNoisyA] (Just existingLockfile))
      noisyResultShuffled =
        solveLockfile
          (testLockfileSolveRequest gameDir [irisNoisyB] (Just (testPaninoLockfile gameDir [sodium, fabricApi])))
      result = solveLockfile request
      resultShuffled = solveLockfile requestShuffled

  assertEqual "lockfile solver succeeds with required dependency" "ready" (solverResultStatus result)
  assertEqual "lockfile solver typed plan is ready" "ready" (typedPlanStatus (solverResultTypedPlan result))
  case (solverResultLockfile result, solverResultLockfile resultShuffled) of
    (Just lockfile, Just shuffledLockfile) -> do
      assertEqual "lockfile solver includes required dependency" ["fabric-api", "iris"] (map resolvedPackageId (lockfilePackages lockfile))
      assertEqual "lockfile solver omits optional dependency by default" False ("sodium" `elem` map resolvedPackageId (lockfilePackages lockfile))
      assertEqual "lockfile fingerprint is deterministic" (lockfileFingerprint lockfile) (lockfileFingerprint shuffledLockfile)
      createDirectoryIfMissing True (gameDir </> "mods")
      BS8.writeFile (gameDir </> "mods" </> "fabric-api.jar") "wrong"
      BS8.writeFile (gameDir </> "mods" </> "z-extra.jar") "extra"
      BS8.writeFile (gameDir </> "mods" </> "a-extra.jar") "extra"
      verifyResponse <- verifyLockfile gameDir lockfile
      verifyResponseShuffled <-
        verifyLockfile
          gameDir
          lockfile
            { lockfilePackages = reverse (lockfilePackages lockfile)
            , lockfileFiles = reverse (lockfileFiles lockfile)
            }
      assertEqual "lockfile verify reports missing files" True (not (null (verifyResponseMissingFiles verifyResponse)))
      assertEqual "lockfile verify reports hash mismatch" True (not (null (verifyResponseHashMismatches verifyResponse)))
      assertEqual
        "lockfile verify extra files are sorted"
        [Just "mods/a-extra.jar", Just "mods/z-extra.jar"]
        (map verifyIssueTargetPath (verifyResponseExtraFiles verifyResponse))
      assertEqual
        "lockfile verify ignores lockfile array order"
        (canonicalJson (toJSON verifyResponse))
        (canonicalJson (toJSON verifyResponseShuffled))
      assertEqual "lockfile verify creates repair plan" True (isJust (verifyResponseRepairPlan verifyResponse))
      assertEqual "lockfile launch verify blocks missing or mismatched files" True (not (null (lockfileLaunchBlockedReasons verifyResponse)))
      case gameDirFromPath gameDir of
        Nothing ->
          fail "lockfile apply test expected non-empty target game dir"
        Just staleApplyGameDir ->
          assertEqual
            "lockfile apply rejects stale solver fingerprint"
            (Left "solver_fingerprint_mismatch")
            ( lockfileApplyReadyLockfile
                LockfileApplyRequest
                  { applyRequestTargetGameDir = staleApplyGameDir
                  , applyRequestSolverFingerprint = "stale-fingerprint"
                  , applyRequestResult = result
                  }
            )
      let applyGameDir = tempDir </> "panino-lockfile-apply-test"
      applyGameDirExists <- doesDirectoryExist applyGameDir
      when applyGameDirExists (removeDirectoryRecursive applyGameDir)
      testWithApplication
        ( pure $ \_ respond ->
            respond (responseLBS status200 [(hContentType, "application/octet-stream"), ("Content-Length", "10")] "downloaded")
        )
        $ \port -> do
          let downloadedPackage =
                (testLockfilePackage "downloaded" "Downloaded" "downloaded-version" "downloaded.jar" "mods/downloaded.jar" "47265105ec5517e46aec2ed5310c177e1e811af8" [])
                  { resolvedPackageDownloadUrls = [urlFromText (Text.pack ("http://127.0.0.1:" <> show port <> "/downloaded.jar"))]
                  , resolvedPackageSize = Just 10
                  }
              applyResult = solveLockfile (testLockfileSolveRequest applyGameDir [downloadedPackage] Nothing)
          execution <-
            case requireExecutableInstallPlan (solverResultTypedPlan applyResult) of
              Left blocked ->
                fail ("lockfile apply test expected executable plan: " <> show blocked)
              Right executablePlan ->
                executeExecutableInstallPlan
                  executablePlan
                  (runLockfilePlanNode manager)
                  rollbackLockfilePlanNode
                  (\_ -> pure ())
          assertEqual "lockfile apply runner executes plan downloads" InstallExecutionSucceeded (installExecutionStatus execution)
          written <- BS8.readFile (applyGameDir </> "mods" </> "downloaded.jar")
          assertEqual "lockfile apply runner writes downloaded file" "downloaded" written
          case solverResultLockfile applyResult of
            Just appliedLockfile -> do
              appliedVerify <- verifyLockfile applyGameDir appliedLockfile
              assertEqual "lockfile apply runner produces verifiable files" "locked" (verifyResponseStatus appliedVerify)
            Nothing ->
              fail "lockfile apply runner solve did not produce lockfile"
    _ ->
      fail "lockfile solver did not produce lockfiles"
  case (solverResultLockfile rootOrderResult, solverResultLockfile rootOrderResultShuffled) of
    (Just lockfile, Just shuffledLockfile) ->
      assertEqual "lockfile root order does not change fingerprint" (lockfileFingerprint lockfile) (lockfileFingerprint shuffledLockfile)
    _ ->
      fail "lockfile root-order solve did not produce lockfiles"
  assertEqual "lockfile root order does not change canonical solver output" (canonicalJson (toJSON rootOrderResult)) (canonicalJson (toJSON rootOrderResultShuffled))
  case (solverResultLockfile noisyResult, solverResultLockfile noisyResultShuffled) of
    (Just lockfile, Just shuffledLockfile) ->
      assertEqual "lockfile package field order does not change fingerprint" (lockfileFingerprint lockfile) (lockfileFingerprint shuffledLockfile)
    _ ->
      fail "lockfile noisy solve did not produce lockfiles"
  assertEqual "lockfile package field order does not change typed plan" (typedPlanFingerprint (solverResultTypedPlan noisyResult)) (typedPlanFingerprint (solverResultTypedPlan noisyResultShuffled))
  assertEqual "lockfile changeset removes unselected relock package" ["sodium"] (map lockfileChangePackageId (changesetRemove (solverResultChangeset result)))
  assertEqual "lockfile explain keeps optional dependency out of plan" True (not (null (explainRejectedCandidates (solverResultExplain result))))
  assertEqual
    "lockfile keepLocked retains existing packages"
    True
    ( maybe
        False
        (\lockfile -> "sodium" `elem` map resolvedPackageId (lockfilePackages lockfile))
        (solverResultLockfile (solveLockfile keepLockedRequest))
    )
  assertLockfileUpdatePolicies gameDir fabricApi sodium
  assertRoomLockRepair gameDir fabricApi sodium

  let missingDependencyResult =
        solveLockfile
          (testLockfileSolveRequest gameDir [iris] Nothing)
  assertEqual "lockfile missing required dependency blocks solve" "blocked" (solverResultStatus missingDependencyResult)
  assertEqual "lockfile blocked solve has blocked typed plan" "blocked" (typedPlanStatus (solverResultTypedPlan missingDependencyResult))
  assertEqual "lockfile missing dependency reason" True ("solver_no_candidate:fabric-api" `elem` solverResultBlockedReasons missingDependencyResult)

  let pathConflictA = testLockfilePackage "path-a" "Path A" "path-a-version" "path-a.jar" "mods/shared.jar" "a9993e364706816aba3e25717850c26c9cd0d89d" []
      pathConflictB = testLockfilePackage "path-b" "Path B" "path-b-version" "path-b.jar" "mods/shared.jar" "589c22335a381f122d129225f5c0ba3056ed5811" []
      duplicateA =
        withPackageSlug
          "duplicate-mod"
          (testLockfilePackage "duplicate-a" "Duplicate A" "duplicate-a-version" "duplicate-a.jar" "mods/duplicate-a.jar" "a9993e364706816aba3e25717850c26c9cd0d89d" [])
      duplicateB =
        withPackageSlug
          "duplicate-mod"
          (testLockfilePackage "duplicate-b" "Duplicate B" "duplicate-b-version" "duplicate-b.jar" "mods/duplicate-b.jar" "589c22335a381f122d129225f5c0ba3056ed5811" [])
      incompatibleA =
        testLockfilePackage "incompatible-a" "Incompatible A" "incompatible-a-version" "incompatible-a.jar" "mods/incompatible-a.jar" "a9993e364706816aba3e25717850c26c9cd0d89d" []
      incompatibleB =
        (testLockfilePackage "incompatible-b" "Incompatible B" "incompatible-b-version" "incompatible-b.jar" "mods/incompatible-b.jar" "589c22335a381f122d129225f5c0ba3056ed5811" [])
          { resolvedPackageConflicts = [testPackageConstraint "incompatible-b" "incompatible-a" "incompatible" True] }
      javaMajorPackage =
        (testLockfilePackage "java-required" "Java Required" "java-required-version" "java-required.jar" "mods/java-required.jar" "7777777777777777777777777777777777777777" [])
          { resolvedPackageJavaMajor = Just 21 }
      pathConflictResult = solveLockfile (testLockfileSolveRequest gameDir [pathConflictA, pathConflictB] Nothing)
      duplicateResult = solveLockfile (testLockfileSolveRequest gameDir [duplicateA, duplicateB] Nothing)
      incompatibleResult = solveLockfile (testLockfileSolveRequest gameDir [incompatibleA, incompatibleB] Nothing)
      javaMajorResult =
        solveLockfile
          ( (testLockfileSolveRequest gameDir [javaMajorPackage] Nothing)
              { solveRequestJavaPolicy = Just (object ["javaMajor" .= (17 :: Int)])
              }
          )
  assertEqual "lockfile same path different hash blocks solve" True ("solver_conflict" `elem` map solverConflictCode (solverResultConflicts pathConflictResult))
  assertEqual "lockfile duplicate mod id blocks solve" True ("solver_duplicate_mod_id" `elem` map solverConflictCode (solverResultConflicts duplicateResult))
  assertEqual "lockfile incompatible dependency blocks solve" True ("solver_conflict" `elem` map solverConflictCode (solverResultConflicts incompatibleResult))
  assertEqual "lockfile Java major mismatch blocks solve" True ("solver_no_candidate" `elem` map solverConflictCode (solverResultConflicts javaMajorResult))

  let packageA =
        testLockfilePackage
          "cycle-a"
          "Cycle A"
          "cycle-a-version"
          "cycle-a.jar"
          "mods/cycle-a.jar"
          "a9993e364706816aba3e25717850c26c9cd0d89d"
          [testPackageConstraint "cycle-a" "cycle-b" "requires" True]
      packageB =
        testLockfilePackage
          "cycle-b"
          "Cycle B"
          "cycle-b-version"
          "cycle-b.jar"
          "mods/cycle-b.jar"
          "589c22335a381f122d129225f5c0ba3056ed5811"
          [testPackageConstraint "cycle-b" "cycle-a" "requires" True]
      cycleResult =
        solveLockfile
          (testLockfileSolveRequest gameDir [packageA] (Just (testPaninoLockfile gameDir [packageB])))
  assertEqual "lockfile dependency cycle does not recurse forever" True ("solver_cycle_detected:cycle-a" `elem` solverResultWarnings cycleResult)
