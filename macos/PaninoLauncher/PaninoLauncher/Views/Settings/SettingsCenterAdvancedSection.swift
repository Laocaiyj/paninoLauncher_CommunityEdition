import SwiftUI

extension SettingsCenterPage {
    var advancedSettings: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            GlassPanel {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    PanelHeader(title: PaninoSettingsSection.advanced.title(language: theme.language), systemImage: PaninoSettingsSection.advanced.systemImage)

                    SettingsRow(title: "Advanced UI", systemImage: "switch.2") {
                        Toggle("Show advanced controls", isOn: $launcherSettings.advancedModeEnabled)
                            .toggleStyle(.switch)
                    }
                    SettingsRow(title: "Auto Core", systemImage: "power") {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Connect Core on launch", isOn: $launcherSettings.autoConnectCore)
                                .toggleStyle(.switch)
                            CapabilityNote(capability: .available)
                        }
                    }
                    SettingsRow(title: "Updates", systemImage: "arrow.triangle.2.circlepath") {
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Check for updates after launch", isOn: $launcherSettings.autoCheckUpdates)
                                .toggleStyle(.switch)
                                .disabled(true)
                            CapabilityNote(
                                capability: .notImplemented,
                                detail: localizedString(
                                    theme.language,
                                    english: "Developer placeholder. Release update checks are not enabled in this build.",
                                    chinese: "开发占位项。此构建未启用发布版自动更新检查。",
                                    italian: "Nessun controllo automatico degli aggiornamenti è ancora collegato.",
                                    french: "Aucun exécuteur de mise à jour automatique n'est encore câblé.",
                                    spanish: "Aún no hay un ejecutor de actualización automática conectado."
                                )
                            )
                        }
                    }
                    SettingsRow(title: "Close", systemImage: "xmark.circle") {
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("Close behavior", selection: $launcherSettings.closeWindowBehavior) {
                                ForEach(CloseWindowBehavior.allCases) { behavior in
                                    Text(behavior.title).tag(behavior)
                                }
                            }
                            .pickerStyle(.segmented)
                            CapabilityNote(capability: .available)
                        }
                    }
                }
            }

            developerDiagnosticsPanel
        }
    }

    private var developerDiagnosticsPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                FullWidthDisclosureGroup(isExpanded: $showAdvancedCore) {
                    VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                        SettingsRow(title: "Core", systemImage: "server.rack") {
                            Text(viewModel.coreState.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        HStack(spacing: 8) {
                            GlassButton(systemImage: "power", title: "Start Core") {
                                Task { await viewModel.startCoreIfNeeded() }
                            }
                            GlassButton(systemImage: "stop.circle", title: "Stop Core") {
                                Task { await viewModel.shutdownCore() }
                            }
                            GlassButton(systemImage: "shippingbox.and.arrow.backward", title: "Export Diagnostics") {
                                diagnosticsStore.exportDiagnosticPackage(
                                    logs: viewModel.logs,
                                    tasks: taskCenterStore.records,
                                    coreState: viewModel.coreState,
                                    javaStatus: viewModel.javaStatus,
                                    managedJavaRuntimes: viewModel.managedJavaRuntimes,
                                    javaRuntimeResolution: viewModel.javaRuntimeResolution
                                )
                                taskCenterStore.enqueueLocal(
                                    kind: "diagnostic-export",
                                    name: localizedString(theme.language, english: "Diagnostic Package", chinese: "诊断包", italian: "Pacchetto diagnostico", french: "Paquet diagnostic", spanish: "Paquete de diagnóstico"),
                                    message: diagnosticsStore.exportStatus
                                )
                            }
                            GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language)) {
                                FinderIntegration.openLogsDirectory()
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text(localizedString(theme.language, english: "Developer Diagnostics", chinese: "开发者诊断", italian: "Diagnostica sviluppatore", french: "Diagnostic développeur", spanish: "Diagnóstico de desarrollo"))
                        .font(.callout.weight(.semibold))
                }
            }
        }
    }
}
