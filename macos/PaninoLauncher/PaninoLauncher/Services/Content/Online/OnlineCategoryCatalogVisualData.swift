import Foundation

extension OnlineCategoryCatalog {
    static let visualCategories: [OnlineCategoryOption] = [
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
            sources: modrinthSources,
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
            sources: modrinthSources,
            priority: 70,
            english: "PBR / Normal Map",
            chinese: "PBR / 法线贴图",
            italian: "PBR / Normal Map",
            french: "PBR / Normal Map",
            spanish: "PBR / Mapa normal"
        )
    ]
}
