import Foundation

@MainActor
enum DiagnosticPackageExporter {
    static func export(
        logs: [LogLine],
        tasks: [TaskRecord],
        coreState: CoreConnectionState,
        javaStatus: JavaRuntimeStatus?,
        managedJavaRuntimes: [CoreJavaManagedRuntime],
        javaRuntimeResolution: CoreJavaRuntimeResolveResponse?,
        networkSpeedTest: CoreNetworkSpeedTestResponse?,
        environmentReport: CoreEnvironmentReport?
    ) throws -> URL {
        let fileManager = FileManager.default
        let directory = try makeExportDirectory()
        var exportWarnings: [String] = []

        try writeLogFiles(logs: logs, to: directory)
        try writeCoreReports(tasks: tasks, javaStatus: javaStatus, to: directory)
        try writeNetworkAndEnvironment(
            networkSpeedTest: networkSpeedTest,
            environmentReport: environmentReport,
            fileManager: fileManager,
            directory: directory,
            warnings: &exportWarnings
        )
        try writeJavaReports(
            tasks: tasks,
            javaStatus: javaStatus,
            managedJavaRuntimes: managedJavaRuntimes,
            javaRuntimeResolution: javaRuntimeResolution,
            environmentReport: environmentReport,
            directory: directory
        )
        try copyTaskArtifacts(tasks: tasks, fileManager: fileManager, directory: directory, warnings: &exportWarnings)
        try writeHostEnvironment(coreState: coreState, javaStatus: javaStatus, to: directory)
        if !exportWarnings.isEmpty {
            try DiagnosticsPackageWriter.writeRedactedText(
                exportWarnings.joined(separator: "\n"),
                to: directory.appendingPathComponent("export-warnings.txt")
            )
        }
        return directory
    }

