import Foundation

enum TaskCenterRecordFactory {
    static func record(from snapshot: TaskSnapshot, previous: TaskRecord? = nil, now: Date = Date()) -> TaskRecord {
        let createdAt = TaskCenterRecordNormalizer.date(from: snapshot.createdAt) ?? now
        let updatedAt = TaskCenterRecordNormalizer.date(from: snapshot.updatedAt) ?? now
        let finishedAt = snapshot.finishedAt.flatMap(TaskCenterRecordNormalizer.date(from:))
        let state = TaskRecordState(taskState: snapshot.state)
        let normalizedErrorCode = TaskCenterRecordNormalizer.normalizedErrorCode(kind: snapshot.kind, errorCode: snapshot.errorCode)
        let diagnostic = TaskCenterRecordNormalizer.primaryDiagnostic(snapshot: snapshot)
        let progressSummary = TaskCenterProgressFormatter.summary(from: snapshot.progress)
        let progressEvents = TaskCenterProgressFormatter.appending(previous?.progressEvents, progress: snapshot.progress)
        let fallbackProgress = snapshot.state == .succeeded ? 1 : (previous?.progress ?? 0)

        return TaskRecord(
            id: snapshot.taskId,
            name: TaskCenterRecordNormalizer.displayName(kind: snapshot.kind, version: snapshot.version),
            kind: snapshot.kind,
            version: snapshot.version,
            gameDir: snapshot.gameDir,
            requestedLoader: snapshot.requestedLoader ?? previous?.requestedLoader,
            requestedShaderLoader: snapshot.requestedShaderLoader ?? previous?.requestedShaderLoader,
            state: state,
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
            diagnostics: TaskCenterRecordNormalizer.diagnostics(snapshot: snapshot, primary: diagnostic),
            message: diagnostic?.userSummary ?? TaskCenterRecordNormalizer.normalizedMessage(kind: snapshot.kind, message: snapshot.message, errorCode: normalizedErrorCode) ?? snapshot.state.rawValue,
            createdAt: previous?.createdAt ?? createdAt,
            updatedAt: updatedAt,
            finishedAt: finishedAt ?? (snapshot.state.isTerminal ? updatedAt : nil)
        )
    }

    static func localRecord(
        id: String,
        kind: String,
        name: String,
        version: String,
        gameDir: String?,
        state: TaskRecordState,
        progress: Double,
        speed: String,
        remainingTime: String,
        currentFile: String,
        errorCode: String?,
        errorDetail: String?,
        diagnostic: CoreDiagnostic?,
        diagnostics: [CoreDiagnostic]?,
        message: String,
        now: Date = Date()
    ) -> TaskRecord {
        let structuredDiagnostic = diagnostic ?? TaskCenterRecordNormalizer.localDiagnostic(
            kind: kind,
            gameDir: gameDir,
            state: state,
            errorCode: errorCode,
            errorDetail: errorDetail,
            message: message
        )
        let structuredDiagnostics = diagnostics ?? structuredDiagnostic.map { [$0] }
        return TaskRecord(
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
    }
}
