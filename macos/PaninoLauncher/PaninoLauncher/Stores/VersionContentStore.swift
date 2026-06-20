import SwiftUI

@MainActor
final class VersionContentStore: ObservableObject {
    @Published var selectedVersionKind: MinecraftVersionKind = .release
    @Published var versionUsageFilter: VersionUsageFilter = .all
    @Published var selectedVersionID: String?
    @Published var selectedLoader: LoaderKind = .fabric
    @Published var selectedAssetKind: ManagedAssetKind = .mods
    @Published var selectedAssetSort: ManagedAssetSort = .name
    @Published var managedAssets: [ManagedAsset] = []
    @Published var fileStatus = "No folder scanned"
    @Published var versionStatus = "Versions not loaded"
    @Published var hasRemoteVersions = false
    @Published var latestReleaseID: String?
    @Published var latestSnapshotID: String?
    @Published var installedInstances: [CoreInstalledMinecraftInstance] = []
    var assetRefreshTask: Task<Void, Never>?
    var versionRefreshTask: Task<Void, Never>?
    var detailTask: Task<Void, Never>?
    var assetLinks: [String: AssetManualLink] = [:]
    var coreBackend: VersionContentCoreBackend?

    @Published var versions: [MinecraftVersionInfo]

    init() {
        versions = VersionContentInfoFactory.fallbackVersions
        loadAssetLinks()
    }

    func configure(coreBackend: VersionContentCoreBackend) {
        self.coreBackend = coreBackend
    }

    var filteredVersions: [MinecraftVersionInfo] {
        versions.filter { version in
            guard version.kind == selectedVersionKind else { return false }
            switch versionUsageFilter {
            case .all:
                return true
            case .installed:
                return version.isInstalled
            case .usedByInstance:
                return version.isUsedByInstance
            }
        }
    }

    var selectedVersion: MinecraftVersionInfo? {
        let selected = selectedVersionID.flatMap { id in versions.first { $0.id == id } }
        return selected ?? filteredVersions.first
    }

}
