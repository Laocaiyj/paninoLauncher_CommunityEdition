import SwiftUI

func discoverVisibleDownloadState(_ version: MinecraftVersionInfo, language: AppLanguage) -> String? {
    version.downloadState == "Available" ? nil : version.downloadState.localizedVersionState(language)
}

func minecraftInstallChoiceKey(loader: String?, shaderLoader: String?) -> String {
    "\(normalizedMinecraftInstallChoice(loader ?? "vanilla"))|\(normalizedMinecraftInstallChoice(shaderLoader ?? "none"))"
}

func normalizedMinecraftInstallChoice(_ value: String) -> String {
    value.lowercased()
        .replacingOccurrences(of: "-", with: "")
        .replacingOccurrences(of: "_", with: "")
}

func minecraftShaderLoaderCompatible(loader: String?, shaderLoader: String?) -> Bool {
    guard let shaderLoader else {
        return true
    }
    let normalizedShader = normalizedMinecraftInstallChoice(shaderLoader)
    let normalizedLoader = normalizedMinecraftInstallChoice(loader ?? "vanilla")
    switch normalizedShader {
    case "iris":
        return normalizedLoader == "fabric" || normalizedLoader == "quilt"
    case "oculus":
        return normalizedLoader == "forge" || normalizedLoader == "neoforge"
    case "optifine":
        return true
    default:
        return true
    }
}

func minecraftShaderLoaderForPreflight(loader: String?, shaderLoader: String?) -> String? {
    guard minecraftShaderLoaderCompatible(loader: loader, shaderLoader: shaderLoader) else {
        return nil
    }
    return shaderLoader
}

func minecraftInstallTargetDirectoryConflictExists(_ url: URL) -> Bool {
    var isDirectory = ObjCBool(false)
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
        return false
    }
    guard isDirectory.boolValue else { return true }
    return !minecraftInstallDirectoryCanBeReused(url)
}

func minecraftInstallDirectoryCanBeReused(_ url: URL) -> Bool {
    guard let entries = try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return false
    }
    guard !entries.isEmpty else { return true }
    guard entries.count == 1, entries[0].lastPathComponent == "downloads" else {
        return false
    }
    return minecraftInstallDownloadsDirectoryCanBeReused(entries[0])
}

func minecraftInstallDownloadsDirectoryCanBeReused(_ url: URL) -> Bool {
    guard let entries = try? FileManager.default.contentsOfDirectory(
        at: url,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else {
        return false
    }
    let reusableFiles: Set<String> = [
        "install-preflight.json",
        "install-rollback.json",
        "install-state.json",
        "loader-install.log",
        "shader-install.log"
    ]
    let reusableDirectories: Set<String> = [
        "rollback-backups"
    ]
    return entries.allSatisfy { entry in
        let name = entry.lastPathComponent
        if reusableFiles.contains(name) {
            return true
        }
        let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        return isDirectory && reusableDirectories.contains(name)
    }
}

enum MinecraftBrowseGroup: String, CaseIterable, Identifiable {
    case recommended
    case release
    case snapshot
    case historical

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .recommended:
            return localizedString(language, english: "Recommended", chinese: "推荐", italian: "Consigliate", french: "Recommandées", spanish: "Recomendadas")
        case .release:
            return localizedString(language, english: "Release", chinese: "正式版", italian: "Release", french: "Release", spanish: "Release")
        case .snapshot:
            return localizedString(language, english: "Snapshot", chinese: "快照版", italian: "Snapshot", french: "Snapshot", spanish: "Snapshot")
        case .historical:
            return localizedString(language, english: "Historical", chinese: "历史版本", italian: "Storiche", french: "Historiques", spanish: "Históricas")
        }
    }
}

enum MinecraftInstallTarget: String, CaseIterable, Identifiable {
    case newConfiguration
    case existingConfiguration
    case downloadOnly

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .newConfiguration:
            return localizedString(language, english: "Create Local Instance After Install", chinese: "安装后生成本地实例", italian: "Crea istanza dopo installazione", french: "Créer l'instance après installation", spanish: "Crear instancia tras instalar")
        case .existingConfiguration:
            return localizedString(language, english: "Selected Configuration", chinese: "当前游戏配置", italian: "Configurazione selezionata", french: "Configuration sélectionnée", spanish: "Configuración seleccionada")
        case .downloadOnly:
            return localizedString(language, english: "Download Version Files Only", chinese: "仅下载版本文件", italian: "Solo file versione", french: "Télécharger fichiers seulement", spanish: "Solo descargar archivos")
        }
    }
}

enum ShaderLoaderChoice: String, CaseIterable, Identifiable {
    case none
    case iris
    case optiFine
    case oculus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .iris:
            return "Iris"
        case .optiFine:
            return "OptiFine"
        case .oculus:
            return "Oculus"
        }
    }
}

enum InstallChoicePreflightState: Equatable {
    case normal
    case warning
    case blocked

    var systemImage: String? {
        switch self {
        case .normal:
            return nil
        case .warning:
            return "exclamationmark.triangle"
        case .blocked:
            return "xmark.octagon"
        }
    }

    var tint: Color {
        switch self {
        case .normal:
            return .secondary
        case .warning:
            return .orange
        case .blocked:
            return .red
        }
    }
}
