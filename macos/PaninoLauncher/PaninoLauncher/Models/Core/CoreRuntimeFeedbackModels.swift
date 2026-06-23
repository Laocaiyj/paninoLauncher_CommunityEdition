import Foundation

struct CoreRuntimeFeedback: Codable, Equatable, Sendable {
    let status: String
    let signals: [String]
    let actions: [String]
    let lastLaunchState: String?
    let lastLaunchTaskId: String?
    let exitCode: Int?
    let durationMs: Int?
    let profilePath: String?
    let profilePresent: Bool?
    let latestLogPath: String?
    let latestLogPresent: Bool?
    let crashReportPath: String?
    let crashReportPresent: Bool?
    let logSummary: String?
}
