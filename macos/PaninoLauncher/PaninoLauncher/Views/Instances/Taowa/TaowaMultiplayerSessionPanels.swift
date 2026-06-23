import AppKit
import SwiftUI

struct TaowaSessionPanel: View {
    let session: CoreTaowaSession
    let health: CoreTaowaSessionHealthResponse?
    let logTail: String
    let onCopyAddress: (String, String) -> Void
    let onLoadLog: (CoreTaowaSession) -> Void
    let onReloadSession: (CoreTaowaSession) -> Void
    let onLoadHealth: (CoreTaowaSession) async -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            PanelHeader(
                                title: localizedString(theme.language, english: "Connection Address", chinese: "连接地址", italian: "Indirizzo", french: "Adresse", spanish: "Dirección"),
                                systemImage: "link"
                            )
                            StatusBadge(title: session.status, style: TaowaSessionStatusStyle.badgeStyle(for: session.status))
                        }
                        Text(session.remoteAddress)
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        MetadataLine(items: [
                            "local \(session.localPort)",
                            "remote \(session.remotePort)",
                            "pid \(session.processId.map(String.init) ?? "-")"
                        ])
                        HStack(spacing: 8) {
                            GlassButton(systemImage: "doc.on.doc", title: localizedString(theme.language, english: "Copy Address", chinese: "复制地址", italian: "Copia indirizzo", french: "Copier adresse", spanish: "Copiar dirección")) {
                                onCopyAddress(
                                    session.remoteAddress,
                                    localizedString(theme.language, english: "Connection address copied.", chinese: "连接地址已复制。", italian: "Indirizzo copiato.", french: "Adresse copiée.", spanish: "Dirección copiada.")
                                )
                            }
                            GlassButton(systemImage: "doc.text.magnifyingglass", title: localizedString(theme.language, english: "Load Log", chinese: "读取日志", italian: "Carica log", french: "Charger journal", spanish: "Cargar registro")) {
                                onLoadLog(session)
                            }
                            GlassButton(systemImage: "arrow.triangle.2.circlepath", title: localizedString(theme.language, english: "Refresh Session", chinese: "刷新会话", italian: "Aggiorna sessione", french: "Actualiser session", spanish: "Actualizar sesión")) {
                                onReloadSession(session)
                            }
                            if !session.frpcLogPath.isEmpty {
                                GlassButton(systemImage: "arrow.up.forward.app", title: localizedString(theme.language, english: "Open Log File", chinese: "打开日志文件", italian: "Apri log", french: "Ouvrir journal", spanish: "Abrir registro")) {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: session.frpcLogPath))
                                }
                            }
                        }
                        if let health {
                            MetadataLine(items: [
                                health.localPortReachable ? "local reachable" : "local unreachable",
                                health.processManaged ? "managed" : "not managed",
                                health.stale ? "stale" : "current"
                            ])
                        }
                    }
                    Spacer(minLength: 0)
                    QRCodeImage(value: session.remoteAddress)
                        .frame(width: 150, height: 150)
                        .accessibilityLabel(localizedString(theme.language, english: "QR code for connection address", chinese: "连接地址二维码", italian: "Codice QR indirizzo", french: "QR code adresse", spanish: "Código QR de dirección"))
                }

                if !logTail.isEmpty {
                    ScrollView {
                        Text(logTail)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                    .padding(10)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .task(id: session.sessionId) {
            await onLoadHealth(session)
        }
    }
}

struct TaowaSessionHistoryPanel: View {
    let sessions: [CoreTaowaSession]
    let selectedSessionId: String?
    let onSelect: (CoreTaowaSession) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Session History", chinese: "会话历史", italian: "Cronologia sessioni", french: "Historique sessions", spanish: "Historial de sesiones"),
                        systemImage: "clock.arrow.circlepath"
                    )
                    Spacer()
                    StatusBadge(title: "\(sessions.count)", style: .neutral)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 10)], spacing: 10) {
                    ForEach(sessions.sorted { $0.updatedAt > $1.updatedAt }.prefix(8)) { session in
                        TaowaSessionHistoryRow(
                            session: session,
                            isSelected: session.sessionId == selectedSessionId,
                            onSelect: {
                                onSelect(session)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct TaowaDiagnosticsPanel: View {
    let diagnostics: [CoreDiagnostic]

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Diagnostics", chinese: "诊断", italian: "Diagnostica", french: "Diagnostic", spanish: "Diagnóstico"),
                    systemImage: "stethoscope"
                )
                ForEach(diagnostics, id: \.code) { diagnostic in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(diagnostic.title)
                                .font(.callout.weight(.semibold))
                            StatusBadge(title: diagnostic.severity, style: diagnostic.severity == "warning" ? .warning : .error)
                        }
                        Text(diagnostic.userSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        MetadataLine(items: [
                            diagnostic.code,
                            diagnostic.phase,
                            diagnostic.actionLabel
                        ])
                        if !diagnostic.evidence.isEmpty {
                            DiagnosticList(
                                title: localizedString(theme.language, english: "Evidence", chinese: "证据", italian: "Evidenza", french: "Preuve", spanish: "Evidencia"),
                                systemImage: "list.bullet.clipboard",
                                items: diagnostic.evidence.prefix(4).map { "\($0.key): \($0.value)" }
                            )
                        }
                    }
                }
            }
        }
    }
}
