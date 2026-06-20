import Foundation

extension DiagnosticPackageExporter {
    static func writeJavaReports(
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
}
