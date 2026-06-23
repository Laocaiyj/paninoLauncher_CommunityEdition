import Foundation

struct CoreEvent: Decodable, Equatable, Identifiable {
    let eventType: String
    let taskId: String?
    let version: String?
    let message: String
    let time: String
    let payload: CoreEventPayload?

    var id: String {
        [time, eventType, taskId ?? "core"].joined(separator: ":")
    }

    private enum CodingKeys: String, CodingKey {
        case eventType = "type"
        case taskId
        case version
        case message
        case time
        case payload
    }
}

struct CoreEventPayload: Decodable, Equatable {
    let state: String?
    let errorCode: String?
    let errorDetail: String?
    let diagnostic: CoreDiagnostic?
    let diagnostics: [CoreDiagnostic]?
    let percent: Double?
    let label: String?
    let phaseId: String?
    let phaseTitle: String?
    let phaseIndex: Int?
    let phaseCount: Int?
    let phasePercent: Double?
    let overallPercent: Double?
    let completedJobs: Int?
    let totalJobs: Int?
    let completedBytes: Int64?
    let totalBytes: Int64?
    let speedBytesPerSecond: Int64?
    let movingAverageSpeedBytesPerSecond: Int64?
    let etaSeconds: Int64?
    let currentLabel: String?
    let activeWorkers: Int?
    let retryCount: Int?
    let sourceHost: String?
    let host: String?
    let source: String?
    let hosts: [TaskProgressHost]?
    let throttleReason: String?
    let multipart: TaskProgressMultipart?
    let session: CoreTaowaSession?

    func taskProgress(taskId: String?) -> TaskProgress? {
        guard let taskId,
              let phaseId,
              let phaseTitle,
              let phaseIndex,
              let phaseCount
        else { return nil }

        let resolvedOverallPercent = overallPercent ?? percent
        let resolvedCurrentLabel = currentLabel ?? label ?? ""
        let resolvedSourceHost = sourceHost ?? host ?? source

        return TaskProgress(
            taskId: taskId,
            phaseId: phaseId,
            phaseTitle: phaseTitle,
            phaseIndex: phaseIndex,
            phaseCount: phaseCount,
            phasePercent: phasePercent,
            overallPercent: resolvedOverallPercent,
            completedJobs: completedJobs ?? 0,
            totalJobs: totalJobs ?? 0,
            completedBytes: completedBytes ?? 0,
            totalBytes: totalBytes ?? 0,
            speedBytesPerSecond: speedBytesPerSecond ?? 0,
            movingAverageSpeedBytesPerSecond: movingAverageSpeedBytesPerSecond,
            etaSeconds: etaSeconds,
            currentLabel: resolvedCurrentLabel,
            activeWorkers: activeWorkers ?? 0,
            retryCount: retryCount ?? 0,
            sourceHost: resolvedSourceHost,
            hosts: hosts,
            throttleReason: throttleReason,
            multipart: multipart
        )
    }
}

enum LogSource: String, Equatable, Sendable {
    case app
    case core
    case game
}

struct LogLine: Identifiable, Equatable, Sendable {
    let id: UUID
    let source: LogSource
    let text: String

    init(text: String, source: LogSource = .app) {
        self.id = UUID()
        self.source = source
        self.text = text
    }
}
