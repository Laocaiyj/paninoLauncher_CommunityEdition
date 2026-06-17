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
        .windowStyle(.hiddenTitleBar)
        .commands {
            PaninoLauncherCommands(
                language: theme.language,
                hasSelectedInstance: instanceStore.selectedInstance != nil,
                dispatch: appActions.dispatch,
                openSettings: openSettingsWindow
            )
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

    private func openSettingsWindow(_ section: PaninoSettingsSection?) {
        if let section {
            appActions.focusSettings(section)
        }
        openWindow(id: PaninoWindowID.settings)
    }
}
