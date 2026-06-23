import Foundation

extension OnlineContentDiscoveryPage {
    func handleDiscoveryTask() {
        configureCoreBackend()
        configureVersionCoreBackend()
        syncManagedKind()
        versionStore.refreshAssets(for: instanceStore.selectedInstance)
        if !versionStore.hasRemoteVersions {
            refreshMinecraftVersions()
        }
        if selectedSection != .minecraft, projects.isEmpty {
            search(clearExisting: false)
        }
    }

    func configureCoreBackend() {
        onlineContentStore.configure(
            coreBackend: OnlineContentCoreBackend(
                search: { query, source, apiKey in
                    try await viewModel.searchContent(query, source: source, curseForgeAPIKey: apiKey)
                },
                project: { projectID, source, query, apiKey in
                    try await viewModel.contentProject(id: projectID, source: source, query: query, curseForgeAPIKey: apiKey)
                },
                minecraftVersions: {
                    try await viewModel.minecraftVersions()
                },
                minecraftPackage: { version in
                    try await viewModel.minecraftPackage(for: version)
                },
                loaderMetadata: { minecraftVersion in
                    try await viewModel.loaderMetadata(for: minecraftVersion)
                }
            )
        )
    }

    func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: .live(viewModel: viewModel)
        )
    }

    func refreshMinecraftVersions() {
        configureVersionCoreBackend()
        versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
    }
}
