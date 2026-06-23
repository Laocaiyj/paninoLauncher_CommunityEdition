import SwiftUI

extension OnlineContentDiscoveryPage {
    var searchPanel: some View {
        GlassPanel(surfaceLevel: .elevatedPanel) {
            VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
                searchInputRow
                searchFilterRow

                categoryChips

                if !activeFilterSummary.isEmpty {
                    MetadataLine(items: activeFilterSummary, font: .caption.weight(.semibold))
                }
            }
        }
    }

    var searchPanelHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                searchPanelTitle
                Spacer(minLength: 12)
                searchSourceControls
            }

            VStack(alignment: .leading, spacing: 10) {
                searchPanelTitle
                searchSourceControls
            }
        }
    }

    private var searchPanelTitle: some View {
        PanelHeader(
            title: localizedString(theme.language, english: "Online Downloads", chinese: "在线下载", italian: "Download online", french: "Téléchargements en ligne", spanish: "Descargas online"),
            systemImage: "arrow.down.app"
        )
    }

    var searchSourceControls: some View {
        HStack(spacing: 8) {
            PaninoGlassSegmentedRail {
                Picker("", selection: $selectedSource) {
                    Text(ContentSourceID.modrinth.displayName).tag(ContentSourceID.modrinth)
                    Text(localizedString(theme.language, english: "CurseForge (Advanced)", chinese: "CurseForge（高级）", italian: "CurseForge (avanzato)", french: "CurseForge (avancé)", spanish: "CurseForge (avanzado)"))
                        .tag(ContentSourceID.curseForge)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(minWidth: 210, idealWidth: 260, maxWidth: 300)
            }
            ToolbarIconButton(
                systemImage: "doc.on.doc",
                title: localizedString(theme.language, english: "Copy Search Debug", chinese: "复制搜索诊断", italian: "Copia debug ricerca", french: "Copier debug recherche", spanish: "Copiar depuración"),
                action: copySearchDebugSummary
            )
        }
    }

    var searchInputRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                searchTextField
                searchSubmitButton
            }

            VStack(alignment: .leading, spacing: 10) {
                searchTextField
                searchSubmitButton
            }
        }
    }

    private var searchTextField: some View {
        PaninoTextInput(
            localizedString(theme.language, english: "Search mods, packs, resources...", chinese: "搜索 Mod、整合包、资源包...", italian: "Cerca mod, pacchetti, risorse...", french: "Rechercher mods, packs, ressources...", spanish: "Buscar mods, packs, recursos..."),
            text: $searchText
        ) {
            refreshOnlineContent()
        }
    }

    private var searchSubmitButton: some View {
        GlassButton(systemImage: "magnifyingglass", title: localizedString(theme.language, english: "Search", chinese: "搜索", italian: "Cerca", french: "Rechercher", spanish: "Buscar"), prominent: true) {
            refreshOnlineContent()
        }
        .disabled(!canSearchSelectedSource || onlineContentStore.isLoading)
    }

    var searchFilterRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                searchFilterControls
            }

            VStack(alignment: .leading, spacing: 10) {
                searchFilterControls
            }
        }
    }

    @ViewBuilder
    private var searchFilterControls: some View {
        Picker(localizedString(theme.language, english: "Sort", chinese: "排序", italian: "Ordina", french: "Tri", spanish: "Orden"), selection: $selectedSort) {
            ForEach(OnlineContentSort.allCases, id: \.self) { sort in
                Text(sort.title(language: theme.language)).tag(sort)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 170)

        Picker(AppText.loader.localized(theme.language), selection: $selectedLoader) {
            Text(localizedString(theme.language, english: "Any Loader", chinese: "任意加载器", italian: "Qualsiasi loader", french: "Tous les chargeurs", spanish: "Cualquier loader"))
                .tag(nil as LoaderFamily?)
            ForEach(LoaderFamily.allCases) { loader in
                Text(loader.displayTitle).tag(loader as LoaderFamily?)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 170)

        Toggle(localizedString(theme.language, english: "Match Minecraft version", chinese: "匹配 Minecraft 版本", italian: "Abbina versione Minecraft", french: "Adapter la version Minecraft", spanish: "Coincidir versión de Minecraft"), isOn: $useMinecraftVersionFilter)
            .toggleStyle(.checkbox)

        versionFilterMenu

        if useMinecraftVersionFilter, let selectedContentMinecraftVersionID {
            MetadataLine(items: ["Minecraft \(selectedContentMinecraftVersionID)"], font: .caption.weight(.semibold))
        }
    }

    var versionFilterMenu: some View {
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
            Label(localizedString(theme.language, english: "Version", chinese: "版本", italian: "Versione", french: "Version", spanish: "Versión"), systemImage: "slider.horizontal.3")
        }
        .menuStyle(.button)
        .disabled(onlineContentStore.isLoading)
    }

    var lastSearchUpdatedText: String? {
        guard let date = onlineContentStore.lastSearchUpdatedAt else { return nil }
        return localizedString(
            theme.language,
            english: "Updated \(date.formatted(date: .omitted, time: .shortened))",
            chinese: "更新于 \(date.formatted(date: .omitted, time: .shortened))",
            italian: "Aggiornato \(date.formatted(date: .omitted, time: .shortened))",
            french: "Mis à jour \(date.formatted(date: .omitted, time: .shortened))",
            spanish: "Actualizado \(date.formatted(date: .omitted, time: .shortened))"
        )
    }

}
