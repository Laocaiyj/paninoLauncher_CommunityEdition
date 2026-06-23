import Foundation

extension LaunchDashboard {
    func currentTaskApplies(to instance: GameInstance) -> Bool {
        guard let task = viewModel.currentTask else { return false }
        guard task.state.isActive || task.state == .failed else { return false }
        guard let taskGameDir = task.gameDir?.trimmingCharacters(in: .whitespacesAndNewlines),
              !taskGameDir.isEmpty else {
            return true
        }
        let instanceGameDir = instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instanceGameDir.isEmpty else { return false }
        return LauncherViewModel.sameFilePath(taskGameDir, instanceGameDir)
    }
}
