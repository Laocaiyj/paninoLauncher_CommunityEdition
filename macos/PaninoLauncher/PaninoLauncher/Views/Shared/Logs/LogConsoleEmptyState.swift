import SwiftUI

struct LogConsoleEmptyState: View {
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
