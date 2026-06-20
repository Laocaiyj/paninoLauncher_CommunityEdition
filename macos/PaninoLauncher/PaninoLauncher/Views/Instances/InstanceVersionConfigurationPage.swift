import SwiftUI

struct InstanceVersionConfigurationPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance
    let version: MinecraftVersionInfo?
    let openResources: () -> Void
    let openDiscover: () -> Void
    let onBack: () -> Void

    @EnvironmentObject var versionStore: VersionContentStore
    @EnvironmentObject var instanceStore: InstanceStore
    @EnvironmentObject var launcherSettings: LauncherSettings
    @EnvironmentObject var theme: ThemeSettings
    @State var confirmApplyVersion = false
    @State var pendingStorageAction: VersionStorageConfirmation?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    InstanceVersionRuntimeHeader(
                        versionStateTitle: versionStateTitle,
                        versionBadgeStyle: versionBadgeStyle,
                        canApplyVersion: canApplyVersion,
                        canRepairVersion: version?.isInstalled == true,
                        onBack: onBack,
                        onApply: { confirmApplyVersion = true },
                        onRepair: repairFocusedVersion,
                        onDiscover: openDiscover
                    )

                    VersionRuntimeMetricsGrid(version: version, instance: instance)

                    VersionStorageControls(
                        version: version,
                        canArchive: canArchive,
                        canDelete: canDelete,
                        selectAction: { pendingStorageAction = $0 }
                    )

                    SettingsRow(
                        title: localizedString(theme.language, english: "Use Global Runtime", chinese: "使用全局运行环境", italian: "Usa runtime globale", french: "Utiliser runtime global", spanish: "Usar runtime global"),
                        systemImage: "globe"
                    ) {
                        Toggle("", isOn: usesGlobalRuntime)
                            .toggleStyle(.switch)
                    }

                    SettingsRow(title: AppText.loader.localized(theme.language), systemImage: "puzzlepiece.extension") {
                        Picker(AppText.loader.localized(theme.language), selection: $instance.loader) {
                            Text("Vanilla").tag(nil as LoaderKind?)
                            ForEach(compatibleLoaders) { loader in
                                Text(loader.title).tag(Optional(loader))
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 520)
                    }

                    SettingsRow(title: AppText.java.localized(theme.language), systemImage: "cup.and.saucer") {
                        VStack(alignment: .leading, spacing: 8) {
                            JavaRuntimePolicySelector(
                                javaPath: $instance.javaPath,
                                managedRuntimes: viewModel.managedJavaRuntimes,
                                localRuntimes: viewModel.discoveredJavaRuntimes
                            )
                            .disabled(usesGlobalRuntime.wrappedValue)

                            HStack(spacing: 8) {
                                GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Scan", chinese: "扫描", italian: "Scansiona", french: "Scanner", spanish: "Escanear")) {
                                    viewModel.scanJavaRuntimes()
                                }
                                Text(viewModel.javaScanStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    SettingsRow(title: localizedString(theme.language, english: "Performance", chinese: "性能配置", italian: "Prestazioni", french: "Performance", spanish: "Rendimiento"), systemImage: "speedometer") {
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
                        .disabled(usesGlobalRuntime.wrappedValue)
                    }
                }
            }

            ResourcesManagementPage(viewModel: viewModel)
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Apply version change?", chinese: "确认更改版本？", italian: "Applicare cambio versione?", french: "Appliquer le changement de version ?", spanish: "¿Aplicar cambio de versión?"),
            isPresented: $confirmApplyVersion,
            titleVisibility: .visible
        ) {
            Button(localizedString(theme.language, english: "Apply to \(instance.name)", chinese: "应用到 \(instance.name)", italian: "Applica a \(instance.name)", french: "Appliquer à \(instance.name)", spanish: "Aplicar a \(instance.name)")) {
                applyVersionChange()
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {}
        } message: {
            Text(versionChangeSummary)
        }
        .confirmationDialog(
            pendingStorageAction?.title(language: theme.language) ?? "",
            isPresented: storageDialogPresented,
            titleVisibility: .visible
        ) {
            if let action = pendingStorageAction {
                Button(action.confirmTitle(language: theme.language), role: action.role) {
                    mutateVersionStorage(action)
                    pendingStorageAction = nil
                }
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {}
        } message: {
            if let action = pendingStorageAction {
                Text(action.message(version: version?.id ?? "-", language: theme.language))
            }
        }
        .task {
            if viewModel.managedJavaRuntimes.isEmpty {
                viewModel.loadManagedJavaRuntimes()
            }
            if launcherSettings.autoDetectJava, viewModel.discoveredJavaRuntimes.isEmpty {
                viewModel.scanJavaRuntimes()
            }
        }
    }
}
