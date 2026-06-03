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

struct InstanceVersionWorkspace: View {
    @ObservedObject var viewModel: LauncherViewModel
    @Binding var instance: GameInstance
    let openResources: () -> Void
    let openDiscover: () -> Void

    @EnvironmentObject private var versionStore: VersionContentStore
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        InstanceEditorSection(
            title: localizedString(theme.language, english: "Selected Version Workspace", chinese: "已选版本工作区", italian: "Area versione selezionata", french: "Espace version sélectionnée", spanish: "Área de versión seleccionada"),
            systemImage: "rectangle.3.group"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Minecraft \(instance.minecraftVersion)")
                            .font(.headline)
                        Text(versionSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    StatusBadge(title: versionStateTitle, style: versionBadgeStyle)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                    workspaceMetric(
                        localizedString(theme.language, english: "Java", chinese: "Java", italian: "Java", french: "Java", spanish: "Java"),
                        selectedVersion?.javaRequirement ?? "--",
                        "cup.and.saucer"
                    )
                    workspaceMetric(
                        localizedString(theme.language, english: "Loader", chinese: "Loader", italian: "Loader", french: "Loader", spanish: "Loader"),
                        instance.loader?.title ?? "Vanilla",
                        "puzzlepiece.extension"
                    )
                    workspaceMetric(
                        localizedString(theme.language, english: "Resources", chinese: "资源", italian: "Risorse", french: "Ressources", spanish: "Recursos"),
                        "\(versionStore.managedAssets.count)",
                        "shippingbox"
                    )
                    workspaceMetric(
                        localizedString(theme.language, english: "Files", chinese: "文件", italian: "File", french: "Fichiers", spanish: "Archivos"),
                        selectedVersion?.clientJarState.localizedVersionState(theme.language) ?? localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando"),
                        "checkmark.seal"
                    )
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        versionActions
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        versionActions
                    }
                }

                if !versionStore.managedAssets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(localizedString(theme.language, english: "Local resources in this configuration", chinese: "当前游戏配置资源概况", italian: "Risorse locali in questa configurazione", french: "Ressources locales de cette configuration", spanish: "Recursos locales de esta configuración"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(versionStore.managedAssets.prefix(4)) { asset in
                            InstanceVersionResourcePreviewRow(asset: asset)
                        }
                    }
                }

                Text(resourceStatusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .task(id: instanceRefreshKey) {
            refreshSelectedVersion()
        }
    }

    @ViewBuilder
    private var versionActions: some View {
        GlassButton(systemImage: "arrow.down.circle", title: installActionTitle, prominent: selectedVersion?.isInstalled != true) {
            applyInstanceRuntime()
            viewModel.install(gameDir: instance.gameDirectory)
        }
        GlassButton(systemImage: "checkmark.seal", title: localizedString(theme.language, english: "Repair", chinese: "修复", italian: "Ripara", french: "Réparer", spanish: "Reparar")) {
            applyInstanceRuntime()
            viewModel.install(gameDir: instance.gameDirectory)
        }
        GlassButton(systemImage: "shippingbox", title: localizedString(theme.language, english: "Manage Resources", chinese: "管理资源", italian: "Gestisci risorse", french: "Gérer ressources", spanish: "Gestionar recursos"), action: openResources)
        GlassButton(systemImage: "magnifyingglass.circle", title: localizedString(theme.language, english: "Find Content", chinese: "查找内容", italian: "Trova contenuti", french: "Trouver contenu", spanish: "Buscar contenido"), action: openDiscover)
    }

    private var selectedVersion: MinecraftVersionInfo? {
        versionStore.versions.first { $0.id == instance.minecraftVersion }
    }

    private var instanceRefreshKey: String {
        "\(instance.id.uuidString)-\(instance.minecraftVersion)"
    }

    private var versionSummary: String {
        guard let selectedVersion else {
            return localizedString(theme.language, english: "Panino is loading this version from Core.", chinese: "Panino 正在从 Core 加载此版本。", italian: "Panino sta caricando questa versione dal Core.", french: "Panino charge cette version depuis Core.", spanish: "Panino está cargando esta versión desde Core.")
        }
        return [
            selectedVersion.kind.title(language: theme.language),
            selectedVersion.releasedAt,
            selectedVersion.downloadState.localizedVersionState(theme.language),
            selectedVersion.verificationState.localizedVersionState(theme.language)
        ].joined(separator: " · ")
    }

    private var versionStateTitle: String {
        guard let selectedVersion else {
            return localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando")
        }
        if selectedVersion.isInstalled {
            return localizedString(theme.language, english: "Installed", chinese: "已安装", italian: "Installata", french: "Installée", spanish: "Instalada")
        }
        return localizedString(theme.language, english: "Needs Install", chinese: "需要安装", italian: "Da installare", french: "À installer", spanish: "Por instalar")
    }

    private var versionBadgeStyle: StatusBadge.Style {
        guard let selectedVersion else { return .running }
        return selectedVersion.isInstalled ? .success : .warning
    }

