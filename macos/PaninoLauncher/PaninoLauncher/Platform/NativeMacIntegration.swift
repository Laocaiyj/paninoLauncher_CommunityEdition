import AppKit
import Foundation
import SwiftUI

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

        let view = PaninoAboutView()
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
