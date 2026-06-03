import Foundation

@MainActor
extension LauncherViewModel {
    func searchContent(_ query: OnlineSearchQuery, source: ContentSourceID, curseForgeAPIKey: String?) async throws -> OnlineSearchPage {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.searchContent(
            CoreContentSearchRequest(source: source, query: query, curseForgeAPIKey: curseForgeAPIKey)
        )
    }

    func sourceTest() async throws -> CoreNetworkSourceTestResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.sourceTest()
    }

    func speedTest(_ request: CoreNetworkSpeedTestRequest = .settingsDefault) async throws -> CoreNetworkSpeedTestResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.speedTest(request)
    }

    func environmentReport(_ request: CoreEnvironmentReportRequest? = nil) async throws -> CoreEnvironmentReport {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.environmentReport(request)
    }

    func resolveGraphicsTuning(_ request: CoreGraphicsTuningRequest) async throws -> CoreResolvedGraphicsTuning {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.resolveGraphicsTuning(request)
    }

    func applyGraphicsTuning(_ request: CoreGraphicsTuningRequest) async throws -> CoreGraphicsTuningApplyResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.applyGraphicsTuning(request)
    }

    func rollbackGraphicsTuning(_ request: CoreGraphicsTuningRollbackRequest) async throws -> CoreGraphicsTuningRollbackResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.rollbackGraphicsTuning(request)
    }

    func performancePackPlan(_ request: CorePerformancePackInstallRequest) async throws -> CorePerformancePackPlan {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.performancePackPlan(request)
    }

    func installPreflight(_ request: CoreLoaderInstallPreflightRequest) async throws -> CoreLoaderInstallPreflightResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        let response = try await apiClient.installPreflight(request)
        lastInstallPreflight = response
        return response
    }

    func inspectInstallPreflight(_ request: CoreLoaderInstallPreflightRequest) async throws -> CoreLoaderInstallPreflightResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.installPreflight(request)
    }

    func rollbackPerformancePack(_ request: CorePerformancePackRollbackRequest) async throws -> CorePerformancePackRollbackResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.rollbackPerformancePack(request)
    }

    func contentProject(
        id projectID: String,
        source: ContentSourceID,
        query: OnlineSearchQuery,
        curseForgeAPIKey: String?
    ) async throws -> CoreContentProjectResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        let searchRequest = CoreContentSearchRequest(source: source, query: query, curseForgeAPIKey: curseForgeAPIKey)
        return try await apiClient.contentProject(
            CoreContentProjectRequest(
                source: source,
                projectId: projectID,
                query: searchRequest,
                curseForgeAPIKey: curseForgeAPIKey
            )
        )
    }

    func resolveContentTargets(_ request: CoreContentResolveTargetsRequest) async throws -> CoreContentResolveTargetsResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.resolveContentTargets(request)
    }

    func contentInstallPlan(_ request: CoreContentInstallRequest) async throws -> CoreContentInstallPlanResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        let runtimeRequest = request.withEffectiveDownloadOptions(LauncherSettings.storedDownloadRuntimeOptions())
        return try await apiClient.contentInstallPlan(runtimeRequest)
    }

    func contentUpdatePlan(_ request: CoreContentUpdatePlanRequest) async throws -> CoreContentUpdatePlanResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.contentUpdatePlan(request)
    }

    func solveLockfile(_ request: CoreLockfileSolveRequest) async throws -> CoreLockfileSolverResult {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.solveLockfile(request)
    }

    func applyLockfile(_ request: CoreLockfileApplyRequest) async throws -> CoreLockfileApplyResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.applyLockfile(request)
    }

    func currentLockfile(gameDir: String? = nil) async throws -> CoreLockfileCurrentResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.currentLockfile(gameDir: gameDir)
    }

    func verifyLockfile(_ request: CoreLockfileVerifyRequest) async throws -> CoreLockfileVerifyResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.verifyLockfile(request)
    }

    func minecraftVersions() async throws -> [MinecraftRemoteVersion] {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.minecraftVersions()
    }

    func minecraftInstallStatus(versionIds: [String], gameDirs: [String]) async throws -> [CoreMinecraftInstallStatus] {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.minecraftInstallStatus(
            CoreMinecraftInstallStatusRequest(versionIds: versionIds, gameDirs: gameDirs)
        )
    }

    func installedMinecraftInstances(versionIds: [String], gameDirs: [String]) async throws -> [CoreInstalledMinecraftInstance] {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.installedMinecraftInstances(
            CoreMinecraftInstallStatusRequest(versionIds: versionIds, gameDirs: gameDirs)
        )
    }

    func minecraftPackage(for version: MinecraftRemoteVersion) async throws -> MinecraftVersionPackage {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.minecraftPackage(CoreMinecraftPackageRequest(id: version.id, url: version.url))
    }

    func loaderMetadata(for minecraftVersion: String) async throws -> [LoaderMetadata] {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.loaderMetadata(CoreContentLoaderRequest(minecraftVersion: minecraftVersion))
    }

    func loaderCompatibility(for minecraftVersion: String) async throws -> CoreLoaderCompatibilityResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.loaderCompatibility(CoreContentLoaderRequest(minecraftVersion: minecraftVersion))
    }

    func configurationCapabilities(for instance: GameInstance) async throws -> CoreConfigurationCapabilities {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.configurationCapabilities(
            CoreGameConfigurationRequest(instance: instance)
        )
    }

    func launchLibrary(instances: [GameInstance]) async throws -> CoreLaunchLibraryResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.launchLibrary(CoreLaunchLibraryRequest(instances: instances))
    }

    func versionSwitchPreflight(for instance: GameInstance, targetMinecraftVersion: String) async throws -> CoreVersionSwitchPreflightResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.versionSwitchPreflight(
            CoreVersionSwitchPreflightRequest(
                configuration: CoreGameConfigurationRequest(instance: instance),
                targetMinecraftVersion: targetMinecraftVersion
            )
        )
    }

    func modpackPreflight(sourceType: String, sourcePath: String?, targetGameDir: String?) async throws -> CoreModpackPreflightResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.modpackPreflight(
            CoreModpackPreflightRequest(sourceType: sourceType, sourcePath: sourcePath, targetGameDir: targetGameDir)
        )
    }

    func modpackImport(sourceType: String, sourcePath: String, targetGameDir: String) async throws -> CoreModpackImportResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.modpackImport(
            CoreModpackImportRequest(sourceType: sourceType, sourcePath: sourcePath, targetGameDir: targetGameDir)
        )
    }

    func exportBackupPreflight(for instance: GameInstance, kind: String, targetPath: String? = nil) async throws -> CoreExportBackupPreflightResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.exportBackupPreflight(
            CoreExportBackupPreflightRequest(
                configuration: CoreGameConfigurationRequest(instance: instance),
                kind: kind,
                targetPath: targetPath
            )
        )
    }

    func localResources(gameDir: String, kind: ManagedAssetKind, loader: LoaderKind) async throws -> [CoreManagedAsset] {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.localResources(
            CoreLocalResourceScanRequest(gameDir: gameDir, kind: kind, loader: loader)
        )
    }

    func toggleLocalResource(path: String) async throws -> CoreLocalResourceMutationResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.toggleLocalResource(CoreLocalResourcePathRequest(path: path))
    }

    func deleteLocalResource(path: String) async throws -> CoreLocalResourceMutationResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.deleteLocalResource(CoreLocalResourcePathRequest(path: path))
    }

    func importLocalResource(sourcePath: String, gameDir: String, kind: ManagedAssetKind) async throws -> CoreLocalResourceMutationResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.importLocalResource(
            CoreLocalResourceImportRequest(sourcePath: sourcePath, gameDir: gameDir, kind: kind)
        )
    }

    func archiveLocalDirectory(sourcePath: String, targetPath: String) async throws -> CoreLocalResourceMutationResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.archiveLocalDirectory(
            CoreLocalArchiveRequest(sourcePath: sourcePath, targetPath: targetPath)
        )
    }

    func importLocalArchive(archivePath: String, targetDir: String, deleteArchive: Bool = false) async throws -> CoreLocalResourceMutationResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.importLocalArchive(
            CoreLocalArchiveImportRequest(archivePath: archivePath, targetDir: targetDir, deleteArchive: deleteArchive)
        )
    }

    func cleanMinecraftVersion(version: String, gameDir: String) async throws -> CoreLocalResourceMutationResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.cleanMinecraftVersion(
            CoreMinecraftCleanVersionRequest(version: version, gameDir: gameDir)
        )
    }

    func mutateMinecraftVersionStorage(version: String, gameDir: String, action: CoreMinecraftVersionStorageAction) async throws -> CoreLocalResourceMutationResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.mutateMinecraftVersionStorage(
            CoreMinecraftVersionStorageRequest(version: version, gameDir: gameDir, action: action)
        )
    }

    func taskHistory(statuses: [String]? = nil, kinds: [String]? = nil, limit: Int = 50, offset: Int = 0) async throws -> CoreTaskHistoryResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.taskHistory(statuses: statuses, kinds: kinds, limit: limit, offset: offset)
    }

    func clearTaskHistory(statuses: [String]? = nil, olderThanDays: Int? = nil, keepFailed: Bool? = nil) async throws -> CoreTaskHistoryClearResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.clearTaskHistory(
            CoreTaskHistoryClearRequest(statuses: statuses, olderThanDays: olderThanDays, keepFailed: keepFailed)
        )
    }
}
