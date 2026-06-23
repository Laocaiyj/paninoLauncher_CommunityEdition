import Foundation

extension OnlineContentDiscoveryPage {
    func coreInstallRequest(
        project: OnlineProject,
        release: OnlineRelease,
        managedKind: ManagedAssetKind,
        gameDirectory: String
    ) -> CoreContentInstallRequest? {
        guard let sourceFile = release.files.first(where: \.isPrimary) ?? release.files.first,
              let sourceURL = sourceFile.downloadURL,
              !gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let hashes = Dictionary(uniqueKeysWithValues: sourceFile.hashes.map { ($0.key.lowercased(), $0.value) })
        let file = CoreContentInstallFile(
            fileName: safeFileName(sourceFile.fileName),
            url: sourceURL,
            sha1: hashes["sha1"],
            size: sourceFile.sizeBytes,
            primary: sourceFile.isPrimary
        )
        let dependencies = release.dependencies.map { dependency in
            CoreContentInstallDependency(
                projectId: dependency.projectID,
                versionId: dependency.versionID,
                source: dependency.source.rawValue,
                name: dependency.projectID ?? dependency.versionID ?? dependency.id,
                required: dependency.relation == .required,
                installed: nil,
                sha1: nil
            )
        }

        return CoreContentInstallRequest(
            source: project.source.rawValue,
            projectId: project.id,
            projectTitle: project.title,
            projectType: project.projectType.rawValue,
            releaseId: release.id,
            gameDir: gameDirectory,
            targetSubdir: managedKind.folderName,
            files: [file],
            dependencies: dependencies,
            gameVersions: release.gameVersions,
            loaders: release.loaders.map(\.rawValue),
            instances: instanceStore.instances
                .filter { !$0.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { instance in
                    CoreContentTargetInstance(
                        instanceId: instance.id.uuidString,
                        name: instance.name,
                        gameDir: instance.gameDirectory,
                        minecraftVersion: instance.contentMinecraftVersion,
                        loader: instance.loader?.rawValue
                    )
                },
            concurrency: launcherSettings.downloadConcurrency,
            retryCount: launcherSettings.downloadRetryCount,
            download: CoreDownloadRuntimeOptions(
                concurrency: launcherSettings.downloadConcurrency,
                retryCount: launcherSettings.downloadRetryCount
            )
        )
    }

    func sameFilePath(_ lhs: String, _ rhs: String) -> Bool {
        URL(fileURLWithPath: lhs).standardizedFileURL.path == URL(fileURLWithPath: rhs).standardizedFileURL.path
    }
}
