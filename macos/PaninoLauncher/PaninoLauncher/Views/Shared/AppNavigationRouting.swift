import SwiftUI

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
