import SwiftUI

struct SettingsRuntimeSection: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var showRuntimeAdvanced: Bool
    @Binding var showLocalJava: Bool
    @Binding var pendingManagedJavaDeletion: CoreJavaManagedRuntime?
    @Binding var pendingLocalJavaDeletion: JavaRuntimeCandidate?

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @State private var graphicsTuningStatus = ""
    @State private var graphicsTuningRunning = false
    @State private var graphicsCanRollback = false
    @State private var graphicsManualOverrides: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            SettingsJavaRuntimePanel(
                viewModel: viewModel,
                showRuntimeAdvanced: $showRuntimeAdvanced,
                showLocalJava: $showLocalJava,
                pendingManagedJavaDeletion: $pendingManagedJavaDeletion,
                pendingLocalJavaDeletion: $pendingLocalJavaDeletion
            )
            minecraftRuntimePanel
        }
    }

    private var minecraftRuntimePanel: some View {
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

    private var advancedLaunchSection: some View {
        FullWidthDisclosureGroup(isExpanded: $showRuntimeAdvanced) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                SettingsRow(title: "Window", systemImage: "rectangle.inset.filled") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Stepper(value: $launcherSettings.windowWidth, in: 640...3840, step: 20) {
                                Text("W \(launcherSettings.windowWidth)")
                                    .monospacedDigit()
                            }
                            Stepper(value: $launcherSettings.windowHeight, in: 480...2160, step: 20) {
                                Text("H \(launcherSettings.windowHeight)")
                                    .monospacedDigit()
                            }
                        }
                        CapabilityNote(capability: .available)
                    }
                }
                SettingsRow(title: localizedString(theme.language, english: "Memory", chinese: "手动内存", italian: "Memoria", french: "Mémoire", spanish: "Memoria"), systemImage: "memorychip") {
                    VStack(alignment: .leading, spacing: 6) {
                        Stepper(value: globalMemoryBinding, in: PaninoLimits.memoryMb, step: 512) {
                            Text("\(viewModel.memoryMb) MB")
                                .monospacedDigit()
                        }
                        CapabilityNote(
                            capability: .available,
                            detail: localizedString(
                                theme.language,
                                english: "Advanced override. Prefer automatic unless you are diagnosing a specific pack.",
                                chinese: "高级覆盖项。除非在排查特定整合包，否则优先使用自动推荐。",
                                italian: "Override avanzato. Preferisci automatico salvo diagnosi specifiche.",
                                french: "Remplacement avancé. Préférez automatique sauf diagnostic précis.",
                                spanish: "Anulación avanzada. Prefiere automático salvo diagnóstico concreto."
                            )
                        )
                    }
                }
                SettingsRow(title: "JVM Args", systemImage: "terminal") {
                    VStack(alignment: .leading, spacing: 6) {
                        PaninoTextInput("Default JVM arguments", text: globalJvmArgumentsBinding)
                        CapabilityNote(capability: .available)
                    }
                }
                SettingsRow(title: localizedString(theme.language, english: "Tuning", chinese: "调校", italian: "Tuning", french: "Réglage", spanish: "Ajuste"), systemImage: "arrow.uturn.backward.circle") {
                    GlassButton(
                        systemImage: "wand.and.stars",
                        title: localizedString(theme.language, english: "Restore Automatic", chinese: "恢复自动推荐", italian: "Ripristina automatico", french: "Restaurer automatique", spanish: "Restaurar automático"),
                        action: restoreGlobalAutomaticTuning
                    )
                }
                SettingsRow(title: "Repair", systemImage: "wrench.and.screwdriver") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Install missing files before launch", isOn: $launcherSettings.installMissingFilesBeforeLaunch)
                            .toggleStyle(.switch)
                        CapabilityNote(capability: .available)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Text(localizedString(theme.language, english: "Advanced Launch", chinese: "高级启动", italian: "Avvio avanzato", french: "Lancement avancé", spanish: "Inicio avanzado"))
                .font(.callout.weight(.semibold))
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

    private var globalMemoryBinding: Binding<Int> {
        Binding(
            get: { viewModel.memoryMb },
            set: { newValue in
                launcherSettings.memoryPolicy = .custom
                viewModel.memoryMb = newValue
            }
        )
    }

    private var globalJvmArgumentsBinding: Binding<String> {
        Binding(
            get: { launcherSettings.jvmArguments },
            set: { newValue in
                launcherSettings.jvmArguments = newValue
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    launcherSettings.jvmProfile = .custom
                }
            }
        )
    }

    private func restoreGlobalAutomaticTuning() {
        launcherSettings.memoryPolicy = .auto
        launcherSettings.jvmProfile = .auto
        launcherSettings.jvmArguments = ""
    }

    private func restoreGlobalAutomaticGraphicsTuning() {
        launcherSettings.graphicsProfile = .balanced
        graphicsManualOverrides = [:]
        graphicsTuningStatus = localizedString(theme.language, english: "Automatic graphics recommendation restored.", chinese: "已恢复自动画面推荐。", italian: "Grafica automatica ripristinata.", french: "Recommandation graphique restaurée.", spanish: "Recomendación gráfica restaurada.")
    }

    private func applyGlobalGraphicsTuning() {
        graphicsTuningRunning = true
        graphicsTuningStatus = localizedString(theme.language, english: "Applying graphics recommendation...", chinese: "正在应用推荐画面设置...", italian: "Applicazione grafica consigliata...", french: "Application des graphismes recommandés...", spanish: "Aplicando gráficos recomendados...")
        Task {
            do {
                let response = try await viewModel.applyGraphicsTuning(globalGraphicsTuningRequest(dryRun: false))
                await MainActor.run {
                    graphicsTuningStatus = response.tuning.summary + " " + localizedString(theme.language, english: "Relaunch Minecraft to use these settings.", chinese: "重新启动 Minecraft 后生效。", italian: "Riavvia Minecraft per usare queste impostazioni.", french: "Relancez Minecraft pour utiliser ces réglages.", spanish: "Reinicia Minecraft para usar estos ajustes.")
                    graphicsCanRollback = true
                    graphicsTuningRunning = false
                }
            } catch {
                await MainActor.run {
                    graphicsTuningStatus = error.localizedDescription
                    graphicsTuningRunning = false
                }
            }
        }
    }

    private func rollbackGlobalGraphicsTuning() {
        graphicsTuningRunning = true
        graphicsTuningStatus = localizedString(theme.language, english: "Restoring previous graphics settings...", chinese: "正在恢复之前的画面设置...", italian: "Ripristino grafica precedente...", french: "Restauration des anciens graphismes...", spanish: "Restaurando gráficos anteriores...")
        Task {
            do {
                _ = try await viewModel.rollbackGraphicsTuning(
                    CoreGraphicsTuningRollbackRequest(
                        gameDir: launcherSettings.defaultGameDirectory,
                        backupPath: diagnosticsStore.lastEnvironmentReport?.graphicsTuning?.backupPath
                    )
                )
                await MainActor.run {
                    graphicsTuningStatus = localizedString(theme.language, english: "Previous graphics settings restored.", chinese: "已恢复之前的画面设置。", italian: "Grafica precedente ripristinata.", french: "Anciens graphismes restaurés.", spanish: "Gráficos anteriores restaurados.")
                    graphicsCanRollback = false
                    graphicsTuningRunning = false
                }
            } catch {
                await MainActor.run {
                    graphicsTuningStatus = error.localizedDescription
                    graphicsTuningRunning = false
                }
            }
        }
    }

    private func globalGraphicsTuningRequest(dryRun: Bool) -> CoreGraphicsTuningRequest {
        CoreGraphicsTuningRequest(
            gameDir: launcherSettings.defaultGameDirectory,
            minecraftVersion: viewModel.version,
            loader: nil,
            requestedProfile: launcherSettings.graphicsProfile.rawValue,
            manualOverrides: graphicsManualOverrides,
            dryRun: dryRun
        )
    }
}
