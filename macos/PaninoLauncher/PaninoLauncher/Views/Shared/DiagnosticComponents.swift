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

struct ErrorDetailContext: Equatable {
    let title: String
    let userSummary: String
    let technicalDetail: String
    let causes: [String]
    let actions: [String]

    var copyText: String {
        """
        \(title)

        User summary:
        \(userSummary)

        Technical details:
        \(technicalDetail)

        Possible causes:
        \(causes.joined(separator: "\n"))

        Recommended actions:
        \(actions.joined(separator: "\n"))
        """
    }

    var minimumReproText: String {
        """
        Panino minimal repro
        title=\(title)
        summary=\(userSummary)

        technical:
        \(technicalDetail)

        actions_tried:
        \(actions.joined(separator: "\n"))
        """
    }
}

struct ErrorDetailPanel: View {
    let context: ErrorDetailContext
    let onCopy: (ErrorDetailContext) -> Void
    let onCopyRepro: (ErrorDetailContext) -> Void
    let onExportDiagnostics: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                HStack {
                    PanelHeader(title: context.title, systemImage: "exclamationmark.triangle")
                    Spacer()
                    GlassButton(systemImage: "doc.on.doc", title: localizedString(theme.language, english: "Copy Details", chinese: "复制详情", italian: "Copia dettagli", french: "Copier détails", spanish: "Copiar detalles")) {
                        onCopy(context)
                    }
                    GlassButton(systemImage: "doc.badge.gearshape", title: localizedString(theme.language, english: "Copy Repro", chinese: "复制复现", italian: "Copia repro", french: "Copier repro", spanish: "Copiar repro")) {
                        onCopyRepro(context)
                    }
                    GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Export Diagnostics", chinese: "导出诊断", italian: "Esporta diagnostica", french: "Exporter diagnostic", spanish: "Exportar diagnóstico"), action: onExportDiagnostics)
                }

                SettingsRow(title: localizedString(theme.language, english: "For You", chinese: "用户说明", italian: "Per te", french: "Pour vous", spanish: "Para ti"), systemImage: "person") {
                    Text(context.userSummary)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }

                DiagnosticList(
                    title: localizedString(theme.language, english: "Recommended Actions", chinese: "建议操作", italian: "Azioni consigliate", french: "Actions recommandées", spanish: "Acciones recomendadas"),
                    systemImage: "checklist",
                    items: context.actions
                )
                DiagnosticList(
                    title: localizedString(theme.language, english: "Possible Causes", chinese: "可能原因", italian: "Cause possibili", french: "Causes possibles", spanish: "Causas posibles"),
                    systemImage: "questionmark.circle",
                    items: context.causes
                )

                SettingsRow(title: localizedString(theme.language, english: "Technical", chinese: "技术详情", italian: "Tecnico", french: "Technique", spanish: "Técnico"), systemImage: "curlybraces") {
                    Text(context.technicalDetail)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(5)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

struct DiagnosticList: View {
    let title: String
    let systemImage: String
    let items: [String]

    var body: some View {
        SettingsRow(title: title, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Label(item, systemImage: "smallcircle.filled.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
    }
}

struct AccountCard: View {
    let accountState: AccountConnectionState
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusStyle.color.opacity(0.18))
                    Image(systemName: statusIcon)
                        .font(.title2)
                        .foregroundStyle(statusStyle.color)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppText.microsoftAccount.localized(theme.language))
                        .font(.headline)
                    Text(accountState.localizedTitle(theme.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                Spacer()

                StatusBadge(title: statusTitle, style: statusStyle)
            }
        }
    }

    private var statusTitle: String {
        switch accountState {
        case .signedIn:
            return AppText.signedIn.localized(theme.language)
        case .restoring:
            return AppText.restoring.localized(theme.language)
        case .waitingForDeviceCode:
            return AppText.waiting.localized(theme.language)
        case .failed:
            return AppText.error.localized(theme.language)
        case .signedOut:
            return AppText.signedOut.localized(theme.language)
        }
    }

    private var statusStyle: StatusBadge.Style {
        switch accountState {
        case .signedIn:
            return .success
        case .restoring, .waitingForDeviceCode:
            return .running
        case .failed:
            return .error
        case .signedOut:
            return .neutral
        }
    }

    private var statusIcon: String {
        switch accountState {
        case .signedIn:
            return "person.crop.circle.fill.badge.checkmark"
        case .restoring, .waitingForDeviceCode:
            return "person.crop.circle.badge.clock"
        case .failed:
            return "person.crop.circle.badge.exclamationmark"
        case .signedOut:
            return "person.crop.circle"
        }
    }
}

struct InstanceCard: View {
    let title: String
    let subtitle: String
    let status: StatusBadge.Style
    let icon: String
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                        .fill(status.color.opacity(0.16))
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(status.color)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Spacer()

                StatusBadge(title: statusTitle, style: status)
            }
        }
    }

    private var statusTitle: String {
        switch status {
        case .success:
            return AppText.ready.localized(theme.language)
        case .warning:
            return AppText.attention.localized(theme.language)
        case .error:
            return AppText.failed.localized(theme.language)
        case .download:
            return AppText.downloading.localized(theme.language)
        case .running:
            return AppText.running.localized(theme.language)
        case .neutral:
            return AppText.idle.localized(theme.language)
        }
    }
}

struct DeviceCodePanel: View {
    let session: DeviceCodeSession
    let onCancel: () -> Void
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(session.userCode)
                    .font(.system(.title3, design: .monospaced).bold())
                    .textSelection(.enabled)

                Link(AppText.openMicrosoft.localized(theme.language), destination: session.verificationURI)

                GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: onCancel)
            }

            Text(session.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: PaninoTokens.Radius.card))
    }
}
