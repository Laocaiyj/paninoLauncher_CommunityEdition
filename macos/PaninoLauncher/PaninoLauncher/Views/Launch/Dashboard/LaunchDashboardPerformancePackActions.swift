import AppKit

extension LaunchDashboard {
    func installPerformancePackAction() -> (() -> Void)? {
        let instance = selectedInstance
        guard let loader = instance.loader?.rawValue,
              !instance.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return openDiscover
        }
        let request = CorePerformancePackInstallRequest(
            gameDir: instance.gameDirectory,
            minecraftVersion: instance.contentMinecraftVersion,
            loader: loader,
            includeOptional: false,
            download: LauncherSettings.storedDownloadRuntimeOptions()
        )
        return {
            Task {
                do {
                    let plan = try await viewModel.performancePackPlan(request)
                    await MainActor.run {
                        pendingPerformancePackReview = PendingPerformancePackReview(plan: plan, request: request)
                    }
                } catch {
                    await MainActor.run {
                        showPerformancePackPlanError(error)
                    }
                }
            }
        }
    }

    @MainActor
    private func showPerformancePackPlanError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localizedString(theme.language, english: "Could not prepare performance pack", chinese: "无法准备性能包", italian: "Impossibile preparare il pacchetto", french: "Impossible de préparer le pack", spanish: "No se pudo preparar el paquete")
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: localizedString(theme.language, english: "OK", chinese: "知道了", italian: "OK", french: "OK", spanish: "OK"))
        alert.runModal()
    }
}
