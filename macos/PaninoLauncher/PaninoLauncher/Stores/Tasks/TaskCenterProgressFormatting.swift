import Foundation

struct TaskCenterProgressSummary {
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

enum TaskCenterProgressFormatter {
    static func summary(from progress: TaskProgress?) -> TaskCenterProgressSummary {
        guard let progress else {
            return TaskCenterProgressSummary(
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

        return TaskCenterProgressSummary(
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

    static func appending(_ events: [TaskProgress]?, progress: TaskProgress?) -> [TaskProgress]? {
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
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
