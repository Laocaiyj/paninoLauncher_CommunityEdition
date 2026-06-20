import Foundation

struct VersionContentManifestResult {
    let versions: [MinecraftVersionInfo]
    let latestReleaseID: String?
    let latestSnapshotID: String?
    let installedInstances: [CoreInstalledMinecraftInstance]
}

struct VersionContentDetailResult {
    let versionID: String
    let versionInfo: MinecraftVersionInfo
}

@MainActor
enum VersionContentRefreshService {
    static func loadMinecraftVersions(
        coreBackend: VersionContentCoreBackend,
        instances: [GameInstance],
        settings: LauncherSettings
    ) async throws -> VersionContentManifestResult {
        let remoteVersions = try await coreBackend.minecraftVersions()
        let gameDirectories = VersionContentInfoFactory.candidateGameDirectories(instances: instances, settings: settings)
        let versionIDs = remoteVersions.map(\.id)
        let gameDirectoryPaths = gameDirectories.map(\.path)

        let statuses = await installStatuses(
            coreBackend: coreBackend,
            versionIDs: versionIDs,
            gameDirectoryPaths: gameDirectoryPaths
        )
        let installedInstances = await installedInstances(
            coreBackend: coreBackend,
            versionIDs: versionIDs,
            gameDirectoryPaths: gameDirectoryPaths,
            fallbackStatuses: statuses
        )
        let statusByVersion = Dictionary(uniqueKeysWithValues: statuses.map { ($0.versionId, $0) })
        let versions = remoteVersions.map {
            VersionContentInfoFactory.versionInfo(
                remoteVersion: $0,
                instances: instances,
                settings: settings,
                package: nil,
                installStatus: statusByVersion[$0.id]
            )
        }
        return VersionContentManifestResult(
            versions: versions,
            latestReleaseID: remoteVersions.first(where: { $0.type == "release" })?.id,
            latestSnapshotID: remoteVersions.first(where: { $0.type == "snapshot" })?.id,
            installedInstances: installedInstances
        )
    }

    static func loadDetails(
        coreBackend: VersionContentCoreBackend,
        version: MinecraftVersionInfo,
        manifestURL: URL,
        instances: [GameInstance],
        settings: LauncherSettings
    ) async throws -> VersionContentDetailResult {
        let remoteVersion = MinecraftRemoteVersion(
            id: version.id,
            type: version.kind.manifestType,
            url: manifestURL,
            releasedAt: VersionContentInfoFactory.parseDate(version.releasedAt)
        )
        let gameDirectories = VersionContentInfoFactory.candidateGameDirectories(instances: instances, settings: settings)
        let installStatus = try await coreBackend.minecraftInstallStatus(
            [version.id],
            gameDirectories.map(\.path)
        ).first
        let package = try await coreBackend.minecraftPackage(remoteVersion)
        let versionInfo = VersionContentInfoFactory.versionInfo(
            remoteVersion: remoteVersion,
            instances: instances,
            settings: settings,
            package: package,
            installStatus: installStatus
        )
        return VersionContentDetailResult(versionID: version.id, versionInfo: versionInfo)
    }

    static func loadAssets(
        coreBackend: VersionContentCoreBackend,
        gameDirectory: String,
        kind: ManagedAssetKind,
        loader: LoaderKind,
        sort: ManagedAssetSort,
        links: [String: AssetManualLink]
    ) async throws -> [ManagedAsset] {
        try await coreBackend.localResources(gameDirectory, kind, loader)
            .map { ManagedAsset.fromCoreAsset($0, links: links) }
            .sorted { ManagedAsset.sort($0, $1, by: sort) }
    }

    private static func installStatuses(
        coreBackend: VersionContentCoreBackend,
        versionIDs: [String],
        gameDirectoryPaths: [String]
    ) async -> [CoreMinecraftInstallStatus] {
        do {
            return try await coreBackend.minecraftInstallStatus(versionIDs, gameDirectoryPaths)
        } catch {
            return []
        }
    }

    private static func installedInstances(
        coreBackend: VersionContentCoreBackend,
        versionIDs: [String],
        gameDirectoryPaths: [String],
        fallbackStatuses: [CoreMinecraftInstallStatus]
    ) async -> [CoreInstalledMinecraftInstance] {
        do {
            return try await coreBackend.installedMinecraftInstances(versionIDs, gameDirectoryPaths)
        } catch {
            return VersionContentInfoFactory.installedInstances(from: fallbackStatuses)
        }
    }
}
