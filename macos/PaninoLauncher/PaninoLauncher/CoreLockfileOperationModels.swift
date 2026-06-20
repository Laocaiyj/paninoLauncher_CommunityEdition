import Foundation

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
