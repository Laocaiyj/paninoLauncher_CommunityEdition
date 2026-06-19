import SwiftUI

struct PendingPerformancePackReview: Identifiable {
    let id = UUID()
    let plan: CorePerformancePackPlan
    let request: CorePerformancePackInstallRequest
}

struct LaunchDashboard: View {
    @ObservedObject var viewModel: LauncherViewModel
    let openInstances: () -> Void
    let openAccount: () -> Void
    let openResources: () -> Void
    let openDiscover: () -> Void
    let openTasks: () -> Void
    let openLogs: () -> Void
    let openSettings: () -> Void

    @EnvironmentObject var theme: ThemeSettings
    @EnvironmentObject var instanceStore: InstanceStore
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var launcherSettings: LauncherSettings
    @EnvironmentObject var versionStore: VersionContentStore
    @EnvironmentObject var taskCenterStore: TaskCenterStore
    @EnvironmentObject var diagnosticsStore: DiagnosticsStore
    @EnvironmentObject var performanceCoachStore: PerformanceCoachStore
    @EnvironmentObject var packDoctorStore: PackDoctorStore
    static let fallbackInstanceID = UUID(uuidString: "B64F9A1D-6D55-4B8D-BA42-7F3CE8D92AA1") ?? UUID()
    @State var detailInstanceID: UUID?
    @State var launchLibrarySummary: CoreLaunchLibraryResponse?
    @State var pendingLaunchAfterRepairInstanceID: UUID?
    @State var pendingPerformancePackReview: PendingPerformancePackReview?
    @State var showPerformanceProfileReview = false

