import Foundation
import AppKit
import SwiftUI

enum LogPanelTab: String, CaseIterable, Identifiable {
    case core
    case game

    var id: String { rawValue }

    var title: String {
        switch self {
        case .core:
            return "Core"
        case .game:
            return "Game"
        }
    }
}

enum LogFilterLevel: String, CaseIterable, Identifiable {
    case all
    case info
    case warning
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .info:
            return "Info"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        }
    }
}

@MainActor
final class DiagnosticsStore: ObservableObject {
    @Published var selectedTab: LogPanelTab = .core
    @Published var filterLevel: LogFilterLevel = .all
    @Published var searchText = ""
    @Published var autoScroll = true
    @Published var pauseScroll = false
    @Published var lastDiagnosticURL: URL?
    @Published var lastNetworkSpeedTest: CoreNetworkSpeedTestResponse?
    @Published var lastEnvironmentReport: CoreEnvironmentReport?
    @Published private(set) var exportStatus = "No diagnostic package exported"
    @Published private(set) var copyStatus = ""

    func filteredLogs(coreLogs: [LogLine], gameLogs: [LogLine]) -> [LogLine] {
        let source = selectedTab == .core ? coreLogs : gameLogs
        return source.filter { line in
            matches(level: filterLevel, line: line.text)
                && (searchText.isEmpty || line.text.localizedCaseInsensitiveContains(searchText))
        }
    }

    func copy(logs: [LogLine]) {
        copyText(logs.map(\.text).joined(separator: "\n"), status: "Copied \(logs.count) redacted log lines.")
    }

    func copyText(_ text: String, status: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(LogRedactor.redact(text), forType: .string)
        copyStatus = status
    }

    func copyDiagnosticSummary(
        logs: [LogLine],
        tasks: [TaskRecord],
        coreState: CoreConnectionState,
        javaStatus: JavaRuntimeStatus?
    ) {
        let active = tasks.first { $0.state.isActive }
        let attention = tasks.first { $0.state.needsAttention }
        let selected = attention ?? active ?? tasks.first
        let selectedDetail = selected?.errorDetail
        let selectedDiagnostic = selected?.diagnostic ?? selected?.diagnostics?.first
        let loader = diagnosticDetailValue("requestedLoader", in: selectedDetail)
        let loaderVersion = diagnosticDetailValue("loaderVersion", in: selectedDetail)
        let lines = [
            "Panino Launcher Diagnostic Summary",
            "Core: \(coreState.detail)",
            "Java: \(javaStatus?.displayText ?? "Not checked")",
            selected.map { "Task: \($0.name) [\($0.state.rawValue)] \($0.message)" },
            selected.map { "Minecraft version: \(diagnosticDetailValue("requestedMinecraftVersion", in: selectedDetail) ?? $0.version)" },
            selected.map { _ in "Loader: \(loader ?? "-")\(loaderVersion.map { " \($0)" } ?? "")" },
            selected.map { _ in "Shader loader: \(diagnosticDetailValue("requestedShaderLoader", in: selectedDetail) ?? "-")" },
            selected.map { _ in "Blocked reasons: \(diagnosticDetailValue("blockedReasons", in: selectedDetail) ?? "-")" },
            selected?.phaseTitle.map { "Phase: \($0)" },
            selectedDiagnostic.map { "Diagnostic: \($0.code) / \($0.phase)" },
            selectedDiagnostic.map { "Action: \($0.actionLabel)" },
            selected.map { "Progress: \(Int(($0.progress * 100).rounded()))%" },
            selected?.errorCode.map { "Error: \($0)" },
            "Log lines: \(logs.count)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")

        copyText(lines, status: "Copied redacted diagnostic summary with \(logs.count) log lines referenced.")
    }

