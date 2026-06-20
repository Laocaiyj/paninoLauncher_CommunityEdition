import Foundation

extension TasksPage {
    func retrySummarySelection() {
        guard let record = summaryRetryRecord else { return }
        retry(record)
    }

    func retry(_ record: TaskRecord) {
        taskCenterStore.selectedRecordID = record.id
        let gameDir = record.gameDir ?? instanceStore.selectedInstance?.gameDirectory
        let restartActiveTask = record.state.isActive
        switch record.kind.lowercased() {
        case "runtime.install":
            if let featureVersion = TaskRetrySupport.javaFeatureVersion(from: record) {
                viewModel.installManagedJavaRuntime(featureVersion: featureVersion)
            } else {
                taskCenterStore.enqueueLocal(
                    kind: record.kind,
                    name: record.name,
                    message: localizedString(theme.language, english: "Java version was not recorded for this task. Start the download again from Runtime settings.", chinese: "此任务没有记录 Java 版本。请从运行环境设置重新下载。", italian: "Versione Java non registrata.", french: "Version Java non enregistrée.", spanish: "Versión Java no registrada.")
                )
            }
        case let kind where kind.contains("content"):
            taskCenterStore.enqueueLocal(
                kind: record.kind,
                name: record.name,
                message: localizedString(theme.language, english: "This content task needs its original project release context. Reinstall it from the project detail page.", chinese: "此内容任务需要原始项目版本上下文。请从项目详情页重新安装。", italian: "Questa attività contenuto richiede il contesto originale della release. Reinstallala dalla pagina progetto.", french: "Cette tâche de contenu nécessite le contexte de version d'origine. Réinstallez depuis la page du projet.", spanish: "Esta tarea de contenido necesita el contexto de la versión original. Reinstálala desde el detalle del proyecto.")
            )
        case let kind where kind.contains("install") || kind.contains("download"):
            let components = TaskRetrySupport.installRetryComponents(from: record)
            viewModel.install(
                version: record.version,
                gameDir: gameDir,
                loader: components.loader,
                shaderLoader: components.shaderLoader,
                restartActiveTask: restartActiveTask
            )
        case let kind where kind.contains("launch"):
            viewModel.launch(
                version: record.version,
                accountID: accountStore.defaultAccountID.isEmpty ? nil : accountStore.defaultAccountID,
                gameDir: gameDir,
                instance: instanceStore.instances.first { $0.gameDirectory == gameDir },
                restartActiveTask: restartActiveTask
            )
        case let kind where kind.contains("log"):
            viewModel.exportLogs()
            taskCenterStore.enqueueLocal(
                kind: "log-export",
                name: localizedString(theme.language, english: "Log Export", chinese: "日志导出", italian: "Esportazione log", french: "Export des journaux", spanish: "Exportación de registros"),
                message: localizedString(theme.language, english: "Log export retry requested.", chinese: "已请求重新导出日志。", italian: "Nuovo export log richiesto.", french: "Nouvel export des journaux demandé.", spanish: "Se solicitó reexportar registros.")
            )
        default:
            taskCenterStore.enqueueLocal(
                kind: record.kind,
                name: record.name,
                message: localizedString(theme.language, english: "Retry request recorded. Open diagnostics if this task type cannot be retried automatically.", chinese: "已记录重试请求；如果该任务无法自动重试，请打开诊断。", italian: "Richiesta di retry registrata. Apri la diagnostica se non può essere riprovata automaticamente.", french: "Nouvelle tentative enregistrée. Ouvrez le diagnostic si cette tâche ne peut pas être relancée automatiquement.", spanish: "Reintento registrado. Abre diagnóstico si no puede reintentarse automáticamente.")
            )
        }
    }

    func openRelevantFolder(_ record: TaskRecord) {
        if record.kind == "taowa-tunnel",
           let instance = instanceFor(record: record) {
            FinderIntegration.openInstanceDirectory(instance)
            return
        }
        if record.kind.lowercased().contains("download") {
            FinderIntegration.openDownloadCache()
            return
        }
        if let instance = instanceStore.selectedInstance {
            FinderIntegration.openInstanceDirectory(instance)
        } else {
            FinderIntegration.openDownloadCache()
        }
    }

    func exportDiagnostics(_ record: TaskRecord) {
        taskCenterStore.selectedRecordID = record.id
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
    }

    func performDiagnosticAction(_ record: TaskRecord) {
        taskCenterStore.selectedRecordID = record.id
        guard let diagnostic = record.diagnostic ?? record.diagnostics?.first else {
            openDiagnostics()
            return
        }

        switch diagnostic.action.kind {
        case "retry":
            if record.kind == "taowa-tunnel" {
                openTaowaInstance(record)
            } else if canRetryAutomatically(record) {
                retry(record)
            } else {
                openDiagnostics()
            }
        case "configureTaowaFrp", "editFrpProfile":
            openTaowaInstance(record)
        case "openFrpcLog":
            openDiagnostics()
        case "installJava":
            appActions.focusSettings(.runtime)
            appActions.dispatch(.openSettings)
        case "switchLoader", "switchVersion":
            appActions.dispatch(.openDiscover)
        case "configureApiKey":
            appActions.focusSettings(.download)
            appActions.dispatch(.openSettings)
        case "clearCache":
            appActions.dispatch(.clearDownloadCache)
        case "openDiagnostics":
            openDiagnostics()
        case "openFolder":
            openRelevantFolder(record)
        case "lowerMemory", "applyGraphicsRecommendation":
            appActions.dispatch(.openLaunch)
        case "manualInstall":
            openRelevantFolder(record)
            openDiagnostics()
        default:
            openDiagnostics()
            exportDiagnostics(record)
        }
    }

    private func instanceFor(record: TaskRecord) -> GameInstance? {
        guard let gameDir = record.gameDir?.trimmingCharacters(in: .whitespacesAndNewlines), !gameDir.isEmpty else {
            return nil
        }
        return instanceStore.instances.first { LauncherViewModel.sameFilePath($0.gameDirectory, gameDir) }
    }

    private func openTaowaInstance(_ record: TaskRecord) {
        if let instance = instanceFor(record: record) {
            instanceStore.selectedInstanceID = instance.id
        }
        appActions.dispatch(.openInstances)
    }
}
