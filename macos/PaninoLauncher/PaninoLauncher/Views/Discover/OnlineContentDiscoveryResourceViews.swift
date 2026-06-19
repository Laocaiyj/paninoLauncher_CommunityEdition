import AppKit
import SwiftUI

extension OnlineContentDiscoveryPage {
    var discoverSceneBackground: some View {
        DiscoverImmersiveBackground(section: selectedSection)
    }

    var discoverScenePrimary: some View {
        DiscoverImmersivePrimary(
            title: discoverSceneTitle,
            subtitle: discoverSceneSubtitle,
            metadata: discoverSceneMetadata,
            status: discoverSceneStatus
        )
    }

    var discoverSceneControls: some View {
        let showsSourceControls = selectedSection != .minecraft

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                discoverSectionPicker
                    .frame(
                        minWidth: showsSourceControls ? 420 : 540,
                        idealWidth: showsSourceControls ? 560 : 760,
                        maxWidth: showsSourceControls ? 720 : 960,
                        alignment: .leading
                    )
                    .layoutPriority(showsSourceControls ? 0 : 1)
                    .scaleEffect(x: showsSourceControls ? 0.985 : 1, y: 1, anchor: .leading)
                if showsSourceControls {
                    searchSourceControls
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: showsSourceControls ? 1_080 : 980, alignment: showsSourceControls ? .leading : .center)
            .animation(
                PaninoMotion.noneWhenReduced(PaninoMotion.standard, reduceMotion: reduceMotion || theme.reducesInterfaceMotion),
                value: showsSourceControls
            )

            VStack(alignment: .trailing, spacing: 8) {
                discoverSectionPicker
                if showsSourceControls {
                    searchSourceControls
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(
                PaninoMotion.noneWhenReduced(PaninoMotion.standard, reduceMotion: reduceMotion || theme.reducesInterfaceMotion),
                value: showsSourceControls
            )
        }
    }

    @ViewBuilder
    var discoverSceneContextShelf: some View {
        if selectedSection == .minecraft {
            DiscoverMinecraftSceneShelf(
                versionCount: versionStore.versions.count,
                status: versionStore.versionStatus,
                searchText: $minecraftSearchText,
                group: $minecraftBrowseGroup,
                refresh: refreshMinecraftVersions
            )
        } else {
            searchPanel
        }
    }

    private var discoverSectionPicker: some View {
        PaninoGlassSegmentedRail {
            Picker("", selection: $selectedSection) {
                ForEach(DiscoverSection.allCases) { section in
                    Text(section.title(language: theme.language)).tag(section)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
        }
    }

    private var discoverSceneTitle: String {
        if selectedSection == .minecraft, let selectedMinecraftVersion {
            return "Minecraft \(selectedMinecraftVersion.id)"
        }
        return selectedSection.title(language: theme.language)
    }

    private var discoverSceneSubtitle: String {
        if selectedSection == .minecraft {
            return localizedString(
                theme.language,
                english: "Browse releases, snapshots, loaders, shader loaders, and local install targets.",
                chinese: "浏览正式版、快照、加载器、光影加载器和本地安装目标。",
                italian: "Sfoglia release, snapshot, loader, shader loader e destinazioni locali.",
                french: "Parcourez les versions, snapshots, chargeurs, shaders et cibles locales.",
                spanish: "Explora versiones, snapshots, loaders, shaders y destinos locales."
            )
        }
        return localizedString(
            theme.language,
            english: "Search installable content with compatibility filters and a side-by-side quick view.",
            chinese: "用兼容性筛选搜索可安装内容，并在旁侧快速查看详情。",
            italian: "Cerca contenuti installabili con filtri di compatibilita e vista rapida.",
            french: "Recherchez du contenu installable avec filtres de compatibilite et apercu.",
            spanish: "Busca contenido instalable con filtros de compatibilidad y vista rapida."
        )
    }

    private var discoverSceneMetadata: [String] {
        if selectedSection == .minecraft {
            return [
                localizedString(theme.language, english: "Versions \(versionStore.versions.count)", chinese: "\(versionStore.versions.count) 个版本", italian: "\(versionStore.versions.count) versioni", french: "\(versionStore.versions.count) versions", spanish: "\(versionStore.versions.count) versiones"),
                minecraftBrowseGroup.title(language: theme.language),
                minecraftSearchText.isEmpty ? nil : minecraftSearchText
            ].compactMap { $0 }
        }

        return [
            selectedSource.displayName,
            selectedType.displayTitle,
            selectedLoader?.displayTitle,
            useMinecraftVersionFilter ? selectedContentMinecraftVersionID.map { "Minecraft \($0)" } : nil,
            localizedString(theme.language, english: "\(projects.count) results", chinese: "\(projects.count) 个结果", italian: "\(projects.count) risultati", french: "\(projects.count) resultats", spanish: "\(projects.count) resultados")
        ].compactMap { $0 }
    }

    private var discoverSceneStatus: String {
        if selectedSection == .minecraft {
            return versionStore.versionStatus
        }
        return sourceStatusText
    }

    var discoverSectionBar: some View {
        GlassPanel(surfaceLevel: .floatingChrome) {
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: catalogColumns, alignment: .leading, spacing: 10) {
                    discoverCatalogButton(.minecraft)
                    discoverCatalogButton(.mods)
                    discoverCatalogButton(.modpacks)
                    discoverCatalogButton(.resources)
                    discoverCatalogButton(.shaders)
                }
            }
        }
    }

    var catalogColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 148), spacing: 8, alignment: .leading)]
    }

    func discoverCatalogButton(_ section: DiscoverSection) -> some View {
        let isSelected = selectedSection == section
        let tokens = theme.resolvedTokens(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion || theme.reducesInterfaceMotion
        )
        return Button {
            withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.standard, reduceMotion: reduceMotion || theme.reducesInterfaceMotion)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 8) {
                Text(section.title(language: theme.language))
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.controlMinSize, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            let shape = RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
            if isSelected {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.semanticSelectionColor.opacity(0.96),
                                theme.semanticSelectionColor.opacity(0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        shape.strokeBorder(Color.white.opacity(0.30), lineWidth: 1)
                    }
                    .shadow(
                        color: theme.semanticSelectionColor.opacity(0.24),
                        radius: tokens.shadowRadius * 0.32,
                        x: 0,
                        y: tokens.shadowYOffset * 0.24
                    )
            } else {
                shape
                    .fill(Color.clear)
                    .paninoGlassSurface(
                        tokens: tokens,
                        level: .elevatedPanel,
                        cornerRadius: tokens.controlCornerRadius,
                        interactive: true
                    )
                    .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.32))
                    .overlay(theme.semanticSelectionColor.opacity(tokens.accentBackgroundOpacity * 0.28))
                    .paninoDepthOverlay(tokens: tokens, level: .elevatedPanel, cornerRadius: tokens.controlCornerRadius)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? Color.white.opacity(0.22)
                        : tokens.strokeColor.opacity(tokens.strokeOpacity * 0.58),
                    lineWidth: tokens.strokeWidth
                )
        }
    }

    var discoverSidebar: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString(theme.language, english: "Minecraft", chinese: "Minecraft", italian: "Minecraft", french: "Minecraft", spanish: "Minecraft"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                discoverSidebarButton(.minecraft)

                Divider()
                    .padding(.vertical, 4)

                Text(localizedString(theme.language, english: "Resources", chinese: "资源", italian: "Risorse", french: "Ressources", spanish: "Recursos"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                discoverSidebarButton(.mods)
                discoverSidebarButton(.modpacks)
                discoverSidebarButton(.resources)
                discoverSidebarButton(.shaders)
            }
        }
    }

    func discoverSidebarButton(_ section: DiscoverSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            Text(section.title(language: theme.language))
                .font(.callout.weight(selectedSection == section ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.controlMinSize, alignment: .leading)
                .padding(.horizontal, 10)
                .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedSection == section ? Color.white : Color.primary)
        .background {
            RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
                .fill(selectedSection == section ? theme.semanticSelectionColor : Color.clear)
        }
    }
}

