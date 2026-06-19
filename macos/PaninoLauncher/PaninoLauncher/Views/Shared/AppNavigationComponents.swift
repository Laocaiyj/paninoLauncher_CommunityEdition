import AppKit
import SwiftUI

struct TopNavigationBar: View {
    @Binding var selection: LauncherSection?
    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let tokens = theme.resolvedTokens(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion
        )

        GeometryReader { proxy in
            let horizontalPadding = PaninoTokens.Layout.pagePadding(for: proxy.size.width)
            let navigationCornerRadius = navigationContainerCornerRadius(tokens: tokens)
            let leadingPadding = max(horizontalPadding, titlebarControlReserve(for: proxy.size.width))

            HStack(spacing: 16) {
                HStack(spacing: 10) {
                    PaninoBrandMark(size: 32, cornerRadius: PaninoTokens.Radius.control)

                    if proxy.size.width >= 720 {
                        Text("Panino")
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, proxy.size.width >= 720 ? 10 : 6)
                .frame(minHeight: 46)
                .background {
                    if theme.chromeStyle == .floatingToolbar {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.clear)
                            .paninoGlassSurface(
                                tokens: tokens,
                                level: .floatingChrome,
                                cornerRadius: 18,
                                interactive: true
                            )
                            .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.30))
                            .paninoDepthOverlay(tokens: tokens, level: .floatingChrome, cornerRadius: 18)
                    }
                }
                .shadow(
                    color: Color.black.opacity(theme.chromeStyle == .floatingToolbar ? tokens.shadowOpacity * 0.35 : 0),
                    radius: theme.chromeStyle == .floatingToolbar ? tokens.shadowRadius * 0.38 : 0,
                    x: 0,
                    y: theme.chromeStyle == .floatingToolbar ? tokens.shadowYOffset * 0.28 : 0
                )

