import Foundation
import SwiftUI

@main
struct PaninoLauncherApp: App {
    @NSApplicationDelegateAdaptor(PaninoAppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var viewModel = LauncherViewModel()
    @StateObject private var theme = ThemeSettings()
    @StateObject private var launcherSettings = LauncherSettings()
    @StateObject private var instanceStore = InstanceStore()
    @StateObject private var versionContentStore = VersionContentStore()
    @StateObject private var accountStore = AccountStore()
    @StateObject private var taskCenterStore = TaskCenterStore()
    @StateObject private var diagnosticsStore = DiagnosticsStore()
    @StateObject private var performanceCoachStore = PerformanceCoachStore()
    @StateObject private var packDoctorStore = PackDoctorStore()
    @StateObject private var appActions = AppActionCenter()
    @StateObject private var onlineContentStore = OnlineContentStore()

    init() {
        if CommandLine.arguments.contains("--self-test-core-env") {
            CoreEnvironmentSelfTest.runAndExit()
        }
        if CommandLine.arguments.contains("--self-test-graphics-ui") {
            GraphicsTuningSelfTest.runAndExit()
        }
        URLCache.shared.memoryCapacity = 64 * 1024 * 1024
        URLCache.shared.diskCapacity = 256 * 1024 * 1024
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .environmentObject(theme)
                .environmentObject(launcherSettings)
                .environmentObject(instanceStore)
                .environmentObject(versionContentStore)
                .environmentObject(accountStore)
                .environmentObject(taskCenterStore)
                .environmentObject(diagnosticsStore)
                .environmentObject(performanceCoachStore)
                .environmentObject(packDoctorStore)
                .environmentObject(appActions)
                .environmentObject(onlineContentStore)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Panino Launcher") {
                    NativeMacCommands.showAboutPanel()
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    openWindow(id: PaninoWindowID.settings)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates") {
                    appActions.dispatch(.checkForUpdates)
                }
            }

            CommandMenu("Game Instance") {
                Button("Launch Current Instance") {
                    appActions.dispatch(.launchDefault)
                }
                .keyboardShortcut(.return, modifiers: [.command])

                Button("Manage Installed Instances") {
                    appActions.dispatch(.openInstances)
                }

                Divider()

                Button("Open Configuration Folder") {
                    appActions.dispatch(.openInstanceDirectory)
                }
                .disabled(instanceStore.selectedInstance == nil)
            }

            CommandMenu("Navigate") {
                Button("Launch") {
                    appActions.dispatch(.openLaunch)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Get Content") {
                    appActions.dispatch(.openDiscover)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button("Activity") {
                    appActions.dispatch(.openActivity)
                }
                .keyboardShortcut("3", modifiers: [.command])
            }

            CommandMenu("Advanced") {
                Button("Start Core") {
                    appActions.dispatch(.startCore)
                }

                Button("Stop Core") {
                    appActions.dispatch(.stopCore)
                }

                Divider()

                Button("Check Java") {
                    appActions.dispatch(.checkJava)
                }

                Button("Scan Java Runtimes") {
                    appActions.dispatch(.scanJava)
                }

                Divider()

                Button("Export Diagnostics") {
                    appActions.dispatch(.exportDiagnostics)
                }

                Button("Open Logs Folder") {
                    appActions.dispatch(.openLogsDirectory)
                }
            }

            CommandMenu("Help") {
                Button("Open Documentation") {
                    NativeMacCommands.openExternalURL("https://minecraft.wiki/")
                }

                Button("Copy Diagnostic Summary") {
                    appActions.dispatch(.copyDiagnosticSummary)
                }
            }

            CommandGroup(replacing: .appTermination) {
                Button("Quit Panino Launcher") {
                    SettingsDebouncer.flush()
                    NativeMacCommands.quit()
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }

        Window("Settings", id: PaninoWindowID.settings) {
            SettingsWindow(viewModel: viewModel)
                .environmentObject(theme)
                .environmentObject(launcherSettings)
                .environmentObject(instanceStore)
                .environmentObject(versionContentStore)
                .environmentObject(accountStore)
                .environmentObject(taskCenterStore)
                .environmentObject(diagnosticsStore)
                .environmentObject(performanceCoachStore)
                .environmentObject(packDoctorStore)
                .environmentObject(appActions)
                .environmentObject(onlineContentStore)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 920, height: 620)
    }
}
