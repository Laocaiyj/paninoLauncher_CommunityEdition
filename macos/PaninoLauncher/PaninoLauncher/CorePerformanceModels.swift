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

struct CorePerformancePackRecommendation: Codable, Equatable, Sendable {
    let status: String
    let title: String
    let detail: String
    let loader: String?
    let minecraftVersion: String?
    let installAutomatically: Bool
    let installable: [CorePerformanceModEntry]
    let existing: [CorePerformanceModEntry]
    let conflicts: [CorePerformanceModEntry]
    let skippedReasons: [String]
}

struct CorePerformanceModEntry: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let role: String
    let optional: Bool
    let status: String
    let reason: String
}

struct CorePerformancePackInstallRequest: Codable, Equatable, Sendable {
    let gameDir: String
    let minecraftVersion: String
    let loader: String
    let includeOptional: Bool
    let download: CoreDownloadRuntimeOptions
    let source: String?
    let curseForgeAPIKey: String?

    init(
        gameDir: String,
        minecraftVersion: String,
        loader: String,
        includeOptional: Bool,
        download: CoreDownloadRuntimeOptions,
        source: String? = nil,
        curseForgeAPIKey: String? = nil
    ) {
        self.gameDir = gameDir
        self.minecraftVersion = minecraftVersion
        self.loader = loader
        self.includeOptional = includeOptional
        self.download = download
        self.source = source
        self.curseForgeAPIKey = curseForgeAPIKey
    }
}

struct CorePerformancePackPlan: Codable, Equatable, Sendable {
    let status: String
    let title: String
    let gameDir: String
    let lockfilePath: String
    let files: [CorePerformancePackPlanFile]
    let blockedReasons: [String]
    let skippedReasons: [String]
    let typedPlan: CoreTypedInstallPlan
}

struct CorePerformancePackPlanFile: Codable, Equatable, Sendable {
    let source: String?
    let projectId: String
    let fileName: String
    let targetPath: String
    let sha1: String?
    let size: Int64?
}

struct CorePerformancePackRollbackRequest: Codable, Equatable, Sendable {
    let gameDir: String
    let lockfilePath: String?
}

struct CorePerformancePackRollbackResponse: Codable, Equatable, Sendable {
    let rolledBack: Bool
    let removed: [String]
    let missing: [String]
    let skipped: [String]
    let lockfilePath: String
}

struct CorePerformancePrimaryAction: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let memoryMb: Int?
}

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

struct CoreResolvedGraphicsTuning: Codable, Equatable, Sendable {
    let requestedProfile: String
    let effectiveProfile: String
    let hardwareTier: String
    let retinaPolicy: String
    let currentOptions: [String: String]
    let recommendedOptions: [String: String]
    let optionsPatch: CoreOptionsPatch
    let summary: String
    let confidence: String?
    let evidence: [CorePerformanceEvidence]?
    let rollbackRef: String?
    let applyMode: String?
    let warnings: [CoreGraphicsTuningWarning]
    let actions: [CoreGraphicsTuningAction]
    let primaryAction: CoreGraphicsTuningAction?
    let backupPath: String?
    let canApply: Bool
    let canRollback: Bool
}

struct CoreGraphicsTuningRequest: Codable, Equatable, Sendable {
    let instanceId: String?
    let gameDir: String?
    let minecraftVersion: String?
    let loader: String?
    let hardwareTier: String?
    let displayScale: Double?
    let displayWidth: Int?
    let displayHeight: Int?
    let refreshRate: Int?
    let isBuiltinDisplay: Bool?
    let powerMode: String?
    let requestedProfile: String
    let shaderEnabled: Bool
    let resourcePackScale: String?
    let modCount: Int?
    let previousSnapshot: CoreResolvedGraphicsTuning?
    let manualOverrides: [String: String]
    let dryRun: Bool

    init(
        instanceId: String? = nil,
        gameDir: String?,
        minecraftVersion: String?,
        loader: String?,
        hardwareTier: String? = nil,
        displayScale: Double? = nil,
        displayWidth: Int? = nil,
        displayHeight: Int? = nil,
        refreshRate: Int? = nil,
        isBuiltinDisplay: Bool? = nil,
        powerMode: String? = nil,
        requestedProfile: String,
        shaderEnabled: Bool = false,
        resourcePackScale: String? = nil,
        modCount: Int? = nil,
        previousSnapshot: CoreResolvedGraphicsTuning? = nil,
        manualOverrides: [String: String] = [:],
        dryRun: Bool = true
    ) {
        self.instanceId = instanceId
        self.gameDir = gameDir
        self.minecraftVersion = minecraftVersion
        self.loader = loader
        self.hardwareTier = hardwareTier
        self.displayScale = displayScale
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
        self.refreshRate = refreshRate
        self.isBuiltinDisplay = isBuiltinDisplay
        self.powerMode = powerMode
        self.requestedProfile = requestedProfile
        self.shaderEnabled = shaderEnabled
        self.resourcePackScale = resourcePackScale
        self.modCount = modCount
        self.previousSnapshot = previousSnapshot
        self.manualOverrides = manualOverrides
        self.dryRun = dryRun
    }
}

struct CoreGraphicsTuningApplyResponse: Codable, Equatable, Sendable {
    let applied: Bool
    let backup: CoreOptionsBackup
    let tuning: CoreResolvedGraphicsTuning
}

struct CoreGraphicsTuningRollbackRequest: Codable, Equatable, Sendable {
    let gameDir: String
    let backupPath: String?
}

struct CoreGraphicsTuningRollbackResponse: Codable, Equatable, Sendable {
    let rolledBack: Bool
    let restoredFrom: String
    let backup: CoreOptionsBackup
}

struct CoreGraphicsTuningWarning: Codable, Equatable, Sendable {
    let code: String
    let severity: String
    let message: String
    let action: String?
}

struct CoreGraphicsTuningAction: Codable, Equatable, Sendable {
    let id: String
    let title: String
    let options: [String: String]
}

struct CoreOptionsPatch: Codable, Equatable, Sendable {
    let path: String?
    let changes: [CoreOptionsPatchChange]
}

struct CoreOptionsPatchChange: Codable, Equatable, Sendable {
    let key: String
    let oldValue: String?
    let newValue: String?
    let reason: String
    let status: String
}

struct CoreOptionsBackup: Codable, Equatable, Sendable {
    let sourcePath: String
    let stablePath: String?
    let timestampPath: String?
    let created: Bool
    let error: String?
}
