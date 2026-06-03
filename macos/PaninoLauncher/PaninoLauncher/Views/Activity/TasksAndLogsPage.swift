import SwiftUI

private enum TaskHistoryFilter: String, CaseIterable, Identifiable {
    case all
    case failed
    case install
    case download
    case launch
    case diagnostic

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .all:
            return localizedString(language, english: "All", chinese: "全部", italian: "Tutte", french: "Toutes", spanish: "Todas")
        case .failed:
            return localizedString(language, english: "Failed", chinese: "失败", italian: "Fallite", french: "Échecs", spanish: "Fallidas")
        case .install:
            return localizedString(language, english: "Install", chinese: "安装", italian: "Installazione", french: "Installation", spanish: "Instalación")
        case .download:
            return localizedString(language, english: "Download", chinese: "下载", italian: "Download", french: "Téléchargement", spanish: "Descarga")
        case .launch:
            return localizedString(language, english: "Launch", chinese: "启动", italian: "Avvio", french: "Lancement", spanish: "Inicio")
        case .diagnostic:
            return localizedString(language, english: "Diagnostic", chinese: "诊断", italian: "Diagnostica", french: "Diagnostic", spanish: "Diagnóstico")
        }
    }

    func includes(_ record: TaskRecord) -> Bool {
        let kind = record.kind.lowercased()
        switch self {
        case .all:
            return true
        case .failed:
            return record.state == .failed || record.state == .interrupted
        case .install:
            return kind.contains("install") || kind.contains("content")
        case .download:
            return kind.contains("download")
        case .launch:
            return kind.contains("launch")
        case .diagnostic:
            return kind.contains("diagnostic") || kind.contains("log") || kind.contains("java") || kind.contains("check")
        }
    }
}

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

    @State private var showHistory = false
    @State private var historyFilter: TaskHistoryFilter = .all
    @State private var clearConfirmation: TaskClearAction?
    @State private var clearStatus: String?
    @State private var detailRecord: TaskRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            TaskCenterSummaryPanel(
                record: focusedRecord,
                coreStatus: viewModel.coreState.localizedTitle(theme.language),
                canCancel: viewModel.canCancelTask,
                onCancel: viewModel.cancelCurrentTask,
                onRetry: retrySummarySelection,
                onDiagnostics: openDiagnostics,
                canRetry: summaryRetryRecord != nil
            )

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

            TaskRecentCompletedSection(records: taskCenterStore.recentCompletedRecords)

            TaskHistorySection(
                records: filteredHistoryRecords,
                isExpanded: $showHistory,
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
            if canRetryAutomatically(record) {
                retry(record)
            } else {
                openDiagnostics()
            }
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

private struct TaskCenterSummaryPanel: View {
    let record: TaskRecord?
    let coreStatus: String
    let canCancel: Bool
    let onCancel: () -> Void
    let onRetry: () -> Void
    let onDiagnostics: () -> Void
    let canRetry: Bool

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    if let record {
                        TaskStateLine(title: record.state.title(language: theme.language), style: record.state.badgeStyle)
                    } else {
                        TaskStateLine(title: AppText.idle.localized(theme.language), style: .neutral)
                    }
                }

                if let record, shouldShowProgress(record) {
                    progressSection(record)
                }

                HStack(spacing: 8) {
                    TaskFact(title: localizedString(theme.language, english: "Core", chinese: "Core", italian: "Core", french: "Core", spanish: "Core"), value: coreStatus)
                    TaskFact(title: localizedString(theme.language, english: "Updated", chinese: "更新", italian: "Aggiornato", french: "Mis à jour", spanish: "Actualizado"), value: record?.updatedAt.formatted(date: .omitted, time: .shortened) ?? "-")
                    TaskFact(title: localizedString(theme.language, english: "Kind", chinese: "类型", italian: "Tipo", french: "Type", spanish: "Tipo"), value: record?.kindTitle ?? "-")
                    Spacer()
                    if canCancel {
                        GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: onCancel)
                    }
                    if canRetry {
                        GlassButton(title: localizedString(theme.language, english: "Retry", chinese: "重试", italian: "Riprova", french: "Réessayer", spanish: "Reintentar"), action: onRetry)
                    }
                    if record?.state.needsAttention == true {
                        GlassButton(title: localizedString(theme.language, english: "View Reason", chinese: "查看原因", italian: "Vedi motivo", french: "Voir raison", spanish: "Ver motivo"), action: onDiagnostics)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func progressSection(_ record: TaskRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(percentText(record))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text(phaseText(record))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }

            if record.progress > 0 || record.state.isTerminal {
                ProgressView(value: min(max(record.progress, 0), 1), total: 1)
                    .tint(record.state.badgeStyle.color)
            } else {
                ProgressView()
                    .tint(record.state.badgeStyle.color)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    progressMetadata(record)
                }
                VStack(alignment: .leading, spacing: 4) {
                    progressMetadata(record)
                }
            }
        }
    }

    @ViewBuilder
    private func progressMetadata(_ record: TaskRecord) -> some View {
        if !record.currentFile.isEmpty {
            progressCaption(localizedString(theme.language, english: "File", chinese: "文件", italian: "File", french: "Fichier", spanish: "Archivo"), record.currentFile)
        }
        if let jobsText = jobsText(record) {
            progressCaption(localizedString(theme.language, english: "Jobs", chinese: "文件数", italian: "File", french: "Fichiers", spanish: "Archivos"), jobsText)
        }
        if let bytesText = bytesText(record) {
            progressCaption(localizedString(theme.language, english: "Bytes", chinese: "数据量", italian: "Byte", french: "Octets", spanish: "Bytes"), bytesText)
        }
        progressCaption(localizedString(theme.language, english: "Speed", chinese: "速度", italian: "Velocità", french: "Vitesse", spanish: "Velocidad"), record.speed)
        if let movingAverageSpeed = record.movingAverageSpeed, movingAverageSpeed != record.speed {
            progressCaption(localizedString(theme.language, english: "Average", chinese: "均速", italian: "Media", french: "Moyenne", spanish: "Media"), movingAverageSpeed)
        }
        if let hostText = hostTelemetryText(record) {
            progressCaption(localizedString(theme.language, english: "Host", chinese: "主机", italian: "Host", french: "Hôte", spanish: "Host"), hostText)
        }
        if let multipart = record.multipartTelemetry, multipart.totalSegments > 0 {
            progressCaption(localizedString(theme.language, english: "Segments", chinese: "分片", italian: "Segmenti", french: "Segments", spanish: "Segmentos"), multipart.displayText)
        }
        if let throttleReason = record.throttleReason, !throttleReason.isEmpty {
            progressCaption(localizedString(theme.language, english: "Gate", chinese: "调度", italian: "Gate", french: "Limite", spanish: "Límite"), throttleReason)
        }
        progressCaption(localizedString(theme.language, english: "ETA", chinese: "剩余", italian: "Tempo", french: "Restant", spanish: "Restante"), record.remainingTime)
    }

    private func progressCaption(_ title: String, _ value: String) -> some View {
        Text("\(title): \(value)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private func shouldShowProgress(_ record: TaskRecord) -> Bool {
        record.state.isActive || record.progress > 0
    }

    private func percentText(_ record: TaskRecord) -> String {
        "\(Int((min(max(record.progress, 0), 1) * 100).rounded()))%"
    }

    private func phaseText(_ record: TaskRecord) -> String {
        let phase = record.phaseTitle ?? record.message
        if let index = record.phaseIndex, let count = record.phaseCount, count > 1 {
            return "\(index)/\(count) \(phase)"
        }
        return phase
    }

    private func jobsText(_ record: TaskRecord) -> String? {
        guard let completed = record.completedJobs, let total = record.totalJobs, total > 0 else { return nil }
        return "\(completed) / \(total)"
    }

    private func bytesText(_ record: TaskRecord) -> String? {
        guard let completed = record.completedBytes, let total = record.totalBytes, total > 0 else { return nil }
        return "\(formattedBytes(completed)) / \(formattedBytes(total))"
    }

    private func hostTelemetryText(_ record: TaskRecord) -> String? {
        guard let host = record.hostTelemetry?.max(by: { $0.activeConnections < $1.activeConnections }) else {
            return record.sourceHost
        }
        return host.displayText
    }

    private var title: String {
        guard let record else {
            return localizedString(theme.language, english: "No Active Task", chinese: "没有正在运行的任务", italian: "Nessuna attività attiva", french: "Aucune tâche active", spanish: "Sin tarea activa")
        }
        guard record.state.isActive else { return record.name }
        let target = record.version.isEmpty ? record.name : record.version
        if record.kind.contains("content") {
            return localizedString(theme.language, english: "Installing \(target)", chinese: "正在安装 \(target)", italian: "Installazione di \(target)", french: "Installation de \(target)", spanish: "Instalando \(target)")
        }
        if record.kind.contains("launch") {
            return localizedString(theme.language, english: "Preparing launch \(target)", chinese: "正在准备启动 \(target)", italian: "Preparazione avvio \(target)", french: "Préparation du lancement \(target)", spanish: "Preparando inicio \(target)")
        }
        if record.kind.contains("install") {
            return localizedString(theme.language, english: "Installing Minecraft \(target)", chinese: "正在安装 Minecraft \(target)", italian: "Installazione Minecraft \(target)", french: "Installation Minecraft \(target)", spanish: "Instalando Minecraft \(target)")
        }
        return record.name
    }

    private var subtitle: String {
        guard let record else {
            return localizedString(theme.language, english: "Ready. Failed or running work appears here.", chinese: "当前空闲；失败或运行中的任务会显示在这里。", italian: "Pronto. Errori o attività in corso appaiono qui.", french: "Prêt. Les échecs et tâches en cours s'affichent ici.", spanish: "Listo. Los fallos y tareas en curso aparecen aquí.")
        }
        if record.state.needsAttention, record.progress > 0 {
            let percent = percentText(record)
            let phase = record.phaseTitle ?? record.message
            return localizedString(theme.language, english: "Failed at \(percent): \(phase)", chinese: "失败于 \(percent)：\(phase)", italian: "Errore al \(percent): \(phase)", french: "Échec à \(percent) : \(phase)", spanish: "Falló al \(percent): \(phase)")
        }
        if record.state == .succeeded {
            return localizedString(theme.language, english: "Installed and verified. Ready to launch.", chinese: "已安装并校验，可启动。", italian: "Installato e verificato. Pronto all'avvio.", french: "Installé et vérifié. Prêt à lancer.", spanish: "Instalado y verificado. Listo para iniciar.")
        }
        return record.message
    }
}

