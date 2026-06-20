import Foundation

struct TaskProgress: Codable, Equatable {
    let taskId: String
    let phaseId: String
    let phaseTitle: String
    let phaseIndex: Int
    let phaseCount: Int
    let phasePercent: Double?
    let overallPercent: Double?
    let completedJobs: Int
    let totalJobs: Int
    let completedBytes: Int64
    let totalBytes: Int64
    let speedBytesPerSecond: Int64
    let movingAverageSpeedBytesPerSecond: Int64?
    let etaSeconds: Int64?
    let currentLabel: String
    let activeWorkers: Int
    let retryCount: Int
    let sourceHost: String?
    let hosts: [TaskProgressHost]?
    let throttleReason: String?
    let multipart: TaskProgressMultipart?

    var fractionComplete: Double? {
        overallPercent.map { min(max($0 / 100, 0), 1) }
    }
}

struct TaskProgressHost: Codable, Equatable {
    let host: String
    let lane: String
    let activeConnections: Int
    let gate: Int
    let maxGate: Int
    let bytesPerSecond: Int64
    let completedBytes: Int64
    let completedJobs: Int
    let retryCount: Int

    var displayText: String {
        "\(host) \(activeConnections)/\(gate) \(formattedBytes(bytesPerSecond))/s"
    }
}

struct TaskProgressMultipart: Codable, Equatable {
    let label: String
    let completedSegments: Int
    let totalSegments: Int
    let activeSegments: Int
    let segmentBytes: Int64
    let totalBytes: Int64
    let currentSegment: Int?

    var displayText: String {
        "\(completedSegments)/\(totalSegments) segments"
    }
}