    func exportDiagnosticPackage(
        logs: [LogLine],
        tasks: [TaskRecord],
        coreState: CoreConnectionState,
        javaStatus: JavaRuntimeStatus?,
        managedJavaRuntimes: [CoreJavaManagedRuntime] = [],
        javaRuntimeResolution: CoreJavaRuntimeResolveResponse? = nil
    ) {
        do {
            let fileManager = FileManager.default
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let directory = try LauncherPaths.appSupportDirectory()
                .appendingPathComponent("Diagnostics", isDirectory: true)
                .appendingPathComponent("diagnostic-\(formatter.string(from: Date()))", isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            var exportWarnings: [String] = []

            let appLogs = redactedLogText(logs.filter { $0.source == .app })
            let coreLogs = redactedLogText(logs.filter { $0.source == .core })
            let gameLogs = redactedLogText(logs.filter { $0.source == .game })
            try writeRedactedText(appLogs, to: directory.appendingPathComponent("app.log"))
            try writeRedactedText(coreLogs, to: directory.appendingPathComponent("core.log"))
            try writeRedactedText(gameLogs, to: directory.appendingPathComponent("game.log"))
            try writeRedactedJSON(tasks, to: directory.appendingPathComponent("tasks.json"))
            try writeRedactedJSON(DiagnosticBundle.from(tasks: tasks), to: directory.appendingPathComponent("diagnostics.json"))
            try writeRedactedJSON(tasks.map(DiagnosticProgressRecord.init(record:)), to: directory.appendingPathComponent("progress.json"))
            try writeRedactedJSON(DiagnosticEffectiveSettings.current(javaStatus: javaStatus), to: directory.appendingPathComponent("effective-settings.json"))
            try writeRedactedJSON(DiagnosticNetworkSummary.from(tasks: tasks), to: directory.appendingPathComponent("network-summary.json"))
            if let lastNetworkSpeedTest {
                try writeRedactedJSON(lastNetworkSpeedTest, to: directory.appendingPathComponent("network-speed-test.json"))
            }
            if let lastEnvironmentReport {
                try writeRedactedJSON(lastEnvironmentReport, to: directory.appendingPathComponent("system-resource-baseline.json"))
                if let jvmTuning = lastEnvironmentReport.jvmTuning {
                    try writeRedactedJSON(jvmTuning, to: directory.appendingPathComponent("jvm-tuning.json"))
                }
                if let effectiveJvmArgs = lastEnvironmentReport.launchEffectiveJvmArgs {
                    try writeRedactedText(effectiveJvmArgs.joined(separator: "\n"), to: directory.appendingPathComponent("launch-effective-jvm-args.txt"))
                }
                if let graphicsTuning = lastEnvironmentReport.graphicsTuning {
                    try writeRedactedJSON(graphicsTuning, to: directory.appendingPathComponent("graphics-tuning.json"))
                    try writeRedactedText(graphicsOptionsPatchText(graphicsTuning), to: directory.appendingPathComponent("graphics-options-patch.txt"))
                    if let backupPath = graphicsTuning.backupPath {
                        let backupURL = URL(fileURLWithPath: backupPath)
                        if fileManager.fileExists(atPath: backupURL.path) {
                            try copyRedactedDiagnosticArtifact(
                                fileManager: fileManager,
                                source: backupURL,
                                destination: directory.appendingPathComponent("options.txt.panino-backup"),
                                warnings: &exportWarnings
                            )
                        }
                    }
                }
            }
            if !managedJavaRuntimes.isEmpty {
                try writeRedactedJSON(managedJavaRuntimes, to: directory.appendingPathComponent("java-runtimes.json"))
            }
            let effectiveJavaResolution = javaRuntimeResolution ?? lastEnvironmentReport?.javaResolution
            if let effectiveJavaResolution {
                try writeRedactedJSON(effectiveJavaResolution, to: directory.appendingPathComponent("java-resolution.json"))
            }
            let javaDownload = DiagnosticJavaDownload(
                resolutionDownload: effectiveJavaResolution?.download,
                runtimeTasks: tasks
                    .filter { $0.kind == "runtime.install" }
                    .map(DiagnosticProgressRecord.init(record:))
            )
            if javaDownload.resolutionDownload != nil || !javaDownload.runtimeTasks.isEmpty {
                try writeRedactedJSON(javaDownload, to: directory.appendingPathComponent("java-download.json"))
            }
            if let installPlanGraph = installPlanGraphCandidate(tasks: tasks, fileManager: fileManager) {
                try copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: installPlanGraph,
                    destination: directory.appendingPathComponent("install-plan-graph.json"),
                    warnings: &exportWarnings
                )
            }
            for artifact in installPlanDiagnosticArtifacts(tasks: tasks, fileManager: fileManager) {
                try copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: artifact.source,
                    destination: directory.appendingPathComponent(artifact.fileName),
                    warnings: &exportWarnings
                )
            }
            if let tuningFile = diagnosticCandidate(fileName: "jvm-tuning.json", tasks: tasks, fileManager: fileManager) {
                try copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: tuningFile,
                    destination: directory.appendingPathComponent("jvm-tuning.json"),
                    warnings: &exportWarnings
                )
            }
            if let argsFile = diagnosticCandidate(fileName: "launch-effective-jvm-args.txt", tasks: tasks, fileManager: fileManager) {
                try copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: argsFile,
                    destination: directory.appendingPathComponent("launch-effective-jvm-args.txt"),
                    warnings: &exportWarnings
                )
            }
            if let graphicsTuningFile = diagnosticCandidate(fileName: "graphics-tuning.json", tasks: tasks, fileManager: fileManager) {
                try copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: graphicsTuningFile,
                    destination: directory.appendingPathComponent("graphics-tuning.json"),
                    warnings: &exportWarnings
                )
            }
            if let graphicsPatchFile = diagnosticCandidate(fileName: "graphics-options-patch.txt", tasks: tasks, fileManager: fileManager) {
                try copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: graphicsPatchFile,
                    destination: directory.appendingPathComponent("graphics-options-patch.txt"),
                    warnings: &exportWarnings
                )
            }
            try copyPerformanceEvidence(tasks: tasks, fileManager: fileManager, destination: directory.appendingPathComponent("performance", isDirectory: true), warnings: &exportWarnings)

            let environment = [
                "Core: \(coreState.detail)",
                "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
                "Host: \(Host.current().localizedName ?? "Unknown")",
                "Java: \(javaStatus?.displayText ?? "Not checked")"
            ].joined(separator: "\n")
            try writeRedactedText(environment, to: directory.appendingPathComponent("environment.txt"))
            try writeRedactedText(javaStatus?.displayText ?? "Java not checked", to: directory.appendingPathComponent("java.txt"))
            if !exportWarnings.isEmpty {
                try writeRedactedText(exportWarnings.joined(separator: "\n"), to: directory.appendingPathComponent("export-warnings.txt"))
            }

            lastDiagnosticURL = directory
            exportStatus = "Diagnostic package exported to \(directory.path) (logs redacted)."
        } catch {
            exportStatus = "Diagnostic export failed: \(error.localizedDescription)"
        }
    }

    private func matches(level: LogFilterLevel, line: String) -> Bool {
        let lowercased = line.lowercased()
        switch level {
        case .all:
            return true
        case .info:
            return !lowercased.contains("warn") && !lowercased.contains("error") && !lowercased.contains("fail")
        case .warning:
            return lowercased.contains("warn")
        case .error:
            return lowercased.contains("error") || lowercased.contains("fail")
        }
    }

    private func redactedLogText(_ logs: [LogLine]) -> String {
        logs.map { LogRedactor.redact($0.text) }.joined(separator: "\n")
    }

    private func installPlanGraphCandidate(tasks: [TaskRecord], fileManager: FileManager) -> URL? {
        diagnosticCandidate(fileName: "install-plan-graph.json", tasks: tasks, fileManager: fileManager)
    }

    private func installPlanDiagnosticArtifacts(tasks: [TaskRecord], fileManager: FileManager) -> [(source: URL, fileName: String)] {
        [
            ("downloads/install-preflight.json", "install-preflight.json"),
            ("downloads/install-state.json", "install-state.json"),
            ("downloads/install-rollback.json", "install-rollback.json"),
            ("downloads/loader-install.log", "loader-install.log"),
            ("downloads/shader-install.log", "shader-install.log"),
            ("downloads/install-plan-execution.json", "install-plan-execution.json"),
            ("downloads/content-install-lock.json", "content-install-lock.json"),
            ("downloads/content-update-lock.json", "content-update-lock.json"),
            ("downloads/performance-pack-lock.json", "performance-pack-lock.json"),
            ("modpack-install-lock.json", "modpack-install-lock.json")
        ]
        .compactMap { relativePath, fileName in
            diagnosticCandidate(relativePath: relativePath, tasks: tasks, fileManager: fileManager)
                .map { ($0, fileName) }
        }
    }

    private func diagnosticCandidate(fileName: String, tasks: [TaskRecord], fileManager: FileManager) -> URL? {
        diagnosticCandidate(relativePath: "downloads/\(fileName)", tasks: tasks, fileManager: fileManager)
    }

    private func diagnosticCandidate(relativePath: String, tasks: [TaskRecord], fileManager: FileManager) -> URL? {
        let taskDirs = tasks
            .compactMap(\.gameDir)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let candidates = Array(NSOrderedSet(array: taskDirs + [LauncherSettings.defaultMinecraftDirectory])) as? [String] ?? []
        return candidates
            .map { diagnosticURL(basePath: $0, relativePath: relativePath) }
            .first { fileManager.fileExists(atPath: $0.path) }
    }

    private func diagnosticURL(basePath: String, relativePath: String) -> URL {
        relativePath
            .split(separator: "/")
            .reduce(URL(fileURLWithPath: basePath, isDirectory: true)) { url, component in
                url.appendingPathComponent(String(component))
            }
    }

    private func copyPerformanceEvidence(tasks: [TaskRecord], fileManager: FileManager, destination: URL, warnings: inout [String]) throws {
        let taskDirs = tasks
            .compactMap(\.gameDir)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let gameDirs = Array(NSOrderedSet(array: taskDirs + [LauncherSettings.defaultMinecraftDirectory])) as? [String] ?? []
        var copied = false
        for gameDir in gameDirs {
            let root = URL(fileURLWithPath: gameDir, isDirectory: true)
                .appendingPathComponent(".panino", isDirectory: true)
                .appendingPathComponent("performance", isDirectory: true)
            guard fileManager.fileExists(atPath: root.path) else { continue }
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for relativePath in [
                "profiles/applied.json",
                "profiles/user-override.json",
                "experiments/cooldowns"
            ] {
                let source = diagnosticURL(basePath: root.path, relativePath: relativePath)
                guard fileManager.fileExists(atPath: source.path) else { continue }
                let target = destination.appendingPathComponent(relativePath.replacingOccurrences(of: "/", with: "-"))
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory)
                if isDirectory.boolValue {
                    try copyDirectoryContents(fileManager: fileManager, source: source, destination: target, warnings: &warnings)
                } else {
                    try copyRedactedDiagnosticArtifact(fileManager: fileManager, source: source, destination: target, warnings: &warnings)
                }
                copied = true
            }
            let profilesRoot = root.appendingPathComponent("profiles", isDirectory: true)
            if fileManager.fileExists(atPath: profilesRoot.path) {
                try copyDirectoryContents(
                    fileManager: fileManager,
                    source: profilesRoot,
                    destination: destination.appendingPathComponent("profiles", isDirectory: true),
                    warnings: &warnings
                )
                copied = true
            }
            if let profileFiles = try? fileManager.contentsOfDirectory(at: profilesRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for profileFile in profileFiles where profileFile.lastPathComponent.hasPrefix("candidate-") {
                    let target = destination.appendingPathComponent("profiles-\(profileFile.lastPathComponent)")
                    try copyRedactedDiagnosticArtifact(fileManager: fileManager, source: profileFile, destination: target, warnings: &warnings)
                    copied = true
                }
            }
            let sessionsRoot = root.appendingPathComponent("sessions", isDirectory: true)
            if fileManager.fileExists(atPath: sessionsRoot.path) {
                try copyDirectoryContents(
                    fileManager: fileManager,
                    source: sessionsRoot,
                    destination: destination.appendingPathComponent("sessions", isDirectory: true),
                    warnings: &warnings
                )
                copied = true
            }
            if let sessionDirs = try? fileManager.contentsOfDirectory(at: sessionsRoot, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
                for sessionDir in sessionDirs.sorted(by: { lhs, rhs in
                    let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return left > right
                }).prefix(3) {
                    for fileName in ["performance-session.json", "gc.log"] {
                        let source = sessionDir.appendingPathComponent(fileName)
                        guard fileManager.fileExists(atPath: source.path) else { continue }
                        let target = destination.appendingPathComponent("\(sessionDir.lastPathComponent)-\(fileName)")
                        try copyRedactedDiagnosticArtifact(fileManager: fileManager, source: source, destination: target, warnings: &warnings)
                        copied = true
                    }
                }
            }
        }
        if copied {
            try writeRedactedText(
                "Performance evidence copied from .panino/performance, including sessions, GC logs, applied/user profiles, candidates, and cooldowns.",
                to: destination.appendingPathComponent("README.txt")
            )
        }
    }

    private func copyDirectoryContents(fileManager: FileManager, source: URL, destination: URL, warnings: inout [String]) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let entries = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        for entry in entries {
            let target = destination.appendingPathComponent(entry.lastPathComponent)
            try copyRedactedDiagnosticArtifact(fileManager: fileManager, source: entry, destination: target, warnings: &warnings)
        }
    }

    private func diagnosticDetailValue(_ key: String, in detail: String?) -> String? {
        guard let detail else { return nil }
        let prefix = "\(key)="
        return detail
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
            .flatMap { value in
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty || trimmed == "-" ? nil : trimmed
            }
    }

    private func graphicsOptionsPatchText(_ tuning: CoreResolvedGraphicsTuning) -> String {
        var lines = [
            "Graphics tuning patch",
            "backup: \(tuning.backupPath ?? "-")",
            "summary: \(tuning.summary)",
            ""
        ]
        lines.append(contentsOf: tuning.optionsPatch.changes.map { change in
            [
                change.status,
                change.key,
                "old=\(change.oldValue ?? "-")",
                "new=\(change.newValue ?? "-")",
                "reason=\(change.reason)"
            ].joined(separator: " | ")
        })
        return lines.joined(separator: "\n")
    }

    private func writeRedactedJSON<T: Encodable>(_ value: T, to destination: URL) throws {
        let data = try JSONEncoder.panino.encode(value)
        try writeRedactedData(data, to: destination)
    }

    private func writeRedactedText(_ text: String, to destination: URL) throws {
        let data = Data(DiagnosticRedactor.redact(text).utf8)
        try writeReplacingExisting(fileManager: .default, data: data, destination: destination)
    }

    private func writeRedactedData(_ data: Data, to destination: URL) throws {
        let redacted = DiagnosticRedactor.redactedData(data)
        try writeReplacingExisting(fileManager: .default, data: redacted, destination: destination)
    }

    private func copyRedactedDiagnosticArtifact(fileManager: FileManager, source: URL, destination: URL, warnings: inout [String]) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else { return }
        if isDirectory.boolValue {
            try copyDirectoryContents(fileManager: fileManager, source: source, destination: destination, warnings: &warnings)
            return
        }
        let data = try Data(contentsOf: source)
        guard DiagnosticRedactor.canRedact(data) else {
            warnings.append("Skipped non-text diagnostic artifact: \(DiagnosticRedactor.redact(source.path))")
            return
        }
        try writeReplacingExisting(fileManager: fileManager, data: DiagnosticRedactor.redactedData(data), destination: destination)
    }

    private func writeReplacingExisting(fileManager: FileManager, data: Data, destination: URL) throws {
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try data.write(to: destination, options: .atomic)
    }
}

