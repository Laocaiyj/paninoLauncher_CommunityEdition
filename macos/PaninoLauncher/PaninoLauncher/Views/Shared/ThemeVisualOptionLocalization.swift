import SwiftUI

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
