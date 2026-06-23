import SwiftUI

struct InstanceGlobalManagementPage: View {
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var theme: ThemeSettings

    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InstanceBasicsPanel(
                instance: $instance,
                openFolder: openInstanceFolder,
                delete: onDelete
            )
            InstanceJavaRuntimeScanPanel(
                viewModel: viewModel,
                autoDetectJava: $launcherSettings.autoDetectJava,
                scanJava: viewModel.scanJavaRuntimes,
                selectRuntime: selectRuntime
            )
            InstanceGlobalDefaultsPanel(
                viewModel: viewModel,
                memoryPolicy: $launcherSettings.memoryPolicy,
                jvmProfile: $launcherSettings.jvmProfile,
                customMemoryMb: globalCustomMemoryMbBinding,
                customJvmArguments: launcherSettings.jvmArguments,
                restoreAutomaticTuning: restoreGlobalAutomaticTuning
            )
        }
        .task {
            loadManagedJavaRuntimesIfNeeded()
        }
    }

    private var globalCustomMemoryMbBinding: Binding<Int?> {
        Binding(
            get: { launcherSettings.memoryPolicy == .custom ? viewModel.memoryMb : nil },
            set: { newValue in
                if let newValue {
                    launcherSettings.memoryPolicy = .custom
                    viewModel.memoryMb = newValue
                } else {
                    launcherSettings.memoryPolicy = .auto
                }
            }
        )
    }

    private func openInstanceFolder() {
        FinderIntegration.openInstanceDirectory(instance)
    }

    private func selectRuntime(_ runtime: JavaRuntimeCandidate) {
        viewModel.javaPath = runtime.path
        viewModel.checkJavaRuntime()
    }

    private func loadManagedJavaRuntimesIfNeeded() {
        if viewModel.managedJavaRuntimes.isEmpty {
            viewModel.loadManagedJavaRuntimes()
        }
    }

    private func restoreGlobalAutomaticTuning() {
        launcherSettings.memoryPolicy = .auto
        launcherSettings.jvmProfile = .auto
        launcherSettings.jvmArguments = ""
    }
}
