import SwiftUI

enum LaunchInstanceDetailTab: String, CaseIterable, Identifiable {
    case overview
    case content
    case version
    case saves
    case settings
    case backup

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .overview:
            return localizedString(language, english: "Overview", chinese: "概览", italian: "Panoramica", french: "Aperçu", spanish: "Resumen")
        case .content:
            return localizedString(language, english: "Content", chinese: "内容", italian: "Contenuto", french: "Contenu", spanish: "Contenido")
        case .version:
            return localizedString(language, english: "Version", chinese: "版本", italian: "Versione", french: "Version", spanish: "Versión")
        case .saves:
            return localizedString(language, english: "Saves", chinese: "存档", italian: "Salvataggi", french: "Sauvegardes", spanish: "Partidas")
        case .settings:
            return localizedString(language, english: "Settings", chinese: "设置", italian: "Impostazioni", french: "Réglages", spanish: "Ajustes")
        case .backup:
            return localizedString(language, english: "Backup", chinese: "备份", italian: "Backup", french: "Sauvegarde", spanish: "Copia")
        }
    }
}

private struct PendingLockfileReview: Identifiable {
    let id = UUID()
    let policy: String
    let result: CoreLockfileSolverResult
}

private enum LaunchShelfMode: String, CaseIterable, Identifiable {
    case recent
    case favorites
    case installed

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .recent:
            return localizedString(language, english: "Recent", chinese: "最近", italian: "Recenti", french: "Récents", spanish: "Recientes")
        case .favorites:
            return localizedString(language, english: "Favorites", chinese: "收藏", italian: "Preferiti", french: "Favoris", spanish: "Favoritos")
        case .installed:
            return localizedString(language, english: "Installed", chinese: "已安装", italian: "Installate", french: "Installées", spanish: "Instaladas")
        }
    }
}

struct LaunchLibraryHomeView: View {
    let hasInstalledInstances: Bool
    let heroInstance: GameInstance
    let heroSummary: CoreLaunchInstanceSummary?
    let performanceSummary: CorePerformanceSummary?
    let packDoctorReport: CoreCompatibilityReport?
    let packDoctorDiagnostics: [CoreDiagnostic]
    let packDoctorStatusText: String
    let packDoctorIsWorking: Bool
    let recentInstances: [GameInstance]
    let recentInstalledInstances: [GameInstance]
    let favoriteInstances: [GameInstance]
    let selectedID: UUID
    let statusTitle: String
    let statusStyle: StatusBadge.Style
    let primaryTitle: String
    let primarySystemImage: String
    let primaryDisabled: Bool
    let canCancel: Bool
    let summaryFor: (GameInstance) -> CoreLaunchInstanceSummary?
    let onPrimaryAction: () -> Void
    let onPackDoctorRefresh: () -> Void
    let onPackDoctorPrimaryAction: () -> Void
    let onCancel: () -> Void
    let select: (UUID) -> Void
    let openDetails: (UUID) -> Void
    let toggleFavorite: (UUID, Bool) -> Void
    let hideRecent: (UUID) -> Void
    let updateAppearance: (UUID, InstanceAppearanceValues) -> Void
    let openDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @State private var shelfMode: LaunchShelfMode = .recent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassPanel {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        libraryHero(showsPanel: false)
                            .frame(minWidth: 420, idealWidth: 620, maxWidth: 760, alignment: .topLeading)
                        LaunchHomeShelfSwitcher(
                            mode: $shelfMode,
                            recentInstances: recentInstances,
                            recentInstalledInstances: recentInstalledInstances,
                            favoriteInstances: favoriteInstances,
                            selectedID: selectedID,
                            summaryFor: summaryFor,
                            select: select,
                            openDetails: openDetails,
                            toggleFavorite: toggleFavorite,
                            hideRecent: hideRecent,
                            showsPanel: false
                        )
                        .frame(minWidth: 420, maxWidth: .infinity, alignment: .topLeading)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        libraryHero(showsPanel: false)
                        LaunchHomeShelfSwitcher(
                            mode: $shelfMode,
                            recentInstances: recentInstances,
                            recentInstalledInstances: recentInstalledInstances,
                            favoriteInstances: favoriteInstances,
                            selectedID: selectedID,
                            summaryFor: summaryFor,
                            select: select,
                            openDetails: openDetails,
                            toggleFavorite: toggleFavorite,
                            hideRecent: hideRecent,
                            showsPanel: false
                        )
                    }
                }
            }
        }
    }

    private func libraryHero(showsPanel: Bool) -> some View {
        LaunchLibraryHeroCard(
            hasInstalledInstances: hasInstalledInstances,
            instance: heroInstance,
            summary: heroSummary,
            performanceSummary: performanceSummary,
            packDoctorReport: packDoctorReport,
            packDoctorDiagnostics: packDoctorDiagnostics,
            packDoctorStatusText: packDoctorStatusText,
            packDoctorIsWorking: packDoctorIsWorking,
            statusTitle: statusTitle,
            statusStyle: statusStyle,
            primaryTitle: primaryTitle,
            primarySystemImage: primarySystemImage,
            primaryDisabled: primaryDisabled,
            canCancel: canCancel,
            onPrimaryAction: onPrimaryAction,
            onPackDoctorRefresh: onPackDoctorRefresh,
            onPackDoctorPrimaryAction: onPackDoctorPrimaryAction,
            onCancel: onCancel,
            openDetails: { openDetails(heroInstance.id) },
            updateAppearance: updateAppearance,
            openDiscover: openDiscover,
            showsPanel: showsPanel
        )
    }
}

