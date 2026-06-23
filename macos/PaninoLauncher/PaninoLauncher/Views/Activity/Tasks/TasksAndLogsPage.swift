import SwiftUI

struct TasksPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    let openDiagnostics: () -> Void

    @EnvironmentObject var theme: ThemeSettings
    @EnvironmentObject var taskCenterStore: TaskCenterStore
    @EnvironmentObject var diagnosticsStore: DiagnosticsStore
    @EnvironmentObject var launcherSettings: LauncherSettings
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var instanceStore: InstanceStore
    @EnvironmentObject var appActions: AppActionCenter

    @State var historyFilter: TaskHistoryFilter = .all
    @State var clearConfirmation: TaskClearAction?
    @State var clearStatus: String?
    @State var detailRecord: TaskRecord?

    var body: some View {
        TaskFocusStage(
            record: focusedRecord,
            coreStatus: viewModel.coreState.localizedTitle(theme.language),
            attentionCount: taskCenterStore.attentionRecords.count,
            canCancel: viewModel.canCancelTask,
            canRetry: summaryRetryRecord != nil,
            recentCompletedRecords: taskCenterStore.recentCompletedRecords,
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
                diagnosticActionTitle: TaskRetrySupport.diagnosticActionTitle(for: record, canRetryAutomatically: canRetryAutomatically(record)),
                diagnosticActionSystemImage: TaskRetrySupport.diagnosticActionSystemImage(for: record),
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
                    diagnosticActionTitle: { TaskRetrySupport.diagnosticActionTitle(for: $0, canRetryAutomatically: canRetryAutomatically($0)) },
                    diagnosticActionSystemImage: { TaskRetrySupport.diagnosticActionSystemImage(for: $0) },
                    onDiagnosticAction: { performDiagnosticAction($0) }
                )
                .frame(maxWidth: 760, alignment: .leading)
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
}
