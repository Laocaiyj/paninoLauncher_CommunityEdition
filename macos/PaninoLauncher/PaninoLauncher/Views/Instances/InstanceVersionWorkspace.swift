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
            coreBackend: .live(viewModel: viewModel)
        )
    }
}
