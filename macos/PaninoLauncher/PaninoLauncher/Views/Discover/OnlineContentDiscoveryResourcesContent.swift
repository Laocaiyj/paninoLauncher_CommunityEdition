import AppKit
import SwiftUI

extension OnlineContentDiscoveryPage {
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
}
