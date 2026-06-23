import SwiftUI

struct LaunchInstanceDetailTabContent<LockfileStatusPanel: View, LockfileUpdatePanel: View>: View {
    @Binding var selectedTab: LaunchInstanceDetailTab
    let instance: GameInstance
    let summary: CoreLaunchInstanceSummary?
    let statusTitle: String
    let primaryTitle: String
    let primarySystemImage: String
    let primaryDisabled: Bool
    let lockfileStatusPanel: LockfileStatusPanel
    let lockfileUpdatePanel: LockfileUpdatePanel
    let launch: () -> Void
    let openContent: () -> Void
    let openDiscover: () -> Void
    let openSettings: () -> Void
    let openVersionManagement: () -> Void
    let backupSaves: () -> Void
    let exportInstance: () -> Void

    @ViewBuilder
    var body: some View {
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
