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

    static func makeExportDirectory() throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let directory = try LauncherPaths.appSupportDirectory()
            .appendingPathComponent("Diagnostics", isDirectory: true)
            .appendingPathComponent("diagnostic-\(formatter.string(from: Date()))", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
