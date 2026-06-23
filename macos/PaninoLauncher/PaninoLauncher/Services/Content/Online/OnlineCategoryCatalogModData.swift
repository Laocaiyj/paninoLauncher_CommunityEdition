import Foundation

extension OnlineCategoryCatalog {
    static let modCategories: [OnlineCategoryOption] = [
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
        )
    ]
}
