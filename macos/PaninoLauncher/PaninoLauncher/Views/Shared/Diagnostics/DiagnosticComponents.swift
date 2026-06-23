import SwiftUI

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
