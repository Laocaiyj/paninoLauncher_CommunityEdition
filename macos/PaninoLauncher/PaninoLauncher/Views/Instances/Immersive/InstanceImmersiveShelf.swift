import SwiftUI

struct InstanceImmersiveShelf: View {
    @Binding var searchText: String
    @Binding var sort: InstanceSort
    @Binding var filter: InstanceFilter
    let counts: [InstanceFilter: Int]
    let instances: [GameInstance]
    let selectedInstanceID: UUID?
    let canLaunch: Bool
    let selectInstance: (GameInstance) -> Void
    let launch: (GameInstance) -> Void
    let openProperties: (GameInstance, InstancePropertySection) -> Void
    let openFolder: (GameInstance) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    controls
                }
                VStack(alignment: .leading, spacing: 10) {
                    controls
                }
            }

            if instances.isEmpty {
                EmptyStateInline(
                    title: localizedString(theme.language, english: "No matching instance", chinese: "没有匹配的实例", italian: "Nessuna istanza", french: "Aucune instance", spanish: "Sin instancias"),
                    message: localizedString(theme.language, english: "Adjust search or filters, or install Minecraft from Get.", chinese: "调整搜索/筛选，或从“获取”安装 Minecraft。", italian: "Modifica ricerca o filtri.", french: "Ajustez recherche ou filtres.", spanish: "Ajusta búsqueda o filtros."),
                    systemImage: "magnifyingglass"
                )
                .frame(minHeight: 82)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(instances) { instance in
                            InstanceLibraryTile(
                                instance: instance,
                                isSelected: selectedInstanceID == instance.id,
                                canLaunch: canLaunch,
                                selectInstance: selectInstance,
                                launch: launch,
                                openProperties: openProperties,
                                openFolder: openFolder
                            )
                            .frame(width: 300)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.panel, tint: theme.semanticSelectionColor, showsShadow: true)
    }

    @ViewBuilder
    private var controls: some View {
        PaninoTextInput(localizedString(theme.language, english: "Search installed instances", chinese: "搜索本地实例", italian: "Cerca istanze", french: "Rechercher instances", spanish: "Buscar instancias"), text: $searchText)
            .frame(minWidth: 240, idealWidth: 320, maxWidth: 360)

        Picker(localizedString(theme.language, english: "Sort"), selection: $sort) {
            ForEach(InstanceSort.allCases) { sort in
                Text(sort.title(language: theme.language)).tag(sort)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 150)

        PaninoGlassSegmentedRail {
            Picker("", selection: $filter) {
                ForEach(InstanceFilter.allCases) { item in
                    Text("\(item.title(language: theme.language)) \(counts[item] ?? 0)").tag(item)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 310)
        }
    }
}