private struct TaskFact: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(minWidth: 110, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TaskStateLine: View {
    let title: String
    let style: StatusBadge.Style

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(style.color)
                .frame(width: 3, height: 16)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

private struct TaskAttentionSection: View {
    let records: [TaskRecord]
    let retryTarget: (TaskRecord) -> String
    let canRetry: (TaskRecord) -> Bool
    let onRetry: (TaskRecord) -> Void
    let onDismiss: (TaskRecord) -> Void
    let onOpenLogs: () -> Void
    let onExportDiagnostics: (TaskRecord) -> Void
    let onOpenFolder: (TaskRecord) -> Void
    let diagnosticActionTitle: (TaskRecord) -> String?
    let diagnosticActionSystemImage: (TaskRecord) -> String
    let onDiagnosticAction: (TaskRecord) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(localizedString(theme.language, english: "Needs Attention", chinese: "需要处理", italian: "Richiede attenzione", french: "Action requise", spanish: "Requiere atención"))
                        .font(.headline)
                    Spacer()
                    CountText(value: records.count, style: .warning)
                }

                if records.isEmpty {
                    EmptyStateInline(
                        title: localizedString(theme.language, english: "No action needed", chinese: "暂无需要处理", italian: "Nessuna azione richiesta", french: "Aucune action requise", spanish: "No requiere acción"),
                        message: localizedString(theme.language, english: "Failures and interrupted tasks will appear here with recovery actions.", chinese: "失败或中断任务会在这里显示，并提供恢复动作。", italian: "Errori e interruzioni appariranno qui.", french: "Les échecs et interruptions apparaîtront ici.", spanish: "Fallos e interrupciones aparecerán aquí."),
                        systemImage: "checkmark.circle"
                    )
                } else {
                    ForEach(records) { record in
                        TaskAttentionCard(
                            record: record,
                            retryTitle: retryTarget(record),
                            canRetry: canRetry(record),
                            onRetry: { onRetry(record) },
                            onDismiss: { onDismiss(record) },
                            onOpenLogs: onOpenLogs,
                            onExportDiagnostics: { onExportDiagnostics(record) },
                            onOpenFolder: { onOpenFolder(record) },
                            diagnosticActionTitle: diagnosticActionTitle(record),
                            diagnosticActionSystemImage: diagnosticActionSystemImage(record),
                            onDiagnosticAction: { onDiagnosticAction(record) }
                        )
                    }
                }
            }
        }
    }
}

