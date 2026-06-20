import SwiftUI

struct InstanceEditor: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance
    let openResources: () -> Void
    let openDiscover: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject var theme: ThemeSettings
    @State var showAdvancedSettings = false
    @State var graphicsTuningStatus = ""
    @State var graphicsTuningRunning = false
    @State var graphicsCanRollback = false
    @State var resolvedGraphicsTuning: CoreResolvedGraphicsTuning?

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
}
