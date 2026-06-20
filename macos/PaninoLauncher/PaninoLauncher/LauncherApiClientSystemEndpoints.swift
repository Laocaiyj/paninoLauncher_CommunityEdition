import Foundation

extension LauncherApiClient {
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

    func shutdown() async throws {
        let _: LauncherApiShutdownResponse = try await send(path: "/api/v1/shutdown", method: "POST")
    }
}