private struct TaskAttentionCard: View {
    let record: TaskRecord
    let retryTitle: String
    let canRetry: Bool
    let onRetry: () -> Void
    let onDismiss: () -> Void
    let onOpenLogs: () -> Void
    let onExportDiagnostics: () -> Void
    let onOpenFolder: () -> Void
    let diagnosticActionTitle: String?
    let diagnosticActionSystemImage: String
    let onDiagnosticAction: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TaskStateLine(title: record.state.title(language: theme.language), style: record.state.badgeStyle)
                Text(record.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(record.message)
                .font(.callout)
                .lineLimit(2)
                .textSelection(.enabled)

            Text(record.advice.localizedRecoveryAdvice(theme.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { actionButtons }
                VStack(alignment: .leading, spacing: 8) { actionButtons }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.orange.opacity(0.24), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if canRetry {
            GlassButton(systemImage: "arrow.clockwise", title: retryTitle, prominent: true, action: onRetry)
        }
        if let diagnosticActionTitle {
            GlassButton(systemImage: diagnosticActionSystemImage, title: diagnosticActionTitle, prominent: !canRetry, action: onDiagnosticAction)
        }
        GlassButton(systemImage: "terminal", title: AppText.logs.localized(theme.language), action: onOpenLogs)
        GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Export Diagnostics", chinese: "导出诊断", italian: "Esporta diagnostica", french: "Exporter diagnostic", spanish: "Exportar diagnóstico"), action: onExportDiagnostics)
        GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta"), action: onOpenFolder)
        if record.state == .interrupted {
            GlassButton(systemImage: "checkmark", title: localizedString(theme.language, english: "Ignore", chinese: "忽略", italian: "Ignora", french: "Ignorer", spanish: "Ignorar"), action: onDismiss)
        }
    }
}

private struct TaskRecentCompletedSection: View {
    let records: [TaskRecord]
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(showsShadow: false) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(localizedString(theme.language, english: "Recent Completed", chinese: "最近完成", italian: "Completate di recente", french: "Récemment terminées", spanish: "Completadas recientes"))
                        .font(.headline)
                    Spacer()
                    CountText(value: records.count, style: .success)
                }
                if records.isEmpty {
                    Text(localizedString(theme.language, english: "No completed tasks yet.", chinese: "暂时没有已完成任务。", italian: "Nessuna attività completata.", french: "Aucune tâche terminée.", spanish: "No hay tareas completadas."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 62)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                        ForEach(records) { record in
                            TaskCompactCard(record: record)
                        }
                    }
                }
            }
        }
    }
}

