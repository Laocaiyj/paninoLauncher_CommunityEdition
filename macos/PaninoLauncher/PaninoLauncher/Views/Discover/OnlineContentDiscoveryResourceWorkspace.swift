import AppKit
import SwiftUI

extension OnlineContentDiscoveryPage {
    var minecraftContent: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            if let selectedMinecraftVersion {
                MinecraftVersionInstallDetailPage(
                    version: selectedMinecraftVersion,
                    instances: instanceStore.instances,
                    selectedInstance: instanceStore.selectedInstance,
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

    var resourcesContent: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            if selectedSource == .curseForge && !onlineContentStore.hasCurseForgeAPIKey() {
                CurseForgeAPIKeyInlineEditor(
                    apiKey: $curseForgeAPIKey,
                    openSettings: openDownloadSettings,
                    onSaved: refreshOnlineContent
                )
            }

            if let failure = onlineContentStore.searchFailures[selectedSource] {
                OnlineSearchErrorBanner(
                    source: selectedSource,
                    message: failure,
                    requestSnapshot: onlineContentStore.searchFailureSnapshots[selectedSource],
                    proxyAddress: $launcherSettings.proxyAddress,
                    retry: refreshOnlineContentApplyingNetworkSettings,
                    switchSource: switchSource,
                    openSettings: openDownloadSettings
                )
            }

            resourcesWorkspace
        }
    }

    var resourcesWorkspace: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: theme.fontDensity.spacing) {
                searchResultsPanel(viewportHeight: resourceWorkspaceHeight)
                    .frame(minWidth: 520, maxWidth: .infinity, alignment: .top)
                if selectedProject != nil {
                    selectedProjectDetailContent(showBackButton: false, viewportHeight: resourceWorkspaceHeight)
                        .frame(width: resourceInspectorWidth, height: resourceWorkspaceHeight, alignment: .top)
                }
            }
            .frame(height: resourceWorkspaceHeight, alignment: .top)

            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                if selectedProject != nil, showingProjectDetail {
                    selectedProjectDetailContent(showBackButton: true)
                } else {
                    searchResultsPanel
                }
            }
        }
    }

    @ViewBuilder
    func selectedProjectDetailContent(showBackButton: Bool, viewportHeight: CGFloat? = nil) -> some View {
        if let selectedProject {
            let detail = VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                    if showBackButton {
                        GlassButton(systemImage: "chevron.left", title: localizedString(theme.language, english: "Back to results", chinese: "返回结果", italian: "Torna ai risultati", french: "Retour aux résultats", spanish: "Volver a resultados")) {
                            showingProjectDetail = false
                        }
                    }

                    OnlineProjectDetailPanel(
                        presentation: showBackButton ? .full : .inspector,
                        project: selectedProject,
                        releases: onlineContentStore.selectedReleases,
                        selectedReleaseID: $selectedReleaseID,
                        currentMinecraftVersion: selectedContentMinecraftVersionID,
                        targetResolution: targetResolution,
                        selectedTargetID: $selectedContentTargetID,
                        targetFailure: targetResolutionFailure,
                        projectFailure: onlineContentStore.projectFailure,
                        isLoading: onlineContentStore.isLoading,
                        retryLoad: { onlineContentStore.loadProject(selectedProject.id, sourceID: selectedProject.source, query: searchQuery) },
                        install: installSelectedRelease,
                        openTasks: openTasks
                    )
                }

            if let viewportHeight {
                ScrollView {
                    detail
                }
                .frame(height: viewportHeight)
                .scrollIndicators(.visible)
                .scrollClipDisabled(false)
            } else {
                detail
            }
        }
    }

    private var resourceWorkspaceHeight: CGFloat {
        let windowHeight = NSApp.keyWindow?.contentLayoutRect.height ?? NSScreen.main?.visibleFrame.height ?? 920
        return min(max(windowHeight - 360, 580), 860)
    }

    private var resourceInspectorWidth: CGFloat {
        560
    }

    var targetContextBar: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedString(theme.language, english: "Minecraft version filter", chinese: "Minecraft 版本过滤", italian: "Filtro versione Minecraft", french: "Filtre de version Minecraft", spanish: "Filtro de versión de Minecraft"))
                        .font(.caption.weight(.semibold))
                    Text(targetContextSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language)) {
                    refreshOnlineContent()
                }
                .disabled(!canSearchSelectedSource || onlineContentStore.isLoading)
                Menu {
                    Button(localizedString(theme.language, english: "All Minecraft versions", chinese: "全部 Minecraft 版本", italian: "Tutte le versioni Minecraft", french: "Toutes les versions Minecraft", spanish: "Todas las versiones de Minecraft")) {
                        useMinecraftVersionFilter = false
                        selectedContentMinecraftVersionID = nil
                    }
                    Divider()
                    if releaseMinecraftVersions.isEmpty {
                        Button(AppText.refresh.localized(theme.language)) {
                            refreshMinecraftVersions()
                        }
                    } else {
                        ForEach(releaseMinecraftVersions) { version in
                            Button(versionMenuTitle(version)) {
                                useMinecraftVersionFilter = true
                                selectedContentMinecraftVersionID = version.id
                            }
                        }
                    }
                } label: {
                    Label(localizedString(theme.language, english: "Choose Version", chinese: "选择版本", italian: "Scegli versione", french: "Choisir la version", spanish: "Elegir versión"), systemImage: "arrow.left.arrow.right")
                }
                .menuStyle(.button)
            }
        }
    }

    var targetContextSummary: String {
        guard useMinecraftVersionFilter else {
            return localizedString(theme.language, english: "No Minecraft version filter selected. Search results are not tied to a local instance.", chinese: "未选择 Minecraft 版本过滤；搜索结果不会绑定本地实例。", italian: "Nessun filtro versione Minecraft selezionato.", french: "Aucun filtre de version Minecraft sélectionné.", spanish: "No se seleccionó filtro de versión de Minecraft.")
        }
        guard let selectedContentMinecraftVersionID else {
            return localizedString(theme.language, english: "Choose a Minecraft version to filter compatible content.", chinese: "请选择 Minecraft 版本，用于筛选兼容内容。", italian: "Scegli una versione Minecraft per filtrare i contenuti compatibili.", french: "Choisissez une version Minecraft pour filtrer le contenu compatible.", spanish: "Elige una versión de Minecraft para filtrar contenido compatible.")
        }
        return localizedString(theme.language, english: "Browsing content compatible with Minecraft \(selectedContentMinecraftVersionID). Install targets are chosen later.", chinese: "正在浏览兼容 Minecraft \(selectedContentMinecraftVersionID) 的内容；安装目标稍后再选。", italian: "Contenuti compatibili con Minecraft \(selectedContentMinecraftVersionID).", french: "Contenu compatible avec Minecraft \(selectedContentMinecraftVersionID).", spanish: "Contenido compatible con Minecraft \(selectedContentMinecraftVersionID).")
    }

    func versionMenuTitle(_ version: MinecraftVersionInfo) -> String {
        let kind = version.kind.title(language: theme.language)
        if version.id == versionStore.latestReleaseID {
            return localizedString(theme.language, english: "\(version.id) · Latest release", chinese: "\(version.id) · 最新正式版", italian: "\(version.id) · Ultima release", french: "\(version.id) · Dernière release", spanish: "\(version.id) · Última release")
        }
        return "\(version.id) · \(kind)"
    }

}
