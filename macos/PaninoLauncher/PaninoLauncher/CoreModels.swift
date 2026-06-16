import Foundation

struct CoreEndpoint: Equatable {
    let baseURL: URL
    let sessionToken: String
}

struct HealthResponse: Decodable, Equatable {
    let status: String
    let service: String
    let time: String
}

struct CoreNetworkEffectiveConfiguration: Codable, Equatable, Sendable {
    let sourceProfile: String
    let officialFallback: Bool
    let metadataRetryCount: Int
    let proxy: CoreNetworkProxyConfiguration
    let endpoints: [CoreNetworkSourceEndpointConfiguration]
}

struct CoreNetworkProxyConfiguration: Codable, Equatable, Sendable {
    let configured: Bool
    let value: String?
    let keys: [String]
}

struct CoreNetworkSourceEndpointConfiguration: Codable, Equatable, Sendable {
    let envVar: String
    let officialBase: String
    let configured: Bool
    let effectiveBases: [String]
}

struct CoreNetworkSourceTestResponse: Codable, Equatable, Sendable {
    let ok: Bool
    let generatedAt: String
    let results: [CoreNetworkSourceTestResult]
}

struct CoreNetworkSourceTestResult: Codable, Equatable, Identifiable, Sendable {
    let endpoint: String
    let url: String
    let candidateCount: Int
    let selectedUrl: String?
    let selectedIndex: Int?
    let usedFallback: Bool
    let ok: Bool
    let status: Int?
    let latencyMs: Int?
    let error: String?
    let attempts: [CoreNetworkSourceTestAttempt]

    var id: String { endpoint }

    var statusText: String {
        if ok {
            let fallback = usedFallback ? " fallback" : ""
            let latency = latencyMs.map { " \($0) ms" } ?? ""
            return "OK\(fallback)\(latency)"
        }
        return error ?? "Failed"
    }
}

struct CoreNetworkSourceTestAttempt: Codable, Equatable, Sendable {
    let url: String
    let status: Int?
    let latencyMs: Int
    let ok: Bool
    let error: String?
}

struct CoreNetworkSpeedTestRequest: Encodable, Equatable, Sendable {
    let categories: [String]
    let urls: [String]
    let sampleBytes: Int64?

    static let settingsDefault = CoreNetworkSpeedTestRequest(
        categories: ["mojang-asset", "mojang-library", "client-jar", "fabric-metadata"],
        urls: [],
        sampleBytes: 4 * 1024 * 1024
    )
}

struct CoreNetworkSpeedTestResponse: Codable, Equatable, Sendable {
    let ok: Bool
    let generatedAt: String
    let sampleBytes: Int64
    let results: [CoreNetworkSpeedTestResult]

    var fastestResult: CoreNetworkSpeedTestResult? {
        results.filter(\.ok).max { $0.bytesPerSecond < $1.bytesPerSecond }
    }
}

struct CoreNetworkSpeedTestResult: Codable, Equatable, Identifiable, Sendable {
    let endpoint: String
    let candidateUrl: String
    let host: String
    let status: Int?
    let bytes: Int64
    let elapsedMs: Int
    let bytesPerSecond: Int64
    let rangeSupported: Bool
    let usedProxy: Bool
    let error: String?
    let ok: Bool

    var id: String { endpoint + candidateUrl }

    var statusText: String {
        if ok {
            return "\(formattedBytes(bytesPerSecond))/s" + (rangeSupported ? " · Range" : " · single")
        }
        return error ?? "Failed"
    }
}

struct CoreEnvironmentReport: Codable, Equatable, Sendable {
    let ok: Bool
    let generatedAt: String
    let performanceSummary: CorePerformanceSummary?
    let context: CoreEnvironmentContext?
    let system: CoreEnvironmentSystem
    let java: CoreEnvironmentJava
    let javaResolution: CoreJavaRuntimeResolveResponse?
    let jvmTuning: CoreResolvedJvmTuning?
    let launchEffectiveJvmArgs: [String]?
    let graphicsTuning: CoreResolvedGraphicsTuning?
    let performancePackRecommendation: CorePerformancePackRecommendation?
    let runtimeFeedback: CoreRuntimeFeedback?
    let directories: CoreEnvironmentDirectories
    let memory: CoreEnvironmentMemory?
    let network: CoreEnvironmentNetwork
    let compatibility: CoreEnvironmentCompatibility?
}

struct CoreRuntimeFeedback: Codable, Equatable, Sendable {
    let status: String
    let signals: [String]
    let actions: [String]
    let lastLaunchState: String?
    let lastLaunchTaskId: String?
    let exitCode: Int?
    let durationMs: Int?
    let profilePath: String?
    let profilePresent: Bool?
    let latestLogPath: String?
    let latestLogPresent: Bool?
    let crashReportPath: String?
    let crashReportPresent: Bool?
    let logSummary: String?
}

struct CoreEnvironmentReportRequest: Equatable, Sendable {
    let gameDir: String?
    let version: String?
    let loader: String?
    let loaderVersion: String?
    let memoryMb: Int?

    let memoryPolicy: String?
    let jvmProfile: String?
    let customMemoryMb: Int?
    let customJvmArgs: String?
    let modCount: Int?
    let resourcePackCount: Int?
    let resourcePackScale: String?
    let shaderPackCount: Int?
    let graphicsProfile: String?
    let graphicsHardwareTier: String?
    let displayScale: Double?
    let displayWidth: Int?
    let displayHeight: Int?
    let refreshRate: Int?
    let isBuiltinDisplay: Bool?
    let shaderEnabled: Bool?

    init(
        gameDir: String?,
        version: String?,
        loader: String?,
        loaderVersion: String?,
        memoryMb: Int?,
        memoryPolicy: String? = nil,
        jvmProfile: String? = nil,
        customMemoryMb: Int? = nil,
        customJvmArgs: String? = nil,
        modCount: Int? = nil,
        resourcePackCount: Int? = nil,
        resourcePackScale: String? = nil,
        shaderPackCount: Int? = nil,
        graphicsProfile: String? = nil,
        graphicsHardwareTier: String? = nil,
        displayScale: Double? = nil,
        displayWidth: Int? = nil,
        displayHeight: Int? = nil,
        refreshRate: Int? = nil,
        isBuiltinDisplay: Bool? = nil,
        shaderEnabled: Bool? = nil
    ) {
        self.gameDir = gameDir
        self.version = version
        self.loader = loader
        self.loaderVersion = loaderVersion
        self.memoryMb = memoryMb
        self.memoryPolicy = memoryPolicy
        self.jvmProfile = jvmProfile
        self.customMemoryMb = customMemoryMb
        self.customJvmArgs = customJvmArgs
        self.modCount = modCount
        self.resourcePackCount = resourcePackCount
        self.resourcePackScale = resourcePackScale
        self.shaderPackCount = shaderPackCount
        self.graphicsProfile = graphicsProfile
        self.graphicsHardwareTier = graphicsHardwareTier
        self.displayScale = displayScale
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
        self.refreshRate = refreshRate
        self.isBuiltinDisplay = isBuiltinDisplay
        self.shaderEnabled = shaderEnabled
    }
}

