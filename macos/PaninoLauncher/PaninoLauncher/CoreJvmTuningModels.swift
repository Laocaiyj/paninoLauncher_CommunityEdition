import Foundation

struct CoreResolvedJvmTuning: Codable, Equatable, Sendable {
    let requestedPolicy: String
    let effectivePolicy: String
    let memoryPolicy: String
    let packScale: String
    let systemMemoryMb: Int?
    let recommendedMemoryMb: Int
    let xmsMb: Int
    let xmxMb: Int
    let jvmArgs: [String]
    let profileName: String
    let summary: String
    let confidence: String?
    let evidence: [CorePerformanceEvidence]?
    let rollbackRef: String?
    let applyMode: String?
    let warnings: [CoreJvmTuningWarning]
    let actions: [CoreJvmTuningAction]
    let primaryAction: CoreJvmTuningAction?
    let canRollback: Bool
}

struct CoreJvmTuningWarning: Codable, Equatable, Sendable {
    let code: String
    let severity: String
    let message: String
    let action: String?
}

struct CoreJvmTuningAction: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let memoryMb: Int?
}
