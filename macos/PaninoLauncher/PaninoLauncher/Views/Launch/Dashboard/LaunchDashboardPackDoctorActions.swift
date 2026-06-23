extension LaunchDashboard {
    func refreshSelectedPackDoctor(force: Bool = false) {
        guard viewModel.coreState.isReady else { return }
        packDoctorStore.refresh(instance: selectedInstance, force: force)
    }

    func performPackDoctorPrimaryAction() {
        guard let actionKind = (packDoctorStore.report?.primaryDiagnostic ?? packDoctorDiagnostics.first)?.action.kind else {
            refreshSelectedPackDoctor(force: true)
            return
        }
        switch actionKind {
        case "switchLoader", "manualInstall":
            openDiscover()
        case "installJava":
            openSettings()
        case "repairInstance":
            performPrimaryAction()
        case "applyPerformanceRecommendation", "rollbackPerformanceProfile":
            if let reviewAction = reviewPerformanceProfileAction() {
                reviewAction()
            } else {
                openSettings()
            }
        default:
            openLogs()
        }
    }
}