private struct LaunchLibraryHeroCard: View {
    let hasInstalledInstances: Bool
    let instance: GameInstance
    let summary: CoreLaunchInstanceSummary?
    let performanceSummary: CorePerformanceSummary?
    let packDoctorReport: CoreCompatibilityReport?
    let packDoctorDiagnostics: [CoreDiagnostic]
    let packDoctorStatusText: String
    let packDoctorIsWorking: Bool
    let statusTitle: String
    let statusStyle: StatusBadge.Style
    let primaryTitle: String
    let primarySystemImage: String
    let primaryDisabled: Bool
    let canCancel: Bool
    let onPrimaryAction: () -> Void
    let onPackDoctorRefresh: () -> Void
    let onPackDoctorPrimaryAction: () -> Void
    let onCancel: () -> Void
    let openDetails: () -> Void
    let updateAppearance: (UUID, InstanceAppearanceValues) -> Void
    let openDiscover: () -> Void
    var showsPanel = true

    @EnvironmentObject private var theme: ThemeSettings
    @State private var appearanceTarget: GameInstance?

    var body: some View {
        Group {
            if showsPanel {
                GlassPanel { content }
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
            if hasInstalledInstances {
                VStack(alignment: .leading, spacing: 16) {
                    LaunchLibraryCover(instance: instance)
                        .frame(height: coverHeight)
                        .overlay(alignment: .topTrailing) {
                            HoverRevealAppearanceButton {
                                appearanceTarget = instance
                            }
                            .padding(12)
                        }

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(instance.name)
                                .font(.title.bold())
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                            metadataLine
                        }
                        Spacer(minLength: 8)
                        LaunchPetPlaceholder()
                    }

                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 10) {
                        LaunchMetric(title: localizedString(theme.language, english: "Last Launch", chinese: "最近启动", italian: "Ultimo avvio", french: "Dernier lancement", spanish: "Último inicio"), value: lastLaunchText)
                        LaunchMetric(title: localizedString(theme.language, english: "Play Time", chinese: "游戏时长", italian: "Tempo gioco", french: "Temps de jeu", spanish: "Tiempo jugado"), value: formattedPlayDuration(instance.totalPlaySeconds ?? 0, language: theme.language))
                        LaunchMetric(title: localizedString(theme.language, english: "Content", chinese: "内容", italian: "Contenuto", french: "Contenu", spanish: "Contenido"), value: contentText)
                    }

                    PackDoctorPanel(
                        report: packDoctorReport,
                        performanceSummary: performanceSummary,
                        diagnostics: packDoctorDiagnostics,
                        isWorking: packDoctorIsWorking,
                        statusText: packDoctorStatusText,
                        onRefresh: onPackDoctorRefresh,
                        onPrimaryAction: onPackDoctorPrimaryAction,
                        onOpenDiagnostics: openDetails
                    )

                    HStack(spacing: 10) {
                        LaunchHeroTextButton(
                            title: primaryTitle,
                            prominent: true,
                            minWidth: 136,
                            minHeight: 56,
                            action: onPrimaryAction
                        )
                            .keyboardShortcut(.return, modifiers: [.command])
                            .disabled(primaryDisabled)
                        LaunchHeroTextButton(
                            title: localizedString(theme.language, english: "Details", chinese: "详情", italian: "Dettagli", french: "Détails", spanish: "Detalles"),
                            minWidth: 118,
                            minHeight: 56,
                            action: openDetails
                        )
                        if canCancel {
                            GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: onCancel)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 460, alignment: .topLeading)
                .sheet(item: $appearanceTarget) { target in
                    InstanceAppearanceEditor(instance: target) { values in
                        updateAppearance(target.id, values)
                    }
                    .environmentObject(theme)
                }
            } else {
                emptyHero
            }
    }

