import Foundation

@MainActor
extension LauncherLogicSelfTest {
    static func runDiagnosticExportModelTests(_ failures: inout [String]) {
        let primary = makeDiagnostic(code: "network_timeout", message: "Network timed out", filePath: "/Users/example/.minecraft/mods/iris.jar")
        let secondary = makeDiagnostic(code: "hash_mismatch", message: "Hash mismatch", filePath: "/Users/example/.minecraft/mods/sodium.jar")
        let record = makeRecord(
            id: "diagnostic-record",
            kind: "content-install",
            state: .failed,
            currentFile: "/Users/example/.minecraft/mods/iris.jar",
            errorCode: "network_timeout",
            diagnostic: primary,
            diagnostics: [primary, secondary]
        )

        let bundle = DiagnosticBundle.from(tasks: [record])
        expect(bundle.diagnostics.map(\.code) == ["network_timeout", "hash_mismatch"], "diagnostic bundle should prefer structured diagnostics array", &failures)

        let fallbackRecord = makeRecord(
            id: "fallback-diagnostic-record",
            kind: "launch",
            state: .failed,
            diagnostic: primary,
            diagnostics: nil
        )
        expect(DiagnosticBundle.from(tasks: [fallbackRecord]).diagnostics.map(\.code) == ["network_timeout"], "diagnostic bundle should fallback to primary diagnostic", &failures)

        var progressRecordSource = record
        progressRecordSource.currentFile = "/Users/example/.minecraft/libraries?access_token=secret"
        progressRecordSource.progress = 0.625
        progressRecordSource.sourceHost = "example.invalid?access_token=host-secret"
        progressRecordSource.progressEvents = [
            makeProgress(overallPercent: 10, currentLabel: "start"),
            makeProgress(overallPercent: 62.5, currentLabel: "middle")
        ]
        let progress = DiagnosticProgressRecord(record: progressRecordSource)
        expect(progress.progressPercent == 63, "diagnostic progress should round progress percent", &failures)
        expect(!progress.currentFile.contains("/Users/example"), "diagnostic progress should redact local current file path", &failures)
        expect(!progress.currentFile.contains("secret"), "diagnostic progress should redact current file query secrets", &failures)
        expect(progress.sourceHost?.contains("host-secret") == false, "diagnostic progress should redact source host secrets", &failures)
        expect(progress.progressEvents.count == 2, "diagnostic progress should preserve progress event count", &failures)

        let network = DiagnosticNetworkSummary.from(tasks: [progressRecordSource, progressRecordSource, fallbackRecord])
        expect(network.hosts.first?.taskCount == 2, "network summary should count tasks per host", &failures)
        expect(network.hosts.first?.host.contains("<redacted>") == true, "network summary should redact host text", &failures)
    }

    static func makeDiagnostic(
        code: String,
        message: String,
        filePath: String? = nil
    ) -> CoreDiagnostic {
        CoreDiagnostic(
            code: code,
            phase: "download",
            severity: "error",
            title: message,
            message: message,
            cause: "network",
            action: CoreDiagnosticAction(kind: "openDiagnostics", label: "Open diagnostics"),
            retryable: true,
            userVisible: true,
            source: "swift-self-test",
            taskId: nil,
            planId: nil,
            packageId: nil,
            filePath: filePath,
            urlHost: "example.invalid",
            evidence: [
                CoreDiagnosticEvidence(key: "path", value: filePath ?? "", redacted: filePath != nil)
            ],
            developerDetail: "detail"
        )
    }
}
