import SwiftUI

struct SettingsCenterPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var selectedSection: PaninoSettingsSection
    let usesInternalScroll: Bool

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var taskCenterStore: TaskCenterStore
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @State private var curseForgeAPIKey = ""
    @State private var showRuntimeAdvanced = false
    @State private var showLocalJava = false
    @State private var pendingManagedJavaDeletion: CoreJavaManagedRuntime?
    @State private var pendingLocalJavaDeletion: JavaRuntimeCandidate?
    @State private var showAdvancedCore = false
    @State private var sourceTestResponse: CoreNetworkSourceTestResponse?
    @State private var sourceTestMessage = ""
    @State private var sourceTestRunning = false
    @State private var speedTestResponse: CoreNetworkSpeedTestResponse?
    @State private var speedTestMessage = ""
    @State private var speedTestRunning = false

    init(
        viewModel: LauncherViewModel,
        selectedSection: Binding<PaninoSettingsSection> = .constant(.account),
        usesInternalScroll: Bool = true
    ) {
        self.viewModel = viewModel
        self._selectedSection = selectedSection
        self.usesInternalScroll = usesInternalScroll
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: PaninoTokens.Layout.sectionSpacing) {
                settingsSidebar
                settingsContentContainer
            }

            VStack(alignment: .leading, spacing: PaninoTokens.Layout.sectionSpacing) {
                settingsSectionPicker
                settingsContentContainer
            }
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Delete managed Java runtime?", chinese: "删除托管 Java Runtime？", italian: "Eliminare il runtime Java gestito?", french: "Supprimer le runtime Java géré ?", spanish: "¿Eliminar el runtime Java gestionado?"),
            isPresented: Binding(
                get: { pendingManagedJavaDeletion != nil },
                set: { if !$0 { pendingManagedJavaDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingManagedJavaDeletion
        ) { runtime in
            Button(AppText.delete.localized(theme.language), role: .destructive) {
                viewModel.deleteManagedJavaRuntime(runtime)
                pendingManagedJavaDeletion = nil
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {
                pendingManagedJavaDeletion = nil
            }
        } message: { runtime in
            Text(localizedString(
                theme.language,
                english: "Panino will permanently remove \(runtime.displayName). If an instance still references it, Core will block the deletion.",
                chinese: "Panino 将永久删除 \(runtime.displayName)。如果仍有实例引用它，Core 会阻止删除。",
                italian: "Panino rimuoverà definitivamente \(runtime.displayName). Se un'istanza lo usa ancora, Core bloccherà l'eliminazione.",
                french: "Panino supprimera définitivement \(runtime.displayName). Si une instance l'utilise encore, Core bloquera la suppression.",
                spanish: "Panino eliminará permanentemente \(runtime.displayName). Si una instancia aún lo referencia, Core bloqueará la eliminación."
            ))
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Delete local Java runtime?", chinese: "删除本机 Java Runtime？", italian: "Eliminare il runtime Java locale?", french: "Supprimer le runtime Java local ?", spanish: "¿Eliminar el runtime Java local?"),
            isPresented: Binding(
                get: { pendingLocalJavaDeletion != nil },
                set: { if !$0 { pendingLocalJavaDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingLocalJavaDeletion
        ) { runtime in
            Button(AppText.delete.localized(theme.language), role: .destructive) {
                viewModel.deleteLocalJavaRuntime(runtime)
                pendingLocalJavaDeletion = nil
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {
                pendingLocalJavaDeletion = nil
            }
        } message: { runtime in
            Text(localizedString(
                theme.language,
                english: "Panino will permanently remove the Java bundle at \(runtime.deleteTarget ?? runtime.path). PATH, /usr/bin/java and Homebrew shims are not deleted.",
                chinese: "Panino 将永久删除 \(runtime.deleteTarget ?? runtime.path) 这个 Java bundle。PATH、/usr/bin/java 和 Homebrew shim 不会被删除。",
                italian: "Panino rimuoverà definitivamente il bundle Java in \(runtime.deleteTarget ?? runtime.path). PATH, /usr/bin/java e shim Homebrew non vengono eliminati.",
                french: "Panino supprimera définitivement le bundle Java dans \(runtime.deleteTarget ?? runtime.path). PATH, /usr/bin/java et les shims Homebrew ne sont pas supprimés.",
                spanish: "Panino eliminará permanentemente el bundle Java en \(runtime.deleteTarget ?? runtime.path). PATH, /usr/bin/java y shims de Homebrew no se eliminan."
            ))
        }
    }

    private var settingsSidebar: some View {
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

    private var settingsSectionPicker: some View {
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
    private var settingsContentContainer: some View {
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
    private var settingsContent: some View {
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

    private var accountSettings: some View {
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

    private var runtimeSettings: some View {
        SettingsRuntimeSection(
            viewModel: viewModel,
            showRuntimeAdvanced: $showRuntimeAdvanced,
            showLocalJava: $showLocalJava,
            pendingManagedJavaDeletion: $pendingManagedJavaDeletion,
            pendingLocalJavaDeletion: $pendingLocalJavaDeletion
        )
    }

    private var advancedSettings: some View {
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

    private func runSourceTest() {
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

    private func runSpeedTest() {
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

    private func restartCore() {
        Task {
            await viewModel.shutdownCore()
            await viewModel.startCoreIfNeeded()
        }
    }
}