    private var emptyHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            EmptyStateInline(
                title: localizedString(theme.language, english: "No local instance yet", chinese: "还没有本地实例", italian: "Nessuna istanza locale", french: "Aucune instance locale", spanish: "Sin instancia local"),
                message: localizedString(theme.language, english: "Install a Minecraft version from Get. It will appear here as the primary launch target.", chinese: "请先从“获取”安装 Minecraft 版本。安装完成后会在这里作为主启动目标显示。", italian: "Installa una versione da Ottieni.", french: "Installez une version depuis Obtenir.", spanish: "Instala una versión desde Obtener."),
                systemImage: "square.stack.3d.up.slash"
            )
            Spacer(minLength: 0)
            GlassButton(
                systemImage: "arrow.down.circle",
                title: localizedString(theme.language, english: "Get Minecraft", chinese: "获取 Minecraft", italian: "Ottieni Minecraft", french: "Obtenir Minecraft", spanish: "Obtener Minecraft"),
                prominent: true,
                action: openDiscover
            )
        }
        .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.heroMinHeight, alignment: .topLeading)
    }

    private var metadataLine: some View {
        HStack(spacing: 6) {
            MetadataLine(items: [
                "Minecraft \(instance.minecraftVersion)",
                instance.loaderTitle(language: theme.language)
            ])
            if instance.isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .accessibilityLabel(localizedString(theme.language, english: "Favorite"))
            }
        }
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .top)]
    }

    private var coverHeight: CGFloat {
        if showsPanel { return 230 }
        return 260
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

private struct LaunchHeroTextButton: View {
    let title: String
    var prominent = false
    var minWidth: CGFloat = 112
    var minHeight: CGFloat = 52
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, prominent ? 30 : 26)
                .frame(minWidth: minWidth, minHeight: minHeight)
        }
        .buttonStyle(
            LaunchHeroTextButtonStyle(
                prominent: prominent,
                accentColor: theme.semanticSelectionColor,
                material: reduceTransparency ? nil : theme.effectiveMaterialStrength.material,
                reduceMotion: reduceMotion || theme.reducesInterfaceMotion
            )
        )
        .opacity(isEnabled ? 1 : 0.56)
        .accessibilityLabel(title)
    }
}

private struct LaunchHeroTextButtonStyle: ButtonStyle {
    let prominent: Bool
    let accentColor: Color
    let material: Material?
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? .white : .primary)
            .background {
                background(isPressed: configuration.isPressed)
            }
            .clipShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
        if prominent {
            shape.fill(accentColor.opacity(isPressed ? 0.82 : 0.96))
        } else if let material {
            shape.fill(material)
            shape.strokeBorder(Color(nsColor: .separatorColor).opacity(0.48))
        } else {
            shape.fill(Color(nsColor: .controlBackgroundColor).opacity(isPressed ? 0.82 : 1))
            shape.strokeBorder(Color(nsColor: .separatorColor).opacity(0.7))
        }
    }
}

private struct HoverRevealAppearanceButton: View {
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .contentShape(Rectangle())

            LaunchHeroTextButton(
                title: localizedString(theme.language, english: "Appearance", chinese: "外观", italian: "Aspetto", french: "Apparence", spanish: "Apariencia"),
                minWidth: 86,
                minHeight: 44,
                action: action
            )
            .opacity(isHovered ? 1 : 0)
            .scaleEffect(isHovered ? 1 : 0.98, anchor: .topTrailing)
            .allowsHitTesting(isHovered)
            .accessibilityHidden(!isHovered)
        }
        .frame(width: 128, height: 64, alignment: .topTrailing)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovered
            }
        }
    }
}

private struct LaunchLibraryCover: View {
    let instance: GameInstance
    @State private var image: NSImage?
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [
                            instance.coverTintColor.opacity(0.44),
                            Color(nsColor: .controlBackgroundColor).opacity(0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: instance.resolvedIconName)
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(instance.coverTintColor)
                        Text("Minecraft \(instance.minecraftVersion)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(instance.loaderTitle(language: theme.language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(18)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
                }
                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.32)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .task(id: instance.coverPath) {
            guard !instance.coverPath.isEmpty else {
                image = nil
                return
            }
            image = await ThumbnailCache.shared.image(path: instance.coverPath, size: CGSize(width: 640, height: 360))
        }
    }
}

private struct LaunchHomeShelfSwitcher: View {
    @Binding var mode: LaunchShelfMode
    let recentInstances: [GameInstance]
    let recentInstalledInstances: [GameInstance]
    let favoriteInstances: [GameInstance]
    let selectedID: UUID
    let summaryFor: (GameInstance) -> CoreLaunchInstanceSummary?
    let select: (UUID) -> Void
    let openDetails: (UUID) -> Void
    let toggleFavorite: (UUID, Bool) -> Void
    let hideRecent: (UUID) -> Void
    var showsPanel = true

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Group {
            if showsPanel {
                GlassPanel { content }
            } else {
                content
            }
        }
    }

    private var content: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode == .recent
                            ? localizedString(theme.language, english: "Recent Launches", chinese: "最近启动", italian: "Avvii recenti", french: "Lancements récents", spanish: "Inicios recientes")
                            : mode == .favorites
                                ? localizedString(theme.language, english: "Favorites", chinese: "收藏", italian: "Preferiti", french: "Favoris", spanish: "Favoritos")
                                : localizedString(theme.language, english: "Recently Installed", chinese: "最近安装", italian: "Installate di recente", french: "Installées récemment", spanish: "Instaladas recientes"))
                            .font(.headline)
                    }
                    Spacer()
                    Picker("", selection: $mode) {
                        ForEach(LaunchShelfMode.allCases) { item in
                            Text(item.title(language: theme.language)).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }

                if visibleInstances.isEmpty {
                    EmptyStateInline(title: emptyTitle, message: emptyMessage, systemImage: emptySystemImage)
                        .frame(minHeight: 74)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
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
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 420, alignment: .topLeading)
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

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: PaninoTokens.Layout.shelfCardWidth), spacing: 10, alignment: .top)]
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
            return localizedString(theme.language, english: "Use the context menu or details page to pin instances.", chinese: "可在右键菜单或详情页收藏实例。", italian: "Usa menu o dettagli per fissarle.", french: "Utilisez le menu ou les détails pour l'ajouter.", spanish: "Usa menú o detalles para fijarlas.")
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

