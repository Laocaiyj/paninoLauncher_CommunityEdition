import Foundation

extension LauncherApiClient {
    func localResources(_ request: CoreLocalResourceScanRequest) async throws -> [CoreManagedAsset] {
        try await send(path: "/api/v1/content/local/scan", method: "POST", body: request)
    }

    func toggleLocalResource(_ request: CoreLocalResourcePathRequest) async throws -> CoreLocalResourceMutationResponse {
        try await send(path: "/api/v1/content/local/toggle", method: "POST", body: request)
    }

    func deleteLocalResource(_ request: CoreLocalResourcePathRequest) async throws -> CoreLocalResourceMutationResponse {
        try await send(path: "/api/v1/content/local/delete", method: "POST", body: request)
    }

    func importLocalResource(_ request: CoreLocalResourceImportRequest) async throws -> CoreLocalResourceMutationResponse {
        try await send(path: "/api/v1/content/local/import", method: "POST", body: request)
    }

    func archiveLocalDirectory(_ request: CoreLocalArchiveRequest) async throws -> CoreLocalResourceMutationResponse {
        try await send(path: "/api/v1/content/local/archive", method: "POST", body: request)
    }

    func importLocalArchive(_ request: CoreLocalArchiveImportRequest) async throws -> CoreLocalResourceMutationResponse {
        try await send(path: "/api/v1/content/local/import-archive", method: "POST", body: request)
    }

    func cleanMinecraftVersion(_ request: CoreMinecraftCleanVersionRequest) async throws -> CoreLocalResourceMutationResponse {
        try await send(path: "/api/v1/content/minecraft/clean-version", method: "POST", body: request)
    }

    func mutateMinecraftVersionStorage(_ request: CoreMinecraftVersionStorageRequest) async throws -> CoreLocalResourceMutationResponse {
        try await send(path: "/api/v1/content/minecraft/version-storage", method: "POST", body: request)
    }
}
