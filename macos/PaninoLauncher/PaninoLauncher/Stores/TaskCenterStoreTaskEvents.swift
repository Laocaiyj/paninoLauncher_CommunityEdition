import Foundation

@MainActor
extension TaskCenterStore {
    func sync(snapshot: TaskSnapshot?) {
        guard let snapshot else { return }
        let previous = records.first { $0.id == snapshot.taskId }
        upsert(TaskCenterRecordFactory.record(from: snapshot, previous: previous))
    }

    func apply(progress: TaskProgress?) {
        guard let progress else { return }
        let summary = TaskCenterProgressFormatter.summary(from: progress)
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
            record.progressEvents = TaskCenterProgressFormatter.appending(record.progressEvents, progress: progress)
            record.updatedAt = now
            if record.message == record.state.rawValue || record.message.isEmpty {
                record.message = summary.currentLabel ?? summary.phaseTitle ?? record.message
            }
            records[index] = record
            records = TaskCenterHistoryPruner.pruned(records, retentionPolicy: retentionPolicy)
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
        let state = TaskCenterRecordNormalizer.taowaRecordState(eventType: event.eventType, sessionStatus: session.status)
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
            let previous = next.first { $0.id == snapshot.taskId }
            let record = TaskCenterRecordFactory.record(from: snapshot, previous: previous)
            if let index = next.firstIndex(where: { $0.id == record.id }) {
                next[index] = record
            } else {
                next.append(record)
            }
        }
        next = TaskCenterHistoryPruner.markMissingCoreTasksInterrupted(next, coreTaskIDs: Set(snapshots.map(\.taskId)))
        records = TaskCenterHistoryPruner.pruned(next, retentionPolicy: retentionPolicy)
        updateSelectionAfterMutation()
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
        upsert(
            TaskCenterRecordFactory.localRecord(
                id: id,
                kind: kind,
                name: name,
                version: version,
                gameDir: gameDir,
                state: state,
                progress: progress,
                speed: speed,
                remainingTime: remainingTime,
                currentFile: currentFile,
                errorCode: errorCode,
                errorDetail: errorDetail,
                diagnostic: diagnostic,
                diagnostics: diagnostics,
                message: message
            )
        )
        return id
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
        records = TaskCenterHistoryPruner.pruned(records, retentionPolicy: retentionPolicy)
        updateSelectionAfterMutation()
    }

    func clearInterrupted(_ record: TaskRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index].state = .cancelled
        records[index].message = "Dismissed interrupted task."
        records[index].updatedAt = Date()
        records[index].finishedAt = Date()
        records = TaskCenterHistoryPruner.pruned(records, retentionPolicy: retentionPolicy)
        updateSelectionAfterMutation()
    }
}
