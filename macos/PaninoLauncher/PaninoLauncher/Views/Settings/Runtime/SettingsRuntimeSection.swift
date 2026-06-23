import SwiftUI

struct SettingsRuntimeSection: View {
    @EnvironmentObject var theme: ThemeSettings

    @ObservedObject var viewModel: LauncherViewModel
    @Binding var showRuntimeAdvanced: Bool
    @Binding var showLocalJava: Bool
    @Binding var pendingManagedJavaDeletion: CoreJavaManagedRuntime?
    @Binding var pendingLocalJavaDeletion: JavaRuntimeCandidate?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            SettingsJavaRuntimePanel(
                viewModel: viewModel,
                showRuntimeAdvanced: $showRuntimeAdvanced,
                showLocalJava: $showLocalJava,
                pendingManagedJavaDeletion: $pendingManagedJavaDeletion,
                pendingLocalJavaDeletion: $pendingLocalJavaDeletion
            )
            SettingsMinecraftRuntimePanel(
                viewModel: viewModel,
                showRuntimeAdvanced: $showRuntimeAdvanced
            )
        }
    }
}