private struct DiagnosticBundle: Codable {
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

private struct DiagnosticProgressRecord: Codable {
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

private struct DiagnosticEffectiveSettings: Codable {
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
        let curseForgeAPIKeyConfigured = UserDefaults.standard.bool(forKey: "OnlineContent.CurseForgeAPIKeyConfigured")
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

private struct DiagnosticJavaDownload: Codable {
    let resolutionDownload: CoreJavaRuntimeDownloadSpec?
    let runtimeTasks: [DiagnosticProgressRecord]
}

private struct DiagnosticNetworkSummary: Codable {
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

private struct DiagnosticHostSummary: Codable {
    let host: String
    let taskCount: Int
}

enum DiagnosticRedactor {
    static func redact(_ text: String) -> String {
        var redacted = text
        let patterns = [
            #"(?i)(--session-token(?:=|\s+))\S+"#,
            #"(?i)(--access-token(?:=|\s+))\S+"#,
            #"(?i)(--accessToken(?:=|\s+))\S+"#,
            #"(?i)((?:Authorization|Proxy-Authorization)\s*:\s*(?:Bearer|Basic)\s+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(Bearer\s+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(Basic\s+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)([?&](?:token|access_token|refresh_token|client_secret|signature|sig|X-Amz-Signature|AWSAccessKeyId)=)[^&\s]+"#,
            #"(?i)(access[_-]?token["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(refresh[_-]?token["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(id[_-]?token["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(session[_-]?token["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(client[_-]?secret["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(api[_-]?key["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(x-api-key["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(x-auth-token["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(x-ms-[A-Za-z0-9_-]+["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(authorization["':=\s]+)[A-Za-z0-9._~+/=-]+"#,
            #"(?i)(cookie["':=\s]+)[^"',\n}]+"#,
            #"(?i)(set-cookie["':=\s]+)[^"',\n}]+"#
        ]

        for pattern in patterns {
            redacted = redacted.replacingOccurrences(
                of: pattern,
                with: "$1<redacted>",
                options: .regularExpression
            )
        }
        return redactLocalPaths(redacted)
    }