struct CoreEnvironmentContext: Codable, Equatable, Sendable {
    let gameDir: String?
    let minecraftVersion: String?
    let loader: String?
    let loaderVersion: String?
    let configuredMemoryMb: Int?
    let memoryPolicy: String?
    let jvmProfile: String?
    let graphicsProfile: String?
    let graphicsHardwareTier: String?
    let displayScale: Double?
    let displayWidth: Int?
    let displayHeight: Int?
    let refreshRate: Int?
    let isBuiltinDisplay: Bool?
    let shaderEnabled: Bool?
    let resourcePackScale: String?
}

struct CoreEnvironmentSystem: Codable, Equatable, Sendable {
    let os: String
    let architecture: String
    let cpuCapabilities: Int
    let memoryBytes: Int64?
    let hardwareProfile: CoreHardwareProfile?
    let fileDescriptorLimit: Int?
}

struct CoreHardwareProfile: Codable, Equatable, Sendable {
    let chipName: String?
    let chipTier: String
    let memoryBytes: Int64?
    let memoryTier: String
}

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

struct CoreEnvironmentJava: Codable, Equatable, Sendable {
    let status: JavaRuntimeStatus
    let architecture: String
    let requiredMajorVersion: Int?
    let installedMajorVersion: Int?
    let architectureMatchesSystem: Bool?
    let conclusion: String
    let actions: [String]
}

struct CoreEnvironmentDirectories: Codable, Equatable, Sendable {
    let gameDir: String?
    let status: String
    let writable: Bool
    let availableDiskBytes: Int64?
    let writeSampleBytes: Int
    let writeElapsedMs: Int?
    let writeBytesPerSecond: Int64
    let error: String?
    let cache: CoreEnvironmentDirectoryCheck?
    let staging: CoreEnvironmentDirectoryCheck?
    let checks: [CoreEnvironmentDirectoryCheck]?
    let actions: [String]
}

struct CoreEnvironmentDirectoryCheck: Codable, Equatable, Sendable {
    let id: String
    let path: String
    let status: String
    let writable: Bool
    let error: String?
    let actions: [String]
}

struct CoreEnvironmentMemory: Codable, Equatable, Sendable {
    let systemBytes: Int64?
    let configuredMb: Int?
    let recommendedMb: Int
    let conclusion: String
    let actions: [String]
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

struct CoreEnvironmentNetwork: Codable, Equatable, Sendable {
    let effective: CoreNetworkEffectiveConfiguration
    let speedTestEndpoint: String
    let sourceTest: CoreNetworkSourceTestResponse?
}

struct CoreEnvironmentCompatibility: Codable, Equatable, Sendable {
    let minecraftVersion: String?
    let loader: String?
    let loaderVersion: String?
    let conclusion: String
    let actions: [String]
}

struct CoreCompatibilityTarget: Codable, Equatable, Sendable {
    let minecraftVersion: String?
    let loader: String?
    let loaderVersion: String?
    let shaderLoader: String?
    let gameDir: String?
    let javaMajor: Int?
    let requiredJavaMajor: Int?
    let javaArch: String?
    let systemArch: String?
}

struct CoreCompatibilityPackageInput: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let source: String?
    let kind: String
    let minecraftVersions: [String]
    let loaders: [String]
    let requiredDependencies: [String]
    let optionalDependencies: [String]
    let present: Bool
    let metadataComplete: Bool
    let javaMajor: Int?
}

struct CoreCompatibilityEvaluateRequest: Codable, Equatable, Sendable {
    let target: CoreCompatibilityTarget
    let packages: [CoreCompatibilityPackageInput]
    let installedPackageIds: [String]
    let missingRequiredDependencies: [String]
    let missingOptionalDependencies: [String]
    let blockedReasons: [String]
    let warnings: [String]

    init(
        target: CoreCompatibilityTarget,
        packages: [CoreCompatibilityPackageInput] = [],
        installedPackageIds: [String] = [],
        missingRequiredDependencies: [String] = [],
        missingOptionalDependencies: [String] = [],
        blockedReasons: [String] = [],
        warnings: [String] = []
    ) {
        self.target = target
        self.packages = packages
        self.installedPackageIds = installedPackageIds
        self.missingRequiredDependencies = missingRequiredDependencies
        self.missingOptionalDependencies = missingOptionalDependencies
        self.blockedReasons = blockedReasons
        self.warnings = warnings
    }
}

struct CoreCompatibilityPackageReport: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let status: String
    let diagnostics: [CoreDiagnostic]
    let blockedReasons: [String]
    let warnings: [String]
    let actions: [CoreDiagnosticAction]
}

struct CoreCompatibilityReport: Codable, Equatable, Sendable {
    let status: String
    let target: CoreCompatibilityTarget
    let packageReports: [CoreCompatibilityPackageReport]
    let globalDiagnostics: [CoreDiagnostic]
    let blockedReasons: [String]
    let warnings: [String]
    let actions: [CoreDiagnosticAction]
    let summary: String

    var allDiagnostics: [CoreDiagnostic] {
        globalDiagnostics + packageReports.flatMap(\.diagnostics)
    }

    var primaryDiagnostic: CoreDiagnostic? {
        allDiagnostics.first
    }
}

struct CoreCompatibilityExplanation: Codable, Equatable, Sendable {
    let status: String
    let summary: String
    let reasons: [String]
    let actions: [String]
    let report: CoreCompatibilityReport
}

enum TaskState: String, Decodable, Equatable {
    case queued
    case running
    case succeeded
    case failed
    case cancelled

    var isActive: Bool {
        self == .queued || self == .running
    }

    var isTerminal: Bool {
        !isActive
    }
}

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

struct TaskSnapshot: Decodable, Equatable, Identifiable {
    let taskId: String
    let kind: String
    let version: String
    let gameDir: String?
    let requestedLoader: String?
    let requestedShaderLoader: String?
    let state: TaskState
    let message: String?
    let errorCode: String?
    let errorDetail: String?
    let diagnostic: CoreDiagnostic?
    let diagnostics: [CoreDiagnostic]
    let createdAt: String
    let updatedAt: String
    let finishedAt: String?
    let progress: TaskProgress?

    var id: String { taskId }

    init(
        taskId: String,
        kind: String,
        version: String,
        gameDir: String?,
        requestedLoader: String? = nil,
        requestedShaderLoader: String? = nil,
        state: TaskState,
        message: String?,
        errorCode: String?,
        errorDetail: String?,
        diagnostic: CoreDiagnostic? = nil,
        diagnostics: [CoreDiagnostic] = [],
        createdAt: String,
        updatedAt: String,
        finishedAt: String?,
        progress: TaskProgress?
    ) {
        self.taskId = taskId
        self.kind = kind
        self.version = version
        self.gameDir = gameDir
        self.requestedLoader = requestedLoader
        self.requestedShaderLoader = requestedShaderLoader
        self.state = state
        self.message = message
        self.errorCode = errorCode
        self.errorDetail = errorDetail
        self.diagnostic = diagnostic
        self.diagnostics = diagnostics
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.finishedAt = finishedAt
        self.progress = progress
    }

