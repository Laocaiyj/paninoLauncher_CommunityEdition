import AppKit
import SwiftUI

enum LaunchLibraryLimits {
    static let recentLaunchCount = 5
}

extension LaunchDashboard {
    var launchModuleColumns: [GridItem] {
        [
            GridItem(
                .adaptive(minimum: 320, maximum: 520),
                spacing: PaninoTokens.Layout.cardSpacing,
                alignment: .top
            )
        ]
    }

    var selectedInstance: GameInstance {
        instanceStore.selectedInstance ?? GameInstance(
            id: Self.fallbackInstanceID,
            name: "Default Game Configuration",
            iconName: "shippingbox.fill",
            coverPath: "",
            minecraftVersion: viewModel.version,
            gameDirectory: "",
            javaPath: viewModel.javaPath,
            memoryMb: viewModel.memoryMb,
            loader: nil,
            loaderVersion: nil,
            jvmArguments: "",
            preLaunchBehavior: "",
            group: "Default",
            isFavorite: false,
            lastLaunchedAt: nil,
            totalPlaySeconds: nil,
            status: .ready
        )
    }

    var launchAccountProfile: AccountProfile? {
        if let account = viewModel.accountState.account {
            return AccountProfile(
                id: account.id,
                name: account.name,
                avatarURL: URL(string: "https://crafatar.com/avatars/\(account.id)?overlay"),
                lastSignedInAt: Date(),
                expiresAt: account.expiresAt
            )
        }
        return accountStore.defaultAccount
    }

    var recentInstances: [GameInstance] {
        if let ids = launchLibrarySummary?.recentIds {
            return orderedInstances(for: ids).prefix(LaunchLibraryLimits.recentLaunchCount).map { $0 }
        }
        return instanceStore.instances
            .filter { $0.lastLaunchedAt != nil && !$0.isHiddenFromRecent }
            .sorted {
                return ($0.lastLaunchedAt ?? .distantPast) > ($1.lastLaunchedAt ?? .distantPast)
            }
            .prefix(LaunchLibraryLimits.recentLaunchCount)
            .map { $0 }
    }

    var favoriteInstances: [GameInstance] {
        if let ids = launchLibrarySummary?.favoriteIds {
            return orderedInstances(for: ids).prefix(6).map { $0 }
        }
        return instanceStore.instances
            .filter(\.isFavorite)
            .sorted {
                ($0.lastLaunchedAt ?? .distantPast) > ($1.lastLaunchedAt ?? .distantPast)
            }
            .prefix(6)
            .map { $0 }
    }

