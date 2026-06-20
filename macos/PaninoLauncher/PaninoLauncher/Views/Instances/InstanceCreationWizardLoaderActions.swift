import Foundation

extension InstanceCreationWizard {
    @MainActor
    func refreshLoaderOptions() async {
        guard draft.source == "Mod Configuration" else {
            loaderOptions = LoaderKind.allCases.map {
                LoaderCompatibilityOption(kind: $0, recommendedVersion: nil, versions: [], isAvailable: false, reason: nil)
            }
            loaderStatus = "Loader metadata not needed for this configuration."
            return
        }
        isLoadingLoaders = true
        do {
            let response = try await loadLoaderCompatibility(draft.minecraftVersion)
            loaderOptions = LoaderCompatibilityOption.options(from: response)
            let available = loaderOptions.filter(\.isAvailable)
            if let current = draft.loader, !available.contains(where: { $0.kind == current }) {
                draft.loader = available.first?.kind
            } else if draft.loader == nil {
                draft.loader = available.first(where: { $0.kind == .fabric })?.kind ?? available.first?.kind
            }
            if let option = selectedLoaderOption {
                draft.loaderVersion = option.recommendedVersion
            }
            loaderStatus = available.isEmpty
                ? "Core did not report any compatible Loader for \(draft.minecraftVersion)."
                : "Loaded \(available.count) compatible loader families from Core."
        } catch {
            loaderOptions = []
            draft.loader = nil
            draft.loaderVersion = nil
            loaderStatus = "Core loader compatibility failed: \(error.localizedDescription)"
        }
        isLoadingLoaders = false
    }
}
