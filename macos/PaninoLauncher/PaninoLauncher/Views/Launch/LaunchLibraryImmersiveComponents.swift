import SwiftUI

struct LaunchImmersiveBackground: View {
    let instance: GameInstance
    let hasInstalledInstances: Bool

    @EnvironmentObject private var theme: ThemeSettings
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if hasInstalledInstances, let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [
                            instance.coverTintColor.opacity(hasInstalledInstances ? 0.70 : 0.38),
                            theme.semanticSelectionColor.opacity(0.34),
                            Color(nsColor: .windowBackgroundColor).opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    if hasInstalledInstances {
                        Image(systemName: instance.resolvedIconName)
                            .font(.system(size: 180, weight: .bold))
                            .foregroundStyle(instance.coverTintColor.opacity(0.24))
                            .offset(x: proxy.size.width * 0.26, y: -proxy.size.height * 0.10)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task(id: instance.coverPath) {
            guard hasInstalledInstances, !instance.coverPath.isEmpty else {
                image = nil
                return
            }
            image = await ThumbnailCache.shared.image(path: instance.coverPath, size: CGSize(width: 1280, height: 720))
        }
    }
}

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

struct LaunchImmersiveControls: View {
    let hasInstalledInstances: Bool
    let primaryTitle: String
    let primaryDisabled: Bool
    let canCancel: Bool
    let onPrimaryAction: () -> Void
    let onCancel: () -> Void
    let openDetails: () -> Void
    let openDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { controls }
            VStack(alignment: .trailing, spacing: 10) { controls }
        }
        .padding(8)
        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.control + 10, tint: theme.semanticSelectionColor, showsShadow: true)
    }

    @ViewBuilder
    private var controls: some View {
        if hasInstalledInstances {
            LaunchHeroTextButton(
                title: primaryTitle,
                prominent: true,
                minWidth: 132,
                minHeight: 48,
                action: onPrimaryAction
            )
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(primaryDisabled)

            LaunchHeroTextButton(
                title: localizedString(theme.language, english: "Details", chinese: "详情", italian: "Dettagli", french: "Détails", spanish: "Detalles"),
                minWidth: 104,
                minHeight: 48,
                action: openDetails
            )

            if canCancel {
                GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: onCancel)
            }
        } else {
            LaunchHeroTextButton(
                title: localizedString(theme.language, english: "Get", chinese: "获取", italian: "Ottieni", french: "Obtenir", spanish: "Obtener"),
                prominent: true,
                minWidth: 104,
                minHeight: 48,
                action: openDiscover
            )
        }
    }
}

