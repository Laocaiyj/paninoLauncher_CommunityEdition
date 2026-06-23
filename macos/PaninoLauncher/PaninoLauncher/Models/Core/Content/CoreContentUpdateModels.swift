import Foundation

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
