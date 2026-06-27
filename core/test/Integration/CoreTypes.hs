{-# LANGUAGE OverloadedStrings #-}

module Integration.CoreTypes
  ( assertCoreTypes
  ) where

import Data.Aeson
  ( eitherDecode
  , encode
  )
import qualified Data.ByteString.Lazy.Char8 as BL8
import Data.Either (isLeft)
import Data.List (isInfixOf)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import Panino.Core.TypedToml
  ( TomlValue(..)
  , blankLine
  , renderToml
  , tableArray
  , tomlKeyValue
  )
import Panino.Core.Types
  ( GameDir
  , Sha1
  , Url
  , sha1FromText
  , sha1Text
  , urlFromText
  )
import Panino.Install.Plan.Types
  ( InstallPlanStatus(..)
  , installPlanStatusFromText
  , installPlanStatusText
  )
import Panino.Lockfile.Types
  ( LockfileSolveRequest
  , LockfileChangeAction(..)
  , LockfileSolveMode(..)
  , LockfileSolveStatus(..)
  , LockfileUpdatePolicy(..)
  , LockfileVerifyIssueKind(..)
  , LockfileVerifyStatus(..)
  , PackageCoordinate(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , coordinateProjectIdText
  , coordinateVersionIdText
  , lockfileChangeActionFromText
  , lockfileChangeActionText
  , lockfileSolveModeFromText
  , lockfileSolveModeText
  , lockfileSolveStatusFromText
  , lockfileSolveStatusText
  , lockfileUpdatePolicyFromText
  , lockfileUpdatePolicyText
  , lockfileMinecraftText
  , lockfileTargetGameDirPath
  , lockfileVerifyIssueKindFromText
  , lockfileVerifyIssueKindText
  , lockfileVerifyStatusText
  , resolvedPackageDownloadUrlTexts
  , resolvedPackageTargetPathFilePath
  , solveRequestMinecraftVersionText
  , solveRequestTargetGameDirPath
  )
import Panino.Api.Routes.Minecraft.Phase
  ( MinecraftTaskPhase(..)
  , installProgressPhases
  , launchRepairProgressPhases
  , minecraftTaskPhaseId
  , progressPhaseId
  )
import TestSupport (assertEqual)

assertCoreTypes :: IO ()
assertCoreTypes = do
  let url = urlFromText "https://example.com/file.jar"
  assertEqual "core url json keeps string wire shape" "\"https://example.com/file.jar\"" (BL8.unpack (encode url))
  assertEqual "core url json roundtrip" (Right url) (eitherDecode "\"https://example.com/file.jar\"" :: Either String Url)
  assertEqual "core sha1 constructor normalizes case" (Just "abcdef") (sha1Text <$> sha1FromText "ABCDEF")
  assertEqual "core sha1 json rejects empty text" True (isLeft (eitherDecode "\"\"" :: Either String Sha1))
  assertEqual "core game dir json rejects empty text" True (isLeft (eitherDecode "\"\"" :: Either String GameDir))
  assertEqual "minecraft install phase ids keep wire shape" ["prepare", "minecraft", "loader", "content", "verify"] (map progressPhaseId installProgressPhases)
  assertEqual "minecraft launch repair phase ids keep wire shape" ["minecraft", "loader", "content", "verify"] (map progressPhaseId launchRepairProgressPhases)
  assertEqual "minecraft launch phase id keeps wire shape" "launch" (minecraftTaskPhaseId MinecraftPhaseLaunch)
  assertEqual "install plan empty status is ready" InstallStatusReady (installPlanStatusFromText "")
  assertEqual "install plan unknown status keeps wire text" "staged" (installPlanStatusText (InstallStatusOther "staged"))
  assertEqual "lockfile solve empty status is blocked" LockfileSolveBlocked (lockfileSolveStatusFromText "")
  assertEqual "lockfile solve unknown status keeps wire text" "queued" (lockfileSolveStatusText (LockfileSolveOther "queued"))
  assertEqual "lockfile solve mode defaults to install" LockfileModeInstall (lockfileSolveModeFromText "")
  assertEqual "lockfile solve mode unknown keeps wire text" "roomSync" (lockfileSolveModeText (lockfileSolveModeFromText "roomSync"))
  assertEqual "lockfile update policy parses updateSelected" LockfileUpdateSelected (lockfileUpdatePolicyFromText "updateSelected")
  assertEqual "lockfile update policy unknown keeps wire text" "customPolicy" (lockfileUpdatePolicyText (lockfileUpdatePolicyFromText "customPolicy"))
  assertEqual "lockfile change action parses repair" LockfileActionRepair (lockfileChangeActionFromText "repair")
  assertEqual "lockfile change action unknown keeps wire text" "customAction" (lockfileChangeActionText (lockfileChangeActionFromText "customAction"))
  assertEqual "lockfile verify locked status keeps wire text" "locked" (lockfileVerifyStatusText LockfileStatusLocked)
  assertEqual "lockfile verify issue kind parses known wire text" VerifyIssueMissingFile (lockfileVerifyIssueKindFromText "missingFile")
  assertEqual "lockfile verify unknown issue kind keeps wire text" "customIssue" (lockfileVerifyIssueKindText (lockfileVerifyIssueKindFromText "customIssue"))
  assertLockfileWireShape
  assertEqual
    "core typed toml escapes strings"
    ("serverAddr = \"host\\\"\\\\\\nname\"\nserverPort = 7000\n\n[[proxies]]\n" :: Text)
    ( renderToml
        [ tomlKeyValue "serverAddr" (TomlString "host\"\\\nname")
        , tomlKeyValue "serverPort" (TomlInteger 7000)
        , blankLine
        , tableArray "proxies"
        ]
    )

assertLockfileWireShape :: IO ()
assertLockfileWireShape = do
  let coordinate =
        PackageCoordinate
          { coordinateSource = "modrinth"
          , coordinateProjectId = Just "iris"
          , coordinateVersionId = Just "iris-version"
          , coordinateFileId = Just "iris-file"
          , coordinateSlug = Just "iris"
          , coordinateName = Just "Iris"
          , coordinateKind = "mod"
          }
      package =
        ResolvedPackage
          { resolvedPackageId = "iris"
          , resolvedPackageCoordinate = coordinate
          , resolvedPackageDisplayName = "Iris"
          , resolvedPackageVersionName = Just "1.0.0"
          , resolvedPackageFileName = Just "iris.jar"
          , resolvedPackageTargetPath = Just "mods/iris.jar"
          , resolvedPackageHashes = Map.singleton "sha1" "abcdef"
          , resolvedPackageSize = Just 1
          , resolvedPackageDownloadUrls = ["https://example.com/iris.jar"]
          , resolvedPackageGameVersions = ["1.21.5"]
          , resolvedPackageLoaders = ["fabric"]
          , resolvedPackageJavaMajor = Nothing
          , resolvedPackageSide = Just "client"
          , resolvedPackageSelectedBecause = []
          , resolvedPackageLocked = False
          , resolvedPackagePinReason = Nothing
          , resolvedPackageDependencies = []
          , resolvedPackageConflicts = []
          , resolvedPackageSourceSnapshot = Nothing
          }
      lockfile =
        PaninoLockfile
          { lockfileVersion = 1
          , lockfileSolverVersion = "test"
          , lockfileFingerprint = "fingerprint"
          , lockfileCreatedAt = Nothing
          , lockfileUpdatedAt = Nothing
          , lockfileTargetGameDir = Just "/tmp/panino"
          , lockfileMinecraft = Just "1.21.5"
          , lockfileJava = Nothing
          , lockfileLoader = Nothing
          , lockfileShaderLoader = Nothing
          , lockfileRoots = ["iris"]
          , lockfilePackages = [package]
          , lockfileFiles = []
          , lockfileConstraints = []
          , lockfileOverrides = []
          , lockfileSourceSnapshots = []
          , lockfileManualEntries = []
          , lockfileWarnings = []
          }
      encodedPackage = BL8.unpack (encode package)
      encodedLockfile = BL8.unpack (encode lockfile)
  assertEqual "coordinate project id text view" (Just "iris") (coordinateProjectIdText coordinate)
  assertEqual "coordinate version id text view" (Just "iris-version") (coordinateVersionIdText coordinate)
  assertEqual "resolved package target path text view" (Just "mods/iris.jar") (resolvedPackageTargetPathFilePath package)
  assertEqual "resolved package download url text view" ["https://example.com/iris.jar"] (resolvedPackageDownloadUrlTexts package)
  assertEqual "lockfile target game dir text view" (Just "/tmp/panino") (lockfileTargetGameDirPath lockfile)
  assertEqual "lockfile minecraft text view" (Just "1.21.5") (lockfileMinecraftText lockfile)
  assertContains "package projectId stays a JSON string" "\"projectId\":\"iris\"" encodedPackage
  assertContains "package versionId stays a JSON string" "\"versionId\":\"iris-version\"" encodedPackage
  assertContains "package targetPath stays a JSON string" "\"targetPath\":\"mods/iris.jar\"" encodedPackage
  assertContains "package downloadUrls stays a JSON string list" "\"downloadUrls\":[\"https://example.com/iris.jar\"]" encodedPackage
  assertContains "lockfile targetGameDir stays a JSON string" "\"targetGameDir\":\"/tmp/panino\"" encodedLockfile
  assertContains "lockfile minecraft stays a JSON string" "\"minecraft\":\"1.21.5\"" encodedLockfile
  case eitherDecode "{\"targetGameDir\":\"/tmp/panino\",\"minecraftVersion\":\"1.21.5\"}" :: Either String LockfileSolveRequest of
    Left err ->
      assertEqual ("lockfile solve request json decodes: " <> err) True False
    Right request -> do
      assertEqual "solve request targetGameDir decodes from JSON string" "/tmp/panino" (solveRequestTargetGameDirPath request)
      assertEqual "solve request minecraftVersion decodes from JSON string" (Just "1.21.5") (solveRequestMinecraftVersionText request)

assertContains :: String -> String -> String -> IO ()
assertContains label expected actual =
  assertEqual label True (expected `isInfixOf` actual)
