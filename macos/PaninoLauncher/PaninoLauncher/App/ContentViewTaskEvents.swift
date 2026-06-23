import SwiftUI

extension ContentView {
    func notifyTaskIfNeeded(_ task: TaskSnapshot?) {
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

    func refreshManagedContentAfterTask(_ task: TaskSnapshot?) {
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
               let targetInstance = instanceStore.instances.first(where: { LauncherViewModel.sameFilePath($0.gameDirectory, gameDir) }) {
                instanceStore.selectedInstanceID = targetInstance.id
            }
            versionStore.refreshAssets(for: instanceStore.selectedInstance)
        }
        if task.kind == "install" || task.kind == "launch" {
            configureVersionCoreBackend()
            versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
        }
    }

    func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: .live(viewModel: viewModel)
        )
    }

    func notifyExpiredAccountIfNeeded(_ account: MinecraftAccount) {
        guard account.isExpired, notifiedExpiredAccountIDs.insert(account.id).inserted else { return }
        UserNotificationService.shared.notifyOnce(
            identifier: "account-expired-\(account.id)",
            title: localizedString(theme.language, english: "Account Expired", chinese: "账号已过期", italian: "Account scaduto", french: "Compte expiré", spanish: "Cuenta expirada"),
            body: localizedString(theme.language, english: "Re-authenticate before launching.", chinese: "启动前请重新登录。", italian: "Riautentica prima di avviare.", french: "Réauthentifiez-vous avant de lancer.", spanish: "Reautentica antes de iniciar.")
        )
    }
}
