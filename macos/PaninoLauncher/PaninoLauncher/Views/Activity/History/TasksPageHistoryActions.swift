import SwiftUI

extension TasksPage {
    func requestClear(_ action: TaskClearAction) {
        if action.requiresConfirmation {
            clearConfirmation = action
        } else {
            performClear(action)
        }
    }

    func performClear(_ action: TaskClearAction) {
        clearConfirmation = nil
        Task {
            let coreSummary = await clearHistoryInCore(action)
            let localDeleted = clearHistoryLocally(action)
            clearStatus = action.statusMessage(language: theme.language, localDeleted: localDeleted, coreSummary: coreSummary)
        }
    }

    func refreshCoreHistory() async {
        do {
            let response = try await viewModel.taskHistory(limit: 80)
            taskCenterStore.mergeCoreHistory(response.tasks)
        } catch {
            clearStatus = nil
        }
    }

    func moveHistorySelection(_ direction: MoveCommandDirection) {
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
}
