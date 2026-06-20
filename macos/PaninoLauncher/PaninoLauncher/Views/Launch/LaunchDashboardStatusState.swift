import Foundation

extension LaunchDashboard {
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
}