                HStack(spacing: 4) {
                    ForEach(LauncherSection.primaryCases) { section in
                        TopNavigationItem(
                            title: section.title(language: theme.language),
                            isSelected: (selection ?? .launch).primaryParent == section,
                            tokens: tokens,
                            chromeStyle: theme.chromeStyle
                        ) {
                            selection = section
                        }
                    }
                }
                .padding(theme.chromeStyle == .integrated ? 2 : 4)
                .background {
                    navigationContainerBackground(tokens: tokens, cornerRadius: navigationCornerRadius)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: navigationCornerRadius, style: .continuous)
                        .strokeBorder(
                            tokens.strokeColor.opacity(navigationStrokeOpacity(tokens: tokens)),
                            lineWidth: tokens.strokeWidth
                        )
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: navigationCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(tokens.depthHighlightOpacity * 1.65), lineWidth: 1)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(Color.black.opacity(tokens.depthShadeOpacity * 1.15))
                        .frame(height: 1)
                        .padding(.horizontal, navigationCornerRadius * 0.55)
                        .allowsHitTesting(false)
                }
                .shadow(
                    color: Color.black.opacity(navigationShadowOpacity(tokens: tokens)),
                    radius: navigationShadowRadius(tokens: tokens),
                    x: 0,
                    y: navigationShadowYOffset(tokens: tokens)
                )

                Spacer(minLength: 16)
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, horizontalPadding)
            .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.topNavigationHeight, maxHeight: PaninoTokens.Layout.topNavigationHeight)
        }
        .frame(height: PaninoTokens.Layout.topNavigationHeight)
        .background {
            topChromeBackground(tokens: tokens)
        }
    }

    private func titlebarControlReserve(for width: CGFloat) -> CGFloat {
        width >= 720 ? 118 : 96
    }

    @ViewBuilder
    private func topChromeBackground(tokens: ResolvedThemeTokens) -> some View {
        if reduceTransparency || colorSchemeContrast == .increased {
            Color(nsColor: .windowBackgroundColor)
                .opacity(colorSchemeContrast == .increased ? 1.0 : 0.96)
                .overlay(theme.semanticSelectionColor.opacity(colorSchemeContrast == .increased ? 0.03 : 0.06))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(tokens.strokeColor.opacity(max(0.44, tokens.strokeOpacity)))
                        .frame(height: tokens.strokeWidth)
                }
        } else {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.12)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.12),
                        tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.18),
                        Color.black.opacity(0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if theme.chromeStyle == .edgeToEdgeSidebar {
                    Rectangle()
                        .fill(theme.semanticSelectionColor.opacity(0.07))
                        .frame(width: 184)
                }
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(tokens.depthHighlightOpacity * 0.36))
                    .blendMode(.plusLighter)
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(tokens.strokeColor.opacity(max(0.28, tokens.strokeOpacity * 0.58)))
                    .frame(height: tokens.strokeWidth)
            }
        }
    }

    private func navigationContainerCornerRadius(tokens: ResolvedThemeTokens) -> CGFloat {
        switch theme.chromeStyle {
        case .integrated:
            return min(tokens.navigationCornerRadius, 14)
        case .floatingToolbar:
            return tokens.navigationCornerRadius
        case .edgeToEdgeSidebar:
            return min(tokens.navigationCornerRadius, 12)
        }
    }

    private func navigationStrokeOpacity(tokens: ResolvedThemeTokens) -> Double {
        switch theme.chromeStyle {
        case .integrated:
            return 0
        case .floatingToolbar:
            return tokens.strokeOpacity * 0.78
        case .edgeToEdgeSidebar:
            return tokens.strokeOpacity * 0.46
        }
    }

    private func navigationShadowOpacity(tokens: ResolvedThemeTokens) -> Double {
        switch theme.chromeStyle {
        case .integrated:
            return tokens.shadowOpacity * 0.28
        case .floatingToolbar:
            return tokens.shadowOpacity * PaninoSurfaceLevel.floatingChrome.shadowMultiplier
        case .edgeToEdgeSidebar:
            return tokens.shadowOpacity * 0.35
        }
    }

    private func navigationShadowRadius(tokens: ResolvedThemeTokens) -> CGFloat {
        theme.chromeStyle == .floatingToolbar ? tokens.shadowRadius * 0.92 : tokens.shadowRadius * 0.35
    }

    private func navigationShadowYOffset(tokens: ResolvedThemeTokens) -> CGFloat {
        theme.chromeStyle == .floatingToolbar ? tokens.shadowYOffset * 0.72 : tokens.shadowYOffset * 0.26
    }

    @ViewBuilder
    private func navigationContainerBackground(tokens: ResolvedThemeTokens, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch theme.chromeStyle {
        case .integrated:
            shape
                .fill(Color.clear)
                .paninoGlassSurface(
                    tokens: tokens,
                    level: .elevatedPanel,
                    cornerRadius: cornerRadius,
                    interactive: true
                )
                .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.38))
                .paninoDepthOverlay(tokens: tokens, level: .elevatedPanel, cornerRadius: cornerRadius)
                .clipShape(shape)
        case .floatingToolbar:
            shape
                .fill(Color.clear)
                .paninoGlassSurface(
                    tokens: tokens,
                    level: .floatingChrome,
                    cornerRadius: cornerRadius,
                    interactive: true
                )
                .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.36))
                .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.54))
                .paninoDepthOverlay(tokens: tokens, level: .floatingChrome, cornerRadius: cornerRadius)
                .clipShape(shape)
        case .edgeToEdgeSidebar:
            shape
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.20))
                .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.28))
                .paninoDepthOverlay(tokens: tokens, level: .elevatedPanel, cornerRadius: cornerRadius)
                .clipShape(shape)
        }
    }
}

struct PaninoBrandMark: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image = PaninoBrandAsset.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: size * 0.58, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

enum PaninoBrandAsset {
    static let image: NSImage? = loadImage()