    var recentInstalledInstances: [GameInstance] {
        if let ids = launchLibrarySummary?.recentInstallIds, !ids.isEmpty {
            return orderedInstances(for: ids).prefix(6).map { $0 }
        }
        return instanceStore.instances
            .filter { !$0.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(6)
            .map { $0 }
    }

    var detailInstance: GameInstance? {
        guard let detailInstanceID else { return nil }
        return instanceStore.instances.first { $0.id == detailInstanceID }
    }

    var selectedLaunchSummary: CoreLaunchInstanceSummary? {
        summary(for: selectedInstance)
    }

    var selectedPerformanceSummary: CorePerformanceSummary? {
        guard let report = diagnosticsStore.lastEnvironmentReport,
              let summary = report.performanceSummary else {
            return nil
        }
        if let reportVersion = report.context?.minecraftVersion,
           reportVersion != selectedInstance.contentMinecraftVersion {
            return nil
        }
        if let reportGameDir = report.context?.gameDir,
           !selectedInstance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           reportGameDir != selectedInstance.gameDirectory {
            return nil
        }
        return summary
    }

    var packDoctorDiagnostics: [CoreDiagnostic] {
        guard let task = viewModel.currentTask, currentTaskApplies(to: selectedInstance) else {
            return packDoctorStore.report?.allDiagnostics ?? []
        }
        let taskDiagnostics = task.diagnostics.isEmpty ? task.diagnostic.map { [$0] } ?? [] : task.diagnostics
        return taskDiagnostics + (packDoctorStore.report?.allDiagnostics ?? [])
    }

    var launchLibraryRefreshSignature: String {
        instanceStore.instances
            .map { instance in
                [
                    instance.id.uuidString,
                    instance.name,
                    instance.minecraftVersion,
                    instance.loader?.rawValue ?? "vanilla",
                    instance.gameDirectory,
                    instance.status.rawValue,
                    instance.isFavorite ? "favorite" : "normal",
                    instance.isHiddenFromRecent ? "hidden" : "visible",
                    instance.lastLaunchedAt?.timeIntervalSince1970.description ?? "never",
                    instance.lastLaunchState?.rawValue ?? "none",
                    "\(instance.launchCount)"
                ].joined(separator: "|")
            }
            .joined(separator: ";")
    }

    var defaultAccountID: String? {
        accountStore.defaultAccountID.isEmpty ? nil : accountStore.defaultAccountID
    }

    var instanceStatus: StatusBadge.Style {
        if let task = viewModel.currentTask, currentTaskApplies(to: selectedInstance) {
            switch task.state {
            case .queued, .running:
                return .running
            case .succeeded:
                return .success
            case .failed:
                return .error
            case .cancelled:
                return .warning
            }
        }
        if let summary = selectedLaunchSummary {
            return statusStyle(for: selectedInstance, summary: summary)
        }
        return viewModel.coreState.isReady ? .success : .neutral
    }

    var launchStatusTitle: String {
        launchStatusTitle(for: selectedInstance)
    }

    func launchStatusTitle(for instance: GameInstance) -> String {
        if let task = viewModel.currentTask, currentTaskApplies(to: instance) {
            return task.state.localizedTitle(theme.language)
        }
        if let summary = summary(for: instance) {
            switch summary.status {
            case "ready":
                return localizedString(theme.language, english: "Ready", chinese: "可启动", italian: "Pronto", french: "Prêt", spanish: "Listo")
            case "needsInstall":
                return localizedString(theme.language, english: "Needs Install", chinese: "需要安装", italian: "Da installare", french: "À installer", spanish: "Falta instalar")
            case "missing":
                return localizedString(theme.language, english: "Missing Files", chinese: "缺少文件", italian: "File mancanti", french: "Fichiers manquants", spanish: "Faltan archivos")
            case "failed":
                return AppText.failed.localized(theme.language)
            case "running":
                return AppText.running.localized(theme.language)
            default:
                break
            }
        }
        return localizedString(theme.language, english: "Ready", chinese: "可启动", italian: "Pronto", french: "Prêt", spanish: "Listo")
    }

    var primaryActionTitle: String {
        primaryActionTitle(for: selectedInstance)
    }

    func primaryActionTitle(for instance: GameInstance) -> String {
        if viewModel.currentTask?.state.isActive == true, currentTaskApplies(to: instance) {
            return localizedString(theme.language, english: "Task Running", chinese: "任务运行中", italian: "Attività in corso", french: "Tâche en cours", spanish: "Tarea activa")
        }
        if needsInstallBeforeLaunch(instance) {
            return localizedString(theme.language, english: "Install & Launch", chinese: "安装并启动", italian: "Installa e avvia", french: "Installer et lancer", spanish: "Instalar e iniciar")
        }
        if let resolution = javaResolution(for: instance), resolution.isDownloadable {
            return localizedString(theme.language, english: "Download Java \(resolution.requiredMajorVersion) & Launch", chinese: "下载 Java \(resolution.requiredMajorVersion) 并启动", italian: "Scarica Java \(resolution.requiredMajorVersion) e avvia", french: "Télécharger Java \(resolution.requiredMajorVersion) et lancer", spanish: "Descargar Java \(resolution.requiredMajorVersion) e iniciar")
        }
        if hasBlockingLaunchFailure(instance) {
            return localizedString(theme.language, english: "View Failure", chinese: "查看失败原因", italian: "Vedi errore", french: "Voir l'échec", spanish: "Ver fallo")
        }
        return AppText.launch.localized(theme.language)
    }

    var primaryActionSystemImage: String {
        primaryActionSystemImage(for: selectedInstance)
    }

    func primaryActionSystemImage(for instance: GameInstance) -> String {
        if let resolution = javaResolution(for: instance), resolution.isDownloadable {
            return "arrow.down.circle"
        }
        if needsInstallBeforeLaunch(instance) {
            return "arrow.down.circle"
        }
        if hasBlockingLaunchFailure(instance) {
            return "exclamationmark.triangle"
        }
        return "play.circle.fill"
    }

    func primaryActionDisabled(for instance: GameInstance) -> Bool {
        if viewModel.coreState == .starting || viewModel.coreState == .stopping {
            return true
        }
        if !viewModel.coreState.isReady {
            return false
        }
        if hasBlockingLaunchFailure(instance) {
            return false
        }
        if let resolution = javaResolution(for: instance), resolution.isDownloadable {
            return !viewModel.canSubmitTask
        }
        if needsInstallBeforeLaunch(instance) {
            return !viewModel.canSubmitTask
        }
        return !viewModel.canLaunch(gameDir: instance.gameDirectory)
    }

    func summary(for instance: GameInstance) -> CoreLaunchInstanceSummary? {
        launchLibrarySummary?.instances.first { summary in
            if summary.id == instance.id.uuidString {
                return true
            }
            return summary.minecraftVersion == instance.minecraftVersion
                && summary.gameDir == instance.gameDirectory
        }
    }

    func orderedInstances(for summaryIds: [String]) -> [GameInstance] {
        summaryIds.compactMap { id in
            instanceStore.instances.first { instance in
                instance.id.uuidString == id || instance.gameDirectory == id
            }
        }
    }

    func refreshSelectedPackDoctor(force: Bool = false) {
        guard viewModel.coreState.isReady else { return }
        packDoctorStore.refresh(instance: selectedInstance, force: force)
    }

    func performPackDoctorPrimaryAction() {
        guard let actionKind = (packDoctorStore.report?.primaryDiagnostic ?? packDoctorDiagnostics.first)?.action.kind else {
            refreshSelectedPackDoctor(force: true)
            return
        }
        switch actionKind {
        case "switchLoader", "manualInstall":
            openDiscover()
        case "installJava":
            openSettings()
        case "repairInstance":
            performPrimaryAction()
        case "applyPerformanceRecommendation", "rollbackPerformanceProfile":
            if let reviewAction = reviewPerformanceProfileAction() {
                reviewAction()
            } else {
                openSettings()
            }
        default:
            openLogs()
        }
    }

    func hasBlockingLaunchFailure(_ instance: GameInstance) -> Bool {
        if instance.status == .failed {
            return true
        }
        guard let summary = summary(for: instance) else { return false }
        if summary.status == "failed" {
            return true
        }
        switch summary.status {
        case "needsInstall", "missing", "notInstalled":
            return false
        default:
            return summary.needsAttention && !summary.canLaunch
        }
    }

    func statusStyle(for instance: GameInstance) -> StatusBadge.Style {
        if let task = viewModel.currentTask, currentTaskApplies(to: instance) {
            switch task.state {
            case .queued, .running:
                return .running
            case .succeeded:
                return .success
            case .failed:
                return .error
            case .cancelled:
                return .warning
            }
        }
        guard let summary = summary(for: instance) else {
            return instance.status.badgeStyle
        }
        return statusStyle(for: instance, summary: summary)
    }

    private func needsInstallBeforeLaunch(_ instance: GameInstance) -> Bool {
        if let summary = summary(for: instance),
           summary.status == "needsInstall" || summary.status == "missing" || summary.status == "notInstalled" {
            return true
        }
        return instance.status == .notInstalled
    }

    private func currentTaskApplies(to instance: GameInstance) -> Bool {
        guard let task = viewModel.currentTask else { return false }
        guard task.state.isActive || task.state == .failed else { return false }
        guard let taskGameDir = task.gameDir?.trimmingCharacters(in: .whitespacesAndNewlines),
              !taskGameDir.isEmpty else {
            return true
        }
        let instanceGameDir = instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instanceGameDir.isEmpty else { return false }
        return LauncherViewModel.sameFilePath(taskGameDir, instanceGameDir)
    }

    private func statusStyle(for instance: GameInstance, summary: CoreLaunchInstanceSummary) -> StatusBadge.Style {
        if summary.canLaunch {
            return .success
        }
        switch summary.status {
        case "failed":
            return .error
        case "needsInstall", "missing":
            return .warning
        case "running":
            return .running
        default:
            return instance.status.badgeStyle
        }
    }

    var corePreflightItem: LaunchPreflightItem {
        if viewModel.coreState.isReady {
            return LaunchPreflightItem(
                id: "core",
                title: localizedString(theme.language, english: "Core service", chinese: "Core 服务", italian: "Servizio Core", french: "Service Core", spanish: "Servicio Core"),
                detail: viewModel.coreState.detail,
                state: .ready,
                actionTitle: nil,
                action: nil
            )
        }
        return LaunchPreflightItem(
            id: "core",
            title: localizedString(theme.language, english: "Core service", chinese: "Core 服务", italian: "Servizio Core", french: "Service Core", spanish: "Servicio Core"),
            detail: viewModel.coreState.detail,
            state: .needsFix,
            actionTitle: localizedString(theme.language, english: "Start", chinese: "启动", italian: "Avvia", french: "Démarrer", spanish: "Iniciar")
        ) {
            Task { await viewModel.startCoreIfNeeded() }
        }
    }

    var javaPreflightItem: LaunchPreflightItem {
        if let resolution = javaResolution(for: selectedInstance) {
            if resolution.isReady {
                return LaunchPreflightItem(
                    id: "java",
                    title: AppText.java.localized(theme.language),
                    detail: resolution.conciseStatus,
                    state: .ready,
                    actionTitle: nil,
                    action: nil
                )
            }
            if resolution.isDownloadable {
                return LaunchPreflightItem(
                    id: "java",
                    title: AppText.java.localized(theme.language),
                    detail: resolution.conciseStatus,
                    state: .needsFix,
                    actionTitle: localizedString(theme.language, english: "Download Java \(resolution.requiredMajorVersion)", chinese: "下载 Java \(resolution.requiredMajorVersion)", italian: "Scarica Java \(resolution.requiredMajorVersion)", french: "Télécharger Java \(resolution.requiredMajorVersion)", spanish: "Descargar Java \(resolution.requiredMajorVersion)")
                ) {
                    viewModel.installManagedJavaRuntime(featureVersion: resolution.requiredMajorVersion)
                }
            }
            return LaunchPreflightItem(
                id: "java",
                title: AppText.java.localized(theme.language),
                detail: resolution.conciseStatus,
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Settings", chinese: "设置", italian: "Impostazioni", french: "Réglages", spanish: "Ajustes"),
                action: openSettings
            )
        }

        guard let javaStatus = viewModel.javaStatus else {
            return LaunchPreflightItem(
                id: "java",
                title: AppText.java.localized(theme.language),
                detail: viewModel.javaRuntimeStatus,
                state: .optional,
                actionTitle: localizedString(theme.language, english: "Resolve", chinese: "解析", italian: "Risolvi", french: "Résoudre", spanish: "Resolver"),
                action: refreshSelectedJavaRuntime
            )
        }
        if !javaStatus.isAvailable {
            return LaunchPreflightItem(
                id: "java",
                title: AppText.java.localized(theme.language),
                detail: javaStatus.displayText,
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Check", chinese: "检查", italian: "Controlla", french: "Vérifier", spanish: "Comprobar"),
                action: viewModel.checkJavaRuntime
            )
        }
        if let requiredJavaMajor, let current = javaMajorVersion(from: javaStatus.versionSummary), current < requiredJavaMajor {
            return LaunchPreflightItem(
                id: "java",
                title: AppText.java.localized(theme.language),
                detail: localizedString(theme.language, english: "Requires Java \(requiredJavaMajor), current runtime looks like Java \(current).", chinese: "需要 Java \(requiredJavaMajor)，当前运行时看起来是 Java \(current)。", italian: "Richiede Java \(requiredJavaMajor), runtime attuale Java \(current).", french: "Nécessite Java \(requiredJavaMajor), runtime actuel Java \(current).", spanish: "Requiere Java \(requiredJavaMajor), runtime actual Java \(current)."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Change Java", chinese: "更换 Java", italian: "Cambia Java", french: "Changer Java", spanish: "Cambiar Java"),
                action: openSettings
            )
        }
        return LaunchPreflightItem(
            id: "java",
            title: AppText.java.localized(theme.language),
            detail: requiredJavaMajor.map { localizedString(theme.language, english: "Java runtime is available. Required: Java \($0).", chinese: "Java 可用。需要：Java \($0)。", italian: "Runtime Java disponibile. Richiesto: Java \($0).", french: "Runtime Java disponible. Requis : Java \($0).", spanish: "Runtime Java disponible. Requerido: Java \($0).") } ?? javaStatus.displayText,
            state: .ready,
            actionTitle: nil,
            action: nil
        )
    }

    var jvmTuningPreflightItem: LaunchPreflightItem {
        let instance = selectedInstance
        if let snapshot = instance.lastJvmTuningSnapshot,
           snapshot.state == .failed,
           let lastKnownGood = instance.lastKnownGoodJvmTuning {
            return LaunchPreflightItem(
                id: "tuning",
                title: localizedString(theme.language, english: "Performance tuning", chinese: "性能调校", italian: "Tuning prestazioni", french: "Réglage performance", spanish: "Ajuste de rendimiento"),
                detail: tuningFailureDetail(snapshot),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Restore Last Good", chinese: "恢复上次可用设置", italian: "Ripristina valido", french: "Restaurer valide", spanish: "Restaurar válido")
            ) {
                updateSelectedInstance { $0.applyJvmTuningSnapshot(lastKnownGood) }
            }
        }

        if hasExperimentalGC(instance) {
            return LaunchPreflightItem(
                id: "tuning",
                title: localizedString(theme.language, english: "Performance tuning", chinese: "性能调校", italian: "Tuning prestazioni", french: "Réglage performance", spanish: "Ajuste de rendimiento"),
                detail: localizedString(theme.language, english: "Experimental performance mode is for controlled testing. Use automatic recommendation for normal play.", chinese: "实验性能模式只适合测试。普通游玩建议改回自动推荐。", italian: "La modalità prestazioni sperimentale è per test controllati. Usa la raccomandazione automatica.", french: "Le mode performance expérimental sert aux tests. Utilisez la recommandation automatique.", spanish: "El modo experimental es para pruebas. Usa la recomendación automática."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Restore Auto", chinese: "恢复自动", italian: "Automatico", french: "Auto", spanish: "Auto")
            ) {
                updateSelectedInstance { $0.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb) }
            }
        }

        if hasCustomJvmConflict(instance) {
            return LaunchPreflightItem(
                id: "tuning",
                title: localizedString(theme.language, english: "Performance tuning", chinese: "性能调校", italian: "Tuning prestazioni", french: "Réglage performance", spanish: "Ajuste de rendimiento"),
                detail: localizedString(theme.language, english: "Custom advanced launch flags conflict with automatic tuning. Use Panino's recommendation first.", chinese: "自定义高级启动参数会和自动调校冲突。先使用 Panino 推荐。", italian: "Flag avanzati personalizzati confliggono con l'autotuning. Usa prima la raccomandazione Panino.", french: "Les options avancées personnalisées entrent en conflit. Utilisez d'abord la recommandation Panino.", spanish: "Los flags avanzados chocan con el ajuste automático. Usa primero la recomendación de Panino."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Restore Auto", chinese: "恢复自动", italian: "Automatico", french: "Auto", spanish: "Auto")
            ) {
                updateSelectedInstance { $0.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb) }
            }
        }

        if let manualMemoryWarning = manualMemoryWarning(for: instance) {
            return LaunchPreflightItem(
                id: "tuning",
                title: localizedString(theme.language, english: "Performance tuning", chinese: "性能调校", italian: "Tuning prestazioni", french: "Réglage performance", spanish: "Ajuste de rendimiento"),
                detail: manualMemoryWarning.detail,
                state: .needsFix,
                actionTitle: manualMemoryWarning.actionTitle
            ) {
                updateSelectedInstance { selected in
                    selected.memoryPolicy = .custom
                    selected.customMemoryMb = manualMemoryWarning.targetMb
                    selected.memoryMb = manualMemoryWarning.targetMb
                }
            }
        }

        return LaunchPreflightItem(
            id: "tuning",
            title: localizedString(theme.language, english: "Performance tuning", chinese: "性能调校", italian: "Tuning prestazioni", french: "Réglage performance", spanish: "Ajuste de rendimiento"),
            detail: tuningReadyDetail(instance),
            state: .ready,
            actionTitle: nil,
            action: nil
        )
    }

    var performanceSummaryPreflightItem: LaunchPreflightItem? {
        guard let summary = selectedPerformanceSummary else { return nil }
        let state: LaunchPreflightState = summary.status == "needsAction" ? .needsFix : .ready
        return LaunchPreflightItem(
            id: "performance-summary",
            title: localizedString(theme.language, english: "Performance recommendation", chinese: "性能推荐", italian: "Consiglio prestazioni", french: "Recommandation performance", spanish: "Recomendación de rendimiento"),
            detail: performanceSummaryDetail(summary),
            state: state,
            actionTitle: summary.primaryAction.title,
            action: performanceSummaryAction(summary.primaryAction)
        )
    }

    var localPerformancePreflightItem: LaunchPreflightItem {
        if jvmTuningPreflightItem.state == .needsFix {
            return LaunchPreflightItem(
                id: "performance-summary",
                title: localizedString(theme.language, english: "Performance recommendation", chinese: "性能推荐", italian: "Consiglio prestazioni", french: "Recommandation performance", spanish: "Recomendación de rendimiento"),
                detail: jvmTuningPreflightItem.detail,
                state: .needsFix,
                actionTitle: jvmTuningPreflightItem.actionTitle,
                action: jvmTuningPreflightItem.action
            )
        }
        if graphicsPreflightItem.state == .needsFix {
            return LaunchPreflightItem(
                id: "performance-summary",
                title: localizedString(theme.language, english: "Performance recommendation", chinese: "性能推荐", italian: "Consiglio prestazioni", french: "Recommandation performance", spanish: "Recomendación de rendimiento"),
                detail: graphicsPreflightItem.detail,
                state: .needsFix,
                actionTitle: graphicsPreflightItem.actionTitle,
                action: graphicsPreflightItem.action
            )
        }
        return LaunchPreflightItem(
            id: "performance-summary",
            title: localizedString(theme.language, english: "Performance recommendation", chinese: "性能推荐", italian: "Consiglio prestazioni", french: "Recommandation performance", spanish: "Recomendación de rendimiento"),
            detail: localizedString(theme.language, english: "Panino will use an estimated memory and graphics baseline until this instance has local launch metrics.", chinese: "在这个实例产生本机启动指标前，Panino 只使用估算的内存和画面 baseline。", italian: "Panino usa una baseline stimata finché non ci sono metriche locali.", french: "Panino utilise une baseline estimée jusqu'aux métriques locales.", spanish: "Panino usa una base estimada hasta tener métricas locales."),
            state: .ready,
            actionTitle: nil,
            action: nil
        )
    }

    var graphicsPreflightItem: LaunchPreflightItem {
        let instance = selectedInstance
        if let snapshot = instance.lastGraphicsTuningSnapshot,
           snapshot.state == .failed,
           snapshot.renderRelatedError || snapshot.quickExit || snapshot.canRollback {
            return LaunchPreflightItem(
                id: "graphics",
                title: localizedString(theme.language, english: "Graphics tuning", chinese: "画面调校", italian: "Tuning grafica", french: "Réglage graphismes", spanish: "Ajuste gráfico"),
                detail: graphicsFailureDetail(snapshot),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Switch Smoother", chinese: "切到更流畅", italian: "Più fluido", french: "Plus fluide", spanish: "Más fluido")
            ) {
                updateSelectedInstance { $0.graphicsProfile = .performance }
            }
        }

        if instance.graphicsProfile == .manual {
            return LaunchPreflightItem(
                id: "graphics",
                title: localizedString(theme.language, english: "Graphics tuning", chinese: "画面调校", italian: "Tuning grafica", french: "Réglage graphismes", spanish: "Ajuste gráfico"),
                detail: localizedString(theme.language, english: "Manual graphics settings are active. Panino can return to the safe recommendation before launch.", chinese: "正在使用手动画面设置。启动前可以恢复 Panino 的安全推荐。", italian: "Grafica manuale attiva. Panino può tornare al consiglio sicuro.", french: "Réglages graphiques manuels actifs. Panino peut revenir au réglage sûr.", spanish: "Gráficos manuales activos. Panino puede volver al ajuste seguro."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Restore Auto", chinese: "恢复自动", italian: "Automatico", french: "Auto", spanish: "Auto")
            ) {
                updateSelectedInstance { $0.restoreAutomaticGraphicsTuning() }
            }
        }

        return LaunchPreflightItem(
            id: "graphics",
            title: localizedString(theme.language, english: "Graphics tuning", chinese: "画面调校", italian: "Tuning grafica", french: "Réglage graphismes", spanish: "Ajuste gráfico"),
            detail: graphicsReadyDetail(instance),
            state: .ready,
            actionTitle: nil,
            action: nil
        )
    }

    var versionPreflightItem: LaunchPreflightItem {
        switch versionInstallState {
        case .installed:
            return LaunchPreflightItem(
                id: "version",
                title: localizedString(theme.language, english: "Minecraft files", chinese: "Minecraft 文件", italian: "File Minecraft", french: "Fichiers Minecraft", spanish: "Archivos Minecraft"),
                detail: localizedString(theme.language, english: "\(selectedInstance.minecraftVersion) is installed and verified.", chinese: "\(selectedInstance.minecraftVersion) 已安装并通过校验。", italian: "\(selectedInstance.minecraftVersion) installato e verificato.", french: "\(selectedInstance.minecraftVersion) installé et vérifié.", spanish: "\(selectedInstance.minecraftVersion) instalado y verificado."),
                state: .ready,
                actionTitle: nil,
                action: nil
            )
        case .available:
            return LaunchPreflightItem(
                id: "version",
                title: localizedString(theme.language, english: "Minecraft files", chinese: "Minecraft 文件", italian: "File Minecraft", french: "Fichiers Minecraft", spanish: "Archivos Minecraft"),
                detail: localizedString(theme.language, english: "\(selectedInstance.minecraftVersion) will be installed before launch.", chinese: "\(selectedInstance.minecraftVersion) 会在启动前安装。", italian: "\(selectedInstance.minecraftVersion) verrà installato prima dell'avvio.", french: "\(selectedInstance.minecraftVersion) sera installé avant le lancement.", spanish: "\(selectedInstance.minecraftVersion) se instalará antes de iniciar."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Install", chinese: "安装", italian: "Installa", french: "Installer", spanish: "Instalar"),
                action: { installSelectedVersion() }
            )
        case .unknown:
            return LaunchPreflightItem(
                id: "version",
                title: localizedString(theme.language, english: "Minecraft files", chinese: "Minecraft 文件", italian: "File Minecraft", french: "Fichiers Minecraft", spanish: "Archivos Minecraft"),
                detail: localizedString(theme.language, english: "Version status is still loading from Core.", chinese: "版本状态仍在从 Core 加载。", italian: "Stato versione in caricamento da Core.", french: "État de version encore chargé depuis Core.", spanish: "Estado de versión cargando desde Core."),
                state: .optional,
                actionTitle: nil,
                action: nil
            )
        }
    }

    var accountPreflightItem: LaunchPreflightItem {
        if let account = viewModel.accountState.account, !account.isExpired {
            return LaunchPreflightItem(
                id: "account",
                title: AppText.account.localized(theme.language),
                detail: localizedString(theme.language, english: "Signed in as \(account.name).", chinese: "已登录为 \(account.name)。", italian: "Accesso come \(account.name).", french: "Connecté en tant que \(account.name).", spanish: "Sesión iniciada como \(account.name)."),
                state: .ready,
                actionTitle: nil,
                action: nil
            )
        }
        if let profile = accountStore.defaultAccount, profile.loginStatus == .expired {
            return LaunchPreflightItem(
                id: "account",
                title: AppText.account.localized(theme.language),
                detail: localizedString(theme.language, english: "\(profile.name)'s Microsoft session needs refresh.", chinese: "\(profile.name) 的 Microsoft 会话需要刷新。", italian: "La sessione Microsoft di \(profile.name) va aggiornata.", french: "La session Microsoft de \(profile.name) doit être actualisée.", spanish: "La sesión Microsoft de \(profile.name) debe actualizarse."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Refresh", chinese: "刷新", italian: "Aggiorna", french: "Actualiser", spanish: "Actualizar")
            ) {
                Task { await viewModel.restoreAccountIfPossible(accountID: profile.id) }
            }
        }
        if let profile = accountStore.defaultAccount, profile.loginStatus == .signedIn {
            return LaunchPreflightItem(
                id: "account",
                title: AppText.account.localized(theme.language),
                detail: localizedString(theme.language, english: "\(profile.name) is ready for launch.", chinese: "\(profile.name) 可用于启动。", italian: "\(profile.name) pronto per l'avvio.", french: "\(profile.name) prêt pour le lancement.", spanish: "\(profile.name) listo para iniciar."),
                state: .ready,
                actionTitle: nil,
                action: nil
            )
        }
        return LaunchPreflightItem(
            id: "account",
            title: AppText.account.localized(theme.language),
            detail: localizedString(theme.language, english: "No online account is selected; launch will use offline fallback where allowed.", chinese: "未选择在线账号；允许时会使用离线回退启动。", italian: "Nessun account online selezionato; verrà usato il fallback offline se consentito.", french: "Aucun compte en ligne sélectionné ; le mode hors ligne sera utilisé si possible.", spanish: "No hay cuenta online seleccionada; se usará modo offline si se permite."),
            state: .optional,
            actionTitle: localizedString(theme.language, english: "Account", chinese: "账号", italian: "Account", french: "Compte", spanish: "Cuenta"),
            action: openAccount
        )
    }

    var diskPreflightItem: LaunchPreflightItem {
        if isGameDirectoryWritable {
            return LaunchPreflightItem(
                id: "disk",
                title: localizedString(theme.language, english: "Game directory", chinese: "游戏目录", italian: "Cartella gioco", french: "Dossier du jeu", spanish: "Directorio del juego"),
                detail: selectedInstance.gameDirectory,
                state: .ready,
                actionTitle: nil,
                action: nil
            )
        }
        return LaunchPreflightItem(
            id: "disk",
            title: localizedString(theme.language, english: "Game directory", chinese: "游戏目录", italian: "Cartella gioco", french: "Dossier du jeu", spanish: "Directorio del juego"),
            detail: localizedString(theme.language, english: "The selected directory is not writable or is missing.", chinese: "所选目录不可写或不存在。", italian: "La cartella scelta non è scrivibile o manca.", french: "Le dossier choisi n'est pas accessible en écriture ou manque.", spanish: "El directorio elegido no es escribible o no existe."),
            state: .needsFix,
            actionTitle: localizedString(theme.language, english: "Edit", chinese: "编辑", italian: "Modifica", french: "Modifier", spanish: "Editar"),
            action: openInstances
        )
    }

    var resourcePreflightItem: LaunchPreflightItem {
        if conflictCount > 0 || missingDependencyCount > 0 || archivedDeprecatedCount > 0 {
            return LaunchPreflightItem(
                id: "resources",
                title: localizedString(theme.language, english: "Resources", chinese: "资源内容", italian: "Risorse", french: "Ressources", spanish: "Recursos"),
                detail: localizedString(theme.language, english: "\(conflictCount) conflicts, \(missingDependencyCount) dependency warnings, \(archivedDeprecatedCount) archived/deprecated hints.", chinese: "\(conflictCount) 个冲突，\(missingDependencyCount) 个依赖风险，\(archivedDeprecatedCount) 个归档/弃用提示。", italian: "\(conflictCount) conflitti, \(missingDependencyCount) avvisi dipendenze, \(archivedDeprecatedCount) indizi archiviati/deprecati.", french: "\(conflictCount) conflits, \(missingDependencyCount) alertes de dépendances, \(archivedDeprecatedCount) indices archivés/obsolètes.", spanish: "\(conflictCount) conflictos, \(missingDependencyCount) avisos de dependencias, \(archivedDeprecatedCount) indicios archivados/obsoletos."),
                state: .needsFix,
                actionTitle: localizedString(theme.language, english: "Review", chinese: "查看", italian: "Controlla", french: "Vérifier", spanish: "Revisar"),
                action: openResources
            )
        }
        let count = versionStore.managedAssets.count
        return LaunchPreflightItem(
            id: "resources",
            title: localizedString(theme.language, english: "Resources", chinese: "资源内容", italian: "Risorse", french: "Ressources", spanish: "Recursos"),
            detail: count == 0
                ? localizedString(theme.language, english: "No managed resources scanned for the selected content type.", chinese: "当前内容类型下未扫描到资源。", italian: "Nessuna risorsa gestita trovata per il tipo scelto.", french: "Aucune ressource gérée trouvée pour le type choisi.", spanish: "No se encontraron recursos gestionados para el tipo actual.")
                : localizedString(theme.language, english: "\(count) managed files scanned.", chinese: "已扫描 \(count) 个托管文件。", italian: "\(count) file gestiti analizzati.", french: "\(count) fichiers gérés analysés.", spanish: "\(count) archivos gestionados escaneados."),
            state: count == 0 ? .optional : .ready,
            actionTitle: count == 0 ? localizedString(theme.language, english: "Discover", chinese: "发现", italian: "Scopri", french: "Découvrir", spanish: "Descubrir") : nil,
            action: count == 0 ? openDiscover : nil
        )
    }

    enum VersionInstallState {
        case installed
        case available
        case unknown
    }

    var versionInstallState: VersionInstallState {
        if let version = versionStore.versions.first(where: { $0.id == selectedInstance.minecraftVersion }) {
            return version.isInstalled ? .installed : .available
        }
        switch selectedInstance.status {
        case .ready, .running:
            return .installed
        case .notInstalled:
            return .available
        case .installing:
            return .unknown
        case .failed:
            return .available
        }
    }

    var versionInfo: MinecraftVersionInfo? {
        versionStore.versions.first { $0.id == selectedInstance.minecraftVersion }
    }

    var requiredJavaMajor: Int? {
        guard let text = versionInfo?.javaRequirement else { return nil }
        return javaMajorVersion(from: text)
    }

    func javaResolution(for instance: GameInstance) -> CoreJavaRuntimeResolveResponse? {
        guard let resolution = viewModel.javaRuntimeResolution,
              resolution.minecraftVersion == instance.minecraftVersion else {
            return nil
        }
        return resolution
    }

    var isGameDirectoryWritable: Bool {
        let path = selectedInstance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return false }
        let directoryPath = path
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directoryPath) {
            return fileManager.isWritableFile(atPath: directoryPath)
        }
        let parent = URL(fileURLWithPath: directoryPath).deletingLastPathComponent().path
        return fileManager.isWritableFile(atPath: parent)
    }

    var conflictCount: Int {
        versionStore.managedAssets.filter { $0.conflictMessage != nil }.count
    }

    var missingDependencyCount: Int {
        versionStore.managedAssets.filter { asset in
            let text = (asset.conflictMessage ?? "") + " " + (asset.metadata.summary ?? "")
            let lowercased = text.lowercased()
            return lowercased.contains("missing") || lowercased.contains("dependency") || lowercased.contains("依赖")
        }.count
    }

    var archivedDeprecatedCount: Int {
        versionStore.managedAssets.filter { asset in
            let text = [asset.name, asset.metadata.displayName, asset.metadata.summary, asset.source]
                .compactMap { $0 }
                .joined(separator: " ")
                .lowercased()
            return text.contains("archived")
                || text.contains("deprecated")
                || text.contains("withheld")
                || text.contains("弃用")
                || text.contains("归档")
        }.count
    }

    var updateCandidateCount: Int {
        versionStore.managedAssets.filter { $0.projectURL != nil || ($0.source?.isEmpty == false) }.count
    }

    var recentChangeCount: Int {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        return versionStore.managedAssets.filter { ($0.modifiedAt ?? .distantPast) >= cutoff }.count
    }

    var sourceSummary: String {
        let sources = Set(versionStore.managedAssets.compactMap { $0.source?.isEmpty == false ? $0.source : nil })
        if sources.isEmpty {
            return localizedString(theme.language, english: "Local files", chinese: "本地文件", italian: "File locali", french: "Fichiers locaux", spanish: "Archivos locales")
        }
        return sources.sorted().prefix(3).joined(separator: ", ")
    }

    var resourceSummary: String {
        let count = versionStore.managedAssets.count
        return localizedString(theme.language, english: "\(count) \(versionStore.selectedAssetKind.title)", chinese: "\(count) 个 \(versionStore.selectedAssetKind.title)", italian: "\(count) \(versionStore.selectedAssetKind.title)", french: "\(count) \(versionStore.selectedAssetKind.title)", spanish: "\(count) \(versionStore.selectedAssetKind.title)")
    }

    private func tuningFailureDetail(_ snapshot: JvmTuningSnapshot) -> String {
        let suffix = snapshot.exitCode.map { exitCodeDetail($0) } ?? ""
        if snapshot.heapOutOfMemory {
            return localizedString(theme.language, english: "Last launch hit game memory pressure.\(suffix) Restore a known-good setup before increasing memory.", chinese: "上次启动出现游戏内存压力。\(suffix) 先恢复可用设置，不要直接加大内存。", italian: "Ultimo avvio con pressione memoria gioco.\(suffix) Ripristina una configurazione valida prima di aumentare memoria.", french: "Le dernier lancement a subi une pression mémoire.\(suffix) Restaurez un réglage valide avant d'augmenter.", spanish: "El último inicio tuvo presión de memoria.\(suffix) Restaura un ajuste válido antes de subir memoria.")
        }
        if snapshot.nativeOutOfMemory {
            return localizedString(theme.language, english: "Last launch looked like system memory pressure.\(suffix) On unified-memory Macs, lower game memory often helps.", chinese: "上次启动像是系统内存压力。\(suffix) 在统一内存 Mac 上，降低游戏内存经常更有效。", italian: "Ultimo avvio con pressione memoria di sistema.\(suffix) Sui Mac a memoria unificata aiuta spesso ridurre memoria gioco.", french: "Le dernier lancement semble lié à la mémoire système.\(suffix) Réduire la mémoire jeu aide souvent sur Mac.", spanish: "El último inicio parece presión de memoria del sistema.\(suffix) Reducir memoria de juego suele ayudar.")
        }
        if snapshot.gcOverheadLimit {
            return localizedString(theme.language, english: "Last launch spent too much time managing memory.\(suffix) Restore a known-good tuning profile first.", chinese: "上次启动花了太多时间处理内存。\(suffix) 先恢复上次可用调校。", italian: "Ultimo avvio con troppa gestione memoria.\(suffix) Ripristina prima un profilo valido.", french: "Le dernier lancement a trop géré la mémoire.\(suffix) Restaurez d'abord un profil valide.", spanish: "El último inicio gestionó demasiada memoria.\(suffix) Restaura primero un perfil válido.")
        }
        return localizedString(theme.language, english: "Last launch failed.\(suffix) Panino can restore the last known-good tuning without changing files.", chinese: "上次启动失败。\(suffix) Panino 可以恢复上次可用调校，不会改游戏文件。", italian: "Ultimo avvio fallito.\(suffix) Panino può ripristinare il tuning valido.", french: "Dernier lancement échoué.\(suffix) Panino peut restaurer le dernier réglage valide.", spanish: "El último inicio falló.\(suffix) Panino puede restaurar el ajuste válido.")
    }

    private func exitCodeDetail(_ exitCode: Int) -> String {
        localizedString(theme.language, english: " Exit code \(exitCode).", chinese: " 退出码 \(exitCode)。", italian: " Codice uscita \(exitCode).", french: " Code de sortie \(exitCode).", spanish: " Código de salida \(exitCode).")
    }

    private func tuningReadyDetail(_ instance: GameInstance) -> String {
        if let summary = instance.lastJvmTuningSnapshot?.tuningSummary,
           !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary
        }
        switch instance.jvmProfile {
        case .largePack:
            return localizedString(theme.language, english: "Large-pack profile selected. Core still keeps room for macOS and graphics memory.", chinese: "已选择大型整合包。Core 仍会给 macOS 和图形内存留空间。", italian: "Profilo pacchetto grande selezionato. Core lascia spazio a macOS e grafica.", french: "Profil gros pack sélectionné. Core garde de la place pour macOS et les graphismes.", spanish: "Perfil pack grande seleccionado. Core deja espacio para macOS y gráficos.")
        case .lowMemory, .batterySaver:
            return localizedString(theme.language, english: "Low-memory profile selected. Minecraft will leave more room for the system.", chinese: "已选择低内存。Minecraft 会给系统留出更多空间。", italian: "Profilo poca memoria selezionato. Minecraft lascia più spazio al sistema.", french: "Profil mémoire basse sélectionné. Minecraft laisse plus de place au système.", spanish: "Perfil poca memoria seleccionado. Minecraft deja más espacio al sistema.")
        case .custom:
            return localizedString(theme.language, english: "Custom tuning is active. Core will keep one final memory recommendation.", chinese: "正在使用自定义调校。Core 会保留一组最终内存建议。", italian: "Tuning personalizzato attivo. Core conserva una raccomandazione memoria finale.", french: "Réglage personnalisé actif. Core garde une recommandation mémoire finale.", spanish: "Ajuste personalizado activo. Core deja una recomendación de memoria final.")
        default:
            return localizedString(theme.language, english: "Automatic profile selected. Core will choose safe memory from this Mac and pack size.", chinese: "已选择自动推荐。Core 会按本机和整合包规模选择安全内存。", italian: "Profilo automatico selezionato. Core sceglie memoria sicura in base al Mac e al pacchetto.", french: "Profil automatique sélectionné. Core choisit la mémoire adaptée au Mac et au pack.", spanish: "Perfil automático seleccionado. Core elige memoria segura según el Mac y el pack.")
        }
    }

    private func graphicsFailureDetail(_ snapshot: GraphicsTuningSnapshot) -> String {
        if snapshot.renderRelatedError {
            return localizedString(theme.language, english: "Last launch looked render or shader related. Switch to a smoother profile before trying again.", chinese: "上次启动像是渲染或 Shader 相关问题。再次启动前建议切到更流畅。", italian: "L'ultimo avvio sembra legato a rendering o shader. Passa a un profilo più fluido.", french: "Le dernier lancement semble lié au rendu ou aux shaders. Passez à un profil plus fluide.", spanish: "El último inicio parece de render o shaders. Cambia a un perfil más fluido.")
        }
        if snapshot.quickExit {
            return localizedString(theme.language, english: "The last session ended very quickly. If the screen stuttered or heated up, use the smoother graphics profile.", chinese: "上次会话很快结束。如果有卡顿或发热，先用更流畅画面配置。", italian: "L'ultima sessione è finita subito. Se c'erano scatti o calore, usa il profilo più fluido.", french: "La dernière session a été très courte. En cas de saccades ou chaleur, utilisez le profil fluide.", spanish: "La última sesión terminó rápido. Si hubo tirones o calor, usa el perfil fluido.")
        }
        return localizedString(theme.language, english: "Panino can lower graphics pressure before launch and keep the original settings recoverable.", chinese: "Panino 可以先降低画面压力，并保留恢复原设置的能力。", italian: "Panino può ridurre il carico grafico e mantenere il ripristino.", french: "Panino peut réduire la pression graphique et garder le retour arrière.", spanish: "Panino puede bajar presión gráfica y conservar recuperación.")
    }

    private func graphicsReadyDetail(_ instance: GameInstance) -> String {
        if let summary = instance.lastGraphicsTuningSnapshot?.tuningSummary,
           !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return summary
        }
        switch instance.graphicsProfile {
        case .clarity:
            return localizedString(theme.language, english: "Clarity profile selected. Panino preserves sharpness and lowers expensive settings first.", chinese: "已选择清晰优先。Panino 会保留清晰度，优先降低高成本项。", italian: "Profilo nitidezza. Panino conserva chiarezza e riduce prima le opzioni costose.", french: "Profil clarté. Panino garde la netteté et réduit les options coûteuses.", spanish: "Perfil claridad. Panino conserva nitidez y baja ajustes costosos.")
        case .performance:
            return localizedString(theme.language, english: "Smoother profile selected. Good for Retina pressure, shaders, heat, or large packs.", chinese: "已选择更流畅。适合 Retina 压力、Shader、发热或大型整合包。", italian: "Profilo fluido. Utile per Retina, shader, calore o pacchetti grandi.", french: "Profil fluide. Utile pour Retina, shaders, chaleur ou gros packs.", spanish: "Perfil fluido. Útil para Retina, shaders, calor o packs grandes.")
        case .batterySaver:
            return localizedString(theme.language, english: "Battery profile selected. Panino lowers visual cost while playing unplugged.", chinese: "已选择省电。Panino 会在电池供电时降低画面成本。", italian: "Profilo batteria. Panino riduce il costo grafico a batteria.", french: "Profil batterie. Panino réduit le coût visuel sur batterie.", spanish: "Perfil batería. Panino baja el coste visual con batería.")
        case .manual:
            return localizedString(theme.language, english: "Manual graphics profile selected. Panino will warn before risky values are applied.", chinese: "已选择手动画面。高风险数值应用前 Panino 会提醒。", italian: "Profilo manuale. Panino avvisa prima dei valori rischiosi.", french: "Profil manuel. Panino alerte avant les valeurs risquées.", spanish: "Perfil manual. Panino avisa de valores riesgosos.")
        case .balanced:
            return localizedString(theme.language, english: "Automatic graphics selected. Panino balances clarity, smoothness, and heat for this Mac.", chinese: "已选择自动画面。Panino 会按这台 Mac 平衡清晰、流畅和发热。", italian: "Grafica automatica. Panino bilancia nitidezza, fluidità e calore.", french: "Graphismes automatiques. Panino équilibre clarté, fluidité et chaleur.", spanish: "Gráficos automáticos. Panino equilibra claridad, fluidez y calor.")
        }
    }

    func refreshSelectedPerformanceSummary() {
        let instance = selectedInstance
        let request = CoreEnvironmentReportRequest(
            gameDir: instance.gameDirectory,
            version: instance.contentMinecraftVersion,
            loader: instance.loader?.rawValue,
            loaderVersion: instance.loaderVersion,
            memoryMb: instance.memoryMb,
            memoryPolicy: instance.memoryPolicy.rawValue,
            jvmProfile: instance.jvmProfile.rawValue,
            customMemoryMb: instance.memoryPolicy == .custom ? (instance.customMemoryMb ?? instance.memoryMb) : instance.customMemoryMb,
            customJvmArgs: instance.customJvmArguments,
            modCount: versionStore.managedAssets.count,
            graphicsProfile: instance.graphicsProfile.rawValue
        )
        Task {
            do {
                let report = try await viewModel.environmentReport(request)
                await MainActor.run {
                    guard selectedInstance.id == instance.id else { return }
                    diagnosticsStore.lastEnvironmentReport = report
                }
            } catch {
                await MainActor.run {
                    guard selectedInstance.id == instance.id else { return }
                    diagnosticsStore.lastEnvironmentReport = nil
                }
            }
        }
    }

    private func performanceSummaryAction(_ action: CorePerformancePrimaryAction) -> (() -> Void)? {
        switch action.id {
        case "installPerformancePack":
            return installPerformancePackAction()
        case "applyGraphics", "viewDetails":
            return reviewPerformanceProfileAction()
        case "restoreAuto":
            return {
                updateSelectedInstance {
                    $0.restoreAutomaticJvmTuning(defaultMemoryMb: SettingsStore.memoryMb)
                    $0.restoreAutomaticGraphicsTuning()
                }
            }
        case "reduceMemory", "increaseMemory":
            guard let memoryMb = action.memoryMb else { return openSettings }
            return {
                updateSelectedInstance {
                    $0.memoryPolicy = .custom
                    $0.customMemoryMb = memoryMb
                    $0.memoryMb = memoryMb
                }
            }
        default:
            return openSettings
        }
    }

    private func reviewPerformanceProfileAction() -> (() -> Void)? {
        let instance = selectedInstance
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return openSettings
        }
        let request = CorePerformanceProfileResolveRequest(
            gameDir: instance.gameDirectory,
            instanceFingerprint: CoreInstanceFingerprint(
                minecraftVersion: instance.contentMinecraftVersion,
                javaRequirement: nil,
                loaderFamily: instance.loader?.rawValue,
                loaderVersion: instance.loaderVersion,
                rendererCapability: instance.graphicsProfile.rawValue,
                modCount: versionStore.managedAssets.count,
                shaderLoader: nil,
                activeShaderPackHash: nil,
                resourcePackScale: nil,
                lockfileFingerprint: nil,
                worldTypeHint: nil
            ),
            knobs: CorePerformanceKnobs(
                heapMaxMb: instance.memoryPolicy == .custom ? (instance.customMemoryMb ?? instance.memoryMb) : instance.memoryMb,
                heapInitialPolicy: instance.memoryPolicy.rawValue,
                gcPolicy: instance.jvmProfile.rawValue,
                renderDistance: nil,
                simulationDistance: nil,
                maxFps: nil,
                vsyncPolicy: instance.graphicsProfile.rawValue,
                particles: nil,
                clouds: nil,
                entityDistanceScaling: nil,
                performancePackSet: []
            ),
            evidence: performanceReviewEvidence(for: instance)
        )
        return {
            showPerformanceProfileReview = true
            performanceCoachStore.resolveBaseline(request: request)
        }
    }

