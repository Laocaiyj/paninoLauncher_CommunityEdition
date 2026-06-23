import SwiftUI

struct MinecraftInstallFailureBanner: View {
    let failure: TaskSnapshot
    let retryInstall: () -> Void
    let openTasks: () -> Void
    let exportDiagnostics: () -> Void
    let openInstanceDirectory: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                localizedString(theme.language, english: "Install failed", chinese: "安装失败", italian: "Installazione fallita", french: "Installation échouée", spanish: "Instalación fallida"),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.callout.weight(.semibold))
            Text(failure.diagnostic?.userSummary ?? failure.message ?? failure.errorCode ?? failure.version)
                .font(.caption)
                .lineLimit(2)
            if let diagnostic = failure.diagnostic {
                Text(diagnostic.actionLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let errorCode = failure.errorCode {
                Text(errorCode)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let detail = failure.errorDetail {
                DisclosureGroup(localizedString(theme.language, english: "Details", chinese: "详情", italian: "Dettagli", french: "Détails", spanish: "Detalles")) {
                    Text(detail)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
            }
            HStack(spacing: 8) {
                GlassButton(systemImage: "arrow.clockwise", title: localizedString(theme.language, english: "Retry", chinese: "重试", italian: "Riprova", french: "Réessayer", spanish: "Reintentar"), action: retryInstall)
                GlassButton(systemImage: "list.bullet.rectangle", title: localizedString(theme.language, english: "Tasks", chinese: "任务", italian: "Attività", french: "Tâches", spanish: "Tareas"), action: openTasks)
                GlassButton(systemImage: "square.and.arrow.up", title: localizedString(theme.language, english: "Export Diagnostics", chinese: "导出诊断", italian: "Esporta diagnostica", french: "Exporter diagnostics", spanish: "Exportar diagnóstico"), action: exportDiagnostics)
                GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开目录", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta"), action: openInstanceDirectory)
            }
            .font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paninoGlassCard(isSelected: true, level: .popover, cornerRadius: 8, tint: .orange, showsShadow: true)
    }
}
