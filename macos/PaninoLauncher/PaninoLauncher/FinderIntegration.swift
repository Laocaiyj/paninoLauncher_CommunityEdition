import AppKit
import Foundation

@MainActor
enum FinderIntegration {
    static func openInstanceDirectory(_ instance: GameInstance?) {
        openDirectory(directoryURL(for: instance))
    }

    static func openLogsDirectory() {
        let url = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Panino Launcher", isDirectory: true)
        openDirectory(url)
    }

    static func openManagedFolder(kind: ManagedAssetKind, instance: GameInstance?) {
        let baseURL = directoryURL(for: instance)
        openDirectory(baseURL.appendingPathComponent(kind.folderName, isDirectory: true))
    }

    static func openSavesDirectory(_ instance: GameInstance?) {
        let baseURL = directoryURL(for: instance)
        openDirectory(baseURL.appendingPathComponent("saves", isDirectory: true))
    }

    static func openDownloadCache() {
        do {
            let url = try LauncherPaths.appSupportDirectory()
                .appendingPathComponent("DownloadCache", isDirectory: true)
            openDirectory(url)
        } catch {
            NSSound.beep()
        }
    }

    private static func directoryURL(for instance: GameInstance?) -> URL {
        let path = instance?.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        if let root = try? LauncherPaths.gameConfigurationsDirectory() {
            return root
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    private static func openDirectory(_ url: URL) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            NSWorkspace.shared.open(url)
        } catch {
            NSSound.beep()
        }
    }
}
