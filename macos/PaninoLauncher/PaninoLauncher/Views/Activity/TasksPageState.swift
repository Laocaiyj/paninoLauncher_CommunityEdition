extension TasksPage {
    var focusedRecord: TaskRecord? {
        if let currentTask = viewModel.currentTask,
           let record = taskCenterStore.records.first(where: { $0.id == currentTask.taskId }) {
            return record
        }
        return taskCenterStore.activeRecords.first
    }

    var filteredHistoryRecords: [TaskRecord] {
        taskCenterStore.historyRecords.filter { historyFilter.includes($0) }
    }

    var summaryRetryRecord: TaskRecord? {
        if let focusedRecord, canRetryAutomatically(focusedRecord) {
            return focusedRecord
        }
        return selectedRetryRecord.flatMap { canRetryAutomatically($0) ? $0 : nil }
    }

    func retryTargetDescription(_ record: TaskRecord) -> String {
        TaskRetrySupport.targetDescription(for: record, language: theme.language)
    }

    func canRetryAutomatically(_ record: TaskRecord) -> Bool {
        TaskRetrySupport.canRetryAutomatically(record)
    }

    private var selectedRetryRecord: TaskRecord? {
        if let selected = taskCenterStore.selectedRecord, taskCenterStore.isActionableAttention(selected) {
            return selected
        }
        return taskCenterStore.attentionRecords.first
    }
}
