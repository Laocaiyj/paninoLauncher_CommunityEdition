import SwiftUI

struct LaunchInstanceSummaryPanel: View {
    let instance: GameInstance
    let statusTitle: String

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Summary", chinese: "摘要", italian: "Riepilogo", french: "Résumé", spanish: "Resumen"))
                    .font(.headline)
                LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                    LaunchMetric(title: localizedString(theme.language, english: "Status", chinese: "状态", italian: "Stato", french: "État", spanish: "Estado"), value: statusTitle)
                    LaunchMetric(title: localizedString(theme.language, english: "Last Launch", chinese: "最近启动", italian: "Ultimo avvio", french: "Dernier lancement", spanish: "Último inicio"), value: instance.lastLaunchedAt?.formatted(date: .abbreviated, time: .shortened) ?? localizedString(theme.language, english: "Never", chinese: "从未", italian: "Mai", french: "Jamais", spanish: "Nunca"))
                    LaunchMetric(title: localizedString(theme.language, english: "Play Time", chinese: "游戏时长", italian: "Tempo gioco", french: "Temps de jeu", spanish: "Tiempo jugado"), value: formattedPlayDuration(instance.totalPlaySeconds ?? 0, language: theme.language))
                    LaunchMetric(title: localizedString(theme.language, english: "Launches", chinese: "启动次数", italian: "Avvii", french: "Lancements", spanish: "Inicios"), value: "\(instance.launchCount)")
                }
            }
        }
    }
}

struct LaunchInstanceManagementPanel: View {
    let instance: GameInstance
    let summary: CoreLaunchInstanceSummary?
    let showContent: () -> Void
    let showVersion: () -> Void
    let showSaves: () -> Void
    let showSettings: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Manage", chinese: "管理", italian: "Gestisci", french: "Gérer", spanish: "Gestionar"))
                    .font(.headline)
                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
                    LaunchDetailActionTile(title: localizedString(theme.language, english: "Content", chinese: "内容", italian: "Contenuto", french: "Contenu", spanish: "Contenido"), subtitle: contentOverview, action: showContent)
                    LaunchDetailActionTile(title: localizedString(theme.language, english: "Version", chinese: "版本", italian: "Versione", french: "Version", spanish: "Versión"), subtitle: "Minecraft \(instance.minecraftVersion)", action: showVersion)
                    LaunchDetailActionTile(title: localizedString(theme.language, english: "Saves", chinese: "存档", italian: "Salvataggi", french: "Sauvegardes", spanish: "Partidas"), subtitle: "\(summary?.content.saveCount ?? 0)", action: showSaves)
                    LaunchDetailActionTile(title: localizedString(theme.language, english: "Settings", chinese: "设置", italian: "Impostazioni", french: "Réglages", spanish: "Ajustes"), subtitle: "\(instance.memoryMb) MB", action: showSettings)
                }
            }
        }
    }

    private var contentOverview: String {
        guard let content = summary?.content else {
            return localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando")
        }
        return "\(content.modCount) Mods · \(content.resourcePackCount) RP · \(content.shaderPackCount) Shaders"
    }

    private var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 190), spacing: 10, alignment: .top)]
    }
}

private struct LaunchDetailActionTile: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.26), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
