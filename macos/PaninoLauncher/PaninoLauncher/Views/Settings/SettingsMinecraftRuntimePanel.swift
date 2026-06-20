import SwiftUI

struct SettingsMinecraftRuntimePanel: View {
    @EnvironmentObject var theme: ThemeSettings
    @EnvironmentObject var launcherSettings: LauncherSettings
    @EnvironmentObject var diagnosticsStore: DiagnosticsStore

    @ObservedObject var viewModel: LauncherViewModel
    @Binding var showRuntimeAdvanced: Bool

    @State var graphicsTuningStatus = ""
    @State var graphicsTuningRunning = false
    @State var graphicsCanRollback = false
    @State var graphicsManualOverrides: [String: String] = [:]

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(title: "Minecraft", systemImage: "cube.box")

                gameDirectoryRow
                performanceRow
                graphicsRow
                advancedLaunchSection
            }
        }
    }

    private var gameDirectoryRow: some View {
        SettingsRow(title: "Game Dir", systemImage: "folder") {
            VStack(alignment: .leading, spacing: 6) {
                PaninoTextInput("Default Minecraft directory", text: $launcherSettings.defaultGameDirectory)
                CapabilityNote(
                    capability: .available,
                    detail: localizedString(
                        theme.language,
                        english: "Used as an additional installed-version discovery root. New Panino installs still default to isolated instance folders.",
                        chinese: "作为已安装版本的额外扫描目录。新的 Panino 安装仍默认使用隔离实例目录。",
                        italian: "Usata come radice aggiuntiva per trovare versioni installate. Le nuove installazioni Panino restano isolate.",
                        french: "Utilisé comme racine de découverte supplémentaire. Les nouvelles installations Panino restent isolées.",
                        spanish: "Se usa como raíz adicional de descubrimiento. Las instalaciones nuevas de Panino siguen aisladas."
                    )
                )
            }
        }
    }

    private var performanceRow: some View {
        SettingsRow(
            title: localizedString(theme.language, english: "Performance", chinese: "性能配置", italian: "Prestazioni", french: "Performance", spanish: "Rendimiento"),
            systemImage: "speedometer"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                JvmTuningControl(
                    memoryPolicy: $launcherSettings.memoryPolicy,
                    jvmProfile: $launcherSettings.jvmProfile,
                    customMemoryMb: globalCustomMemoryMbBinding,
                    currentMemoryMb: viewModel.memoryMb,
                    customJvmArguments: launcherSettings.jvmArguments,
                    resolved: diagnosticsStore.lastEnvironmentReport?.jvmTuning,
                    onRestoreAutomatic: restoreGlobalAutomaticTuning
                )

                Divider()

                Picker(localizedString(theme.language, english: "Pre-launch apply", chinese: "启动前应用", italian: "Applica prima dell'avvio", french: "Application avant lancement", spanish: "Aplicar antes de iniciar"), selection: $launcherSettings.performanceApplyMode) {
                    ForEach(PerformanceApplyMode.allCases) { mode in
                        Text(mode.title(language: theme.language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 430)

                PerformancePrivacySettings(
                    keepLocalSessions: $launcherSettings.performanceLocalTelemetryEnabled,
                    allowExperiments: $launcherSettings.performanceExperimentsEnabled,
                    shareAnonymousPriors: $launcherSettings.performanceShareAnonymousPriors,
                    language: theme.language
                )
            }
        }
    }

    private var graphicsRow: some View {
        SettingsRow(
            title: localizedString(theme.language, english: "Graphics", chinese: "画面配置", italian: "Grafica", french: "Graphismes", spanish: "Gráficos"),
            systemImage: "sparkles.tv"
        ) {
            GraphicsTuningControl(
                graphicsProfile: $launcherSettings.graphicsProfile,
                manualOverrides: $graphicsManualOverrides,
                resolved: diagnosticsStore.lastEnvironmentReport?.graphicsTuning,
                canRollback: graphicsCanRollback || diagnosticsStore.lastEnvironmentReport?.graphicsTuning?.canRollback == true,
                statusText: graphicsTuningStatus,
                isWorking: graphicsTuningRunning,
                onApplyRecommended: applyGlobalGraphicsTuning,
                onRollback: rollbackGlobalGraphicsTuning,
                onRestoreAutomatic: restoreGlobalAutomaticGraphicsTuning
            )
        }
    }
}
