import SwiftUI

struct VersionsAndModsPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var instanceStore: InstanceStore
    @EnvironmentObject private var launcherSettings: LauncherSettings
    @EnvironmentObject private var theme: ThemeSettings
    @State private var versionSearchText = ""
    @State private var showReleaseVersions = false
    @State private var showSnapshots = false
    @State private var showHistorical = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            MinecraftVersionBrowserPanel(
                searchText: $versionSearchText,
                usageFilter: $versionStore.versionUsageFilter,
                showReleaseVersions: $showReleaseVersions,
                showSnapshots: $showSnapshots,
                showHistorical: $showHistorical,
                recommendedVersions: recommendedVersions,
                releaseVersions: filteredVersions(kind: .release),
                snapshotVersions: filteredVersions(kind: .snapshot),
                historicalVersions: filteredVersions(kind: .oldBeta) + filteredVersions(kind: .oldAlpha),
                selectedVersion: versionStore.selectedVersion,
                versionStatus: versionStore.versionStatus,
                refresh: {
                    configureVersionCoreBackend()
                    versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
                },
                selectVersion: selectVersion,
                installSelected: installVersion,
                repairSelected: installVersion,
                cleanUnused: { version in
                    versionStore.cleanUnusedVersion(version, instances: instanceStore.instances, settings: launcherSettings)
                }
            )

            LoaderPlanPanel(
                selectedLoader: $versionStore.selectedLoader,
                compatibleLoaderKinds: compatibleLoaderKinds,
                compatibilityMessage: loaderCompatibilityMessage
            )
        }
        .task {
            configureVersionCoreBackend()
            versionStore.refreshMinecraftVersions(instances: instanceStore.instances, settings: launcherSettings)
        }
    }

    private var recommendedVersions: [MinecraftVersionInfo] {
        uniqueVersions(
            currentInstanceVersions
                + latestReleaseVersions
                + versionStore.versions.filter(\.isInstalled)
                + versionStore.versions.filter(\.isUsedByInstance)
                + Array(versionStore.versions.filter { $0.kind == .release }.prefix(8))
        )
        .filter(matchesSearchAndUsage)
    }

    private var currentInstanceVersions: [MinecraftVersionInfo] {
        guard let currentVersion = instanceStore.selectedInstance?.minecraftVersion else { return [] }
        return versionStore.versions.filter { $0.id == currentVersion }
    }

    private var latestReleaseVersions: [MinecraftVersionInfo] {
        guard let latestReleaseID = versionStore.latestReleaseID else { return [] }
        return versionStore.versions.filter { $0.id == latestReleaseID }
    }

    private var compatibleLoaderKinds: [LoaderKind] {
        guard let selectedVersion = versionStore.selectedVersion else { return LoaderKind.allCases }
        return selectedVersion.kind == .oldAlpha || selectedVersion.kind == .oldBeta ? [] : LoaderKind.allCases
    }

    private var loaderCompatibilityMessage: String {
        guard let selectedVersion = versionStore.selectedVersion else {
            return AppText.loaderPlanDescription.localized(theme.language)
        }
        if selectedVersion.kind == .oldAlpha || selectedVersion.kind == .oldBeta {
            return localizedString(theme.language, english: "Historical versions default to Vanilla because modern loader metadata is not reliable.", chinese: "历史版本默认使用原版，因为现代 Loader 元数据不可可靠判断。", italian: "Le versioni storiche usano Vanilla perché i metadata loader non sono affidabili.", french: "Les versions historiques utilisent Vanilla car les métadonnées des loaders ne sont pas fiables.", spanish: "Las versiones históricas usan Vanilla porque los metadatos de loaders no son fiables.")
        }
        return AppText.loaderPlanDescription.localized(theme.language)
    }

    private func filteredVersions(kind: MinecraftVersionKind) -> [MinecraftVersionInfo] {
        versionStore.versions
            .filter { $0.kind == kind }
            .filter(matchesSearchAndUsage)
            .prefix(120)
            .map { $0 }
    }

    private func matchesSearchAndUsage(_ version: MinecraftVersionInfo) -> Bool {
        let query = versionSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty || version.id.localizedCaseInsensitiveContains(query) else { return false }
        switch versionStore.versionUsageFilter {
        case .all:
            return true
        case .installed:
            return version.isInstalled
        case .usedByInstance:
            return version.isUsedByInstance
        }
    }

    private func selectVersion(_ version: MinecraftVersionInfo) {
        versionStore.selectedVersionID = version.id
        versionStore.loadDetails(
            for: version,
            instances: instanceStore.instances,
            settings: launcherSettings
        )
    }

    private func installVersion(_ version: MinecraftVersionInfo) {
        viewModel.version = version.id
        viewModel.install(gameDir: instanceStore.selectedInstance?.gameDirectory)
    }

    private func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: .live(viewModel: viewModel)
        )
    }
}
