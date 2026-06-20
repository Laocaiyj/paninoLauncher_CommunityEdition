import Foundation

enum MinecraftVersionKind: String, CaseIterable, Identifiable {
    case release
    case snapshot
    case oldBeta
    case oldAlpha

    var id: String { rawValue }

    var title: String {
        switch self {
        case .release:
            return "Release"
        case .snapshot:
            return "Snapshot"
        case .oldBeta:
            return "Old Beta"
        case .oldAlpha:
            return "Old Alpha"
        }
    }
}

struct MinecraftVersionInfo: Identifiable, Equatable {
    let id: String
    let kind: MinecraftVersionKind
    let releasedAt: String
    let javaRequirement: String
    let downloadState: String
    let verificationState: String
    let manifestURL: URL?
    let libraryCount: Int?
    let assetIndexState: String
    let clientJarState: String
    let nativesState: String
    let diskUsageBytes: Int64?
    let installRoot: String?
    let isInstalled: Bool
    let isArchived: Bool
    let archivePath: String?
    let isUsedByInstance: Bool
}
