import Foundation

extension LauncherApiClient {
    func contentInstallPlan(_ request: CoreContentInstallRequest) async throws -> CoreContentInstallPlanResponse {
        try await send(path: "/api/v1/content/install-plan", method: "POST", body: request)
    }

    func contentUpdatePlan(_ request: CoreContentUpdatePlanRequest) async throws -> CoreContentUpdatePlanResponse {
        try await send(path: "/api/v1/content/update-plan", method: "POST", body: request)
    }

    func solveLockfile(_ request: CoreLockfileSolveRequest) async throws -> CoreLockfileSolverResult {
        try await send(path: "/api/v1/lockfile/solve", method: "POST", body: request)
    }

    func applyLockfile(_ request: CoreLockfileApplyRequest) async throws -> CoreLockfileApplyResponse {
        try await send(path: "/api/v1/lockfile/apply", method: "POST", body: request)
    }

    func currentLockfile(gameDir: String? = nil) async throws -> CoreLockfileCurrentResponse {
        var components = URLComponents(url: endpoint.baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/v1/lockfile/current"
        if let gameDir = Self.sanitizedGameDir(gameDir) {
            components.queryItems = [URLQueryItem(name: "gameDir", value: gameDir)]
        }
        guard let url = components.url else { throw LauncherApiError.invalidResponse }
        return try await send(authorizedRequest(url: url, method: "GET"))
    }

    func diffLockfile(_ request: CoreLockfileDiffRequest) async throws -> CoreLockfileChangeset {
        try await send(path: "/api/v1/lockfile/diff", method: "POST", body: request)
    }

    func explainLockfile(_ request: CoreLockfileSolveRequest) async throws -> CoreLockfileExplain {
        try await send(path: "/api/v1/lockfile/explain", method: "POST", body: request)
    }

    func verifyLockfile(_ request: CoreLockfileVerifyRequest) async throws -> CoreLockfileVerifyResponse {
        try await send(path: "/api/v1/lockfile/verify", method: "POST", body: request)
    }

    func installContent(_ request: CoreContentInstallRequest) async throws -> TaskAccepted {
        try await send(path: "/api/v1/content/install", method: "POST", body: request)
    }

    func resolveContentTargets(_ request: CoreContentResolveTargetsRequest) async throws -> CoreContentResolveTargetsResponse {
        try await send(path: "/api/v1/content/resolve-targets", method: "POST", body: request)
    }

    func searchContent(_ request: CoreContentSearchRequest) async throws -> OnlineSearchPage {
        try await send(path: "/api/v1/content/search", method: "POST", body: request)
    }

    func contentProject(_ request: CoreContentProjectRequest) async throws -> CoreContentProjectResponse {
        try await send(path: "/api/v1/content/project", method: "POST", body: request)
    }

    func minecraftVersions() async throws -> [MinecraftRemoteVersion] {
        try await send(path: "/api/v1/content/minecraft/versions", method: "GET")
    }

    func minecraftInstallStatus(_ request: CoreMinecraftInstallStatusRequest) async throws -> [CoreMinecraftInstallStatus] {
        try await send(path: "/api/v1/content/minecraft/install-status", method: "POST", body: request)
    }

    func installedMinecraftInstances(_ request: CoreMinecraftInstallStatusRequest) async throws -> [CoreInstalledMinecraftInstance] {
        try await send(path: "/api/v1/content/minecraft/installed-instances", method: "POST", body: request)
    }

    func minecraftPackage(_ request: CoreMinecraftPackageRequest) async throws -> MinecraftVersionPackage {
        try await send(path: "/api/v1/content/minecraft/package", method: "POST", body: request)
    }

    func loaderMetadata(_ request: CoreContentLoaderRequest) async throws -> [LoaderMetadata] {
        try await send(path: "/api/v1/content/loaders", method: "POST", body: request)
    }

    func loaderCompatibility(_ request: CoreContentLoaderRequest) async throws -> CoreLoaderCompatibilityResponse {
        try await send(path: "/api/v1/content/loader-compatibility", method: "POST", body: request)
    }

    func configurationCapabilities(_ request: CoreGameConfigurationRequest) async throws -> CoreConfigurationCapabilities {
        try await send(path: "/api/v1/config/capabilities", method: "POST", body: request)
    }

    func launchLibrary(_ request: CoreLaunchLibraryRequest) async throws -> CoreLaunchLibraryResponse {
        try await send(path: "/api/v1/config/launch-library", method: "POST", body: request)
    }

    func versionSwitchPreflight(_ request: CoreVersionSwitchPreflightRequest) async throws -> CoreVersionSwitchPreflightResponse {
        try await send(path: "/api/v1/config/version-switch-preflight", method: "POST", body: request)
    }

    func modpackPreflight(_ request: CoreModpackPreflightRequest) async throws -> CoreModpackPreflightResponse {
        try await send(path: "/api/v1/content/modpack/preflight", method: "POST", body: request)
    }

    func modpackImport(_ request: CoreModpackImportRequest) async throws -> CoreModpackImportResponse {
        try await send(path: "/api/v1/content/modpack/import", method: "POST", body: request)
    }

    func exportBackupPreflight(_ request: CoreExportBackupPreflightRequest) async throws -> CoreExportBackupPreflightResponse {
        try await send(path: "/api/v1/config/export-preflight", method: "POST", body: request)
    }
}
