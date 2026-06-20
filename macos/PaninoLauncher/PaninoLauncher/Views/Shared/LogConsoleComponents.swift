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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            toolbar
            filterBar
            exportedPathRows
            logViewport
        }
    }

    private var toolbar: some View {
        HStack(alignment: .center, spacing: 10) {
            PanelHeader(title: title, systemImage: "terminal")

            Spacer()

            Picker("", selection: $diagnosticsStore.selectedTab) {
                ForEach(LogPanelTab.allCases) { tab in
                    Text(tab.title(language: theme.language)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            Picker("", selection: $diagnosticsStore.filterLevel) {
                ForEach(LogFilterLevel.allCases) { level in
                    Text(level.title(language: theme.language)).tag(level)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 110)

            GlassButton(systemImage: "square.and.arrow.down", title: AppText.export.localized(theme.language), action: onExport)
            GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Diagnostics", chinese: "诊断", italian: "Diagnostica", french: "Diagnostic", spanish: "Diagnóstico"), action: onExportDiagnostics)
            GlassButton(systemImage: "trash", title: AppText.clear.localized(theme.language), action: onClear)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            PaninoTextInput(
                localizedString(theme.language, english: "Search logs", chinese: "搜索日志", italian: "Cerca log", french: "Rechercher dans les journaux", spanish: "Buscar registros"),
                text: $diagnosticsStore.searchText
            )
            .frame(maxWidth: 260)

            Toggle(isOn: $diagnosticsStore.autoScroll) {
                Label(localizedString(theme.language, english: "Auto Scroll", chinese: "自动滚动", italian: "Scorrimento automatico", french: "Défilement auto", spanish: "Desplazamiento automático"), systemImage: "arrow.down.to.line")
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: $diagnosticsStore.pauseScroll) {
                Label(localizedString(theme.language, english: "Pause", chinese: "暂停", italian: "Pausa", french: "Pause", spanish: "Pausa"), systemImage: "pause.circle")
            }
            .toggleStyle(.checkbox)

            Spacer()

            GlassButton(systemImage: "doc.on.doc", title: localizedString(theme.language, english: "Copy Selected", chinese: "复制选中", italian: "Copia selezione", french: "Copier sélection", spanish: "Copiar selección")) {
                diagnosticsStore.copy(logs: selectedLogs)
            }
            .disabled(selectedLogs.isEmpty)
        }
    }

    private var exportedPathRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let exportedURL {
                diagnosticPathRow(
                    title: localizedString(theme.language, english: "Log", chinese: "日志", italian: "Log", french: "Journal", spanish: "Registro"),
                    url: exportedURL
                )
            }
            if let diagnosticURL {
                diagnosticPathRow(
                    title: localizedString(theme.language, english: "Diagnostics", chinese: "诊断", italian: "Diagnostica", french: "Diagnostic", spanish: "Diagnóstico"),
                    url: diagnosticURL
                )
            }
            if !diagnosticsStore.copyStatus.isEmpty {
                Text(diagnosticsStore.copyStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var logViewport: some View {
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

    private func diagnosticPathRow(title: String, url: URL) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text(url.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
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

private struct LogConsoleEmptyState: View {
    let onExportDiagnostics: () -> Void
    let onOpenLogsFolder: () -> Void
    let onCopySummary: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString(theme.language, english: "No logs yet", chinese: "还没有日志", italian: "Ancora nessun log", french: "Aucun journal", spanish: "Aún no hay registros"))
                .font(.headline)
            Text(localizedString(theme.language, english: "Export a diagnostic package, open the log folder, or copy the current environment summary.", chinese: "可以导出诊断包、打开日志文件夹，或复制当前环境摘要。", italian: "Esporta diagnostica, apri la cartella log o copia il riepilogo ambiente.", french: "Exportez un diagnostic, ouvrez le dossier des journaux ou copiez le résumé.", spanish: "Exporta diagnóstico, abre la carpeta de registros o copia el resumen."))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Export Diagnostics", chinese: "导出诊断包", italian: "Esporta diagnostica", french: "Exporter diagnostic", spanish: "Exportar diagnóstico"), action: onExportDiagnostics)
                GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Log Folder", chinese: "打开日志文件夹", italian: "Apri cartella log", french: "Ouvrir dossier", spanish: "Abrir carpeta"), action: onOpenLogsFolder)
                GlassButton(systemImage: "doc.on.doc", title: localizedString(theme.language, english: "Copy Summary", chinese: "复制摘要", italian: "Copia riepilogo", french: "Copier résumé", spanish: "Copiar resumen"), action: onCopySummary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LogConsoleLineRow: View {
    let line: LogLine
    let isSelected: Bool
    let select: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Text(line.text)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(
                isSelected ? theme.semanticSelectionColor.opacity(0.16) : Color.clear,
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: select)
    }
}
