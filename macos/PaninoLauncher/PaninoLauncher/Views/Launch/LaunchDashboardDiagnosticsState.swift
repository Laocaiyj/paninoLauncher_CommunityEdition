import Foundation

extension LaunchDashboard {
    var selectedPerformanceSummary: CorePerformanceSummary? {
        guard let report = diagnosticsStore.lastEnvironmentReport,
              let summary = report.performanceSummary else {
            return nil
        }
        if let reportVersion = report.context?.minecraftVersion,
           reportVersion != selectedInstance.contentMinecraftVersion {
            return nil
        }
        if let reportGameDir = report.context?.gameDir,
           !selectedInstance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           reportGameDir != selectedInstance.gameDirectory {
            return nil
        }
        return summary
    }

    var packDoctorDiagnostics: [CoreDiagnostic] {
        guard let task = viewModel.currentTask, currentTaskApplies(to: selectedInstance) else {
            return packDoctorStore.report?.allDiagnostics ?? []
        }
        let taskDiagnostics = task.diagnostics.isEmpty ? task.diagnostic.map { [$0] } ?? [] : task.diagnostics
        return taskDiagnostics + (packDoctorStore.report?.allDiagnostics ?? [])
    }
}
