import SwiftUI

struct InstanceEditorHeader: View {
    @EnvironmentObject private var theme: ThemeSettings

    let openFolder: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack {
            PanelHeader(title: localizedString(theme.language, english: "Game Configuration Editor", chinese: "游戏配置编辑", italian: "Editor configurazione", french: "Éditeur de configuration", spanish: "Editor de configuración"), systemImage: "square.and.pencil")
            Spacer()
            GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language), action: openFolder)
            GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language), action: delete)
        }
    }
}

struct InstanceEditorBasicsSection: View {
    @EnvironmentObject private var theme: ThemeSettings

    @Binding var instance: GameInstance

    var body: some View {
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
    }
}

struct InstanceEditorPerformanceSection: View {
    @EnvironmentObject private var theme: ThemeSettings

    @Binding var instance: GameInstance
    let restoreAutomaticTuning: () -> Void
    let restoreLastKnownGoodTuning: (JvmTuningSnapshot) -> Void

    var body: some View {
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
    }
}

struct InstanceEditorGraphicsSection: View {
    @EnvironmentObject private var theme: ThemeSettings

    @Binding var instance: GameInstance
    let resolvedGraphicsTuning: CoreResolvedGraphicsTuning?
    let canRollback: Bool
    let statusText: String
    let isWorking: Bool
    let applyRecommended: () -> Void
    let rollback: () -> Void
    let restoreAutomatic: () -> Void

    var body: some View {
        InstanceEditorSection(
            title: localizedString(theme.language, english: "Graphics Profile", chinese: "画面配置", italian: "Profilo grafica", french: "Profil graphismes", spanish: "Perfil gráfico"),
            systemImage: "sparkles.tv"
        ) {
            GraphicsTuningControl(
                graphicsProfile: $instance.graphicsProfile,
                manualOverrides: $instance.graphicsManualOverrides,
                resolved: resolvedGraphicsTuning,
                canRollback: canRollback,
                statusText: statusText,
                isWorking: isWorking,
                onApplyRecommended: applyRecommended,
                onRollback: rollback,
                onRestoreAutomatic: restoreAutomatic
            )
        }
    }
}

struct InstanceEditorRuntimeOverridesSection: View {
    @EnvironmentObject private var theme: ThemeSettings

    @Binding var instance: GameInstance
    let managedRuntimes: [CoreJavaManagedRuntime]
    let localRuntimes: [JavaRuntimeCandidate]
    let manualMemory: Binding<Int>
    let customJvmArguments: Binding<String>
    let restoreAutomaticTuning: () -> Void

    var body: some View {
        InstanceEditorSection(
            title: localizedString(theme.language, english: "Runtime Overrides", chinese: "运行环境覆盖", italian: "Override runtime", french: "Overrides runtime", spanish: "Sobrescrituras runtime"),
            systemImage: "slider.horizontal.3"
        ) {
            SettingsRow(title: "Java", systemImage: "cup.and.saucer") {
                JavaRuntimePolicySelector(
                    javaPath: $instance.javaPath,
                    managedRuntimes: managedRuntimes,
                    localRuntimes: localRuntimes
                )
            }

            SettingsRow(title: localizedString(theme.language, english: "Manual Memory", chinese: "手动内存", italian: "Memoria manuale", french: "Mémoire manuelle", spanish: "Memoria manual"), systemImage: "memorychip") {
                Stepper(value: manualMemory, in: PaninoLimits.memoryMb, step: 512) {
                    Text("\(instance.memoryMb) MB")
                        .monospacedDigit()
                }
            }

            SettingsRow(title: "JVM Args", systemImage: "terminal") {
                PaninoTextInput("Extra JVM arguments", text: customJvmArguments)
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
    }
}

struct InstanceEditorOrganizationSection: View {
    @EnvironmentObject private var theme: ThemeSettings

    @Binding var instance: GameInstance

    var body: some View {
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
