import SwiftUI

struct InstanceImmersivePrimary: View {
    let instance: GameInstance?
    let totalCount: Int
    let filteredCount: Int
    let statusText: String
    let openDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let instance {
                MetadataLine(items: [
                    "Minecraft \(instance.minecraftVersion)",
                    instance.loaderTitle(language: theme.language),
                    instance.group
                ])
                .foregroundStyle(.white.opacity(0.82))

                Text(instance.name)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.42), radius: 10, x: 0, y: 4)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { facts(instance) }
                    VStack(alignment: .leading, spacing: 8) { facts(instance) }
                }

                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.control + 4, tint: instance.coverTintColor)
                }
            } else {
                Text(localizedString(theme.language, english: "No local instances", chinese: "还没有本地实例", italian: "Nessuna istanza locale", french: "Aucune instance locale", spanish: "Sin instancias locales"))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                    .shadow(color: .black.opacity(0.34), radius: 10, x: 0, y: 4)

                Text(localizedString(theme.language, english: "Install Minecraft from Get. Verified instances will appear here as playable scenes.", chinese: "从“获取”安装 Minecraft。校验完成的实例会作为可游玩的场景显示在这里。", italian: "Installa Minecraft da Ottieni.", french: "Installez Minecraft depuis Obtenir.", spanish: "Instala Minecraft desde Obtener."))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(3)
                    .frame(maxWidth: 560, alignment: .leading)

                GlassButton(
                    systemImage: "arrow.down.circle",
                    title: localizedString(theme.language, english: "Get Minecraft", chinese: "获取 Minecraft", italian: "Ottieni Minecraft", french: "Obtenir Minecraft", spanish: "Obtener"),
                    prominent: true,
                    action: openDiscover
                )
            }
        }
        .frame(maxWidth: 820, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func facts(_ instance: GameInstance) -> some View {
        ImmersiveTextPill(title: localizedString(theme.language, english: "Status", chinese: "状态", italian: "Stato", french: "État", spanish: "Estado"), value: instance.status.title(language: theme.language)) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(instance.status.badgeStyle.color)
                .frame(width: 3, height: 18)
        }
        ImmersiveTextPill(title: localizedString(theme.language, english: "Memory", chinese: "内存", italian: "Memoria", french: "Mémoire", spanish: "Memoria"), value: "\(instance.memoryMb) MB")
        ImmersiveTextPill(title: localizedString(theme.language, english: "Library", chinese: "库", italian: "Libreria", french: "Bibliothèque", spanish: "Biblioteca"), value: "\(filteredCount) / \(totalCount)")
    }
}
