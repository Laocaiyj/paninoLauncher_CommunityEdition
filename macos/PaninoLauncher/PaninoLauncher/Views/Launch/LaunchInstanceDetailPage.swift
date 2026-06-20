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

struct PendingLockfileReview: Identifiable {
    let id = UUID()
    let policy: String
    let result: CoreLockfileSolverResult
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

    @EnvironmentObject var theme: ThemeSettings
    @State private var selectedTab: LaunchInstanceDetailTab = .overview
    @State private var appearanceTarget: GameInstance?
    @State var currentLockfile: CorePaninoLockfile?
    @State var lockfileVerify: CoreLockfileVerifyResponse?
    @State var lockfileStatusMessage = ""
    @State var lockfileBusy = false
    @State var pendingLockfileReview: PendingLockfileReview?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LaunchInstanceDetailHeader(
                instance: instance,
                primaryTitle: primaryTitle,
                primarySystemImage: primarySystemImage,
                primaryDisabled: primaryDisabled,
                canCancel: canCancel,
                back: back,
                launch: launch,
                cancel: cancel,
                editAppearance: {
                    appearanceTarget = instance
                },
                toggleFavorite: toggleFavorite
            )

            HStack(alignment: .top, spacing: 16) {
                LaunchInstanceDetailSidebar(selectedTab: $selectedTab)
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
            LaunchInstanceSummaryPanel(instance: instance, statusTitle: statusTitle)
            lockfileStatusPanel
            LaunchInstanceManagementPanel(
                instance: instance,
                summary: summary,
                showContent: { selectedTab = .content },
                showVersion: { selectedTab = .version },
                showSaves: { selectedTab = .saves },
                showSettings: { selectedTab = .settings }
            )
        }
    }

    private var contentContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LaunchInstanceContentPanel(
                instance: instance,
                summary: summary,
                openContent: openContent,
                openDiscover: openDiscover
            )
            lockfileUpdatePanel
        }
    }

    private var versionContent: some View {
        LaunchInstanceVersionPanel(
            instance: instance,
            summary: summary,
            primaryTitle: primaryTitle,
            primarySystemImage: primarySystemImage,
            primaryDisabled: primaryDisabled,
            launch: launch,
            openVersionManagement: openVersionManagement
        )
    }

    private var savesContent: some View {
        LaunchInstanceSavesPanel(
            instance: instance,
            summary: summary,
            showBackup: { selectedTab = .backup }
        )
    }

    private var settingsContent: some View {
        LaunchInstanceSettingsPanel(instance: instance, openSettings: openSettings)
    }

    private var backupContent: some View {
        LaunchInstanceBackupPanel(backupSaves: backupSaves, exportInstance: exportInstance)
    }

}
