import Foundation

@MainActor
extension LauncherViewModel {
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
}
