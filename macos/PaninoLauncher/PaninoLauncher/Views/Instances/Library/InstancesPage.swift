import SwiftUI

struct InstancesPage: View {
    @ObservedObject var viewModel: LauncherViewModel
    let openResources: () -> Void
    let openDiscover: () -> Void
    @EnvironmentObject var instanceStore: InstanceStore
    @EnvironmentObject var launcherSettings: LauncherSettings
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var versionStore: VersionContentStore
    @EnvironmentObject var theme: ThemeSettings
    @EnvironmentObject var appActions: AppActionCenter
    @State var searchText = ""
    @State var sort: InstanceSort = .favoritesFirst
    @State var filter: InstanceFilter = .all
    @State var confirmDelete = false
    @State var showingProperties = false
    @State var propertySection: InstancePropertySection = .overview
    @State var instanceOperationStatus = ""
    @State var isMutatingInstance = false

    var body: some View {
        Group {
            if showingProperties, let binding = instanceStore.selectedInstanceBinding {
                InstancePropertiesPage(
                    viewModel: viewModel,
                    instance: binding,
                    section: $propertySection,
                    openDiscover: openDiscover,
                    onBack: { showingProperties = false },
                    onDuplicate: instanceStore.duplicateSelected,
                    onDelete: { confirmDelete = true },
                    onArchive: archiveSelectedInstance,
                    onMoveOut: moveOutSelectedInstance,
                    onRestoreArchive: restoreArchivedInstance
                )
            } else {
                instanceLibrary
            }
        }
        .task {
            configureVersionCoreBackend()
            refreshSelectedInstanceVersionState()
        }
        .onChange(of: instanceStore.selectedInstanceID) {
            refreshSelectedInstanceVersionState()
        }
        .onChange(of: instanceStore.selectedInstance?.minecraftVersion ?? "") {
            refreshSelectedInstanceVersionState()
        }
        .onChange(of: appActions.instanceContentSequence) {
            openRequestedInstanceContent(appActions.requestedInstanceContentKind)
        }
        .confirmationDialog(
            localizedString(theme.language, english: "Delete this game configuration?", chinese: "删除此游戏配置？", italian: "Eliminare questa configurazione?", french: "Supprimer cette configuration ?", spanish: "¿Eliminar esta configuración?"),
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(localizedString(theme.language, english: "Delete Game Configuration", chinese: "删除游戏配置", italian: "Elimina configurazione", french: "Supprimer configuration", spanish: "Eliminar configuración"), role: .destructive) {
                deleteSelectedInstanceFiles()
            }
            Button(AppText.cancel.localized(theme.language), role: .cancel) {}
        } message: {
            if let selected = instanceStore.selectedInstance {
                Text(deleteConfirmationMessage(selected))
            }
        }
    }

    private var instanceLibrary: some View {
        ImmersivePageScaffold(
            minHeight: 720,
            backgroundContent: {
                InstanceImmersiveBackground(instance: sceneInstance)
            },
            primaryContent: {
                InstanceImmersivePrimary(
                    instance: sceneInstance,
                    totalCount: instanceStore.instances.count,
                    filteredCount: filteredInstances.count,
                    statusText: instanceOperationStatus.isEmpty ? instanceStore.storageStatus : instanceOperationStatus,
                    openDiscover: openDiscover
                )
            },
            floatingControls: {
                InstanceImmersiveControls(
                    instance: sceneInstance,
                    canSubmitTask: viewModel.canSubmitTask,
                    isMutatingInstance: isMutatingInstance,
                    launch: { instance in launchSelectedInstance(instance) },
                    openProperties: { instance in
                        instanceStore.selectedInstanceID = instance.id
                        propertySection = .overview
                        showingProperties = true
                    },
                    openFolder: { instance in FinderIntegration.openInstanceDirectory(instance) },
                    restoreArchive: restoreArchivedInstance,
                    openDiscover: openDiscover
                )
            },
            contextShelf: {
                InstanceImmersiveShelf(
                    searchText: $searchText,
                    sort: $sort,
                    filter: $filter,
                    counts: collectionCounts,
                    instances: filteredInstances,
                    selectedInstanceID: instanceStore.selectedInstanceID,
                    canLaunch: viewModel.canSubmitTask,
                    selectInstance: { instance in
                        instanceStore.selectedInstanceID = instance.id
                    },
                    launch: { instance in launchSelectedInstance(instance) },
                    openProperties: { instance, section in
                        instanceStore.selectedInstanceID = instance.id
                        propertySection = section
                        showingProperties = true
                    },
                    openFolder: { instance in
                        FinderIntegration.openInstanceDirectory(instance)
                    }
                )
            }
        )
    }
}
