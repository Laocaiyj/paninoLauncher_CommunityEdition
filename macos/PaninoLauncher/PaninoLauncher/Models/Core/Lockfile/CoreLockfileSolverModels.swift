import Foundation

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
