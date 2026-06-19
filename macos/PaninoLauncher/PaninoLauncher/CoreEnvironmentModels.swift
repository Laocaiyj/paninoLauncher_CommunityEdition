import Foundation

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
