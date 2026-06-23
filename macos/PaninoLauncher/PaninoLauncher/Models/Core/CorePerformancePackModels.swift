import Foundation

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
