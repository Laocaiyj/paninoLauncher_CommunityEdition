import SwiftUI

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
