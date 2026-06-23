import SwiftUI

struct LogsPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @EnvironmentObject var theme: ThemeSettings
    @EnvironmentObject var diagnosticsStore: DiagnosticsStore
    @EnvironmentObject var taskCenterStore: TaskCenterStore
    @State private var areLogsExpanded = false

    var body: some View {
        logWorkspace
        .padding(20)
        .frame(minWidth: 760, minHeight: 620)
    }

    @ViewBuilder
    private var logWorkspace: some View {
        if let context = errorContext {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: theme.fontDensity.spacing) {
                    ErrorDetailPanel(context: context, onCopy: copyErrorContext, onCopyRepro: copyMinimumRepro, onExportDiagnostics: exportDiagnostics)
                        .frame(minWidth: 420, maxWidth: .infinity, alignment: .topLeading)
                    logConsole(showsPanel: true, scrollMinHeight: 360)
                        .frame(width: 440, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    ErrorDetailPanel(context: context, onCopy: copyErrorContext, onCopyRepro: copyMinimumRepro, onExportDiagnostics: exportDiagnostics)
                    collapsedLogConsole
                }
            }
        } else {
            logConsole(showsPanel: true, scrollMinHeight: 320)
                .frame(minHeight: 420)
        }
    }

    private var collapsedLogConsole: some View {
        GlassPanel(showsShadow: false, surfaceLevel: .panel) {
            FullWidthDisclosureGroup(isExpanded: $areLogsExpanded) {
                logConsole(showsPanel: false, scrollMinHeight: 220)
                    .padding(.top, 12)
            } label: {
                HStack(spacing: 10) {
                    Text(localizedString(theme.language, english: "Logs", chinese: "日志详情", italian: "Log", french: "Journaux", spanish: "Registros"))
                        .font(.headline)
                    CountText(value: displayedLogCount)
                    Text(localizedString(theme.language, english: "Expand only when you need raw Core/Game output.", chinese: "仅在需要原始 Core/游戏输出时展开。", italian: "Espandi solo se servono i log grezzi.", french: "Dépliez seulement si les journaux bruts sont nécessaires.", spanish: "Expande solo si necesitas la salida sin procesar."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }

    private func logConsole(showsPanel: Bool, scrollMinHeight: CGFloat) -> some View {
        LogConsole(
            title: AppText.coreLogs.localized(theme.language),
            logs: coreLogsForDisplay,
            gameLogs: gameLogsForDisplay,
            exportedURL: viewModel.lastExportedLogURL,
            diagnosticURL: diagnosticsStore.lastDiagnosticURL,
            showsPanel: showsPanel,
            scrollMinHeight: scrollMinHeight,
            onExport: {
                viewModel.exportLogs()
                taskCenterStore.enqueueLocal(
                    kind: "log-export",
                    name: localizedString(theme.language, english: "Log Export", chinese: "日志导出", italian: "Esportazione log", french: "Export des journaux", spanish: "Exportación de registros"),
                    message: localizedString(theme.language, english: "Launcher log export requested.", chinese: "已请求导出启动器日志。", italian: "Export log launcher richiesto.", french: "Export des journaux du lanceur demandé.", spanish: "Se solicitó exportar registros del launcher.")
                )
            },
            onClear: viewModel.clearLogs,
            onExportDiagnostics: exportDiagnostics
        )
    }
}
