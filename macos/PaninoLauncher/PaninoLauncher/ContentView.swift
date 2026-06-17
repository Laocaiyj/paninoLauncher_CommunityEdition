import AppKit
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

private struct TopNavigationBar: View {
    @Binding var selection: LauncherSection?
    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding = PaninoTokens.Layout.pagePadding(for: proxy.size.width)
            let tokens = theme.resolvedTokens(
                reduceTransparency: reduceTransparency,
                increasedContrast: colorSchemeContrast == .increased,
                reduceMotion: reduceMotion
            )
            let navigationCornerRadius = navigationContainerCornerRadius(tokens: tokens)

            HStack(spacing: 18) {
                HStack(spacing: 10) {
                    PaninoBrandMark(size: 32, cornerRadius: PaninoTokens.Radius.control)

                    if proxy.size.width >= 720 {
                        Text("Panino")
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 4) {
                    ForEach(LauncherSection.primaryCases) { section in
                        TopNavigationItem(
                            title: section.title(language: theme.language),
                            isSelected: (selection ?? .launch).primaryParent == section,
                            tokens: tokens,
                            chromeStyle: theme.chromeStyle
                        ) {
                            selection = section
                        }
                    }
                }
                .padding(theme.chromeStyle == .integrated ? 2 : 4)
                .background {
                    navigationContainerBackground(tokens: tokens, cornerRadius: navigationCornerRadius)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: navigationCornerRadius, style: .continuous)
                        .stroke(tokens.strokeColor.opacity(navigationStrokeOpacity(tokens: tokens)), lineWidth: tokens.strokeWidth)
                }
                .shadow(
                    color: Color.black.opacity(navigationShadowOpacity(tokens: tokens)),
                    radius: navigationShadowRadius(tokens: tokens),
                    x: 0,
                    y: navigationShadowYOffset(tokens: tokens)
                )

                Spacer(minLength: 16)
            }
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.topNavigationHeight, maxHeight: PaninoTokens.Layout.topNavigationHeight)
        }
        .frame(height: PaninoTokens.Layout.topNavigationHeight)
        .background {
            if theme.chromeStyle == .floatingToolbar {
                Color.clear
            } else if reduceTransparency {
                Color(nsColor: .windowBackgroundColor).opacity(0.96)
            } else {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(theme.chromeStyle == .edgeToEdgeSidebar ? .regularMaterial : .thinMaterial)
                        .overlay(theme.semanticSelectionColor.opacity(theme.chromeStyle == .edgeToEdgeSidebar ? 0.055 : 0.018))

                    if theme.chromeStyle == .edgeToEdgeSidebar {
                        Rectangle()
                            .fill(theme.semanticSelectionColor.opacity(0.12))
                            .frame(width: 184)
                    }
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.36))
                        .frame(height: 1)
                }
            }
        }
    }

    private func navigationContainerCornerRadius(tokens: ResolvedThemeTokens) -> CGFloat {
        switch theme.chromeStyle {
        case .integrated:
            return min(tokens.navigationCornerRadius, 14)
        case .floatingToolbar:
            return tokens.navigationCornerRadius
        case .edgeToEdgeSidebar:
            return min(tokens.navigationCornerRadius, 12)
        }
    }

    private func navigationStrokeOpacity(tokens: ResolvedThemeTokens) -> Double {
        switch theme.chromeStyle {
        case .integrated:
            return 0
        case .floatingToolbar:
            return tokens.strokeOpacity * 0.78
        case .edgeToEdgeSidebar:
            return tokens.strokeOpacity * 0.46
        }
    }

    private func navigationShadowOpacity(tokens: ResolvedThemeTokens) -> Double {
        switch theme.chromeStyle {
        case .integrated:
            return 0
        case .floatingToolbar:
            return tokens.shadowOpacity
        case .edgeToEdgeSidebar:
            return tokens.shadowOpacity * 0.35
        }
    }

    private func navigationShadowRadius(tokens: ResolvedThemeTokens) -> CGFloat {
        theme.chromeStyle == .floatingToolbar ? tokens.shadowRadius * 0.65 : tokens.shadowRadius * 0.25
    }

    private func navigationShadowYOffset(tokens: ResolvedThemeTokens) -> CGFloat {
        theme.chromeStyle == .floatingToolbar ? tokens.shadowYOffset * 0.5 : tokens.shadowYOffset * 0.2
    }

    @ViewBuilder
    private func navigationContainerBackground(tokens: ResolvedThemeTokens, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch theme.chromeStyle {
        case .integrated:
            shape.fill(Color.clear)
        case .floatingToolbar:
            shape
                .fill(Color.clear)
                .paninoGlassSurface(tokens: tokens, cornerRadius: cornerRadius, interactive: true, tintOpacity: 0.04)
                .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.58))
                .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.20))
                .clipShape(shape)
        case .edgeToEdgeSidebar:
            shape
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.20))
                .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.28))
                .clipShape(shape)
        }
    }
}

