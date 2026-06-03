import SwiftUI

struct InstanceEditor: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance
    let openResources: () -> Void
    let openDiscover: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @State private var showAdvancedSettings = false
    @State private var graphicsTuningStatus = ""
    @State private var graphicsTuningRunning = false
    @State private var graphicsCanRollback = false
    @State private var resolvedGraphicsTuning: CoreResolvedGraphicsTuning?

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    PanelHeader(title: localizedString(theme.language, english: "Game Configuration Editor", chinese: "游戏配置编辑", italian: "Editor configurazione", french: "Éditeur de configuration", spanish: "Editor de configuración"), systemImage: "square.and.pencil")
                    Spacer()
                    GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language)) {
                        FinderIntegration.openInstanceDirectory(instance)
                    }
                    GlassButton(systemImage: "trash", title: "Delete", action: onDelete)
                }

                InstanceEditorSection(
                    title: localizedString(theme.language, english: "Basics", chinese: "基础信息", italian: "Base", french: "Base", spanish: "Básico"),
                    systemImage: "info.circle"
                ) {
                    SettingsRow(title: "Name", systemImage: "text.cursor") {
                        PaninoTextInput(localizedString(theme.language, english: "Configuration name", chinese: "游戏配置名称", italian: "Nome configurazione", french: "Nom de configuration", spanish: "Nombre de configuración"), text: $instance.name)
                    }

                    SettingsRow(title: "Icon", systemImage: "app.badge") {
                        PaninoTextInput("SF Symbol name", text: $instance.iconName)
                    }

                    SettingsRow(title: "Cover", systemImage: "photo") {
                        PaninoTextInput("Cover image path", text: $instance.coverPath)
                    }

                    SettingsRow(title: "Game Dir", systemImage: "folder") {
                        PaninoTextInput("Game directory", text: $instance.gameDirectory)
                    }
                }

                InstanceVersionLoaderSelector(viewModel: viewModel, instance: $instance)

                InstanceVersionWorkspace(
                    viewModel: viewModel,
                    instance: $instance,
                    openResources: openResources,
                    openDiscover: openDiscover
                )

                InstanceEditorSection(
                    title: localizedString(theme.language, english: "Performance Profile", chinese: "性能配置", italian: "Profilo prestazioni", french: "Profil performance", spanish: "Perfil de rendimiento"),
                    systemImage: "speedometer"
                ) {
                    JvmTuningControl(
                        memoryPolicy: $instance.memoryPolicy,
                        jvmProfile: $instance.jvmProfile,
                        customMemoryMb: $instance.customMemoryMb,
                        currentMemoryMb: instance.memoryMb,
                        customJvmArguments: instance.customJvmArguments,
                        lastSnapshot: instance.lastJvmTuningSnapshot,
                        lastKnownGood: instance.lastKnownGoodJvmTuning,
                        onRestoreAutomatic: restoreAutomaticTuning,
                        onRestoreLastKnownGood: restoreLastKnownGoodTuning
                    )
                }

                InstanceEditorSection(
                    title: localizedString(theme.language, english: "Graphics Profile", chinese: "画面配置", italian: "Profilo grafica", french: "Profil graphismes", spanish: "Perfil gráfico"),
                    systemImage: "sparkles.tv"
                ) {
                    GraphicsTuningControl(
                        graphicsProfile: $instance.graphicsProfile,
                        manualOverrides: $instance.graphicsManualOverrides,
                        resolved: resolvedGraphicsTuning,
                        canRollback: graphicsCanRollback || instance.lastGraphicsTuningSnapshot?.canRollback == true,
                        statusText: graphicsTuningStatus,
                        isWorking: graphicsTuningRunning,
                        onApplyRecommended: applyGraphicsTuning,
                        onRollback: rollbackGraphicsTuning,
                        onRestoreAutomatic: restoreAutomaticGraphicsTuning
                    )
                }

                FullWidthDisclosureGroup(isExpanded: $showAdvancedSettings) {
                    InstanceEditorSection(
                        title: localizedString(theme.language, english: "Runtime Overrides", chinese: "运行环境覆盖", italian: "Override runtime", french: "Overrides runtime", spanish: "Sobrescrituras runtime"),
                        systemImage: "slider.horizontal.3"
                    ) {
                        SettingsRow(title: "Java", systemImage: "cup.and.saucer") {
                            JavaRuntimePolicySelector(
                                javaPath: $instance.javaPath,
                                managedRuntimes: viewModel.managedJavaRuntimes,
                                localRuntimes: viewModel.discoveredJavaRuntimes
                            )
                        }

                        SettingsRow(title: localizedString(theme.language, english: "Manual Memory", chinese: "手动内存", italian: "Memoria manuale", french: "Mémoire manuelle", spanish: "Memoria manual"), systemImage: "memorychip") {
                            Stepper(value: manualMemoryBinding, in: PaninoLimits.memoryMb, step: 512) {
                                Text("\(instance.memoryMb) MB")
                                    .monospacedDigit()
                            }
                        }

                        SettingsRow(title: "JVM Args", systemImage: "terminal") {
                            PaninoTextInput("Extra JVM arguments", text: customJvmArgumentsBinding)
                        }

                        SettingsRow(title: localizedString(theme.language, english: "Tuning", chinese: "调校", italian: "Tuning", french: "Réglage", spanish: "Ajuste"), systemImage: "arrow.uturn.backward.circle") {
                            GlassButton(
                                systemImage: "wand.and.stars",
                                title: localizedString(theme.language, english: "Restore Automatic", chinese: "恢复自动推荐", italian: "Ripristina automatico", french: "Restaurer automatique", spanish: "Restaurar automático"),
                                action: restoreAutomaticTuning
                            )
                        }

                        SettingsRow(title: "Pre-launch", systemImage: "checklist") {
                            PaninoTextInput("Pre-launch behavior", text: $instance.preLaunchBehavior)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text(localizedString(theme.language, english: "Advanced Java & Launch", chinese: "高级 Java 与启动", italian: "Java e avvio avanzati", french: "Java et lancement avancés", spanish: "Java e inicio avanzado"))
                        .font(.headline)
                }

                InstanceEditorSection(
                    title: localizedString(theme.language, english: "Organization", chinese: "整理", italian: "Organizzazione", french: "Organisation", spanish: "Organización"),
                    systemImage: "folder.badge.gearshape"
                ) {
                    SettingsRow(title: "Group", systemImage: "folder.badge.gearshape") {
                        PaninoTextInput("Group", text: $instance.group)
                    }

                    SettingsRow(title: "Favorite", systemImage: "star") {
                        Toggle("Pinned", isOn: $instance.isFavorite)
                            .toggleStyle(.switch)
                    }

                    SettingsRow(title: AppText.status.localized(theme.language), systemImage: "circle.dashed") {
                        Picker(AppText.status.localized(theme.language), selection: $instance.status) {
                            ForEach(InstanceStatus.allCases) { status in
                                Text(status.title).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
        .task {
            if viewModel.managedJavaRuntimes.isEmpty {
                viewModel.loadManagedJavaRuntimes()
            }
            if viewModel.discoveredJavaRuntimes.isEmpty {
                viewModel.scanJavaRuntimes()
            }
        }
        .task(id: graphicsPreviewSignature) {
            refreshGraphicsTuningPreview()
        }
    }

    private var manualMemoryBinding: Binding<Int> {
        Binding(
            get: { instance.customMemoryMb ?? instance.memoryMb },
            set: { newValue in
                instance.memoryPolicy = .custom
                instance.customMemoryMb = newValue
                instance.memoryMb = newValue
            }
        )
    }

    private var customJvmArgumentsBinding: Binding<String> {
        Binding(
            get: { instance.customJvmArguments },
            set: { newValue in
                instance.customJvmArguments = newValue
                instance.jvmArguments = newValue
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    instance.jvmProfile = .custom
                }
            }
        )
    }

    private var graphicsPreviewSignature: String {
        [
            instance.gameDirectory,
            instance.contentMinecraftVersion,
            instance.loader?.rawValue ?? "",
            instance.graphicsProfile.rawValue,
            instance.graphicsManualOverrides
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: ";")
        ].joined(separator: "|")
    }

    private func restoreAutomaticTuning() {
        instance.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb)
    }

    private func restoreLastKnownGoodTuning(_ snapshot: JvmTuningSnapshot) {
        instance.applyJvmTuningSnapshot(snapshot)
    }

    private func restoreAutomaticGraphicsTuning() {
        instance.restoreAutomaticGraphicsTuning()
        resolvedGraphicsTuning = nil
        graphicsTuningStatus = localizedString(theme.language, english: "Automatic graphics recommendation restored.", chinese: "已恢复自动画面推荐。", italian: "Grafica automatica ripristinata.", french: "Recommandation graphique restaurée.", spanish: "Recomendación gráfica restaurada.")
    }

    private func refreshGraphicsTuningPreview() {
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            resolvedGraphicsTuning = nil
            return
        }
        Task {
            do {
                let resolved = try await viewModel.resolveGraphicsTuning(graphicsTuningRequest(dryRun: true))
                await MainActor.run {
                    resolvedGraphicsTuning = resolved
                }
            } catch {
                await MainActor.run {
                    resolvedGraphicsTuning = nil
                }
            }
        }
    }

    private func applyGraphicsTuning() {
        graphicsTuningRunning = true
        graphicsTuningStatus = localizedString(theme.language, english: "Applying graphics recommendation...", chinese: "正在应用推荐画面设置...", italian: "Applicazione grafica consigliata...", french: "Application des graphismes recommandés...", spanish: "Aplicando gráficos recomendados...")
        Task {
            do {
                let response = try await viewModel.applyGraphicsTuning(graphicsTuningRequest(dryRun: false))
                await MainActor.run {
                    graphicsTuningStatus = response.tuning.summary + " " + localizedString(theme.language, english: "Relaunch Minecraft to use these settings.", chinese: "重新启动 Minecraft 后生效。", italian: "Riavvia Minecraft per usare queste impostazioni.", french: "Relancez Minecraft pour utiliser ces réglages.", spanish: "Reinicia Minecraft para usar estos ajustes.")
                    resolvedGraphicsTuning = response.tuning
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

    private func rollbackGraphicsTuning() {
        graphicsTuningRunning = true
        graphicsTuningStatus = localizedString(theme.language, english: "Restoring previous graphics settings...", chinese: "正在恢复之前的画面设置...", italian: "Ripristino grafica precedente...", french: "Restauration des anciens graphismes...", spanish: "Restaurando gráficos anteriores...")
        Task {
            do {
                _ = try await viewModel.rollbackGraphicsTuning(
                    CoreGraphicsTuningRollbackRequest(gameDir: instance.gameDirectory, backupPath: nil)
                )
                await MainActor.run {
                    graphicsTuningStatus = localizedString(theme.language, english: "Previous graphics settings restored.", chinese: "已恢复之前的画面设置。", italian: "Grafica precedente ripristinata.", french: "Anciens graphismes restaurés.", spanish: "Gráficos anteriores restaurados.")
                    resolvedGraphicsTuning = nil
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

    private func graphicsTuningRequest(dryRun: Bool) -> CoreGraphicsTuningRequest {
        CoreGraphicsTuningRequest(
            instanceId: instance.id.uuidString,
            gameDir: instance.gameDirectory,
            minecraftVersion: instance.contentMinecraftVersion,
            loader: instance.loader?.rawValue,
            requestedProfile: instance.graphicsProfile.rawValue,
            manualOverrides: instance.graphicsManualOverrides,
            dryRun: dryRun
        )
    }
}

struct InstanceEditorSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
    }
}
