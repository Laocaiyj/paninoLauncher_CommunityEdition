import SwiftUI

extension ContentView {
    func handleNativeCommand(_ command: NativeAppCommand?) {
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

    func retrySelectedTask() {
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

    var defaultAccountID: String? {
        accountStore.defaultAccountID.isEmpty ? nil : accountStore.defaultAccountID
    }
}
