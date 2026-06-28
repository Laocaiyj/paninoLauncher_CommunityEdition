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
  , tomlKey
  , tomlKeyValue
  , tomlPath
  )
import Panino.Core.Types
  ( GameDir
  , ProjectId
  , Sha1
  , Url
  , VersionId
  , gameDirPath
  , projectIdText
  , relativePathFilePath
  , sha1FromText
  , sha1Text
  , urlFromText
  , urlText
  , versionIdText
  )
import Panino.Core.WireText
  ( wireText
  )
import Panino.Api.Types
  ( ContentInstallDependency(..)
  , ContentInstallFile(..)
  , ContentInstallRequest(..)
  , ContentPlanAction(..)
  , ContentUpdateLockEntry(..)
  , ContentUpdateMode(..)
  , ContentUpdatePlanResource(..)
  , DownloadRuntimeOptions(..)
  , InstallRequest(..)
  , LaunchRequest(..)
  , TaskKind(..)
  , contentPlanActionFromText
  , contentPlanActionText
  , contentUpdateModeFromText
  , contentUpdateModeText
  , installRequestGameDirPath
  , installRequestVersionText
  , launchRequestGameDirPath
  , launchRequestVersionText
  , TaskPhaseId
  , TaskState(..)
  , taskKindFromText
  , taskKindText
  , taskPhaseIdText
  , taskStateFromText
  , taskStateText
  )
import Panino.Install.Plan.Types
  ( InstallNodeAction(..)
  , InstallNodePhase(..)
  , InstallPlanStatus(..)
  , InstallRollbackActionKind(..)
  , InstallVerificationStatus(..)
  , installNodeActionFromText
  , installNodeActionText
  , installNodePhaseFromText
  , installNodePhaseText
  , installPlanStatusFromText
  , installPlanStatusText
  , installRollbackActionFromText
  , installRollbackActionText
  , installVerificationStatusFromText
  , installVerificationStatusText
  )
