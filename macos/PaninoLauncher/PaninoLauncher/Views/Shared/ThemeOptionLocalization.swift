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

extension ThemeGlassStyle {
    func title(language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            switch self {
            case .automatic: return "自动"
            case .clear: return "通透"
            case .frosted: return "磨砂"
            case .solid: return "实色"
            }
        case .english:
            return title
        case .italian:
            switch self {
            case .automatic: return "Automatico"
            case .clear: return "Chiaro"
            case .frosted: return "Satinato"
            case .solid: return "Solido"
            }
        case .french:
            switch self {
            case .automatic: return "Automatique"
            case .clear: return "Transparent"
            case .frosted: return "Dépoli"
            case .solid: return "Opaque"
            }
        case .spanish:
            switch self {
            case .automatic: return "Automático"
            case .clear: return "Claro"
            case .frosted: return "Esmerilado"
            case .solid: return "Sólido"
            }
        }
    }
}

extension ThemeChromeStyle {
    func title(language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            switch self {
            case .integrated: return "一体式"
            case .floatingToolbar: return "漂浮工具栏"
            case .edgeToEdgeSidebar: return "通栏侧栏"
            }
        case .english:
            return title
        case .italian:
            switch self {
            case .integrated: return "Integrato"
            case .floatingToolbar: return "Barra flottante"
            case .edgeToEdgeSidebar: return "Barra laterale estesa"
            }
        case .french:
            switch self {
            case .integrated: return "Intégré"
            case .floatingToolbar: return "Barre flottante"
            case .edgeToEdgeSidebar: return "Barre latérale étendue"
            }
        case .spanish:
            switch self {
            case .integrated: return "Integrado"
            case .floatingToolbar: return "Barra flotante"
            case .edgeToEdgeSidebar: return "Barra lateral completa"
            }
        }
    }
}

extension ThemeDepthStyle {
    func title(language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            switch self {
            case .flat: return "极简"
            case .soft: return "空间"
            case .layered: return "液态"
            case .retro: return "复古"
            }
        case .english:
            return title
        case .italian:
            switch self {
            case .flat: return "Minimale"
            case .soft: return "Spaziale"
            case .layered: return "Liquido"
            case .retro: return "Retro"
            }
        case .french:
            switch self {
            case .flat: return "Minimal"
            case .soft: return "Spatial"
            case .layered: return "Liquide"
            case .retro: return "Rétro"
            }
        case .spanish:
            switch self {
            case .flat: return "Mínimo"
            case .soft: return "Espacial"
            case .layered: return "Líquido"
            case .retro: return "Retro"
            }
        }
    }
}

extension ThemeControlShape {
    func title(language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            switch self {
            case .roundedRect: return "圆角矩形"
            case .capsule: return "胶囊"
            case .concentric: return "同心圆角"
            }
        case .english:
            return title
        case .italian:
            switch self {
            case .roundedRect: return "Rettangolo"
            case .capsule: return "Capsula"
            case .concentric: return "Concentrico"
            }
        case .french:
            switch self {
            case .roundedRect: return "Rectangle"
            case .capsule: return "Capsule"
            case .concentric: return "Concentrique"
            }
        case .spanish:
            switch self {
            case .roundedRect: return "Rectángulo"
            case .capsule: return "Cápsula"
            case .concentric: return "Concéntrico"
            }
        }
    }
}

extension ThemeMotionStyle {
    func title(language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            switch self {
            case .system: return "系统"
            case .reduced: return "降低"
            case .expressive: return "灵动"
            }
        case .english:
            return title
        case .italian:
            switch self {
            case .system: return "Sistema"
            case .reduced: return "Ridotto"
            case .expressive: return "Espressivo"
            }
        case .french:
            switch self {
            case .system: return "Système"
            case .reduced: return "Réduit"
            case .expressive: return "Expressif"
            }
        case .spanish:
            switch self {
            case .system: return "Sistema"
            case .reduced: return "Reducido"
            case .expressive: return "Expresivo"
            }
        }
    }
}

extension MaterialStrength {
    func title(language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            switch self {
            case .off: return "关闭"
            case .low: return "低"
            case .medium: return "中"
            case .high: return "高"
            }
        case .english:
            return title
        case .italian:
            switch self {
            case .off: return "Spento"
            case .low: return "Basso"
            case .medium: return "Medio"
            case .high: return "Alto"
            }
        case .french:
            switch self {
            case .off: return "Désactivé"
            case .low: return "Faible"
            case .medium: return "Moyen"
            case .high: return "Élevé"
            }
        case .spanish:
            switch self {
            case .off: return "Desactivado"
            case .low: return "Bajo"
            case .medium: return "Medio"
            case .high: return "Alto"
            }
        }
    }
}

extension ThemeBackgroundMode {
    func title(language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            switch self {
            case .default: return "默认"
            case .currentInstance: return "当前配置"
            case .customImage: return "自定义图片"
            case .solidColor: return "纯色"
            }
        case .english:
            return title
        case .italian:
            switch self {
            case .default: return "Predefinito"
            case .currentInstance: return "Configurazione attuale"
            case .customImage: return "Immagine"
            case .solidColor: return "Colore pieno"
            }
        case .french:
            switch self {
            case .default: return "Par défaut"
            case .currentInstance: return "Configuration actuelle"
            case .customImage: return "Image"
            case .solidColor: return "Couleur unie"
            }
        case .spanish:
            switch self {
            case .default: return "Predeterminado"
            case .currentInstance: return "Configuración actual"
            case .customImage: return "Imagen"
            case .solidColor: return "Color sólido"
            }
        }
    }
}

extension FontDensity {
    func title(language: AppLanguage) -> String {
        switch language {
        case .chineseSimplified:
            switch self {
            case .compact: return "紧凑"
            case .standard: return "标准"
            case .comfortable: return "宽松"
            }
        case .english:
            return title
        case .italian:
            switch self {
            case .compact: return "Compatta"
            case .standard: return "Standard"
            case .comfortable: return "Comoda"
            }
        case .french:
            switch self {
            case .compact: return "Compacte"
            case .standard: return "Standard"
            case .comfortable: return "Aérée"
            }
        case .spanish:
            switch self {
            case .compact: return "Compacta"
            case .standard: return "Estándar"
            case .comfortable: return "Cómoda"
            }
        }
    }
}
