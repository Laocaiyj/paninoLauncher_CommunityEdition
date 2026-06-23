import Foundation

extension LauncherApiClient {
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
}
