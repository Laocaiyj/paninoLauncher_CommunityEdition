import SwiftUI

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
                        LaunchShelfInstanceRail(
                            mode: mode,
                            instances: visibleInstances,
                            selectedID: selectedID,
                            summaryFor: summaryFor,
                            select: select,
                            openDetails: openDetails,
                            toggleFavorite: toggleFavorite,
                            hideRecent: hideRecent
                        )
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
