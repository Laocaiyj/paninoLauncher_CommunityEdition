import SwiftUI

struct SettingsCenterPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var selectedSection: PaninoSettingsSection

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var taskCenterStore: TaskCenterStore
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @EnvironmentObject private var onlineContentStore: OnlineContentStore
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
    @State private var graphicsTuningStatus = ""
    @State private var graphicsTuningRunning = false
    @State private var graphicsCanRollback = false
    @State private var graphicsManualOverrides: [String: String] = [:]

    init(
        viewModel: LauncherViewModel,
        selectedSection: Binding<PaninoSettingsSection> = .constant(.account)
    ) {
        self.viewModel = viewModel
        self._selectedSection = selectedSection
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            settingsSidebar

            ScrollView {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    switch selectedSection {
                    case .account:
                        accountSettings
                    case .runtime:
                        runtimeSettings
                    case .download:
                        downloadSettings
                    case .appearance:
                        AppearanceSettingsPage(showLanguage: true)
                    case .advanced:
                        advancedSettings
                    }
                }
                .padding(22)
                .frame(maxWidth: 920, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollContentBackground(.hidden)
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
                .padding(.horizontal, 14)
                .padding(.top, 18)
                .padding(.bottom, 8)

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
        .padding(.horizontal, 10)
        .frame(width: PaninoTokens.Layout.secondarySidebarWidth)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
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
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            GlassPanel {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    PanelHeader(title: PaninoSettingsSection.runtime.title(language: theme.language), systemImage: PaninoSettingsSection.runtime.systemImage)

                    SettingsRow(title: "Java", systemImage: "cup.and.saucer") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Text(localizedString(theme.language, english: "Automatic management", chinese: "自动管理", italian: "Gestione automatica", french: "Gestion automatique", spanish: "Gestión automática"))
                                    .font(.callout.weight(.semibold))
                                Spacer()
                                GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
                                    viewModel.loadManagedJavaRuntimes()
                                    viewModel.resolveJavaRuntime(version: viewModel.version)
                                }
                                GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Scan", chinese: "扫描", italian: "Scansiona", french: "Scanner", spanish: "Escanear")) {
                                    viewModel.scanJavaRuntimes()
                                }
                                if let resolution = viewModel.javaRuntimeResolution, resolution.isDownloadable {
                                    GlassButton(systemImage: "arrow.down.circle", title: localizedString(theme.language, english: "Download Java \(resolution.requiredMajorVersion)", chinese: "下载 Java \(resolution.requiredMajorVersion)", italian: "Scarica Java \(resolution.requiredMajorVersion)", french: "Télécharger Java \(resolution.requiredMajorVersion)", spanish: "Descargar Java \(resolution.requiredMajorVersion)"), prominent: true) {
                                        viewModel.installManagedJavaRuntime(featureVersion: resolution.requiredMajorVersion)
                                    }
                                }
                                if let runtime = selectedManagedRuntimeForRepair {
                                    GlassButton(systemImage: "wrench.and.screwdriver", title: localizedString(theme.language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar")) {
                                        viewModel.verifyManagedJavaRuntime(runtime)
                                    }
                                }
                            }
                            Text(viewModel.javaRuntimeResolution?.conciseStatus ?? viewModel.javaRuntimeStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(localizedString(theme.language, english: "Managed Runtimes", chinese: "托管 Runtime", italian: "Runtime gestiti", french: "Runtimes gérés", spanish: "Runtimes gestionados"))
                                .font(.headline)
                            Spacer()
                            GlassButton(systemImage: "square.and.arrow.down", title: localizedString(theme.language, english: "Import", chinese: "导入", italian: "Importa", french: "Importer", spanish: "Importar")) {
                                viewModel.importManagedJavaRuntime()
                            }
                            GlassButton(systemImage: "arrow.triangle.2.circlepath", title: localizedString(theme.language, english: "Clean", chinese: "清理", italian: "Pulisci", french: "Nettoyer", spanish: "Limpiar")) {
                                viewModel.cleanupManagedJavaRuntimes()
                            }
                        }
                        if viewModel.managedJavaRuntimes.isEmpty {
                            Text(localizedString(theme.language, english: "No managed Java runtime is installed yet.", chinese: "尚未安装托管 Java Runtime。", italian: "Nessun runtime Java gestito installato.", french: "Aucun runtime Java géré installé.", spanish: "Aún no hay runtime Java gestionado."))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.managedJavaRuntimes) { runtime in
                                    ManagedJavaRuntimeRow(
                                        runtime: runtime,
                                        makeDefault: { viewModel.selectManagedJavaRuntime(runtime) },
                                        verify: { viewModel.verifyManagedJavaRuntime(runtime) },
                                        remove: { pendingManagedJavaDeletion = runtime }
                                    )
                                }
                            }
                        }
                    }

                    FullWidthDisclosureGroup(isExpanded: $showLocalJava) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(viewModel.javaScanStatus)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Scan This Mac", chinese: "扫描本机", italian: "Scansiona Mac", french: "Scanner ce Mac", spanish: "Escanear Mac")) {
                                    viewModel.scanJavaRuntimes()
                                }
                            }
                            if viewModel.discoveredJavaRuntimes.filter(\.isAvailable).isEmpty {
                                Text(localizedString(theme.language, english: "No local Java runtime is available yet.", chinese: "尚未发现可用的本机 Java。", italian: "Nessun Java locale disponibile.", french: "Aucun Java local disponible.", spanish: "No hay Java local disponible."))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(viewModel.discoveredJavaRuntimes.filter(\.isAvailable)) { runtime in
                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack(spacing: 8) {
                                                    Text(runtime.source)
                                                        .font(.caption.weight(.semibold))
                                                    if runtime.hasMeaningfulSummary {
                                                        Text(runtime.displayText)
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                            .lineLimit(1)
                                                    }
                                                }
                                                Text(runtime.pathDetailText)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                                if let deleteTarget = runtime.deleteTarget, runtime.supportsDeletion {
                                                    Text(deleteTarget)
                                                        .font(.caption2)
                                                        .foregroundStyle(.tertiary)
                                                        .lineLimit(1)
                                                        .truncationMode(.middle)
                                                }
                                            }
                                            Spacer(minLength: 8)
                                            if runtime.supportsDeletion {
                                                GlassButton(systemImage: "trash", title: AppText.delete.localized(theme.language)) {
                                                    pendingLocalJavaDeletion = runtime
                                                }
                                            }
                                        }
                                        .padding(9)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text(localizedString(theme.language, english: "Local Java", chinese: "本机 Java", italian: "Java locale", french: "Java local", spanish: "Java local"))
                            .font(.callout.weight(.semibold))
                    }

                    FullWidthDisclosureGroup(isExpanded: $showRuntimeAdvanced) {
                        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                            SettingsRow(title: localizedString(theme.language, english: "Override", chinese: "覆盖", italian: "Override", french: "Remplacement", spanish: "Sobrescribir"), systemImage: "terminal") {
                                VStack(alignment: .leading, spacing: 8) {
                                    JavaRuntimePolicySelector(
                                        javaPath: $viewModel.javaPath,
                                        managedRuntimes: viewModel.managedJavaRuntimes,
                                        localRuntimes: viewModel.discoveredJavaRuntimes
                                    )
                                    HStack(spacing: 8) {
                                        GlassButton(systemImage: "checkmark.circle", title: localizedString(theme.language, english: "Check", chinese: "检查", italian: "Verifica", french: "Vérifier", spanish: "Comprobar")) {
                                            viewModel.checkJavaRuntime()
                                        }
                                        GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Scan This Mac", chinese: "扫描本机", italian: "Scansiona Mac", french: "Scanner ce Mac", spanish: "Escanear Mac")) {
                                            viewModel.scanJavaRuntimes()
                                        }
                                    }
                                    if let javaStatus = viewModel.javaStatus {
                                        Text(javaStatus.displayText)
                                            .font(.caption)
                                            .foregroundStyle(javaStatus.isAvailable ? .secondary : Color.orange)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Text(localizedString(theme.language, english: "Advanced Java", chinese: "高级 Java", italian: "Java avanzato", french: "Java avancé", spanish: "Java avanzado"))
                            .font(.callout.weight(.semibold))
                    }
                }
            }
            .task {
                viewModel.loadManagedJavaRuntimes()
                viewModel.resolveJavaRuntime(version: viewModel.version)
                if launcherSettings.autoDetectJava, viewModel.discoveredJavaRuntimes.isEmpty {
                    viewModel.scanJavaRuntimes()
                }
            }

            GlassPanel {
                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    PanelHeader(title: "Minecraft", systemImage: "cube.box")

                    SettingsRow(title: "Game Dir", systemImage: "folder") {
                        VStack(alignment: .leading, spacing: 6) {
                            PaninoTextInput("Default Minecraft directory", text: $launcherSettings.defaultGameDirectory)
                            CapabilityNote(
                                capability: .available,
                                detail: localizedString(
                                    theme.language,
                                    english: "Used as an additional installed-version discovery root. New Panino installs still default to isolated instance folders.",
                                    chinese: "作为已安装版本的额外扫描目录。新的 Panino 安装仍默认使用隔离实例目录。",
                                    italian: "Usata come radice aggiuntiva per trovare versioni installate. Le nuove installazioni Panino restano isolate.",
                                    french: "Utilisé comme racine de découverte supplémentaire. Les nouvelles installations Panino restent isolées.",
                                    spanish: "Se usa como raíz adicional de descubrimiento. Las instalaciones nuevas de Panino siguen aisladas."
                                )
                            )
                        }
                    }

                    SettingsRow(
                        title: localizedString(theme.language, english: "Performance", chinese: "性能配置", italian: "Prestazioni", french: "Performance", spanish: "Rendimiento"),
                        systemImage: "speedometer"
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            JvmTuningControl(
                                memoryPolicy: $launcherSettings.memoryPolicy,
                                jvmProfile: $launcherSettings.jvmProfile,
                                customMemoryMb: globalCustomMemoryMbBinding,
                                currentMemoryMb: viewModel.memoryMb,
                                customJvmArguments: launcherSettings.jvmArguments,
                                resolved: diagnosticsStore.lastEnvironmentReport?.jvmTuning,
                                onRestoreAutomatic: restoreGlobalAutomaticTuning
                            )

                            Divider()

                            Picker(localizedString(theme.language, english: "Pre-launch apply", chinese: "启动前应用", italian: "Applica prima dell'avvio", french: "Application avant lancement", spanish: "Aplicar antes de iniciar"), selection: $launcherSettings.performanceApplyMode) {
                                ForEach(PerformanceApplyMode.allCases) { mode in
                                    Text(mode.title(language: theme.language)).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 430)

                            PerformancePrivacySettings(
                                keepLocalSessions: $launcherSettings.performanceLocalTelemetryEnabled,
                                allowExperiments: $launcherSettings.performanceExperimentsEnabled,
                                shareAnonymousPriors: $launcherSettings.performanceShareAnonymousPriors,
                                language: theme.language
                            )
                        }
                    }

                    SettingsRow(
                        title: localizedString(theme.language, english: "Graphics", chinese: "画面配置", italian: "Grafica", french: "Graphismes", spanish: "Gráficos"),
                        systemImage: "sparkles.tv"
                    ) {
                        GraphicsTuningControl(
                            graphicsProfile: $launcherSettings.graphicsProfile,
                            manualOverrides: $graphicsManualOverrides,
                            resolved: diagnosticsStore.lastEnvironmentReport?.graphicsTuning,
                            canRollback: graphicsCanRollback || diagnosticsStore.lastEnvironmentReport?.graphicsTuning?.canRollback == true,
                            statusText: graphicsTuningStatus,
                            isWorking: graphicsTuningRunning,
                            onApplyRecommended: applyGlobalGraphicsTuning,
                            onRollback: rollbackGlobalGraphicsTuning,
                            onRestoreAutomatic: restoreGlobalAutomaticGraphicsTuning
                        )
                    }

                    FullWidthDisclosureGroup(isExpanded: $showAdvancedCore) {
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
            }
        }
    }

    private var selectedManagedRuntimeForRepair: CoreJavaManagedRuntime? {
        if let selectedRuntimeId = viewModel.javaRuntimeResolution?.selectedRuntimeId,
           let runtime = viewModel.managedJavaRuntimes.first(where: { $0.id == selectedRuntimeId }) {
            return runtime
        }
        return viewModel.managedJavaRuntimes.first
    }

    private var downloadSettings: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                PanelHeader(title: PaninoSettingsSection.download.title(language: theme.language), systemImage: PaninoSettingsSection.download.systemImage)

                SettingsRow(title: "Download Strategy", systemImage: "speedometer") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Download Strategy", selection: $launcherSettings.downloadStrategy) {
                            ForEach(DownloadStrategy.allCases) { strategy in
                                Text(strategy.title).tag(strategy)
                            }
                        }
                        .pickerStyle(.segmented)
                        CapabilityNote(
                            capability: viewModel.coreState.isReady ? .requiresCoreRestart : .available,
                            detail: launcherSettings.downloadStrategy.detail
                        )
                    }
                }

                if launcherSettings.advancedModeEnabled {
                    SettingsRow(title: "Source", systemImage: "globe") {
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("Source", selection: $launcherSettings.downloadSource) {
                                ForEach(DownloadSource.selectableCases) { source in
                                    Text(source.title).tag(source)
                                }
                            }
                            .pickerStyle(.segmented)
                            CapabilityNote(
                                capability: viewModel.coreState.isReady ? .requiresCoreRestart : .available,
                                detail: localizedString(
                                    theme.language,
                                    english: "Official and BMCLAPI are wired through Core startup environment. Custom is hidden until one validated profile format exists.",
                                    chinese: "Official 与 BMCLAPI 已通过 Core 启动环境接入。Custom 在统一格式落地前隐藏。",
                                    italian: "Official e BMCLAPI sono collegati tramite ambiente Core. Custom resta nascosto finché il formato non è definito.",
                                    french: "Official et BMCLAPI passent par l'environnement Core. Custom reste masqué jusqu'à un format validé.",
                                    spanish: "Official y BMCLAPI están conectados vía entorno Core. Custom queda oculto hasta validar un formato."
                                )
                            )
                            HStack(spacing: 8) {
                                GlassButton(systemImage: "network", title: sourceTestRunning ? "Checking..." : "Check Connection") {
                                    runSourceTest()
                                }
                                .disabled(sourceTestRunning)
                                GlassButton(systemImage: "speedometer", title: speedTestRunning ? "Testing..." : "Test Download Speed") {
                                    runSpeedTest()
                                }
                                .disabled(speedTestRunning)
                                if !sourceTestMessage.isEmpty {
                                    Text(sourceTestMessage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                if !speedTestMessage.isEmpty {
                                    Text(speedTestMessage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            if let sourceTestResponse {
                                SourceTestResultsView(response: sourceTestResponse)
                            }
                            if let speedTestResponse {
                                SpeedTestResultsView(response: speedTestResponse)
                            }
                        }
                    }
                }

                SettingsRow(title: "Proxy", systemImage: "network") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            PaninoTextInput("http://127.0.0.1:7890", text: $launcherSettings.proxyAddress)
                            if viewModel.coreState.isReady {
                                GlassButton(systemImage: "arrow.clockwise", title: "Restart Core") {
                                    restartCore()
                                }
                            }
                        }
                        CapabilityNote(
                            capability: viewModel.coreState.isReady ? .requiresCoreRestart : .available,
                            detail: viewModel.coreState.isReady
                                ? localizedString(
                                    theme.language,
                                    english: "Proxy is injected when Core starts and applies to Core downloads only. Microsoft sign-in follows the system browser/auth flow.",
                                    chinese: "代理会在 Core 启动时注入，仅影响 Core 下载。Microsoft 登录仍使用系统浏览器/认证流程。",
                                    italian: "Il proxy viene iniettato all'avvio di Core. Riavvia Core per applicarlo ai download.",
                                    french: "Le proxy est injecté au démarrage de Core. Redémarrez Core pour l'appliquer aux téléchargements.",
                                    spanish: "El proxy se inyecta al iniciar Core. Reinicia Core para aplicarlo a las descargas."
                                )
                                : nil
                        )
                    }
                }

                if launcherSettings.advancedModeEnabled {
                    SettingsRow(title: "Max Global Workers", systemImage: "number") {
                        VStack(alignment: .leading, spacing: 6) {
                            Stepper(value: $launcherSettings.downloadConcurrency, in: LauncherSettings.downloadConcurrencyRange) {
                                Text("\(launcherSettings.downloadConcurrency)")
                                    .monospacedDigit()
                            }
                            CapabilityNote(
                                capability: .available,
                                detail: "Strategy treats this as a ceiling; Core still adjusts active workers from resource limits and host telemetry."
                            )
                        }
                    }

                    SettingsRow(title: "Retries", systemImage: "arrow.clockwise") {
                        VStack(alignment: .leading, spacing: 6) {
                            Stepper(value: $launcherSettings.downloadRetryCount, in: LauncherSettings.downloadRetryCountRange) {
                                Text("\(launcherSettings.downloadRetryCount)")
                                    .monospacedDigit()
                            }
                            CapabilityNote(capability: .available)
                        }
                    }

                    SettingsRow(title: "Engine Limits", systemImage: "slider.horizontal.3") {
                        DownloadEngineLimitsView(strategy: launcherSettings.downloadStrategy, maxWorkers: launcherSettings.downloadConcurrency)
                    }
                }

                SettingsRow(title: "CurseForge API", systemImage: "key") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localizedString(theme.language, english: "Optional advanced channel. Release builds do not include a shared API key; personal keys stay only in local Keychain.", chinese: "可选高级渠道。发布版不会内置共享 API Key；个人 Key 只保存在本机钥匙串。", italian: "Canale avanzato opzionale. Le build pubbliche non includono una chiave condivisa.", french: "Canal avancé optionnel. Les versions publiques n'intègrent pas de clé partagée.", spanish: "Canal avanzado opcional. Las versiones públicas no incluyen una clave compartida."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            PaninoTextInput(
                                onlineContentStore.hasCurseForgeAPIKey() ? "Stored in Keychain" : "Optional personal CurseForge API Key",
                                text: $curseForgeAPIKey,
                                isSecure: true
                            )
                            GlassButton(systemImage: "checkmark.circle", title: AppText.apply.localized(theme.language), prominent: true) {
                                onlineContentStore.saveCurseForgeAPIKey(curseForgeAPIKey)
                                curseForgeAPIKey = ""
                            }
                            GlassButton(systemImage: "trash", title: AppText.clear.localized(theme.language)) {
                                onlineContentStore.saveCurseForgeAPIKey("")
                                curseForgeAPIKey = ""
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 8)], spacing: 8) {
                        ForEach(launcherSettings.cacheSummaries) { summary in
                            CacheSummaryTile(summary: summary)
                        }
                    }
                    HStack(spacing: 8) {
                        GlassButton(systemImage: "arrow.clockwise", title: "Refresh Cache") {
                            launcherSettings.refreshCacheSummaries()
                        }
                        GlassButton(systemImage: "trash", title: "Clear Staging") {
                            launcherSettings.clearCacheScopes([.downloadStaging], taskCenterStore: taskCenterStore)
                        }
                        GlassButton(systemImage: "trash", title: "Clear Metadata") {
                            launcherSettings.clearCacheScopes([.metadataHttp, .verificationIndex, .urlCache], taskCenterStore: taskCenterStore)
                        }
                        GlassButton(systemImage: "trash", title: "Clear All") {
                            launcherSettings.clearCacheScopes(Set(CacheScope.allCases), taskCenterStore: taskCenterStore)
                        }
                        GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language)) {
                            FinderIntegration.openDownloadCache()
                        }
                    }
                    Text(launcherSettings.cacheStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
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

    private var globalMemoryBinding: Binding<Int> {
        Binding(
            get: { viewModel.memoryMb },
            set: { newValue in
                launcherSettings.memoryPolicy = .custom
                viewModel.memoryMb = newValue
            }
        )
    }

    private var globalJvmArgumentsBinding: Binding<String> {
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

    private func restoreGlobalAutomaticTuning() {
        launcherSettings.memoryPolicy = .auto
        launcherSettings.jvmProfile = .auto
        launcherSettings.jvmArguments = ""
    }

    private func restoreGlobalAutomaticGraphicsTuning() {
        launcherSettings.graphicsProfile = .balanced
        graphicsManualOverrides = [:]
        graphicsTuningStatus = localizedString(theme.language, english: "Automatic graphics recommendation restored.", chinese: "已恢复自动画面推荐。", italian: "Grafica automatica ripristinata.", french: "Recommandation graphique restaurée.", spanish: "Recomendación gráfica restaurada.")
    }

    private func applyGlobalGraphicsTuning() {
        graphicsTuningRunning = true
        graphicsTuningStatus = localizedString(theme.language, english: "Applying graphics recommendation...", chinese: "正在应用推荐画面设置...", italian: "Applicazione grafica consigliata...", french: "Application des graphismes recommandés...", spanish: "Aplicando gráficos recomendados...")
        Task {
            do {
                let response = try await viewModel.applyGraphicsTuning(globalGraphicsTuningRequest(dryRun: false))
                await MainActor.run {
                    graphicsTuningStatus = response.tuning.summary + " " + localizedString(theme.language, english: "Relaunch Minecraft to use these settings.", chinese: "重新启动 Minecraft 后生效。", italian: "Riavvia Minecraft per usare queste impostazioni.", french: "Relancez Minecraft pour utiliser ces réglages.", spanish: "Reinicia Minecraft para usar estos ajustes.")
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

    private func rollbackGlobalGraphicsTuning() {
        graphicsTuningRunning = true
        graphicsTuningStatus = localizedString(theme.language, english: "Restoring previous graphics settings...", chinese: "正在恢复之前的画面设置...", italian: "Ripristino grafica precedente...", french: "Restauration des anciens graphismes...", spanish: "Restaurando gráficos anteriores...")
        Task {
            do {
                _ = try await viewModel.rollbackGraphicsTuning(
                    CoreGraphicsTuningRollbackRequest(
                        gameDir: launcherSettings.defaultGameDirectory,
                        backupPath: diagnosticsStore.lastEnvironmentReport?.graphicsTuning?.backupPath
                    )
                )
                await MainActor.run {
                    graphicsTuningStatus = localizedString(theme.language, english: "Previous graphics settings restored.", chinese: "已恢复之前的画面设置。", italian: "Grafica precedente ripristinata.", french: "Anciens graphismes restaurés.", spanish: "Gráficos anteriores restaurados.")
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

    private func globalGraphicsTuningRequest(dryRun: Bool) -> CoreGraphicsTuningRequest {
        CoreGraphicsTuningRequest(
            gameDir: launcherSettings.defaultGameDirectory,
            minecraftVersion: viewModel.version,
            loader: nil,
            requestedProfile: launcherSettings.graphicsProfile.rawValue,
            manualOverrides: graphicsManualOverrides,
            dryRun: dryRun
        )
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

private struct SettingsSectionButton: View {
    let section: PaninoSettingsSection
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            Text(section.title(language: theme.language))
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 38)
                .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
                .fill(isSelected ? theme.semanticSelectionColor : Color.clear)
        }
    }
}

private struct SourceTestResultsView: View {
    let response: CoreNetworkSourceTestResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(response.results) { result in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(result.endpoint)
                            .font(.caption.weight(.semibold))
                        Text(result.statusText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(result.ok ? .green : .orange)
                        Spacer(minLength: 0)
                    }
                    Text(result.selectedUrl ?? result.url)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let error = result.error, !result.ok {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct SpeedTestResultsView: View {
    let response: CoreNetworkSpeedTestResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Recommended Strategy")
                    .font(.caption.weight(.semibold))
                Text(recommendedStrategy.title)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            if let fastest = response.fastestResult {
                HStack(spacing: 8) {
                    Text("Fastest")
                        .font(.caption.weight(.semibold))
                    Text("\(fastest.endpoint) · \(formattedBytes(fastest.bytesPerSecond))/s")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                    Spacer(minLength: 0)
                }
            }

            ForEach(response.results) { result in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(result.endpoint)
                            .font(.caption.weight(.semibold))
                        Text(result.statusText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(result.ok ? .green : .orange)
                        Spacer(minLength: 0)
                        Text(result.usedProxy ? "proxy" : "direct")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(result.candidateUrl)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let error = result.error, !result.ok {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var recommendedStrategy: DownloadStrategy {
        guard let fastest = response.fastestResult else { return .conservative }
        if fastest.bytesPerSecond >= 20 * 1024 * 1024 && fastest.rangeSupported {
            return .fast
        }
        if fastest.bytesPerSecond < 3 * 1024 * 1024 || !fastest.rangeSupported {
            return .conservative
        }
        return .auto
    }
}

private struct DownloadEngineLimitsView: View {
    let strategy: DownloadStrategy
    let maxWorkers: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
            EngineLimitTile(title: "Global", value: "\(effectiveMaxWorkers)")
            EngineLimitTile(title: "Per-host", value: perHostText)
            EngineLimitTile(title: "Multipart", value: multipartText)
            EngineLimitTile(title: "Segment", value: "8-16 MB")
        }
    }

    private var effectiveMaxWorkers: Int {
        switch strategy {
        case .auto:
            return maxWorkers
        case .fast:
            return max(maxWorkers, 48)
        case .conservative:
            return min(maxWorkers, 12)
        }
    }

    private var perHostText: String {
        switch strategy {
        case .auto:
            return "AIMD"
        case .fast:
            return "AIMD+"
        case .conservative:
            return "Capped"
        }
    }

    private var multipartText: String {
        switch strategy {
        case .auto:
            return "32 MB+"
        case .fast:
            return "32 MB+"
        case .conservative:
            return "Range only"
        }
    }
}

private struct EngineLimitTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CacheSummaryTile: View {
    let summary: CacheScopeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(summary.sizeText)
                .font(.callout.weight(.semibold).monospacedDigit())
            Text(summary.path)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private enum SettingCapability {
    case available
    case requiresCoreRestart
    case advancedOnly
    case notImplemented
}

private struct CapabilityNote: View {
    let capability: SettingCapability
    var detail: String? = nil

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        if let message = displayMessage, !message.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                if capability != .available {
                    Circle()
                        .fill(indicatorColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                }
                Text(message)
                    .font(.caption)
                    .foregroundStyle(capability == .available ? .secondary : indicatorColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var displayMessage: String? {
        switch capability {
        case .available:
            return detail
        case .requiresCoreRestart:
            let restart = localizedString(
                theme.language,
                english: "Restart Core to apply this change.",
                chinese: "重启 Core 后生效。",
                italian: "Riavvia Core per applicare la modifica.",
                french: "Redémarrez Core pour appliquer ce changement.",
                spanish: "Reinicia Core para aplicar este cambio."
            )
            if let detail, !detail.isEmpty {
                return "\(restart) \(detail)"
            }
            return restart
        case .advancedOnly:
            return detail ?? localizedString(
                theme.language,
                english: "Visible when advanced controls are enabled.",
                chinese: "启用高级控制后显示。",
                italian: "Visibile quando i controlli avanzati sono attivi.",
                french: "Visible lorsque les contrôles avancés sont activés.",
                spanish: "Visible cuando los controles avanzados están activos."
            )
        case .notImplemented:
            return detail
        }
    }

    private var indicatorColor: Color {
        switch capability {
        case .available:
            return .secondary
        case .requiresCoreRestart:
            return .orange
        case .advancedOnly:
            return .blue
        case .notImplemented:
            return .secondary
        }
    }
}
