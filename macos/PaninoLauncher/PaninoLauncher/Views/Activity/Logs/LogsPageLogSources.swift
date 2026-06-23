import AppKit

extension LogsPage {
    var gameLogsForDisplay: [LogLine] {
        viewModel.logs.filter { $0.source == .game }
    }

    var displayedLogCount: Int {
        diagnosticsStore.filteredLogs(coreLogs: coreLogsForDisplay, gameLogs: gameLogsForDisplay).count
    }

    var coreLogsForDisplay: [LogLine] {
        let coreLogs = viewModel.logs.filter { $0.source == .core }
        guard coreLogs.isEmpty,
              let selected = taskCenterStore.selectedRecord,
              taskCenterStore.isActionableAttention(selected)
        else {
            return coreLogs
        }

        let detail = selected.errorDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = [
            "Task \(selected.id) \(selected.state.rawValue): \(selected.kind) \(selected.version)",
            "Error code: \(selected.errorCode ?? "no-error-code")",
            "Message: \(selected.message)"
        ]
        if let detail, !detail.isEmpty {
            lines.append("Detail: \(detail)")
        }
        return lines.map { LogLine(text: $0, source: .core) }
    }

    func exportDiagnostics() {
        diagnosticsStore.exportDiagnosticPackage(
            logs: logsForDiagnosticExport,
            tasks: taskCenterStore.records,
            coreState: viewModel.coreState,
            javaStatus: viewModel.javaStatus,
            managedJavaRuntimes: viewModel.managedJavaRuntimes,
            javaRuntimeResolution: viewModel.javaRuntimeResolution
        )
        taskCenterStore.enqueueLocal(
            kind: "log-export",
            name: localizedString(theme.language, english: "Diagnostic Package", chinese: "诊断包", italian: "Pacchetto diagnostico", french: "Paquet diagnostic", spanish: "Paquete de diagnóstico"),
            message: diagnosticsStore.exportStatus
        )
    }

    func copyErrorContext(_ context: ErrorDetailContext) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context.copyText, forType: .string)
    }

    func copyMinimumRepro(_ context: ErrorDetailContext) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(context.minimumReproText, forType: .string)
    }

    private var logsForDiagnosticExport: [LogLine] {
        if viewModel.logs.contains(where: { $0.source == .core }) {
            return viewModel.logs
        }
        return viewModel.logs + coreLogsForDisplay
    }
}
