import SwiftUI

struct InstanceRuntimeSettingsPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance

    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    javaSettings
                    performanceSettings
                    loaderSummary
                }
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

    private var header: some View {
        HStack {
            PanelHeader(title: localizedString(theme.language, english: "Runtime Settings", chinese: "运行设置", italian: "Impostazioni runtime", french: "Paramètres runtime", spanish: "Ajustes de runtime"), systemImage: "slider.horizontal.3")
            Spacer()
            Toggle(localizedString(theme.language, english: "Automatic defaults", chinese: "自动默认", italian: "Predefiniti automatici", french: "Défauts automatiques", spanish: "Valores automáticos"), isOn: usesGlobalRuntime)
                .toggleStyle(.switch)
        }
    }

    private var javaSettings: some View {
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
    }

    private var performanceSettings: some View {
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

    private var loaderSummary: some View {
        SettingsRow(title: AppText.loader.localized(theme.language), systemImage: "puzzlepiece.extension") {
            VStack(alignment: .leading, spacing: 3) {
                Text(instance.loaderTitle(language: theme.language, includesVersion: true))
                    .font(.callout.weight(.semibold))
                Text(localizedString(theme.language, english: "Loader changes use the install/preflight flow so Core can validate compatibility.", chinese: "Loader 变更必须走安装/预检流程，由 Core 判断兼容性。", italian: "Le modifiche loader passano dal Core.", french: "Les changements de loader passent par Core.", spanish: "Los cambios de loader pasan por Core."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var usesGlobalRuntime: Binding<Bool> {
        Binding(
            get: { instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            set: { useGlobal in
                if useGlobal {
                    instance.javaPath = ""
                    instance.memoryMb = SettingsStore.memoryMb
                    instance.memoryPolicy = .auto
                    instance.jvmProfile = .auto
                } else {
                    instance.javaPath = "java"
                }
            }
        )
    }

    private func restoreAutomaticTuning() {
        instance.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb)
    }

    private func restoreLastKnownGoodTuning(_ snapshot: JvmTuningSnapshot) {
        instance.applyJvmTuningSnapshot(snapshot)
    }
}
