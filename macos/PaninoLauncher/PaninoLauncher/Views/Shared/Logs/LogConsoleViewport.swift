import SwiftUI

struct LogConsoleViewport: View {
    let logs: [LogLine]
    let gameLogs: [LogLine]
    let visibleLogs: [LogLine]
    @Binding var selectedLogID: UUID?
    let scrollMinHeight: CGFloat
    let onExportDiagnostics: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var diagnosticsStore: DiagnosticsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if visibleLogs.isEmpty {
                        LogConsoleEmptyState(
                            onExportDiagnostics: onExportDiagnostics,
                            onOpenLogsFolder: FinderIntegration.openLogsDirectory,
                            onCopySummary: copyEmptySummary
                        )
                        .padding(.vertical, 28)
                    } else {
                        ForEach(visibleLogs) { line in
                            LogConsoleLineRow(
                                line: line,
                                isSelected: selectedLogID == line.id
                            ) {
                                selectedLogID = line.id
                            }
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("log-bottom")
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: scrollMinHeight)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor))
            }
            .onChange(of: visibleLogs.count) {
                guard diagnosticsStore.autoScroll, !diagnosticsStore.pauseScroll else { return }
                DispatchQueue.main.async {
                    withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                        proxy.scrollTo("log-bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    private func copyEmptySummary() {
        let summary = localizedString(
            theme.language,
            english: "No logs are currently captured. Core tab: \(logs.count) lines. Game tab: \(gameLogs.count) lines.",
            chinese: "当前没有捕获到日志。Core：\(logs.count) 行，游戏：\(gameLogs.count) 行。",
            italian: "Nessun log acquisito. Core: \(logs.count) righe. Gioco: \(gameLogs.count) righe.",
            french: "Aucun journal capturé. Core : \(logs.count) lignes. Jeu : \(gameLogs.count) lignes.",
            spanish: "No hay registros capturados. Core: \(logs.count) líneas. Juego: \(gameLogs.count) líneas."
        )
        diagnosticsStore.copyText(
            summary,
            status: localizedString(
                theme.language,
                english: "Copied redacted environment summary.",
                chinese: "已复制脱敏环境摘要。",
                italian: "Riepilogo ambiente redatto copiato.",
                french: "Résumé expurgé copié.",
                spanish: "Resumen redactado copiado."
            )
        )
    }
}
