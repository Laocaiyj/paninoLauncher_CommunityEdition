import Foundation

struct CorePerformanceSummary: Codable, Equatable, Sendable {
    let status: String
    let title: String
    let detail: String
    let hardwareTier: String
    let hardwareLabel: String
    let jvm: CorePerformanceJvmSummary
    let graphics: CorePerformanceGraphicsSummary?
    let performancePack: CorePerformancePackSuggestion
    let primaryAction: CorePerformancePrimaryAction
    let reasons: [String]
    let confidence: String?
    let evidence: [CorePerformanceEvidence]?
    let rollbackRef: String?
}

struct CorePerformanceEvidence: Codable, Equatable, Sendable {
    let key: String
    let value: String
    let source: String
}

struct CoreInstanceFingerprint: Codable, Equatable, Sendable {
    var minecraftVersion: String?
    var javaRequirement: String?
    var loaderFamily: String?
    var loaderVersion: String?
    var rendererCapability: String?
    var modCount: Int?
    var shaderLoader: String?
    var activeShaderPackHash: String?
    var resourcePackScale: String?
    var lockfileFingerprint: String?
    var worldTypeHint: String?
}

struct CorePerformanceKnobs: Codable, Equatable, Sendable {
    var heapMaxMb: Int?
    var heapInitialPolicy: String?
    var gcPolicy: String?
    var renderDistance: Int?
    var simulationDistance: Int?
    var maxFps: Int?
    var vsyncPolicy: String?
    var particles: String?
    var clouds: String?
    var entityDistanceScaling: String?
    var performancePackSet: [String]?
}

struct CorePerformanceProfile: Codable, Equatable, Sendable {
    let profileId: String
    let profileKind: String
    let source: String
    let instanceFingerprint: CoreInstanceFingerprint
    let knobs: CorePerformanceKnobs
    let confidence: String
    let evidence: [CorePerformanceEvidence]
    let rollbackRef: String?
    let cooldownUntil: String?
}

struct CorePerformanceRecommendation: Codable, Equatable, Sendable {
    let profileId: String
    let confidence: String
    let evidence: [CorePerformanceEvidence]
    let objectiveScore: Double?
    let warnings: [String]
    let actions: [String]
    let rollbackRef: String?
    let diagnosticPaths: [String]
    let baseline: CorePerformanceProfile
    let candidate: CorePerformanceProfile?
}

struct CorePerformanceProfileResolveRequest: Codable, Equatable, Sendable {
    let gameDir: String
    let instanceFingerprint: CoreInstanceFingerprint
    let knobs: CorePerformanceKnobs
    let evidence: [CorePerformanceEvidence]
}

struct CorePerformanceCandidateRequest: Codable, Equatable, Sendable {
    let gameDir: String
    let baselineProfileId: String?
    let budgetLaunches: Int
    let budgetChangedKnobs: Int
}

struct CorePerformanceCandidateResponse: Codable, Equatable, Sendable {
    let candidate: CorePerformanceProfile
    let safetyGate: CoreSafetyGateDecision
    let recommendation: CorePerformanceRecommendation
}

struct CoreSafetyGateDecision: Codable, Equatable, Sendable {
    let allowed: Bool
    let reasons: [String]
    let score: CorePerformanceScore?
}

struct CorePerformanceScore: Codable, Equatable, Sendable {
    let smoothness: Double
    let stability: Double
    let memorySafety: Double
    let visualQuality: Double
    let energy: Double?
    let overall: Double
    let rejected: Bool
    let rejectReasons: [String]
}

struct CorePerformanceApplyRequest: Codable, Equatable, Sendable {
    let gameDir: String
    let profile: CorePerformanceProfile
}

struct CorePerformanceApplyResponse: Codable, Equatable, Sendable {
    let applied: Bool
    let profile: CorePerformanceProfile
    let rollbackRef: String?
}

struct CorePerformanceRollbackRequest: Codable, Equatable, Sendable {
    let gameDir: String
    let rollbackRef: String
}

struct CorePerformanceRollbackResponse: Codable, Equatable, Sendable {
    let rolledBack: Bool
    let profile: CorePerformanceProfile?
}

struct CorePerformanceJvmSummary: Codable, Equatable, Sendable {
    let profileName: String
    let memoryMb: Int
    let summary: String
}

struct CorePerformanceGraphicsSummary: Codable, Equatable, Sendable {
    let profile: String
    let renderDistance: String?
    let simulationDistance: String?
    let maxFps: String?
    let summary: String
    let canApply: Bool
}

struct CorePerformancePackSuggestion: Codable, Equatable, Sendable {
    let status: String
    let title: String
    let detail: String
    let loader: String?
    let installAutomatically: Bool
}

struct CorePerformancePrimaryAction: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let memoryMb: Int?
}
