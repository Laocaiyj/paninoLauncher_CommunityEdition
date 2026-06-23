import SwiftUI

private struct LaunchQuickActions: View {
    let resourceSummary: String
    let updateCandidates: Int
    let conflicts: Int
    let missingDependencies: Int
    let onOpenInstance: () -> Void
    let onOpenMods: () -> Void
    let onOpenResourcePacks: () -> Void
    let onOpenLogs: () -> Void
    let onEditInstance: () -> Void
    let onOpenResources: () -> Void
    let onOpenDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(
                    title: localizedString(theme.language, english: "Quick Actions", chinese: "快捷操作", italian: "Azioni rapide", french: "Actions rapides", spanish: "Acciones rápidas"),
                    systemImage: "bolt"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], spacing: 8) {
                    LaunchShortcutButton(title: localizedString(theme.language, english: "Folder", chinese: "配置目录", italian: "Cartella", french: "Dossier", spanish: "Carpeta"), systemImage: "folder", action: onOpenInstance)
                    LaunchShortcutButton(title: "Mods", systemImage: "puzzlepiece.extension", action: onOpenMods)
                    LaunchShortcutButton(title: localizedString(theme.language, english: "Resource Packs", chinese: "资源包", italian: "Pacchetti", french: "Packs", spanish: "Paquetes"), systemImage: "photo.stack", action: onOpenResourcePacks)
                    LaunchShortcutButton(title: AppText.logs.localized(theme.language), systemImage: "terminal", action: onOpenLogs)
                    LaunchShortcutButton(title: localizedString(theme.language, english: "Edit", chinese: "编辑配置", italian: "Modifica", french: "Modifier", spanish: "Editar"), systemImage: "square.and.pencil", action: onEditInstance)
                }

                HStack(spacing: 8) {
                    LaunchResourceChip(
                        title: localizedString(theme.language, english: "Updates", chinese: "可更新", italian: "Aggiornamenti", french: "Mises à jour", spanish: "Actualizaciones"),
                        value: "\(updateCandidates)",
                        style: .download,
                        action: onOpenDiscover
                    )
                    LaunchResourceChip(
                        title: localizedString(theme.language, english: "Conflicts", chinese: "冲突", italian: "Conflitti", french: "Conflits", spanish: "Conflictos"),
                        value: "\(conflicts)",
                        style: conflicts > 0 ? .warning : .success,
                        action: onOpenResources
                    )
                    LaunchResourceChip(
                        title: localizedString(theme.language, english: "Deps", chinese: "依赖", italian: "Dip.", french: "Dép.", spanish: "Deps"),
                        value: "\(missingDependencies)",
                        style: missingDependencies > 0 ? .warning : .success,
                        action: onOpenResources
                    )
                }

                Text(resourceSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct LaunchShortcutButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.34), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct LaunchResourceChip: View {
    let title: String
    let value: String
    let style: StatusBadge.Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(style.color)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(value)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 9)
            .frame(height: 32)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .background(style.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(style.color)
    }
}