private struct PaninoBrandMark: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image = PaninoBrandAsset.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: size * 0.58, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

private enum PaninoBrandAsset {
    static let image: NSImage? = loadImage()

    private static func loadImage() -> NSImage? {
        if let image = NSImage(named: "PaninoAppIcon") {
            return image
        }

        for bundle in resourceBundles {
            if let url = bundle.url(
                forResource: "panino-app-icon",
                withExtension: "png",
                subdirectory: "Assets.xcassets/PaninoAppIcon.imageset"
            ),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }

    private static var resourceBundles: [Bundle] {
        #if SWIFT_PACKAGE
        [Bundle.module, Bundle.main]
        #else
        [Bundle.main]
        #endif
    }
}

private struct TopNavigationItem: View {
    let title: String
    let isSelected: Bool
    let tokens: ResolvedThemeTokens
    let chromeStyle: ThemeChromeStyle
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minWidth: 144, minHeight: PaninoTokens.Layout.controlMinSize)
                .contentShape(RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            let shape = RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
            if isSelected {
                shape
                    .fill(tokens.selectionColor)
            } else {
                shape.fill(Color.clear)
            }
        }
        .shadow(
            color: tokens.selectionColor.opacity(isSelected && chromeStyle == .floatingToolbar ? 0.22 : 0),
            radius: isSelected && chromeStyle == .floatingToolbar ? 8 : 0,
            x: 0,
            y: isSelected && chromeStyle == .floatingToolbar ? 2 : 0
        )
        .accessibilityLabel(title)
        .help(title)
    }
}

private struct LauncherDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.45))
            .frame(width: 1)
            .ignoresSafeArea(edges: .vertical)
    }
}

private struct LauncherHorizontalDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.45))
            .frame(height: 1)
    }
}

private enum LauncherSection: String, CaseIterable, Identifiable, Hashable {
    case launch
    case instances
    case discover
    case resources
    case versions
    case account
    case downloads
    case logs
    case diagnostics
    case settings

    var id: String { rawValue }

    static var primaryCases: [LauncherSection] {
        [.launch, .instances, .discover, .diagnostics]
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .launch:
            return AppText.launch.localized(language)
        case .instances:
            return AppText.instances.localized(language)
        case .discover:
            return localizedString(language, english: "Get", chinese: "获取", italian: "Ottieni", french: "Obtenir", spanish: "Obtener")
        case .resources:
            return localizedString(language, english: "Resources", chinese: "资源", italian: "Risorse", french: "Ressources", spanish: "Recursos")
        case .versions:
            return AppText.versions.localized(language)
        case .account:
            return AppText.account.localized(language)
        case .downloads:
            return AppText.tasks.localized(language)
        case .logs:
            return AppText.logs.localized(language)
        case .diagnostics:
            return localizedString(language, english: "Tasks", chinese: "任务", italian: "Attività", french: "Tâches", spanish: "Tareas")
        case .settings:
            return AppText.settings.localized(language)
        }
    }

    var primaryParent: LauncherSection {
        switch self {
        case .discover:
            return .discover
        case .instances, .resources, .versions:
            return .instances
        case .downloads, .logs, .diagnostics:
            return .diagnostics
        case .launch, .account, .settings:
            return .launch
        }
    }

    var systemImage: String {
        switch self {
        case .launch:
            return "play.square.stack"
        case .instances:
            return "square.stack.3d.up.fill"
        case .discover:
            return "arrow.down.app"
        case .resources:
            return "folder.badge.gearshape"
        case .versions:
            return "puzzlepiece.extension"
        case .account:
            return "person.crop.circle"
        case .downloads:
            return "arrow.down.circle"
        case .logs:
            return "terminal"
        case .diagnostics:
            return "checklist"
        case .settings:
            return "gearshape"
        }
    }
}

