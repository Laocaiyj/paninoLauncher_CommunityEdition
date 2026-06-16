import Foundation

enum LauncherApiError: LocalizedError, Equatable {
    case invalidResponse
    case unexpectedStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Core returned an invalid HTTP response."
        case .unexpectedStatus(let statusCode, let body):
            return "Core returned HTTP \(statusCode): \(body)"
        }
    }
}

struct LauncherApiClient: Equatable {
    let endpoint: CoreEndpoint

    func health() async throws -> HealthResponse {
        try await send(path: "/api/v1/health", method: "GET")
    }

    func effectiveNetworkConfiguration() async throws -> CoreNetworkEffectiveConfiguration {
        try await send(path: "/api/v1/network/effective-config", method: "GET")
    }

    func sourceTest() async throws -> CoreNetworkSourceTestResponse {
        try await send(path: "/api/v1/network/source-test", method: "GET")
    }

    func speedTest(_ request: CoreNetworkSpeedTestRequest) async throws -> CoreNetworkSpeedTestResponse {
        try await send(path: "/api/v1/network/speed-test", method: "POST", body: request)
    }

    func resolveGraphicsTuning(_ request: CoreGraphicsTuningRequest) async throws -> CoreResolvedGraphicsTuning {
        try await send(path: "/api/v1/graphics/tuning/resolve", method: "POST", body: request)
    }

    func applyGraphicsTuning(_ request: CoreGraphicsTuningRequest) async throws -> CoreGraphicsTuningApplyResponse {
        try await send(path: "/api/v1/graphics/tuning/apply", method: "POST", body: request)
    }

    func rollbackGraphicsTuning(_ request: CoreGraphicsTuningRollbackRequest) async throws -> CoreGraphicsTuningRollbackResponse {
        try await send(path: "/api/v1/graphics/tuning/rollback", method: "POST", body: request)
    }

    func performancePackPlan(_ request: CorePerformancePackInstallRequest) async throws -> CorePerformancePackPlan {
        try await send(path: "/api/v1/performance/pack/plan", method: "POST", body: request)
    }

    func installPerformancePack(_ request: CorePerformancePackInstallRequest) async throws -> TaskAccepted {
        try await send(path: "/api/v1/performance/pack/install", method: "POST", body: request)
    }

    func rollbackPerformancePack(_ request: CorePerformancePackRollbackRequest) async throws -> CorePerformancePackRollbackResponse {
        try await send(path: "/api/v1/performance/pack/rollback", method: "POST", body: request)
    }

    func resolvePerformanceProfile(_ request: CorePerformanceProfileResolveRequest) async throws -> CorePerformanceRecommendation {
        try await send(path: "/api/v1/performance/profile/resolve", method: "POST", body: request)
    }

    func performanceCandidate(_ request: CorePerformanceCandidateRequest) async throws -> CorePerformanceCandidateResponse {
        try await send(path: "/api/v1/performance/profile/candidate", method: "POST", body: request)
    }

    func applyPerformanceProfile(_ request: CorePerformanceApplyRequest) async throws -> CorePerformanceApplyResponse {
        try await send(path: "/api/v1/performance/profile/apply", method: "POST", body: request)
    }

    func rollbackPerformanceProfile(_ request: CorePerformanceRollbackRequest) async throws -> CorePerformanceRollbackResponse {
        try await send(path: "/api/v1/performance/profile/rollback", method: "POST", body: request)
    }