    private enum CodingKeys: String, CodingKey {
        case taskId
        case kind
        case version
        case gameDir
        case requestedLoader
        case requestedShaderLoader
        case state
        case message
        case errorCode
        case errorDetail
        case diagnostic
        case diagnostics
        case createdAt
        case updatedAt
        case finishedAt
        case progress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskId = try container.decode(String.self, forKey: .taskId)
        kind = try container.decode(String.self, forKey: .kind)
        version = try container.decode(String.self, forKey: .version)
        gameDir = try container.decodeIfPresent(String.self, forKey: .gameDir)
        requestedLoader = try container.decodeIfPresent(String.self, forKey: .requestedLoader)
        requestedShaderLoader = try container.decodeIfPresent(String.self, forKey: .requestedShaderLoader)
        state = try container.decode(TaskState.self, forKey: .state)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        errorCode = try container.decodeIfPresent(String.self, forKey: .errorCode)
        errorDetail = try container.decodeIfPresent(String.self, forKey: .errorDetail)
        diagnostic = try container.decodeIfPresent(CoreDiagnostic.self, forKey: .diagnostic)
        diagnostics = try container.decodeIfPresent([CoreDiagnostic].self, forKey: .diagnostics) ?? diagnostic.map { [$0] } ?? []
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        finishedAt = try container.decodeIfPresent(String.self, forKey: .finishedAt)
        progress = try container.decodeIfPresent(TaskProgress.self, forKey: .progress)
    }

    static func failedInstall(version: String, gameDir: String?, requestedLoader: String? = nil, requestedShaderLoader: String? = nil, message: String, errorCode: String?, errorDetail: String?, diagnostic: CoreDiagnostic? = nil, diagnostics: [CoreDiagnostic] = []) -> TaskSnapshot {
        let now = ISO8601DateFormatter().string(from: Date())
        return TaskSnapshot(
            taskId: "install-preflight-\(Int(Date().timeIntervalSince1970))",
            kind: "install",
            version: version,
            gameDir: gameDir,
            requestedLoader: requestedLoader,
            requestedShaderLoader: requestedShaderLoader,
            state: .failed,
            message: message,
            errorCode: errorCode,
            errorDetail: errorDetail,
            diagnostic: diagnostic,
            diagnostics: diagnostics.isEmpty ? diagnostic.map { [$0] } ?? [] : diagnostics,
            createdAt: now,
            updatedAt: now,
            finishedAt: now,
            progress: nil
        )
    }
}

struct TaskProgress: Codable, Equatable {
    let taskId: String
    let phaseId: String
    let phaseTitle: String
    let phaseIndex: Int
    let phaseCount: Int
    let phasePercent: Double?
    let overallPercent: Double?
    let completedJobs: Int
    let totalJobs: Int
    let completedBytes: Int64
    let totalBytes: Int64
    let speedBytesPerSecond: Int64
    let movingAverageSpeedBytesPerSecond: Int64?
    let etaSeconds: Int64?
    let currentLabel: String
    let activeWorkers: Int
    let retryCount: Int
    let sourceHost: String?
    let hosts: [TaskProgressHost]?
    let throttleReason: String?
    let multipart: TaskProgressMultipart?

    var fractionComplete: Double? {
        overallPercent.map { min(max($0 / 100, 0), 1) }
    }
}

struct TaskProgressHost: Codable, Equatable {
    let host: String
    let lane: String
    let activeConnections: Int
    let gate: Int
    let maxGate: Int
    let bytesPerSecond: Int64
    let completedBytes: Int64
    let completedJobs: Int
    let retryCount: Int

    var displayText: String {
        "\(host) \(activeConnections)/\(gate) \(formattedBytes(bytesPerSecond))/s"
    }
}

struct TaskProgressMultipart: Codable, Equatable {
    let label: String
    let completedSegments: Int
    let totalSegments: Int
    let activeSegments: Int
    let segmentBytes: Int64
    let totalBytes: Int64
    let currentSegment: Int?

    var displayText: String {
        "\(completedSegments)/\(totalSegments) segments"
    }
}

struct TaskAccepted: Decodable, Equatable {
    let taskId: String
    let state: TaskState
    let task: TaskSnapshot
}

struct CoreTaskHistoryResponse: Decodable, Equatable {
    let tasks: [TaskSnapshot]
    let totalCount: Int
    let offset: Int
    let limit: Int
}

struct CoreTaskHistoryClearRequest: Encodable, Equatable {
    let statuses: [String]?
    let olderThanDays: Int?
    let keepFailed: Bool?
}

struct CoreTaskHistoryClearResponse: Decodable, Equatable {
    let deleted: Int
    let kept: Int
    let skippedActive: Int
}

struct CoreContentInstallFile: Codable, Equatable, Sendable {
    let fileName: String
    let url: URL
    let sha1: String?
    let size: Int64?
    let primary: Bool?
}

struct CoreContentInstallDependency: Codable, Equatable, Sendable {
    let projectId: String?
    let versionId: String?
    let source: String?
    let name: String
    let required: Bool
    let installed: Bool?
    let sha1: String?
}

struct CoreDownloadRuntimeOptions: Codable, Equatable, Sendable {
    let concurrency: Int
    let retryCount: Int

    let strategy: String?

    init(concurrency: Int, retryCount: Int, strategy: String? = nil) {
        self.concurrency = concurrency
        self.retryCount = retryCount
        self.strategy = strategy
    }
}

struct CoreContentInstallRequest: Codable, Equatable, Sendable {
    let source: String
    let projectId: String?
    let projectTitle: String
    let projectType: String?
    let releaseId: String
    let gameDir: String
    let targetSubdir: String
    let files: [CoreContentInstallFile]
    let dependencies: [CoreContentInstallDependency]
    let gameVersions: [String]
    let loaders: [String]
    let instances: [CoreContentTargetInstance]
    let concurrency: Int?
    let retryCount: Int?
    let download: CoreDownloadRuntimeOptions?

    init(
        source: String,
        projectId: String?,
        projectTitle: String,
        projectType: String?,
        releaseId: String,
        gameDir: String,
        targetSubdir: String,
        files: [CoreContentInstallFile],
        dependencies: [CoreContentInstallDependency],
        gameVersions: [String],
        loaders: [String],
        instances: [CoreContentTargetInstance],
        concurrency: Int?,
        retryCount: Int? = nil,
        download: CoreDownloadRuntimeOptions? = nil
    ) {
        self.source = source
        self.projectId = projectId
        self.projectTitle = projectTitle
        self.projectType = projectType
        self.releaseId = releaseId
        self.gameDir = gameDir
        self.targetSubdir = targetSubdir
        self.files = files
        self.dependencies = dependencies
        self.gameVersions = gameVersions
        self.loaders = loaders
        self.instances = instances
        self.concurrency = concurrency
        self.retryCount = retryCount
        self.download = download
    }
}

extension CoreContentInstallRequest {
    func withEffectiveDownloadOptions(_ fallback: CoreDownloadRuntimeOptions) -> CoreContentInstallRequest {
        let effectiveConcurrency = concurrency ?? download?.concurrency ?? fallback.concurrency
        let effectiveRetryCount = retryCount ?? download?.retryCount ?? fallback.retryCount
        let effectiveDownload = CoreDownloadRuntimeOptions(
            concurrency: effectiveConcurrency,
            retryCount: effectiveRetryCount,
            strategy: download?.strategy ?? fallback.strategy
        )
        return CoreContentInstallRequest(
            source: source,
            projectId: projectId,
            projectTitle: projectTitle,
            projectType: projectType,
            releaseId: releaseId,
            gameDir: gameDir,
            targetSubdir: targetSubdir,
            files: files,
            dependencies: dependencies,
            gameVersions: gameVersions,
            loaders: loaders,
            instances: instances,
            concurrency: effectiveConcurrency,
            retryCount: effectiveRetryCount,
            download: effectiveDownload
        )
    }

