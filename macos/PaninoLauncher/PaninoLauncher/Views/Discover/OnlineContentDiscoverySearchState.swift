import Foundation

extension OnlineContentDiscoveryPage {
    var searchQuery: OnlineSearchQuery {
        OnlineSearchQuery(
            text: searchText,
            projectTypes: [selectedType],
            categories: selectedCategory.map { Set([$0]) } ?? [],
            gameVersion: useMinecraftVersionFilter ? selectedContentMinecraftVersionID : nil,
            loaders: Set(effectiveSearchLoaders),
            sort: selectedSort,
            offset: onlinePage * 30,
            limit: 30
        )
    }

    var effectiveSearchLoaders: [LoaderFamily] {
        if let selectedLoader {
            return [selectedLoader]
        }
        return []
    }

    var activeFilterSummary: [String] {
        [
            selectedType.displayTitle,
            selectedCategoryOption?.title(language: theme.language),
            selectedLoader?.displayTitle,
            useMinecraftVersionFilter ? selectedContentMinecraftVersionID.map { "Minecraft \($0)" } : nil
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
    }

    var onlinePageStatus: String {
        guard let page = onlineContentStore.searchResults[selectedSource] else { return "" }
        let start = page.offset + 1
        let end = min(page.offset + page.projects.count, page.total)
        return localizedString(
            theme.language,
            english: "\(start)-\(end) of \(page.total) results",
            chinese: "第 \(start)-\(end) 个，共 \(page.total) 个结果",
            italian: "\(start)-\(end) di \(page.total) risultati",
            french: "\(start)-\(end) sur \(page.total) résultats",
            spanish: "\(start)-\(end) de \(page.total) resultados"
        )
    }

    var hasNextOnlinePage: Bool {
        guard let page = onlineContentStore.searchResults[selectedSource] else { return false }
        if let hasMore = page.hasMore {
            return hasMore
        }
        if page.nextPrefetchKey != nil {
            return true
        }
        return page.offset + page.projects.count < page.total
    }

    var sourceStatusText: String {
        if !canSearchSelectedSource {
            return localizedString(
                theme.language,
                english: "\(selectedSource.displayName) requires an API key before searching.",
                chinese: "\(selectedSource.displayName) 需要用户自备 API Key 后才能搜索。",
                italian: "\(selectedSource.displayName) richiede una chiave API prima della ricerca.",
                french: "\(selectedSource.displayName) nécessite une clé API avant la recherche.",
                spanish: "\(selectedSource.displayName) requiere una API key antes de buscar."
            )
        }
        if let failure = onlineContentStore.searchFailures[selectedSource] {
            return "\(selectedSource.displayName): \(localizedOnlineError(failure, language: theme.language))"
        }
        if let page = onlineContentStore.searchResults[selectedSource] {
            return localizedString(
                theme.language,
                english: "Loaded \(page.projects.count) \(selectedSource.displayName) projects",
                chinese: "已加载 \(page.projects.count) 个 \(selectedSource.displayName) 项目",
                italian: "Caricati \(page.projects.count) progetti \(selectedSource.displayName)",
                french: "\(page.projects.count) projets \(selectedSource.displayName) chargés",
                spanish: "\(page.projects.count) proyectos de \(selectedSource.displayName) cargados"
            )
        }
        return onlineContentStore.statusMessage
    }
}
