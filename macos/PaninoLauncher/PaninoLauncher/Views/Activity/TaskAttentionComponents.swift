import SwiftUI

struct TaskAttentionSection: View {
    let records: [TaskRecord]
    let retryTarget: (TaskRecord) -> String
    let canRetry: (TaskRecord) -> Bool
    let onRetry: (TaskRecord) -> Void
    let onDismiss: (TaskRecord) -> Void
    let onOpenLogs: () -> Void
    let onExportDiagnostics: (TaskRecord) -> Void
    let onOpenFolder: (TaskRecord) -> Void
    let diagnosticActionTitle: (TaskRecord) -> String?
    let diagnosticActionSystemImage: (TaskRecord) -> String
    let onDiagnosticAction: (TaskRecord) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(localizedString(theme.language, english: "Needs Attention", chinese: "需要处理", italian: "Richiede attenzione", french: "Action requise", spanish: "Requiere atención"))
                        .font(.headline)
                    Spacer()
                    CountText(value: records.count, style: .warning)
                }

                if records.isEmpty {
                    EmptyStateInline(
                        title: localizedString(theme.language, english: "No action needed", chinese: "暂无需要处理", italian: "Nessuna azione richiesta", french: "Aucune action requise", spanish: "No requiere acción"),
                        message: localizedString(theme.language, english: "Failures and interrupted tasks will appear here with recovery actions.", chinese: "失败或中断任务会在这里显示，并提供恢复动作。", italian: "Errori e interruzioni appariranno qui.", french: "Les échecs et interruptions apparaîtront ici.", spanish: "Fallos e interrupciones aparecerán aquí."),
                        systemImage: "checkmark.circle"
                    )
                } else {
                    ForEach(records) { record in
                        TaskAttentionCard(
                            record: record,
                            retryTitle: retryTarget(record),
                            canRetry: canRetry(record),
                            onRetry: { onRetry(record) },
                            onDismiss: { onDismiss(record) },
                            onOpenLogs: onOpenLogs,
                            onExportDiagnostics: { onExportDiagnostics(record) },
                            onOpenFolder: { onOpenFolder(record) },
                            diagnosticActionTitle: diagnosticActionTitle(record),
                            diagnosticActionSystemImage: diagnosticActionSystemImage(record),
                            onDiagnosticAction: { onDiagnosticAction(record) }
                        )
                    }
                }
            }
        }
    }
}

private struct TaskAttentionCard: View {
    let record: TaskRecord
    let retryTitle: String
    let canRetry: Bool
    let onRetry: () -> Void
    let onDismiss: () -> Void
    let onOpenLogs: () -> Void
    let onExportDiagnostics: () -> Void
    let onOpenFolder: () -> Void
    let diagnosticActionTitle: String?
    let diagnosticActionSystemImage: String
    let onDiagnosticAction: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TaskStateLine(title: record.state.title(language: theme.language), style: record.state.badgeStyle)
                Text(record.name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(record.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(record.message)
                .font(.callout)
                .lineLimit(2)
                .textSelection(.enabled)

            Text(record.advice.localizedRecoveryAdvice(theme.language))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { actionButtons }
                VStack(alignment: .leading, spacing: 8) { actionButtons }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .paninoGlassCard(isSelected: true, level: .popover, cornerRadius: 8, tint: .orange, showsShadow: true)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if canRetry {
            GlassButton(systemImage: "arrow.clockwise", title: retryTitle, prominent: true, action: onRetry)
        }
        if let diagnosticActionTitle {
            GlassButton(systemImage: diagnosticActionSystemImage, title: diagnosticActionTitle, prominent: !canRetry, action: onDiagnosticAction)
        }
        GlassButton(systemImage: "terminal", title: AppText.logs.localized(theme.language), action: onOpenLogs)
        GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Export Diagnostics", chinese: "导出诊断", italian: "Esporta diagnostica", french: "Exporter diagnostic", spanish: "Exportar diagnóstico"), action: onExportDiagnostics)
        GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta"), action: onOpenFolder)
        if record.state == .interrupted {
            GlassButton(systemImage: "checkmark", title: localizedString(theme.language, english: "Ignore", chinese: "忽略", italian: "Ignora", french: "Ignorer", spanish: "Ignorar"), action: onDismiss)
        }
    }
}
