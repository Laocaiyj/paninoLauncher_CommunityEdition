import SwiftUI

struct InstanceVersionLoaderSelector: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance

    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var theme: ThemeSettings
    @State private var searchText = ""
    @State private var showMoreVersions = false
    @State private var loaderOptions: [LoaderCompatibilityOption] = []
    @State private var loaderStatus = "Loader compatibility is loaded by Core."
    @State private var isLoadingLoaders = false

    var body: some View {
        InstanceEditorSection(
            title: localizedString(theme.language, english: "Version & Loader", chinese: "版本与 Loader", italian: "Versione e loader", french: "Version et loader", spanish: "Versión y loader"),
            systemImage: "cube.box"
        ) {
            HStack(alignment: .top, spacing: 14) {
                InstanceVersionSummaryBlock(
                    minecraftVersion: instance.minecraftVersion,
                    statusTitle: versionStatusTitle,
                    isInstalled: selectedVersion?.isInstalled == true
                )

                LoaderFamilyPickerBlock(
                    selection: loaderSelection,
                    availableOptions: availableLoaderOptions,
                    unavailableOptions: unavailableLoaderOptions,
                    isLoading: isLoadingLoaders,
                    message: loaderCompatibilityMessage
                )
            }

            MinecraftVersionBrowser(
                searchText: $searchText,
                isExpanded: $showMoreVersions,
                versions: visibleVersions,
                selectedVersionID: instance.minecraftVersion,
                selectVersion: selectVersion
            )
        }
        .task(id: instance.minecraftVersion) {
            await refreshLoaderCompatibility()
        }
    }

    private var loaderSelection: Binding<LoaderKind?> {
        Binding(
            get: { instance.loader },
            set: { newLoader in
                guard let newLoader else {
                    instance.loader = nil
                    instance.loaderVersion = nil
                    return
                }
                guard let option = loaderOptions.first(where: { $0.kind == newLoader && $0.isAvailable }) else {
                    return
                }
                instance.loader = option.kind
                instance.loaderVersion = option.recommendedVersion
            }
        )
    }

    private var availableLoaderOptions: [LoaderCompatibilityOption] {
        loaderOptions.filter(\.isAvailable)
    }

    private var unavailableLoaderOptions: [LoaderCompatibilityOption] {
        loaderOptions.filter { !$0.isAvailable }
    }

    private var visibleVersions: [MinecraftVersionInfo] {
        let source: [MinecraftVersionInfo]
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            source = showMoreVersions ? versionStore.versions.filter { $0.kind == .release } : recommendedVersions
        } else {
            source = versionStore.versions.filter { $0.id.localizedCaseInsensitiveContains(searchText) }
        }
        return applyUsagePriority(source).prefix(showMoreVersions || !searchText.isEmpty ? 80 : 8).map { $0 }
    }

    private var recommendedVersions: [MinecraftVersionInfo] {
        uniqueVersions(
            versionStore.versions.filter { $0.id == instance.minecraftVersion }
                + latestReleaseVersions
                + versionStore.versions.filter(\.isInstalled)
                + versionStore.versions.filter(\.isUsedByInstance)
                + Array(versionStore.versions.filter { $0.kind == .release }.prefix(6))
        )
    }

    private var latestReleaseVersions: [MinecraftVersionInfo] {
        guard let latestReleaseID = versionStore.latestReleaseID else { return [] }
        return versionStore.versions.filter { $0.id == latestReleaseID }
    }

    private var selectedVersion: MinecraftVersionInfo? {
        versionStore.versions.first { $0.id == instance.minecraftVersion }
    }

    private var versionStatusTitle: String {
        guard let selectedVersion else { return instance.minecraftVersion }
        if selectedVersion.isUsedByInstance {
            return localizedString(theme.language, english: "Used by current configuration", chinese: "当前配置正在使用", italian: "Usata dalla configurazione", french: "Utilisée par la configuration", spanish: "Usada por la configuración")
        }
        if selectedVersion.isInstalled {
            return localizedString(theme.language, english: "Installed", chinese: "已安装", italian: "Installata", french: "Installée", spanish: "Instalada")
        }
        return selectedVersion.javaRequirement
    }

    private var loaderCompatibilityMessage: String {
        if isLoadingLoaders {
            return "Loading Loader compatibility from Core..."
        }
        if loaderOptions.isEmpty {
            return loaderStatus
        }
        let available = availableLoaderOptions.map(\.kind.title).joined(separator: ", ")
        return available.isEmpty ? loaderStatus : "Compatible Loaders from Core: \(available)."
    }

    @MainActor
    private func refreshLoaderCompatibility() async {
        isLoadingLoaders = true
        do {
            let response = try await viewModel.loaderCompatibility(for: instance.minecraftVersion)
            loaderOptions = LoaderCompatibilityOption.options(from: response)
            if let loader = instance.loader,
               !loaderOptions.contains(where: { $0.kind == loader && $0.isAvailable }) {
                instance.loader = nil
                instance.loaderVersion = nil
            }
            if let loader = instance.loader,
               instance.loaderVersion == nil,
               let option = loaderOptions.first(where: { $0.kind == loader }) {
                instance.loaderVersion = option.recommendedVersion
            }
            loaderStatus = "Core returned \(availableLoaderOptions.count) compatible Loader families."
        } catch {
            loaderOptions = []
            loaderStatus = "Core Loader compatibility failed: \(error.localizedDescription)"
        }
        isLoadingLoaders = false
    }

    private func selectVersion(_ version: MinecraftVersionInfo) -> () -> Void {
        {
            versionStore.selectedVersionID = version.id
        }
    }

    private func applyUsagePriority(_ versions: [MinecraftVersionInfo]) -> [MinecraftVersionInfo] {
        versions.sorted {
            if $0.id == instance.minecraftVersion { return true }
            if $1.id == instance.minecraftVersion { return false }
            if $0.isInstalled != $1.isInstalled { return $0.isInstalled && !$1.isInstalled }
            if $0.isUsedByInstance != $1.isUsedByInstance { return $0.isUsedByInstance && !$1.isUsedByInstance }
            return $0.id.localizedStandardCompare($1.id) == .orderedDescending
        }
    }
}
