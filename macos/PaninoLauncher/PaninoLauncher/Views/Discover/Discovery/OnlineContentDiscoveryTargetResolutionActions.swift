import Foundation

extension OnlineContentDiscoveryPage {
    func recommendedReleaseID() -> String? {
        guard let selectedContentMinecraftVersionID else { return nil }
        return onlineContentStore.selectedReleases.first { $0.gameVersions.contains(selectedContentMinecraftVersionID) }?.id
    }

    func resolveTargetsForSelection() {
        targetResolutionTask?.cancel()
        targetResolution = nil
        targetResolutionFailure = nil
        selectedContentTargetID = nil

        guard let selectedProject,
              let selectedRelease,
              let managedKind = selectedProject.projectType.managedAssetKind else { return }

        let request = CoreContentResolveTargetsRequest(
            projectType: selectedProject.projectType.rawValue,
            projectTitle: selectedProject.title,
            releaseId: selectedRelease.id,
            targetSubdir: managedKind.folderName,
            gameVersions: selectedRelease.gameVersions,
            loaders: selectedRelease.loaders.map(\.rawValue),
            instances: instanceStore.instances
                .filter { !$0.gameDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { instance in
                    CoreContentTargetInstance(
                        instanceId: instance.id.uuidString,
                        name: instance.name,
                        gameDir: instance.gameDirectory,
                        minecraftVersion: instance.contentMinecraftVersion,
                        loader: instance.loader?.rawValue
                    )
                }
        )

        targetResolutionTask = Task {
            do {
                let response = try await viewModel.resolveContentTargets(request)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    targetResolution = response
                    targetResolutionFailure = nil
                    selectedContentTargetID = preferredContentTargetID(in: response, release: selectedRelease)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    targetResolution = nil
                    targetResolutionFailure = error.localizedDescription
                    selectedContentTargetID = nil
                }
            }
        }
    }

    func selectedContentTarget(release: OnlineRelease) -> CoreContentTargetCandidate? {
        guard let selectedContentTargetID else { return nil }
        return targetResolution?.candidates.first {
            $0.id == selectedContentTargetID && isContentTargetVersionMatched($0, release: release)
        }
    }

    func preferredContentTargetID(in response: CoreContentResolveTargetsResponse, release: OnlineRelease) -> String? {
        if let selectedContentTargetID,
           response.candidates.contains(where: { $0.id == selectedContentTargetID && isContentTargetVersionMatched($0, release: release) }) {
            return selectedContentTargetID
        }
        if let recommended = response.recommended,
           isContentTargetVersionMatched(recommended, release: release) {
            return recommended.id
        }
        return response.candidates.first { isContentTargetVersionMatched($0, release: release) }?.id
    }

    func isContentTargetVersionMatched(_ target: CoreContentTargetCandidate, release: OnlineRelease) -> Bool {
        let hasVersionMismatch = target.blockedReasons.contains { reason in
            reason.localizedCaseInsensitiveContains("minecraft_version_mismatch")
        }
        guard !hasVersionMismatch else { return false }
        return release.gameVersions.isEmpty || release.gameVersions.contains(target.minecraftVersion)
    }
}
