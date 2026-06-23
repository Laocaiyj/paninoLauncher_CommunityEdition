import Foundation

enum OnlineInstallPlanAction: String, Sendable {
    case install
    case update
    case alreadyInstalled
    case unsupported
    case blocked
}

struct OnlineInstallPlan: Identifiable, Equatable, Sendable {
    let id: String
    let projectTitle: String
    let releaseTitle: String
    let projectType: OnlineProjectType
    let managedKind: ManagedAssetKind?
    let sourceURL: URL?
    let destinationURL: URL?
    let targetConfigurationName: String?
    let targetMinecraftVersion: String?
    let fileName: String
    let fileSizeBytes: Int64
    let hashes: [String: String]
    let action: OnlineInstallPlanAction
    let dependencies: [OnlineDependency]
    let warnings: [String]
    let blockingReasons: [String]
}
