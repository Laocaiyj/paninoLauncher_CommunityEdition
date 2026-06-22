import Foundation

extension LaunchDashboard {
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
