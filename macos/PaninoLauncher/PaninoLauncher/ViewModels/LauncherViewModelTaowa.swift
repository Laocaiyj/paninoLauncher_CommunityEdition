import Foundation

@MainActor
extension LauncherViewModel {
    func taowaFrpProfiles() async throws -> CoreTaowaProfilesResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.taowaFrpProfiles()
    }

    func saveTaowaFrpProfile(profileId: String?, request: CoreTaowaFrpProfileRequest) async throws -> CoreTaowaFrpProfile {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        if let profileId, !profileId.isEmpty {
            return try await apiClient.updateTaowaFrpProfile(profileId: profileId, request: request)
        }
        return try await apiClient.createTaowaFrpProfile(request)
    }

    func deleteTaowaFrpProfile(profileId: String) async throws -> CoreTaowaFrpProfileDeleteResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.deleteTaowaFrpProfile(profileId: profileId)
    }

    func testTaowaFrpProfile(profileId: String) async throws -> CoreTaowaFrpProfileTestResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.testTaowaFrpProfile(profileId: profileId)
    }

    func taowaLanDetect(_ request: CoreTaowaLanDetectRequest) async throws -> CoreTaowaLanPortDetection {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.taowaLanDetect(request)
    }

    func taowaValidatePort(_ request: CoreTaowaLanValidatePortRequest) async throws -> CoreTaowaLanPortDetection {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.taowaValidatePort(request)
    }

    func taowaSessions() async throws -> CoreTaowaSessionsResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.taowaSessions()
    }

    func taowaSession(sessionId: String) async throws -> CoreTaowaSession {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.taowaSession(sessionId: sessionId)
    }

    func startTaowaSession(_ request: CoreTaowaSessionStartRequest) async throws -> CoreTaowaSession {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.startTaowaSession(request)
    }

    func stopTaowaSession(sessionId: String) async throws -> CoreTaowaSession {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.stopTaowaSession(sessionId: sessionId)
    }

    func taowaSessionLog(sessionId: String) async throws -> CoreTaowaSessionLogResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.taowaSessionLog(sessionId: sessionId)
    }

    func taowaSessionHealth(sessionId: String) async throws -> CoreTaowaSessionHealthResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.taowaSessionHealth(sessionId: sessionId)
    }

    func clearTaowaSessionHistory(_ request: CoreTaowaSessionHistoryClearRequest) async throws -> CoreTaowaSessionHistoryClearResponse {
        try await ensureClient()
        guard let apiClient else { throw LauncherApiError.invalidResponse }
        return try await apiClient.clearTaowaSessionHistory(request)
    }
}
