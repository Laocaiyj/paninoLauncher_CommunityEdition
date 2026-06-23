import SwiftUI

struct ResourcesManagementPanel: View {
    let selectedInstance: GameInstance?
    let isAssetKindAvailable: Bool
    @Binding var assetSearchText: String
    @Binding var selectedSort: ManagedAssetSort
    let filteredManagedAssets: [ManagedAsset]
    let groupedAssets: [(title: String, assets: [ManagedAsset])]
    let selectedAssetIDs: Set<String>
    let emptyTitle: String
    let fileStatus: String
    let updatePlanStatus: String
    let installActionTitle: String
    let unavailableTitle: String
    let unavailableDescription: String
    let refresh: () -> Void
    let openFolder: () -> Void
    let openDiscover: () -> Void
    let selectAll: () -> Void
    let sortChanged: () -> Void
    let toggleSelection: (String) -> Void
    let toggleAsset: (ManagedAsset) -> Void
    let linkAsset: (ManagedAsset) -> Void
    let deleteAsset: (ManagedAsset) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                header

                if isAssetKindAvailable {
                    resourceControls
                    sortRow
                    resourceDropHint
                    assetList
                } else {
                    unavailableState
                }

                statusLines
            }
        }
    }

    private var header: some View {
        HStack {
            PanelHeader(
                title: localizedString(theme.language, english: "Current Configuration Resources", chinese: "当前游戏配置资源", italian: "Risorse configurazione attuale", french: "Ressources de la configuration", spanish: "Recursos de configuración"),
                systemImage: "folder.badge.gearshape"
            )
            Spacer()
            if let selectedInstance {
                MetadataLine(items: ["Minecraft \(selectedInstance.minecraftVersion)", selectedInstance.loaderTitle(language: theme.language)])
            }
            GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: refresh)
            GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language), action: openFolder)
        }
    }

    private var resourceControls: some View {
        HStack(spacing: 8) {
            PaninoTextInput(
                localizedString(theme.language, english: "Search installed content", chinese: "搜索已安装内容", italian: "Cerca contenuti installati", french: "Rechercher contenu installé", spanish: "Buscar contenido instalado"),
                text: $assetSearchText
            )

            GlassButton(systemImage: "folder", title: AppText.openFolder.localized(theme.language), action: openFolder)
            GlassButton(systemImage: "arrow.down.app", title: installActionTitle, action: openDiscover)
            GlassButton(
                systemImage: "checklist",
                title: localizedString(theme.language, english: "Select All", chinese: "全选", italian: "Seleziona tutto", french: "Tout sélectionner", spanish: "Seleccionar todo"),
                action: selectAll
            )
            .disabled(filteredManagedAssets.isEmpty)
        }
    }

    private var sortRow: some View {
        SettingsRow(
            title: localizedString(theme.language, english: "Sort", chinese: "排序", italian: "Ordina", french: "Tri", spanish: "Orden"),
            systemImage: "arrow.up.arrow.down"
        ) {
            Picker(localizedString(theme.language, english: "Sort"), selection: $selectedSort) {
                ForEach(ManagedAssetSort.allCases) { sort in
                    Text(sort.title(language: theme.language)).tag(sort)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedSort) {
                sortChanged()
            }
        }
    }

    private var resourceDropHint: some View {
        Text(
            localizedString(
                theme.language,
                english: "Installed content is scoped to the selected game configuration. Drop .jar or .zip files anywhere in this window to import through Core.",
                chinese: "已安装内容以当前游戏配置为上下文。可将 .jar 或 .zip 文件拖入窗口并通过 Core 导入。",
                italian: "Il contenuto installato è legato all'istanza selezionata. Trascina .jar o .zip nella finestra per importare via Core.",
                french: "Le contenu installé est lié à la configuration sélectionnée. Déposez .jar ou .zip pour importer via Core.",
                spanish: "El contenido instalado pertenece a la instancia seleccionada. Suelta .jar o .zip para importar mediante Core."
            )
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var assetList: some View {
        if filteredManagedAssets.isEmpty {
            ContentUnavailableView(
                emptyTitle,
                systemImage: "tray",
                description: Text(fileStatus)
            )
            .frame(minHeight: 220)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(groupedAssets, id: \.title) { group in
                    ManagedAssetGroupView(
                        title: group.title,
                        assets: group.assets,
                        selectedAssetIDs: selectedAssetIDs,
                        toggleSelection: toggleSelection,
                        toggleAsset: toggleAsset,
                        linkAsset: linkAsset,
                        deleteAsset: deleteAsset
                    )
                }
            }
        }
    }

    private var unavailableState: some View {
        ContentUnavailableView(
            unavailableTitle,
            systemImage: "exclamationmark.circle",
            description: Text(unavailableDescription)
        )
        .frame(minHeight: 220)
    }

    @ViewBuilder
    private var statusLines: some View {
        Text(fileStatus)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .truncationMode(.middle)
        if !updatePlanStatus.isEmpty {
            Text(updatePlanStatus)
                .font(.caption)
                .foregroundStyle(Color.orange)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }
}
