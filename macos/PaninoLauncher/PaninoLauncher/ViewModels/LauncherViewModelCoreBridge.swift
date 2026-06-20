import Foundation

@MainActor
extension LauncherViewModel {
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
}