    func withEffectiveConcurrency(_ fallback: Int) -> CoreContentInstallRequest {
        withEffectiveDownloadOptions(
            CoreDownloadRuntimeOptions(
                concurrency: fallback,
                retryCount: retryCount ?? download?.retryCount ?? 3
            )
        )
    }
}

struct CoreContentInstallPlanFile: Decodable, Equatable, Sendable {
    let fileName: String
    let targetPath: String
    let size: Int64?
    let sha1: String?
    let action: String
    let primary: Bool
}

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

struct CorePackageCoordinate: Codable, Equatable, Sendable {
    let source: String
    let projectId: String?
    let versionId: String?
    let fileId: String?
    let slug: String?
    let name: String?
    let kind: String
}

struct CorePackageConstraint: Codable, Equatable, Sendable {
    let constraintId: String
    let sourcePackage: String?
    let targetPackageId: String?
    let targetKind: String
    let relation: String
    let minecraftVersions: [String]
    let loaders: [String]
    let javaMajor: Int?
    let side: String?
    let required: Bool
    let reason: String
}

struct CoreResolvedPackage: Codable, Equatable, Sendable {
    let packageId: String
    let coordinate: CorePackageCoordinate
    let displayName: String
    let versionName: String?
    let fileName: String?
    let targetPath: String?
    let hashes: [String: String]
    let size: Int64?
    let downloadUrls: [String]
    let gameVersions: [String]
    let loaders: [String]
    let javaMajor: Int?
    let side: String?
    let selectedBecause: [String]
    let locked: Bool
    let pinReason: String?
    let dependencies: [CorePackageConstraint]
    let conflicts: [CorePackageConstraint]
    let sourceSnapshot: String?
}

struct CoreLockfilePlatform: Codable, Equatable, Sendable {
    let family: String?
    let version: String?
    let major: Int?
    let runtimeId: String?
    let source: String?
    let path: String?
}

struct CoreLockfileFile: Codable, Equatable, Sendable {
    let packageId: String
    let fileName: String
    let targetPath: String
    let hashes: [String: String]
    let size: Int64?
    let downloadUrls: [String]
    let kind: String
}

struct CorePaninoLockfile: Codable, Equatable, Sendable {
    let lockfileVersion: Int
    let solverVersion: String
    let fingerprint: String
    let createdAt: Date?
    let updatedAt: Date?
    let targetGameDir: String?
    let minecraft: String?
    let java: CoreLockfilePlatform?
    let loader: CoreLockfilePlatform?
    let shaderLoader: CoreLockfilePlatform?
    let roots: [String]
    let packages: [CoreResolvedPackage]
    let files: [CoreLockfileFile]
    let constraints: [CorePackageConstraint]
    let overrides: [String]
    let sourceSnapshots: [String]
    let manualEntries: [CoreResolvedPackage]
    let warnings: [String]
}

struct CoreLockfileSolveRequest: Codable, Equatable, Sendable {
    let mode: String
    let targetGameDir: String
    let minecraftVersion: String?
    let loader: String?
    let loaderVersion: String?
    let javaPolicy: CoreLockfilePlatform?
    let shaderLoader: String?
    let sourceType: String?
    let sourcePath: String?
    let includePerformancePack: Bool
    let roots: [CoreResolvedPackage]
    let existingLockfile: CorePaninoLockfile?
    let updatePolicy: String
    let sourcePolicy: String?
    let curseForgeAPIKey: String?
    let includeOptionalDependencies: Bool
    let selectedOptionalDependencies: [String]
    let ignoredDependencies: [String]
    let pinnedPackages: [String]
    let manualPackages: [CoreResolvedPackage]

    init(
        mode: String,
        targetGameDir: String,
        minecraftVersion: String?,
        loader: String?,
        loaderVersion: String? = nil,
        javaPolicy: CoreLockfilePlatform? = nil,
        shaderLoader: String? = nil,
        sourceType: String? = nil,
        sourcePath: String? = nil,
        includePerformancePack: Bool = false,
        roots: [CoreResolvedPackage] = [],
        existingLockfile: CorePaninoLockfile? = nil,
        updatePolicy: String = "keepLocked",
        sourcePolicy: String? = nil,
        curseForgeAPIKey: String? = nil,
        includeOptionalDependencies: Bool = false,
        selectedOptionalDependencies: [String] = [],
        ignoredDependencies: [String] = [],
        pinnedPackages: [String] = [],
        manualPackages: [CoreResolvedPackage] = []
    ) {
        self.mode = mode
        self.targetGameDir = targetGameDir
        self.minecraftVersion = minecraftVersion
        self.loader = loader
        self.loaderVersion = loaderVersion
        self.javaPolicy = javaPolicy
        self.shaderLoader = shaderLoader
        self.sourceType = sourceType
        self.sourcePath = sourcePath
        self.includePerformancePack = includePerformancePack
        self.roots = roots
        self.existingLockfile = existingLockfile
        self.updatePolicy = updatePolicy
        self.sourcePolicy = sourcePolicy
        self.curseForgeAPIKey = curseForgeAPIKey
        self.includeOptionalDependencies = includeOptionalDependencies
        self.selectedOptionalDependencies = selectedOptionalDependencies
        self.ignoredDependencies = ignoredDependencies
        self.pinnedPackages = pinnedPackages
        self.manualPackages = manualPackages
    }
}

struct CoreLockfileChange: Codable, Equatable, Sendable {
    let action: String
    let packageId: String
    let displayName: String
    let fromVersionId: String?
    let toVersionId: String?
    let targetPath: String?
    let reason: String
}

struct CoreLockfileChangeset: Codable, Equatable, Sendable {
    let keep: [CoreLockfileChange]
    let add: [CoreLockfileChange]
    let replace: [CoreLockfileChange]
    let remove: [CoreLockfileChange]
    let repair: [CoreLockfileChange]
    let manual: [CoreLockfileChange]
    let blocked: [CoreLockfileChange]
}

struct CoreSolverConflict: Codable, Equatable, Sendable {
    let conflictId: String
    let code: String
    let title: String
    let message: String
    let packageIds: [String]
    let filePaths: [String]
    let diagnostic: CoreDiagnostic?
}

struct CoreLockfileExplainEntry: Codable, Equatable, Sendable {
    let packageId: String?
    let constraintId: String?
    let kind: String
    let reason: String
    let required: Bool
}

struct CoreLockfileExplain: Codable, Equatable, Sendable {
    let rootRequests: [CoreLockfileExplainEntry]
    let constraints: [CoreLockfileExplainEntry]
    let selectedCandidates: [CoreLockfileExplainEntry]
    let rejectedCandidates: [CoreLockfileExplainEntry]
    let lockfileFingerprint: String?
}

struct CoreLockfileSolverResult: Codable, Equatable, Sendable {
    let status: String
    let lockfile: CorePaninoLockfile?
    let typedPlan: CoreTypedInstallPlan
    let changeset: CoreLockfileChangeset
    let warnings: [String]
    let blockedReasons: [String]
    let conflicts: [CoreSolverConflict]
    let explain: CoreLockfileExplain
    let diagnostics: [CoreDiagnostic]
}

