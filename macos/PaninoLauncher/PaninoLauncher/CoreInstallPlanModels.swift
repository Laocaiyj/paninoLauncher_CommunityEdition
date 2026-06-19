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