    private var installActionTitle: String {
        if selectedVersion?.isInstalled == true {
            return localizedString(theme.language, english: "Reinstall", chinese: "重新安装", italian: "Reinstalla", french: "Réinstaller", spanish: "Reinstalar")
        }
        return localizedString(theme.language, english: "Install", chinese: "安装", italian: "Installa", french: "Installer", spanish: "Instalar")
    }

    private var resourceStatusLine: String {
        let resourceTitle = versionStore.selectedAssetKind.title(language: theme.language)
        return localizedString(
            theme.language,
            english: "\(versionStore.managedAssets.count) \(resourceTitle) scanned for this configuration. \(versionStore.fileStatus)",
            chinese: "已为当前游戏配置扫描 \(versionStore.managedAssets.count) 个\(resourceTitle)。\(versionStore.fileStatus)",
            italian: "\(versionStore.managedAssets.count) \(resourceTitle) analizzati per questa istanza. \(versionStore.fileStatus)",
            french: "\(versionStore.managedAssets.count) \(resourceTitle) analysés pour cette instance. \(versionStore.fileStatus)",
            spanish: "\(versionStore.managedAssets.count) \(resourceTitle) escaneados para esta instancia. \(versionStore.fileStatus)"
        )
    }

    private func workspaceMetric(_ title: String, _ value: String, _ systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }

    private func applyInstanceRuntime() {
        viewModel.version = instance.minecraftVersion
        let usesGlobalRuntime = instance.javaPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        viewModel.memoryMb = usesGlobalRuntime ? SettingsStore.memoryMb : instance.memoryMb
        viewModel.javaPath = usesGlobalRuntime ? SettingsStore.javaPath : instance.javaPath
        if let loader = instance.loader {
            versionStore.selectedLoader = loader
        }
    }

    private func refreshSelectedVersion() {
        configureVersionCoreBackend()
        versionStore.selectedVersionID = instance.minecraftVersion
        versionStore.refreshAssets(for: instance)
    }

    private func configureVersionCoreBackend() {
        versionStore.configure(
            coreBackend: VersionContentCoreBackend(
                minecraftVersions: {
                    try await viewModel.minecraftVersions()
                },
                minecraftInstallStatus: { versionIds, gameDirs in
                    try await viewModel.minecraftInstallStatus(versionIds: versionIds, gameDirs: gameDirs)
                },
                installedMinecraftInstances: { versionIds, gameDirs in
                    try await viewModel.installedMinecraftInstances(versionIds: versionIds, gameDirs: gameDirs)
                },
                minecraftPackage: { version in
                    try await viewModel.minecraftPackage(for: version)
                },
                localResources: { gameDir, kind, loader in
                    try await viewModel.localResources(gameDir: gameDir, kind: kind, loader: loader)
                },
                toggleLocalResource: { path in
                    try await viewModel.toggleLocalResource(path: path)
                },
                deleteLocalResource: { path in
                    try await viewModel.deleteLocalResource(path: path)
                },
                importLocalResource: { sourcePath, gameDir, kind in
                    try await viewModel.importLocalResource(sourcePath: sourcePath, gameDir: gameDir, kind: kind)
                },
                cleanMinecraftVersion: { version, gameDir in
                    try await viewModel.cleanMinecraftVersion(version: version, gameDir: gameDir)
                },
                mutateMinecraftVersionStorage: { version, gameDir, action in
                    try await viewModel.mutateMinecraftVersionStorage(version: version, gameDir: gameDir, action: action)
                }
            )
        )
    }
}

struct InstanceVersionResourcePreviewRow: View {
    let asset: ManagedAsset

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: asset.isEnabled ? "checkmark.circle.fill" : "pause.circle")
                .foregroundStyle(asset.isEnabled ? .green : .secondary)
                .frame(width: 18)
            Text(asset.metadata.displayName ?? asset.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            if let source = asset.source {
                Text(source)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct VersionPickerRow: View {
    let version: MinecraftVersionInfo
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(version.id)
                        .font(.callout.weight(.semibold))
                    Text("\(version.kind.title(language: theme.language)) · \(version.javaRequirement)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if version.isUsedByInstance {
                    StatusBadge(title: localizedString(theme.language, english: "Used by Config", chinese: "配置使用中", italian: "Usata", french: "Utilisée", spanish: "En uso"), style: .success)
                } else if version.isInstalled {
                    StatusBadge(title: localizedString(theme.language, english: "Installed", chinese: "已安装", italian: "Installata", french: "Installée", spanish: "Instalada"), style: .success)
                }
            }
            .padding(9)
            .background(
                isSelected ? theme.semanticSelectionColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor).opacity(0.28),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.65) : Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

func uniqueVersions(_ versions: [MinecraftVersionInfo]) -> [MinecraftVersionInfo] {
    var seen = Set<String>()
    return versions.filter { version in
        seen.insert(version.id).inserted
    }
}