    private static func loadImage() -> NSImage? {
        if let image = NSImage(named: "PaninoAppIcon") {
            return image
        }

        for bundle in resourceBundles {
            if let url = bundle.url(
                forResource: "panino-app-icon",
                withExtension: "png",
                subdirectory: "Assets.xcassets/PaninoAppIcon.imageset"
            ),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }

    private static var resourceBundles: [Bundle] {
        #if SWIFT_PACKAGE
        [Bundle.module, Bundle.main]
        #else
        [Bundle.main]
        #endif
    }
}

struct TopNavigationItem: View {
    let title: String
    let isSelected: Bool
    let tokens: ResolvedThemeTokens
    let chromeStyle: ThemeChromeStyle
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minWidth: 144, minHeight: PaninoTokens.Layout.controlMinSize)
                .contentShape(RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            let shape = RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
            if isSelected {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                tokens.selectionColor.opacity(0.96),
                                tokens.selectionColor.opacity(0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        shape
                            .strokeBorder(Color.white.opacity(0.30), lineWidth: 1)
                    }
                    .overlay(alignment: .top) {
                        shape
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            .blendMode(.plusLighter)
                    }
                    .shadow(
                        color: tokens.selectionColor.opacity(chromeStyle == .floatingToolbar ? 0.34 : 0.18),
                        radius: chromeStyle == .floatingToolbar ? 12 : 6,
                        x: 0,
                        y: chromeStyle == .floatingToolbar ? 4 : 2
                    )
            } else {
                shape
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.24 : 0))
                    .overlay {
                        shape
                            .strokeBorder(Color.white.opacity(isHovering ? tokens.depthRimOpacity * 0.90 : 0), lineWidth: 1)
                    }
            }
        }
        .onHover { hovering in
            withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: theme.reducesInterfaceMotion)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel(title)
        .help(title)
    }
}

struct LauncherHorizontalDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.45))
            .frame(height: 1)
    }
}

enum LauncherSection: String, CaseIterable, Identifiable, Hashable {
    case launch
    case instances
    case discover
    case resources
    case versions
    case account
    case downloads
    case logs
    case diagnostics
    case settings

    var id: String { rawValue }

    static var primaryCases: [LauncherSection] {
        [.launch, .instances, .discover, .diagnostics]
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .launch:
            return AppText.launch.localized(language)
        case .instances:
            return AppText.instances.localized(language)
        case .discover:
            return localizedString(language, english: "Get", chinese: "获取", italian: "Ottieni", french: "Obtenir", spanish: "Obtener")
        case .resources:
            return localizedString(language, english: "Resources", chinese: "资源", italian: "Risorse", french: "Ressources", spanish: "Recursos")
        case .versions:
            return AppText.versions.localized(language)
        case .account:
            return AppText.account.localized(language)
        case .downloads:
            return AppText.tasks.localized(language)
        case .logs:
            return AppText.logs.localized(language)
        case .diagnostics:
            return localizedString(language, english: "Tasks", chinese: "任务", italian: "Attività", french: "Tâches", spanish: "Tareas")
        case .settings:
            return AppText.settings.localized(language)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .launch:
            return localizedString(language, english: "Library home, quick launch, and pack health.", chinese: "游戏库首页、快速启动与整合包健康状态。", italian: "Libreria, avvio rapido e salute del pacchetto.", french: "Bibliothèque, lancement rapide et santé du pack.", spanish: "Biblioteca, inicio rápido y salud del paquete.")
        case .instances:
            return localizedString(language, english: "Browse local instances and attached resources.", chinese: "浏览本地实例和关联资源。", italian: "Sfoglia istanze locali e risorse collegate.", french: "Parcourir les instances locales et ressources liées.", spanish: "Explora instancias locales y recursos vinculados.")
        case .discover:
            return localizedString(language, english: "Search, filter, and install Minecraft content.", chinese: "搜索、筛选并安装 Minecraft 内容。", italian: "Cerca, filtra e installa contenuti Minecraft.", french: "Rechercher, filtrer et installer du contenu Minecraft.", spanish: "Busca, filtra e instala contenido de Minecraft.")
        case .resources:
            return localizedString(language, english: "Manage versions, libraries, mods, and local files.", chinese: "管理版本、库、Mod 与本地文件。", italian: "Gestisci versioni, librerie, mod e file locali.", french: "Gérer versions, bibliothèques, mods et fichiers locaux.", spanish: "Gestiona versiones, bibliotecas, mods y archivos locales.")
        case .versions:
            return localizedString(language, english: "Inspect installed versions and content inventory.", chinese: "查看已安装版本与内容清单。", italian: "Controlla versioni installate e inventario contenuti.", french: "Inspecter versions installées et inventaire.", spanish: "Inspecciona versiones instaladas e inventario.")
        case .account:
            return localizedString(language, english: "Accounts, authentication, and identity state.", chinese: "账号、认证与身份状态。", italian: "Account, autenticazione e identità.", french: "Comptes, authentification et identité.", spanish: "Cuentas, autenticación e identidad.")
        case .downloads:
            return localizedString(language, english: "Downloads, installation queue, and history.", chinese: "下载、安装队列与历史记录。", italian: "Download, coda installazioni e cronologia.", french: "Téléchargements, file d'installation et historique.", spanish: "Descargas, cola de instalación e historial.")
        case .logs:
            return localizedString(language, english: "Core and game logs for troubleshooting.", chinese: "用于排查问题的 Core 与游戏日志。", italian: "Log Core e gioco per diagnosi.", french: "Journaux Core et jeu pour dépannage.", spanish: "Registros de Core y juego para diagnóstico.")
        case .diagnostics:
            return localizedString(language, english: "Active tasks, failures, diagnostics, and logs.", chinese: "活动任务、失败、诊断与日志。", italian: "Attività, errori, diagnostica e log.", french: "Tâches, échecs, diagnostics et journaux.", spanish: "Tareas, fallos, diagnósticos y registros.")
        case .settings:
            return localizedString(language, english: "Runtime, download, appearance, and advanced options.", chinese: "运行环境、下载、外观与高级选项。", italian: "Runtime, download, aspetto e opzioni avanzate.", french: "Runtime, téléchargements, apparence et options avancées.", spanish: "Runtime, descargas, apariencia y opciones avanzadas.")
        }
    }

    var primaryParent: LauncherSection {
        switch self {
        case .discover:
            return .discover
        case .instances, .resources, .versions:
            return .instances
        case .downloads, .logs, .diagnostics:
            return .diagnostics
        case .launch, .account, .settings:
            return .launch
        }
    }

    var systemImage: String {
        switch self {
        case .launch:
            return "play.square.stack"
        case .instances:
            return "square.stack.3d.up.fill"
        case .discover:
            return "arrow.down.app"
        case .resources:
            return "folder.badge.gearshape"
        case .versions:
            return "puzzlepiece.extension"
        case .account:
            return "person.crop.circle"
        case .downloads:
            return "arrow.down.circle"
        case .logs:
            return "terminal"
        case .diagnostics:
            return "checklist"
        case .settings:
            return "gearshape"
        }
    }
}