    private func performanceReviewEvidence(for instance: GameInstance) -> [CorePerformanceEvidence] {
        let summaryEvidence = selectedPerformanceSummary?.evidence ?? []
        return summaryEvidence + [
            CorePerformanceEvidence(key: "source", value: "launch-ui", source: "swift"),
            CorePerformanceEvidence(key: "jvmProfile", value: instance.jvmProfile.rawValue, source: "instance"),
            CorePerformanceEvidence(key: "graphicsProfile", value: instance.graphicsProfile.rawValue, source: "instance")
        ]
    }

    func applySelectedPerformanceProfile(_ profile: CorePerformanceProfile) {
        updateSelectedInstance { instance in
            if let heapMaxMb = profile.knobs.heapMaxMb {
                instance.memoryPolicy = .custom
                instance.customMemoryMb = heapMaxMb
                instance.memoryMb = heapMaxMb
            }

            if let gcPolicy = profile.knobs.gcPolicy?.lowercased() {
                if gcPolicy.contains("zgc") {
                    instance.jvmProfile = .experimentalZgc
                } else if gcPolicy != "auto" && gcPolicy != "default" && gcPolicy != "g1_or_default" {
                    instance.jvmProfile = .custom
                }
            }

            if profile.knobs.renderDistance != nil
                || profile.knobs.simulationDistance != nil
                || profile.knobs.maxFps != nil
                || profile.knobs.vsyncPolicy != nil
                || profile.knobs.particles != nil
                || profile.knobs.clouds != nil
                || profile.knobs.entityDistanceScaling != nil {
                instance.graphicsProfile = .performance
            }
        }
    }