private struct LaunchShelfTile: View {
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
            .background(selected ? theme.semanticSelectionColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.26), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(selected ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
            }
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

struct LaunchInstanceDetailPage: View {
    let instance: GameInstance
    @ObservedObject var viewModel: LauncherViewModel
    let summary: CoreLaunchInstanceSummary?
    let statusTitle: String
    let statusStyle: StatusBadge.Style
    let primaryTitle: String
    let primarySystemImage: String
    let primaryDisabled: Bool
    let canCancel: Bool
    let back: () -> Void
    let launch: () -> Void
    let cancel: () -> Void
    let openContent: () -> Void
    let openDiscover: () -> Void
    let openSettings: () -> Void
    let openVersionManagement: () -> Void
    let backupSaves: () -> Void
    let exportInstance: () -> Void
    let toggleFavorite: () -> Void
    let updateAppearance: (UUID, InstanceAppearanceValues) -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @State private var selectedTab: LaunchInstanceDetailTab = .overview
    @State private var appearanceTarget: GameInstance?
    @State private var currentLockfile: CorePaninoLockfile?
    @State private var lockfileVerify: CoreLockfileVerifyResponse?
    @State private var lockfileStatusMessage = ""
    @State private var lockfileBusy = false
    @State private var pendingLockfileReview: PendingLockfileReview?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            detailHeader

            HStack(alignment: .top, spacing: 16) {
                tabSidebar
                    .frame(width: 210, alignment: .topLeading)
                tabContent
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .sheet(item: $appearanceTarget) { target in
            InstanceAppearanceEditor(instance: target) { values in
                updateAppearance(target.id, values)
            }
            .environmentObject(theme)
        }
        .sheet(item: $pendingLockfileReview) { review in
            LockfileReviewSheet(
                result: review.result,
                title: lockfileReviewTitle(for: review.policy),
                subtitle: lockfileReviewSubtitle(for: review.result),
                confirmTitle: localizedString(theme.language, english: "Apply", chinese: "应用", italian: "Applica", french: "Appliquer", spanish: "Aplicar"),
                onCancel: { pendingLockfileReview = nil },
                onConfirm: { applyLockfileReview(review) }
            )
            .environmentObject(theme)
        }
        .task(id: instance.gameDirectory) {
            await refreshLockfileState()
        }
    }

