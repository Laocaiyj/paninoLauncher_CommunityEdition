import Foundation

extension LaunchDashboard {
    enum VersionInstallState {
        case installed
        case available
        case unknown
    }

    var versionInstallState: VersionInstallState {
        if let version = versionStore.versions.first(where: { $0.id == selectedInstance.minecraftVersion }) {
            return version.isInstalled ? .installed : .available
        }
        switch selectedInstance.status {
        case .ready, .running:
            return .installed
        case .notInstalled:
            return .available
        case .installing:
            return .unknown
        case .failed:
            return .available
        }
    }

    var versionInfo: MinecraftVersionInfo? {
        versionStore.versions.first { $0.id == selectedInstance.minecraftVersion }
    }

    var requiredJavaMajor: Int? {
        guard let text = versionInfo?.javaRequirement else { return nil }
        return javaMajorVersion(from: text)
    }

    func javaResolution(for instance: GameInstance) -> CoreJavaRuntimeResolveResponse? {
        guard let resolution = viewModel.javaRuntimeResolution,
              resolution.minecraftVersion == instance.minecraftVersion else {
            return nil
        }
        return resolution
    }

    var isGameDirectoryWritable: Bool {
        let path = selectedInstance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return false }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            return fileManager.isWritableFile(atPath: path)
        }

        let parent = URL(fileURLWithPath: path).deletingLastPathComponent().path
        return fileManager.isWritableFile(atPath: parent)
    }
}
