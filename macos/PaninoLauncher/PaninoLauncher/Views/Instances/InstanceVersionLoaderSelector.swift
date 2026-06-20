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
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedString(theme.language, english: "Minecraft", chinese: "Minecraft", italian: "Minecraft", french: "Minecraft", spanish: "Minecraft"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(instance.minecraftVersion)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(width: 180, alignment: .leading)
                        .frame(minHeight: PaninoTokens.Layout.controlMinSize)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                    StatusBadge(title: versionStatusTitle, style: selectedVersion?.isInstalled == true ? .success : .download)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Loader")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Loader", selection: loaderSelection) {
                        Text("Vanilla").tag(nil as LoaderKind?)
                        ForEach(availableLoaderOptions) { option in
                            Text(option.kind.title).tag(Optional(option.kind))
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 430)
                    .disabled(isLoadingLoaders || availableLoaderOptions.isEmpty)
                    if !unavailableLoaderOptions.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(unavailableLoaderOptions) { option in
                                Text(option.kind.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: Capsule())
                                    .help(option.reason ?? "Core marked this Loader unavailable.")
                            }
                        }
                    }
                    Text(loaderCompatibilityMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            FullWidthDisclosureGroup(isExpanded: $showMoreVersions) {
                VStack(alignment: .leading, spacing: 8) {
                    PaninoTextInput("Search version", text: $searchText)
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(visibleVersions) { version in
                                VersionPickerRow(
                                    version: version,
                                    isSelected: version.id == instance.minecraftVersion,
                                    action: selectVersion(version)
                                )
                            }
                        }
                    }
                    .frame(height: 220)
                    .clipped()
                }
                .padding(.top, 8)
            } label: {
                Text(localizedString(theme.language, english: "Browse more versions", chinese: "浏览更多版本", italian: "Sfoglia altre versioni", french: "Parcourir plus de versions", spanish: "Ver más versiones"))
                    .font(.caption.weight(.semibold))
            }
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