private struct SidebarView: View {
    @Binding var selection: LauncherSection?
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                PaninoBrandMark(size: 28, cornerRadius: 8)

                Text("Panino")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.top, 56)
            .padding(.horizontal, 14)

            VStack(spacing: 4) {
                ForEach(LauncherSection.primaryCases) { section in
                    SidebarItem(
                        title: section.title(language: theme.language),
                        isSelected: selection == section
                    ) {
                        selection = section
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
    }
}

private struct SidebarItem: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.callout.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
                .fill(isSelected ? theme.semanticSelectionColor : Color.clear)
        }
        .accessibilityLabel(title)
        .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
    }
}

private struct MainContentView: View {
    let section: LauncherSection
    @Binding var sectionSelection: LauncherSection?
    @ObservedObject var viewModel: LauncherViewModel
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var appActions: AppActionCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = PaninoTokens.Layout.contentWidth(for: proxy.size.width)
            let pagePadding = PaninoTokens.Layout.pagePadding(for: proxy.size.width)

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                        switch section {
                        case .launch:
                            LaunchDashboard(
                                viewModel: viewModel,
                                openInstances: { sectionSelection = .instances },
                                openAccount: { openSettingsWindow(.account) },
                                openResources: { sectionSelection = .instances },
                                openDiscover: { sectionSelection = .discover },
                                openTasks: { sectionSelection = .diagnostics },
                                openLogs: { sectionSelection = .diagnostics },
                                openSettings: { openSettingsWindow() }
                            )
                        case .instances:
                            InstancesPage(
                                viewModel: viewModel,
                                openResources: { sectionSelection = .instances },
                                openDiscover: { sectionSelection = .discover }
                            )
                        case .discover:
                            OnlineContentDiscoveryPage(
                                viewModel: viewModel,
                                openSettings: { openSettingsWindow() },
                                openDownloadSettings: { openSettingsWindow(.download) },
                                openTasks: { sectionSelection = .diagnostics }
                            )
                        case .resources:
                            InstancesPage(
                                viewModel: viewModel,
                                openResources: { sectionSelection = .instances },
                                openDiscover: { sectionSelection = .discover }
                            )
                        case .versions:
                            VersionsAndModsPage(viewModel: viewModel)
                        case .account:
                            SettingsCenterPage(viewModel: viewModel)
                        case .downloads:
                            ActivityPage(viewModel: viewModel)
                        case .logs:
                            ActivityPage(viewModel: viewModel)
                        case .diagnostics:
                            ActivityPage(viewModel: viewModel)
                        case .settings:
                            SettingsCenterPage(viewModel: viewModel)
                        }
                    }
                    .id(section)
                    .transition(.opacity)
                    .animation(PaninoMotion.noneWhenReduced(PaninoMotion.page, reduceMotion: reduceMotion || theme.reducesInterfaceMotion), value: section)
                    .padding(.horizontal, pagePadding)
                    .padding(.top, PaninoTokens.Layout.pageTopSpacing)
                    .padding(.bottom, 24)
                    .frame(maxWidth: contentWidth, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .scrollContentBackground(.hidden)

                BottomStatusBar(viewModel: viewModel) {
                    sectionSelection = .diagnostics
                }
            }
        }
    }

    private func openSettingsWindow(_ section: PaninoSettingsSection? = nil) {
        if let section {
            appActions.focusSettings(section)
        }
        openWindow(id: PaninoWindowID.settings)
    }
}