    func environmentReport(_ request: CoreEnvironmentReportRequest? = nil) async throws -> CoreEnvironmentReport {
        var components = URLComponents(url: endpoint.baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/v1/environment/report"
        var queryItems: [URLQueryItem] = []
        if let gameDir = Self.sanitizedGameDir(request?.gameDir) {
            queryItems.append(URLQueryItem(name: "gameDir", value: gameDir))
        }
        if let version = request?.version?.trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty {
            queryItems.append(URLQueryItem(name: "version", value: version))
        }
        if let loader = request?.loader?.trimmingCharacters(in: .whitespacesAndNewlines), !loader.isEmpty {
            queryItems.append(URLQueryItem(name: "loader", value: loader))
        }
        if let loaderVersion = request?.loaderVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !loaderVersion.isEmpty {
            queryItems.append(URLQueryItem(name: "loaderVersion", value: loaderVersion))
        }
        if let memoryMb = request?.memoryMb {
            queryItems.append(URLQueryItem(name: "memoryMb", value: String(memoryMb)))
        }
        if let memoryPolicy = request?.memoryPolicy {
            queryItems.append(URLQueryItem(name: "memoryPolicy", value: memoryPolicy))
        }
        if let jvmProfile = request?.jvmProfile {
            queryItems.append(URLQueryItem(name: "jvmProfile", value: jvmProfile))
        }
        if let customMemoryMb = request?.customMemoryMb {
            queryItems.append(URLQueryItem(name: "customMemoryMb", value: String(customMemoryMb)))
        }
        if let customJvmArgs = request?.customJvmArgs, !customJvmArgs.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "customJvmArgs", value: customJvmArgs))
        }
        if let modCount = request?.modCount {
            queryItems.append(URLQueryItem(name: "modCount", value: String(modCount)))
        }
        if let resourcePackCount = request?.resourcePackCount {
            queryItems.append(URLQueryItem(name: "resourcePackCount", value: String(resourcePackCount)))
        }
        if let resourcePackScale = request?.resourcePackScale?.trimmingCharacters(in: .whitespacesAndNewlines), !resourcePackScale.isEmpty {
            queryItems.append(URLQueryItem(name: "resourcePackScale", value: resourcePackScale))
        }
        if let shaderPackCount = request?.shaderPackCount {
            queryItems.append(URLQueryItem(name: "shaderPackCount", value: String(shaderPackCount)))
        }
        if let graphicsProfile = request?.graphicsProfile?.trimmingCharacters(in: .whitespacesAndNewlines), !graphicsProfile.isEmpty {
            queryItems.append(URLQueryItem(name: "graphicsProfile", value: graphicsProfile))
        }
        if let graphicsHardwareTier = request?.graphicsHardwareTier?.trimmingCharacters(in: .whitespacesAndNewlines), !graphicsHardwareTier.isEmpty {
            queryItems.append(URLQueryItem(name: "graphicsHardwareTier", value: graphicsHardwareTier))
        }
        if let displayScale = request?.displayScale {
            queryItems.append(URLQueryItem(name: "displayScale", value: String(displayScale)))
        }
        if let displayWidth = request?.displayWidth {
            queryItems.append(URLQueryItem(name: "displayWidth", value: String(displayWidth)))
        }
        if let displayHeight = request?.displayHeight {
            queryItems.append(URLQueryItem(name: "displayHeight", value: String(displayHeight)))
        }
        if let refreshRate = request?.refreshRate {
            queryItems.append(URLQueryItem(name: "refreshRate", value: String(refreshRate)))
        }
        if let isBuiltinDisplay = request?.isBuiltinDisplay {
            queryItems.append(URLQueryItem(name: "isBuiltinDisplay", value: String(isBuiltinDisplay)))
        }
        if let shaderEnabled = request?.shaderEnabled {
            queryItems.append(URLQueryItem(name: "shaderEnabled", value: String(shaderEnabled)))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw LauncherApiError.invalidResponse }
        return try await send(authorizedRequest(url: url, method: "GET"))
    }

    func evaluateCompatibility(_ request: CoreCompatibilityEvaluateRequest) async throws -> CoreCompatibilityReport {
        try await send(path: "/api/v1/compatibility/evaluate", method: "POST", body: request)
    }

    func explainCompatibility(_ request: CoreCompatibilityEvaluateRequest) async throws -> CoreCompatibilityExplanation {
        try await send(path: "/api/v1/compatibility/explain", method: "POST", body: request)
    }

    func install(
        version: String,
        gameDir: String,
        loader: String? = nil,
        loaderVersion: String? = nil,
        shaderLoader: String? = nil,
        shaderVersion: String? = nil,
        instanceName: String? = nil,
        downloadOptions: CoreDownloadRuntimeOptions = CoreDownloadRuntimeOptions(concurrency: 32, retryCount: 3)
    ) async throws -> TaskAccepted {
        let body = InstallRequest(
            version: version,
            gameDir: gameDir,
            loader: loader,
            loaderVersion: loaderVersion,
            shaderLoader: shaderLoader,
            shaderVersion: shaderVersion,
            instanceName: instanceName,
            concurrency: downloadOptions.concurrency,
            retryCount: downloadOptions.retryCount,
            download: downloadOptions
        )
        return try await send(path: "/api/v1/install", method: "POST", body: body)
    }

    func installPreflight(_ request: CoreLoaderInstallPreflightRequest) async throws -> CoreLoaderInstallPreflightResponse {
        let downloadOptions = CoreDownloadRuntimeOptions(concurrency: 32, retryCount: 3)
        let body = InstallRequest(
            version: request.version,
            gameDir: request.gameDir ?? "",
            loader: request.loader,
            loaderVersion: request.loaderVersion,
            shaderLoader: request.shaderLoader,
            shaderVersion: request.shaderVersion,
            instanceName: request.instanceName,
            concurrency: downloadOptions.concurrency,
            retryCount: downloadOptions.retryCount,
            download: downloadOptions
        )
        return try await send(path: "/api/v1/install/preflight", method: "POST", body: body)
    }

    func launch(
        version: String,
        memoryMb: Int,
        javaPath: String?,
        account: MinecraftAccount?,
        gameDir: String,
        instanceId: String? = nil,
        loader: String? = nil,
        memoryPolicy: String? = nil,
        jvmProfile: String? = nil,
        customMemoryMb: Int? = nil,
        customJvmArguments: [String] = [],
        installBeforeLaunch: Bool = true,
        downloadOptions: CoreDownloadRuntimeOptions = CoreDownloadRuntimeOptions(concurrency: 32, retryCount: 3),
        jvmArguments: [String] = [],
        windowWidth: Int? = nil,
        windowHeight: Int? = nil
    ) async throws -> TaskAccepted {
        let body = LaunchRequest(
            version: version,
            gameDir: gameDir,
            memoryMb: memoryMb,
            java: javaPath,
            instanceId: instanceId,
            loader: loader,
            memoryPolicy: memoryPolicy,
            jvmProfile: jvmProfile,
            customMemoryMb: customMemoryMb,
            username: account?.name,
            uuid: account?.id,
            accessToken: account?.accessToken,
            jvmArgs: jvmArguments,
            customJvmArgs: customJvmArguments,
            windowWidth: windowWidth,
            windowHeight: windowHeight,
            concurrency: downloadOptions.concurrency,
            retryCount: downloadOptions.retryCount,
            download: downloadOptions,
            install: installBeforeLaunch
        )
        return try await send(path: "/api/v1/launch", method: "POST", body: body)
    }

    func task(id: String) async throws -> TaskSnapshot {
        try await send(path: "/api/v1/tasks/\(id)", method: "GET")
    }

    func taskHistory(statuses: [String]? = nil, kinds: [String]? = nil, limit: Int = 50, offset: Int = 0) async throws -> CoreTaskHistoryResponse {
        var components = URLComponents(url: endpoint.baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/v1/tasks/history"
        var queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        if let statuses, !statuses.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: statuses.joined(separator: ",")))
        }
        if let kinds, !kinds.isEmpty {
            queryItems.append(URLQueryItem(name: "kind", value: kinds.joined(separator: ",")))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw LauncherApiError.invalidResponse }
        return try await send(authorizedRequest(url: url, method: "GET"))
    }

    func clearTaskHistory(_ request: CoreTaskHistoryClearRequest) async throws -> CoreTaskHistoryClearResponse {
        try await send(path: "/api/v1/tasks/history/clear", method: "POST", body: request)
    }

    func cancelTask(id: String) async throws -> TaskAccepted {
        try await send(path: "/api/v1/tasks/\(id)/cancel", method: "POST")
    }

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

    func taowaFrpProfiles() async throws -> CoreTaowaProfilesResponse {
        try await send(path: "/api/v1/taowa/frp/profiles", method: "GET")
    }

    func createTaowaFrpProfile(_ request: CoreTaowaFrpProfileRequest) async throws -> CoreTaowaFrpProfile {
        try await send(path: "/api/v1/taowa/frp/profiles", method: "POST", body: request)
    }

    func updateTaowaFrpProfile(profileId: String, request: CoreTaowaFrpProfileRequest) async throws -> CoreTaowaFrpProfile {
        try await send(path: "/api/v1/taowa/frp/profiles/\(Self.pathSegment(profileId))", method: "PUT", body: request)
    }

    func deleteTaowaFrpProfile(profileId: String) async throws -> CoreTaowaFrpProfileDeleteResponse {
        try await send(path: "/api/v1/taowa/frp/profiles/\(Self.pathSegment(profileId))", method: "DELETE")
    }

    func testTaowaFrpProfile(profileId: String) async throws -> CoreTaowaFrpProfileTestResponse {
        try await send(path: "/api/v1/taowa/frp/profiles/\(Self.pathSegment(profileId))/test", method: "POST")
    }

    func taowaLanDetect(_ request: CoreTaowaLanDetectRequest) async throws -> CoreTaowaLanPortDetection {
        try await send(path: "/api/v1/taowa/lan/detect", method: "POST", body: request)
    }

    func taowaValidatePort(_ request: CoreTaowaLanValidatePortRequest) async throws -> CoreTaowaLanPortDetection {
        try await send(path: "/api/v1/taowa/lan/validate-port", method: "POST", body: request)
    }

    func taowaSessions() async throws -> CoreTaowaSessionsResponse {
        try await send(path: "/api/v1/taowa/sessions", method: "GET")
    }

    func taowaSession(sessionId: String) async throws -> CoreTaowaSession {
        try await send(path: "/api/v1/taowa/sessions/\(Self.pathSegment(sessionId))", method: "GET")
    }

    func startTaowaSession(_ request: CoreTaowaSessionStartRequest) async throws -> CoreTaowaSession {
        try await send(path: "/api/v1/taowa/sessions/start", method: "POST", body: request)
    }

    func stopTaowaSession(sessionId: String) async throws -> CoreTaowaSession {
        try await send(path: "/api/v1/taowa/sessions/\(Self.pathSegment(sessionId))/stop", method: "POST")
    }

    func taowaSessionLog(sessionId: String) async throws -> CoreTaowaSessionLogResponse {
        try await send(path: "/api/v1/taowa/sessions/\(Self.pathSegment(sessionId))/log", method: "GET")
    }

    func taowaSessionHealth(sessionId: String) async throws -> CoreTaowaSessionHealthResponse {
        try await send(path: "/api/v1/taowa/sessions/\(Self.pathSegment(sessionId))/health", method: "GET")
    }

    func clearTaowaSessionHistory(_ request: CoreTaowaSessionHistoryClearRequest) async throws -> CoreTaowaSessionHistoryClearResponse {
        try await send(path: "/api/v1/taowa/sessions/clear-history", method: "POST", body: request)
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

    func checkJavaRuntime(_ request: CoreJavaCheckRequest) async throws -> JavaRuntimeStatus {
        try await send(path: "/api/v1/runtime/java/check", method: "POST", body: request)
    }

    func scanJavaRuntimes() async throws -> [JavaRuntimeCandidate] {
        try await send(path: "/api/v1/runtime/java/scan", method: "GET")
    }

    func managedJavaRuntimes() async throws -> CoreJavaManagedResponse {
        try await send(path: "/api/v1/runtime/java/managed", method: "GET")
    }

    func resolveJavaRuntime(_ request: CoreJavaRuntimeResolveRequest) async throws -> CoreJavaRuntimeResolveResponse {
        try await send(path: "/api/v1/runtime/java/resolve", method: "POST", body: request)
    }

    func javaRuntimeCatalog(featureVersion: Int, os: String? = nil, arch: String? = nil, imageType: String = "jre", provider: String? = nil) async throws -> [CoreJavaRuntimeCatalogItem] {
        var components = URLComponents(url: endpoint.baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/v1/runtime/java/catalog"
        var queryItems = [
            URLQueryItem(name: "featureVersion", value: String(featureVersion)),
            URLQueryItem(name: "imageType", value: imageType)
        ]
        if let os, !os.isEmpty {
            queryItems.append(URLQueryItem(name: "os", value: os))
        }
        if let arch, !arch.isEmpty {
            queryItems.append(URLQueryItem(name: "arch", value: arch))
        }
        if let provider, !provider.isEmpty {
            queryItems.append(URLQueryItem(name: "provider", value: provider))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw LauncherApiError.invalidResponse }
        return try await send(authorizedRequest(url: url, method: "GET"))
    }

    func selectJavaRuntime(_ request: CoreJavaRuntimeSelectRequest) async throws -> CoreJavaRuntimeSelectResponse {
        try await send(path: "/api/v1/runtime/java/select", method: "POST", body: request)
    }

    func installJavaRuntime(_ request: CoreJavaRuntimeInstallRequest) async throws -> TaskAccepted {
        try await send(path: "/api/v1/runtime/java/install", method: "POST", body: request)
    }

    func importJavaRuntime(_ request: CoreJavaRuntimeImportRequest) async throws -> CoreJavaManagedRuntime {
        try await send(path: "/api/v1/runtime/java/import", method: "POST", body: request)
    }

    func cleanupJavaRuntimes() async throws -> CoreJavaRuntimeCleanupResponse {
        try await send(path: "/api/v1/runtime/java/cleanup", method: "POST")
    }

    func verifyJavaRuntime(id: String) async throws -> CoreJavaManagedRuntime {
        try await send(path: "/api/v1/runtime/java/verify", method: "POST", body: CoreJavaRuntimeVerifyRequest(id: id))
    }

    func deleteJavaRuntime(id: String) async throws -> CoreJavaRuntimeDeleteResponse {
        let escapedID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        return try await send(path: "/api/v1/runtime/java/managed/\(escapedID)", method: "DELETE")
    }

    func deleteLocalJavaRuntime(path: String) async throws -> CoreJavaRuntimeLocalDeleteResponse {
        try await send(
            path: "/api/v1/runtime/java/local/delete",
            method: "POST",
            body: CoreJavaRuntimeLocalDeleteRequest(path: path)
        )
    }

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

    func shutdown() async throws {
        let _: ShutdownResponse = try await send(path: "/api/v1/shutdown", method: "POST")
    }

    func authorizedRequest(path: String, method: String = "GET") -> URLRequest {
        authorizedRequest(url: url(for: path), method: method)
    }

    func authorizedRequest(url: URL, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(endpoint.sessionToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func send<Response: Decodable>(path: String, method: String, body: some Encodable) async throws -> Response {
        var request = authorizedRequest(path: path, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request)
    }

    private func send<Response: Decodable>(path: String, method: String) async throws -> Response {
        try await send(authorizedRequest(path: path, method: method))
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LauncherApiError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LauncherApiError.unexpectedStatus(httpResponse.statusCode, body)
        }

        return try Self.jsonDecoder.decode(Response.self, from: data)
    }

    private func url(for path: String) -> URL {
        var components = URLComponents(url: endpoint.baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        return components.url!
    }

    private static func sanitizedGameDir(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func pathSegment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
    }

    private static var jsonDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = fractionalFormatter.date(from: value) ?? formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date \(value)")
        }
        return decoder
    }
}

private struct InstallRequest: Encodable {
    let version: String
    let gameDir: String
    let loader: String?
    let loaderVersion: String?
    let shaderLoader: String?
    let shaderVersion: String?
    let instanceName: String?
    let concurrency: Int
    let retryCount: Int
    let download: CoreDownloadRuntimeOptions
}

private struct LaunchRequest: Encodable {
    let version: String
    let gameDir: String
    let memoryMb: Int
    let java: String?
    let instanceId: String?
    let loader: String?
    let memoryPolicy: String?
    let jvmProfile: String?
    let customMemoryMb: Int?
    let username: String?
    let uuid: String?
    let accessToken: String?
    let jvmArgs: [String]
    let customJvmArgs: [String]
    let windowWidth: Int?
    let windowHeight: Int?
    let concurrency: Int
    let retryCount: Int
    let download: CoreDownloadRuntimeOptions
    let install: Bool
}

private struct ShutdownResponse: Decodable {
    let status: String
}
