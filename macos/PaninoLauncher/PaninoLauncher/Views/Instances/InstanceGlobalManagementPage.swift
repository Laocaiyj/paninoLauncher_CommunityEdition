import SwiftUI

struct InstanceGlobalManagementPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        PanelHeader(
                            title: localizedString(theme.language, english: "Configuration Basics", chinese: "游戏配置基础", italian: "Base configurazione", french: "Base de configuration", spanish: "Base de configuración"),
                            systemImage: "info.circle"
                        )
                        Spacer()
                        GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language)) {
                            FinderIntegration.openInstanceDirectory(instance)
                        }
                        GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language), action: onDelete)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                        SettingsRow(title: "Name", systemImage: "text.cursor") {
                            PaninoTextInput(localizedString(theme.language, english: "Configuration name", chinese: "游戏配置名称", italian: "Nome configurazione", french: "Nom de configuration", spanish: "Nombre de configuración"), text: $instance.name)
                        }
                        SettingsRow(title: "Group", systemImage: "folder.badge.gearshape") {
                            PaninoTextInput("Group", text: $instance.group)
                        }
                        SettingsRow(title: "Game Dir", systemImage: "folder") {
                            PaninoTextInput("Game directory", text: $instance.gameDirectory)
                        }
                        SettingsRow(title: "Favorite", systemImage: "star") {
                            Toggle("Pinned", isOn: $instance.isFavorite)
                                .toggleStyle(.switch)
                        }
                    }
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        PanelHeader(
                            title: localizedString(theme.language, english: "Automated Runtime", chinese: "自动运行环境", italian: "Runtime automatico", french: "Runtime automatisé", spanish: "Runtime automatizado"),
                            systemImage: "wand.and.stars"
                        )
                        Spacer()
                        Toggle(
                            localizedString(theme.language, english: "Auto detect", chinese: "自动检测", italian: "Rileva automaticamente", french: "Détection auto", spanish: "Detectar automáticamente"),
                            isOn: $launcherSettings.autoDetectJava
                        )
                        .toggleStyle(.checkbox)
                        GlassButton(systemImage: "arrow.clockwise", title: localizedString(theme.language, english: "Scan Java", chinese: "扫描 Java", italian: "Scansiona Java", french: "Scanner Java", spanish: "Escanear Java")) {
                            viewModel.scanJavaRuntimes()
                        }
                    }

                    Text(viewModel.javaScanStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if viewModel.discoveredJavaRuntimes.isEmpty {
                        ContentUnavailableView(
                            localizedString(theme.language, english: "No Java runtimes scanned yet", chinese: "尚未扫描到 Java 运行时", italian: "Nessun runtime Java analizzato", french: "Aucun runtime Java analysé", spanish: "No se escanearon runtimes Java"),
                            systemImage: "cup.and.saucer",
                            description: Text(localizedString(theme.language, english: "Panino can scan PATH, macOS JavaVirtualMachines and Homebrew OpenJDK locations through Core.", chinese: "Panino 会通过 Core 扫描 PATH、macOS JavaVirtualMachines 和 Homebrew OpenJDK 位置。", italian: "Panino analizza PATH, JavaVirtualMachines macOS e OpenJDK Homebrew tramite Core.", french: "Panino analyse PATH, JavaVirtualMachines macOS et OpenJDK Homebrew via Core.", spanish: "Panino escanea PATH, JavaVirtualMachines de macOS y OpenJDK de Homebrew mediante Core."))
                        )
                        .frame(minHeight: 140)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                            ForEach(viewModel.discoveredJavaRuntimes) { runtime in
                                JavaRuntimeCandidateCard(runtime: runtime, isSelected: viewModel.javaPath == runtime.path) {
                                    viewModel.javaPath = runtime.path
                                    viewModel.checkJavaRuntime()
                                }
                            }
                        }
                    }
                }
            }
            .task {
                if launcherSettings.autoDetectJava, viewModel.discoveredJavaRuntimes.isEmpty {
                    viewModel.scanJavaRuntimes()
                }
            }

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
                            memoryPolicy: $launcherSettings.memoryPolicy,
                            jvmProfile: $launcherSettings.jvmProfile,
                            customMemoryMb: globalCustomMemoryMbBinding,
                            currentMemoryMb: viewModel.memoryMb,
                            customJvmArguments: launcherSettings.jvmArguments,
                            onRestoreAutomatic: restoreGlobalAutomaticTuning
                        )
                    }
                }
            }
        }
        .task {
            if viewModel.managedJavaRuntimes.isEmpty {
                viewModel.loadManagedJavaRuntimes()
            }
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

    private func restoreGlobalAutomaticTuning() {
        launcherSettings.memoryPolicy = .auto
        launcherSettings.jvmProfile = .auto
        launcherSettings.jvmArguments = ""
    }
}

private struct JavaRuntimeCandidateCard: View {
    let runtime: JavaRuntimeCandidate
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: runtime.isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(runtime.isAvailable ? .green : .orange)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(runtime.source)
                        .font(.caption.weight(.semibold))
                    Text(runtime.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(runtime.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.semanticSelectionColor)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(
                isSelected ? theme.semanticSelectionColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.3),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!runtime.isAvailable)
    }
}
