import SwiftUI

struct InstanceArchiveMetricItem: Identifiable, Equatable {
    let title: String
    let value: String

    var id: String {
        title
    }
}

struct InstanceArchiveMetricsGrid: View {
    let items: [InstanceArchiveMetricItem]
    let minimumColumnWidth: CGFloat

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumColumnWidth), spacing: 10)], spacing: 10) {
            ForEach(items) { item in
                InstanceArchiveMetricCard(title: item.title, value: item.value)
            }
        }
    }
}

struct InstanceArchiveMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct InstanceArchiveStatusText: View {
    let status: String

    var body: some View {
        if !status.isEmpty {
            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}

struct InstanceSavesActionBar: View {
    @EnvironmentObject private var theme: ThemeSettings

    let isCheckingPreflight: Bool
    let isMutatingSaves: Bool
    let runPreflight: () -> Void
    let openSavesFolder: () -> Void
    let backupSaves: () -> Void
    let importSaves: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            GlassButton(systemImage: "checklist", title: localizedString(theme.language, english: "Run Preflight", chinese: "运行预检", italian: "Preflight", french: "Précontrôle", spanish: "Preflight"), action: runPreflight)
                .disabled(isCheckingPreflight)
            GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Saves Folder", chinese: "打开存档文件夹", italian: "Apri salvataggi", french: "Ouvrir sauvegardes", spanish: "Abrir partidas"), action: openSavesFolder)
            GlassButton(systemImage: "archivebox", title: localizedString(theme.language, english: "Backup Saves", chinese: "备份存档", italian: "Backup salvataggi", french: "Sauvegarder", spanish: "Respaldar partidas"), action: backupSaves)
                .disabled(isMutatingSaves)
            GlassButton(systemImage: "square.and.arrow.down", title: localizedString(theme.language, english: "Import Saves", chinese: "导入存档", italian: "Importa salvataggi", french: "Importer", spanish: "Importar partidas"), action: importSaves)
                .disabled(isMutatingSaves)
        }
    }
}

struct InstanceExportActionBar: View {
    @EnvironmentObject private var theme: ThemeSettings

    let isCheckingPreflight: Bool
    let isExporting: Bool
    let runPreflight: () -> Void
    let openFolder: () -> Void
    let exportModpack: () -> Void
    let exportInstanceZip: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            GlassButton(systemImage: "checklist", title: localizedString(theme.language, english: "Run Preflight", chinese: "运行预检", italian: "Preflight", french: "Précontrôle", spanish: "Preflight"), action: runPreflight)
                .disabled(isCheckingPreflight)
            GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language), action: openFolder)
            GlassButton(systemImage: "shippingbox.and.arrow.up", title: localizedString(theme.language, english: "Export Modpack", chinese: "导出整合包", italian: "Esporta modpack", french: "Exporter modpack", spanish: "Exportar modpack"), action: exportModpack)
                .disabled(isExporting)
            GlassButton(systemImage: "doc.zipper", title: localizedString(theme.language, english: "Export Zip", chinese: "导出压缩包", italian: "Esporta zip", french: "Exporter zip", spanish: "Exportar zip"), action: exportInstanceZip)
                .disabled(isExporting)
        }
    }
}
