import SwiftUI

extension InstanceIconBackdropStyle {
    func title(language: AppLanguage) -> String {
        switch self {
        case .automatic:
            return localizedString(language, english: "Auto", chinese: "自动", italian: "Auto", french: "Auto", spanish: "Auto")
        case .none:
            return localizedString(language, english: "None", chinese: "无", italian: "Nessuno", french: "Aucun", spanish: "Ninguno")
        case .plate:
            return localizedString(language, english: "Plate", chinese: "底板", italian: "Piastra", french: "Plaque", spanish: "Placa")
        case .glass:
            return localizedString(language, english: "Glass", chinese: "玻璃", italian: "Vetro", french: "Verre", spanish: "Cristal")
        }
    }
}

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

enum InstanceAppearanceIconPreset: String, CaseIterable, Identifiable {
    case cube
    case chest
    case stack
    case pickaxe
    case forge
    case mod
    case world
    case leaf
    case fire
    case water
    case lightning
    case controller

    var id: String { rawValue }

    var systemName: String {
        switch self {
        case .cube: return "cube.fill"
        case .chest: return "shippingbox.fill"
        case .stack: return "square.stack.3d.up.fill"
        case .pickaxe: return "hammer.fill"
        case .forge: return "wrench.and.screwdriver.fill"
        case .mod: return "puzzlepiece.extension.fill"
        case .world: return "mountain.2.fill"
        case .leaf: return "leaf.fill"
        case .fire: return "flame.fill"
        case .water: return "drop.fill"
        case .lightning: return "bolt.fill"
        case .controller: return "gamecontroller.fill"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .cube:
            return localizedString(language, english: "Block", chinese: "方块", italian: "Blocco", french: "Bloc", spanish: "Bloque")
        case .chest:
            return localizedString(language, english: "Crate", chinese: "箱子", italian: "Cassa", french: "Caisse", spanish: "Caja")
        case .stack:
            return localizedString(language, english: "Stack", chinese: "堆叠", italian: "Pila", french: "Pile", spanish: "Pila")
        case .pickaxe:
            return localizedString(language, english: "Tool", chinese: "工具", italian: "Attrezzo", french: "Outil", spanish: "Herramienta")
        case .forge:
            return localizedString(language, english: "Forge", chinese: "锻造", italian: "Forgia", french: "Forge", spanish: "Forja")
        case .mod:
            return localizedString(language, english: "Mod", chinese: "Mod", italian: "Mod", french: "Mod", spanish: "Mod")
        case .world:
            return localizedString(language, english: "World", chinese: "世界", italian: "Mondo", french: "Monde", spanish: "Mundo")
        case .leaf:
            return localizedString(language, english: "Nature", chinese: "自然", italian: "Natura", french: "Nature", spanish: "Naturaleza")
        case .fire:
            return localizedString(language, english: "Fire", chinese: "火焰", italian: "Fuoco", french: "Feu", spanish: "Fuego")
        case .water:
            return localizedString(language, english: "Water", chinese: "水域", italian: "Acqua", french: "Eau", spanish: "Agua")
        case .lightning:
            return localizedString(language, english: "Power", chinese: "能量", italian: "Energia", french: "Énergie", spanish: "Energía")
        case .controller:
            return localizedString(language, english: "Game", chinese: "游戏", italian: "Gioco", french: "Jeu", spanish: "Juego")
        }
    }
}

extension InstanceAppearanceValues {
    var normalized: InstanceAppearanceValues {
        let trimmedIconName = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCoverColor = coverColorHex.normalizedHex
        return InstanceAppearanceValues(
            iconName: trimmedIconName.isEmpty ? "cube.fill" : trimmedIconName,
            coverPath: coverPath.trimmingCharacters(in: .whitespacesAndNewlines),
            coverColorHex: normalizedCoverColor.isEmpty ? GameInstance.defaultCoverColorHex : normalizedCoverColor,
            coverFocusX: GameInstance.clampedUnit(coverFocusX),
            coverFocusY: GameInstance.clampedUnit(coverFocusY),
            coverBlur: GameInstance.clampedUnit(coverBlur),
            coverDim: GameInstance.clampedUnit(coverDim),
            iconBackdropStyle: iconBackdropStyle
        )
    }

    init(
        iconName: String,
        coverPath: String,
        coverColorHex: String,
        coverFocusX: Double,
        coverFocusY: Double,
        coverBlur: Double,
        coverDim: Double,
        iconBackdropStyle: InstanceIconBackdropStyle
    ) {
        self.iconName = iconName
        self.coverPath = coverPath
        self.coverColorHex = coverColorHex
        self.coverFocusX = coverFocusX
        self.coverFocusY = coverFocusY
        self.coverBlur = coverBlur
        self.coverDim = coverDim
        self.iconBackdropStyle = iconBackdropStyle
    }
}
