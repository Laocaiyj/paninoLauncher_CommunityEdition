import Foundation

extension ResourcesManagementPage {
    func toggleSelection(_ id: String) {
        if selectedAssetIDs.contains(id) {
            selectedAssetIDs.remove(id)
        } else {
            selectedAssetIDs.insert(id)
        }
    }

    func syncSelectedLoader() {
        if let loader = instanceStore.selectedInstance?.loader {
            versionStore.selectedLoader = loader
        }
    }

    func prepareContentUpdatePlan() {
        guard let instance = instanceStore.selectedInstance else { return }
        let assets = selectedAssets
        guard !assets.isEmpty else { return }
        updatePlanStatus = localizedString(theme.language, english: "Checking update plan...", chinese: "正在检查更新计划...", italian: "Controllo aggiornamenti...", french: "Vérification du plan...", spanish: "Revisando actualización...")

        let resources = assets.map { asset in
            CoreContentUpdatePlanResource(
                projectId: nil,
                projectTitle: asset.metadata.displayName ?? asset.name,
                currentReleaseId: asset.metadata.version ?? "local",
                currentFileName: asset.name,
                currentSha1: nil,
                currentTargetPath: asset.url.path,
                remoteReleaseId: "unresolved",
                remoteFileName: asset.name,
                remoteUrl: nil,
                remoteSha1: nil,
                remoteSize: nil,
                selected: true,
                dependencies: []
            )
        }
        let request = CoreContentUpdatePlanRequest(
            mode: "updateSelected",
            gameDir: instance.gameDirectory,
            source: "local",
            resources: resources
        )

        Task {
            do {
                let response = try await viewModel.contentUpdatePlan(request)
                await MainActor.run {
                    updatePlanStatus = response.blockedReasons.isEmpty ? "" : response.blockedReasons.joined(separator: ", ")
                    pendingUpdateReview = PendingContentUpdateReview(response: response)
                }
            } catch {
                await MainActor.run {
                    updatePlanStatus = error.localizedDescription
                }
            }
        }
    }

    func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: .live(viewModel: viewModel)
        )
    }
}