struct CoreLockfileCurrentResponse: Decodable, Equatable, Sendable {
    let path: String
    let lockfile: CorePaninoLockfile?
}

struct CoreLockfileApplyRequest: Codable, Equatable, Sendable {
    let targetGameDir: String
    let solverFingerprint: String
    let result: CoreLockfileSolverResult
}

struct CoreInstallNodeResult: Decodable, Equatable, Sendable {
    let nodeId: String
    let status: String
    let message: String?
    let diagnostic: CoreDiagnostic?
}

struct CoreInstallPlanExecutionResult: Decodable, Equatable, Sendable {
    let planId: String
    let status: String
    let results: [CoreInstallNodeResult]
    let completedNodeIds: [String]
    let failedNodeId: String?
    let rolledBackNodeIds: [String]
}

struct CoreLockfileApplyResponse: Decodable, Equatable, Sendable {
    let status: String
    let lockfilePath: String
    let resultPath: String
    let explainPath: String
    let execution: CoreInstallPlanExecutionResult?
}

struct CoreLockfileVerifyRequest: Codable, Equatable, Sendable {
    let targetGameDir: String?
    let lockfile: CorePaninoLockfile?
}

struct CoreLockfileVerifyIssue: Codable, Equatable, Sendable {
    let kind: String
    let packageId: String?
    let targetPath: String?
    let expectedSha1: String?
    let actualSha1: String?
    let message: String
}

struct CoreLockfileVerifyResponse: Decodable, Equatable, Sendable {
    let status: String
    let fingerprint: String?
    let missingFiles: [CoreLockfileVerifyIssue]
    let hashMismatches: [CoreLockfileVerifyIssue]
    let extraFiles: [CoreLockfileVerifyIssue]
    let manualFiles: [CoreLockfileVerifyIssue]
    let javaMismatch: [CoreLockfileVerifyIssue]
    let loaderMismatch: [CoreLockfileVerifyIssue]
    let lockfileDrift: [CoreLockfileVerifyIssue]
    let repairPlan: CoreTypedInstallPlan?
}

struct CoreLockfileDiffRequest: Codable, Equatable, Sendable {
    let base: CorePaninoLockfile
    let target: CorePaninoLockfile
}

struct CoreLoaderInstallPreflightRequest: Encodable, Equatable, Sendable {
    let version: String
    let gameDir: String?
    let loader: String?
    let loaderVersion: String?
    let shaderLoader: String?
    let shaderVersion: String?
    let instanceName: String?
}

struct CoreLoaderInstallPreflightResponse: Decodable, Equatable, Sendable {
    let status: String
    let minecraftVersion: String
    let loader: String?
    let loaderVersion: String?
    let loaderProfileId: String?
    let shaderLoader: String?
    let shaderVersion: String?
    let shaderResolvedLoader: String?
    let shaderFallbackFrom: String?
    let shaderFallbackTo: String?
    let installerProbeStatus: String?
    let shaderProjects: [String]
    let requiredDependencies: [String]
    let javaRuntime: CoreJavaRuntimeResolveResponse?
    let warnings: [String]
    let blockedReasons: [String]
    let typedPlan: CoreTypedInstallPlan
    let diagnostics: CoreLoaderInstallPreflightDiagnostics
    let diagnostic: CoreDiagnostic?
    let structuredDiagnostics: [CoreDiagnostic]?

    var isBlocked: Bool {
        status == "blocked" || !blockedReasons.isEmpty
    }

    var displaySummary: String {
        if isBlocked {
            if let diagnostic, !diagnostic.userSummary.isEmpty {
                return diagnostic.userSummary
            }
            if let structured = structuredDiagnostics?.first, !structured.userSummary.isEmpty {
                return structured.userSummary
            }
            return blockedReasons.first ?? "Install is blocked."
        }
        if status == "warning" {
            return warnings.first ?? "Install can continue with warnings."
        }
        return "Install can continue."
    }
}

struct CoreLoaderInstallPreflightDiagnostics: Decodable, Equatable, Sendable {
    let loaderSources: [CoreLoaderMetadataSourceResult]
    let loaderProfileUrl: String?
    let installerUrl: String?
    let installerProbeStatus: String?
    let shaderProjects: [String]
}

struct CoreLoaderMetadataSourceResult: Decodable, Equatable, Sendable {
    let source: String
    let ok: Bool
    let versions: [LoaderMetadata]
    let versionCount: Int
    let selectedVersion: String?
    let error: String?
    let latencyMs: Int
}

struct CoreInstallPreflightBlockedError: Decodable, Equatable, Sendable {
    let error: String
    let diagnostic: CoreDiagnostic?
    let structuredDiagnostics: [CoreDiagnostic]?
    let blockedReasons: [String]?
    let preflight: CoreLoaderInstallPreflightResponse?
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

struct CoreContentInstallPlanResponse: Decodable, Equatable, Sendable {
    let action: String
    let source: String
    let projectId: String?
    let projectTitle: String
    let releaseId: String
    let targetDir: String
    let files: [CoreContentInstallPlanFile]
    let dependencies: [CoreContentInstallDependency]
    let warnings: [String]
    let blockedReasons: [String]
    let totalSize: Int64?
    let typedPlan: CoreTypedInstallPlan
}

struct CoreContentUpdatePlanResource: Codable, Equatable, Sendable {
    let projectId: String?
    let projectTitle: String
    let currentReleaseId: String?
    let currentFileName: String
    let currentSha1: String?
    let currentTargetPath: String
    let remoteReleaseId: String?
    let remoteFileName: String?
    let remoteUrl: String?
    let remoteSha1: String?
    let remoteSize: Int64?
    let selected: Bool?
    let dependencies: [CoreContentInstallDependency]
}

struct CoreContentUpdatePlanRequest: Codable, Equatable, Sendable {
    let mode: String
    let gameDir: String
    let source: String
    let resources: [CoreContentUpdatePlanResource]
}

struct CoreContentUpdateLockEntry: Codable, Equatable, Sendable {
    let projectId: String?
    let projectTitle: String
    let oldReleaseId: String?
    let newReleaseId: String?
    let oldSha1: String?
    let newSha1: String?
    let targetPath: String
    let backupPath: String?
}

struct CoreContentUpdatePlanResponse: Decodable, Equatable, Sendable {
    let action: String
    let mode: String
    let lockfilePath: String
    let lockEntries: [CoreContentUpdateLockEntry]
    let warnings: [String]
    let blockedReasons: [String]
    let typedPlan: CoreTypedInstallPlan
}

struct CoreContentTargetInstance: Codable, Equatable, Sendable {
    let instanceId: String?
    let name: String
    let gameDir: String
    let minecraftVersion: String
    let loader: String?
}

struct CoreContentResolveTargetsRequest: Codable, Equatable, Sendable {
    let projectType: String
    let projectTitle: String
    let releaseId: String?
    let targetSubdir: String
    let gameVersions: [String]
    let loaders: [String]
    let instances: [CoreContentTargetInstance]
}

struct CoreContentTargetCandidate: Decodable, Equatable, Identifiable, Sendable {
    let instanceId: String?
    let name: String
    let gameDir: String
    let minecraftVersion: String
    let loader: String?
    let score: Int
    let reasons: [String]
    let blockedReasons: [String]
    let recommended: Bool

