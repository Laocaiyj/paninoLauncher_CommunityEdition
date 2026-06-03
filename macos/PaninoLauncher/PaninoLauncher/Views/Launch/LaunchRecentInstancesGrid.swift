import SwiftUI

struct LaunchRecentInstancesStrip: View {
    let instances: [GameInstance]
    let selectedID: UUID
    let select: (UUID) -> Void
    let openInstances: () -> Void
    let openResources: () -> Void
    let openDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Recent Configurations", chinese: "最近游戏配置", italian: "Configurazioni recenti", french: "Configurations récentes", spanish: "Configuraciones recientes"),
                        systemImage: "square.stack.3d.up"
                    )
                    Spacer()
                    CountText(value: visibleInstances.count, style: .download)
                    GlassButton(
                        systemImage: "rectangle.stack",
                        title: localizedString(theme.language, english: "Manage", chinese: "管理", italian: "Gestisci", french: "Gérer", spanish: "Gestionar"),
                        action: openInstances
                    )
                }

                if visibleInstances.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(localizedString(theme.language, english: "No recent launches yet", chinese: "还没有最近启动记录", italian: "Nessun avvio recente", french: "Aucun lancement récent", spanish: "Sin inicios recientes"))
                            .font(.headline)
                        Text(localizedString(theme.language, english: "Launch a game configuration once and it will appear here.", chinese: "启动一次游戏配置后，它会显示在这里。", italian: "Avvia una configurazione e comparirà qui.", french: "Lancez une configuration et elle apparaîtra ici.", spanish: "Inicia una configuración y aparecerá aquí."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                } else {
                    LazyVGrid(columns: tileColumns, alignment: .leading, spacing: 8) {
                        ForEach(visibleInstances) { instance in
                            recentTile(instance)
                        }
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        favoritesBadge
                        instanceLibraryHint
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        favoritesBadge
                        instanceLibraryHint
                    }
                }
            }
        }
    }

    private var tileColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 148), spacing: 8, alignment: .top)]
    }

    private var favoritesBadge: some View {
        Label(
            localizedString(theme.language, english: "Favorites first", chinese: "收藏优先", italian: "Preferiti prima", french: "Favoris d'abord", spanish: "Favoritos primero"),
            systemImage: "star.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    private var instanceLibraryHint: some View {
        Text(localizedString(theme.language, english: "Only configurations you have launched appear here.", chinese: "这里只显示实际启动过的游戏配置。", italian: "Qui appaiono solo configurazioni avviate.", french: "Seules les configurations lancées apparaissent ici.", spanish: "Aquí solo aparecen configuraciones iniciadas."))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }

    private var visibleInstances: [GameInstance] {
        return instances
            .filter { $0.lastLaunchedAt != nil }
            .sorted {
                if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
                return ($0.lastLaunchedAt ?? .distantPast) > ($1.lastLaunchedAt ?? .distantPast)
            }
            .prefix(LaunchLibraryLimits.recentLaunchCount)
            .map { $0 }
    }

    private func recentTile(_ instance: GameInstance) -> some View {
        Button {
            select(instance.id)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: instance.iconName.isEmpty ? "cube.fill" : instance.iconName)
                    .foregroundStyle(theme.semanticSelectionColor)
                    .frame(width: 24, height: 24)
                    .background(theme.semanticSelectionColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(instance.name)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        if instance.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                    Text("Minecraft \(instance.minecraftVersion)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(lastLaunchText(instance))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(
                (instance.id == selectedID ? theme.semanticSelectionColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.3)),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(instance.id == selectedID ? theme.semanticSelectionColor.opacity(0.8) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func lastLaunchText(_ instance: GameInstance) -> String {
        guard let date = instance.lastLaunchedAt else {
            return localizedString(theme.language, english: "Never launched", chinese: "尚未启动", italian: "Mai avviata", french: "Jamais lancée", spanish: "Nunca iniciada")
        }
        return date.formatted(date: .numeric, time: .shortened)
    }
}

private struct LaunchShortcutTile: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
