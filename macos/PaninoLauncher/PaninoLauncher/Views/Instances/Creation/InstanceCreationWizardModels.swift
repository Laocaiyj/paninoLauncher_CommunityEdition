import Foundation

enum InstanceCreationStep: String, CaseIterable, Identifiable {
    case source
    case version
    case review

    var id: String { rawValue }
}

struct InstanceCreationDraft: Equatable {
    var name = "New Game Configuration"
    var source = "Blank Configuration"
    var minecraftVersion = "1.20.1"
    var loader: LoaderKind?
    var loaderVersion: String?
    var modpackSource = "Online"
    var modpackPath = ""
    var gameDirectory = ""
    var javaPath = ""
    var memoryMb = 4096
    var group = "Default"

    init() {}

    @MainActor
    init(settings: LauncherSettings) {
        gameDirectory = Self.defaultConfigurationDirectory(name: name)
        javaPath = ""
        memoryMb = SettingsStore.memoryMb
    }

    static func defaultConfigurationDirectory(name: String) -> String {
        let slug = name
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9._-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-._"))
        let safeSlug = slug.isEmpty ? UUID().uuidString : slug
        let root = (try? LauncherPaths.gameConfigurationsDirectory())
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Panino Launcher/minecraft/versions", isDirectory: true)
        return root
            .appendingPathComponent(safeSlug, isDirectory: true)
            .path
    }
}

struct PendingModpackImportReview: Identifiable {
    let id = UUID()
    let plan: CoreTypedInstallPlan
    let sourcePath: String
    let targetGameDir: String
}