struct MainContentView: View {
    let section: LauncherSection
    @Binding var sectionSelection: LauncherSection?
    @ObservedObject var viewModel: LauncherViewModel
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var appActions: AppActionCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            PaninoWorkspaceScaffold(spacing: theme.fontDensity.spacing) { _ in
                sectionContent
            }
            .id(section)
            .transition(.opacity)
            .animation(PaninoMotion.noneWhenReduced(PaninoMotion.page, reduceMotion: reduceMotion || theme.reducesInterfaceMotion), value: section)

            BottomStatusBar(viewModel: viewModel) {
                sectionSelection = .diagnostics
            }
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .launch:
            LaunchDashboard(
                viewModel: viewModel,
                openInstances: { sectionSelection = .instances },
                openAccount: { openSettingsWindow(.account) },
                openResources: { sectionSelection = .instances },
                openDiscover: { sectionSelection = .discover },
                openTasks: { sectionSelection = .diagnostics },
                openLogs: { sectionSelection = .diagnostics },
                openSettings: { openSettingsWindow() }
            )
        case .instances:
            InstancesPage(
                viewModel: viewModel,
                openResources: { sectionSelection = .instances },
                openDiscover: { sectionSelection = .discover }
            )
        case .discover:
            OnlineContentDiscoveryPage(
                viewModel: viewModel,
                openSettings: { openSettingsWindow() },
                openDownloadSettings: { openSettingsWindow(.download) },
                openTasks: { sectionSelection = .diagnostics }
            )
        case .resources:
            InstancesPage(
                viewModel: viewModel,
                openResources: { sectionSelection = .instances },
                openDiscover: { sectionSelection = .discover }
            )
        case .versions:
            VersionsAndModsPage(viewModel: viewModel)
        case .account:
            SettingsCenterPage(viewModel: viewModel, usesInternalScroll: false)
        case .downloads:
            ActivityPage(viewModel: viewModel)
        case .logs:
            ActivityPage(viewModel: viewModel)
        case .diagnostics:
            ActivityPage(viewModel: viewModel)
        case .settings:
            SettingsCenterPage(viewModel: viewModel, usesInternalScroll: false)
        }
    }

    private func openSettingsWindow(_ section: PaninoSettingsSection? = nil) {
        if let section {
            appActions.focusSettings(section)
        }
        openWindow(id: PaninoWindowID.settings)
    }
}
