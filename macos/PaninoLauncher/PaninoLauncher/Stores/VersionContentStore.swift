import Foundation
import AppKit
import SwiftUI

@MainActor
struct VersionContentCoreBackend {
    let minecraftVersions: () async throws -> [MinecraftRemoteVersion]
    let minecraftInstallStatus: (_ versionIds: [String], _ gameDirs: [String]) async throws -> [CoreMinecraftInstallStatus]
    let installedMinecraftInstances: (_ versionIds: [String], _ gameDirs: [String]) async throws -> [CoreInstalledMinecraftInstance]
    let minecraftPackage: (MinecraftRemoteVersion) async throws -> MinecraftVersionPackage
    let localResources: (_ gameDir: String, _ kind: ManagedAssetKind, _ loader: LoaderKind) async throws -> [CoreManagedAsset]
    let toggleLocalResource: (_ path: String) async throws -> CoreLocalResourceMutationResponse
    let deleteLocalResource: (_ path: String) async throws -> CoreLocalResourceMutationResponse
    let importLocalResource: (_ sourcePath: String, _ gameDir: String, _ kind: ManagedAssetKind) async throws -> CoreLocalResourceMutationResponse
    let cleanMinecraftVersion: (_ version: String, _ gameDir: String) async throws -> CoreLocalResourceMutationResponse
    let mutateMinecraftVersionStorage: (_ version: String, _ gameDir: String, _ action: CoreMinecraftVersionStorageAction) async throws -> CoreLocalResourceMutationResponse
}

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
        versions = VersionContentStore.fallbackVersions
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
                let remoteVersions = try await coreBackend.minecraftVersions()
                let gameDirectories = Self.candidateGameDirectories(instances: instances, settings: settings)
                let statuses: [CoreMinecraftInstallStatus]
                do {
                    statuses = try await coreBackend.minecraftInstallStatus(
                        remoteVersions.map(\.id),
                        gameDirectories.map(\.path)
                    )
                } catch {
                    statuses = []
                }
                let installedInstances: [CoreInstalledMinecraftInstance]
                do {
                    installedInstances = try await coreBackend.installedMinecraftInstances(
                        remoteVersions.map(\.id),
                        gameDirectories.map(\.path)
                    )
                } catch {
                    installedInstances = Self.installedInstances(from: statuses)
                }
                let statusByVersion = Dictionary(uniqueKeysWithValues: statuses.map { ($0.versionId, $0) })
                let nextVersions = remoteVersions.map {
                    Self.versionInfo(
                        remoteVersion: $0,
                        instances: instances,
                        settings: settings,
                        package: nil,
                        installStatus: statusByVersion[$0.id]
                    )
                }
                guard !Task.isCancelled else { return }
                latestReleaseID = remoteVersions.first(where: { $0.type == "release" })?.id
                latestSnapshotID = remoteVersions.first(where: { $0.type == "snapshot" })?.id
                self.installedInstances = installedInstances
                versions = nextVersions
                hasRemoteVersions = true
                selectedVersionID = selectedVersionID ?? nextVersions.first(where: { $0.kind == .release })?.id
                versionStatus = "Loaded \(nextVersions.count) Minecraft versions"
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
                let remoteVersion = MinecraftRemoteVersion(
                    id: version.id,
                    type: version.kind.manifestType,
                    url: manifestURL,
                    releasedAt: Self.parseDate(version.releasedAt)
                )
                let gameDirectories = Self.candidateGameDirectories(instances: instances, settings: settings)
                let installStatus = try await coreBackend.minecraftInstallStatus(
                    [version.id],
                    gameDirectories.map(\.path)
                ).first
                let package = try await coreBackend.minecraftPackage(remoteVersion)
                guard !Task.isCancelled else { return }
                if let index = versions.firstIndex(where: { $0.id == version.id }) {
                    versions[index] = Self.versionInfo(
                        remoteVersion: remoteVersion,
                        instances: instances,
                        settings: settings,
                        package: package,
                        installStatus: installStatus
                    )
                }
                versionStatus = "Loaded details for \(version.id)"
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
                let assets = try await coreBackend.localResources(gameDirectory, selectedKind, selectedLoader)
                    .map { Self.asset(from: $0, links: assetLinks) }
                    .sorted { Self.assetSort($0, $1, sort: selectedSort) }

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
        versionStatus = "\(actionStatusPrefix(action)) \(version.id) via Core"
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

    nonisolated private static func asset(
        from coreAsset: CoreManagedAsset,
        links: [String: AssetManualLink]
    ) -> ManagedAsset {
        let url = URL(fileURLWithPath: coreAsset.path)
        let link = links[coreAsset.path]
        return ManagedAsset(
            id: coreAsset.id,
            name: coreAsset.name,
            url: url,
            isEnabled: coreAsset.isEnabled,
            conflictMessage: coreAsset.conflictMessage,
            metadata: coreAsset.metadata,
            fileSizeBytes: coreAsset.fileSizeBytes,
            modifiedAt: coreAsset.modifiedAt,
            source: link?.source ?? coreAsset.source,
            projectURL: link?.projectURL ?? coreAsset.projectURL
        )
    }

    nonisolated private static func assetSort(_ lhs: ManagedAsset, _ rhs: ManagedAsset, sort: ManagedAssetSort) -> Bool {
        switch sort {
        case .name:
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        case .status:
            if lhs.isEnabled != rhs.isEnabled { return lhs.isEnabled && !rhs.isEnabled }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        case .source:
            return (lhs.source ?? "").localizedCaseInsensitiveCompare(rhs.source ?? "") == .orderedAscending
        case .updated:
            return (lhs.modifiedAt ?? .distantPast) > (rhs.modifiedAt ?? .distantPast)
        case .size:
            return lhs.fileSizeBytes > rhs.fileSizeBytes
        }
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

    private static let fallbackVersions: [MinecraftVersionInfo] = [
        MinecraftVersionInfo(id: "1.21.5", kind: .release, releasedAt: "2025-03-25", javaRequirement: "Java 21", downloadState: "Available", verificationState: "Needs download", manifestURL: nil, libraryCount: nil, assetIndexState: "-", clientJarState: "-", nativesState: "-", diskUsageBytes: nil, installRoot: nil, isInstalled: false, isArchived: false, archivePath: nil, isUsedByInstance: false),
        MinecraftVersionInfo(id: "1.20.1", kind: .release, releasedAt: "2023-06-12", javaRequirement: "Java 17", downloadState: "Available", verificationState: "Needs download", manifestURL: nil, libraryCount: nil, assetIndexState: "-", clientJarState: "-", nativesState: "-", diskUsageBytes: nil, installRoot: nil, isInstalled: false, isArchived: false, archivePath: nil, isUsedByInstance: false)
    ]

    private static func versionInfo(
        remoteVersion: MinecraftRemoteVersion,
        instances: [GameInstance],
        settings: LauncherSettings,
        package: MinecraftVersionPackage?,
        installStatus: CoreMinecraftInstallStatus?
    ) -> MinecraftVersionInfo {
        let gameDirectories = candidateGameDirectories(instances: instances, settings: settings)
        let installed = installStatus?.installed ?? false
        let archived = installStatus?.archived ?? false
        let completeInstall = installStatus?.versionJson == true && installStatus?.clientJar == true
        let used = instances.contains { $0.minecraftVersion == remoteVersion.id }
        let packageURL = package.map { _ in remoteVersion.url } ?? remoteVersion.url
        return MinecraftVersionInfo(
            id: remoteVersion.id,
            kind: MinecraftVersionKind(manifestType: remoteVersion.type),
            releasedAt: remoteVersion.releasedAt?.formatted(date: .numeric, time: .omitted) ?? "-",
            javaRequirement: javaRequirement(package?.javaMajorVersion, versionID: remoteVersion.id),
            downloadState: completeInstall ? "Installed" : (archived ? "Archived" : (installed ? "Incomplete" : "Available")),
            verificationState: verificationState(installStatus: installStatus, archived: archived),
            manifestURL: packageURL,
            libraryCount: package?.libraryCount,
            assetIndexState: assetIndexState(package?.assetIndex, gameDirectories: gameDirectories),
            clientJarState: clientJarState(package: package, installStatus: installStatus),
            nativesState: nativesState(package),
            diskUsageBytes: installed ? installStatus?.diskUsageBytes : nil,
            installRoot: installStatus?.installRoot,
            isInstalled: installed,
            isArchived: archived,
            archivePath: installStatus?.archivePath,
            isUsedByInstance: used
        )
    }

    private func actionStatusPrefix(_ action: CoreMinecraftVersionStorageAction) -> String {
        switch action {
        case .delete:
            return "Deleting"
        case .archive:
            return "Archiving"
        case .restore:
            return "Restoring"
        }
    }

    private static func verificationState(installStatus: CoreMinecraftInstallStatus?, archived: Bool) -> String {
        if archived { return "Archived" }
        guard let installStatus else { return "Needs download" }
        if installStatus.versionJson && installStatus.clientJar { return "Files complete" }
        if !installStatus.versionJson { return "Missing version.json" }
        if !installStatus.clientJar { return "Missing client.jar" }
        return "Needs repair"
    }

    private static func candidateGameDirectories(instances: [GameInstance], settings: LauncherSettings) -> [URL] {
        let configurationsDirectory = try? LauncherPaths.gameConfigurationsDirectory()
            .path
        let legacyMinecraftDirectory = try? LauncherPaths.appSupportDirectory()
            .appendingPathComponent("minecraft", isDirectory: true)
            .path
        let configuredDefault = settings.defaultGameDirectory
        let paths = ([configurationsDirectory, legacyMinecraftDirectory, configuredDefault].compactMap { $0 } + instances.map(\.gameDirectory))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        return paths.compactMap { path in
            let standardized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
            guard seen.insert(standardized.path).inserted else { return nil }
            return standardized
        }
    }

    private static func installedInstances(from statuses: [CoreMinecraftInstallStatus]) -> [CoreInstalledMinecraftInstance] {
        statuses.compactMap { status in
            guard status.versionJson, status.clientJar, !status.archived, let installRoot = status.installRoot else {
                return nil
            }
            return CoreInstalledMinecraftInstance(
                versionId: status.versionId,
                minecraftVersion: status.versionId,
                loader: nil,
                loaderVersion: nil,
                name: nil,
                gameDir: installRoot,
                versionJson: status.versionJson,
                clientJar: status.clientJar,
                diskUsageBytes: status.diskUsageBytes,
                archived: status.archived,
                archivePath: status.archivePath
            )
        }
    }

    private static func assetIndexState(_ assetIndex: MinecraftAssetIndex?, gameDirectories: [URL]) -> String {
        guard let assetIndex else { return "Not loaded" }
        let cached = gameDirectories.contains { gameDirectory in
            let url = gameDirectory.appendingPathComponent("assets/indexes/\(assetIndex.id).json")
            return FileManager.default.fileExists(atPath: url.path)
        }
        return cached ? "Cached" : "Missing"
    }

    private static func clientJarState(package: MinecraftVersionPackage?, installStatus: CoreMinecraftInstallStatus?) -> String {
        if installStatus?.clientJar == true { return "Cached" }
        return package?.downloads[.client] == nil ? "Unknown" : "Missing"
    }

    private static func nativesState(_ package: MinecraftVersionPackage?) -> String {
        guard let package else { return "Not loaded" }
        return package.nativeLibraryCount == 0 ? "None" : "\(package.nativeLibraryCount) native libraries"
    }

    private static func javaRequirement(_ majorVersion: Int?, versionID: String) -> String {
        if let majorVersion { return "Java \(majorVersion)" }
        if versionID.compare("1.20.5", options: .numeric) != .orderedAscending { return "Java 21" }
        if versionID.compare("1.18", options: .numeric) != .orderedAscending { return "Java 17" }
        return "Java 8"
    }

    private static func parseDate(_ text: String) -> Date? {
        DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none) == text ? Date() : nil
    }
}
