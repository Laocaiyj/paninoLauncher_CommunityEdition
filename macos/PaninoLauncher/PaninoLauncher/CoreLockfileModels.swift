import Foundation

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
