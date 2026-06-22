import Foundation

extension LaunchDashboard {
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

    private func needsInstallBeforeLaunch(_ instance: GameInstance) -> Bool {
        if let summary = summary(for: instance),
           summary.status == "needsInstall" || summary.status == "missing" || summary.status == "notInstalled" {
            return true
        }
        return instance.status == .notInstalled
    }
}