private struct TaskHistorySection: View {
    let records: [TaskRecord]
    @Binding var isExpanded: Bool
    let selectedRecordID: String?
    @Binding var filter: TaskHistoryFilter
    @Binding var retentionPolicy: TaskHistoryRetentionPolicy
    let clearStatus: String?
    let onSelect: (TaskRecord) -> Void
    let onClear: (TaskClearAction) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(showsShadow: false) {
            FullWidthDisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Picker("", selection: $filter) {
                            ForEach(TaskHistoryFilter.allCases) { item in
                                Text(item.title(language: theme.language)).tag(item)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 520)

                        Picker("", selection: $retentionPolicy) {
                            ForEach(TaskHistoryRetentionPolicy.allCases) { policy in
                                Text(policy.title(language: theme.language)).tag(policy)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 190)

                        Spacer()

                        TaskClearMenu(onClear: onClear)
                    }

                    if let clearStatus {
                        Text(clearStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if records.isEmpty {
                        ContentUnavailableView(
                            localizedString(theme.language, english: "No History", chinese: "没有历史", italian: "Nessuna cronologia", french: "Aucun historique", spanish: "Sin historial"),
                            systemImage: "tray",
                            description: Text(localizedString(theme.language, english: "Finished tasks appear here after downloads, installs, launches or diagnostics.", chinese: "下载、安装、启动或诊断结束后会显示在这里。", italian: "Le attività finite appariranno qui.", french: "Les tâches terminées apparaissent ici.", spanish: "Las tareas finalizadas aparecerán aquí."))
                        )
                        .frame(minHeight: 140)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(records) { record in
                                TaskRecordRow(
                                    record: record,
                                    isSelected: selectedRecordID == record.id
                                ) {
                                    onSelect(record)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10)
            } label: {
                HStack {
                    Text(localizedString(theme.language, english: "Task History", chinese: "任务历史", italian: "Cronologia attività", french: "Historique des tâches", spanish: "Historial de tareas"))
                        .font(.headline)
                    Spacer()
                    CountText(value: records.count)
                }
            }
        }
    }
}

private struct TaskClearMenu: View {
    let onClear: (TaskClearAction) -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Menu {
            Button(TaskClearAction.completed.title(language: theme.language)) { onClear(.completed) }
            Button(TaskClearAction.cancelledAndInterrupted.title(language: theme.language)) { onClear(.cancelledAndInterrupted) }
            Button(TaskClearAction.failed.title(language: theme.language)) { onClear(.failed) }
            Button(TaskClearAction.allFinishedKeepingFailures.title(language: theme.language)) { onClear(.allFinishedKeepingFailures) }
            Divider()
            Button(TaskClearAction.allFinished.title(language: theme.language), role: .destructive) { onClear(.allFinished) }
            Button(TaskClearAction.allHistory.title(language: theme.language), role: .destructive) { onClear(.allHistory) }
        } label: {
            Label(localizedString(theme.language, english: "Clean Up", chinese: "清理", italian: "Pulisci", french: "Nettoyer", spanish: "Limpiar"), systemImage: "trash")
        }
        .menuStyle(.button)
        .fixedSize()
    }
}

private struct TaskCompactCard: View {
    let record: TaskRecord
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                TaskStateLine(title: record.state.title(language: theme.language), style: record.state.badgeStyle)
            }
            Text(record.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(minHeight: 96, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.30), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct TaskRecordRow: View {
    let record: TaskRecord
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(record.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Text(record.finishedAt?.formatted(date: .abbreviated, time: .shortened) ?? record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                TaskStateLine(title: record.state.title(language: theme.language), style: record.state.badgeStyle)
            }
            .padding(.horizontal, 12)
            .frame(height: 64)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.72) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(record.name), \(record.state.title(language: theme.language)), \(record.message)")
    }

    private var rowBackground: Color {
        isSelected ? theme.semanticSelectionColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.30)
    }
}

private struct TaskRecordDetailSheet: View {
    let record: TaskRecord
    let canRetry: Bool
    let onRetry: () -> Void
    let onOpenLogs: () -> Void
    let onExportDiagnostics: () -> Void
    let onOpenFolder: () -> Void
    let diagnosticActionTitle: String?
    let diagnosticActionSystemImage: String
    let onDiagnosticAction: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.dismiss) private var dismiss
    private var recoveryRecords: [TaskRecoveryRecord] {
        TaskRecoveryRecord.records(for: record)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.name)
                        .font(.title3.weight(.semibold))
                    Text(record.kindTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TaskStateLine(title: record.state.title(language: theme.language), style: record.state.badgeStyle)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                TaskFact(title: localizedString(theme.language, english: "Version", chinese: "版本", italian: "Versione", french: "Version", spanish: "Versión"), value: record.version.isEmpty ? "-" : record.version)
                TaskFact(title: localizedString(theme.language, english: "Created", chinese: "创建", italian: "Creato", french: "Créée", spanish: "Creada"), value: record.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "-")
                TaskFact(title: localizedString(theme.language, english: "Finished", chinese: "结束", italian: "Terminato", french: "Terminée", spanish: "Finalizada"), value: record.finishedAt?.formatted(date: .abbreviated, time: .shortened) ?? "-")
                TaskFact(title: localizedString(theme.language, english: "Error", chinese: "错误", italian: "Errore", french: "Erreur", spanish: "Error"), value: record.errorCode ?? "-")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString(theme.language, english: "Message", chinese: "消息", italian: "Messaggio", french: "Message", spanish: "Mensaje"))
                    .font(.headline)
                Text(record.message)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.32), in: RoundedRectangle(cornerRadius: 8))
            }

            if !recoveryRecords.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedString(theme.language, english: "Recovery Records", chinese: "可回滚记录", italian: "Registri di ripristino", french: "Journaux de restauration", spanish: "Registros de reversión"))
                        .font(.headline)
                    ForEach(recoveryRecords) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: item.systemImage)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title.localized(theme.language))
                                    .font(.callout.weight(.medium))
                                Text(item.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            if record.state.needsAttention {
                Text(record.advice.localizedRecoveryAdvice(theme.language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            HStack {
                GlassButton(systemImage: "xmark", title: AppText.cancel.localized(theme.language)) {
                    dismiss()
                }
                Spacer()
                GlassButton(systemImage: "terminal", title: AppText.logs.localized(theme.language), action: onOpenLogs)
                GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Export Diagnostics", chinese: "导出诊断", italian: "Esporta diagnostica", french: "Exporter diagnostic", spanish: "Exportar diagnóstico"), action: onExportDiagnostics)
                GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta"), action: onOpenFolder)
                if let diagnosticActionTitle {
                    GlassButton(systemImage: diagnosticActionSystemImage, title: diagnosticActionTitle, prominent: !canRetry, action: onDiagnosticAction)
                }
                if canRetry {
                    GlassButton(systemImage: "arrow.clockwise", title: localizedString(theme.language, english: "Retry", chinese: "重试", italian: "Riprova", french: "Réessayer", spanish: "Reintentar"), prominent: true, action: onRetry)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
    }
}

private struct TaskRecoveryRecord: Identifiable, Equatable {
    let id: String
    let title: TaskRecoveryTitle
    let path: String
    let systemImage: String

    static func records(for record: TaskRecord) -> [TaskRecoveryRecord] {
        var records: [TaskRecoveryRecord] = []
        let combinedText = [record.message, record.errorDetail].compactMap { $0 }.joined(separator: "\n")
        appendMarkerRecord(
            to: &records,
            id: "rollback",
            title: TaskRecoveryTitle(english: "Rollback Record", chinese: "回滚记录", italian: "Registro rollback", french: "Journal de restauration", spanish: "Registro de reversión"),
            systemImage: "arrow.uturn.backward.circle",
            markers: ["Rollback record:", "回滚记录："],
            in: combinedText
        )
        appendMarkerRecord(
            to: &records,
            id: "plan",
            title: TaskRecoveryTitle(english: "Install Plan", chinese: "安装计划", italian: "Piano installazione", french: "Plan d'installation", spanish: "Plan de instalación"),
            systemImage: "list.bullet.rectangle",
            markers: ["Plan:", "计划："],
            in: combinedText
        )
        appendMarkerRecord(
            to: &records,
            id: "execution",
            title: TaskRecoveryTitle(english: "Execution Result", chinese: "执行结果", italian: "Risultato esecuzione", french: "Résultat d'exécution", spanish: "Resultado de ejecución"),
            systemImage: "checklist",
            markers: ["Execution:", "执行："],
            in: combinedText
        )

        if records.isEmpty, let gameDir = record.gameDir?.trimmingCharacters(in: .whitespacesAndNewlines), !gameDir.isEmpty {
            records.append(contentsOf: inferredRecords(kind: record.kind, gameDir: gameDir))
        }
        return deduped(records)
    }

    private static func appendMarkerRecord(
        to records: inout [TaskRecoveryRecord],
        id: String,
        title: TaskRecoveryTitle,
        systemImage: String,
        markers: [String],
        in text: String
    ) {
        for marker in markers {
            if let path = path(after: marker, in: text) {
                records.append(TaskRecoveryRecord(id: id, title: title, path: path, systemImage: systemImage))
                return
            }
        }
    }

    private static func path(after marker: String, in text: String) -> String? {
        guard let markerRange = text.range(of: marker) else { return nil }
        let tail = text[markerRange.upperBound...]
        let terminators = [" Rollback record:", " Plan:", " Execution:", " 回滚记录：", " 计划：", " 执行：", "\n"]
        let end = terminators
            .compactMap { token in tail.range(of: token)?.lowerBound }
            .min() ?? tail.endIndex
        let path = String(tail[..<end])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".)"))
        return path.isEmpty ? nil : path
    }

    private static func inferredRecords(kind: String, gameDir: String) -> [TaskRecoveryRecord] {
        let lowered = kind.lowercased()
        if lowered.contains("performance-pack") {
            return [
                TaskRecoveryRecord(
                    id: "performance-pack-lock",
                    title: TaskRecoveryTitle(english: "Rollback Record", chinese: "回滚记录", italian: "Registro rollback", french: "Journal de restauration", spanish: "Registro de reversión"),
                    path: "\(gameDir)/downloads/performance-pack-lock.json",
                    systemImage: "arrow.uturn.backward.circle"
                )
            ]
        }
        if lowered.contains("content") {
            return [
                TaskRecoveryRecord(
                    id: "content-install-lock",
                    title: TaskRecoveryTitle(english: "Rollback Record", chinese: "回滚记录", italian: "Registro rollback", french: "Journal de restauration", spanish: "Registro de reversión"),
                    path: "\(gameDir)/downloads/content-install-lock.json",
                    systemImage: "arrow.uturn.backward.circle"
                ),
                TaskRecoveryRecord(
                    id: "install-plan-graph",
                    title: TaskRecoveryTitle(english: "Install Plan", chinese: "安装计划", italian: "Piano installazione", french: "Plan d'installation", spanish: "Plan de instalación"),
                    path: "\(gameDir)/downloads/install-plan-graph.json",
                    systemImage: "list.bullet.rectangle"
                ),
                TaskRecoveryRecord(
                    id: "install-plan-execution",
                    title: TaskRecoveryTitle(english: "Execution Result", chinese: "执行结果", italian: "Risultato esecuzione", french: "Résultat d'exécution", spanish: "Resultado de ejecución"),
                    path: "\(gameDir)/downloads/install-plan-execution.json",
                    systemImage: "checklist"
                )
            ]
        }
        return []
    }

    private static func deduped(_ records: [TaskRecoveryRecord]) -> [TaskRecoveryRecord] {
        var seen = Set<String>()
        return records.filter { record in
            let key = record.path
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}

private struct TaskRecoveryTitle: Equatable {
    let english: String
    let chinese: String
    let italian: String
    let french: String
    let spanish: String

    func localized(_ language: AppLanguage) -> String {
        localizedString(language, english: english, chinese: chinese, italian: italian, french: french, spanish: spanish)
    }
}

private enum TaskClearAction: CaseIterable, Identifiable {
    case completed
    case cancelledAndInterrupted
    case failed
    case allFinishedKeepingFailures
    case allFinished
    case allHistory

    var id: String { String(describing: self) }

    var requiresConfirmation: Bool {
        self == .allFinished || self == .allHistory
    }

    var coreStatuses: [String] {
        switch self {
        case .completed:
            return ["succeeded"]
        case .cancelledAndInterrupted:
            return ["cancelled"]
        case .failed:
            return ["failed"]
        case .allFinishedKeepingFailures:
            return ["succeeded", "cancelled", "failed"]
        case .allFinished, .allHistory:
            return ["succeeded", "failed", "cancelled"]
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .completed:
            return localizedString(language, english: "Clear completed", chinese: "清理已完成", italian: "Cancella completate", french: "Effacer terminées", spanish: "Borrar completadas")
        case .cancelledAndInterrupted:
            return localizedString(language, english: "Clear cancelled/interrupted", chinese: "清理取消/中断", italian: "Cancella annullate/interrotte", french: "Effacer annulées/interrompues", spanish: "Borrar canceladas/interrumpidas")
        case .failed:
            return localizedString(language, english: "Clear failed", chinese: "清理失败项", italian: "Cancella fallite", french: "Effacer échecs", spanish: "Borrar fallidas")
        case .allFinishedKeepingFailures:
            return localizedString(language, english: "Clear finished, keep failures", chinese: "清理完成项，保留失败", italian: "Cancella finite, conserva errori", french: "Effacer terminées, garder échecs", spanish: "Borrar finalizadas, conservar fallos")
        case .allFinished:
            return localizedString(language, english: "Clear all finished", chinese: "清理全部结束任务", italian: "Cancella tutte finite", french: "Effacer toutes terminées", spanish: "Borrar todas finalizadas")
        case .allHistory:
            return localizedString(language, english: "Clear all history", chinese: "清空全部历史", italian: "Cancella tutta cronologia", french: "Effacer tout l'historique", spanish: "Borrar todo el historial")
        }
    }

    func statusMessage(language: AppLanguage, localDeleted: Int, coreSummary: CoreTaskHistoryClearResponse?) -> String {
        if let coreSummary {
            return localizedString(
                language,
                english: "Cleaned \(localDeleted) local records. Core deleted \(coreSummary.deleted), kept \(coreSummary.kept), skipped \(coreSummary.skippedActive) active.",
                chinese: "已清理 \(localDeleted) 条本地记录。Core 删除 \(coreSummary.deleted) 条，保留 \(coreSummary.kept) 条，跳过 \(coreSummary.skippedActive) 条活动任务。",
                italian: "Puliti \(localDeleted) record locali. Core ha eliminato \(coreSummary.deleted), mantenuto \(coreSummary.kept), saltato \(coreSummary.skippedActive) attive.",
                french: "\(localDeleted) entrées locales nettoyées. Core a supprimé \(coreSummary.deleted), gardé \(coreSummary.kept), ignoré \(coreSummary.skippedActive) actives.",
                spanish: "Se limpiaron \(localDeleted) registros locales. Core eliminó \(coreSummary.deleted), conservó \(coreSummary.kept), omitió \(coreSummary.skippedActive) activas."
            )
        }
        return localizedString(
            language,
            english: "Cleaned \(localDeleted) local records. Core was unavailable; active tasks were still preserved locally.",
            chinese: "已清理 \(localDeleted) 条本地记录。Core 暂不可用，本地仍保留活动任务。",
            italian: "Puliti \(localDeleted) record locali. Core non disponibile; attività attive conservate localmente.",
            french: "\(localDeleted) entrées locales nettoyées. Core indisponible ; tâches actives conservées localement.",
            spanish: "Se limpiaron \(localDeleted) registros locales. Core no disponible; tareas activas conservadas localmente."
        )
    }
}

private extension TaskHistoryRetentionPolicy {
    func title(language: AppLanguage) -> String {
        switch self {
        case .recent20:
            return localizedString(language, english: "Recent 20", chinese: "最近 20 条", italian: "Recenti 20", french: "20 récentes", spanish: "20 recientes")
        case .recent50:
            return localizedString(language, english: "Recent 50", chinese: "最近 50 条", italian: "Recenti 50", french: "50 récentes", spanish: "50 recientes")
        case .sevenDays:
            return localizedString(language, english: "7 days", chinese: "7 天内", italian: "7 giorni", french: "7 jours", spanish: "7 días")
        case .failuresOnly:
            return localizedString(language, english: "Failures only", chinese: "仅失败/中断", italian: "Solo errori", french: "Échecs seulement", spanish: "Solo fallos")
        }
    }
}

struct LogsPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @EnvironmentObject private var taskCenterStore: TaskCenterStore
    @State private var areLogsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            if let context = errorContext {
                ErrorDetailPanel(context: context, onCopy: copyErrorContext, onCopyRepro: copyMinimumRepro, onExportDiagnostics: exportDiagnostics)
                collapsedLogConsole
            } else {
                logConsole(showsPanel: true, scrollMinHeight: 320)
                    .frame(minHeight: 420)
            }
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 620)
    }

    private var collapsedLogConsole: some View {
        GlassPanel(showsShadow: false) {
            FullWidthDisclosureGroup(isExpanded: $areLogsExpanded) {
                logConsole(showsPanel: false, scrollMinHeight: 220)
                    .padding(.top, 12)
            } label: {
                HStack(spacing: 10) {
                    Text(localizedString(theme.language, english: "Logs", chinese: "日志详情", italian: "Log", french: "Journaux", spanish: "Registros"))
                        .font(.headline)
                    CountText(value: displayedLogCount)
                    Text(localizedString(theme.language, english: "Expand only when you need raw Core/Game output.", chinese: "仅在需要原始 Core/游戏输出时展开。", italian: "Espandi solo se servono i log grezzi.", french: "Dépliez seulement si les journaux bruts sont nécessaires.", spanish: "Expande solo si necesitas la salida sin procesar."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }

    private func logConsole(showsPanel: Bool, scrollMinHeight: CGFloat) -> some View {
        LogConsole(
            title: AppText.coreLogs.localized(theme.language),
            logs: coreLogsForDisplay,
            gameLogs: gameLogsForDisplay,
            exportedURL: viewModel.lastExportedLogURL,
            diagnosticURL: diagnosticsStore.lastDiagnosticURL,
            showsPanel: showsPanel,
            scrollMinHeight: scrollMinHeight,
            onExport: {
                viewModel.exportLogs()
                taskCenterStore.enqueueLocal(
                    kind: "log-export",
                    name: localizedString(theme.language, english: "Log Export", chinese: "日志导出", italian: "Esportazione log", french: "Export des journaux", spanish: "Exportación de registros"),
                    message: localizedString(theme.language, english: "Launcher log export requested.", chinese: "已请求导出启动器日志。", italian: "Export log launcher richiesto.", french: "Export des journaux du lanceur demandé.", spanish: "Se solicitó exportar registros del launcher.")
                )
            },
            onClear: viewModel.clearLogs,
            onExportDiagnostics: exportDiagnostics
        )
    }

    private var errorContext: ErrorDetailContext? {
        if let selected = taskCenterStore.selectedRecord, taskCenterStore.isActionableAttention(selected) {
            let insight = TaskFailureInsight(record: selected, language: theme.language)
            let summary = [selected.kind, selected.version, selected.errorCode ?? "no-error-code"].joined(separator: " / ")
            let diagnostic = selected.diagnostic ?? selected.diagnostics?.first
            let diagnosticDetail = diagnostic.map { diagnostic in
                let evidenceLines = diagnostic.evidence.map { evidence in
                    "Evidence: \(evidence.key)=\(evidence.value)\(evidence.redacted ? " (redacted)" : "")"
                }
                return ([
                    "Diagnostic: \(diagnostic.code)",
                    "Phase: \(diagnostic.phase)",
                    "Source: \(diagnostic.source)",
                    diagnostic.filePath.map { "File: \($0)" },
                    diagnostic.planId.map { "Plan: \($0)" },
                    diagnostic.packageId.map { "Package: \($0)" },
                    diagnostic.urlHost.map { "Host: \($0)" },
                    diagnostic.developerDetail
                ] + evidenceLines)
                .compactMap { $0 }
                .joined(separator: "\n")
            }
            let technicalDetail = [summary, diagnosticDetail, selected.errorDetail]
                .compactMap { value in
                    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                    return value
                }
                .joined(separator: "\n")
            return ErrorDetailContext(
                title: selected.state == .interrupted
                    ? localizedString(theme.language, english: "Task Interrupted", chinese: "任务已中断", italian: "Attività interrotta", french: "Tâche interrompue", spanish: "Tarea interrumpida")
                    : localizedString(theme.language, english: "Task Failed", chinese: "任务失败", italian: "Attività fallita", french: "Échec de la tâche", spanish: "Tarea fallida"),
                userSummary: diagnostic?.userSummary ?? insight.userSummary ?? selected.message,
                technicalDetail: technicalDetail,
                causes: mergedDiagnosticItems(
                    [diagnostic?.cause].compactMap { $0 } + insight.causes,
                    recoveryCauses(errorCode: selected.errorCode, language: theme.language)
                ),
                actions: mergedDiagnosticItems(
                    [diagnostic?.actionLabel].compactMap { $0 } + insight.actions,
                    recoveryActions(errorCode: selected.errorCode, language: theme.language)
                )
            )
        }

        if case .failed(let message) = viewModel.coreState {
            return ErrorDetailContext(
                title: localizedString(theme.language, english: "Core Error", chinese: "Core 错误", italian: "Errore Core", french: "Erreur Core", spanish: "Error de Core"),
                userSummary: message,
                technicalDetail: viewModel.coreState.detail,
                causes: [
                    localizedString(theme.language, english: "Core process crashed or failed to start.", chinese: "Core 进程崩溃或启动失败。", italian: "Il processo Core è terminato o non è partito.", french: "Le processus Core a planté ou n'a pas démarré.", spanish: "El proceso Core falló o no arrancó."),
                    localizedString(theme.language, english: "Local port, permissions, or bundled runtime may be unavailable.", chinese: "本地端口、权限或内置运行时可能不可用。", italian: "Porta locale, permessi o runtime integrato potrebbero non essere disponibili.", french: "Le port local, les permissions ou le runtime intégré peuvent être indisponibles.", spanish: "El puerto local, permisos o runtime integrado pueden no estar disponibles.")
                ],
                actions: [
                    localizedString(theme.language, english: "Start Core again; the launcher restarts it once automatically after a crash.", chinese: "重新启动 Core；崩溃后启动器会自动重启一次。", italian: "Riavvia Core; il launcher lo riavvia automaticamente una volta dopo un crash.", french: "Redémarrez Core ; le lanceur le relance une fois automatiquement après un plantage.", spanish: "Inicia Core de nuevo; el launcher lo reinicia una vez tras un cierre inesperado."),
                    localizedString(theme.language, english: "Export diagnostics and inspect app.log/core.log if it fails again.", chinese: "再次失败时导出诊断包并检查 app.log/core.log。", italian: "Esporta diagnostica e controlla app.log/core.log se fallisce ancora.", french: "Exportez le diagnostic et inspectez app.log/core.log si l'échec persiste.", spanish: "Exporta diagnóstico y revisa app.log/core.log si vuelve a fallar.")
                ]
            )
        }

        if case .failed(let message) = viewModel.accountState {
            return ErrorDetailContext(
                title: localizedString(theme.language, english: "Account Error", chinese: "账号错误", italian: "Errore account", french: "Erreur de compte", spanish: "Error de cuenta"),
                userSummary: message,
                technicalDetail: message,
                causes: [
                    localizedString(theme.language, english: "The login session expired or Microsoft returned an authentication error.", chinese: "登录会话过期，或 Microsoft 返回了认证错误。", italian: "La sessione è scaduta o Microsoft ha restituito un errore.", french: "La session a expiré ou Microsoft a renvoyé une erreur d'authentification.", spanish: "La sesión expiró o Microsoft devolvió un error de autenticación.")
                ],
                actions: [
                    localizedString(theme.language, english: "Re-authenticate the default account from the Account page.", chinese: "在账号页面重新登录默认账号。", italian: "Riautentica l'account predefinito dalla pagina Account.", french: "Réauthentifiez le compte par défaut depuis la page Compte.", spanish: "Reautentica la cuenta predeterminada desde Cuenta.")
                ]
            )
        }

        return nil
    }

    private var gameLogsForDisplay: [LogLine] {
        viewModel.logs.filter { $0.source == .game }
    }

    private var displayedLogCount: Int {
        diagnosticsStore.filteredLogs(coreLogs: coreLogsForDisplay, gameLogs: gameLogsForDisplay).count
    }

    private var coreLogsForDisplay: [LogLine] {
        let coreLogs = viewModel.logs.filter { $0.source == .core }
        guard coreLogs.isEmpty,
              let selected = taskCenterStore.selectedRecord,
              taskCenterStore.isActionableAttention(selected)
        else {
            return coreLogs
        }

        let detail = selected.errorDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = [
            "Task \(selected.id) \(selected.state.rawValue): \(selected.kind) \(selected.version)",
            "Error code: \(selected.errorCode ?? "no-error-code")",
            "Message: \(selected.message)"
        ]
        if let detail, !detail.isEmpty {
            lines.append("Detail: \(detail)")
        }
        let logLines = lines.map { LogLine(text: $0, source: .core) }
        return logLines
    }

    private func exportDiagnostics() {
        diagnosticsStore.exportDiagnosticPackage(
            logs: logsForDiagnosticExport,
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

    private var logsForDiagnosticExport: [LogLine] {
        if viewModel.logs.contains(where: { $0.source == .core }) {
            return viewModel.logs
        }
        return viewModel.logs + coreLogsForDisplay
    }

    private func copyErrorContext(_ context: ErrorDetailContext) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context.copyText, forType: .string)
    }

    private func copyMinimumRepro(_ context: ErrorDetailContext) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context.minimumReproText, forType: .string)
    }

    private func mergedDiagnosticItems(_ primary: [String], _ fallback: [String]) -> [String] {
        var result: [String] = []
        for item in primary + fallback where !result.contains(item) {
            result.append(item)
        }
        return Array(result.prefix(4))
    }
}

private struct TaskFailureInsight {
    let userSummary: String?
    let causes: [String]
    let actions: [String]

    init(record: TaskRecord, language: AppLanguage) {
        let sourceText = [record.message, record.errorDetail, record.errorCode]
            .compactMap { $0 }
            .joined(separator: "\n")
        let lowercased = sourceText.lowercased()
        let dependencies = Self.matches(in: sourceText, pattern: #"requires\s+([A-Za-z0-9_.+\-]+)"#)
        let affectedMods = Self.matches(in: sourceText, pattern: #"([A-Za-z0-9_.+\-]+\.jar)\s+requires"#)

        if lowercased.contains("required mod dependencies are missing") || lowercased.contains("dependencies are missing") {
            let dependencyList = dependencies.isEmpty
                ? localizedString(language, english: "one or more dependencies", chinese: "一个或多个依赖", italian: "una o più dipendenze", french: "une ou plusieurs dépendances", spanish: "una o más dependencias")
                : Self.listSummary(dependencies)
            let modList = affectedMods.isEmpty
                ? localizedString(language, english: "an installed mod", chinese: "某个已安装 Mod", italian: "una mod installata", french: "un mod installé", spanish: "un mod instalado")
                : Self.listSummary(affectedMods)
            let shouldRecommendFabricAPI = dependencies.isEmpty || dependencies.contains { $0.lowercased().hasPrefix("fabric-") }
            userSummary = localizedString(
                language,
                english: "This instance cannot start because \(modList) is missing required dependencies: \(dependencyList).",
                chinese: "这个实例暂时不能启动：\(modList) 缺少必需依赖：\(dependencyList)。",
                italian: "Questa istanza non può avviarsi perché \(modList) non trova le dipendenze richieste: \(dependencyList).",
                french: "Cette instance ne peut pas démarrer car \(modList) n'a pas les dépendances requises : \(dependencyList).",
                spanish: "Esta instancia no puede iniciarse porque \(modList) no tiene las dependencias requeridas: \(dependencyList)."
            )
            causes = [
                localizedString(
                    language,
                    english: "A mod was installed without its required dependency modules.",
                    chinese: "有 Mod 已安装，但它依赖的模块没有一起安装。",
                    italian: "Una mod è installata senza i moduli dipendenti richiesti.",
                    french: "Un mod est installé sans ses modules dépendants requis.",
                    spanish: "Un mod está instalado sin sus módulos de dependencia requeridos."
                ),
                localizedString(
                    language,
                    english: "The installed dependency version may not match this Minecraft/loader version.",
                    chinese: "已安装的依赖版本也可能不匹配当前 Minecraft/加载器版本。",
                    italian: "La versione della dipendenza può non corrispondere a Minecraft/loader.",
                    french: "La version de dépendance installée peut ne pas correspondre à Minecraft/loader.",
                    spanish: "La versión de dependencia instalada puede no coincidir con Minecraft/loader."
                )
            ]
            actions = [
                shouldRecommendFabricAPI
                    ? localizedString(
                        language,
                        english: "Install Fabric API compatible with this Minecraft version into the selected instance.",
                        chinese: "在当前实例中安装与该 Minecraft 版本兼容的 Fabric API。",
                        italian: "Installa Fabric API compatibile con questa versione Minecraft nell'istanza.",
                        french: "Installez Fabric API compatible avec cette version Minecraft dans l'instance.",
                        spanish: "Instala Fabric API compatible con esta versión de Minecraft en la instancia."
                    )
                    : localizedString(
                        language,
                        english: "Install the missing dependency mods listed above into the selected instance.",
                        chinese: "把上面列出的缺失依赖 Mod 安装到当前实例。",
                        italian: "Installa nell'istanza le mod dipendenti mancanti elencate sopra.",
                        french: "Installez dans l'instance les mods de dépendance manquants ci-dessus.",
                        spanish: "Instala en la instancia los mods de dependencia faltantes indicados arriba."
                    ),
                localizedString(
                    language,
                    english: "If the dependency cannot be installed, remove or update the affected mod, then launch again.",
                    chinese: "如果依赖无法安装，请移除或更新相关 Mod，然后重新启动。",
                    italian: "Se la dipendenza non è installabile, rimuovi o aggiorna la mod e riavvia.",
                    french: "Si la dépendance ne peut pas être installée, retirez ou mettez à jour le mod, puis relancez.",
                    spanish: "Si no puedes instalar la dependencia, elimina o actualiza el mod afectado y vuelve a iniciar."
                )
            ]
            return
        }

        userSummary = nil
        causes = []
        actions = []
    }

    private static func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var values: [String] = []
        for match in regex.matches(in: text, options: [], range: nsRange) {
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { continue }
            let value = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: " .;,)"))
            guard !value.isEmpty, !values.contains(value) else { continue }
            values.append(value)
        }
        return values
    }

    private static func listSummary(_ values: [String]) -> String {
        guard !values.isEmpty else { return "unknown dependency" }
        let visible = values.prefix(3)
        if values.count > visible.count {
            return visible.joined(separator: ", ") + " +\(values.count - visible.count)"
        }
        return visible.joined(separator: ", ")
    }
}