    private func performanceSummaryDetail(_ summary: CorePerformanceSummary) -> String {
        [
            summary.title,
            performanceConfidenceDetail(summary.confidence),
            summary.detail,
            performanceEvidenceSummary(summary.evidence),
            performanceRollbackSummary(summary.rollbackRef)
        ]
        .compactMap { $0?.isEmpty == false ? $0 : nil }
        .joined(separator: "\n")
    }

    private func performanceConfidenceDetail(_ confidence: String?) -> String {
        switch confidence {
        case "measured_once":
            return localizedString(theme.language, english: "Measured once on this Mac.", chinese: "已在这台 Mac 上测过一次。", italian: "Misurato una volta su questo Mac.", french: "Mesuré une fois sur ce Mac.", spanish: "Medido una vez en este Mac.")
        case "measured_stable", "experiment_won":
            return localizedString(theme.language, english: "Verified by local launch history.", chinese: "已通过本机启动历史验证。", italian: "Verificato dagli avvii locali.", french: "Vérifié par l'historique local.", spanish: "Verificado con historial local.")
        case "blocked":
            return localizedString(theme.language, english: "Blocked by safety checks.", chinese: "已被安全检查阻止。", italian: "Bloccato dai controlli.", french: "Bloqué par sécurité.", spanish: "Bloqueado por seguridad.")
        default:
            return localizedString(theme.language, english: "Estimated baseline, not measured yet.", chinese: "这是估算 baseline，尚未本机实测。", italian: "Baseline stimata, non ancora misurata.", french: "Baseline estimée, pas encore mesurée.", spanish: "Base estimada, aún no medida.")
        }
    }

