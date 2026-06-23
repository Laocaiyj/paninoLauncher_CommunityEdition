import Foundation

extension LaunchDashboard {
    func refreshSelectedPerformanceSummary() {
        let instance = selectedInstance
        let request = CoreEnvironmentReportRequest(
            gameDir: instance.gameDirectory,
            version: instance.contentMinecraftVersion,
            loader: instance.loader?.rawValue,
            loaderVersion: instance.loaderVersion,
            memoryMb: instance.memoryMb,
            memoryPolicy: instance.memoryPolicy.rawValue,
            jvmProfile: instance.jvmProfile.rawValue,
            customMemoryMb: instance.memoryPolicy == .custom ? (instance.customMemoryMb ?? instance.memoryMb) : instance.customMemoryMb,
            customJvmArgs: instance.customJvmArguments,
            modCount: versionStore.managedAssets.count,
            graphicsProfile: instance.graphicsProfile.rawValue
        )
        Task {
            do {
                let report = try await viewModel.environmentReport(request)
                await MainActor.run {
                    guard selectedInstance.id == instance.id else { return }
                    diagnosticsStore.lastEnvironmentReport = report
                }
            } catch {
                await MainActor.run {
                    guard selectedInstance.id == instance.id else { return }
                    diagnosticsStore.lastEnvironmentReport = nil
                }
            }
        }
    }
}
