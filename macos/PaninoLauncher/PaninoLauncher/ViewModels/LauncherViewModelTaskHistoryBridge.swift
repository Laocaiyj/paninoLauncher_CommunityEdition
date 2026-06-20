import Foundation

@MainActor
extension LauncherViewModel {
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
