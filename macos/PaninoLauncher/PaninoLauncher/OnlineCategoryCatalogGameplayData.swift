import Foundation

extension OnlineCategoryCatalog {
    static let gameplayCategories: [OnlineCategoryOption] = [
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
            sources: modrinthSources,
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
            sources: modrinthSources,
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
}
