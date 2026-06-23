import SwiftUI

extension OnlineContentDiscoveryPage {
    var searchResultsPanel: some View {
        searchResultsPanel()
    }

    func searchResultsPanel(viewportHeight: CGFloat? = nil) -> some View {
        GlassPanel(showsShadow: false, surfaceLevel: .panel) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    PanelHeader(
                        title: localizedString(theme.language, english: "Results", chinese: "搜索结果", italian: "Risultati", french: "Résultats", spanish: "Resultados"),
                        systemImage: "list.bullet.rectangle"
                    )
                    Spacer()
                    if onlineContentStore.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    if let lastSearchUpdatedText {
                        Text(lastSearchUpdatedText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    CountText(value: projects.count)
                }

                if onlineContentStore.isLoading && projects.isEmpty {
                    OnlineProjectSkeletonList()
                } else if let failure = onlineContentStore.searchFailures[selectedSource], projects.isEmpty {
                    OnlineRequestFailedView(
                        source: selectedSource,
                        message: failure,
                        retry: refreshOnlineContent,
                        switchSource: switchSource
                    )
                } else if projects.isEmpty {
                    OnlineEmptyResultsView(
                        source: selectedSource,
                        canSearch: canSearchSelectedSource,
                        isVersionFiltered: useMinecraftVersionFilter && selectedContentMinecraftVersionID != nil,
                        retry: refreshOnlineContent,
                        relaxVersionFilter: relaxMinecraftVersionFilter,
                        switchSource: switchSource
                    )
                } else {
                    projectResultsList(viewportHeight: viewportHeight)
                    onlinePageControls
                }
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: viewportHeight, alignment: .top)
    }

    @ViewBuilder
    private func projectResultsList(viewportHeight: CGFloat?) -> some View {
        let rows = LazyVStack(spacing: 6) {
            ForEach(projects) { project in
                OnlineProjectResultRow(
                    project: project,
                    isSelected: selectedProject?.id == project.id
                ) {
                    showingProjectDetail = true
                    selectedReleaseID = nil
                    targetResolution = nil
                    targetResolutionFailure = nil
                    onlineContentStore.selectProjectPreview(project)
                    onlineContentStore.loadProject(project.id, sourceID: project.source, query: searchQuery)
                }
            }
        }

        if let viewportHeight {
            ScrollView {
                rows
                    .padding(.trailing, 4)
            }
            .frame(height: max(viewportHeight - 92, 260), alignment: .top)
            .scrollIndicators(.visible)
            .scrollClipDisabled(false)
        } else {
            rows
        }
    }

    private var onlinePageControls: some View {
        HStack {
            Text(onlinePageStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            if onlineContentStore.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            } else {
                Color.clear
                    .frame(width: 18, height: 18)
            }
            GlassButton(systemImage: "chevron.left", title: localizedString(theme.language, english: "Previous", chinese: "上一页", italian: "Precedente", french: "Précédent", spanish: "Anterior")) {
                goToOnlinePage(max(onlinePage - 1, 0))
            }
            .disabled(onlinePage <= 0 || onlineContentStore.isLoading)
            GlassButton(systemImage: "chevron.right", title: localizedString(theme.language, english: "Next", chinese: "下一页", italian: "Successiva", french: "Suivant", spanish: "Siguiente")) {
                goToOnlinePage(onlinePage + 1)
            }
            .disabled(!hasNextOnlinePage || onlineContentStore.isLoading)
        }
    }
}