import Panino.Lockfile.Types
  ( LockfileApplyRejection(..)
  , LockfileApplyStatus(..)
  , LockfileFile(..)
  , LockfileSolveRequest
  , LockfileChange(..)
  , LockfileChangeAction(..)
  , LockfileSolveMode(..)
  , LockfileSolveStatus(..)
  , LockfileUpdatePolicy(..)
  , LockfileVerifyIssue(..)
  , LockfileVerifyIssueKind(..)
  , LockfileVerifyStatus(..)
  , PackageCoordinate(..)
  , PackageSource(..)
  , PaninoLockfile(..)
  , ResolvedPackage(..)
  , coordinateProjectIdText
  , coordinateVersionIdText
  , lockfileApplyRejectionFromText
  , lockfileApplyRejectionText
  , lockfileApplyStatusText
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
  , packageSourceFromText
  , packageSourceText
  , resolvedPackageDownloadUrlTexts
  , resolvedPackageTargetPathFilePath
  , resolvedPackageSha1Text
  , lockfileFileSha1Text
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
import Panino.Api.Routes.Minecraft.InstallTask
  ( InstallTaskState(..)
  , installTaskStateText
  )
import Panino.Api.Routes.Minecraft.InstallTask.Rollback
  ( InstallRollbackStatus(..)
  , installRollbackStatusText
  )
import Panino.Api.Routes.Minecraft.LaunchTask
  ( LaunchTaskOutcome(..)
  , launchTaskOutcomeText
  )
import Panino.Minecraft.Types
  ( DownloadInfo(..)
  , VersionJson(..)
  , VersionManifest(..)
  , VersionSummary(..)
  )
import TestSupport (assertEqual)

assertCoreTypes :: IO ()
assertCoreTypes = do
  let url = urlFromText "https://example.com/file.jar"
  assertEqual "core url wire text keeps string shape" "https://example.com/file.jar" (wireText url)
  assertEqual "core url json keeps string wire shape" "\"https://example.com/file.jar\"" (BL8.unpack (encode url))
  assertEqual "core url json roundtrip" (Right url) (eitherDecode "\"https://example.com/file.jar\"" :: Either String Url)
  assertEqual "core url json rejects empty text" True (isLeft (eitherDecode "\"\"" :: Either String Url))
  assertEqual "core sha1 constructor normalizes case" (Just "abcdef") (sha1Text <$> sha1FromText "ABCDEF")
  assertEqual "core sha1 json rejects empty text" True (isLeft (eitherDecode "\"\"" :: Either String Sha1))
  assertEqual "core game dir json rejects empty text" True (isLeft (eitherDecode "\"\"" :: Either String GameDir))
  assertEqual "minecraft install phase ids keep wire shape" ["prepare", "minecraft", "loader", "content", "verify"] (map (taskPhaseIdText . progressPhaseId) installProgressPhases)
  assertEqual "minecraft launch repair phase ids keep wire shape" ["minecraft", "loader", "content", "verify"] (map (taskPhaseIdText . progressPhaseId) launchRepairProgressPhases)
  assertEqual "minecraft launch phase id keeps wire shape" "launch" (taskPhaseIdText (minecraftTaskPhaseId MinecraftPhaseLaunch))
  assertEqual "launch task outcome texts keep wire shape" ["java process started", "java exited successfully"] (map launchTaskOutcomeText [LaunchProcessStarted, LaunchProcessExitedSuccessfully])
  assertEqual "install task state ids keep wire shape" ["running", "succeeded", "failed", "cancelled"] (map installTaskStateText [InstallTaskRunning, InstallTaskSucceeded, InstallTaskFailed, InstallTaskCancelled])
  assertEqual "install task state json keeps string wire shape" "\"failed\"" (BL8.unpack (encode InstallTaskFailed))
  assertEqual "install rollback status texts keep wire shape" ["rolled_back", "partial_install_left_for_diagnosis"] (map installRollbackStatusText [InstallRolledBack, InstallRollbackPartialForDiagnosis])
  assertEqual "install rollback status json keeps string wire shape" "\"rolled_back\"" (BL8.unpack (encode InstallRolledBack))
  assertEqual "task phase id json keeps string wire shape" (Right "content") (taskPhaseIdText <$> (eitherDecode "\"content\"" :: Either String TaskPhaseId))
  assertEqual "task kind parses launch" TaskKindLaunch (taskKindFromText "launch")
  assertEqual "task kind unknown keeps wire text" "diagnostics.export" (taskKindText (taskKindFromText "diagnostics.export"))
  assertEqual "task state parses running" TaskRunning (taskStateFromText "running")
  assertEqual "task state unknown keeps wire text" "waitingForRuntime" (taskStateText (taskStateFromText "waitingForRuntime"))
  assertEqual "content plan action parses update" ContentPlanUpdate (contentPlanActionFromText "update")
  assertEqual "content plan action unknown keeps wire text" "dryRun" (contentPlanActionText (contentPlanActionFromText "dryRun"))
  assertEqual "content update mode normalizes separators" ContentUpdateAllSafe (contentUpdateModeFromText "update_all-safe")
  assertEqual "content update mode unknown keeps wire text" "safePreview" (contentUpdateModeText (contentUpdateModeFromText "safePreview"))
  assertEqual "install plan empty status is ready" InstallStatusReady (installPlanStatusFromText "")
  assertEqual "install plan unknown status keeps wire text" "staged" (installPlanStatusText (InstallStatusOther "staged"))
  assertEqual "install node action parses replace" InstallNodeReplace (installNodeActionFromText "replace")
  assertEqual "install node action unknown keeps wire text" "hydrate" (installNodeActionText (installNodeActionFromText "hydrate"))
  assertEqual "install node action preserves extension case" "removeCandidate" (installNodeActionText (installNodeActionFromText "removeCandidate"))
  assertEqual "install node phase parses metadata" InstallNodePhaseMetadata (installNodePhaseFromText "metadata")
  assertEqual "install node phase unknown keeps wire text" "post-verify" (installNodePhaseText (installNodePhaseFromText "post-verify"))
  assertEqual "install verification parses error status" InstallVerificationError (installVerificationStatusFromText "error")
  assertEqual "install verification unknown keeps wire text" "softBlocked" (installVerificationStatusText (installVerificationStatusFromText "softBlocked"))
  assertEqual "install rollback parses remove created file" InstallRollbackRemoveCreatedFile (installRollbackActionFromText "removeCreatedFile")
  assertEqual "install rollback parses legacy none" InstallRollbackNone (installRollbackActionFromText "none")
  assertEqual "install rollback unknown keeps wire text" "runtimeStoreCleanup" (installRollbackActionText (installRollbackActionFromText "runtimeStoreCleanup"))
  assertEqual "lockfile solve empty status is blocked" LockfileSolveBlocked (lockfileSolveStatusFromText "")
  assertEqual "lockfile solve unknown status keeps wire text" "queued" (lockfileSolveStatusText (LockfileSolveOther "queued"))
  assertEqual "lockfile solve mode defaults to install" LockfileModeInstall (lockfileSolveModeFromText "")
  assertEqual "lockfile solve mode unknown keeps wire text" "roomSync" (lockfileSolveModeText (lockfileSolveModeFromText "roomSync"))
  assertEqual "lockfile update policy parses updateSelected" LockfileUpdateSelected (lockfileUpdatePolicyFromText "updateSelected")
  assertEqual "lockfile update policy unknown keeps wire text" "customPolicy" (lockfileUpdatePolicyText (lockfileUpdatePolicyFromText "customPolicy"))
  assertEqual "lockfile change action parses repair" LockfileActionRepair (lockfileChangeActionFromText "repair")
  assertEqual "lockfile change action unknown keeps wire text" "customAction" (lockfileChangeActionText (lockfileChangeActionFromText "customAction"))
  assertEqual "lockfile apply rejection parses fingerprint mismatch" LockfileApplySolverFingerprintMismatch (lockfileApplyRejectionFromText "solver_fingerprint_mismatch")
  assertEqual "lockfile apply rejection unknown keeps wire text" "custom_apply_rejection" (lockfileApplyRejectionText (lockfileApplyRejectionFromText "custom_apply_rejection"))
  assertEqual "lockfile apply rejection json keeps string wire shape" "\"solver_blocked\"" (BL8.unpack (encode LockfileApplySolverBlocked))
  assertEqual "lockfile apply status keeps wire shape" "applied" (lockfileApplyStatusText LockfileApplied)
  assertEqual "lockfile apply status json keeps string wire shape" "\"applied\"" (BL8.unpack (encode LockfileApplied))
  assertEqual "lockfile verify locked status keeps wire text" "locked" (lockfileVerifyStatusText LockfileStatusLocked)
  assertEqual "lockfile verify issue kind parses known wire text" VerifyIssueMissingFile (lockfileVerifyIssueKindFromText "missingFile")
  assertEqual "lockfile verify unknown issue kind keeps wire text" "customIssue" (lockfileVerifyIssueKindText (lockfileVerifyIssueKindFromText "customIssue"))
  let verifyIssue =
        LockfileVerifyIssue
          { verifyIssueKind = VerifyIssueHashMismatch
          , verifyIssuePackageId = Just "iris"
          , verifyIssueTargetPath = Just "mods/iris.jar"
          , verifyIssueExpectedSha1 = Just "ABCDEF"
          , verifyIssueActualSha1 = Just "123456"
          , verifyIssueMessage = "Lockfile-managed file hash does not match."
          }
      encodedVerifyIssue = BL8.unpack (encode verifyIssue)
  assertContains "lockfile verify expected sha stays a JSON string" "\"expectedSha1\":\"abcdef\"" encodedVerifyIssue
  assertContains "lockfile verify actual sha stays a JSON string" "\"actualSha1\":\"123456\"" encodedVerifyIssue
  assertEqual "package source parses curseforge alias" PackageSourceCurseForge (packageSourceFromText "curse-forge")
  assertEqual "package source unknown preserves wire text" "customSource" (packageSourceText (packageSourceFromText "customSource"))
  assertLockfileWireShape
  assertMinecraftRequestWireShape
  assertContentApiWireShape
  assertMojangManifestWireShape
  assertEqual
    "core typed toml escapes strings"
    ("serverAddr = \"host\\\"\\\\\\nname\"\nserverPort = 7000\n\n[[proxies]]\n" :: Text)
    ( renderToml
        [ tomlKeyValue (tomlKey "serverAddr") (TomlString "host\"\\\nname")
        , tomlKeyValue (tomlKey "serverPort") (TomlInteger 7000)
        , blankLine
        , tableArray (tomlKey "proxies")
        ]
    )
  assertEqual
    "core typed toml renders dotted keys and quotes unsafe key segments"
    ("auth.token = \"secret\"\n\"server addr\".\"token\\\"name\" = \"value\"\n" :: Text)
    ( renderToml
        [ tomlKeyValue (tomlPath "auth" ["token"]) (TomlString "secret")
        , tomlKeyValue (tomlPath "server addr" ["token\"name"]) (TomlString "value")
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
      lockfileFile =
        LockfileFile
          { lockfileFilePackageId = "iris"
          , lockfileFileName = "iris.jar"
          , lockfileFileTargetPath = "mods/iris.jar"
          , lockfileFileHashes = Map.singleton "sha1" "ABCDEF"
          , lockfileFileSize = Just 1
          , lockfileFileDownloadUrls = ["https://example.com/iris.jar"]
          , lockfileFileKind = "mod"
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
      lockfileChange =
        LockfileChange
          { lockfileChangeAction = LockfileActionReplace
          , lockfileChangePackageId = "iris"
          , lockfileChangeDisplayName = "Iris"
          , lockfileChangeFromVersionId = Just "old-version"
          , lockfileChangeToVersionId = Just "new-version"
          , lockfileChangeTargetPath = Just "mods/iris.jar"
          , lockfileChangeReason = "Selected package differs from existing lockfile."
          }
      encodedChange = BL8.unpack (encode lockfileChange)
  assertEqual "coordinate project id text view" (Just "iris") (coordinateProjectIdText coordinate)
  assertEqual "coordinate version id text view" (Just "iris-version") (coordinateVersionIdText coordinate)
  assertEqual "resolved package target path text view" (Just "mods/iris.jar") (resolvedPackageTargetPathFilePath package)
  assertEqual "resolved package download url text view" ["https://example.com/iris.jar"] (resolvedPackageDownloadUrlTexts package)
  assertEqual "resolved package sha1 accessor normalizes text" (Just "abcdef") (resolvedPackageSha1Text package)
  assertEqual "resolved package sha1 accessor rejects empty text" Nothing (resolvedPackageSha1Text package { resolvedPackageHashes = Map.singleton "sha1" "" })
  assertEqual "lockfile file sha1 accessor normalizes text" (Just "abcdef") (lockfileFileSha1Text lockfileFile)
  assertEqual "lockfile file sha1 accessor rejects empty text" Nothing (lockfileFileSha1Text lockfileFile { lockfileFileHashes = Map.singleton "sha1" "" })
  assertEqual "lockfile target game dir text view" (Just "/tmp/panino") (lockfileTargetGameDirPath lockfile)
  assertEqual "lockfile minecraft text view" (Just "1.21.5") (lockfileMinecraftText lockfile)
  assertContains "package projectId stays a JSON string" "\"projectId\":\"iris\"" encodedPackage
  assertContains "package versionId stays a JSON string" "\"versionId\":\"iris-version\"" encodedPackage
  assertContains "package targetPath stays a JSON string" "\"targetPath\":\"mods/iris.jar\"" encodedPackage
  assertContains "package downloadUrls stays a JSON string list" "\"downloadUrls\":[\"https://example.com/iris.jar\"]" encodedPackage
  assertContains "lockfile targetGameDir stays a JSON string" "\"targetGameDir\":\"/tmp/panino\"" encodedLockfile
  assertContains "lockfile minecraft stays a JSON string" "\"minecraft\":\"1.21.5\"" encodedLockfile
  assertContains "lockfile change fromVersionId stays a JSON string" "\"fromVersionId\":\"old-version\"" encodedChange
  assertContains "lockfile change toVersionId stays a JSON string" "\"toVersionId\":\"new-version\"" encodedChange
  case eitherDecode "{\"action\":\"replace\",\"packageId\":\"iris\",\"displayName\":\"Iris\",\"fromVersionId\":\"old-version\",\"toVersionId\":\"new-version\",\"targetPath\":\"mods/iris.jar\",\"reason\":\"changed\"}" :: Either String LockfileChange of
    Left err ->
      assertEqual ("lockfile change json decodes: " <> err) True False
    Right change -> do
      assertEqual "lockfile change from version decodes as VersionId" (Just "old-version") (versionIdText <$> lockfileChangeFromVersionId change)
      assertEqual "lockfile change to version decodes as VersionId" (Just "new-version") (versionIdText <$> lockfileChangeToVersionId change)
  assertEqual "lockfile change empty version id is rejected" True (isLeft (eitherDecode "{\"fromVersionId\":\"\"}" :: Either String LockfileChange))
  case eitherDecode "{\"targetGameDir\":\"/tmp/panino\",\"minecraftVersion\":\"1.21.5\"}" :: Either String LockfileSolveRequest of
    Left err ->
      assertEqual ("lockfile solve request json decodes: " <> err) True False
    Right request -> do
      assertEqual "solve request targetGameDir decodes from JSON string" "/tmp/panino" (solveRequestTargetGameDirPath request)
      assertEqual "solve request minecraftVersion decodes from JSON string" (Just "1.21.5") (solveRequestMinecraftVersionText request)

assertContentApiWireShape :: IO ()
assertContentApiWireShape = do
  let installFile =
        ContentInstallFile
          { contentFileName = "sodium.jar"
          , contentFileUrl = "https://cdn.example.com/sodium.jar"
          , contentFileSha1 = Just "abcdef"
          , contentFileSize = Just 42
          , contentFilePrimary = Just True
          }
      dependency =
        ContentInstallDependency
          { contentDependencyProjectId = Just "fabric-api"
          , contentDependencyVersionId = Just "fabric-version"
          , contentDependencySource = Just "modrinth"
          , contentDependencyName = "Fabric API"
          , contentDependencyRequired = True
          , contentDependencyInstalled = Just False
          , contentDependencySha1 = Just "feedface"
          }
      updateLockEntry =
        ContentUpdateLockEntry
          { updateLockProjectId = Just "sodium"
          , updateLockProjectTitle = "Sodium"
          , updateLockOldReleaseId = Just "old-release"
          , updateLockNewReleaseId = Just "new-release"
          , updateLockOldSha1 = Just "oldsha"
          , updateLockNewSha1 = Just "newsha"
          , updateLockTargetPath = "/tmp/mc/mods/sodium.jar"
          , updateLockBackupPath = Nothing
          }
      encodedFile = BL8.unpack (encode installFile)
      encodedDependency = BL8.unpack (encode dependency)
      encodedLockEntry = BL8.unpack (encode updateLockEntry)
  assertContains "content file url stays a JSON string" "\"url\":\"https://cdn.example.com/sodium.jar\"" encodedFile
  assertContains "content file sha1 stays a JSON string" "\"sha1\":\"abcdef\"" encodedFile
  assertContains "content dependency project id stays a JSON string" "\"projectId\":\"fabric-api\"" encodedDependency
  assertContains "content dependency version id stays a JSON string" "\"versionId\":\"fabric-version\"" encodedDependency
  assertContains "content update lock old sha stays a JSON string" "\"oldSha1\":\"oldsha\"" encodedLockEntry
  assertContains "content update lock new release id stays a JSON string" "\"newReleaseId\":\"new-release\"" encodedLockEntry
  case eitherDecode "{\"source\":\"modrinth\",\"projectId\":\"sodium\",\"projectTitle\":\"Sodium\",\"releaseId\":\"version-1\",\"targetSubdir\":\"mods\",\"files\":[{\"fileName\":\"sodium.jar\",\"url\":\"https://cdn.example.com/sodium.jar\",\"sha1\":\"abcdef\"}],\"dependencies\":[{\"projectId\":\"fabric-api\",\"versionId\":\"fabric-version\",\"name\":\"Fabric API\",\"required\":true,\"sha1\":\"feedface\"}]}" :: Either String ContentInstallRequest of
    Left err ->
      assertEqual ("content install request json decodes: " <> err) True False
    Right request -> do
      assertEqual "content install request project id decodes from JSON string" (Just "sodium") (projectIdText <$> (contentInstallProjectId request :: Maybe ProjectId))
      assertEqual "content install request release id decodes from JSON string" "version-1" (versionIdText (contentInstallReleaseId request :: VersionId))
      assertEqual "content install request file url decodes from JSON string" ["https://cdn.example.com/sodium.jar"] (map (urlText . contentFileUrl) (contentInstallFiles request))
      assertEqual "content install request dependency sha decodes from JSON string" [Just "feedface"] (map (fmap sha1Text . contentDependencySha1) (contentInstallDependencies request))
      assertEqual "content install request download defaults remain available" (DownloadRuntimeOptions Nothing Nothing Nothing) (contentInstallDownload request)
  case eitherDecode "{\"projectId\":\"sodium\",\"projectTitle\":\"Sodium\",\"currentReleaseId\":\"old-release\",\"currentFileName\":\"sodium-old.jar\",\"currentSha1\":\"oldsha\",\"currentTargetPath\":\"/tmp/mc/mods/sodium.jar\",\"remoteReleaseId\":\"new-release\",\"remoteFileName\":\"sodium-new.jar\",\"remoteUrl\":\"https://cdn.example.com/sodium-new.jar\",\"remoteSha1\":\"newsha\",\"remoteSize\":42,\"selected\":true,\"dependencies\":[{\"projectId\":\"fabric-api\",\"versionId\":\"fabric-version\",\"name\":\"Fabric API\",\"required\":true,\"sha1\":\"feedface\"}]}" :: Either String ContentUpdatePlanResource of
    Left err ->
      assertEqual ("content update resource json decodes: " <> err) True False
    Right resource -> do
      assertEqual "content update resource project id decodes from JSON string" (Just "sodium") (projectIdText <$> (updateResourceProjectId resource :: Maybe ProjectId))
      assertEqual "content update resource remote release id decodes from JSON string" (Just "new-release") (versionIdText <$> (updateResourceRemoteReleaseId resource :: Maybe VersionId))
      assertEqual "content update resource remote url decodes from JSON string" (Just "https://cdn.example.com/sodium-new.jar") (urlText <$> updateResourceRemoteUrl resource)

assertMinecraftRequestWireShape :: IO ()
assertMinecraftRequestWireShape = do
  case eitherDecode "{\"version\":\"1.21.5\",\"gameDir\":\"/tmp/mc\",\"loader\":\"fabric\"}" :: Either String InstallRequest of
    Left err ->
      assertEqual ("install request json decodes: " <> err) True False
    Right request -> do
      assertEqual "install request version decodes from JSON string" "1.21.5" (installRequestVersionText request)
      assertEqual "install request game dir decodes from JSON string" (Just "/tmp/mc") (installRequestGameDirPath request)
      assertEqual "install request typed game dir remains inspectable" (Just "/tmp/mc") (gameDirPath <$> installRequestGameDir request)
  case eitherDecode "{\"version\":\"1.21.5\",\"gameDir\":\"\"}" :: Either String InstallRequest of
    Left err ->
      assertEqual ("install request empty gameDir decodes as missing: " <> err) True False
    Right request ->
      assertEqual "install request empty gameDir remains missing for route validation" Nothing (installRequestGameDirPath request)
  assertEqual "install request empty version is rejected" True (isLeft (eitherDecode "{\"version\":\"\"}" :: Either String InstallRequest))
  case eitherDecode "{\"version\":\"1.21.5\",\"gameDir\":\"/tmp/mc\",\"java\":\"/usr/bin/java\",\"install\":true}" :: Either String LaunchRequest of
    Left err ->
      assertEqual ("launch request json decodes: " <> err) True False
    Right request -> do
      assertEqual "launch request version decodes from JSON string" "1.21.5" (launchRequestVersionText request)
      assertEqual "launch request game dir decodes from JSON string" (Just "/tmp/mc") (launchRequestGameDirPath request)
      assertEqual "launch request java path wire field remains FilePath" (Just "/usr/bin/java") (launchRequestJavaPath request)

assertMojangManifestWireShape :: IO ()
assertMojangManifestWireShape = do
  case eitherDecode "{\"versions\":[{\"id\":\"1.21.5\",\"url\":\"https://piston-meta.example/1.21.5.json\",\"sha1\":\"ABCDEF\"}]}" :: Either String VersionManifest of
    Left err ->
      assertEqual ("version manifest json decodes: " <> err) True False
    Right manifest ->
      case manifestVersions manifest of
        [summary] -> do
          assertEqual "manifest version id decodes from JSON string" "1.21.5" (versionIdText (versionSummaryId summary))
          assertEqual "manifest version url decodes from JSON string" "https://piston-meta.example/1.21.5.json" (urlText (versionSummaryUrl summary))
          assertEqual "manifest version sha1 normalizes from JSON string" (Just "abcdef") (sha1Text <$> versionSummarySha1 summary)
        _ ->
          assertEqual "version manifest keeps one summary" 1 (length (manifestVersions manifest))
  assertEqual "manifest empty version id is rejected" True (isLeft (eitherDecode "{\"versions\":[{\"id\":\"\",\"url\":\"https://example.com/v.json\"}]}" :: Either String VersionManifest))
  case eitherDecode "{\"id\":\"1.21.5\",\"type\":\"release\",\"downloads\":{\"client\":{\"sha1\":\"ABCDEF\",\"size\":1,\"url\":\"https://cdn.example/client.jar\",\"path\":\"client.jar\"}},\"assetIndex\":{\"id\":\"17\",\"sha1\":\"AABBCC\",\"size\":2,\"url\":\"https://cdn.example/assets.json\",\"path\":\"indexes/17.json\"},\"libraries\":[],\"mainClass\":\"net.minecraft.client.main.Main\"}" :: Either String VersionJson of
    Left err ->
      assertEqual ("version json decodes: " <> err) True False
    Right versionJson -> do
      assertEqual "version json id decodes from JSON string" "1.21.5" (versionIdText (versionId versionJson))
      case Map.lookup "client" (versionDownloads versionJson) of
        Nothing ->
          assertEqual "version json keeps client download" True False
        Just client -> do
          assertEqual "version json client url decodes from JSON string" (Just "https://cdn.example/client.jar") (urlText <$> downloadUrl client)
          assertEqual "version json client sha1 normalizes from JSON string" (Just "abcdef") (sha1Text <$> downloadSha1 client)
          assertEqual "version json client path decodes from JSON string" (Just "client.jar") (relativePathFilePath <$> downloadPath client)
      assertEqual "version json asset index sha1 normalizes from JSON string" (Just "aabbcc") (sha1Text <$> downloadSha1 (versionAssetIndex versionJson))
  assertEqual "download info empty sha1 is rejected" True (isLeft (eitherDecode "{\"sha1\":\"\"}" :: Either String DownloadInfo))

assertContains :: String -> String -> String -> IO ()
assertContains label expected actual =
  assertEqual label True (expected `isInfixOf` actual)
