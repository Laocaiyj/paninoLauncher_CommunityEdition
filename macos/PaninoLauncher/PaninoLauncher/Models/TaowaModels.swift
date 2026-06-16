import Foundation

struct CoreTaowaProfilesResponse: Codable, Equatable, Sendable {
    let profiles: [CoreTaowaFrpProfile]
}

struct CoreTaowaFrpProfile: Codable, Equatable, Identifiable, Sendable {
    let profileId: String
    let displayName: String
    let serverAddr: String
    let serverPort: Int
    let token: String?
    let hasToken: Bool
    let remotePort: Int
    let protocolName: String
    let frpcPath: String
    let enabled: Bool
    let createdAt: Date
    let updatedAt: Date

    var id: String { profileId }
    var remoteAddress: String { "\(serverAddr):\(remotePort)" }

    private enum CodingKeys: String, CodingKey {
        case profileId
        case displayName
        case serverAddr
        case serverPort
        case token
        case hasToken
        case remotePort
        case protocolName = "protocol"
        case frpcPath
        case enabled
        case createdAt
        case updatedAt
    }
}

struct CoreTaowaFrpProfileRequest: Codable, Equatable, Sendable {
    let profileId: String?
    let displayName: String
    let serverAddr: String
    let serverPort: Int
    let token: String?
    let remotePort: Int
    let protocolName: String
    let frpcPath: String
    let enabled: Bool

    private enum CodingKeys: String, CodingKey {
        case profileId
        case displayName
        case serverAddr
        case serverPort
        case token
        case remotePort
        case protocolName = "protocol"
        case frpcPath
        case enabled
    }
}

struct CoreTaowaFrpProfileDeleteResponse: Codable, Equatable, Sendable {
    let profileId: String
    let deleted: Bool
}

struct CoreTaowaFrpProfileTestResponse: Codable, Equatable, Sendable {
    let profileId: String
    let ok: Bool
    let checks: [CoreTaowaFrpProfileTestCheck]
    let diagnostics: [CoreDiagnostic]
}

struct CoreTaowaFrpProfileTestCheck: Codable, Equatable, Identifiable, Sendable {
    let name: String
    let ok: Bool
    let message: String

    var id: String { name }
}

struct CoreTaowaLanDetectRequest: Codable, Equatable, Sendable {
    let instanceId: String?
    let gameDir: String
    let timeoutSeconds: Int?
}

struct CoreTaowaLanValidatePortRequest: Codable, Equatable, Sendable {
    let instanceId: String?
    let gameDir: String?
    let localPort: Int
}

struct CoreTaowaLanPortDetection: Codable, Equatable, Sendable {
    let instanceId: String?
    let gameDir: String
    let logPath: String
    let status: String
    let detectedPort: Int?
    let evidence: [CoreTaowaLanEvidence]
    let diagnostics: [CoreDiagnostic]

    var isDetected: Bool { status == "detected" && detectedPort != nil }
}

struct CoreTaowaLanEvidence: Codable, Equatable, Sendable, Identifiable {
    let kind: String
    let message: String
    let port: Int?

    var id: String { "\(kind)|\(message)|\(port.map(String.init) ?? "-")" }
}

struct CoreTaowaSessionStartRequest: Codable, Equatable, Sendable {
    let profileId: String
    let instanceId: String?
    let gameDir: String
    let localPort: Int
}

struct CoreTaowaSessionsResponse: Codable, Equatable, Sendable {
    let sessions: [CoreTaowaSession]
}

struct CoreTaowaSession: Codable, Equatable, Identifiable, Sendable {
    let sessionId: String
    let profileId: String
    let instanceId: String?
    let gameDir: String
    let localPort: Int
    let remoteAddress: String
    let remotePort: Int
    let frpcConfigPath: String
    let frpcLogPath: String
    let status: String
    let processId: Int?
    let diagnostics: [CoreDiagnostic]
    let startedAt: Date
    let updatedAt: Date

    var id: String { sessionId }
    var isActive: Bool { status == "prepared" || status == "startingFrpc" || status == "running" }
    var isRunning: Bool { status == "running" }
}

struct CoreTaowaSessionLogResponse: Codable, Equatable, Sendable {
    let sessionId: String
    let logPath: String
    let tail: String
}

struct CoreTaowaSessionHealthResponse: Codable, Equatable, Sendable {
    let session: CoreTaowaSession
    let localPortReachable: Bool
    let processManaged: Bool
    let stale: Bool
}

struct CoreTaowaSessionHistoryClearRequest: Codable, Equatable, Sendable {
    let statuses: [String]?
    let keepActive: Bool
}

struct CoreTaowaSessionHistoryClearResponse: Codable, Equatable, Sendable {
    let deleted: Int
    let kept: Int
    let skippedActive: Int
}
