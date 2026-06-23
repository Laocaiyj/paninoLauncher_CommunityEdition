import Foundation

extension DiagnosticPackageExporter {
    static func copyTaskArtifacts(
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

    static func copyNamedArtifact(
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
}
