import Foundation
import AppKit
import SwiftUI

@MainActor
final class VersionContentStore: ObservableObject {
    @Published var selectedVersionKind: MinecraftVersionKind = .release
    @Published var versionUsageFilter: VersionUsageFilter = .all
    @Published var selectedVersionID: String?
    @Published var selectedLoader: LoaderKind = .fabric
    @Published var selectedAssetKind: ManagedAssetKind = .mods
    @Published var selectedAssetSort: ManagedAssetSort = .name
    @Published private(set) var managedAssets: [ManagedAsset] = []
    @Published private(set) var fileStatus = "No folder scanned"
    @Published private(set) var versionStatus = "Versions not loaded"
    @Published private(set) var hasRemoteVersions = false
    @Published private(set) var latestReleaseID: String?
    @Published private(set) var latestSnapshotID: String?
    @Published private(set) var installedInstances: [CoreInstalledMinecraftInstance] = []
    private var assetRefreshTask: Task<Void, Never>?
    private var versionRefreshTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    private var assetLinks: [String: AssetManualLink] = [:]
    private var coreBackend: VersionContentCoreBackend?

    @Published private(set) var versions: [MinecraftVersionInfo]

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

    func refreshMinecraftVersions(instances: [GameInstance], settings: LauncherSettings) {
        guard let coreBackend else {
            versionStatus = "Core backend is not ready for Minecraft versions"
            return
        }
        versionRefreshTask?.cancel()
        versionStatus = "Refreshing Minecraft manifest via Core"
        versionRefreshTask = Task {
            do {
                let result = try await VersionContentRefreshService.loadMinecraftVersions(
                    coreBackend: coreBackend,
                    instances: instances,
                    settings: settings
                )
                guard !Task.isCancelled else { return }
                latestReleaseID = result.latestReleaseID
                latestSnapshotID = result.latestSnapshotID
                self.installedInstances = result.installedInstances
                versions = result.versions
                hasRemoteVersions = true
                selectedVersionID = selectedVersionID ?? result.versions.first(where: { $0.kind == .release })?.id
                versionStatus = "Loaded \(result.versions.count) Minecraft versions"
            } catch {
                guard !Task.isCancelled else { return }
                hasRemoteVersions = false
                versionStatus = "Version refresh failed: \(error.localizedDescription)"
            }
        }
    }

    func loadDetails(for version: MinecraftVersionInfo?, instances: [GameInstance], settings: LauncherSettings) {
        guard let version, let manifestURL = version.manifestURL else { return }
        guard let coreBackend else {
            versionStatus = "Core backend is not ready for Minecraft version details"
            return
        }
        selectedVersionID = version.id
        detailTask?.cancel()
        versionStatus = "Loading details for \(version.id) via Core"
        detailTask = Task {
            do {
                let result = try await VersionContentRefreshService.loadDetails(
                    coreBackend: coreBackend,
                    version: version,
                    manifestURL: manifestURL,
                    instances: instances,
                    settings: settings
                )
                guard !Task.isCancelled else { return }
                if let index = versions.firstIndex(where: { $0.id == result.versionID }) {
                    versions[index] = result.versionInfo
                }
                versionStatus = "Loaded details for \(result.versionID)"
            } catch {
                guard !Task.isCancelled else { return }
                versionStatus = "Version detail failed: \(error.localizedDescription)"
            }
        }
    }

    func refreshAssets(for instance: GameInstance?) {
        guard let gameDirectory = instance?.gameDirectory, !gameDirectory.isEmpty else {
            assetRefreshTask?.cancel()
            managedAssets = []
            fileStatus = "Select a game configuration with a game directory"
            return
        }
        guard let coreBackend else {
            assetRefreshTask?.cancel()
            managedAssets = []
            fileStatus = "Core backend is not ready for local content"
            return
        }

        let selectedKind = selectedAssetKind
        let selectedLoader = selectedLoader
        let selectedSort = selectedAssetSort
        let assetLinks = assetLinks
        assetRefreshTask?.cancel()
        fileStatus = "Scanning \(selectedKind.title) via Core"
        assetRefreshTask = Task {
            do {
                let assets = try await VersionContentRefreshService.loadAssets(
                    coreBackend: coreBackend,
                    gameDirectory: gameDirectory,
                    kind: selectedKind,
                    loader: selectedLoader,
                    sort: selectedSort,
                    links: assetLinks
                )
                guard !Task.isCancelled else { return }
                managedAssets = assets
                fileStatus = "Scanned \(selectedKind.folderName) via Core"
            } catch {
                guard !Task.isCancelled else { return }
                managedAssets = []
                fileStatus = "Scan failed: \(error.localizedDescription)"
            }
        }
    }

