import SwiftUI

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
                InstanceVersionWorkspaceHeader(
                    minecraftVersion: instance.minecraftVersion,
                    summary: versionSummary,
                    stateTitle: versionStateTitle,
                    badgeStyle: versionBadgeStyle
                )

                InstanceVersionWorkspaceMetricGrid(
                    javaRequirement: selectedVersion?.javaRequirement ?? "--",
                    loaderTitle: instance.loader?.title ?? "Vanilla",
                    resourceCount: versionStore.managedAssets.count,
                    fileStateTitle: versionFileStateTitle
                )

                InstanceVersionWorkspaceActions(
                    installTitle: installActionTitle,
                    installProminent: selectedVersion?.isInstalled != true,
                    install: installSelectedVersion,
                    repair: repairSelectedVersion,
                    manageResources: openResources,
                    findContent: openDiscover
                )

                InstanceVersionResourceSummary(assets: Array(versionStore.managedAssets.prefix(4)))

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

    private var versionFileStateTitle: String {
        selectedVersion?.clientJarState.localizedVersionState(theme.language)
            ?? localizedString(theme.language, english: "Loading", chinese: "加载中", italian: "Caricamento", french: "Chargement", spanish: "Cargando")
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

    private func installSelectedVersion() {
        installOrRepairSelectedVersion()
    }

    private func repairSelectedVersion() {
        installOrRepairSelectedVersion()
    }

    private func installOrRepairSelectedVersion() {
        applyInstanceRuntime()
        viewModel.install(gameDir: instance.gameDirectory)
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
            coreBackend: .live(viewModel: viewModel)
        )
    }
}
