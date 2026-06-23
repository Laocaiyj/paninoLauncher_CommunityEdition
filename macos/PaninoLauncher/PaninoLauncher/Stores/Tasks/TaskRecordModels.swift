import Foundation

enum TaskRecordState: String, Codable, CaseIterable, Identifiable {
    case queued
    case running
    case succeeded
    case failed
    case cancelled
    case interrupted

    var id: String { rawValue }

    var isActive: Bool {
        self == .queued || self == .running
    }

    var isTerminal: Bool {
        !isActive
    }

    var needsAttention: Bool {
        self == .failed || self == .interrupted
    }
}

enum TaskHistoryRetentionPolicy: String, Codable, CaseIterable, Identifiable {
    case recent20
    case recent50
    case sevenDays
    case failuresOnly

    var id: String { rawValue }
}

struct TaskRecord: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var kind: String
    var version: String
    var gameDir: String?
    var requestedLoader: String?
    var requestedShaderLoader: String?
    var state: TaskRecordState
    var progress: Double
    var speed: String
    var remainingTime: String
    var currentFile: String
    var phaseTitle: String?
    var phaseIndex: Int?
    var phaseCount: Int?
    var completedJobs: Int?
    var totalJobs: Int?
    var completedBytes: Int64?
    var totalBytes: Int64?
    var sourceHost: String?
    var retryCount: Int?
    var movingAverageSpeed: String?
    var throttleReason: String?
    var hostTelemetry: [TaskProgressHost]?
    var multipartTelemetry: TaskProgressMultipart?
    var progressEvents: [TaskProgress]?
    var errorCode: String?
    var errorDetail: String?
    var diagnostic: CoreDiagnostic?
    var diagnostics: [CoreDiagnostic]?
    var message: String
    var createdAt: Date?
    var updatedAt: Date
    var finishedAt: Date?

    var advice: String {
        if let diagnostic {
            return diagnostic.actionLabel
        }
        let source = [errorCode, message].compactMap { $0 }.joined(separator: " ").lowercased()
        if source.contains("network") || source.contains("timeout") || source.contains("proxy") {
            return "Check network connectivity, proxy settings, and retry the task."
        }
        if source.contains("hash") || source.contains("checksum") || source.contains("mismatch") {
            return "Clear corrupted cache, then retry the download."
        }
        if source.contains("permission") || source.contains("denied") || source.contains("writable") {
            return "Check folder permissions and choose a writable game directory."
        }
        if source.contains("disk") || source.contains("space") || source.contains("full") {
            return "Free disk space, then retry the task."
        }
        if source.contains("version") || source.contains("manifest") || source.contains("json") {
            return "Refresh version metadata, then retry or choose another Minecraft version."
        }
        return "Review logs, then retry if the issue is temporary."
    }

    var kindTitle: String {
        if kind == "runtime.install" {
            return "Java Runtime"
        }
        if kind == "taowa-tunnel" {
            return "Taowa Tunnel"
        }
        return kind.capitalized
    }
}

extension TaskRecordState {
    init(taskState: TaskState) {
        switch taskState {
        case .queued:
            self = .queued
        case .running:
            self = .running
        case .succeeded:
            self = .succeeded
        case .failed:
            self = .failed
        case .cancelled:
            self = .cancelled
        }
    }
}
