import Foundation

enum InstanceAppearanceColorPreset: String, CaseIterable, Identifiable {
    case redstone
    case grass
    case diamond
    case gold
    case amethyst
    case nether
    case prismarine
    case deepslate

    var id: String { rawValue }

    var hex: String {
        switch self {
        case .redstone: return "#ef4444"
        case .grass: return "#22c55e"
        case .diamond: return "#38bdf8"
        case .gold: return "#f59e0b"
        case .amethyst: return "#a855f7"
        case .nether: return "#dc2626"
        case .prismarine: return "#14b8a6"
        case .deepslate: return "#64748b"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .redstone:
            return localizedString(language, english: "Redstone", chinese: "红石", italian: "Redstone", french: "Redstone", spanish: "Redstone")
        case .grass:
            return localizedString(language, english: "Grass", chinese: "草方块", italian: "Erba", french: "Herbe", spanish: "Hierba")
        case .diamond:
            return localizedString(language, english: "Diamond", chinese: "钻石", italian: "Diamante", french: "Diamant", spanish: "Diamante")
        case .gold:
            return localizedString(language, english: "Gold", chinese: "金锭", italian: "Oro", french: "Or", spanish: "Oro")
        case .amethyst:
            return localizedString(language, english: "Amethyst", chinese: "紫水晶", italian: "Ametista", french: "Améthyste", spanish: "Amatista")
        case .nether:
            return localizedString(language, english: "Nether", chinese: "下界", italian: "Nether", french: "Nether", spanish: "Nether")
        case .prismarine:
            return localizedString(language, english: "Prismarine", chinese: "海晶", italian: "Prismarine", french: "Prismarine", spanish: "Prismarino")
        case .deepslate:
            return localizedString(language, english: "Deepslate", chinese: "深板岩", italian: "Ardesia", french: "Ardoise", spanish: "Pizarra")
        }
    }
}
