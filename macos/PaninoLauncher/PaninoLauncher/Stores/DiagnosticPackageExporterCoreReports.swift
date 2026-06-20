import Foundation

extension DiagnosticPackageExporter {
    static func writeLogFiles(logs: [LogLine], to directory: URL) throws {
        let appLogs = DiagnosticsPackageWriter.redactedLogText(logs.filter { $0.source == .app })
        let coreLogs = DiagnosticsPackageWriter.redactedLogText(logs.filter { $0.source == .core })
        let gameLogs = DiagnosticsPackageWriter.redactedLogText(logs.filter { $0.source == .game })
        try DiagnosticsPackageWriter.writeRedactedText(appLogs, to: directory.appendingPathComponent("app.log"))
        try DiagnosticsPackageWriter.writeRedactedText(coreLogs, to: directory.appendingPathComponent("core.log"))
        try DiagnosticsPackageWriter.writeRedactedText(gameLogs, to: directory.appendingPathComponent("game.log"))
    }

    static func writeCoreReports(tasks: [TaskRecord], javaStatus: JavaRuntimeStatus?, to directory: URL) throws {
        try DiagnosticsPackageWriter.writeRedactedJSON(tasks, to: directory.appendingPathComponent("tasks.json"))
        try DiagnosticsPackageWriter.writeRedactedJSON(
            DiagnosticBundle.from(tasks: tasks),
            to: directory.appendingPathComponent("diagnostics.json")
        )
        try DiagnosticsPackageWriter.writeRedactedJSON(
            tasks.map(DiagnosticProgressRecord.init(record:)),
            to: directory.appendingPathComponent("progress.json")
        )
        try DiagnosticsPackageWriter.writeRedactedJSON(
            DiagnosticEffectiveSettings.current(javaStatus: javaStatus),
            to: directory.appendingPathComponent("effective-settings.json")
        )
        try DiagnosticsPackageWriter.writeRedactedJSON(
            DiagnosticNetworkSummary.from(tasks: tasks),
            to: directory.appendingPathComponent("network-summary.json")
        )
    }

    static func writeHostEnvironment(coreState: CoreConnectionState, javaStatus: JavaRuntimeStatus?, to directory: URL) throws {
        let environment = [
            "Core: \(coreState.detail)",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Host: \(Host.current().localizedName ?? "Unknown")",
            "Java: \(javaStatus?.displayText ?? "Not checked")"
        ].joined(separator: "\n")
        try DiagnosticsPackageWriter.writeRedactedText(environment, to: directory.appendingPathComponent("environment.txt"))
    }
}
