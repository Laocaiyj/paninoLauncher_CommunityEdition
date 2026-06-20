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
            let directory = try DiagnosticPackageExporter.export(
                logs: logs,
                tasks: tasks,
                coreState: coreState,
                javaStatus: javaStatus,
                managedJavaRuntimes: managedJavaRuntimes,
                javaRuntimeResolution: javaRuntimeResolution,
                networkSpeedTest: lastNetworkSpeedTest,
                environmentReport: lastEnvironmentReport
            )
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