    private func performanceEvidenceSummary(_ evidence: [CorePerformanceEvidence]?) -> String? {
        guard let evidence, !evidence.isEmpty else { return nil }
        let rendered = evidence.prefix(3).map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        return localizedString(theme.language, english: "Evidence: \(rendered).", chinese: "证据：\(rendered)。", italian: "Evidenza: \(rendered).", french: "Preuves : \(rendered).", spanish: "Evidencia: \(rendered).")
    }

    private func performanceRollbackSummary(_ rollbackRef: String?) -> String? {
        guard let rollbackRef, !rollbackRef.isEmpty else { return nil }
        return localizedString(theme.language, english: "Rollback available: \(rollbackRef).", chinese: "可回滚：\(rollbackRef)。", italian: "Rollback disponibile: \(rollbackRef).", french: "Rollback disponible : \(rollbackRef).", spanish: "Rollback disponible: \(rollbackRef).")
    }

    private func installPerformancePackAction() -> (() -> Void)? {
        let instance = selectedInstance
        guard let loader = instance.loader?.rawValue,
              !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return openDiscover
        }
        let request = CorePerformancePackInstallRequest(
            gameDir: instance.gameDirectory,
            minecraftVersion: instance.contentMinecraftVersion,
            loader: loader,
            includeOptional: false,
            download: LauncherSettings.storedDownloadRuntimeOptions()
        )
        return {
            Task {
                do {
                    let plan = try await viewModel.performancePackPlan(request)
                    await MainActor.run {
                        pendingPerformancePackReview = PendingPerformancePackReview(plan: plan, request: request)
                    }
                } catch {
                    await MainActor.run {
                        showPerformancePackPlanError(error)
                    }
                }
            }
        }
    }

    @MainActor
    private func showPerformancePackPlanError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localizedString(theme.language, english: "Could not prepare performance pack", chinese: "无法准备性能包", italian: "Impossibile preparare il pacchetto", french: "Impossible de préparer le pack", spanish: "No se pudo preparar el paquete")
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: localizedString(theme.language, english: "OK", chinese: "知道了", italian: "OK", french: "OK", spanish: "OK"))
        alert.runModal()
    }

    private func hasExperimentalGC(_ instance: GameInstance) -> Bool {
        instance.jvmProfile == .experimentalZgc
    }

    private func hasCustomJvmConflict(_ instance: GameInstance) -> Bool {
        splitJvmArguments(instance.customJvmArguments).contains { argument in
            argument.hasPrefix("-Xmx")
                || argument.hasPrefix("-Xms")
                || argument.contains("UseZGC")
                || argument.contains("UseG1GC")
                || argument.contains("UseShenandoahGC")
                || argument.contains("UseParallelGC")
                || argument.contains("UseSerialGC")
        }
    }

    private func manualMemoryWarning(for instance: GameInstance) -> (detail: String, actionTitle: String, targetMb: Int)? {
        guard instance.memoryPolicy == .custom else { return nil }
        let memoryMb = instance.customMemoryMb ?? instance.memoryMb
        if memoryMb >= 12 * 1024 {
            return (
                localizedString(theme.language, english: "Manual game memory is \(memoryMb) MB. On unified-memory Macs this can starve graphics and system cache.", chinese: "手动游戏内存是 \(memoryMb) MB。在统一内存 Mac 上可能挤压图形和系统缓存。", italian: "Memoria gioco manuale \(memoryMb) MB. Sui Mac a memoria unificata può comprimere grafica e cache.", french: "Mémoire jeu manuelle \(memoryMb) Mo. Sur Mac à mémoire unifiée cela peut gêner graphismes et cache.", spanish: "Memoria manual \(memoryMb) MB. En Mac de memoria unificada puede presionar gráficos y caché."),
                localizedString(theme.language, english: "Reduce to 8GB", chinese: "降到 8GB", italian: "Riduci a 8GB", french: "Réduire à 8 Go", spanish: "Bajar a 8GB"),
                8 * 1024
            )
        }
        if memoryMb < 2 * 1024 {
            return (
                localizedString(theme.language, english: "Manual game memory is below 2GB. Modern Minecraft and mod loaders usually need more.", chinese: "手动游戏内存低于 2GB。新版 Minecraft 和 Loader 通常不够用。", italian: "Memoria gioco sotto 2GB. Minecraft moderno e loader di solito richiedono di più.", french: "Mémoire jeu sous 2 Go. Minecraft moderne et les loaders demandent souvent plus.", spanish: "Memoria manual bajo 2GB. Minecraft moderno y loaders suelen necesitar más."),
                localizedString(theme.language, english: "Raise to 4GB", chinese: "升到 4GB", italian: "Porta a 4GB", french: "Monter à 4 Go", spanish: "Subir a 4GB"),
                4 * 1024
            )
        }
        return nil
    }

    var launchSummary: String {
        let java = javaResolution(for: selectedInstance)?.conciseStatus
            ?? (selectedInstance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Auto Java" : selectedInstance.javaPath)
        let loader = selectedInstance.loaderTitle(language: theme.language)
        let tuning = selectedInstance.memoryPolicy == .custom
            ? "\(selectedInstance.customMemoryMb ?? selectedInstance.memoryMb) MB"
            : localizedString(theme.language, english: "Auto tuning", chinese: "自动调校", italian: "Tuning auto", french: "Réglage auto", spanish: "Ajuste auto")
        return "Minecraft \(selectedInstance.minecraftVersion) · \(loader) · \(tuning) · \(java)"
    }

    var memoryBinding: Binding<Int> {
        Binding(
            get: { selectedInstance.memoryMb },
            set: { newValue in
                viewModel.memoryMb = newValue
                updateSelectedInstance {
                    $0.memoryPolicy = .custom
                    $0.customMemoryMb = newValue
                    $0.memoryMb = newValue
                }
            }
        )
    }

    var javaBinding: Binding<String> {
        Binding(
            get: { selectedInstance.javaPath },
            set: { newValue in
                viewModel.javaPath = newValue
                updateSelectedInstance { $0.javaPath = newValue }
            }
        )
    }

    var loaderBinding: Binding<LoaderKind?> {
        Binding(
            get: { selectedInstance.loader },
            set: { newValue in
                updateSelectedInstance { $0.loader = newValue }
            }
        )
    }
}