    var id: String {
        [instanceId, gameDir, name].compactMap { $0 }.joined(separator: "|")
    }
}

struct CoreContentResolveTargetsResponse: Decodable, Equatable, Sendable {
    let candidates: [CoreContentTargetCandidate]
    let recommended: CoreContentTargetCandidate?
    let blockedReasons: [String]
}

struct CoreContentSearchRequest: Encodable, Equatable, Sendable {
    let source: ContentSourceID
    let text: String
    let projectTypes: [OnlineProjectType]
    let categories: [String]
    let gameVersion: String?
    let loaders: [LoaderFamily]
    let sort: OnlineContentSort
    let offset: Int
    let limit: Int
    let curseForgeAPIKey: String?

    init(source: ContentSourceID, query: OnlineSearchQuery, curseForgeAPIKey: String?) {
        self.source = source
        self.text = query.text
        self.projectTypes = Array(query.projectTypes)
        self.categories = Array(query.categories)
        self.gameVersion = query.gameVersion
        self.loaders = Array(query.loaders)
        self.sort = query.sort
        self.offset = query.offset
        self.limit = query.limit
        self.curseForgeAPIKey = curseForgeAPIKey
    }
}

struct CoreContentProjectRequest: Encodable, Equatable, Sendable {
    let source: ContentSourceID
    let projectId: String
    let query: CoreContentSearchRequest
    let curseForgeAPIKey: String?
}

struct CoreContentProjectResponse: Decodable, Equatable, Sendable {
    let project: OnlineProject
    let releases: [OnlineRelease]
}

struct CoreMinecraftPackageRequest: Encodable, Equatable, Sendable {
    let id: String
    let url: URL
}

struct CoreMinecraftInstallStatusRequest: Encodable, Equatable, Sendable {
    let versionIds: [String]
    let gameDirs: [String]
}

struct CoreMinecraftInstallStatus: Decodable, Equatable, Sendable {
    let versionId: String
    let installed: Bool
    let versionJson: Bool
    let clientJar: Bool
    let diskUsageBytes: Int64?
    let installRoot: String?
    let archived: Bool
    let archivePath: String?
}

struct CoreInstalledMinecraftInstance: Decodable, Equatable, Sendable {
    let versionId: String
    let minecraftVersion: String?
    let loader: String?
    let loaderVersion: String?
    let name: String?
    let gameDir: String
    let versionJson: Bool
    let clientJar: Bool
    let diskUsageBytes: Int64?
    let archived: Bool
    let archivePath: String?
}

struct CoreContentLoaderRequest: Encodable, Equatable, Sendable {
    let minecraftVersion: String
}

struct CoreGameConfigurationRequest: Codable, Equatable, Sendable {
    let id: String?
    let name: String
    let minecraftVersion: String
    let loader: String?
    let loaderVersion: String?
    let gameDir: String
    let javaPath: String?
    let memoryMb: Int
    let memoryPolicy: String
    let jvmProfile: String
    let graphicsProfile: String
    let customMemoryMb: Int?
    let customJvmArgs: [String]
    let status: String?
    let isFavorite: Bool
    let lastLaunchedAt: String?
    let lastLaunchState: String?
    let launchCount: Int
    let isHiddenFromRecent: Bool

    init(instance: GameInstance) {
        self.id = instance.id.uuidString
        self.name = instance.name
        self.minecraftVersion = instance.minecraftVersion
        self.loader = instance.loader?.rawValue
        self.loaderVersion = instance.loaderVersion
        self.gameDir = instance.gameDirectory
        self.javaPath = instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instance.javaPath
        self.memoryMb = instance.memoryMb
        self.memoryPolicy = instance.memoryPolicy.rawValue
        self.jvmProfile = instance.jvmProfile.rawValue
        self.graphicsProfile = instance.graphicsProfile.rawValue
        self.customMemoryMb = instance.customMemoryMb
        self.customJvmArgs = splitJvmArguments(instance.customJvmArguments)
        self.status = instance.status.rawValue
        self.isFavorite = instance.isFavorite
        self.lastLaunchedAt = instance.lastLaunchedAt.map { ISO8601DateFormatter().string(from: $0) }
        self.lastLaunchState = instance.lastLaunchState?.rawValue
        self.launchCount = instance.launchCount
        self.isHiddenFromRecent = instance.isHiddenFromRecent
    }
}

func splitJvmArguments(_ value: String) -> [String] {
    var result: [String] = []
    var current = ""
    var quote: Character?
    var escaping = false

    for char in value {
        if escaping {
            current.append(char)
            escaping = false
            continue
        }
        if char == "\\" {
            escaping = true
            continue
        }
        if let activeQuote = quote {
            if char == activeQuote {
                quote = nil
            } else {
                current.append(char)
            }
            continue
        }
        if char == "\"" || char == "'" {
            quote = char
            continue
        }
        if char.isWhitespace {
            if !current.isEmpty {
                result.append(current)
                current.removeAll(keepingCapacity: true)
            }
        } else {
            current.append(char)
        }
    }
    if escaping {
        current.append("\\")
    }
    if !current.isEmpty {
        result.append(current)
    }
    return result
}

struct CoreLaunchLibraryRequest: Encodable, Equatable, Sendable {
    let configurations: [CoreGameConfigurationRequest]

    init(instances: [GameInstance]) {
        self.configurations = instances.map(CoreGameConfigurationRequest.init(instance:))
    }
}

struct CoreLaunchContentSummary: Decodable, Equatable, Sendable {
    let modCount: Int
    let resourcePackCount: Int
    let shaderPackCount: Int
    let saveCount: Int
    let logCount: Int
    let conflictCount: Int
    let warningCount: Int
}

struct CoreLaunchInstanceSummary: Decodable, Equatable, Identifiable, Sendable {
    let id: String?
    let name: String
    let minecraftVersion: String
    let loader: String?
    let gameDir: String
    let status: String
    let canLaunch: Bool
    let needsAttention: Bool
    let attentionReasons: [String]
    let isFavorite: Bool
    let lastLaunchedAt: String?
    let lastLaunchState: String?
    let launchCount: Int
    let isHiddenFromRecent: Bool
    let installedAt: String?
    let content: CoreLaunchContentSummary
    let diskUsageBytes: Int64?

