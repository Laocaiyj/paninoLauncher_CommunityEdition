import SwiftUI

extension SettingsCenterPage {
    var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString(theme.language, english: "Settings", chinese: "设置", italian: "Impostazioni", french: "Réglages", spanish: "Ajustes"))
                .font(.title3.bold())
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.bottom, 4)

            ForEach(PaninoSettingsSection.allCases) { section in
                SettingsSectionButton(
                    section: section,
                    isSelected: selectedSection == section
                ) {
                    selectedSection = section
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .frame(width: PaninoTokens.Layout.secondarySidebarWidth)
    }

    var settingsSectionPicker: some View {
        PaninoGlassSegmentedRail {
            Picker("", selection: $selectedSection) {
                ForEach(PaninoSettingsSection.allCases) { section in
                    Text(section.title(language: theme.language)).tag(section)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(minWidth: 520, idealWidth: 620, maxWidth: .infinity)
        }
    }

    @ViewBuilder
    var settingsContentContainer: some View {
        if usesInternalScroll {
            ScrollView {
                settingsContent
                    .padding(22)
                    .frame(maxWidth: 920, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollContentBackground(.hidden)
        } else {
            settingsContent
                .frame(maxWidth: 920, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    var settingsContent: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            switch selectedSection {
            case .account:
                accountSettings
            case .runtime:
                runtimeSettings
            case .download:
                SettingsDownloadSection(
                    viewModel: viewModel,
                    curseForgeAPIKey: $curseForgeAPIKey,
                    sourceTestResponse: sourceTestResponse,
                    sourceTestMessage: sourceTestMessage,
                    sourceTestRunning: sourceTestRunning,
                    speedTestResponse: speedTestResponse,
                    speedTestMessage: speedTestMessage,
                    speedTestRunning: speedTestRunning,
                    runSourceTest: runSourceTest,
                    runSpeedTest: runSpeedTest,
                    restartCore: restartCore
                )
            case .appearance:
                AppearanceSettingsPage(showLanguage: true)
            case .advanced:
                advancedSettings
            }
        }
    }

    var accountSettings: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(title: PaninoSettingsSection.account.title(language: theme.language), systemImage: PaninoSettingsSection.account.systemImage)

                if launcherSettings.advancedModeEnabled {
                    SettingsRow(title: "Client ID", systemImage: "key") {
                        PaninoTextInput("Azure app client ID", text: $viewModel.microsoftClientId, isSecure: true)
                    }
                } else {
                    SettingsRow(title: "Microsoft", systemImage: "key") {
                        Text(
                            viewModel.canStartLogin
                                ? localizedString(theme.language, english: "Built-in sign-in configuration is available.", chinese: "已使用内置登录配置。", italian: "Configurazione di accesso integrata disponibile.", french: "Configuration de connexion intégrée disponible.", spanish: "La configuración integrada de inicio está disponible.")
                                : localizedString(theme.language, english: "Client ID override is hidden until Advanced is enabled.", chinese: "Client ID 覆盖会在启用高级项后显示。", italian: "L'override Client ID è nascosto finché Avanzate non è attivo.", french: "Le Client ID personnalisé est masqué jusqu'à l'activation d'Avancé.", spanish: "El Client ID personalizado se oculta hasta activar Avanzado.")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    }
                }

                AccountCard(accountState: viewModel.accountState)
            }
        }
    }

    var runtimeSettings: some View {
        SettingsRuntimeSection(
            viewModel: viewModel,
            showRuntimeAdvanced: $showRuntimeAdvanced,
            showLocalJava: $showLocalJava,
            pendingManagedJavaDeletion: $pendingManagedJavaDeletion,
            pendingLocalJavaDeletion: $pendingLocalJavaDeletion
        )
    }

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

    func runSourceTest() {
        sourceTestRunning = true
        sourceTestMessage = "Checking connection through Core..."
        Task {
            do {
                let response = try await viewModel.sourceTest()
                await MainActor.run {
                    sourceTestResponse = response
                    sourceTestMessage = response.ok ? "Connection check passed" : "Connection check found failures"
                    sourceTestRunning = false
                }
            } catch {
                await MainActor.run {
                    sourceTestMessage = "Connection check failed: \(error.localizedDescription)"
                    sourceTestRunning = false
                }
            }
        }
    }

    func runSpeedTest() {
        speedTestRunning = true
        speedTestMessage = "Measuring download throughput..."
        let reportRequest = CoreEnvironmentReportRequest(
            gameDir: launcherSettings.defaultGameDirectory,
            version: viewModel.version,
            loader: nil,
            loaderVersion: nil,
            memoryMb: viewModel.memoryMb,
            memoryPolicy: launcherSettings.memoryPolicy.rawValue,
            jvmProfile: launcherSettings.jvmProfile.rawValue,
            customMemoryMb: launcherSettings.memoryPolicy == .custom ? viewModel.memoryMb : nil,
            customJvmArgs: launcherSettings.jvmArguments,
            graphicsProfile: launcherSettings.graphicsProfile.rawValue
        )
        Task {
            do {
                async let speed = viewModel.speedTest()
                async let environment = viewModel.environmentReport(reportRequest)
                let response = try await speed
                let report = try await environment
                await MainActor.run {
                    speedTestResponse = response
                    diagnosticsStore.lastNetworkSpeedTest = response
                    diagnosticsStore.lastEnvironmentReport = report
                    let fastest = response.fastestResult.map { formattedBytes($0.bytesPerSecond) + "/s" } ?? "-"
                    speedTestMessage = response.ok ? "Fastest: \(fastest)" : "Speed test found failures"
                    speedTestRunning = false
                }
            } catch {
                await MainActor.run {
                    speedTestMessage = "Speed test failed: \(error.localizedDescription)"
                    speedTestRunning = false
                }
            }
        }
    }

    func restartCore() {
        Task {
            await viewModel.shutdownCore()
            await viewModel.startCoreIfNeeded()
        }
    }
}
