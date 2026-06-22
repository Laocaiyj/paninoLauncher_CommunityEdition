import SwiftUI

struct InstanceGlobalDefaultsPanel: View {
    @EnvironmentObject private var theme: ThemeSettings

    @ObservedObject var viewModel: LauncherViewModel
    @Binding var memoryPolicy: InstanceMemoryPolicy
    @Binding var jvmProfile: InstanceJvmProfile
    let customMemoryMb: Binding<Int?>
    let customJvmArguments: String
    let restoreAutomaticTuning: () -> Void

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Global Defaults", chinese: "全局默认", italian: "Predefiniti globali", french: "Valeurs globales", spanish: "Valores globales"),
                    systemImage: "gearshape"
                )

                SettingsRow(title: AppText.java.localized(theme.language), systemImage: "cup.and.saucer") {
                    VStack(alignment: .leading, spacing: 8) {
                        JavaRuntimePolicySelector(
                            javaPath: $viewModel.javaPath,
                            managedRuntimes: viewModel.managedJavaRuntimes,
                            localRuntimes: viewModel.discoveredJavaRuntimes
                        )
                        GlassButton(systemImage: "checkmark.circle", title: localizedString(theme.language, english: "Check", chinese: "检查", italian: "Controlla", french: "Vérifier", spanish: "Comprobar"), action: viewModel.checkJavaRuntime)
                    }
                }

                if let javaStatus = viewModel.javaStatus {
                    Text(javaStatus.displayText)
                        .font(.caption)
                        .foregroundStyle(javaStatus.isAvailable ? .secondary : Color.orange)
                }

                SettingsRow(title: localizedString(theme.language, english: "Performance", chinese: "性能配置", italian: "Prestazioni", french: "Performance", spanish: "Rendimiento"), systemImage: "speedometer") {
                    JvmTuningControl(
                        memoryPolicy: $memoryPolicy,
                        jvmProfile: $jvmProfile,
                        customMemoryMb: customMemoryMb,
                        currentMemoryMb: viewModel.memoryMb,
                        customJvmArguments: customJvmArguments,
                        onRestoreAutomatic: restoreAutomaticTuning
                    )
                }
            }
        }
    }
}
