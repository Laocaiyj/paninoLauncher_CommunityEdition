import SwiftUI

extension LaunchDashboard {
    func performancePackReviewSheet(for review: PendingPerformancePackReview) -> some View {
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

    @ViewBuilder
    var performanceProfileReviewSheet: some View {
        if let recommendation = performanceCoachStore.recommendation {
            PerformanceProfileReviewSheet(
                recommendation: recommendation,
                candidate: performanceCoachStore.candidate,
                isWorking: performanceCoachStore.isWorking,
                statusText: performanceCoachStore.statusText,
                onGenerateCandidate: generatePerformanceProfileCandidate,
                onApply: applyAndPersistPerformanceProfile,
                onRollback: rollbackPerformanceProfile
            )
        } else {
            ProgressView()
                .padding(32)
                .frame(width: 360)
        }
    }

    private func generatePerformanceProfileCandidate(_ baselineProfileId: String?) {
        performanceCoachStore.generateCandidate(
            request: CorePerformanceCandidateRequest(
                gameDir: selectedInstance.gameDirectory,
                baselineProfileId: baselineProfileId,
                budgetLaunches: 1,
                budgetChangedKnobs: 1
            )
        )
    }

    private func applyAndPersistPerformanceProfile(_ profile: CorePerformanceProfile) {
        applySelectedPerformanceProfile(profile)
        performanceCoachStore.apply(profile: profile, gameDir: selectedInstance.gameDirectory)
    }

    private func rollbackPerformanceProfile(_ rollbackRef: String) {
        performanceCoachStore.rollback(gameDir: selectedInstance.gameDirectory, rollbackRef: rollbackRef)
    }
}
