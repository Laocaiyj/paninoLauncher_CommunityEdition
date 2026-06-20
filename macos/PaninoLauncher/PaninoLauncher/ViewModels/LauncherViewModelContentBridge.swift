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
}
