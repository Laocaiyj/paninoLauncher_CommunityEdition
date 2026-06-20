import SwiftUI

struct SettingsJavaRuntimePanel: View {
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var launcherSettings: LauncherSettings

    @ObservedObject var viewModel: LauncherViewModel
    @Binding var showRuntimeAdvanced: Bool
    @Binding var showLocalJava: Bool
    @Binding var pendingManagedJavaDeletion: CoreJavaManagedRuntime?
    @Binding var pendingLocalJavaDeletion: JavaRuntimeCandidate?

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(title: PaninoSettingsSection.runtime.title(language: theme.language), systemImage: PaninoSettingsSection.runtime.systemImage)

                SettingsJavaManagementRow(viewModel: viewModel)
                SettingsManagedJavaRuntimesSection(
                    viewModel: viewModel,
                    pendingManagedJavaDeletion: $pendingManagedJavaDeletion
                )
                SettingsLocalJavaSection(
                    viewModel: viewModel,
                    isExpanded: $showLocalJava,
                    pendingLocalJavaDeletion: $pendingLocalJavaDeletion
                )
                SettingsAdvancedJavaSection(
                    viewModel: viewModel,
                    isExpanded: $showRuntimeAdvanced
                )
            }
        }
        .task {
            viewModel.loadManagedJavaRuntimes()
            viewModel.resolveJavaRuntime(version: viewModel.version)
            if launcherSettings.autoDetectJava, viewModel.discoveredJavaRuntimes.isEmpty {
                viewModel.scanJavaRuntimes()
            }
        }
    }
}
