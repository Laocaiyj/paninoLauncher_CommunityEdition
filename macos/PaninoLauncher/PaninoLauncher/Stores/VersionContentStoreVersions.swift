import Foundation

@MainActor
extension VersionContentStore {
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
}
