import SwiftUI

extension OnlineContentDiscoveryPage {
    var minecraftContent: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            if let selectedMinecraftVersion {
                MinecraftVersionInstallDetailPage(
                    version: selectedMinecraftVersion,
                    instances: instanceStore.instances,
                    target: $minecraftInstallTarget,
                    instanceName: $minecraftInstanceName,
                    loader: $selectedMinecraftLoader,
                    loaderVersion: $selectedMinecraftLoaderVersion,
                    shaderLoader: $selectedShaderLoader,
                    shaderLoaderVersion: $selectedShaderLoaderVersion,
                    loaderOptions: minecraftLoaderOptions,
                    shaderReleases: minecraftShaderReleases,
                    versionOptionsStatus: minecraftVersionOptionsStatus,
                    confirmInstall: $confirmMinecraftInstall,
                    preflight: minecraftInstallPreflight,
                    preflightStatus: minecraftInstallPreflightStatus,
                    choicePreflights: minecraftInstallChoicePreflights,
                    lastInstallFailure: viewModel.lastTaskFailure,
                    back: {
                        self.selectedMinecraftVersion = nil
                    },
                    install: installSelectedMinecraftVersion,
                    openTasks: openTasks,
                    exportDiagnostics: exportMinecraftInstallDiagnostics,
                    openInstanceDirectory: openMinecraftInstallDirectory,
                    downloadJava: downloadMinecraftInstallJava
                )
            } else {
                MinecraftVersionBrowsePage(
                    versions: versionStore.versions,
                    latestReleaseID: versionStore.latestReleaseID,
                    latestSnapshotID: versionStore.latestSnapshotID,
                    status: versionStore.versionStatus,
                    searchText: $minecraftSearchText,
                    group: $minecraftBrowseGroup,
                    page: $minecraftPage,
                    refresh: refreshMinecraftVersions,
                    select: openMinecraftInstallDetail
                )
            }
        }
    }
}
