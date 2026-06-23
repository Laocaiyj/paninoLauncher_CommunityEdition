import SwiftUI

extension LaunchDashboard {
    func refreshDashboardForSelectedInstanceTask() {
        refreshSelectedVersionState()
        applyInstanceSettings()
        refreshSelectedJavaRuntime()
        refreshSelectedPerformanceSummary()
        refreshSelectedPackDoctor()
        versionStore.refreshAssets(for: instanceStore.selectedInstance)
    }

    func refreshDashboardAfterSelectedInstanceChange() {
        applyInstanceSettings()
        refreshSelectedJavaRuntime()
        refreshSelectedPerformanceSummary()
        refreshSelectedPackDoctor()
        versionStore.refreshAssets(for: instanceStore.selectedInstance)
        refreshSelectedVersionState()
    }

    func refreshDashboardAfterMinecraftVersionChange() {
        applyInstanceSettings()
        refreshSelectedJavaRuntime()
        refreshSelectedPerformanceSummary()
        refreshSelectedPackDoctor()
        refreshSelectedVersionState()
    }
}
