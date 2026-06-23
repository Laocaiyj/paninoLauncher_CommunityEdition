import Foundation

extension OnlineContentDiscoveryPage {
    func minecraftInstallGameDirectory(for version: MinecraftVersionInfo) -> String? {
        switch minecraftInstallTarget {
        case .newConfiguration:
            return manualGameConfigurationDirectory().map(\.path)
        case .existingConfiguration:
            return instanceStore.selectedInstance?.gameDirectory
        case .downloadOnly:
            return downloadOnlyDirectory(for: version).path
        }
    }

    func manualGameConfigurationDirectory() -> URL? {
        let trimmedName = minecraftInstanceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }
        let root = gameConfigurationsRoot()
        return root.appendingPathComponent(slug(trimmedName), isDirectory: true)
    }

    func downloadOnlyDirectory(for version: MinecraftVersionInfo) -> URL {
        let base = (try? LauncherPaths.appSupportDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Panino Launcher", isDirectory: true)
        return base
            .appendingPathComponent("DownloadCache", isDirectory: true)
            .appendingPathComponent("MinecraftVersionFiles", isDirectory: true)
            .appendingPathComponent(slug(version.id), isDirectory: true)
    }

    func gameConfigurationsRoot() -> URL {
        (try? LauncherPaths.gameConfigurationsDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Panino Launcher/minecraft/versions", isDirectory: true)
    }

    func slug(_ value: String) -> String {
        var result = ""
        for scalar in value.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-")).contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !result.hasSuffix("-") {
                result.append("-")
            }
        }
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        return trimmed.isEmpty ? "minecraft" : trimmed
    }

    func minecraftInstallDisplayName(for _: MinecraftVersionInfo) -> String {
        minecraftInstanceName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func automaticMinecraftInstallShaderLoader() -> String? {
        switch selectedShaderLoader {
        case .none, .optiFine:
            return nil
        case .iris, .oculus:
            return minecraftShaderLoaderForPreflight(loader: selectedMinecraftLoader?.rawValue, shaderLoader: selectedShaderLoader.rawValue)
        }
    }

    func automaticMinecraftInstallShaderVersion() -> String? {
        switch selectedShaderLoader {
        case .none, .optiFine:
            return nil
        case .iris, .oculus:
            return selectedShaderLoaderVersion
        }
    }
}