    static func redactedData(_ data: Data) -> Data {
        if let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
            let sanitized = sanitizeJSONValue(object)
            if JSONSerialization.isValidJSONObject(sanitized),
               let jsonData = try? JSONSerialization.data(withJSONObject: sanitized, options: [.prettyPrinted, .sortedKeys]) {
                return jsonData
            }
        }
        if let text = String(data: data, encoding: .utf8) {
            return Data(redact(text).utf8)
        }
        return Data()
    }

    static func canRedact(_ data: Data) -> Bool {
        if (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
            return true
        }
        return String(data: data, encoding: .utf8) != nil
    }

    private static func sanitizeJSONValue(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            var sanitized: [String: Any] = [:]
            for (key, child) in dictionary {
                sanitized[key] = isSensitiveKey(key) ? "<redacted>" : sanitizeJSONValue(child)
            }
            return sanitized
        }
        if let array = value as? [Any] {
            return array.map(sanitizeJSONValue)
        }
        if let string = value as? String {
            return redact(string)
        }
        return value
    }

    private static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased().replacingOccurrences(of: #"[^a-z0-9]"#, with: "", options: .regularExpression)
        if normalized.contains("token")
            || normalized.contains("secret")
            || normalized.contains("apikey")
            || normalized.contains("authorization")
            || normalized.contains("cookie")
            || normalized.contains("signature")
            || normalized == "sig"
            || normalized == "awsaccesskeyid" {
            return true
        }
        return normalized.hasPrefix("xms") || normalized == "xauthtoken" || normalized == "xapikey"
    }

    private static func redactLocalPaths(_ text: String) -> String {
        var redacted = text
        let home = NSHomeDirectory()
        if !home.isEmpty {
            redacted = redacted.replacingOccurrences(of: "file://\(home)", with: "file://~")
            redacted = redacted.replacingOccurrences(of: home, with: "~")
        }
        redacted = redacted.replacingOccurrences(
            of: #"file:///Users/[^/\s"']+"#,
            with: "file://~",
            options: .regularExpression
        )
        redacted = redacted.replacingOccurrences(
            of: #"/Users/[^/\s"']+"#,
            with: "~",
            options: .regularExpression
        )
        return redacted
    }
}

enum LogRedactor {
    static func redact(_ text: String) -> String {
        DiagnosticRedactor.redact(text)
    }
}
