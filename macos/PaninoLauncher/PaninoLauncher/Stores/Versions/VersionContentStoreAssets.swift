import AppKit
import Foundation

@MainActor
extension VersionContentStore {
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

    func loadAssetLinks() {
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

    private func folderURL(for instance: GameInstance?) -> URL? {
        guard let path = instance?.gameDirectory, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent(selectedAssetKind.folderName, isDirectory: true)
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
