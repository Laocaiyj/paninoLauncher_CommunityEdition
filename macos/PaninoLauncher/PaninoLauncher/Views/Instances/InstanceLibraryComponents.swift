import SwiftUI

enum InstanceSort: String, CaseIterable, Identifiable {
    case favoritesFirst
    case name

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .favoritesFirst:
            return localizedString(language, english: "Favorites First", chinese: "收藏优先", italian: "Preferiti prima", french: "Favoris d'abord", spanish: "Favoritos primero")
        case .name:
            return localizedString(language, english: "Name", chinese: "名称", italian: "Nome", french: "Nom", spanish: "Nombre")
        }
    }
}

enum InstanceFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case needsAttention

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .all:
            return localizedString(language, english: "All", chinese: "全部", italian: "Tutte", french: "Toutes", spanish: "Todas")
        case .favorites:
            return localizedString(language, english: "Favorites", chinese: "收藏", italian: "Preferite", french: "Favorites", spanish: "Favoritas")
        case .needsAttention:
            return localizedString(language, english: "Needs Attention", chinese: "需要处理", italian: "Da verificare", french: "À traiter", spanish: "Requieren atención")
        }
    }
}

struct InstanceLibraryTile: View {
    let instance: GameInstance
    let isSelected: Bool
    let canLaunch: Bool
    let selectInstance: (GameInstance) -> Void
    let launch: (GameInstance) -> Void
    let openProperties: (GameInstance, InstancePropertySection) -> Void
    let openFolder: (GameInstance) -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InstanceCardCover(instance: instance)
                .frame(height: 108)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(instance.name)
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                        if instance.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.yellow)
                        }
                    }

                    MetadataLine(items: [
                        "Minecraft \(instance.minecraftVersion)",
                        instance.loaderTitle(language: theme.language)
                    ], font: .caption.weight(.medium))

                    Text("\(localizedString(theme.language, english: "Memory", chinese: "内存", italian: "Memoria", french: "Mémoire", spanish: "Memoria")) \(instance.memoryMb) MB")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 7) {
                    InstanceTileActionButton(
                        title: AppText.launch.localized(theme.language),
                        systemImage: "play.fill",
                        prominent: true
                    ) {
                        selectInstance(instance)
                        launch(instance)
                    }
                    .disabled(!canLaunch || !capabilities.canLaunch)

                    Spacer(minLength: 0)

                    InstanceTileActionButton(
                        title: localizedString(theme.language, english: "Properties", chinese: "属性", italian: "Proprietà", french: "Propriétés", spanish: "Propiedades"),
                        systemImage: "slider.horizontal.3"
                    ) {
                        selectInstance(instance)
                        openProperties(instance, .overview)
                    }

                    if let contentSection {
                        InstanceTileActionButton(
                            title: localizedString(theme.language, english: "Content", chinese: "内容", italian: "Contenuti", french: "Contenu", spanish: "Contenido"),
                            systemImage: "shippingbox"
                        ) {
                            selectInstance(instance)
                            openProperties(instance, contentSection)
                        }
                    }

                    InstanceTileActionButton(
                        title: AppText.openFolder.localized(theme.language),
                        systemImage: "folder"
                    ) {
                        selectInstance(instance)
                        openFolder(instance)
                    }
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, minHeight: 224, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                .fill(isSelected ? theme.semanticSelectionColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.34))
        }
        .clipShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous)
                .strokeBorder(isSelected ? theme.semanticSelectionColor.opacity(0.62) : Color(nsColor: .separatorColor).opacity(0.36))
        }
        .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.card, style: .continuous))
        .onTapGesture {
            selectInstance(instance)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(instance.name), Minecraft \(instance.minecraftVersion), \(instance.status.title(language: theme.language))")
    }

    private var capabilities: GameConfigurationCapabilities {
        GameConfigurationCapabilities.capabilities(for: instance)
    }

    private var contentSection: InstancePropertySection? {
        if capabilities.canManageMods {
            return .mods
        }
        if capabilities.canManageResourcePacks {
            return .resourcePacks
        }
        if capabilities.canManageShaderPacks {
            return .shaders
        }
        return nil
    }
}