struct LaunchImmersiveContextShelf: View {
    let hasInstalledInstances: Bool
    @Binding var mode: LaunchShelfMode
    let performanceSummary: CorePerformanceSummary?
    let packDoctorReport: CoreCompatibilityReport?
    let packDoctorDiagnostics: [CoreDiagnostic]
    let packDoctorStatusText: String
    let packDoctorIsWorking: Bool
    let recentInstances: [GameInstance]
    let recentInstalledInstances: [GameInstance]
    let favoriteInstances: [GameInstance]
    let selectedID: UUID
    let summaryFor: (GameInstance) -> CoreLaunchInstanceSummary?
    let onPackDoctorRefresh: () -> Void
    let onPackDoctorPrimaryAction: () -> Void
    let select: (UUID) -> Void
    let openDetails: (UUID) -> Void
    let toggleFavorite: (UUID, Bool) -> Void
    let hideRecent: (UUID) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        if hasInstalledInstances {
            VStack(alignment: .leading, spacing: 12) {
                PackDoctorPanel(
                    report: packDoctorReport,
                    performanceSummary: performanceSummary,
                    diagnostics: packDoctorDiagnostics,
                    isWorking: packDoctorIsWorking,
                    statusText: packDoctorStatusText,
                    presentation: .compact,
                    onRefresh: onPackDoctorRefresh,
                    onPrimaryAction: onPackDoctorPrimaryAction,
                    onOpenDiagnostics: { openDetails(selectedID) }
                )
                .frame(maxWidth: 760, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            shelfTitle
                            Spacer(minLength: 12)
                            LaunchShelfModeSelector(mode: $mode)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            shelfTitle
                            LaunchShelfModeSelector(mode: $mode)
                        }
                    }

                    if visibleInstances.isEmpty {
                        EmptyStateInline(title: emptyTitle, message: emptyMessage, systemImage: emptySystemImage)
                            .frame(minHeight: 72)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 10) {
                                ForEach(visibleInstances) { instance in
                                    LaunchShelfTile(
                                        instance: instance,
                                        summary: summaryFor(instance),
                                        selected: instance.id == selectedID,
                                        select: { select(instance.id) },
                                        openDetails: { openDetails(instance.id) },
                                        toggleFavorite: { toggleFavorite(instance.id, !instance.isFavorite) },
                                        hideRecent: mode == .recent ? { hideRecent(instance.id) } : nil
                                    )
                                    .frame(width: 236)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(14)
                .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.panel, tint: theme.semanticSelectionColor, showsShadow: true)
            }
        }
    }

    private var shelfTitle: some View {
        Text(mode == .recent
            ? localizedString(theme.language, english: "Recent Launches", chinese: "最近启动", italian: "Avvii recenti", french: "Lancements récents", spanish: "Inicios recientes")
            : mode == .favorites
                ? localizedString(theme.language, english: "Favorites", chinese: "收藏", italian: "Preferiti", french: "Favoris", spanish: "Favoritos")
                : localizedString(theme.language, english: "Recently Installed", chinese: "最近安装", italian: "Installate di recente", french: "Installées récemment", spanish: "Instaladas recientes"))
            .font(.headline)
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private var visibleInstances: [GameInstance] {
        switch mode {
        case .recent:
            return recentInstances
        case .favorites:
            return favoriteInstances
        case .installed:
            return recentInstalledInstances
        }
    }

    private var emptyTitle: String {
        switch mode {
        case .recent:
            return localizedString(theme.language, english: "No recent launches", chinese: "还没有最近启动", italian: "Nessun avvio recente", french: "Aucun lancement récent", spanish: "Sin inicios recientes")
        case .favorites:
            return localizedString(theme.language, english: "No favorites yet", chinese: "还没有收藏", italian: "Nessun preferito", french: "Aucun favori", spanish: "Sin favoritos")
        case .installed:
            return localizedString(theme.language, english: "No installed games yet", chinese: "还没有本地实例", italian: "Nessuna installazione", french: "Aucune installation", spanish: "Sin instalaciones")
        }
    }

    private var emptyMessage: String {
        switch mode {
        case .recent:
            return localizedString(theme.language, english: "Launch an instance once and it will appear here.", chinese: "启动一次实例后会出现在这里。", italian: "Avvia un'istanza e apparirà qui.", french: "Lancez une instance pour la voir ici.", spanish: "Inicia una instancia y aparecerá aquí.")
        case .favorites:
            return localizedString(theme.language, english: "Use details or the context menu to pin instances.", chinese: "可在详情或右键菜单里收藏实例。", italian: "Usa dettagli o menu contestuale.", french: "Utilisez détails ou menu contextuel.", spanish: "Usa detalles o menú contextual.")
        case .installed:
            return localizedString(theme.language, english: "Install Minecraft from Get and Core will add it here.", chinese: "从“获取”安装 Minecraft 后，Core 会自动加入这里。", italian: "Installa Minecraft da Ottieni.", french: "Installez Minecraft depuis Obtenir.", spanish: "Instala Minecraft desde Obtener.")
        }
    }

    private var emptySystemImage: String {
        switch mode {
        case .recent:
            return "clock"
        case .favorites:
            return "star"
        case .installed:
            return "square.stack.3d.up"
        }
    }
}
