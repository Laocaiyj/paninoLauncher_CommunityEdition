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
            records = pruned(records)
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
        sorted(records.filter { $0.state.isActive })
    }

    var attentionRecords: [TaskRecord] {
        actionableAttentionRecords(in: records)
    }

    var interruptedTasks: [TaskRecord] {
        sorted(records.filter { $0.state == .interrupted })
    }

    var recentCompletedRecords: [TaskRecord] {
        Array(sorted(records.filter { $0.state == .succeeded }).prefix(3))
    }

    var historyRecords: [TaskRecord] {
        sorted(records.filter { !$0.state.isActive })
    }

    func sync(snapshot: TaskSnapshot?) {
        guard let snapshot else { return }
        let createdAt = Self.date(from: snapshot.createdAt) ?? Date()
        let updatedAt = Self.date(from: snapshot.updatedAt) ?? Date()
        let finishedAt = snapshot.finishedAt.flatMap(Self.date(from:))
        let previous = records.first { $0.id == snapshot.taskId }
        let normalizedErrorCode = Self.normalizedErrorCode(kind: snapshot.kind, errorCode: snapshot.errorCode)
        let diagnostic = Self.normalizedDiagnostic(snapshot: snapshot)
        let progressSummary = Self.progressSummary(from: snapshot.progress)
        let progressEvents = Self.appendingProgress(previous?.progressEvents, progress: snapshot.progress)
        let fallbackProgress = snapshot.state == .succeeded ? 1 : (previous?.progress ?? 0)
        let record = TaskRecord(
            id: snapshot.taskId,
            name: Self.displayName(kind: snapshot.kind, version: snapshot.version),
            kind: snapshot.kind,
            version: snapshot.version,
            gameDir: snapshot.gameDir,
            requestedLoader: snapshot.requestedLoader ?? previous?.requestedLoader,
            requestedShaderLoader: snapshot.requestedShaderLoader ?? previous?.requestedShaderLoader,
            state: TaskRecordState(taskState: snapshot.state),
            progress: max(fallbackProgress, progressSummary.fraction ?? 0),
            speed: progressSummary.speed,
            remainingTime: progressSummary.remainingTime,
            currentFile: progressSummary.currentLabel ?? snapshot.message ?? snapshot.version,
            phaseTitle: progressSummary.phaseTitle,
            phaseIndex: progressSummary.phaseIndex,
            phaseCount: progressSummary.phaseCount,
            completedJobs: progressSummary.completedJobs,
            totalJobs: progressSummary.totalJobs,
            completedBytes: progressSummary.completedBytes,
            totalBytes: progressSummary.totalBytes,
            sourceHost: progressSummary.sourceHost,
            retryCount: progressSummary.retryCount,
            movingAverageSpeed: progressSummary.movingAverageSpeed,
            throttleReason: progressSummary.throttleReason,
            hostTelemetry: progressSummary.hostTelemetry,
            multipartTelemetry: progressSummary.multipartTelemetry,
            progressEvents: progressEvents,
            errorCode: normalizedErrorCode,
            errorDetail: snapshot.errorDetail,
            diagnostic: diagnostic,
            diagnostics: Self.normalizedDiagnostics(snapshot: snapshot, primary: diagnostic),
            message: diagnostic?.userSummary ?? Self.normalizedMessage(kind: snapshot.kind, message: snapshot.message, errorCode: normalizedErrorCode) ?? snapshot.state.rawValue,
            createdAt: previous?.createdAt ?? createdAt,
            updatedAt: updatedAt,
            finishedAt: finishedAt ?? (snapshot.state.isTerminal ? updatedAt : nil)
        )
        upsert(record)
    }

    func apply(progress: TaskProgress?) {
        guard let progress else { return }
        let summary = Self.progressSummary(from: progress)
        let now = Date()

        if let index = records.firstIndex(where: { $0.id == progress.taskId }) {
            var record = records[index]
            record.progress = max(record.progress, summary.fraction ?? record.progress)
            record.speed = summary.speed
            record.remainingTime = summary.remainingTime
            record.currentFile = summary.currentLabel ?? record.currentFile
            record.phaseTitle = summary.phaseTitle
            record.phaseIndex = summary.phaseIndex
            record.phaseCount = summary.phaseCount
            record.completedJobs = summary.completedJobs
            record.totalJobs = summary.totalJobs
            record.completedBytes = summary.completedBytes
            record.totalBytes = summary.totalBytes
            record.sourceHost = summary.sourceHost
            record.retryCount = summary.retryCount
            record.movingAverageSpeed = summary.movingAverageSpeed
            record.throttleReason = summary.throttleReason
            record.hostTelemetry = summary.hostTelemetry
            record.multipartTelemetry = summary.multipartTelemetry
            record.progressEvents = Self.appendingProgress(record.progressEvents, progress: progress)
            record.updatedAt = now
            if record.message == record.state.rawValue || record.message.isEmpty {
                record.message = summary.currentLabel ?? summary.phaseTitle ?? record.message
            }
            records[index] = record
            records = pruned(records)
            selectedRecordID = progress.taskId
            return
        }

        upsert(
            TaskRecord(
                id: progress.taskId,
                name: progress.phaseTitle,
                kind: "task",
                version: "",
                gameDir: nil,
                requestedLoader: nil,
                requestedShaderLoader: nil,
                state: .running,
                progress: summary.fraction ?? 0,
                speed: summary.speed,
                remainingTime: summary.remainingTime,
                currentFile: summary.currentLabel ?? "",
                phaseTitle: summary.phaseTitle,
                phaseIndex: summary.phaseIndex,
                phaseCount: summary.phaseCount,
                completedJobs: summary.completedJobs,
                totalJobs: summary.totalJobs,
                completedBytes: summary.completedBytes,
                totalBytes: summary.totalBytes,
                sourceHost: summary.sourceHost,
                retryCount: summary.retryCount,
                movingAverageSpeed: summary.movingAverageSpeed,
                throttleReason: summary.throttleReason,
                hostTelemetry: summary.hostTelemetry,
                multipartTelemetry: summary.multipartTelemetry,
                progressEvents: [progress],
                errorCode: nil,
                errorDetail: nil,
                diagnostic: nil,
                diagnostics: nil,
                message: summary.currentLabel ?? summary.phaseTitle ?? "running",
                createdAt: now,
                updatedAt: now,
                finishedAt: nil
            )
        )
    }

    func applyTaowa(event: CoreEvent?) {
        guard let event,
              event.eventType.hasPrefix("taowa.session."),
              let session = event.payload?.session
        else { return }

        let primaryDiagnostic = event.payload?.diagnostic ?? session.diagnostics.first
        let allDiagnostics: [CoreDiagnostic]? = {
            if let diagnostics = event.payload?.diagnostics, !diagnostics.isEmpty {
                return diagnostics
            }
            if !session.diagnostics.isEmpty {
                return session.diagnostics
            }
            return primaryDiagnostic.map { [$0] }
        }()
        let state = Self.taowaRecordState(eventType: event.eventType, sessionStatus: session.status)
        let message: String
        switch state {
        case .running:
            message = "Taowa tunnel running at \(session.remoteAddress)."
        case .succeeded:
            message = "Taowa tunnel stopped for \(session.remoteAddress)."
        case .failed, .interrupted:
            message = primaryDiagnostic?.userSummary ?? event.message
        case .queued, .cancelled:
            message = event.message
        }

        upsertLocal(
            id: "taowa:\(session.sessionId)",
            kind: "taowa-tunnel",
            name: "Taowa Tunnel",
            version: session.remoteAddress,
            gameDir: session.gameDir,
            state: state,
            progress: state.isActive ? 0.66 : 1,
            currentFile: "frpc \(session.localPort) -> \(session.remoteAddress)",
            errorCode: state.needsAttention ? primaryDiagnostic?.code : nil,
            errorDetail: primaryDiagnostic?.developerDetail,
            diagnostic: primaryDiagnostic,
            diagnostics: allDiagnostics,
            message: message
        )
    }

    func mergeCoreHistory(_ snapshots: [TaskSnapshot]) {
        guard !snapshots.isEmpty else { return }
        var next = records
        for snapshot in snapshots {
            let createdAt = Self.date(from: snapshot.createdAt) ?? Date()
            let updatedAt = Self.date(from: snapshot.updatedAt) ?? Date()
            let finishedAt = snapshot.finishedAt.flatMap(Self.date(from:))
            let state = TaskRecordState(taskState: snapshot.state)
            let normalizedErrorCode = Self.normalizedErrorCode(kind: snapshot.kind, errorCode: snapshot.errorCode)
            let diagnostic = Self.normalizedDiagnostic(snapshot: snapshot)
            let progressSummary = Self.progressSummary(from: snapshot.progress)
            let previous = next.first { $0.id == snapshot.taskId }
            let progressEvents = Self.appendingProgress(previous?.progressEvents, progress: snapshot.progress)
            let record = TaskRecord(
                id: snapshot.taskId,
                name: Self.displayName(kind: snapshot.kind, version: snapshot.version),
                kind: snapshot.kind,
                version: snapshot.version,
                gameDir: snapshot.gameDir,
                requestedLoader: snapshot.requestedLoader ?? previous?.requestedLoader,
                requestedShaderLoader: snapshot.requestedShaderLoader ?? previous?.requestedShaderLoader,
                state: state,
                progress: state == .succeeded ? 1 : (progressSummary.fraction ?? 0),
                speed: progressSummary.speed,
                remainingTime: progressSummary.remainingTime,
                currentFile: progressSummary.currentLabel ?? snapshot.message ?? snapshot.version,
                phaseTitle: progressSummary.phaseTitle,
                phaseIndex: progressSummary.phaseIndex,
                phaseCount: progressSummary.phaseCount,
                completedJobs: progressSummary.completedJobs,
                totalJobs: progressSummary.totalJobs,
                completedBytes: progressSummary.completedBytes,
                totalBytes: progressSummary.totalBytes,
                sourceHost: progressSummary.sourceHost,
                retryCount: progressSummary.retryCount,
                movingAverageSpeed: progressSummary.movingAverageSpeed,
                throttleReason: progressSummary.throttleReason,
                hostTelemetry: progressSummary.hostTelemetry,
                multipartTelemetry: progressSummary.multipartTelemetry,
                progressEvents: progressEvents,
                errorCode: normalizedErrorCode,
                errorDetail: snapshot.errorDetail,
                diagnostic: diagnostic,
                diagnostics: Self.normalizedDiagnostics(snapshot: snapshot, primary: diagnostic),
                message: diagnostic?.userSummary ?? Self.normalizedMessage(kind: snapshot.kind, message: snapshot.message, errorCode: normalizedErrorCode) ?? snapshot.state.rawValue,
                createdAt: createdAt,
                updatedAt: updatedAt,
                finishedAt: finishedAt
            )
            if let index = next.firstIndex(where: { $0.id == record.id }) {
                next[index] = record
            } else {
                next.append(record)
            }
        }
        next = markMissingCoreTasksInterrupted(next, coreTaskIDs: Set(snapshots.map(\.taskId)))
        records = pruned(next)
        updateSelectionAfterMutation()
    }

    private func markMissingCoreTasksInterrupted(_ input: [TaskRecord], coreTaskIDs: Set<String>) -> [TaskRecord] {
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

    func enqueueLocal(kind: String, name: String, message: String) {
        upsertLocal(kind: kind, name: name, state: .queued, message: message)
    }

    @discardableResult
    func upsertLocal(
        id: String = UUID().uuidString,
        kind: String,
        name: String,
        version: String = "",
        gameDir: String? = nil,
        state: TaskRecordState,
        progress: Double = 0,
        speed: String = "-",
        remainingTime: String = "-",
        currentFile: String = "",
        errorCode: String? = nil,
        errorDetail: String? = nil,
        diagnostic: CoreDiagnostic? = nil,
        diagnostics: [CoreDiagnostic]? = nil,
        message: String
    ) -> String {
        let now = Date()
        let structuredDiagnostic = diagnostic ?? Self.localDiagnostic(
            kind: kind,
            gameDir: gameDir,
            state: state,
            errorCode: errorCode,
            errorDetail: errorDetail,
            message: message
        )
        let structuredDiagnostics = diagnostics ?? structuredDiagnostic.map { [$0] }
        upsert(
            TaskRecord(
                id: id,
                name: name,
                kind: kind,
                version: version,
                gameDir: gameDir,
                requestedLoader: nil,
                requestedShaderLoader: nil,
                state: state,
                progress: min(max(progress, 0), 1),
                speed: speed,
                remainingTime: remainingTime,
                currentFile: currentFile,
                phaseTitle: nil,
                phaseIndex: nil,
                phaseCount: nil,
                completedJobs: nil,
                totalJobs: nil,
                completedBytes: nil,
                totalBytes: nil,
                sourceHost: nil,
                retryCount: nil,
                movingAverageSpeed: nil,
                throttleReason: nil,
                hostTelemetry: nil,
                multipartTelemetry: nil,
                progressEvents: nil,
                errorCode: errorCode,
                errorDetail: errorDetail,
                diagnostic: structuredDiagnostic,
                diagnostics: structuredDiagnostics,
                message: structuredDiagnostic?.userSummary ?? message,
                createdAt: now,
                updatedAt: now,
                finishedAt: state.isTerminal ? now : nil
            )
        )
        return id
    }

    private static func localDiagnostic(
        kind: String,
        gameDir: String?,
        state: TaskRecordState,
        errorCode: String?,
        errorDetail: String?,
        message: String
    ) -> CoreDiagnostic? {
        guard state.needsAttention, let errorCode, !errorCode.isEmpty else { return nil }
        let action = localDiagnosticAction(errorCode: errorCode)
        let evidence = gameDir.map { [CoreDiagnosticEvidence(key: "gameDir", value: $0, redacted: false)] } ?? []
        return CoreDiagnostic(
            code: errorCode,
            phase: localDiagnosticPhase(kind: kind, errorCode: errorCode),
            severity: "error",
            title: "Local task failed",
            message: message,
            cause: errorDetail ?? message,
            action: action,
            retryable: action.kind == "retry",
            userVisible: true,
            source: "swift",
            taskId: nil,
            planId: nil,
            packageId: nil,
            filePath: nil,
            urlHost: nil,
            evidence: evidence,
            developerDetail: errorDetail
        )
    }

    private static func localDiagnosticPhase(kind: String, errorCode: String) -> String {
        let source = "\(kind) \(errorCode)".lowercased()
        if source.contains("cache") {
            return "diagnostic"
        }
        if source.contains("archive") || source.contains("backup") || source.contains("source") {
            return "write"
        }
        return "diagnostic"
    }

    private static func localDiagnosticAction(errorCode: String) -> CoreDiagnosticAction {
        switch errorCode {
        case "cache_cleanup_failed":
            return CoreDiagnosticAction(kind: "clearCache", label: "Clear cache")
        case "missing_source", "archive_failed", "preflight_blocked":
            return CoreDiagnosticAction(kind: "openDiagnostics", label: "Open diagnostics")
        default:
            return CoreDiagnosticAction(kind: "openDiagnostics", label: "Open diagnostics")
        }
    }

    func markInterrupted(activeTask: TaskSnapshot?) {
        if let activeTask {
            sync(snapshot: activeTask)
        }
        let now = Date()
        for index in records.indices where records[index].state.isActive {
            records[index].state = .interrupted
            records[index].message = "Task interrupted by Core shutdown."
            records[index].updatedAt = now
            records[index].finishedAt = now
        }
        records = pruned(records)
        updateSelectionAfterMutation()
    }

    func clearInterrupted(_ record: TaskRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index].state = .cancelled
        records[index].message = "Dismissed interrupted task."
        records[index].updatedAt = Date()
        records[index].finishedAt = Date()
        records = pruned(records)
        updateSelectionAfterMutation()
    }

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

    func pruneHistory() {
        records = pruned(records)
        updateSelectionAfterMutation()
    }

    private func upsert(_ record: TaskRecord) {
        var next = records
        if let index = next.firstIndex(where: { $0.id == record.id }) {
            var updated = record
            updated.createdAt = next[index].createdAt ?? record.createdAt
            next[index] = updated
        } else {
            next.append(record)
        }
        records = pruned(next)
        if records.contains(where: { $0.id == record.id }) {
            selectedRecordID = record.id
        } else {
            updateSelectionAfterMutation()
        }
    }

    @discardableResult
    private func clearRecords(where shouldRemove: (TaskRecord) -> Bool) -> Int {
        let previousCount = records.count
        records.removeAll { record in
            guard !record.state.isActive else { return false }
            return shouldRemove(record)
        }
        records = pruned(records)
        updateSelectionAfterMutation()
        return previousCount - records.count
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
                records = pruned(try JSONDecoder.panino.decode([TaskRecord].self, from: data).map(Self.normalizedRecord))
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

    private func pruned(_ input: [TaskRecord]) -> [TaskRecord] {
        let ordered = sorted(input.map(Self.normalizedRecord))
        let active = ordered.filter { $0.state.isActive }
        let cutoff30 = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast

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
            let cutoff7 = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
            return unique(active + ordered.filter { !$0.state.isActive && ($0.finishedAt ?? $0.updatedAt) >= cutoff7 })
        case .failuresOnly:
            return unique(active + actionableAttentionRecords(in: ordered).filter { ($0.finishedAt ?? $0.updatedAt) >= cutoff30 })
        }
    }

    func isActionableAttention(_ record: TaskRecord) -> Bool {
        isActionableAttention(record, in: records)
    }

    private func actionableAttentionRecords(in input: [TaskRecord]) -> [TaskRecord] {
        sorted(input.filter { record in
            isActionableAttention(record, in: input)
        })
    }

    private func isActionableAttention(_ record: TaskRecord, in input: [TaskRecord]) -> Bool {
        record.state.needsAttention
            && !isLocalPlanningRecord(record)
            && !isSupersededByLaterSuccess(record, in: input)
    }

    private func isSupersededByLaterSuccess(_ record: TaskRecord, in input: [TaskRecord]) -> Bool {
        guard record.state.needsAttention else { return false }
        let recordTime = terminalTime(for: record)
        return input.contains { candidate in
            candidate.id != record.id
                && candidate.state == .succeeded
                && sameSupersessionTarget(record, candidate)
                && terminalTime(for: candidate) >= recordTime
        }
    }

    private func sameSupersessionTarget(_ lhs: TaskRecord, _ rhs: TaskRecord) -> Bool {
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

    private func isCoreHistoryBackedRecord(_ record: TaskRecord) -> Bool {
        switch record.kind {
        case "install", "launch", "runtime.install", "content-install", "performance-pack-install":
            return true
        default:
            return false
        }
    }

    private func terminalTime(for record: TaskRecord) -> Date {
        record.finishedAt ?? record.updatedAt
    }

    private func normalizedGameDir(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: trimmed, isDirectory: true).standardizedFileURL.path
    }

    private func installComponents(from record: TaskRecord) -> (loader: String?, shaderLoader: String?, hasRecordedSelection: Bool) {
        let loader = normalizedInstallComponent(record.requestedLoader) ?? normalizedInstallComponent(detailValue("requestedLoader", in: record.errorDetail))
        let shaderLoader = normalizedInstallComponent(record.requestedShaderLoader) ?? normalizedInstallComponent(detailValue("requestedShaderLoader", in: record.errorDetail))
        return (loader, shaderLoader, loader != nil || shaderLoader != nil)
    }

    private func detailValue(_ key: String, in detail: String?) -> String? {
        guard let detail else { return nil }
        let prefix = "\(key)="
        return detail
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }

    private func normalizedInstallComponent(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "-" || trimmed.lowercased() == "none" || trimmed.lowercased() == "vanilla" {
            return nil
        }
        return trimmed.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: "-", with: "")
    }

    private func isLocalPlanningRecord(_ record: TaskRecord) -> Bool {
        record.kind.hasSuffix("-plan")
    }

    private static func normalizedErrorCode(kind: String, errorCode: String?) -> String? {
        guard let errorCode else { return nil }
        if kind == "install", errorCode == "process_launch_failed" {
            return "install_failed"
        }
        if kind == "content-install", errorCode == "process_launch_failed" {
            return "content_install_failed"
        }
        return errorCode
    }

    private static func normalizedDiagnostic(snapshot: TaskSnapshot) -> CoreDiagnostic? {
        snapshot.diagnostic ?? snapshot.diagnostics.first
    }

    private static func normalizedDiagnostics(snapshot: TaskSnapshot, primary: CoreDiagnostic?) -> [CoreDiagnostic]? {
        let values = snapshot.diagnostics.isEmpty ? primary.map { [$0] } ?? [] : snapshot.diagnostics
        return values.isEmpty ? nil : values
    }

    private static func taowaRecordState(eventType: String, sessionStatus: String) -> TaskRecordState {
        if eventType == "taowa.session.failed" || sessionStatus == "failed" {
            return .failed
        }
        if eventType == "taowa.session.stopped" || sessionStatus == "stopped" {
            return .succeeded
        }
        if ["prepared", "startingFrpc", "running"].contains(sessionStatus) {
            return .running
        }
        return .running
    }

    private static func normalizedMessage(kind: String, message: String?, errorCode: String?) -> String? {
        if kind == "runtime.install" {
            if let errorCode, !errorCode.isEmpty {
                return message ?? "Java Runtime install failed. Open logs for the Core error detail, then retry."
            }
            if let message, !message.isEmpty {
                return message
            }
            return nil
        }
        if kind == "install", errorCode == "install_failed" {
            return "Install failed before Minecraft was ready. Open logs for the Core error detail, then retry."
        }
        if kind == "content-install", errorCode == "content_install_failed" {
            return "Content install failed. Open logs for the Core error detail, then retry."
        }
        return message
    }

    private static func normalizedRecord(_ record: TaskRecord) -> TaskRecord {
        var next = record
        let errorCode = normalizedErrorCode(kind: record.kind, errorCode: record.errorCode)
        next.errorCode = errorCode
        next.message = record.diagnostic?.userSummary ?? normalizedMessage(kind: record.kind, message: record.message, errorCode: errorCode) ?? record.message
        if next.diagnostics == nil, let diagnostic = next.diagnostic {
            next.diagnostics = [diagnostic]
        }
        if record.kind == "runtime.install" {
            next.name = displayName(kind: record.kind, version: record.version)
        }
        return next
    }

    private static func displayName(kind: String, version: String) -> String {
        if kind == "runtime.install" {
            if let major = javaMajorVersion(from: version) {
                return "Java Runtime \(major)"
            }
            return version.isEmpty ? "Java Runtime" : "Java Runtime \(version)"
        }
        return "\(kind.capitalized) \(version)"
    }

    private func sorted(_ input: [TaskRecord]) -> [TaskRecord] {
        input.sorted { lhs, rhs in
            lhs.updatedAt > rhs.updatedAt
        }
    }

    private func unique(_ input: [TaskRecord]) -> [TaskRecord] {
        var seen = Set<String>()
        return input.filter { record in
            seen.insert(record.id).inserted
        }
    }

    private func updateSelectionAfterMutation() {
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

    private static func date(from value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return fractional.date(from: value) ?? plain.date(from: value)
    }

    private static func progressSummary(from progress: TaskProgress?) -> ProgressSummary {
        guard let progress else {
            return ProgressSummary(
                fraction: nil,
                speed: "-",
                remainingTime: "-",
                currentLabel: nil,
                phaseTitle: nil,
                phaseIndex: nil,
                phaseCount: nil,
                completedJobs: nil,
                totalJobs: nil,
                completedBytes: nil,
                totalBytes: nil,
                sourceHost: nil,
                retryCount: nil,
                movingAverageSpeed: nil,
                throttleReason: nil,
                hostTelemetry: nil,
                multipartTelemetry: nil
            )
        }

        return ProgressSummary(
            fraction: progress.fractionComplete,
            speed: formattedSpeed(progress.speedBytesPerSecond),
            remainingTime: formattedDuration(progress.etaSeconds),
            currentLabel: progress.currentLabel.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            phaseTitle: progress.phaseTitle,
            phaseIndex: progress.phaseIndex,
            phaseCount: progress.phaseCount,
            completedJobs: progress.completedJobs,
            totalJobs: progress.totalJobs,
            completedBytes: progress.completedBytes,
            totalBytes: progress.totalBytes,
            sourceHost: progress.sourceHost,
            retryCount: progress.retryCount,
            movingAverageSpeed: progress.movingAverageSpeedBytesPerSecond.map(formattedSpeed),
            throttleReason: progress.throttleReason,
            hostTelemetry: progress.hosts,
            multipartTelemetry: progress.multipart
        )
    }

    private static func appendingProgress(_ events: [TaskProgress]?, progress: TaskProgress?) -> [TaskProgress]? {
        guard let progress else { return events }
        let existing = events ?? []
        if existing.last == progress {
            return existing
        }
        return Array((existing + [progress]).suffix(200))
    }

    private static func formattedSpeed(_ bytesPerSecond: Int64) -> String {
        guard bytesPerSecond > 0 else { return "0 B/s" }
        return "\(formattedBytes(bytesPerSecond))/s"
    }

    private static func formattedDuration(_ seconds: Int64?) -> String {
        guard let seconds, seconds >= 0 else { return "-" }
        if seconds < 60 {
            return "\(seconds)s"
        }
        let minutes = seconds / 60
        let remainder = seconds % 60
        if minutes < 60 {
            return "\(minutes)m \(remainder)s"
        }
        let hours = minutes / 60
        return "\(hours)h \(minutes % 60)m"
    }

    private struct ProgressSummary {
        let fraction: Double?
        let speed: String
        let remainingTime: String
        let currentLabel: String?
        let phaseTitle: String?
        let phaseIndex: Int?
        let phaseCount: Int?
        let completedJobs: Int?
        let totalJobs: Int?
        let completedBytes: Int64?
        let totalBytes: Int64?
        let sourceHost: String?
        let retryCount: Int?
        let movingAverageSpeed: String?
        let throttleReason: String?
        let hostTelemetry: [TaskProgressHost]?
        let multipartTelemetry: TaskProgressMultipart?
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
