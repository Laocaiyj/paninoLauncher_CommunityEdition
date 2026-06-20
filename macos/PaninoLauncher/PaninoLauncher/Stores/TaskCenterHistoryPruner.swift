import Foundation

enum TaskCenterHistoryPruner {
    static func sorted(_ input: [TaskRecord]) -> [TaskRecord] {
        input.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }
    }

    static func unique(_ input: [TaskRecord]) -> [TaskRecord] {
        var seen = Set<String>()
        return input.filter { record in
            seen.insert(record.id).inserted
        }
    }

    static func pruned(
        _ input: [TaskRecord],
        retentionPolicy: TaskHistoryRetentionPolicy,
        now: Date = Date()
    ) -> [TaskRecord] {
        let ordered = sorted(input.map(TaskCenterRecordNormalizer.normalizedRecord))
        let active = ordered.filter { $0.state.isActive }
        let cutoff30 = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? .distantPast

        switch retentionPolicy {
        case .recent20:
            let attention = actionableAttentionRecords(in: ordered)
                .filter { ($0.finishedAt ?? $0.updatedAt) >= cutoff30 }
            let finished = Array(ordered.filter { $0.state == .succeeded || $0.state == .cancelled }.prefix(20))
            return unique(active + attention + finished)
        case .recent50:
            let attention = actionableAttentionRecords(in: ordered)
                .filter { ($0.finishedAt ?? $0.updatedAt) >= cutoff30 }
            let finished = Array(ordered.filter { $0.state == .succeeded || $0.state == .cancelled }.prefix(50))
            return unique(active + attention + finished)
        case .sevenDays:
            let cutoff7 = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? .distantPast
            return unique(active + ordered.filter { !$0.state.isActive && ($0.finishedAt ?? $0.updatedAt) >= cutoff7 })
        case .failuresOnly:
            return unique(active + actionableAttentionRecords(in: ordered).filter { ($0.finishedAt ?? $0.updatedAt) >= cutoff30 })
        }
    }

    static func actionableAttentionRecords(in input: [TaskRecord]) -> [TaskRecord] {
        sorted(input.filter { record in
            isActionableAttention(record, in: input)
        })
    }

    static func isActionableAttention(_ record: TaskRecord, in input: [TaskRecord]) -> Bool {
        record.state.needsAttention
            && !isLocalPlanningRecord(record)
            && !isSupersededByLaterSuccess(record, in: input)
    }

    static func markMissingCoreTasksInterrupted(_ input: [TaskRecord], coreTaskIDs: Set<String>) -> [TaskRecord] {
        input.map { record in
            guard record.state.isActive, isCoreHistoryBackedRecord(record), !coreTaskIDs.contains(record.id) else {
                return record
            }
            var interrupted = record
            interrupted.state = .interrupted
            interrupted.message = "Task was interrupted before Core reported a final state."
            interrupted.finishedAt = record.updatedAt
            return interrupted
        }
    }

    private static func isSupersededByLaterSuccess(_ record: TaskRecord, in input: [TaskRecord]) -> Bool {
        guard record.state.needsAttention else { return false }
        let recordTime = terminalTime(for: record)
        return input.contains { candidate in
            candidate.id != record.id
                && candidate.state == .succeeded
                && sameSupersessionTarget(record, candidate)
                && terminalTime(for: candidate) >= recordTime
        }
    }

    private static func sameSupersessionTarget(_ lhs: TaskRecord, _ rhs: TaskRecord) -> Bool {
        let lhsKind = lhs.kind.lowercased()
        let rhsKind = rhs.kind.lowercased()
        guard lhs.version == rhs.version else { return false }
        guard lhsKind == rhsKind || (lhsKind == "install" && rhsKind == "launch") else { return false }
        let lhsGameDir = normalizedGameDir(lhs.gameDir)
        let rhsGameDir = normalizedGameDir(rhs.gameDir)
        if let lhsGameDir, let rhsGameDir {
            guard lhsGameDir == rhsGameDir else { return false }
        } else if lhsGameDir != nil || rhsGameDir != nil {
            return false
        }
        if lhsKind == "install", rhsKind == "install" {
            let lhsComponents = installComponents(from: lhs)
            let rhsComponents = installComponents(from: rhs)
            if lhsComponents.hasRecordedSelection || rhsComponents.hasRecordedSelection {
                return lhsComponents.loader == rhsComponents.loader
                    && lhsComponents.shaderLoader == rhsComponents.shaderLoader
            }
        }
        return true
    }

    private static func isCoreHistoryBackedRecord(_ record: TaskRecord) -> Bool {
        switch record.kind {
        case "install", "launch", "runtime.install", "content-install", "performance-pack-install":
            return true
        default:
            return false
        }
    }

    private static func terminalTime(for record: TaskRecord) -> Date {
        record.finishedAt ?? record.updatedAt
    }

    private static func normalizedGameDir(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: trimmed, isDirectory: true).standardizedFileURL.path
    }

    private static func installComponents(from record: TaskRecord) -> (loader: String?, shaderLoader: String?, hasRecordedSelection: Bool) {
        let loader = normalizedInstallComponent(record.requestedLoader) ?? normalizedInstallComponent(detailValue("requestedLoader", in: record.errorDetail))
        let shaderLoader = normalizedInstallComponent(record.requestedShaderLoader) ?? normalizedInstallComponent(detailValue("requestedShaderLoader", in: record.errorDetail))
        return (loader, shaderLoader, loader != nil || shaderLoader != nil)
    }

    private static func detailValue(_ key: String, in detail: String?) -> String? {
        guard let detail else { return nil }
        let prefix = "\(key)="
        return detail
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private static func normalizedInstallComponent(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "-" || trimmed.lowercased() == "none" || trimmed.lowercased() == "vanilla" {
            return nil
        }
        return trimmed.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")
    }

    private static func isLocalPlanningRecord(_ record: TaskRecord) -> Bool {
        record.kind.hasSuffix("-plan")
    }
}
