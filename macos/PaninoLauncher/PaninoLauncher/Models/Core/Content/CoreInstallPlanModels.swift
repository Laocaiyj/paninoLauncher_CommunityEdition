import Foundation

struct CoreTypedInstallPlan: Codable, Equatable, Sendable {
    let planId: String
    let fingerprint: String
    let planKind: String
    let title: String
    let targetGameDir: String?
    let source: String?
    let status: String
    let summary: CoreInstallPlanSummary
    let nodes: [CoreInstallPlanNode]
    let edges: [CoreInstallPlanEdge]
    let warnings: [String]
    let blockedReasons: [String]
    let diagnostics: [CoreDiagnostic]?
    let rollbackPolicy: String
}

struct CoreInstallPlanSummary: Codable, Equatable, Sendable {
    let totalNodes: Int
    let downloadNodes: Int
    let keepNodes: Int
    let replaceNodes: Int
    let writeNodes: Int
    let estimatedBytes: Int64?
}

struct CoreInstallPlanNode: Codable, Equatable, Sendable {
    let id: String
    let kind: String
    let action: String
    let phase: String
    let label: String
    let targetPath: String?
    let sourceUrls: [String]
    let sha1: String?
    let size: Int64?
    let required: Bool
    let dependsOn: [String]
    let verifications: [CoreInstallVerification]
    let rollback: CoreInstallPlanRollbackAction
    let blockedReason: String?
    let diagnostics: [CoreDiagnostic]?
}

struct CoreInstallPlanEdge: Codable, Equatable, Sendable {
    let from: String
    let to: String
    let kind: String
    let required: Bool
}

struct CoreInstallVerification: Codable, Equatable, Sendable {
    let kind: String
    let status: String
    let message: String?
}

struct CoreInstallPlanRollbackAction: Codable, Equatable, Sendable {
    let action: String
    let targetPath: String?
    let backupPath: String?
    let reason: String?
}
