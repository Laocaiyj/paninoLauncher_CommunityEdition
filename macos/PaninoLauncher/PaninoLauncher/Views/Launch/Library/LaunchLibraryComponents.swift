import SwiftUI

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
    let openDiscover: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @State private var shelfMode: LaunchShelfMode = .recent

    var body: some View {
        ImmersivePageScaffold(
            minHeight: hasInstalledInstances ? 720 : 560,
            backgroundContent: {
                LaunchImmersiveBackground(instance: heroInstance, hasInstalledInstances: hasInstalledInstances)
            },
            primaryContent: {
                LaunchImmersiveHeroSummary(
                    hasInstalledInstances: hasInstalledInstances,
                    instance: heroInstance,
                    summary: heroSummary,
                    statusTitle: statusTitle,
                    statusStyle: statusStyle,
                    openDiscover: openDiscover
                )
            },
            floatingControls: {
                LaunchImmersiveControls(
                    hasInstalledInstances: hasInstalledInstances,
                    primaryTitle: primaryTitle,
                    primaryDisabled: primaryDisabled,
                    canCancel: canCancel,
                    onPrimaryAction: onPrimaryAction,
                    onCancel: onCancel,
                    openDetails: { openDetails(heroInstance.id) },
                    openDiscover: openDiscover
                )
            },
            contextShelf: {
                LaunchImmersiveContextShelf(
                    hasInstalledInstances: hasInstalledInstances,
                    mode: $shelfMode,
                    performanceSummary: performanceSummary,
                    packDoctorReport: packDoctorReport,
                    packDoctorDiagnostics: packDoctorDiagnostics,
                    packDoctorStatusText: packDoctorStatusText,
                    packDoctorIsWorking: packDoctorIsWorking,
                    recentInstances: recentInstances,
                    recentInstalledInstances: recentInstalledInstances,
                    favoriteInstances: favoriteInstances,
                    selectedID: selectedID,
                    summaryFor: summaryFor,
                    onPackDoctorRefresh: onPackDoctorRefresh,
                    onPackDoctorPrimaryAction: onPackDoctorPrimaryAction,
                    select: select,
                    openDetails: openDetails,
                    toggleFavorite: toggleFavorite,
                    hideRecent: hideRecent
                )
            }
        )
    }

}
