import Foundation

@MainActor
extension LauncherViewModel {
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
}
