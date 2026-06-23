import SwiftUI

extension OnlineContentDiscoveryPage {
    var body: some View {
        contentReviewSheet
    }

    private var contentReviewSheet: some View {
        contentWithLifecycle
            .sheet(item: $pendingContentInstallReview) { review in
                InstallPlanReviewSheet(
                    plan: review.plan.typedPlan,
                    title: localizedString(theme.language, english: "Review install plan", chinese: "确认安装计划", italian: "Controlla piano installazione", french: "Vérifier le plan", spanish: "Revisar instalación"),
                    subtitle: "\(review.plan.projectTitle) · \(review.releaseVersionName)",
                    confirmTitle: localizedString(theme.language, english: "Install", chinese: "安装", italian: "Installa", french: "Installer", spanish: "Instalar"),
                    repairTitle: contentReviewRepairTitle(for: review.plan.typedPlan),
                    onCancel: { pendingContentInstallReview = nil },
                    onRepair: { repairContentInstallReview(review) },
                    onConfirm: { beginReviewedContentInstall(review) }
                )
                .environmentObject(theme)
            }
    }

    private var contentWithLifecycle: some View {
        minecraftInstallChangeHandlers
            .onDisappear(perform: cancelTransientTasks)
    }

    private var minecraftInstallChangeHandlers: some View {
        minecraftBrowseChangeHandlers
            .onChange(of: selectedMinecraftLoader) { _, _ in
                handleMinecraftInstallSelectionChanged()
            }
            .onChange(of: selectedShaderLoader) { _, _ in
                handleMinecraftInstallSelectionChanged()
            }
            .onChange(of: selectedMinecraftLoaderVersion) { _, _ in
                handleMinecraftInstallInputChanged()
            }
            .onChange(of: selectedShaderLoaderVersion) { _, _ in
                handleMinecraftInstallInputChanged()
            }
            .onChange(of: minecraftInstanceName) { _, _ in
                handleMinecraftInstallInputChanged()
            }
    }

    private var minecraftBrowseChangeHandlers: some View {
        onlineContentChangeHandlers
            .onChange(of: selectedReleaseID) { _, _ in
                handleSelectedReleaseIDChanged()
            }
            .onChange(of: minecraftBrowseGroup) { _, _ in
                handleMinecraftBrowseGroupChanged()
            }
            .onChange(of: minecraftSearchText) { _, _ in
                handleMinecraftSearchTextChanged()
            }
    }

    private var onlineContentChangeHandlers: some View {
        discoveryPageContent
            .task {
                handleDiscoveryTask()
            }
            .onChange(of: selectedSection) { _, _ in
                handleSelectedSectionChanged()
            }
            .onChange(of: selectedSource) { _, _ in
                handleSelectedSourceChanged()
            }
            .onChange(of: selectedType) { _, _ in
                handleSelectedTypeChanged()
            }
            .onChange(of: selectedSort) { _, _ in
                handleSelectedSortChanged()
            }
            .onChange(of: selectedLoader) { _, _ in
                handleSelectedLoaderChanged()
            }
            .onChange(of: useMinecraftVersionFilter) { _, _ in
                handleUseMinecraftVersionFilterChanged()
            }
            .onChange(of: selectedContentMinecraftVersionID) { _, _ in
                handleSelectedContentMinecraftVersionChanged()
            }
            .onChange(of: searchText) { _, _ in
                debounceSearch()
            }
            .onChange(of: onlineContentStore.selectedReleases) { _, _ in
                handleSelectedReleasesChanged()
            }
    }

    @ViewBuilder
    private var discoveryPageContent: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            ImmersivePageScaffold(
                minHeight: selectedSection == .minecraft ? 500 : 540,
                backgroundContent: {
                    discoverSceneBackground
                },
                primaryContent: {
                    discoverScenePrimary
                },
                floatingControls: {
                    discoverSceneControls
                },
                contextShelf: {
                    discoverSceneContextShelf
                }
            )

            if selectedSection == .minecraft {
                minecraftContent
            } else {
                resourcesContent
            }
        }
    }
}
