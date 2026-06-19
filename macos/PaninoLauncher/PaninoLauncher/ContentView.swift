import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var taskCenterStore: TaskCenterStore
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @EnvironmentObject private var performanceCoachStore: PerformanceCoachStore
    @EnvironmentObject private var packDoctorStore: PackDoctorStore
    @EnvironmentObject private var appActions: AppActionCenter
    @State private var notifiedTaskIDs: Set<String> = []
    @State private var notifiedExpiredAccountIDs: Set<String> = []
    @State private var selectedSection: LauncherSection? = .launch

    var body: some View {
        ZStack {
            LauncherBackground(
                version: viewModel.version,
                isImmersiveEnabled: (selectedSection ?? .launch) == .launch
            )

            VStack(spacing: 0) {
                TopNavigationBar(selection: $selectedSection)

                LauncherHorizontalDivider()

                MainContentView(
                    section: selectedSection ?? .launch,
                    sectionSelection: $selectedSection,
                    viewModel: viewModel
                )
                    .frame(minWidth: PaninoTokens.Window.minimumMainWidth, maxWidth: .infinity)
            }
        }
        .tint(theme.semanticSelectionColor)
        .controlSize(theme.fontDensity.controlSize)
        .preferredColorScheme(theme.appearance.colorScheme)
        .dynamicTypeSize(.xSmall ... .accessibility3)
        .frame(minWidth: PaninoTokens.Window.minimumWidth, minHeight: PaninoTokens.Window.minimumHeight)
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            DroppedContentImporter.importItems(
                providers,
                selectedKind: versionStore.selectedAssetKind,
                instance: instanceStore.selectedInstance,
                taskStore: taskCenterStore,
                versionStore: versionStore
            )
        }
        .onAppear {
            NativeMenuLocalizer.apply(language: theme.language)
        }
        .task {
            UserNotificationService.shared.requestAuthorization()
            if launcherSettings.autoConnectCore {
                Task {
                    await viewModel.startCoreIfNeeded()
                }
            }
            Task {
                viewModel.checkJavaRuntime()
            }
            Task {
                await viewModel.restoreAccountIfPossible(accountID: accountStore.defaultAccountID.isEmpty ? nil : accountStore.defaultAccountID)
            }
        }
        .onDisappear {
            Task {
                await viewModel.shutdownCore()
            }
        }
        .onChange(of: theme.language) {
            NativeMenuLocalizer.apply(language: theme.language)
        }
        .onChange(of: appActions.commandSequence) {
            handleNativeCommand(appActions.lastCommand)
        }
        .onChange(of: viewModel.accountState) {
            if let account = viewModel.accountState.account {
                accountStore.upsert(account: account)
                notifyExpiredAccountIfNeeded(account)
            }
        }
        .onChange(of: viewModel.currentTask) {
            taskCenterStore.sync(snapshot: viewModel.currentTask)
            refreshManagedContentAfterTask(viewModel.currentTask)
            notifyTaskIfNeeded(viewModel.currentTask)
        }
        .onChange(of: viewModel.currentTaskProgress) {
            taskCenterStore.apply(progress: viewModel.currentTaskProgress)
        }
        .onChange(of: viewModel.latestCoreEvent) {
            taskCenterStore.applyTaowa(event: viewModel.latestCoreEvent)
        }
        .onChange(of: versionStore.installedInstances) {
            instanceStore.reconcileInstalledInstances(versionStore.installedInstances, settings: launcherSettings)
        }
        .onChange(of: viewModel.coreState) {
            if viewModel.coreState.isReady, let endpoint = viewModel.apiClient?.endpoint {
                performanceCoachStore.configure(endpoint: endpoint)
                packDoctorStore.configure(endpoint: endpoint)
            }
            if case .failed = viewModel.coreState {
                taskCenterStore.markInterrupted(activeTask: viewModel.currentTask)
            }
        }
    }

    private func handleNativeCommand(_ command: NativeAppCommand?) {
        guard let command else { return }

        switch command {
        case .launchDefault:
            selectedSection = .launch
            if let selectedID = instanceStore.selectedInstanceID {
                instanceStore.selectedInstanceID = selectedID
            }
            viewModel.launch(accountID: defaultAccountID, gameDir: instanceStore.selectedInstance?.gameDirectory, instance: instanceStore.selectedInstance)
        case .openLaunch:
            selectedSection = .launch
        case .openRecent:
            selectedSection = .instances
            if let recent = instanceStore.instances.max(by: {
                ($0.lastLaunchedAt ?? .distantPast) < ($1.lastLaunchedAt ?? .distantPast)
            }) {
                instanceStore.selectedInstanceID = recent.id
            }
        case .openSettings:
            openWindow(id: PaninoWindowID.settings)
        case .openLogs:
            selectedSection = .diagnostics
        case .retryTask:
            selectedSection = .diagnostics
            retrySelectedTask()
        case .checkForUpdates:
            appActions.statusMessage = localizedString(
                theme.language,
                english: "No update channel is configured for this development build.",
                chinese: "此开发构建尚未配置更新通道。",
                italian: "Nessun canale di aggiornamento configurato per questa build.",
                french: "Aucun canal de mise à jour n'est configuré pour cette version.",
                spanish: "No hay canal de actualización configurado para esta build."
            )
            UserNotificationService.shared.notifyOnce(
                identifier: "panino-update-check-\(Date().timeIntervalSince1970)",
                title: "Panino Launcher",
                body: appActions.statusMessage
            )
        case .openInstances:
            selectedSection = .instances
        case .openResources:
            selectedSection = .resources
        case .openVersions:
            selectedSection = .versions
        case .openDiscover:
            selectedSection = .discover
        case .openActivity:
            selectedSection = .diagnostics
        case .openAccountSettings:
            appActions.focusSettings(.account)
            openWindow(id: PaninoWindowID.settings)
        case .startCore:
            Task { await viewModel.startCoreIfNeeded() }
        case .stopCore:
            Task { await viewModel.shutdownCore() }
        case .checkJava:
            viewModel.checkJavaRuntime()
        case .scanJava:
            viewModel.scanJavaRuntimes()
        case .signIn:
            viewModel.signInWithMicrosoft()
        case .signOut:
            if let account = viewModel.accountState.account {
                viewModel.signOut(accountID: account.id)
                accountStore.markSignedOut(accountID: account.id)
            }
        case .openInstanceDirectory:
            FinderIntegration.openInstanceDirectory(instanceStore.selectedInstance)
        case .openDownloadCache:
            FinderIntegration.openDownloadCache()
        case .clearDownloadCache:
            launcherSettings.clearDownloadCache()
            taskCenterStore.enqueueLocal(
                kind: "download",
                name: localizedString(theme.language, english: "Clear Download Cache", chinese: "清理下载缓存", italian: "Pulisci cache download", french: "Vider cache téléchargements", spanish: "Limpiar caché de descargas"),
                message: launcherSettings.cacheStatus
            )
        case .openLogsDirectory:
            FinderIntegration.openLogsDirectory()
        case .exportDiagnostics:
            diagnosticsStore.exportDiagnosticPackage(
                logs: viewModel.logs,
                tasks: taskCenterStore.records,
                coreState: viewModel.coreState,
                javaStatus: viewModel.javaStatus,
                managedJavaRuntimes: viewModel.managedJavaRuntimes,
                javaRuntimeResolution: viewModel.javaRuntimeResolution
            )
            taskCenterStore.enqueueLocal(
                kind: "log-export",
                name: localizedString(theme.language, english: "Diagnostic Package", chinese: "诊断包", italian: "Pacchetto diagnostico", french: "Paquet diagnostic", spanish: "Paquete de diagnóstico"),
                message: diagnosticsStore.exportStatus
            )
        case .copyDiagnosticSummary:
            diagnosticsStore.copyDiagnosticSummary(
                logs: viewModel.logs,
                tasks: taskCenterStore.records,
                coreState: viewModel.coreState,
                javaStatus: viewModel.javaStatus
            )
            appActions.statusMessage = diagnosticsStore.copyStatus
        case .duplicateInstance:
            instanceStore.duplicateSelected()
            selectedSection = .instances
        case .createInstance:
            selectedSection = .instances
            appActions.statusMessage = localizedString(
                theme.language,
                english: "Direct game configuration creation is disabled. Install Minecraft from Get; installed local instances appear automatically.",
                chinese: "已取消直接新建游戏配置。请从“获取”页安装 Minecraft；本地实例会在安装完成后自动出现。",
                italian: "La creazione diretta è disabilitata. Installa Minecraft da Ottieni.",
                french: "La création directe est désactivée. Installez Minecraft depuis Obtenir.",
                spanish: "La creación directa está desactivada. Instala Minecraft desde Obtener."
            )
        case .deleteInstance:
            selectedSection = .instances
            appActions.statusMessage = localizedString(
                theme.language,
                english: "Delete the selected local instance from Local Instances after confirmation.",
                chinese: "请在“本地实例”页确认后删除当前本地实例。",
                italian: "Elimina l'istanza locale dalla pagina Istanze locali dopo conferma.",
                french: "Supprimez l'instance locale depuis Instances locales après confirmation.",
                spanish: "Elimina la instancia local desde Instancias locales tras confirmar."
            )
        }
    }

    private func retrySelectedTask() {
        let selected = taskCenterStore.selectedRecord.flatMap {
            taskCenterStore.isActionableAttention($0) ? $0 : nil
        }
        guard let record = selected ?? taskCenterStore.attentionRecords.first else {
            return
        }

        switch record.kind.lowercased() {
        case let kind where kind.contains("launch"):
            viewModel.launch(
                version: record.version,
                accountID: defaultAccountID,
                gameDir: record.gameDir ?? instanceStore.selectedInstance?.gameDirectory,
                instance: instanceStore.selectedInstance,
                restartActiveTask: record.state.isActive
            )
        case let kind where kind.contains("log"):
            viewModel.exportLogs()
        case let kind where kind.contains("content"):
            appActions.statusMessage = localizedString(
                theme.language,
                english: "Reinstall content from its project page; the task history does not contain the original release payload.",
                chinese: "请从项目页面重新安装内容；任务历史不包含原始发布包参数。",
                italian: "Reinstalla il contenuto dalla pagina progetto; la cronologia non contiene il payload originale.",
                french: "Réinstallez le contenu depuis sa page projet ; l'historique ne contient pas la charge d'origine.",
                spanish: "Reinstala el contenido desde su página; el historial no contiene la carga original."
            )
        case let kind where kind.contains("install") || kind.contains("download"):
            viewModel.install(
                version: record.version,
                gameDir: record.gameDir ?? instanceStore.selectedInstance?.gameDirectory,
                restartActiveTask: record.state.isActive
            )
        default:
            appActions.statusMessage = localizedString(
                theme.language,
                english: "This task type cannot be retried automatically.",
                chinese: "此任务类型无法自动重试。",
                italian: "Questo tipo di attività non può essere ritentato automaticamente.",
                french: "Ce type de tâche ne peut pas être relancé automatiquement.",
                spanish: "Este tipo de tarea no puede reintentarse automáticamente."
            )
        }
    }

    private func notifyTaskIfNeeded(_ task: TaskSnapshot?) {
        guard let task, task.state.isTerminal, notifiedTaskIDs.insert(task.taskId).inserted else { return }
        let kind = task.kind.lowercased()

        if task.state == .succeeded, kind.contains("install") {
            UserNotificationService.shared.notifyOnce(
                identifier: "task-installed-\(task.taskId)",
                title: localizedString(theme.language, english: "Install Complete", chinese: "安装完成", italian: "Installazione completata", french: "Installation terminée", spanish: "Instalación completa"),
                body: "\(task.version) \(task.message ?? "")"
            )
        } else if task.state == .failed, kind.contains("launch") {
            UserNotificationService.shared.notifyOnce(
                identifier: "task-launch-failed-\(task.taskId)",
                title: localizedString(theme.language, english: "Launch Failed", chinese: "启动失败", italian: "Avvio fallito", french: "Échec du lancement", spanish: "Inicio fallido"),
                body: task.diagnostic?.userSummary ?? task.message ?? task.errorCode ?? task.version
            )
        } else if task.state == .failed, kind.contains("download") || kind.contains("install") {
            UserNotificationService.shared.notifyOnce(
                identifier: "task-download-failed-\(task.taskId)",
                title: kind.contains("install")
                    ? localizedString(theme.language, english: "Install Failed", chinese: "安装失败", italian: "Installazione fallita", french: "Installation échouée", spanish: "Instalación fallida")
                    : localizedString(theme.language, english: "Download Failed", chinese: "下载失败", italian: "Download fallito", french: "Échec du téléchargement", spanish: "Descarga fallida"),
                body: task.diagnostic?.userSummary ?? task.message ?? task.errorCode ?? task.version
            )
        }
    }

    private func refreshManagedContentAfterTask(_ task: TaskSnapshot?) {
        guard let task else { return }
        if task.kind == "launch" {
            if task.state.isActive {
                instanceStore.markLaunchStarted(from: task)
            } else if task.state.isTerminal {
                instanceStore.markLaunchFinished(from: task)
            }
        }
        guard task.state == .succeeded else { return }
        if task.kind == "content-install" {
            if let gameDir = task.gameDir,
               let targetInstance = instanceStore.instances.first(where: { sameFilePath($0.gameDirectory, gameDir) }) {
                instanceStore.selectedInstanceID = targetInstance.id
            }
            versionStore.refreshAssets(for: instanceStore.selectedInstance)
        }
        if task.kind == "install" || task.kind == "launch" {
            configureVersionCoreBackend()
            versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
        }
    }

    private func sameFilePath(_ lhs: String, _ rhs: String) -> Bool {
        URL(fileURLWithPath: lhs).standardizedFileURL.path == URL(fileURLWithPath: rhs).standardizedFileURL.path
    }

    private func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: VersionContentCoreBackend(
                minecraftVersions: {
                    try await viewModel.minecraftVersions()
                },
                minecraftInstallStatus: { versionIds, gameDirs in
                    try await viewModel.minecraftInstallStatus(versionIds: versionIds, gameDirs: gameDirs)
                },
                installedMinecraftInstances: { versionIds, gameDirs in
                    try await viewModel.installedMinecraftInstances(versionIds: versionIds, gameDirs: gameDirs)
                },
                minecraftPackage: { version in
                    try await viewModel.minecraftPackage(for: version)
                },
                localResources: { gameDir, kind, loader in
                    try await viewModel.localResources(gameDir: gameDir, kind: kind, loader: loader)
                },
                toggleLocalResource: { path in
                    try await viewModel.toggleLocalResource(path: path)
                },
                deleteLocalResource: { path in
                    try await viewModel.deleteLocalResource(path: path)
                },
                importLocalResource: { sourcePath, gameDir, kind in
                    try await viewModel.importLocalResource(sourcePath: sourcePath, gameDir: gameDir, kind: kind)
                },
                cleanMinecraftVersion: { version, gameDir in
                    try await viewModel.cleanMinecraftVersion(version: version, gameDir: gameDir)
                },
                mutateMinecraftVersionStorage: { version, gameDir, action in
                    try await viewModel.mutateMinecraftVersionStorage(version: version, gameDir: gameDir, action: action)
                }
            )
        )
    }

    private func notifyExpiredAccountIfNeeded(_ account: MinecraftAccount) {
        guard account.isExpired, notifiedExpiredAccountIDs.insert(account.id).inserted else { return }
        UserNotificationService.shared.notifyOnce(
            identifier: "account-expired-\(account.id)",
            title: localizedString(theme.language, english: "Account Expired", chinese: "账号已过期", italian: "Account scaduto", french: "Compte expiré", spanish: "Cuenta expirada"),
            body: localizedString(theme.language, english: "Re-authenticate before launching.", chinese: "启动前请重新登录。", italian: "Riautentica prima di avviare.", french: "Réauthentifiez-vous avant de lancer.", spanish: "Reautentica antes de iniciar.")
        )
    }

    private var defaultAccountID: String? {
        accountStore.defaultAccountID.isEmpty ? nil : accountStore.defaultAccountID
    }

}
