import SwiftUI

struct LaunchShelfTile: View {
    let instance: GameInstance
    let summary: CoreLaunchInstanceSummary?
    let selected: Bool
    let select: () -> Void
    let openDetails: () -> Void
    let toggleFavorite: () -> Void
    let hideRecent: (() -> Void)?

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button {
            select()
            openDetails()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: instance.resolvedIconName)
                        .foregroundStyle(instance.coverTintColor)
                        .frame(width: 28, height: 28)
                        .background(instance.coverTintColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(instance.name)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        Text("Minecraft \(instance.minecraftVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    MetadataLine(items: [instance.loaderTitle(language: theme.language)])
                    Spacer(minLength: 0)
                    if showsStatus {
                        PlainStatusText(title: statusTitle, style: summaryStyle)
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .paninoGlassCard(isSelected: selected, level: selected ? .elevatedPanel : .panel, cornerRadius: 9, tint: instance.coverTintColor, showsShadow: selected)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(instance.isFavorite ? localizedString(theme.language, english: "Unpin Favorite", chinese: "取消收藏", italian: "Rimuovi preferito", french: "Retirer favori", spanish: "Quitar favorito") : localizedString(theme.language, english: "Pin Favorite", chinese: "加入收藏", italian: "Aggiungi preferito", french: "Ajouter favori", spanish: "Añadir favorito"), action: toggleFavorite)
            if let hideRecent {
                Button(localizedString(theme.language, english: "Hide from Recent", chinese: "从最近启动隐藏", italian: "Nascondi dai recenti", french: "Masquer des récents", spanish: "Ocultar de recientes"), action: hideRecent)
            }
            Button(localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta")) {
                FinderIntegration.openInstanceDirectory(instance)
            }
            Button(localizedString(theme.language, english: "Details", chinese: "详情", italian: "Dettagli", french: "Détails", spanish: "Detalles"), action: openDetails)
        }
    }

    private var statusTitle: String {
        switch summary?.status ?? instance.status.rawValue {
        case "ready":
            return AppText.ready.localized(theme.language)
        case "needsInstall":
            return localizedString(theme.language, english: "Needs Install", chinese: "需要安装", italian: "Da installare", french: "À installer", spanish: "Falta instalar")
        case "failed":
            return AppText.failed.localized(theme.language)
        case "running":
            return AppText.running.localized(theme.language)
        default:
            return instance.status.title(language: theme.language)
        }
    }

    private var showsStatus: Bool {
        summaryStyle != .success || (summary?.status ?? instance.status.rawValue) != "ready"
    }

    private var summaryStyle: StatusBadge.Style {
        if summary?.canLaunch == true { return .success }
        switch summary?.status ?? instance.status.rawValue {
        case "failed":
            return .error
        case "needsInstall", "missing":
            return .warning
        case "running":
            return .running
        default:
            return instance.status.badgeStyle
        }
    }
}
