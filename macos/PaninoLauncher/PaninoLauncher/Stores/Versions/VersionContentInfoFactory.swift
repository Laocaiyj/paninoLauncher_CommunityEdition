import Foundation

@MainActor
enum VersionContentInfoFactory {
    static let fallbackVersions: [MinecraftVersionInfo] = [
        MinecraftVersionInfo(id: "1.21.5", kind: .release, releasedAt: "2025-03-25", javaRequirement: "Java 21", downloadState: "Available", verificationState: "Needs download", manifestURL: nil, libraryCount: nil, assetIndexState: "-", clientJarState: "-", nativesState: "-", diskUsageBytes: nil, installRoot: nil, isInstalled: false, isArchived: false, archivePath: nil, isUsedByInstance: false),
        MinecraftVersionInfo(id: "1.20.1", kind: .release, releasedAt: "2023-06-12", javaRequirement: "Java 17", downloadState: "Available", verificationState: "Needs download", manifestURL: nil, libraryCount: nil, assetIndexState: "-", clientJarState: "-", nativesState: "-", diskUsageBytes: nil, installRoot: nil, isInstalled: false, isArchived: false, archivePath: nil, isUsedByInstance: false)
    ]

    static func versionInfo(
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

    static func actionStatusPrefix(_ action: CoreMinecraftVersionStorageAction) -> String {
        switch action {
        case .delete:
            return "Deleting"
        case .archive:
            return "Archiving"
        case .restore:
            return "Restoring"
        }
    }

    static func candidateGameDirectories(instances: [GameInstance], settings: LauncherSettings) -> [URL] {
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

    static func installedInstances(from statuses: [CoreMinecraftInstallStatus]) -> [CoreInstalledMinecraftInstance] {
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

    static func parseDate(_ text: String) -> Date? {
        DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none) == text ? Date() : nil
    }

    private static func verificationState(installStatus: CoreMinecraftInstallStatus?, archived: Bool) -> String {
        if archived { return "Archived" }
        guard let installStatus else { return "Needs download" }
        if installStatus.versionJson && installStatus.clientJar { return "Files complete" }
        if !installStatus.versionJson { return "Missing version.json" }
        if !installStatus.clientJar { return "Missing client.jar" }
        return "Needs repair"
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
}
