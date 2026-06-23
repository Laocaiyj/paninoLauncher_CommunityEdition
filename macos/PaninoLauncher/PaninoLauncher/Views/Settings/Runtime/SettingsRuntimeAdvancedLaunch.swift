import SwiftUI

extension SettingsMinecraftRuntimePanel {
    var advancedLaunchSection: some View {
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

    var globalCustomMemoryMbBinding: Binding<Int?> {
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

    var globalMemoryBinding: Binding<Int> {
        Binding(
            get: { viewModel.memoryMb },
            set: { newValue in
                launcherSettings.memoryPolicy = .custom
                viewModel.memoryMb = newValue
            }
        )
    }

    var globalJvmArgumentsBinding: Binding<String> {
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

    func restoreGlobalAutomaticTuning() {
        launcherSettings.memoryPolicy = .auto
        launcherSettings.jvmProfile = .auto
        launcherSettings.jvmArguments = ""
    }
}
