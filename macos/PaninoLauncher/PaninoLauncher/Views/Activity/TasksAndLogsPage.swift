import SwiftUI

struct TasksPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    let openDiagnostics: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var taskCenterStore: TaskCenterStore
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var appActions: AppActionCenter

    @State private var historyFilter: TaskHistoryFilter = .all
    @State private var clearConfirmation: TaskClearAction?
    @State private var clearStatus: String?
    @State private var detailRecord: TaskRecord?

    var body: some View {
        TaskFocusStage(
            record: focusedRecord,
            coreStatus: viewModel.coreState.localizedTitle(theme.language),
            attentionCount: taskCenterStore.attentionRecords.count,
            canCancel: viewModel.canCancelTask,
            canRetry: summaryRetryRecord != nil,
            onCancel: viewModel.cancelCurrentTask,
            onRetry: retrySummarySelection,
            onDiagnostics: openDiagnostics
        ) {
            taskFocusContext
        }
        .task {
            await refreshCoreHistory()
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Clear task history?", chinese: "清理任务历史？", italian: "Cancellare cronologia attività?", french: "Effacer l'historique des tâches ?", spanish: "¿Borrar historial de tareas?"),
            isPresented: Binding(
                get: { clearConfirmation != nil },
                set: { if !$0 { clearConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let clearConfirmation {
                Button(clearConfirmation.title(language: theme.language), role: .destructive) {
                    performClear(clearConfirmation)
                }
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {
                clearConfirmation = nil
            }
        } message: {
            Text(localizedString(theme.language, english: "Running and queued tasks are preserved by Core.", chinese: "Core 会保留正在运行和排队中的任务。", italian: "Core conserva le attività in esecuzione e in coda.", french: "Core conserve les tâches en cours et en file.", spanish: "Core conserva tareas en ejecución y en cola."))
        }
        .sheet(item: $detailRecord) { record in
            TaskRecordDetailSheet(
                record: record,
                canRetry: canRetryAutomatically(record),
                onRetry: { retry(record) },
                onOpenLogs: openDiagnostics,
                onExportDiagnostics: { exportDiagnostics(record) },
                onOpenFolder: { openRelevantFolder(record) },
                diagnosticActionTitle: diagnosticActionTitle(for: record),
                diagnosticActionSystemImage: diagnosticActionSystemImage(for: record),
                onDiagnosticAction: { performDiagnosticAction(record) }
            )
        }
    }

    private var taskFocusContext: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            if !taskCenterStore.attentionRecords.isEmpty {
                TaskAttentionSection(
                    records: taskCenterStore.attentionRecords,
                    retryTarget: retryTargetDescription,
                    canRetry: canRetryAutomatically,
                    onRetry: retry,
                    onDismiss: taskCenterStore.clearInterrupted,
                    onOpenLogs: openDiagnostics,
                    onExportDiagnostics: exportDiagnostics,
                    onOpenFolder: openRelevantFolder,
                    diagnosticActionTitle: { diagnosticActionTitle(for: $0) },
                    diagnosticActionSystemImage: { diagnosticActionSystemImage(for: $0) },
                    onDiagnosticAction: { performDiagnosticAction($0) }
                )
                .frame(maxWidth: 760, alignment: .leading)
            }

            if !taskCenterStore.recentCompletedRecords.isEmpty {
                TaskRecentCompletedSection(records: taskCenterStore.recentCompletedRecords)
            }
            taskHistoryPanel
        }
    }

    private var taskHistoryPanel: some View {
        TaskHistorySection(
            records: filteredHistoryRecords,
            selectedRecordID: taskCenterStore.selectedRecordID,
            filter: $historyFilter,
            retentionPolicy: $taskCenterStore.retentionPolicy,
            clearStatus: clearStatus,
            onSelect: { taskCenterStore.selectedRecordID = $0.id },
            onClear: requestClear
        )
        .onMoveCommand(perform: moveHistorySelection)
        .onSubmit {
            if let selected = taskCenterStore.selectedRecord {
                detailRecord = selected
            }
        }
    }

    private var focusedRecord: TaskRecord? {
        if let currentTask = viewModel.currentTask,
           let record = taskCenterStore.records.first(where: { $0.id == currentTask.taskId }) {
            return record
        }
        return taskCenterStore.activeRecords.first
    }

    private var filteredHistoryRecords: [TaskRecord] {
        taskCenterStore.historyRecords.filter { historyFilter.includes($0) }
    }

    private var selectedRetryRecord: TaskRecord? {
        if let selected = taskCenterStore.selectedRecord, taskCenterStore.isActionableAttention(selected) {
            return selected
        }
        return taskCenterStore.attentionRecords.first
    }

    private var summaryRetryRecord: TaskRecord? {
        if let focusedRecord, canRetryAutomatically(focusedRecord) {
            return focusedRecord
        }
        return selectedRetryRecord.flatMap { canRetryAutomatically($0) ? $0 : nil }
    }

    private func retrySummarySelection() {
        guard let record = summaryRetryRecord else { return }
        retry(record)
    }

    private func retryTargetDescription(_ record: TaskRecord) -> String {
        let kind = record.kind.lowercased()
        if kind == "runtime.install" {
            return localizedString(theme.language, english: "Retry Java download", chinese: "重试 Java 下载", italian: "Riprova download Java", french: "Réessayer Java", spanish: "Reintentar Java")
        }
        if kind.contains("launch") {
            return localizedString(theme.language, english: "Retry launch", chinese: "重新启动", italian: "Riprova avvio", french: "Relancer", spanish: "Reintentar inicio")
        }
        if kind.contains("install") || kind.contains("download") {
            return localizedString(theme.language, english: "Retry install/download", chinese: "重试安装/下载", italian: "Riprova installazione/download", french: "Réessayer installation/téléchargement", spanish: "Reintentar instalación/descarga")
        }
        return localizedString(theme.language, english: "Retry task", chinese: "重试任务", italian: "Riprova attività", french: "Réessayer la tâche", spanish: "Reintentar tarea")
    }

    private func retry(_ record: TaskRecord) {
        taskCenterStore.selectedRecordID = record.id
        let gameDir = record.gameDir ?? instanceStore.selectedInstance?.gameDirectory
        let restartActiveTask = record.state.isActive
        switch record.kind.lowercased() {
        case "runtime.install":
            if let featureVersion = javaFeatureVersion(from: record) {
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
            let components = installRetryComponents(from: record)
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

    private func canRetryAutomatically(_ record: TaskRecord) -> Bool {
        let kind = record.kind.lowercased()
        guard record.state.isActive || record.state.needsAttention else { return false }
        guard !kind.contains("content") else { return false }
        return kind == "runtime.install" || kind.contains("install") || kind.contains("download") || kind.contains("launch") || kind.contains("log")
    }

    private func installRetryComponents(from record: TaskRecord) -> (loader: LoaderKind?, shaderLoader: String?) {
        let loaderValue = record.requestedLoader ?? detailValue("requestedLoader", in: record.errorDetail)
        let shaderValue = record.requestedShaderLoader ?? detailValue("requestedShaderLoader", in: record.errorDetail)
        return (
            loader: loaderValue.flatMap(loaderKind),
            shaderLoader: normalizedRetryComponent(shaderValue)
        )
    }

    private func loaderKind(_ value: String) -> LoaderKind? {
        let normalized = normalizedRetryComponent(value)?.lowercased()
        return LoaderKind.allCases.first { kind in
            kind.rawValue.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "_", with: "") == normalized
        }
    }

    private func detailValue(_ key: String, in detail: String?) -> String? {
        guard let detail else { return nil }
        let prefix = "\(key)="
        return detail
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private func normalizedRetryComponent(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "-" || trimmed.lowercased() == "none" || trimmed.lowercased() == "vanilla" {
            return nil
        }
        return trimmed
    }

    private func javaFeatureVersion(from record: TaskRecord) -> Int? {
        if let major = javaMajorVersion(from: record.version) {
            return major
        }
        if let major = javaMajorVersion(from: record.name) {
            return major
        }
        return nil
    }

    private func openRelevantFolder(_ record: TaskRecord) {
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

    private func exportDiagnostics(_ record: TaskRecord) {
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

    private func performDiagnosticAction(_ record: TaskRecord) {
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

    private func diagnosticActionTitle(for record: TaskRecord) -> String? {
        guard let diagnostic = record.diagnostic ?? record.diagnostics?.first else { return nil }
        if diagnostic.action.kind == "retry", canRetryAutomatically(record) {
            return nil
        }
        return diagnostic.actionLabel
    }

    private func diagnosticActionSystemImage(for record: TaskRecord) -> String {
        switch (record.diagnostic ?? record.diagnostics?.first)?.action.kind {
        case "installJava":
            return "cup.and.saucer"
        case "switchLoader", "switchVersion":
            return "slider.horizontal.3"
        case "configureApiKey":
            return "key"
        case "clearCache":
            return "trash"
        case "openFolder", "manualInstall":
            return "folder"
        case "configureTaowaFrp", "editFrpProfile":
            return "server.rack"
        case "openFrpcLog":
            return "terminal"
        case "lowerMemory":
            return "memorychip"
        case "applyGraphicsRecommendation":
            return "display"
        case "retry":
            return "arrow.clockwise"
        default:
            return "stethoscope"
        }
    }

    private func requestClear(_ action: TaskClearAction) {
        if action.requiresConfirmation {
            clearConfirmation = action
        } else {
            performClear(action)
        }
    }

    private func performClear(_ action: TaskClearAction) {
        clearConfirmation = nil
        Task {
            let coreSummary = await clearHistoryInCore(action)
            let localDeleted = clearHistoryLocally(action)
            clearStatus = action.statusMessage(language: theme.language, localDeleted: localDeleted, coreSummary: coreSummary)
        }
    }

    private func clearHistoryInCore(_ action: TaskClearAction) async -> CoreTaskHistoryClearResponse? {
        do {
            return try await viewModel.clearTaskHistory(
                statuses: action.coreStatuses,
                olderThanDays: nil,
                keepFailed: action == .allFinishedKeepingFailures
            )
        } catch {
            return nil
        }
    }

    private func clearHistoryLocally(_ action: TaskClearAction) -> Int {
        switch action {
        case .completed:
            return taskCenterStore.clearCompleted()
        case .cancelledAndInterrupted:
            return taskCenterStore.clearCancelledAndInterrupted()
        case .failed:
            return taskCenterStore.clearFailed()
        case .allFinished:
            return taskCenterStore.clearAllFinished()
        case .allFinishedKeepingFailures:
            return taskCenterStore.clearMatching(statuses: [.succeeded, .cancelled, .interrupted], keepFailed: true)
        case .allHistory:
            return taskCenterStore.clearAllHistory(keepActive: true)
        }
    }

    private func refreshCoreHistory() async {
        do {
            let response = try await viewModel.taskHistory(limit: 80)
            taskCenterStore.mergeCoreHistory(response.tasks)
        } catch {
            clearStatus = nil
        }
    }

    private func moveHistorySelection(_ direction: MoveCommandDirection) {
        guard !filteredHistoryRecords.isEmpty else { return }
        let records = filteredHistoryRecords
        let currentIndex = taskCenterStore.selectedRecordID.flatMap { id in
            records.firstIndex { $0.id == id }
        } ?? 0
        let nextIndex: Int
        switch direction {
        case .up:
            nextIndex = max(currentIndex - 1, 0)
        case .down:
            nextIndex = min(currentIndex + 1, records.count - 1)
        default:
            return
        }
        taskCenterStore.selectedRecordID = records[nextIndex].id
    }
}
