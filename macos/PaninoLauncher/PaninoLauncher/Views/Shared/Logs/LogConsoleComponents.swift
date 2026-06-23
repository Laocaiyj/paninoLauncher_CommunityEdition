import SwiftUI

struct LogConsole: View {
    let title: String
    let logs: [LogLine]
    let gameLogs: [LogLine]
    let exportedURL: URL?
    let diagnosticURL: URL?
    var showsPanel = true
    var scrollMinHeight: CGFloat = 320
    let onExport: () -> Void
    let onClear: () -> Void
    let onExportDiagnostics: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @State private var selectedLogID: UUID?

    private var visibleLogs: [LogLine] {
        diagnosticsStore.filteredLogs(coreLogs: logs, gameLogs: gameLogs)
    }

    private var selectedLogs: [LogLine] {
        guard let selectedLogID else { return [] }
        return visibleLogs.filter { $0.id == selectedLogID }
    }

    var body: some View {
        Group {
            if showsPanel {
                GlassPanel {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            LogConsoleToolbar(
                title: title,
                onExport: onExport,
                onExportDiagnostics: onExportDiagnostics,
                onClear: onClear
            )

            LogConsoleFilterBar(
                selectedLogs: selectedLogs,
                onCopySelected: { diagnosticsStore.copy(logs: selectedLogs) }
            )

            LogConsolePathRows(
                exportedURL: exportedURL,
                diagnosticURL: diagnosticURL
            )

            LogConsoleViewport(
                logs: logs,
                gameLogs: gameLogs,
                visibleLogs: visibleLogs,
                selectedLogID: $selectedLogID,
                scrollMinHeight: scrollMinHeight,
                onExportDiagnostics: onExportDiagnostics
            )
        }
    }
}
