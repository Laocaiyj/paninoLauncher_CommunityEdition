import Foundation

struct DiagnosticBundle: Codable {
    let diagnostics: [CoreDiagnostic]

    static func from(tasks: [TaskRecord]) -> DiagnosticBundle {
        let values = tasks.flatMap { record -> [CoreDiagnostic] in
            if let diagnostics = record.diagnostics, !diagnostics.isEmpty {
                return diagnostics
            }
            return record.diagnostic.map { [$0] } ?? []
        }
        return DiagnosticBundle(diagnostics: values)
    }
}

struct DiagnosticProgressRecord: Codable {
    let taskId: String
    let name: String
    let state: String
    let progressPercent: Int
    let phaseTitle: String?
    let phaseIndex: Int?
    let phaseCount: Int?
    let currentFile: String
    let completedJobs: Int?
    let totalJobs: Int?
    let completedBytes: Int64?
    let totalBytes: Int64?
    let speed: String
    let remainingTime: String
    let sourceHost: String?
    let retryCount: Int?
    let movingAverageSpeed: String?
    let throttleReason: String?
    let hostTelemetry: [TaskProgressHost]?
    let multipartTelemetry: TaskProgressMultipart?
    let progressEvents: [TaskProgress]
    let updatedAt: Date
    let finishedAt: Date?

    init(record: TaskRecord) {
        taskId = record.id
        name = record.name
        state = record.state.rawValue
        progressPercent = Int((record.progress * 100).rounded())
        phaseTitle = record.phaseTitle
        phaseIndex = record.phaseIndex
        phaseCount = record.phaseCount
        currentFile = LogRedactor.redact(record.currentFile)
        completedJobs = record.completedJobs
        totalJobs = record.totalJobs
        completedBytes = record.completedBytes
        totalBytes = record.totalBytes
        speed = record.speed
        remainingTime = record.remainingTime
        sourceHost = record.sourceHost.map(LogRedactor.redact)
        retryCount = record.retryCount
        movingAverageSpeed = record.movingAverageSpeed
        throttleReason = record.throttleReason
        hostTelemetry = record.hostTelemetry
        multipartTelemetry = record.multipartTelemetry
        progressEvents = record.progressEvents ?? []
        updatedAt = record.updatedAt
        finishedAt = record.finishedAt
    }
}

struct DiagnosticEffectiveSettings: Codable {
    let downloadStrategy: String
    let downloadConcurrency: Int
    let retryCount: Int
    let source: String
    let proxyConfigured: Bool
    let curseForgeAPIKeyConfigured: Bool
    let java: String

    @MainActor
    static func current(javaStatus: JavaRuntimeStatus?) -> DiagnosticEffectiveSettings {
        let download = LauncherSettings.storedDownloadRuntimeOptions()
        let proxyAddress = SettingsStore.string(forKey: "Settings.ProxyAddress", default: "")
        let curseForgeAPIKeyConfigured = UserDefaults.standard.bool(
            forKey: OnlineContentCredentialStore.curseForgeAPIKeyConfiguredKey
        )
        return DiagnosticEffectiveSettings(
            downloadStrategy: LauncherSettings.storedDownloadStrategy().rawValue,
            downloadConcurrency: download.concurrency,
            retryCount: download.retryCount,
            source: LauncherSettings.storedDownloadSource().rawValue,
            proxyConfigured: !proxyAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            curseForgeAPIKeyConfigured: curseForgeAPIKeyConfigured,
            java: javaStatus?.displayText ?? "Not checked"
        )
    }
}

struct DiagnosticJavaDownload: Codable {
    let resolutionDownload: CoreJavaRuntimeDownloadSpec?
    let runtimeTasks: [DiagnosticProgressRecord]
}

struct DiagnosticNetworkSummary: Codable {
    let hosts: [DiagnosticHostSummary]

    static func from(tasks: [TaskRecord]) -> DiagnosticNetworkSummary {
        let grouped = Dictionary(grouping: tasks.compactMap(\.sourceHost)) { $0 }
        return DiagnosticNetworkSummary(
            hosts: grouped
                .map { host, entries in
                    DiagnosticHostSummary(host: LogRedactor.redact(host), taskCount: entries.count)
                }
                .sorted { $0.host < $1.host }
        )
    }
}

struct DiagnosticHostSummary: Codable {
    let host: String
    let taskCount: Int
}
