import Foundation

@MainActor
extension VersionContentCoreBackend {
    static func live(viewModel: LauncherViewModel) -> VersionContentCoreBackend {
        VersionContentCoreBackend(
            minecraftVersions: {
                try await viewModel.minecraftVersions()
            },
            minecraftInstallStatus: { versionIds, gameDirs in
                try await viewModel.minecraftInstallStatus(versionIds: versionIds, gameDirs: gameDirs)
            },
            installedMinecraftInstances: { versionIds, gameDirs in
                try await viewModel.installedMinecraftInstances(versionIds: versionIds, gameDirs: gameDirs)
            },
            minecraftPackage: { version in
                try await viewModel.minecraftPackage(for: version)
            },
            localResources: { gameDir, kind, loader in
                try await viewModel.localResources(gameDir: gameDir, kind: kind, loader: loader)
            },
            toggleLocalResource: { path in
                try await viewModel.toggleLocalResource(path: path)
            },
            deleteLocalResource: { path in
                try await viewModel.deleteLocalResource(path: path)
            },
            importLocalResource: { sourcePath, gameDir, kind in
                try await viewModel.importLocalResource(sourcePath: sourcePath, gameDir: gameDir, kind: kind)
            },
            cleanMinecraftVersion: { version, gameDir in
                try await viewModel.cleanMinecraftVersion(version: version, gameDir: gameDir)
            },
            mutateMinecraftVersionStorage: { version, gameDir, action in
                try await viewModel.mutateMinecraftVersionStorage(version: version, gameDir: gameDir, action: action)
            }
        )
    }
}