    private static func makeExportDirectory() throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let directory = try LauncherPaths.appSupportDirectory()
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("diagnostic-\(formatter.string(from: Date()))", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func writeLogFiles(logs: [LogLine], to directory: URL) throws {
        let appLogs = DiagnosticsPackageWriter.redactedLogText(logs.filter { $0.source == .app })
        let coreLogs = DiagnosticsPackageWriter.redactedLogText(logs.filter { $0.source == .core })
        let gameLogs = DiagnosticsPackageWriter.redactedLogText(logs.filter { $0.source == .game })
        try DiagnosticsPackageWriter.writeRedactedText(appLogs, to: directory.appendingPathComponent("app.log"))
        try DiagnosticsPackageWriter.writeRedactedText(coreLogs, to: directory.appendingPathComponent("core.log"))
        try DiagnosticsPackageWriter.writeRedactedText(gameLogs, to: directory.appendingPathComponent("game.log"))
    }

    private static func writeCoreReports(tasks: [TaskRecord], javaStatus: JavaRuntimeStatus?, to directory: URL) throws {
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

    private static func writeNetworkAndEnvironment(
        networkSpeedTest: CoreNetworkSpeedTestResponse?,
        environmentReport: CoreEnvironmentReport?,
        fileManager: FileManager,
        directory: URL,
        warnings: inout [String]
    ) throws {
        if let networkSpeedTest {
            try DiagnosticsPackageWriter.writeRedactedJSON(
                networkSpeedTest,
                to: directory.appendingPathComponent("network-speed-test.json")
            )
        }
        guard let environmentReport else { return }

        try DiagnosticsPackageWriter.writeRedactedJSON(
            environmentReport,
            to: directory.appendingPathComponent("system-resource-baseline.json")
        )
        if let jvmTuning = environmentReport.jvmTuning {
            try DiagnosticsPackageWriter.writeRedactedJSON(jvmTuning, to: directory.appendingPathComponent("jvm-tuning.json"))
        }
        if let effectiveJvmArgs = environmentReport.launchEffectiveJvmArgs {
            try DiagnosticsPackageWriter.writeRedactedText(
                effectiveJvmArgs.joined(separator: "\n"),
                to: directory.appendingPathComponent("launch-effective-jvm-args.txt")
            )
        }
        try writeGraphicsTuningBackup(
            environmentReport: environmentReport,
            fileManager: fileManager,
            directory: directory,
            warnings: &warnings
        )
    }

    private static func writeGraphicsTuningBackup(
        environmentReport: CoreEnvironmentReport,
        fileManager: FileManager,
        directory: URL,
        warnings: inout [String]
    ) throws {
        guard let graphicsTuning = environmentReport.graphicsTuning else { return }

        try DiagnosticsPackageWriter.writeRedactedJSON(
            graphicsTuning,
            to: directory.appendingPathComponent("graphics-tuning.json")
        )
        try DiagnosticsPackageWriter.writeRedactedText(
            DiagnosticsPackageWriter.graphicsOptionsPatchText(graphicsTuning),
            to: directory.appendingPathComponent("graphics-options-patch.txt")
        )
        guard let backupPath = graphicsTuning.backupPath else { return }

        let backupURL = URL(fileURLWithPath: backupPath)
        if fileManager.fileExists(atPath: backupURL.path) {
            try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                fileManager: fileManager,
                source: backupURL,
                destination: directory.appendingPathComponent("options.txt.panino-backup"),
                warnings: &warnings
            )
        }
    }

    private static func writeJavaReports(
        tasks: [TaskRecord],
        javaStatus: JavaRuntimeStatus?,
        managedJavaRuntimes: [CoreJavaManagedRuntime],
        javaRuntimeResolution: CoreJavaRuntimeResolveResponse?,
        environmentReport: CoreEnvironmentReport?,
        directory: URL
    ) throws {
        if !managedJavaRuntimes.isEmpty {
            try DiagnosticsPackageWriter.writeRedactedJSON(
                managedJavaRuntimes,
                to: directory.appendingPathComponent("java-runtimes.json")
            )
        }
        let effectiveJavaResolution = javaRuntimeResolution ?? environmentReport?.javaResolution
        if let effectiveJavaResolution {
            try DiagnosticsPackageWriter.writeRedactedJSON(
                effectiveJavaResolution,
                to: directory.appendingPathComponent("java-resolution.json")
            )
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
        try DiagnosticsPackageWriter.writeRedactedText(
            javaStatus?.displayText ?? "Java not checked",
            to: directory.appendingPathComponent("java.txt")
        )
    }

    private static func copyTaskArtifacts(
        tasks: [TaskRecord],
        fileManager: FileManager,
        directory: URL,
        warnings: inout [String]
    ) throws {
        if let installPlanGraph = DiagnosticsPackageWriter.installPlanGraphCandidate(tasks: tasks, fileManager: fileManager) {
            try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                fileManager: fileManager,
                source: installPlanGraph,
                destination: directory.appendingPathComponent("install-plan-graph.json"),
                warnings: &warnings
            )
        }
        for artifact in DiagnosticsPackageWriter.installPlanDiagnosticArtifacts(tasks: tasks, fileManager: fileManager) {
            try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
                fileManager: fileManager,
                source: artifact.source,
                destination: directory.appendingPathComponent(artifact.fileName),
                warnings: &warnings
            )
        }
        try copyNamedArtifact(fileName: "jvm-tuning.json", tasks: tasks, fileManager: fileManager, directory: directory, warnings: &warnings)
        try copyNamedArtifact(fileName: "launch-effective-jvm-args.txt", tasks: tasks, fileManager: fileManager, directory: directory, warnings: &warnings)
        try copyNamedArtifact(fileName: "graphics-tuning.json", tasks: tasks, fileManager: fileManager, directory: directory, warnings: &warnings)
        try copyNamedArtifact(fileName: "graphics-options-patch.txt", tasks: tasks, fileManager: fileManager, directory: directory, warnings: &warnings)
        try DiagnosticsPackageWriter.copyPerformanceEvidence(
            tasks: tasks,
            fileManager: fileManager,
            destination: directory.appendingPathComponent("performance", isDirectory: true),
            warnings: &warnings
        )
    }

    private static func copyNamedArtifact(
        fileName: String,
        tasks: [TaskRecord],
        fileManager: FileManager,
        directory: URL,
        warnings: inout [String]
    ) throws {
        guard let source = DiagnosticsPackageWriter.diagnosticCandidate(fileName: fileName, tasks: tasks, fileManager: fileManager) else {
            return
        }
        try DiagnosticsPackageWriter.copyRedactedDiagnosticArtifact(
            fileManager: fileManager,
            source: source,
            destination: directory.appendingPathComponent(fileName),
            warnings: &warnings
        )
    }

    private static func writeHostEnvironment(coreState: CoreConnectionState, javaStatus: JavaRuntimeStatus?, to directory: URL) throws {
        let environment = [
            "Core: \(coreState.detail)",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Host: \(Host.current().localizedName ?? "Unknown")",
            "Java: \(javaStatus?.displayText ?? "Not checked")"
        ].joined(separator: "\n")
        try DiagnosticsPackageWriter.writeRedactedText(environment, to: directory.appendingPathComponent("environment.txt"))
    }
}
