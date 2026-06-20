import Foundation

@MainActor
extension TaskCenterStore {
    @discardableResult
    func clearCompleted() -> Int {
        clearRecords { $0.state == .succeeded }
    }

    @discardableResult
    func clearCancelledAndInterrupted() -> Int {
        clearRecords { $0.state == .cancelled || $0.state == .interrupted }
    }

    @discardableResult
    func clearFailed() -> Int {
        clearRecords { $0.state == .failed }
    }

    @discardableResult
    func clearAllFinished() -> Int {
        clearRecords { $0.state.isTerminal }
    }

    @discardableResult
    func clearAllHistory(keepActive: Bool = true) -> Int {
        clearRecords { keepActive ? $0.state.isTerminal : true }
    }

    @discardableResult
    func clearMatching(statuses: Set<TaskRecordState>, olderThanDays: Int? = nil, keepFailed: Bool = false) -> Int {
        let now = Date()
        return clearRecords { record in
            guard statuses.contains(record.state), record.state.isTerminal else { return false }
            if keepFailed, record.state == .failed { return false }
            if let olderThanDays {
                let basis = record.finishedAt ?? record.updatedAt
                return now.timeIntervalSince(basis) >= Double(olderThanDays * 86_400)
            }
            return true
        }
    }

    @discardableResult
    private func clearRecords(where shouldRemove: (TaskRecord) -> Bool) -> Int {
        let previousCount = records.count
        records.removeAll { record in
            guard !record.state.isActive else { return false }
            return shouldRemove(record)
        }
        records = TaskCenterHistoryPruner.pruned(records, retentionPolicy: retentionPolicy)
        updateSelectionAfterMutation()
        return previousCount - records.count
    }
}
