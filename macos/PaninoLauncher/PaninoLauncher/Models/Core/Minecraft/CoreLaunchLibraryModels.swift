import Foundation

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