    var stableID: String { id ?? "\(minecraftVersion)|\(gameDir)" }
}

struct CoreLaunchLibraryResponse: Decodable, Equatable, Sendable {
    let instances: [CoreLaunchInstanceSummary]
    let totalCount: Int
    let readyCount: Int
    let attentionCount: Int
    let recentIds: [String]
    let recentInstallIds: [String]?
    let favoriteIds: [String]
    let attentionIds: [String]
}

struct CoreConfigurationCapabilities: Decodable, Equatable, Sendable {
    let canLaunch: Bool
    let canManageMods: Bool
    let canManageResourcePacks: Bool
    let canManageShaderPacks: Bool
    let canInstallLoader: Bool
    let canExportModpack: Bool
    let canBackupSaves: Bool
    let canRepair: Bool
    let reasons: [String]
}

struct CoreLoaderCompatibilityEntry: Decodable, Equatable, Sendable {
    let loader: String
    let available: Bool
    let recommendedVersion: String?
    let versions: [String]
    let reason: String?
    let experimental: Bool
}

struct CoreLoaderCompatibilityResponse: Decodable, Equatable, Sendable {
    let minecraftVersion: String
    let options: [CoreLoaderCompatibilityEntry]
}

struct CoreVersionSwitchPreflightRequest: Encodable, Equatable, Sendable {
    let configuration: CoreGameConfigurationRequest
    let targetMinecraftVersion: String
}

struct CoreVersionSwitchPreflightResponse: Decodable, Equatable, Sendable {
    let allowed: Bool
    let recommendedAction: String
    let warnings: [String]
    let blockingReasons: [String]
    let capabilities: CoreConfigurationCapabilities
}

struct CoreModpackPreflightRequest: Encodable, Equatable, Sendable {
    let sourceType: String
    let sourcePath: String?
    let targetGameDir: String?
}

struct CoreModpackPreflightResponse: Decodable, Equatable, Sendable {
    let valid: Bool
    let name: String?
    let minecraftVersion: String?
    let loader: String?
    let loaderVersion: String?
    let modCount: Int
    let resourcePackCount: Int
    let shaderPackCount: Int
    let overridesCount: Int
    let estimatedDownloadBytes: Int64?
    let requiresApiKey: Bool
    let warnings: [String]
    let blockingReasons: [String]
    let typedPlan: CoreTypedInstallPlan
}

struct CoreModpackImportRequest: Encodable, Equatable, Sendable {
    let sourceType: String
    let sourcePath: String
    let targetGameDir: String
}

struct CoreModpackImportResponse: Decodable, Equatable, Sendable {
    let imported: Bool
    let targetGameDir: String
    let stagingPath: String
    let lockfilePath: String
    let filesWritten: Int
    let warnings: [String]
    let blockingReasons: [String]
    let typedPlan: CoreTypedInstallPlan
}

struct CoreExportBackupPreflightRequest: Encodable, Equatable, Sendable {
    let configuration: CoreGameConfigurationRequest
    let kind: String
    let targetPath: String?
}

struct CoreExportBackupPreflightResponse: Decodable, Equatable, Sendable {
    let allowed: Bool
    let warnings: [String]
    let blockingReasons: [String]
    let estimatedBytes: Int64?
    let checkedPaths: [String]
}

struct CoreJavaCheckRequest: Encodable, Equatable, Sendable {
    let java: String?
}

struct CoreJavaManagedResponse: Codable, Equatable, Sendable {
    let runtimes: [CoreJavaManagedRuntime]
    let root: String
}

struct CoreJavaManagedRuntime: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let vendor: String
    let provider: String
    let featureVersion: Int
    let version: String
    let os: String
    let arch: String
    let imageType: String
    let javaHome: String
    let javaExecutable: String
    let sourceUrl: String
    let sha256: String?
    let installedAt: Date
    let lastVerifiedAt: Date?
    let diskUsageBytes: Int64?
    let usedByInstanceCount: Int

    var displayName: String {
        "Java \(featureVersion)"
    }

    var detailText: String {
        [
            vendor.capitalized,
            osDisplayName,
            archDisplayName,
            imageType.uppercased(),
            diskUsageBytes.map { formattedBytes($0) }
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    private var osDisplayName: String {
        os == "mac" ? "macOS" : os
    }

    private var archDisplayName: String {
        switch arch {
        case "aarch64":
            return "ARM64"
        case "x64":
            return "x64"
        default:
            return arch
        }
    }
}

struct CoreJavaRuntimeDownloadSpec: Codable, Equatable, Sendable {
    let provider: String
    let vendor: String
    let featureVersion: Int
    let os: String
    let arch: String
    let imageType: String
    let url: String
    let checksumUrl: String?
    let sha256: String?
}

struct CoreJavaRuntimeCatalogItem: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let provider: String
    let vendor: String
    let featureVersion: Int
    let os: String
    let arch: String
    let imageType: String
    let download: CoreJavaRuntimeDownloadSpec
    let stale: Bool?
    let cachedAt: Date?
    let warnings: [String]
}

struct CoreJavaRuntimeResolveRequest: Encodable, Equatable, Sendable {
    let minecraftVersion: String
    let gameDir: String?
    let instanceId: String?
    let policy: String?
    let preferredRuntimeId: String?
    let customPath: String?
}

struct CoreJavaRuntimeResolveResponse: Codable, Equatable, Sendable {
    let minecraftVersion: String
    let requiredMajorVersion: Int
    let source: String
    let policy: String
    let status: String
    let selectedRuntimeId: String?
    let javaExecutable: String?
    let download: CoreJavaRuntimeDownloadSpec?
    let actions: [String]
    let warnings: [String]
    let blockingReasons: [String]

    var isReady: Bool { status == "ready" }
    var isDownloadable: Bool { status == "downloadable" }

    var conciseStatus: String {
        switch status {
        case "ready":
            if selectedRuntimeId != nil {
                return "Auto · Java \(requiredMajorVersion) · Panino"
            }
            return "Auto · Java \(requiredMajorVersion) · Ready"
        case "downloadable":
            return "Java \(requiredMajorVersion) needs download"
        case "incompatible":
            return "Java \(requiredMajorVersion) is incompatible"
        case "missing":
            return "Java \(requiredMajorVersion) is missing"
        case "blocked":
            return blockingReasons.first ?? "Java runtime is blocked"
        default:
            return "Java \(requiredMajorVersion) · \(status)"
        }
    }
}

struct CoreJavaRuntimeInstallRequest: Encodable, Equatable, Sendable {
    let featureVersion: Int
    let provider: String
    let vendor: String
    let os: String?
    let arch: String?
    let imageType: String
    let setDefault: Bool
    let download: CoreDownloadRuntimeOptions
}

struct CoreJavaRuntimeSelectRequest: Encodable, Equatable, Sendable {
    let scope: String
    let instanceId: String?
    let policy: String
    let preferredRuntimeId: String?
    let customPath: String?
    let lockPatchVersion: Bool
}

struct CoreJavaRuntimePolicyRecord: Codable, Equatable, Sendable {
    let scope: String
    let instanceId: String?
    let policy: String
    let preferredRuntimeId: String?
    let customPath: String?
    let lockPatchVersion: Bool
    let updatedAt: Date
}

struct CoreJavaRuntimeSelectResponse: Decodable, Equatable, Sendable {
    let policy: CoreJavaRuntimePolicyRecord
    let message: String
}

struct CoreJavaRuntimeImportRequest: Encodable, Equatable, Sendable {
    let sourcePath: String
    let provider: String
    let vendor: String
    let featureVersion: Int?
    let os: String?
    let arch: String?
    let imageType: String
    let setDefault: Bool
}

struct CoreJavaRuntimeVerifyRequest: Encodable, Equatable, Sendable {
    let id: String
}

struct CoreJavaRuntimeLocalDeleteRequest: Encodable, Equatable, Sendable {
    let path: String
}

struct CoreJavaRuntimeLocalDeleteResponse: Decodable, Equatable, Sendable {
    let deleted: Bool
    let path: String
    let targetRoot: String?
    let message: String
}

struct CoreJavaRuntimeDeleteResponse: Decodable, Equatable, Sendable {
    let deleted: Bool
    let id: String
    let message: String
    let references: [String]?
}

struct CoreJavaRuntimeCleanupResponse: Decodable, Equatable, Sendable {
    let deletedRuntimeIds: [String]
    let deletedDownloadFiles: [String]
    let deletedStagingDirs: [String]
    let freedBytes: Int64
    let keptRuntimeIds: [String]
    let message: String
}

struct JavaRuntimeCandidate: Decodable, Identifiable, Equatable, Sendable {
    let path: String
    let isAvailable: Bool
    let versionSummary: String
    let source: String
    let canDelete: Bool?
    let deleteTarget: String?

