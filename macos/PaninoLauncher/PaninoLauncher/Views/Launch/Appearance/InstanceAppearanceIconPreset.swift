import Foundation

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
