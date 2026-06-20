import Foundation

enum InstanceLocalCatalog {
    static func effectiveGameDirectory(for instance: GameInstance) -> String {
        instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isIsolatedGameDirectory(_ path: String) -> Bool {
        guard let root = try? LauncherPaths.gameConfigurationsDirectory()
            .standardizedFileURL
        else {
            return false
        }
        let standardized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
        let rootPath = root.path
        return standardized == rootPath || standardized.hasPrefix(rootPath + "/")
    }

    static func isolatedGameDirectory(forVersion version: String) -> String? {
        guard let root = try? LauncherPaths.gameConfigurationsDirectory()
            .standardizedFileURL
        else {
            return nil
        }
        return root
            .appendingPathComponent(SafeFileComponent.sanitize(version), isDirectory: true)
            .path
    }

    static func isConcreteLocalInstance(_ instance: GameInstance) -> Bool {
        let gameDirectory = effectiveGameDirectory(for: instance)
        guard !gameDirectory.isEmpty,
              isIsolatedGameDirectory(gameDirectory)
        else {
            return false
        }
        return FileManager.default.fileExists(atPath: gameDirectory)
    }

    static func key(version: String, gameDirectory: String) -> String {
        let standardized = URL(fileURLWithPath: gameDirectory, isDirectory: true).standardizedFileURL.path
        return "\(version)|\(standardized)"
    }

    static func normalizeDuplicateNames(_ source: [GameInstance]) -> [GameInstance] {
        var counts: [String: Int] = [:]
        return source.map { instance in
            var next = instance
            let count = counts[instance.name, default: 0] + 1
            counts[instance.name] = count
            if count > 1 {
                next.name = "\(instance.name) \(count)"
            }
            return next
        }
    }

    static func sort(_ lhs: GameInstance, _ rhs: GameInstance) -> Bool {
        if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite && !rhs.isFavorite }
        if lhs.lastLaunchedAt != rhs.lastLaunchedAt {
            return (lhs.lastLaunchedAt ?? .distantPast) > (rhs.lastLaunchedAt ?? .distantPast)
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    @MainActor
    static func gameInstance(
        from installed: CoreInstalledMinecraftInstance,
        settings: LauncherSettings,
        existingNames: Set<String>
    ) -> GameInstance {
        let baseName = displayName(from: installed)
        return GameInstance(
            id: UUID(),
            name: uniqueName(baseName, existingNames: existingNames),
            iconName: "shippingbox.fill",
            coverPath: "",
            minecraftVersion: installed.versionId,
            gameDirectory: installed.gameDir,
            javaPath: "",
            memoryMb: SettingsStore.memoryMb,
            memoryPolicy: settings.memoryPolicy,
            jvmProfile: settings.jvmProfile,
            graphicsProfile: settings.graphicsProfile,
            graphicsManualOverrides: [:],
            loader: installed.loader.flatMap(LoaderKind.init(rawValue:)),
            loaderVersion: installed.loaderVersion,
            jvmArguments: settings.jvmArguments,
            customJvmArguments: settings.jvmArguments,
            preLaunchBehavior: settings.installMissingFilesBeforeLaunch ? "Install missing files" : "Launch directly",
            group: "Local",
            isFavorite: false,
            lastLaunchedAt: nil,
            totalPlaySeconds: nil,
            status: installed.versionJson && installed.clientJar ? .ready : .notInstalled,
            baseMinecraftVersion: installed.minecraftVersion
        )
    }

    private static func displayName(from installed: CoreInstalledMinecraftInstance) -> String {
        if let name = installed.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }
        let directoryName = URL(fileURLWithPath: installed.gameDir, isDirectory: true).lastPathComponent
        guard !directoryName.isEmpty, directoryName != installed.versionId else {
            return "Minecraft \(installed.versionId)"
        }

        let words = directoryName
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .map(String.init)
        guard !words.isEmpty else {
            return "Minecraft \(installed.versionId)"
        }
        return words
            .map { word in
                word.contains(".") || word.allSatisfy(\.isNumber)
                    ? word
                    : word.capitalized
            }
            .joined(separator: " ")
    }

    private static func uniqueName(_ baseName: String, existingNames: Set<String>) -> String {
        guard existingNames.contains(baseName) else { return baseName }
        var index = 2
        while existingNames.contains("\(baseName) \(index)") {
            index += 1
        }
        return "\(baseName) \(index)"
    }
}
