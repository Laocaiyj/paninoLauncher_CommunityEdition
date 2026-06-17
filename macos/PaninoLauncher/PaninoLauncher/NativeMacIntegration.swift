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
    case openResources
    case openVersions
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
    private static var aboutWindowController: NSWindowController?

    static func showAboutPanel() {
        if let window = aboutWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let view = PaninoAboutView(
            icon: PaninoAboutResources.appIcon,
            versionText: PaninoAboutResources.alphaVersionText
        )
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 390),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "About Panino Launcher"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.center()

        let controller = NSWindowController(window: window)
        aboutWindowController = controller
        controller.showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
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

private struct PaninoAboutView: View {
    let icon: NSImage?
    let versionText: String

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 18)

            PaninoAboutAppIcon(icon: icon)

            VStack(spacing: 7) {
                Text("Panino Launcher")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(versionText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("A native macOS Minecraft launcher.")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, 8)
            }

            AboutBuiltWithLine()
            .padding(.top, 2)

            Spacer(minLength: 18)
        }
        .frame(width: 560, height: 390)
        .padding(.horizontal, 36)
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.31, blue: 0.36).opacity(0.18),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 40,
                    endRadius: 310
                )
            }
            .ignoresSafeArea()
        }
    }
}

private struct AboutBuiltWithLine: View {
    var body: some View {
        HStack(spacing: 7) {
            Text("Built with")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            AboutInlineTechnologyMark(mark: .swift)

            Text("SwiftUI")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("+")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)

            AboutInlineTechnologyMark(mark: .haskell)

            Text("Haskell")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Built with SwiftUI and Haskell")
    }
}

private struct AboutInlineTechnologyMark: View {
    let mark: AboutTechnologyMark

    var body: some View {
        AboutTechnologyMarkView(mark: mark)
            .padding(mark.inlinePadding)
            .frame(width: mark.inlineSize.width, height: mark.inlineSize.height)
            .background {
                RoundedRectangle(cornerRadius: mark.inlineCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: mark.backgroundColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: mark.inlineCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

private struct PaninoAboutAppIcon: View {
    let icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 14, x: 0, y: 8)
        .accessibilityLabel("Panino Launcher")
    }
}

private enum AboutTechnologyMark {
    case swift
    case haskell

    var backgroundColors: [Color] {
        switch self {
        case .swift:
            return [
                Color(red: 0.95, green: 0.31, blue: 0.23),
                Color(red: 0.98, green: 0.62, blue: 0.18)
            ]
        case .haskell:
            return [
                Color(red: 0.97, green: 0.96, blue: 0.99),
                Color(red: 0.90, green: 0.88, blue: 0.95)
            ]
        }
    }

    var inlineSize: CGSize {
        switch self {
        case .swift: return CGSize(width: 25, height: 25)
        case .haskell: return CGSize(width: 34, height: 25)
        }
    }

    var inlineCornerRadius: CGFloat {
        switch self {
        case .swift: return 8
        case .haskell: return 7
        }
    }

    var inlinePadding: CGFloat {
        switch self {
        case .swift: return 4
        case .haskell: return 4
        }
    }
}

private struct AboutTechnologyMarkView: View {
    let mark: AboutTechnologyMark

    var body: some View {
        switch mark {
        case .swift:
            if PaninoAboutResources.hasSwiftSymbol {
                Image(systemName: "swift")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
            } else {
                Text("S")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        case .haskell:
            HaskellLogoMark()
        }
    }
}

private struct HaskellLogoMark: View {
    var body: some View {
        ZStack {
            HaskellLogoPolygon(points: [
                CGPoint(x: 0.0, y: 0.0),
                CGPoint(x: 33.7, y: 0.0),
                CGPoint(x: 78.6, y: 67.4),
                CGPoint(x: 33.7, y: 134.8),
                CGPoint(x: 0.0, y: 134.8),
                CGPoint(x: 44.9, y: 67.4)
            ])
            .fill(Color(red: 0.27, green: 0.23, blue: 0.38))

            HaskellLogoPolygon(points: [
                CGPoint(x: 44.9, y: 134.8),
                CGPoint(x: 89.8, y: 67.4),
                CGPoint(x: 44.9, y: 0.0),
                CGPoint(x: 78.6, y: 0.0),
                CGPoint(x: 168.4, y: 134.8),
                CGPoint(x: 134.7, y: 134.8),
                CGPoint(x: 106.1, y: 91.9),
                CGPoint(x: 77.6, y: 134.8)
            ])
            .fill(Color(red: 0.37, green: 0.31, blue: 0.53))

            HaskellLogoPolygon(points: [
                CGPoint(x: 116.1, y: 39.3),
                CGPoint(x: 218.0, y: 39.3),
                CGPoint(x: 218.0, y: 61.8),
                CGPoint(x: 131.1, y: 61.8)
            ])
            .fill(Color(red: 0.56, green: 0.31, blue: 0.55))

            HaskellLogoPolygon(points: [
                CGPoint(x: 138.6, y: 73.0),
                CGPoint(x: 210.0, y: 73.0),
                CGPoint(x: 210.0, y: 95.5),
                CGPoint(x: 153.6, y: 95.5)
            ])
            .fill(Color(red: 0.56, green: 0.31, blue: 0.55))
        }
        .aspectRatio(256.0 / 134.8, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct HaskellLogoPolygon: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        let viewBox = CGSize(width: 256.0, height: 134.8)
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let xOffset = rect.midX - (viewBox.width * scale / 2)
        let yOffset = rect.midY - (viewBox.height * scale / 2)

        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: xOffset + point.x * scale,
                y: yOffset + point.y * scale
            )
        }

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: map(first))
        for point in points.dropFirst() {
            path.addLine(to: map(point))
        }
        path.closeSubpath()
        return path
    }
}

@MainActor
private enum PaninoAboutResources {
    static let appIcon: NSImage? = loadAppIcon()

    static let hasSwiftSymbol: Bool = NSImage(
        systemSymbolName: "swift",
        accessibilityDescription: nil
    ) != nil

    static var alphaVersionText: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let marketingVersion = nonEmpty(info["CFBundleShortVersionString"] as? String) ?? "0.1"
        let buildNumber = nonEmpty(info["CFBundleVersion"] as? String)

        if let buildNumber {
            return "Alpha \(marketingVersion) · Development Build \(buildNumber)"
        }
        return "Alpha \(marketingVersion) · Development"
    }

    private static func loadAppIcon() -> NSImage? {
        if let image = NSImage(named: "PaninoAppIcon") {
            return image
        }
        if let image = NSImage(named: "AppIcon") {
            return image
        }

        for bundle in resourceBundles {
            if let url = bundle.url(
                forResource: "panino-app-icon",
                withExtension: "png",
                subdirectory: "Assets.xcassets/PaninoAppIcon.imageset"
            ),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return NSApplication.shared.applicationIconImage
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static var resourceBundles: [Bundle] {
        #if SWIFT_PACKAGE
        [Bundle.module, Bundle.main]
        #else
        [Bundle.main]
        #endif
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
