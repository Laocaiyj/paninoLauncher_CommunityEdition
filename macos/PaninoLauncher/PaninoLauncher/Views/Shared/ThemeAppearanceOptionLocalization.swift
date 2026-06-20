import SwiftUI

extension ThemeAppearanceMode {
    func title(language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            switch self {
            case .system: return "跟随系统"
            case .light: return "浅色"
            case .dark: return "深色"
            case .highContrast: return "高对比"
            }
        case .english:
            return title
        case .italian:
            switch self {
            case .system: return "Sistema"
            case .light: return "Chiaro"
            case .dark: return "Scuro"
            case .highContrast: return "Alto contrasto"
            }
        case .french:
            switch self {
            case .system: return "Système"
            case .light: return "Clair"
            case .dark: return "Sombre"
            case .highContrast: return "Contraste élevé"
            }
        case .spanish:
            switch self {
            case .system: return "Sistema"
            case .light: return "Claro"
            case .dark: return "Oscuro"
            case .highContrast: return "Alto contraste"
            }
        }
    }
}

extension ThemeAccentColor {
    func title(language: AppLanguage) -> String {
        guard language == .chineseSimplified else { return title }
        switch self {
        case .system: return "系统"
        case .blue: return "蓝色"
        case .emerald: return "翠绿"
        case .amber: return "琥珀"
        case .red: return "红色"
        case .purple: return "紫色"
        case .graphite: return "石墨"
        case .teal: return "青色"
        case .mint: return "薄荷"
        case .pink: return "粉色"
        case .indigo: return "靛蓝"
        case .slate: return "板岩"
        case .custom: return "自定义"
        }
    }
}

extension ThemePreset {
    func title(language: AppLanguage) -> String {
        guard language == .chineseSimplified else { return title }
        switch self {
        case .vanilla: return "原版"
        case .nether: return "下界"
        case .deepDark: return "深暗"
        case .liquidGlass: return "液态玻璃"
        case .frostedGraphite: return "磨砂石墨"
        case .minecraftAmbient: return "Minecraft 氛围"
        case .focusSolid: return "专注纯色"
        case .highLegibility: return "高可读性"
        }
    }
}