    func toggle(_ asset: ManagedAsset, instance: GameInstance?) {
        guard let coreBackend else {
            fileStatus = "Core backend is not ready for local content"
            return
        }
        fileStatus = "Updating \(asset.name) via Core"
        Task {
            do {
                _ = try await coreBackend.toggleLocalResource(asset.url.path)
                refreshAssets(for: instance)
            } catch {
                fileStatus = "Toggle failed: \(error.localizedDescription)"
            }
        }
    }

    func delete(_ asset: ManagedAsset, instance: GameInstance?) {
        guard let coreBackend else {
            fileStatus = "Core backend is not ready for local content"
            return
        }
        fileStatus = "Deleting \(asset.name) via Core"
        Task {
            do {
                _ = try await coreBackend.deleteLocalResource(asset.url.path)
                refreshAssets(for: instance)
            } catch {
                fileStatus = "Delete failed: \(error.localizedDescription)"
            }
        }
    }

    func link(_ asset: ManagedAsset, source: String, projectURL: URL?, instance: GameInstance?) {
        assetLinks[asset.id] = AssetManualLink(source: source, projectURL: projectURL)
        saveAssetLinks()
        refreshAssets(for: instance)
    }

    func mutateVersionStorage(_ version: MinecraftVersionInfo, action: CoreMinecraftVersionStorageAction, instances: [GameInstance], settings: LauncherSettings) {
        if action != .restore, instances.contains(where: { $0.minecraftVersion == version.id }) {
            versionStatus = "Version \(version.id) is used by a game configuration"
            return
        }
        guard let coreBackend else {
            versionStatus = "Core backend is not ready for Minecraft version storage"
            return
        }
        versionStatus = "\(VersionContentInfoFactory.actionStatusPrefix(action)) \(version.id) via Core"
        Task {
            do {
                guard let installRoot = version.installRoot else {
                    versionStatus = "Version \(version.id) does not have an isolated install root"
                    return
                }
                let response = try await coreBackend.mutateMinecraftVersionStorage(version.id, installRoot, action)
                versionStatus = response.message
                refreshMinecraftVersions(instances: instances, settings: settings)
            } catch {
                versionStatus = "Version storage failed: \(error.localizedDescription)"
            }
        }
    }

    func cleanUnusedVersion(_ version: MinecraftVersionInfo, instances: [GameInstance], settings: LauncherSettings) {
        mutateVersionStorage(version, action: .delete, instances: instances, settings: settings)
    }

    func importLocalFile(_ sourceURL: URL, kind: ManagedAssetKind, instance: GameInstance?) async throws -> CoreLocalResourceMutationResponse {
        guard let coreBackend else {
            throw VersionContentStoreError.coreBackendUnavailable
        }
        guard let gameDirectory = instance?.gameDirectory, !gameDirectory.isEmpty else {
            throw VersionContentStoreError.missingInstanceGameDirectory
        }
        let response = try await coreBackend.importLocalResource(sourceURL.path, gameDirectory, kind)
        refreshAssets(for: instance)
        return response
    }

    func openFolder(for instance: GameInstance?) {
        guard let folderURL = folderURL(for: instance) else { return }
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folderURL)
    }

    private func folderURL(for instance: GameInstance?) -> URL? {
        guard let path = instance?.gameDirectory, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent(selectedAssetKind.folderName, isDirectory: true)
    }

    private func loadAssetLinks() {
        do {
            let url = try assetLinksURL()
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                assetLinks = try JSONDecoder.panino.decode([String: AssetManualLink].self, from: data)
            }
        } catch {
            fileStatus = "Asset links load failed: \(error.localizedDescription)"
        }
    }

    private func saveAssetLinks() {
        do {
            let url = try assetLinksURL()
            let data = try JSONEncoder.panino.encode(assetLinks)
            try data.write(to: url, options: .atomic)
        } catch {
            fileStatus = "Asset links save failed: \(error.localizedDescription)"
        }
    }

    private func assetLinksURL() throws -> URL {
        try LauncherPaths.appSupportDirectory().appendingPathComponent("asset-links.json")
    }

}
