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
