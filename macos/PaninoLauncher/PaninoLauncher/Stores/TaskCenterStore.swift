import Foundation
import SwiftUI

@MainActor
final class TaskCenterStore: ObservableObject {
    @Published var records: [TaskRecord] = [] {
        didSet {
            guard !isLoading else { return }
            save()
        }
    }

    @Published var selectedRecordID: String?
    @Published var retentionPolicy: TaskHistoryRetentionPolicy = TaskCenterStore.storedRetentionPolicy() {
        didSet {
            SettingsStore.set(retentionPolicy.rawValue, forKey: Self.retentionPolicyKey)
            guard !isLoading else { return }
            records = TaskCenterHistoryPruner.pruned(records, retentionPolicy: retentionPolicy)
            updateSelectionAfterMutation()
        }
    }

    @Published private(set) var statusMessage = "Tasks not loaded"
    private var isLoading = false

    init() {
        load()
        markUnfinishedTasksInterrupted()
        pruneHistory()
    }

    var selectedRecord: TaskRecord? {
        records.first { $0.id == selectedRecordID } ?? records.first
    }

    var activeRecords: [TaskRecord] {
        TaskCenterHistoryPruner.sorted(records.filter { $0.state.isActive })
    }

    var attentionRecords: [TaskRecord] {
        TaskCenterHistoryPruner.actionableAttentionRecords(in: records)
    }

    var interruptedTasks: [TaskRecord] {
        TaskCenterHistoryPruner.sorted(records.filter { $0.state == .interrupted })
    }

    var recentCompletedRecords: [TaskRecord] {
        Array(TaskCenterHistoryPruner.sorted(records.filter { $0.state == .succeeded }).prefix(3))
    }

    var historyRecords: [TaskRecord] {
        TaskCenterHistoryPruner.sorted(records.filter { !$0.state.isActive })
    }

    func pruneHistory() {
        records = TaskCenterHistoryPruner.pruned(records, retentionPolicy: retentionPolicy)
        updateSelectionAfterMutation()
    }

    func upsert(_ record: TaskRecord) {
        var next = records
        if let index = next.firstIndex(where: { $0.id == record.id }) {
            var updated = record
            updated.createdAt = next[index].createdAt ?? record.createdAt
            next[index] = updated
        } else {
            next.append(record)
        }
        records = TaskCenterHistoryPruner.pruned(next, retentionPolicy: retentionPolicy)
        if records.contains(where: { $0.id == record.id }) {
            selectedRecordID = record.id
        } else {
            updateSelectionAfterMutation()
        }
    }

    private func markUnfinishedTasksInterrupted() {
        let now = Date()
        for index in records.indices where records[index].state.isActive {
            records[index].state = .interrupted
            records[index].message = "Task was interrupted before the last shutdown."
            records[index].updatedAt = now
            records[index].finishedAt = now
        }
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            let fileURL = try tasksURL()
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                records = TaskCenterHistoryPruner.pruned(
                    try JSONDecoder.panino.decode([TaskRecord].self, from: data).map(TaskCenterRecordNormalizer.normalizedRecord),
                    retentionPolicy: retentionPolicy
                )
            }
            statusMessage = "Tasks loaded from \(fileURL.path)"
        } catch {
            statusMessage = "Task load failed: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            let fileURL = try tasksURL()
            let data = try JSONEncoder.panino.encode(records)
            try data.write(to: fileURL, options: .atomic)
            statusMessage = "Tasks saved at \(fileURL.path)"
        } catch {
            statusMessage = "Task save failed: \(error.localizedDescription)"
        }
    }

    func isActionableAttention(_ record: TaskRecord) -> Bool {
        TaskCenterHistoryPruner.isActionableAttention(record, in: records)
    }

    func updateSelectionAfterMutation() {
        if let selectedRecordID, records.contains(where: { $0.id == selectedRecordID }) {
            return
        }
        selectedRecordID = activeRecords.first?.id ?? attentionRecords.first?.id ?? records.first?.id
    }

    private func tasksURL() throws -> URL {
        try LauncherPaths.appSupportDirectory().appendingPathComponent("tasks.json")
    }

    private static let retentionPolicyKey = "TaskHistoryRetentionPolicy"

    private static func storedRetentionPolicy() -> TaskHistoryRetentionPolicy {
        let raw = SettingsStore.string(forKey: retentionPolicyKey, default: "")
        return TaskHistoryRetentionPolicy(rawValue: raw) ?? .recent20
    }

}
