import Foundation

struct OnlineCategoryOption: Identifiable, Hashable, Sendable {
    let id: String
    let projectTypes: Set<OnlineProjectType>
    let sources: Set<ContentSourceID>
    let priority: Int
    let englishTitle: String
    let chineseTitle: String
    let italianTitle: String
    let frenchTitle: String
    let spanishTitle: String

    func title(language: AppLanguage) -> String {
        localizedString(
            language,
            english: englishTitle,
            chinese: chineseTitle,
            italian: italianTitle,
            french: frenchTitle,
            spanish: spanishTitle
        )
    }
}

enum OnlineCategoryCatalog {
    static func options(for projectType: OnlineProjectType, source: ContentSourceID) -> [OnlineCategoryOption] {
        all
            .filter { $0.projectTypes.contains(projectType) && $0.sources.contains(source) && supports($0, projectType: projectType, source: source) }
            .sorted {
                if $0.priority == $1.priority {
                    return $0.englishTitle.localizedCaseInsensitiveCompare($1.englishTitle) == .orderedAscending
                }
                return $0.priority < $1.priority
            }
    }

    static func option(id: String, projectType: OnlineProjectType, source: ContentSourceID) -> OnlineCategoryOption? {
        options(for: projectType, source: source).first { $0.id == id }
    }

    private static let modrinth: Set<ContentSourceID> = [.modrinth]
    private static let bothSources: Set<ContentSourceID> = [.modrinth, .curseForge]

    private static let all: [OnlineCategoryOption] = [
        option(
            "performance",
            types: [.mod],
            sources: bothSources,
            priority: 10,
            english: "Performance",
            chinese: "性能优化",
            italian: "Prestazioni",
            french: "Performance",
            spanish: "Rendimiento"
        ),
        option(
            "library",
            types: [.mod],
            sources: bothSources,
            priority: 20,
            english: "API / Library",
            chinese: "API / 库",
            italian: "API / Libreria",
            french: "API / Bibliothèque",
            spanish: "API / Biblioteca"
        ),
        option(
            "world-map",
            types: [.mod],
            sources: bothSources,
            priority: 30,
            english: "World / Map",
            chinese: "世界 / 地图",
            italian: "Mondo / Mappa",
            french: "Monde / Carte",
            spanish: "Mundo / Mapa"
        ),
        option(
            "utility",
            types: [.mod],
            sources: bothSources,
            priority: 40,
            english: "Utility",
            chinese: "实用工具",
            italian: "Utilità",
            french: "Utilitaire",
            spanish: "Utilidad"
        ),
        option(
            "technology",
            types: [.mod, .modpack],
            sources: bothSources,
            priority: 50,
            english: "Technology",
            chinese: "科技",
            italian: "Tecnologia",
            french: "Technologie",
            spanish: "Tecnología"
        ),
        option(
            "magic",
            types: [.mod, .modpack],
            sources: bothSources,
            priority: 60,
            english: "Magic",
            chinese: "魔法",
            italian: "Magia",
            french: "Magie",
            spanish: "Magia"
        ),
        option(
            "adventure",
            types: [.mod, .modpack],
            sources: bothSources,
            priority: 70,
            english: "Adventure / RPG",
            chinese: "冒险 / RPG",
            italian: "Avventura / RPG",
            french: "Aventure / RPG",
            spanish: "Aventura / RPG"
        ),
        option(
            "storage",
            types: [.mod],
            sources: bothSources,
            priority: 80,
            english: "Storage",
            chinese: "存储",
            italian: "Archiviazione",
            french: "Stockage",
            spanish: "Almacenamiento"
        ),
        option(
            "vanilla-plus",
            types: [.resourcePack, .modpack],
            sources: bothSources,
            priority: 10,
            english: "Vanilla+",
            chinese: "原版增强",
            italian: "Vanilla+",
            french: "Vanilla+",
            spanish: "Vanilla+"
        ),
        option(
            "realistic",
            types: [.resourcePack, .shaderPack],
            sources: bothSources,
            priority: 20,
            english: "Realistic",
            chinese: "写实",
            italian: "Realistico",
            french: "Réaliste",
            spanish: "Realista"
        ),
        option(
            "ui-font",
            types: [.resourcePack],
            sources: modrinth,
            priority: 30,
            english: "UI / Font",
            chinese: "界面 / 字体",
            italian: "UI / Font",
            french: "UI / Police",
            spanish: "UI / Fuente"
        ),
        option(
            "16x",
            types: [.resourcePack],
            sources: bothSources,
            priority: 40,
            english: "16x",
            chinese: "16x",
            italian: "16x",
            french: "16x",
            spanish: "16x"
        ),
        option(
            "32x",
            types: [.resourcePack],
            sources: bothSources,
            priority: 50,
            english: "32x",
            chinese: "32x",
            italian: "32x",
            french: "32x",
            spanish: "32x"
        ),
        option(
            "64x-plus",
            types: [.resourcePack],
            sources: bothSources,
            priority: 60,
            english: "64x+",
            chinese: "64x+",
            italian: "64x+",
            french: "64x+",
            spanish: "64x+"
        ),
        option(
            "pbr",
            types: [.resourcePack, .shaderPack],
            sources: modrinth,
            priority: 70,
            english: "PBR / Normal Map",
            chinese: "PBR / 法线贴图",
            italian: "PBR / Normal Map",
            french: "PBR / Normal Map",
            spanish: "PBR / Mapa normal"
        ),
        option(
            "lightweight",
            types: [.shaderPack, .modpack],
            sources: bothSources,
            priority: 10,
            english: "Lightweight",
            chinese: "轻量",
            italian: "Leggero",
            french: "Léger",
            spanish: "Ligero"
        ),
        option(
            "balanced",
            types: [.shaderPack],
            sources: modrinth,
            priority: 20,
            english: "Balanced",
            chinese: "均衡",
            italian: "Bilanciato",
            french: "Équilibré",
            spanish: "Equilibrado"
        ),
        option(
            "high-quality",
            types: [.shaderPack],
            sources: modrinth,
            priority: 30,
            english: "High Quality",
            chinese: "高画质",
            italian: "Alta qualità",
            french: "Haute qualité",
            spanish: "Alta calidad"
        ),
        option(
            "quests",
            types: [.modpack],
            sources: bothSources,
            priority: 80,
            english: "Quests",
            chinese: "任务线",
            italian: "Missioni",
            french: "Quêtes",
            spanish: "Misiones"
        )
    ]

    private static func supports(_ option: OnlineCategoryOption, projectType: OnlineProjectType, source: ContentSourceID) -> Bool {
        if source == .curseForge && projectType == .shaderPack {
            return false
        }
        return true
    }

    private static func option(
        _ id: String,
        types: Set<OnlineProjectType>,
        sources: Set<ContentSourceID>,
        priority: Int,
        english: String,
        chinese: String,
        italian: String,
        french: String,
        spanish: String
    ) -> OnlineCategoryOption {
        OnlineCategoryOption(
            id: id,
            projectTypes: types,
            sources: sources,
            priority: priority,
            englishTitle: english,
            chineseTitle: chinese,
            italianTitle: italian,
            frenchTitle: french,
            spanishTitle: spanish
        )
    }
}