private struct DiscoverImmersiveBackground: View {
    let section: DiscoverSection

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        sectionTint.opacity(0.64),
                        theme.semanticSelectionColor.opacity(0.28),
                        Color(nsColor: .windowBackgroundColor).opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.24),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.80
                )

                Image(systemName: section.symbolName)
                    .font(.system(size: min(proxy.size.width, 520) * 0.34, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.13))
                    .offset(x: proxy.size.width * 0.26, y: -proxy.size.height * 0.08)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var sectionTint: Color {
        switch section {
        case .minecraft:
            return Color(red: 0.24, green: 0.62, blue: 0.34)
        case .mods:
            return Color(red: 0.36, green: 0.42, blue: 0.92)
        case .modpacks:
            return Color(red: 0.87, green: 0.36, blue: 0.27)
        case .resources:
            return Color(red: 0.27, green: 0.62, blue: 0.84)
        case .shaders:
            return Color(red: 0.92, green: 0.55, blue: 0.22)
        }
    }
}

private struct DiscoverImmersivePrimary: View {
    let title: String
    let subtitle: String
    let metadata: [String]
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetadataLine(items: metadata, font: .caption.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.82))

            Text(title)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.62)
                .shadow(color: .black.opacity(0.34), radius: 10, x: 0, y: 4)

            Text(subtitle)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .frame(maxWidth: 760, alignment: .leading)

            if !status.isEmpty {
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.22), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DiscoverMinecraftSceneShelf: View {
    let versionCount: Int
    let status: String
    @Binding var searchText: String
    @Binding var group: MinecraftBrowseGroup
    let refresh: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    minecraftSearchField
                    groupPicker
                    refreshButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    minecraftSearchField
                    HStack(spacing: 10) {
                        groupPicker
                        refreshButton
                    }
                }
            }

            HStack(spacing: 8) {
                ImmersiveTextPill(
                    title: localizedString(theme.language, english: "Catalog", chinese: "目录", italian: "Catalogo", french: "Catalogue", spanish: "Catalogo"),
                    value: localizedString(theme.language, english: "\(versionCount) versions", chinese: "\(versionCount) 个版本", italian: "\(versionCount) versioni", french: "\(versionCount) versions", spanish: "\(versionCount) versiones")
                )

                if !status.isEmpty {
                    ImmersiveTextPill(
                        title: localizedString(theme.language, english: "Status", chinese: "状态", italian: "Stato", french: "Etat", spanish: "Estado"),
                        value: status
                    )
                }
            }
        }
        .padding(14)
        .paninoGlassCard(level: .floatingChrome, cornerRadius: PaninoTokens.Radius.panel, tint: theme.semanticSelectionColor)
    }

    private var minecraftSearchField: some View {
        PaninoTextInput(
            localizedString(theme.language, english: "Search version, e.g. 1.20.1", chinese: "搜索版本，例如 1.20.1", italian: "Cerca versione, es. 1.20.1", french: "Rechercher version, ex. 1.20.1", spanish: "Buscar version, ej. 1.20.1"),
            text: $searchText
        )
        .frame(minWidth: 260, idealWidth: 420, maxWidth: 560)
    }

    private var groupPicker: some View {
        PaninoGlassSegmentedRail {
            Picker("", selection: $group) {
                ForEach(MinecraftBrowseGroup.allCases) { browseGroup in
                    Text(browseGroup.title(language: theme.language)).tag(browseGroup)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(minWidth: 300, idealWidth: 430, maxWidth: 500)
        }
    }

    private var refreshButton: some View {
        GlassButton(systemImage: "arrow.clockwise", title: AppText.refresh.localized(theme.language), action: refresh)
    }
}

private extension DiscoverSection {
    var symbolName: String {
        switch self {
        case .minecraft:
            return "cube.box.fill"
        case .mods:
            return "shippingbox.fill"
        case .modpacks:
            return "square.stack.3d.up.fill"
        case .resources:
            return "photo.stack.fill"
        case .shaders:
            return "sun.max.fill"
        }
    }
}
