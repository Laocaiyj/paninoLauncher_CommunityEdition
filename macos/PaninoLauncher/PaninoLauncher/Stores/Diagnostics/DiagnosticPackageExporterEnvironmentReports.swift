import Foundation

extension DiagnosticPackageExporter {
    static func writeNetworkAndEnvironment(
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

    static func writeGraphicsTuningBackup(
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
}
