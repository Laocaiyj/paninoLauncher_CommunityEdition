import AppKit
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

enum NativeAppCommand: String {
    case launchDefault
    case openLaunch
    case openRecent
    case openInstances
    case openDiscover
    case openActivity
    case openSettings
    case openAccountSettings
    case openLogs
    case retryTask
    case checkForUpdates
    case startCore
    case stopCore
    case checkJava
    case scanJava
    case signIn
    case signOut
    case openInstanceDirectory
    case openDownloadCache
    case clearDownloadCache
    case openLogsDirectory
    case exportDiagnostics
    case copyDiagnosticSummary
    case duplicateInstance
    case createInstance
    case deleteInstance
}

extension Notification.Name {
    static let paninoNativeCommand = Notification.Name("PaninoLauncher.NativeCommand")
}

@MainActor
final class AppActionCenter: ObservableObject {
    @Published private(set) var commandSequence = 0
    @Published private(set) var lastCommand: NativeAppCommand?
    @Published private(set) var settingsSectionSequence = 0
    @Published private(set) var requestedSettingsSection: PaninoSettingsSection = .account
    @Published private(set) var instanceContentSequence = 0
    @Published private(set) var requestedInstanceContentKind: ManagedAssetKind?
    @Published var statusMessage = ""

    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .paninoNativeCommand,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let command = notification.object as? NativeAppCommand else { return }
            Task { @MainActor in
                self?.dispatch(command)
            }
        }
    }

    func dispatch(_ command: NativeAppCommand) {
        lastCommand = command
        commandSequence += 1
    }

    func focusSettings(_ section: PaninoSettingsSection) {
        requestedSettingsSection = section
        settingsSectionSequence += 1
    }

    func focusInstanceContent(_ kind: ManagedAssetKind) {
        requestedInstanceContentKind = kind
        instanceContentSequence += 1
    }
}

@MainActor
final class PaninoAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        UserNotificationService.shared.requestAuthorization()
    }

    func applicationWillTerminate(_ notification: Notification) {
        SettingsDebouncer.flush()
        CoreProcessManager.emergencyStopRecordedCore()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        LauncherSettings.storedCloseWindowBehavior() == .quit
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeKey {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(dockItem("Launch Default Configuration", action: #selector(launchDefaultInstance)))
        menu.addItem(dockItem("Open Recent Configuration", action: #selector(openRecentInstance)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(dockItem("Open Settings", action: #selector(openSettings)))
        return menu
    }

    @objc private func launchDefaultInstance() {
        post(.launchDefault)
    }

    @objc private func openRecentInstance() {
        post(.openRecent)
    }

    @objc private func openSettings() {
        post(.openSettings)
    }

    private func dockItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func post(_ command: NativeAppCommand) {
        NotificationCenter.default.post(name: .paninoNativeCommand, object: command)
    }
}

@MainActor
enum NativeMacCommands {
    static func showAboutPanel() {
        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [
                .applicationName: "Panino Launcher",
                .version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Development",
                .credits: NSAttributedString(string: "A native macOS Minecraft launcher.")
            ]
        )
    }

    static func quit() {
        NSApplication.shared.terminate(nil)
    }

    static func openExternalURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class UserNotificationService {
    static let shared = UserNotificationService()

    private var requestedAuthorization = false
    private var deliveredIdentifiers = Set<String>()

    private init() {}

    func requestAuthorization() {
        guard !requestedAuthorization, let center else { return }
        requestedAuthorization = true
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    func notifyOnce(identifier: String, title: String, body: String) {
        guard let center else { return }
        guard deliveredIdentifiers.insert(identifier).inserted else { return }
        requestAuthorization()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        Task {
            try? await center.add(request)
        }
    }

    private var center: UNUserNotificationCenter? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return UNUserNotificationCenter.current()
    }
}

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

    static func openDownloadCache() {
        do {
            let url = try LauncherPaths.appSupportDirectory()
                .appendingPathComponent("DownloadCache", isDirectory: true)
            openDirectory(url)
        } catch {
            NSSound.beep()
        }
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

enum DroppedContentImporter {
    @MainActor
    static func importItems(
        _ providers: [NSItemProvider],
        selectedKind: ManagedAssetKind,
        instance: GameInstance?,
        taskStore: TaskCenterStore,
        versionStore: VersionContentStore
    ) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }

        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard error == nil, let sourceURL = fileURL(from: item) else { return }
                Task { @MainActor in
                    importFile(
                        sourceURL,
                        selectedKind: selectedKind,
                        instance: instance,
                        taskStore: taskStore,
                        versionStore: versionStore
                    )
                }
            }
        }

        return true
    }

    @MainActor
    private static func importFile(
        _ sourceURL: URL,
        selectedKind: ManagedAssetKind,
        instance: GameInstance?,
        taskStore: TaskCenterStore,
        versionStore: VersionContentStore
    ) {
        let kind = importKind(for: sourceURL, selectedKind: selectedKind)
        guard instance?.gameDirectory.isEmpty == false else {
            taskStore.enqueueLocal(kind: "import", name: "Import Failed", message: "Select a game configuration before importing content.")
            return
        }

        taskStore.enqueueLocal(kind: "import", name: "Import \(sourceURL.lastPathComponent)", message: "Queued \(kind.title) import.")

        Task {
            do {
                let response = try await versionStore.importLocalFile(sourceURL, kind: kind, instance: instance)
                await MainActor.run {
                    taskStore.enqueueLocal(kind: "import", name: "Imported \(sourceURL.lastPathComponent)", message: response.path ?? response.message)
                }
            } catch {
                await MainActor.run {
                    taskStore.enqueueLocal(kind: "import", name: "Import Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        return nil
    }

    private static func importKind(for url: URL, selectedKind: ManagedAssetKind) -> ManagedAssetKind {
        if url.pathExtension.localizedCaseInsensitiveCompare("jar") == .orderedSame {
            return .mods
        }
        return selectedKind
    }
}

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 128
    }

    func image(path: String, size: CGSize = CGSize(width: 96, height: 96)) async -> NSImage? {
        let key = "\(path)#\(Int(size.width))x\(Int(size.height))" as NSString
        if let image = cache.object(forKey: key) {
            return image
        }

        let scale = max(NSScreen.main?.backingScaleFactor ?? 2, 1)
        let image = await Task.detached(priority: .utility) {
            Self.downsampledImage(path: path, size: size, scale: scale)
        }.value

        if let image {
            cache.setObject(image, forKey: key, cost: Self.cacheCost(for: size))
        }
        return image
    }

    nonisolated private static func downsampledImage(path: String, size: CGSize, scale: CGFloat) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else {
            return nil
        }

        let maxPixelSize = max(1, Int(max(size.width, size.height) * scale))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: size)
    }

    nonisolated private static func cacheCost(for size: CGSize) -> Int {
        max(1, Int(size.width * size.height * 4))
    }
}

@MainActor
enum SettingsDebouncer {
    private static var tasks: [String: Task<Void, Never>] = [:]
    private static var values: [String: String] = [:]

    static func set(_ value: String, forKey key: String, delayNanoseconds: UInt64 = 350_000_000) {
        values[key] = value
        tasks[key]?.cancel()
        tasks[key] = Task {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled, let value = values[key] else { return }
            SettingsStore.set(value, forKey: key)
            values.removeValue(forKey: key)
            tasks.removeValue(forKey: key)
        }
    }

    static func flush() {
        for (key, value) in values {
            SettingsStore.set(value, forKey: key)
        }
        values.removeAll()
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