    var id: String { path }

    var displayText: String {
        cleanVersionSummary.isEmpty ? path : cleanVersionSummary
    }

    var hasMeaningfulSummary: Bool {
        !cleanVersionSummary.isEmpty
    }

    var pathDetailText: String {
        path.isEmpty ? "java" : path
    }

    var supportsDeletion: Bool {
        canDelete == true && !(deleteTarget?.isEmpty ?? true)
    }

    private var cleanVersionSummary: String {
        let trimmed = versionSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.localizedCaseInsensitiveCompare("Property settings:") != .orderedSame else {
            return ""
        }
        return trimmed
    }
}

struct CoreLocalResourceScanRequest: Encodable, Equatable, Sendable {
    let gameDir: String
    let kind: ManagedAssetKind
    let loader: LoaderKind?
}

struct CoreLocalResourcePathRequest: Encodable, Equatable, Sendable {
    let path: String
}

struct CoreLocalResourceImportRequest: Encodable, Equatable, Sendable {
    let sourcePath: String
    let gameDir: String
    let kind: ManagedAssetKind
}

struct CoreLocalArchiveRequest: Encodable, Equatable, Sendable {
    let sourcePath: String
    let targetPath: String
}

struct CoreLocalArchiveImportRequest: Encodable, Equatable, Sendable {
    let archivePath: String
    let targetDir: String
    let deleteArchive: Bool
}

struct CoreMinecraftCleanVersionRequest: Encodable, Equatable, Sendable {
    let version: String
    let gameDir: String
}

enum CoreMinecraftVersionStorageAction: String, Encodable, Equatable, Sendable {
    case delete
    case archive
    case restore
}

struct CoreMinecraftVersionStorageRequest: Encodable, Equatable, Sendable {
    let version: String
    let gameDir: String
    let action: CoreMinecraftVersionStorageAction
}

struct CoreLocalResourceMutationResponse: Decodable, Equatable, Sendable {
    let changed: Bool
    let path: String?
    let message: String
}

struct CoreManagedAsset: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let path: String
    let isEnabled: Bool
    let conflictMessage: String?
    let metadata: ManagedAssetMetadata
    let fileSizeBytes: Int64
    let modifiedAt: Date?
    let source: String?
    let projectURL: URL?
}

struct CoreEvent: Decodable, Equatable, Identifiable {
    let eventType: String
    let taskId: String?
    let version: String?
    let message: String
    let time: String
    let payload: CoreEventPayload?

    var id: String {
        [time, eventType, taskId ?? "core"].joined(separator: ":")
    }

    private enum CodingKeys: String, CodingKey {
        case eventType = "type"
        case taskId
        case version
        case message
        case time
        case payload
    }
}

struct CoreEventPayload: Decodable, Equatable {
    let state: String?
    let errorCode: String?
    let errorDetail: String?
    let diagnostic: CoreDiagnostic?
    let diagnostics: [CoreDiagnostic]?
    let percent: Double?
    let label: String?
    let phaseId: String?
    let phaseTitle: String?
    let phaseIndex: Int?
    let phaseCount: Int?
    let phasePercent: Double?
    let overallPercent: Double?
    let completedJobs: Int?
    let totalJobs: Int?
    let completedBytes: Int64?
    let totalBytes: Int64?
    let speedBytesPerSecond: Int64?
    let movingAverageSpeedBytesPerSecond: Int64?
    let etaSeconds: Int64?
    let currentLabel: String?
    let activeWorkers: Int?
    let retryCount: Int?
    let sourceHost: String?
    let host: String?
    let source: String?
    let hosts: [TaskProgressHost]?
    let throttleReason: String?
    let multipart: TaskProgressMultipart?
    let session: CoreTaowaSession?

    func taskProgress(taskId: String?) -> TaskProgress? {
        guard let taskId,
              let phaseId,
              let phaseTitle,
              let phaseIndex,
              let phaseCount
        else { return nil }

        let resolvedOverallPercent = overallPercent ?? percent
        let resolvedCurrentLabel = currentLabel ?? label ?? ""
        let resolvedSourceHost = sourceHost ?? host ?? source

        return TaskProgress(
            taskId: taskId,
            phaseId: phaseId,
            phaseTitle: phaseTitle,
            phaseIndex: phaseIndex,
            phaseCount: phaseCount,
            phasePercent: phasePercent,
            overallPercent: resolvedOverallPercent,
            completedJobs: completedJobs ?? 0,
            totalJobs: totalJobs ?? 0,
            completedBytes: completedBytes ?? 0,
            totalBytes: totalBytes ?? 0,
            speedBytesPerSecond: speedBytesPerSecond ?? 0,
            movingAverageSpeedBytesPerSecond: movingAverageSpeedBytesPerSecond,
            etaSeconds: etaSeconds,
            currentLabel: resolvedCurrentLabel,
            activeWorkers: activeWorkers ?? 0,
            retryCount: retryCount ?? 0,
            sourceHost: resolvedSourceHost,
            hosts: hosts,
            throttleReason: throttleReason,
            multipart: multipart
        )
    }
}

enum LogSource: String, Equatable, Sendable {
    case app
    case core
    case game
}

struct LogLine: Identifiable, Equatable, Sendable {
    let id: UUID
    let source: LogSource
    let text: String

    init(text: String, source: LogSource = .app) {
        self.id = UUID()
        self.source = source
        self.text = text
    }
}

struct JavaRuntimeStatus: Codable, Equatable, Sendable {
    let path: String
    let isAvailable: Bool
    let versionSummary: String
    let version: String?
    let majorVersion: Int?
    let vendor: String?
    let architecture: String?
    let executablePermission: Bool?
    let rawSummary: String?

    init(
        path: String,
        isAvailable: Bool,
        versionSummary: String,
        version: String? = nil,
        majorVersion: Int? = nil,
        vendor: String? = nil,
        architecture: String? = nil,
        executablePermission: Bool? = nil,
        rawSummary: String? = nil
    ) {
        self.path = path
        self.isAvailable = isAvailable
        self.versionSummary = versionSummary
        self.version = version
        self.majorVersion = majorVersion
        self.vendor = vendor
        self.architecture = architecture
        self.executablePermission = executablePermission
        self.rawSummary = rawSummary
    }

    var displayText: String {
        if isAvailable {
            return versionSummary.isEmpty ? "Java available" : versionSummary
        }
        return versionSummary.isEmpty ? "Java unavailable" : versionSummary
    }
}

enum CoreConnectionState: Equatable {
    case stopped
    case starting
    case running
    case stopping
    case failed(String)

    var title: String {
        switch self {
        case .stopped:
            return "Core stopped"
        case .starting:
            return "Starting Core"
        case .running:
            return "Core connected"
        case .stopping:
            return "Stopping Core"
        case .failed:
            return "Core failed"
        }
    }

    var detail: String {
        switch self {
        case .failed(let message):
            return message
        default:
            return title
        }
    }

    var isReady: Bool {
        self == .running
    }
}
