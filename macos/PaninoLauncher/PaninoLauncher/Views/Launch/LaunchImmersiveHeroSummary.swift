import SwiftUI

struct LaunchImmersiveHeroSummary: View {
    let hasInstalledInstances: Bool
    let instance: GameInstance
    let summary: CoreLaunchInstanceSummary?
    let statusTitle: String
    let statusStyle: StatusBadge.Style
    let openDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if hasInstalledInstances {
                MetadataLine(items: [
                    "Minecraft \(instance.minecraftVersion)",
                    instance.loaderTitle(language: theme.language)
                ])
                .foregroundStyle(.white.opacity(0.82))

                Text(instance.name)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.42), radius: 10, x: 0, y: 4)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { immersiveFacts }
                    VStack(alignment: .leading, spacing: 8) { immersiveFacts }
                }
            } else {
                Text(localizedString(theme.language, english: "Build your library", chinese: "开始建立游戏库", italian: "Crea la tua libreria", french: "Créez votre bibliothèque", spanish: "Crea tu biblioteca"))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                    .shadow(color: .black.opacity(0.34), radius: 10, x: 0, y: 4)

                Text(localizedString(theme.language, english: "Install Minecraft from Get. Panino will turn it into a launchable scene here.", chinese: "从“获取”安装 Minecraft 后，Panino 会把它作为可启动场景显示在这里。", italian: "Installa Minecraft da Ottieni.", french: "Installez Minecraft depuis Obtenir.", spanish: "Instala Minecraft desde Obtener."))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(3)
                    .frame(maxWidth: 560, alignment: .leading)

                LaunchHeroTextButton(
                    title: localizedString(theme.language, english: "Get Minecraft", chinese: "获取 Minecraft", italian: "Ottieni Minecraft", french: "Obtenir Minecraft", spanish: "Obtener Minecraft"),
                    prominent: true,
                    action: openDiscover
                )
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var immersiveFacts: some View {
        ImmersiveTextPill(title: localizedString(theme.language, english: "Status", chinese: "状态", italian: "Stato", french: "État", spanish: "Estado"), value: statusTitle) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(statusStyle.color)
                .frame(width: 3, height: 18)
        }
        ImmersiveTextPill(title: localizedString(theme.language, english: "Last Launch", chinese: "最近启动", italian: "Ultimo avvio", french: "Dernier lancement", spanish: "Último inicio"), value: lastLaunchText)
        ImmersiveTextPill(title: localizedString(theme.language, english: "Play Time", chinese: "游戏时长", italian: "Tempo gioco", french: "Temps de jeu", spanish: "Tiempo jugado"), value: formattedPlayDuration(instance.totalPlaySeconds ?? 0, language: theme.language))
        ImmersiveTextPill(title: localizedString(theme.language, english: "Content", chinese: "内容", italian: "Contenuto", french: "Contenu", spanish: "Contenido"), value: contentText)
    }

    private var lastLaunchText: String {
        instance.lastLaunchedAt?.formatted(date: .abbreviated, time: .shortened)
            ?? localizedString(theme.language, english: "Never", chinese: "从未", italian: "Mai", french: "Jamais", spanish: "Nunca")
    }

    private var contentText: String {
        guard let content = summary?.content else {
            return localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando")
        }
        return localizedString(
            theme.language,
            english: "\(content.modCount) mods, \(content.saveCount) saves",
            chinese: "\(content.modCount) 个 Mod，\(content.saveCount) 个存档",
            italian: "\(content.modCount) mod, \(content.saveCount) salvataggi",
            french: "\(content.modCount) mods, \(content.saveCount) sauvegardes",
            spanish: "\(content.modCount) mods, \(content.saveCount) partidas"
        )
    }
}
