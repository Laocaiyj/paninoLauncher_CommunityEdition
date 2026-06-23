import Foundation

struct CoreDiagnostic: Codable, Equatable, Sendable {
    let code: String
    let phase: String
    let severity: String
    let title: String
    let message: String
    let cause: String
    let action: CoreDiagnosticAction
    let retryable: Bool
    let userVisible: Bool
    let source: String
    let taskId: String?
    let planId: String?
    let packageId: String?
    let filePath: String?
    let urlHost: String?
    let evidence: [CoreDiagnosticEvidence]
    let developerDetail: String?

    var userSummary: String {
        message.isEmpty ? title : message
    }

    var actionLabel: String {
        action.label.isEmpty ? action.kind : action.label
    }
}

struct CoreDiagnosticAction: Codable, Equatable, Sendable {
    let kind: String
    let label: String
    let target: String?
    let payload: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case kind
        case label
        case target
        case payload
    }

    init(kind: String, label: String, target: String? = nil, payload: [String: String]? = nil) {
        self.kind = kind
        self.label = label
        self.target = target
        self.payload = payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "openDiagnostics"
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? "Open diagnostics"
        target = try container.decodeIfPresent(String.self, forKey: .target)
        payload = try? container.decode([String: String].self, forKey: .payload)
    }
}

struct CoreDiagnosticEvidence: Codable, Equatable, Sendable {
    let key: String
    let value: String
    let redacted: Bool
}