    var body: some View {
        Group {
            if let detailInstance {
                LaunchInstanceDetailPage(
                    instance: detailInstance,
                    viewModel: viewModel,
                    summary: summary(for: detailInstance),
                    statusTitle: launchStatusTitle(for: detailInstance),
                    statusStyle: statusStyle(for: detailInstance),
                    primaryTitle: primaryActionTitle(for: detailInstance),
                    primarySystemImage: primaryActionSystemImage(for: detailInstance),
                    primaryDisabled: primaryActionDisabled(for: detailInstance),
                    canCancel: viewModel.canCancelTask,
                    back: { detailInstanceID = nil },
                    launch: { selectAndLaunch(detailInstance.id) },
                    cancel: viewModel.cancelCurrentTask,
                    openContent: openResources,
                    openDiscover: openDiscover,
                    openSettings: openSettings,
                    openVersionManagement: openInstances,
                    backupSaves: { backupSaves(for: detailInstance) },
                    exportInstance: { exportInstance(for: detailInstance) },
                    toggleFavorite: {
                        instanceStore.setFavorite(detailInstance.id, isFavorite: !detailInstance.isFavorite)
                    },
                    updateAppearance: { instanceID, values in
                        updateInstance(instanceID) { instance in
                            instance.applyAppearance(values)
                        }
                    }
                )
            } else {
                LaunchLibraryHomeView(
                    hasInstalledInstances: !instanceStore.instances.isEmpty,
                    heroInstance: selectedInstance,
                    heroSummary: selectedLaunchSummary,
                    performanceSummary: selectedPerformanceSummary,
                    packDoctorReport: packDoctorStore.report,
                    packDoctorDiagnostics: packDoctorDiagnostics,
                    packDoctorStatusText: packDoctorStore.statusText,
                    packDoctorIsWorking: packDoctorStore.isWorking,
                    recentInstances: recentInstances,
                    recentInstalledInstances: recentInstalledInstances,
                    favoriteInstances: favoriteInstances,
                    selectedID: selectedInstance.id,
                    statusTitle: launchStatusTitle,
                    statusStyle: instanceStatus,
                    primaryTitle: primaryActionTitle,
                    primaryDisabled: primaryActionDisabled(for: selectedInstance),
                    canCancel: viewModel.canCancelTask,
                    summaryFor: summary(for:),
                    onPrimaryAction: performPrimaryAction,
                    onPackDoctorRefresh: { refreshSelectedPackDoctor(force: true) },
                    onPackDoctorPrimaryAction: performPackDoctorPrimaryAction,
                    onCancel: viewModel.cancelCurrentTask,
                    select: { instanceStore.selectedInstanceID = $0 },
                    openDetails: openDetail,
                    toggleFavorite: instanceStore.setFavorite,
                    hideRecent: { instanceStore.setHiddenFromRecent($0, hidden: true) },
                    openDiscover: openDiscover
                )
            }
        }
        .task(id: selectedInstance.id) {
            refreshSelectedVersionState()
            applyInstanceSettings()
            refreshSelectedJavaRuntime()
            refreshSelectedPerformanceSummary()
            refreshSelectedPackDoctor()
            versionStore.refreshAssets(for: instanceStore.selectedInstance)
        }
        .task(id: launchLibraryRefreshSignature) {
            await refreshLaunchLibrarySummary()
        }
        .onChange(of: selectedInstance.id) {
            applyInstanceSettings()
            refreshSelectedJavaRuntime()
            refreshSelectedPerformanceSummary()
            refreshSelectedPackDoctor()
            versionStore.refreshAssets(for: instanceStore.selectedInstance)
            refreshSelectedVersionState()
        }
        .onChange(of: selectedInstance.minecraftVersion) {
            applyInstanceSettings()
            refreshSelectedJavaRuntime()
            refreshSelectedPerformanceSummary()
            refreshSelectedPackDoctor()
            refreshSelectedVersionState()
        }
        .onChange(of: viewModel.currentTask) {
            continuePendingLaunchAfterRepairIfReady(viewModel.currentTask)
        }
        .sheet(item: $pendingPerformancePackReview) { review in
            InstallPlanReviewSheet(
                plan: review.plan.typedPlan,
                title: localizedString(theme.language, english: "Review performance pack", chinese: "确认性能包计划", italian: "Controlla pacchetto prestazioni", french: "Vérifier le pack performance", spanish: "Revisar paquete de rendimiento"),
                subtitle: review.plan.title,
                confirmTitle: localizedString(theme.language, english: "Install", chinese: "安装", italian: "Installa", french: "Installer", spanish: "Instalar"),
                repairTitle: review.plan.typedPlan.status == "blocked" || !review.plan.typedPlan.blockedReasons.isEmpty
                    ? localizedString(theme.language, english: "Open Discover", chinese: "打开获取", italian: "Apri scoperta", french: "Ouvrir Découvrir", spanish: "Abrir Descubrir")
                    : nil,
                onCancel: { pendingPerformancePackReview = nil },
                onRepair: {
                    pendingPerformancePackReview = nil
                    openDiscover()
                },
                onConfirm: {
                    pendingPerformancePackReview = nil
                    viewModel.installPerformancePack(review.request)
                }
            )
            .environmentObject(theme)
        }
        .sheet(isPresented: $showPerformanceProfileReview) {
            if let recommendation = performanceCoachStore.recommendation {
                PerformanceProfileReviewSheet(
                    recommendation: recommendation,
                    candidate: performanceCoachStore.candidate,
                    isWorking: performanceCoachStore.isWorking,
                    statusText: performanceCoachStore.statusText,
                    onGenerateCandidate: { baselineProfileId in
                        performanceCoachStore.generateCandidate(
                            request: CorePerformanceCandidateRequest(
                                gameDir: selectedInstance.gameDirectory,
                                baselineProfileId: baselineProfileId,
                                budgetLaunches: 1,
                                budgetChangedKnobs: 1
                            )
                        )
                    },
                    onApply: { profile in
                        applySelectedPerformanceProfile(profile)
                        performanceCoachStore.apply(profile: profile, gameDir: selectedInstance.gameDirectory)
                    },
                    onRollback: { rollbackRef in
                        performanceCoachStore.rollback(gameDir: selectedInstance.gameDirectory, rollbackRef: rollbackRef)
                    }
                )
            } else {
                ProgressView()
                    .padding(32)
                    .frame(width: 360)
            }
        }
    }
}
