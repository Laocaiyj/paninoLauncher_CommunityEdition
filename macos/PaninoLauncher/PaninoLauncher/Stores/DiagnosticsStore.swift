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
        let loader = DiagnosticsPackageWriter.diagnosticDetailValue("requestedLoader", in: selectedDetail)
        let loaderVersion = DiagnosticsPackageWriter.diagnosticDetailValue("loaderVersion", in: selectedDetail)
        let lines = [
            "Panino Launcher Diagnostic Summary",
            "Core: \(coreState.detail)",
            "Java: \(javaStatus?.displayText ?? "Not checked")",
            selected.map { "Task: \($0.name) [\($0.state.rawValue)] \($0.message)" },
            selected.map { "Minecraft version: \(DiagnosticsPackageWriter.diagnosticDetailValue("requestedMinecraftVersion", in: selectedDetail) ?? $0.version)" },
            selected.map { _ in "Loader: \(loader ?? "-")\(loaderVersion.map { " \($0)" } ?? "")" },
            selected.map { _ in "Shader loader: \(DiagnosticsPackageWriter.diagnosticDetailValue("requestedShaderLoader", in: selectedDetail) ?? "-")" },
            selected.map { _ in "Blocked reasons: \(DiagnosticsPackageWriter.diagnosticDetailValue("blockedReasons", in: selectedDetail) ?? "-")" },
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

            let appLogs = DiagnosticsPackageWriter.redactedLogText(logs.filter { $0.source == .app })
            let coreLogs = DiagnosticsPackageWriter.redactedLogText(logs.filter { $0.source == .core })
            let gameLogs = DiagnosticsPackageWriter.redactedLogText(logs.filter { $0.source == .game })
            try DiagnosticsPackageWriter.writeRedactedText(appLogs, to: directory.appendingPathComponent("app.log"))
            try DiagnosticsPackageWriter.writeRedactedText(coreLogs, to: directory.appendingPathComponent("core.log"))
            try DiagnosticsPackageWriter.writeRedactedText(gameLogs, to: directory.appendingPathComponent("game.log"))
            try DiagnosticsPackageWriter.writeRedactedJSON(tasks, to: directory.appendingPathComponent("tasks.json"))
            try DiagnosticsPackageWriter.writeRedactedJSON(DiagnosticBundle.from(tasks: tasks), to: directory.appendingPathComponent("diagnostics.json"))
            try DiagnosticsPackageWriter.writeRedactedJSON(tasks.map(DiagnosticProgressRecord.init(record:)), to: directory.appendingPathComponent("progress.json"))
            try DiagnosticsPackageWriter.writeRedactedJSON(DiagnosticEffectiveSettings.current(javaStatus: javaStatus), to: directory.appendingPathComponent("effective-settings.json"))
            try DiagnosticsPackageWriter.writeRedactedJSON(DiagnosticNetworkSummary.from(tasks: tasks), to: directory.appendingPathComponent("network-summary.json"))
            if let lastNetworkSpeedTest {
                try DiagnosticsPackageWriter.writeRedactedJSON(lastNetworkSpeedTest, to: directory.appendingPathComponent("network-speed-test.json"))
            }
            if let lastEnvironmentReport {
                try DiagnosticsPackageWriter.writeRedactedJSON(lastEnvironmentReport, to: directory.appendingPathComponent("system-resource-baseline.json"))
                if let jvmTuning = lastEnvironmentReport.jvmTuning {
                    try DiagnosticsPackageWriter.writeRedactedJSON(jvmTuning, to: directory.appendingPathComponent("jvm-tuning.json"))
                }
                if let effectiveJvmArgs = lastEnvironmentReport.launchEffectiveJvmArgs {
                    try DiagnosticsPackageWriter.writeRedactedText(effectiveJvmArgs.joined(separator: "\n"), to: directory.appendingPathComponent("launch-effective-jvm-args.txt"))
                }
                if let graphicsTuning = lastEnvironmentReport.graphicsTuning {
                    try DiagnosticsPackageWriter.writeRedactedJSON(graphicsTuning, to: directory.appendingPathComponent("graphics-tuning.json"))
                    try DiagnosticsPackageWriter.writeRedactedText(DiagnosticsPackageWriter.graphicsOptionsPatchText(graphicsTuning), to: directory.appendingPathComponent("graphics-options-patch.txt"))
                    if let backupPath = graphicsTuning.backupPath {
                        let backupURL = URL(fileURLWithPath: backupPath)
                        if fileManager.fileExists(atPath: backupURL.path) {
                            try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
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
                try DiagnosticsPackageWriter.writeRedactedJSON(managedJavaRuntimes, to: directory.appendingPathComponent("java-runtimes.json"))
            }
            let effectiveJavaResolution = javaRuntimeResolution ?? lastEnvironmentReport?.javaResolution
            if let effectiveJavaResolution {
                try DiagnosticsPackageWriter.writeRedactedJSON(effectiveJavaResolution, to: directory.appendingPathComponent("java-resolution.json"))
            }
            let javaDownload = DiagnosticJavaDownload(
                resolutionDownload: effectiveJavaResolution?.download,
                runtimeTasks: tasks
                    .filter { $0.kind == "runtime.install" }
                    .map(DiagnosticProgressRecord.init(record:))
            )
            if javaDownload.resolutionDownload != nil || !javaDownload.runtimeTasks.isEmpty {
                try DiagnosticsPackageWriter.writeRedactedJSON(javaDownload, to: directory.appendingPathComponent("java-download.json"))
            }
            if let installPlanGraph = DiagnosticsPackageWriter.installPlanGraphCandidate(tasks: tasks, fileManager: fileManager) {
                try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: installPlanGraph,
                    destination: directory.appendingPathComponent("install-plan-graph.json"),
                    warnings: &exportWarnings
                )
            }
            for artifact in DiagnosticsPackageWriter.installPlanDiagnosticArtifacts(tasks: tasks, fileManager: fileManager) {
                try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: artifact.source,
                    destination: directory.appendingPathComponent(artifact.fileName),
                    warnings: &exportWarnings
                )
            }
            if let tuningFile = DiagnosticsPackageWriter.diagnosticCandidate(fileName: "jvm-tuning.json", tasks: tasks, fileManager: fileManager) {
                try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: tuningFile,
                    destination: directory.appendingPathComponent("jvm-tuning.json"),
                    warnings: &exportWarnings
                )
            }
            if let argsFile = DiagnosticsPackageWriter.diagnosticCandidate(fileName: "launch-effective-jvm-args.txt", tasks: tasks, fileManager: fileManager) {
                try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: argsFile,
                    destination: directory.appendingPathComponent("launch-effective-jvm-args.txt"),
                    warnings: &exportWarnings
                )
            }
            if let graphicsTuningFile = DiagnosticsPackageWriter.diagnosticCandidate(fileName: "graphics-tuning.json", tasks: tasks, fileManager: fileManager) {
                try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: graphicsTuningFile,
                    destination: directory.appendingPathComponent("graphics-tuning.json"),
                    warnings: &exportWarnings
                )
            }
            if let graphicsPatchFile = DiagnosticsPackageWriter.diagnosticCandidate(fileName: "graphics-options-patch.txt", tasks: tasks, fileManager: fileManager) {
                try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                    fileManager: fileManager,
                    source: graphicsPatchFile,
                    destination: directory.appendingPathComponent("graphics-options-patch.txt"),
                    warnings: &exportWarnings
                )
            }
            try DiagnosticsPackageWriter.copyPerformanceEvidence(tasks: tasks, fileManager: fileManager, destination: directory.appendingPathComponent("performance", isDirectory: true), warnings: &exportWarnings)

            let environment = [
                "Core: \(coreState.detail)",
                "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
                "Host: \(Host.current().localizedName ?? "Unknown")",
                "Java: \(javaStatus?.displayText ?? "Not checked")"
            ].joined(separator: "\n")
            try DiagnosticsPackageWriter.writeRedactedText(environment, to: directory.appendingPathComponent("environment.txt"))
            try DiagnosticsPackageWriter.writeRedactedText(javaStatus?.displayText ?? "Java not checked", to: directory.appendingPathComponent("java.txt"))
            if !exportWarnings.isEmpty {
                try DiagnosticsPackageWriter.writeRedactedText(exportWarnings.joined(separator: "\n"), to: directory.appendingPathComponent("export-warnings.txt"))
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
}