    private var detailHeader: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Button(action: back) {
                        Label(localizedString(theme.language, english: "Back", chinese: "返回", italian: "Indietro", french: "Retour", spanish: "Volver"), systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text(instance.name)
                                .font(.title2.bold())
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        MetadataLine(items: instance.metadataLine(language: theme.language))
                    }

                    Spacer()
                    LaunchPetPlaceholder()
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { headerActions }
                    VStack(alignment: .leading, spacing: 10) { headerActions }
                }
            }
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        GlassButton(systemImage: primarySystemImage, title: primaryTitle, prominent: true, action: launch)
            .disabled(primaryDisabled)
        if canCancel {
            GlassButton(systemImage: "xmark.circle", title: AppText.cancel.localized(theme.language), action: cancel)
        }
        GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta")) {
            FinderIntegration.openInstanceDirectory(instance)
        }
        GlassButton(systemImage: "paintpalette", title: localizedString(theme.language, english: "Appearance", chinese: "外观", italian: "Aspetto", french: "Apparence", spanish: "Apariencia")) {
            appearanceTarget = instance
        }
        GlassButton(systemImage: instance.isFavorite ? "star.slash" : "star", title: instance.isFavorite ? localizedString(theme.language, english: "Unpin", chinese: "取消收藏", italian: "Sblocca", french: "Retirer", spanish: "Quitar") : localizedString(theme.language, english: "Pin", chinese: "收藏", italian: "Fissa", french: "Épingler", spanish: "Fijar"), action: toggleFavorite)
    }

    private var tabSidebar: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(LaunchInstanceDetailTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.title(language: theme.language))
                            .font(.callout.weight(selectedTab == tab ? .semibold : .regular))
                            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                            .padding(.horizontal, 12)
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedTab == tab ? Color.white : .primary)
                    .background(selectedTab == tab ? theme.semanticSelectionColor : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .overview:
            overviewContent
        case .content:
            contentContent
        case .version:
            versionContent
        case .saves:
            savesContent
        case .settings:
            settingsContent
        case .backup:
            backupContent
        }
    }

    private var overviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            summaryPanel
            lockfileStatusPanel
            managementPanel
        }
    }

    private var summaryPanel: some View {
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

    private var managementPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Manage", chinese: "管理", italian: "Gestisci", french: "Gérer", spanish: "Gestionar"))
                    .font(.headline)
                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
                    detailAction(title: localizedString(theme.language, english: "Content", chinese: "内容", italian: "Contenuto", french: "Contenu", spanish: "Contenido"), subtitle: contentOverview, action: { selectedTab = .content })
                    detailAction(title: localizedString(theme.language, english: "Version", chinese: "版本", italian: "Versione", french: "Version", spanish: "Versión"), subtitle: "Minecraft \(instance.minecraftVersion)", action: { selectedTab = .version })
                    detailAction(title: localizedString(theme.language, english: "Saves", chinese: "存档", italian: "Salvataggi", french: "Sauvegardes", spanish: "Partidas"), subtitle: "\(summary?.content.saveCount ?? 0)", action: { selectedTab = .saves })
                    detailAction(title: localizedString(theme.language, english: "Settings", chinese: "设置", italian: "Impostazioni", french: "Réglages", spanish: "Ajustes"), subtitle: "\(instance.memoryMb) MB", action: { selectedTab = .settings })
                }
            }
        }
    }

    private var lockfileStatusPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(localizedString(theme.language, english: "Lockfile", chinese: "锁文件", italian: "Lockfile", french: "Lockfile", spanish: "Lockfile"), systemImage: "lock.doc")
                        .font(.headline)
                    Spacer()
                    StatusBadge(title: lockfileStatusTitle, style: lockfileBadgeStyle)
                }
                LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                    LaunchMetric(title: localizedString(theme.language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"), value: "\(currentLockfile?.files.count ?? 0)")
                    LaunchMetric(title: localizedString(theme.language, english: "Drift", chinese: "漂移", italian: "Deriva", french: "Dérive", spanish: "Deriva"), value: "\(lockfileVerify?.lockfileDrift.count ?? 0)")
                    LaunchMetric(title: localizedString(theme.language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar"), value: lockfileVerify?.repairPlan == nil ? "-" : localizedString(theme.language, english: "Ready", chinese: "可用", italian: "Pronto", french: "Prêt", spanish: "Listo"))
                    LaunchMetric(title: localizedString(theme.language, english: "Manual", chinese: "手动", italian: "Manuale", french: "Manuel", spanish: "Manual"), value: "\(manualChangeCount)")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { lockfileActionButtons }
                    VStack(alignment: .leading, spacing: 10) { lockfileActionButtons }
                }
                if !lockfileStatusMessage.isEmpty {
                    Text(lockfileStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .paninoTruncation(.summary(lines: 2))
                }
            }
        }
    }

    @ViewBuilder
    private var lockfileActionButtons: some View {
        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
            Task { await refreshLockfileState() }
        }
        .disabled(lockfileBusy)
        if lockfileVerify?.repairPlan != nil {
            GlassButton(systemImage: "wrench.and.screwdriver", title: localizedString(theme.language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar")) {
                Task { await prepareLockfileReview(policy: "repair") }
            }
            .disabled(lockfileBusy)
        }
    }

    private var lockfileUpdatePanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Lockfile Updates", chinese: "锁文件更新", italian: "Aggiornamenti lockfile", french: "Mises à jour lockfile", spanish: "Actualizaciones lockfile"))
                    .font(.headline)
                LazyVGrid(columns: actionColumns, alignment: .leading, spacing: 10) {
                    updatePolicyButton(policy: "keepLocked", systemImage: "lock", title: localizedString(theme.language, english: "Keep Locked", chinese: "保持锁定", italian: "Mantieni bloccato", french: "Garder verrouillé", spanish: "Mantener fijado"))
                    updatePolicyButton(policy: "updateSelected", systemImage: "checklist.checked", title: localizedString(theme.language, english: "Update Selected", chinese: "只更新选中项", italian: "Aggiorna selezionati", french: "Mettre à jour sélection", spanish: "Actualizar selección"))
                    updatePolicyButton(policy: "updateAllSafe", systemImage: "shield.checkered", title: localizedString(theme.language, english: "Update All Safe", chinese: "安全更新全部", italian: "Aggiorna sicuro", french: "Tout mettre à jour sûr", spanish: "Actualizar seguro"))
                    updatePolicyButton(policy: "relock", systemImage: "arrow.triangle.2.circlepath", title: localizedString(theme.language, english: "Relock", chinese: "重新锁定", italian: "Riblocca", french: "Reverrouiller", spanish: "Rebloquear"))
                }
            }
        }
    }

    private func updatePolicyButton(policy: String, systemImage: String, title: String) -> some View {
        Button {
            Task { await prepareLockfileReview(policy: policy) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(updatePolicySubtitle(policy))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.26), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(lockfileBusy)
    }

    private var contentContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    Text(localizedString(theme.language, english: "Installed Content", chinese: "已安装内容", italian: "Contenuto installato", french: "Contenu installé", spanish: "Contenido instalado"))
                        .font(.headline)
                    LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                        LaunchMetric(title: "Mods", value: "\(summary?.content.modCount ?? 0)")
                        LaunchMetric(title: localizedString(theme.language, english: "Resource Packs", chinese: "资源包", italian: "Pacchetti risorse", french: "Packs de ressources", spanish: "Paquetes de recursos"), value: "\(summary?.content.resourcePackCount ?? 0)")
                        LaunchMetric(title: localizedString(theme.language, english: "Shaders", chinese: "光影包", italian: "Shader", french: "Shaders", spanish: "Shaders"), value: "\(summary?.content.shaderPackCount ?? 0)")
                        LaunchMetric(title: localizedString(theme.language, english: "Warnings", chinese: "警告", italian: "Avvisi", french: "Alertes", spanish: "Avisos"), value: "\(summary?.content.warningCount ?? 0)")
                    }
                    HStack(spacing: 10) {
                        GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Manage Content", chinese: "管理内容", italian: "Gestisci contenuti", french: "Gérer contenu", spanish: "Gestionar contenido"), action: openContent)
                        GlassButton(systemImage: "arrow.down.circle", title: localizedString(theme.language, english: "Install Online", chinese: "在线安装", italian: "Installa online", french: "Installer en ligne", spanish: "Instalar online"), action: openDiscover)
                        GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta")) {
                            FinderIntegration.openManagedFolder(kind: .mods, instance: instance)
                        }
                        .disabled(instance.loader == nil)
                    }
                }
            }
            lockfileUpdatePanel
        }
    }

    private var versionContent: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Version and Loader", chinese: "版本与加载器", italian: "Versione e loader", french: "Version et chargeur", spanish: "Versión y cargador"))
                    .font(.headline)
                LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                    LaunchMetric(title: "Minecraft", value: instance.minecraftVersion)
                    LaunchMetric(title: localizedString(theme.language, english: "Loader"), value: instance.loaderTitle(language: theme.language))
                    LaunchMetric(title: localizedString(theme.language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"), value: summary?.status ?? instance.status.rawValue)
                    LaunchMetric(title: localizedString(theme.language, english: "Disk", chinese: "磁盘", italian: "Disco", french: "Disque", spanish: "Disco"), value: formattedBytes(summary?.diskUsageBytes))
                }
                HStack(spacing: 10) {
                    GlassButton(systemImage: "square.stack.3d.up", title: localizedString(theme.language, english: "Manage Versions", chinese: "版本管理", italian: "Gestisci versioni", french: "Gérer versions", spanish: "Gestionar versiones"), action: openVersionManagement)
                    GlassButton(systemImage: primarySystemImage, title: primaryTitle, action: launch)
                        .disabled(primaryDisabled)
                    GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Folder", chinese: "打开文件夹", italian: "Apri cartella", french: "Ouvrir dossier", spanish: "Abrir carpeta")) {
                        FinderIntegration.openInstanceDirectory(instance)
                    }
                }
            }
        }
    }

    private var savesContent: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Saves", chinese: "存档", italian: "Salvataggi", french: "Sauvegardes", spanish: "Partidas"))
                    .font(.headline)
                LaunchMetric(title: localizedString(theme.language, english: "Detected Saves", chinese: "已检测存档", italian: "Salvataggi rilevati", french: "Sauvegardes détectées", spanish: "Partidas detectadas"), value: "\(summary?.content.saveCount ?? 0)")
                    .frame(maxWidth: 240)
                HStack(spacing: 10) {
                    GlassButton(systemImage: "folder", title: localizedString(theme.language, english: "Open Saves Folder", chinese: "打开存档文件夹", italian: "Apri salvataggi", french: "Ouvrir sauvegardes", spanish: "Abrir partidas")) {
                        FinderIntegration.openSavesDirectory(instance)
                    }
                    GlassButton(systemImage: "archivebox", title: localizedString(theme.language, english: "Backup", chinese: "备份", italian: "Backup", french: "Sauvegarder", spanish: "Respaldar"), action: { selectedTab = .backup })
                }
            }
        }
    }

    private var settingsContent: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Run Settings", chinese: "运行设置", italian: "Impostazioni avvio", french: "Réglages d'exécution", spanish: "Ajustes de ejecución"))
                    .font(.headline)
                LazyVGrid(columns: detailMetricColumns, alignment: .leading, spacing: 10) {
                    LaunchMetric(title: "Java", value: instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? localizedString(theme.language, english: "Automatic", chinese: "自动", italian: "Automatico", french: "Automatique", spanish: "Automático") : instance.javaPath)
                    LaunchMetric(title: localizedString(theme.language, english: "Memory", chinese: "内存", italian: "Memoria", french: "Mémoire", spanish: "Memoria"), value: "\(instance.memoryMb) MB")
                    LaunchMetric(title: localizedString(theme.language, english: "JVM Args", chinese: "JVM 参数", italian: "Argomenti JVM", french: "Arguments JVM", spanish: "Argumentos JVM"), value: instance.jvmArguments.isEmpty ? "-" : instance.jvmArguments)
                }
                GlassButton(systemImage: "gearshape", title: localizedString(theme.language, english: "Open Settings", chinese: "打开设置", italian: "Apri impostazioni", french: "Ouvrir réglages", spanish: "Abrir ajustes"), action: openSettings)
            }
        }
    }

    private var backupContent: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString(theme.language, english: "Backup and Export", chinese: "备份与导出", italian: "Backup ed esportazione", french: "Sauvegarde et export", spanish: "Copia y exportación"))
                    .font(.headline)
                Text(localizedString(theme.language, english: "Preflight checks and archive/export work are delegated to Core.", chinese: "预检、压缩和导出由 Core 处理。", italian: "Controlli e archivi sono gestiti dal Core.", french: "Les contrôles et archives sont gérés par Core.", spanish: "Las comprobaciones y archivos las gestiona Core."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    GlassButton(systemImage: "archivebox", title: localizedString(theme.language, english: "Backup Saves", chinese: "备份存档", italian: "Backup salvataggi", french: "Sauvegarder", spanish: "Respaldar partidas"), action: backupSaves)
                    GlassButton(systemImage: "square.and.arrow.up", title: localizedString(theme.language, english: "Export Instance", chinese: "导出实例", italian: "Esporta istanza", french: "Exporter instance", spanish: "Exportar instancia"), action: exportInstance)
                }
            }
        }
    }

    private var detailMetricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 170), spacing: 10, alignment: .top)]
    }

    private var actionColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 190), spacing: 10, alignment: .top)]
    }

    private var manualChangeCount: Int {
        guard let lockfileVerify else { return 0 }
        return lockfileVerify.manualFiles.count + lockfileVerify.extraFiles.count
    }

    private var lockfileStatusTitle: String {
        if lockfileBusy {
            return localizedString(theme.language, english: "Checking", chinese: "检查中", italian: "Controllo", french: "Vérification", spanish: "Comprobando")
        }
        if needsRelock {
            return localizedString(theme.language, english: "Needs Relock", chinese: "需要重解", italian: "Da ribloccare", french: "À reverrouiller", spanish: "Rebloquear")
        }
        guard let lockfileVerify else {
            return currentLockfile == nil
                ? localizedString(theme.language, english: "No Lock", chinese: "未锁定", italian: "Nessun lock", french: "Non verrouillé", spanish: "Sin lock")
                : localizedString(theme.language, english: "Unknown", chinese: "未知", italian: "Sconosciuto", french: "Inconnu", spanish: "Desconocido")
        }
        if lockfileVerify.repairPlan != nil {
            return localizedString(theme.language, english: "Repairable", chinese: "可修复", italian: "Riparabile", french: "Réparable", spanish: "Reparable")
        }
        if manualChangeCount > 0 {
            return localizedString(theme.language, english: "Manual Changes", chinese: "手动修改", italian: "Modifiche manuali", french: "Modifications", spanish: "Cambios manuales")
        }
        if lockfileVerify.status == "locked" {
            return localizedString(theme.language, english: "Locked", chinese: "已锁定", italian: "Bloccato", french: "Verrouillé", spanish: "Bloqueado")
        }
        return localizedString(theme.language, english: "Drifted", chinese: "有漂移", italian: "Deriva", french: "Dérive", spanish: "Deriva")
    }

    private var lockfileBadgeStyle: StatusBadge.Style {
        if lockfileBusy { return .download }
        if needsRelock || lockfileVerify?.repairPlan != nil { return .warning }
        if manualChangeCount > 0 || lockfileVerify?.status == "drifted" { return .warning }
        return currentLockfile == nil ? .neutral : .success
    }

    private var needsRelock: Bool {
        guard let currentLockfile else { return false }
        if let minecraft = currentLockfile.minecraft, minecraft != instance.contentMinecraftVersion {
            return true
        }
        if let family = currentLockfile.loader?.family, family != instance.loader?.rawValue {
            return true
        }
        return false
    }

    @MainActor
    private func refreshLockfileState() async {
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        lockfileBusy = true
        defer { lockfileBusy = false }
        do {
            let current = try await viewModel.currentLockfile(gameDir: instance.gameDirectory)
            currentLockfile = current.lockfile
            if let lockfile = current.lockfile {
                lockfileVerify = try await viewModel.verifyLockfile(CoreLockfileVerifyRequest(targetGameDir: instance.gameDirectory, lockfile: lockfile))
                lockfileStatusMessage = ""
            } else {
                lockfileVerify = nil
                lockfileStatusMessage = localizedString(theme.language, english: "No panino-lock.json exists for this instance.", chinese: "此实例还没有 panino-lock.json。", italian: "Nessun panino-lock.json per questa istanza.", french: "Aucun panino-lock.json pour cette instance.", spanish: "No hay panino-lock.json para esta instancia.")
            }
        } catch {
            lockfileVerify = nil
            lockfileStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func prepareLockfileReview(policy: String) async {
        guard !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        lockfileBusy = true
        defer { lockfileBusy = false }
        do {
            if currentLockfile == nil {
                let current = try await viewModel.currentLockfile(gameDir: instance.gameDirectory)
                currentLockfile = current.lockfile
            }
            let request = CoreLockfileSolveRequest(
                mode: policy == "repair" ? "repair" : "update",
                targetGameDir: instance.gameDirectory,
                minecraftVersion: instance.contentMinecraftVersion,
                loader: instance.loader?.rawValue,
                loaderVersion: instance.loaderVersion,
                existingLockfile: currentLockfile,
                updatePolicy: policy
            )
            let result = try await viewModel.solveLockfile(request)
            pendingLockfileReview = PendingLockfileReview(policy: policy, result: result)
            lockfileStatusMessage = ""
        } catch {
            lockfileStatusMessage = error.localizedDescription
        }
    }

    private func applyLockfileReview(_ review: PendingLockfileReview) {
        guard let lockfile = review.result.lockfile else { return }
        Task {
            do {
                _ = try await viewModel.applyLockfile(
                    CoreLockfileApplyRequest(
                        targetGameDir: instance.gameDirectory,
                        solverFingerprint: lockfile.fingerprint,
                        result: review.result
                    )
                )
                pendingLockfileReview = nil
                lockfileStatusMessage = localizedString(theme.language, english: "Lockfile applied.", chinese: "锁文件已应用。", italian: "Lockfile applicato.", french: "Lockfile appliqué.", spanish: "Lockfile aplicado.")
                await refreshLockfileState()
            } catch {
                lockfileStatusMessage = error.localizedDescription
            }
        }
    }

    private func updatePolicySubtitle(_ policy: String) -> String {
        switch policy {
        case "updateSelected":
            return localizedString(theme.language, english: "Selected packages and required dependencies.", chinese: "选中项目及必需依赖。", italian: "Elementi selezionati e dipendenze.", french: "Sélection et dépendances.", spanish: "Selección y dependencias.")
        case "updateAllSafe":
            return localizedString(theme.language, english: "Compatible updates only.", chinese: "只接受兼容更新。", italian: "Solo aggiornamenti compatibili.", french: "Mises à jour compatibles.", spanish: "Solo compatibles.")
        case "relock":
            return localizedString(theme.language, english: "Resolve from current inputs.", chinese: "按当前输入重新求解。", italian: "Risolvi dagli input attuali.", french: "Résoudre depuis les entrées.", spanish: "Resolver de nuevo.")
        default:
            return localizedString(theme.language, english: "Preserve existing locked packages.", chinese: "保留已锁定内容。", italian: "Mantieni pacchetti bloccati.", french: "Conserver le verrou.", spanish: "Conservar bloqueados.")
        }
    }

    private func lockfileReviewTitle(for policy: String) -> String {
        switch policy {
        case "repair":
            return localizedString(theme.language, english: "Review repair plan", chinese: "确认修复计划", italian: "Controlla riparazione", french: "Vérifier réparation", spanish: "Revisar reparación")
        case "updateSelected":
            return localizedString(theme.language, english: "Review selected update", chinese: "确认选中更新", italian: "Controlla selezionati", french: "Vérifier sélection", spanish: "Revisar selección")
        case "updateAllSafe":
            return localizedString(theme.language, english: "Review safe update", chinese: "确认安全更新", italian: "Controlla aggiornamento sicuro", french: "Vérifier mise à jour sûre", spanish: "Revisar actualización segura")
        case "relock":
            return localizedString(theme.language, english: "Review relock", chinese: "确认重新锁定", italian: "Controlla riblocco", french: "Vérifier reverrouillage", spanish: "Revisar rebloqueo")
        default:
            return localizedString(theme.language, english: "Review lockfile", chinese: "确认锁文件", italian: "Controlla lockfile", french: "Vérifier lockfile", spanish: "Revisar lockfile")
        }
    }

    private func lockfileReviewSubtitle(for result: CoreLockfileSolverResult) -> String {
        let changes = result.changeset.add.count + result.changeset.replace.count + result.changeset.remove.count + result.changeset.repair.count
        let deps = result.lockfile?.constraints.filter { $0.required && $0.relation == "requires" }.count ?? 0
        return localizedString(theme.language, english: "\(changes) changes · \(deps) required dependencies", chinese: "\(changes) 个变更 · \(deps) 个必需依赖", italian: "\(changes) cambi · \(deps) dipendenze", french: "\(changes) changements · \(deps) dépendances", spanish: "\(changes) cambios · \(deps) dependencias")
    }

    private var contentOverview: String {
        guard let content = summary?.content else {
            return localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando")
        }
        return "\(content.modCount) Mods · \(content.resourcePackCount) RP · \(content.shaderPackCount) Shaders"
    }

    private func detailAction(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
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

    private func formattedBytes(_ bytes: Int64?) -> String {
        guard let bytes else { return "-" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
