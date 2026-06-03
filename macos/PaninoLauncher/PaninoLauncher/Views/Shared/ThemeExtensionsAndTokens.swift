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

enum PaninoTokens {
    enum Window {
        static let minimumWidth: CGFloat = 1280
        static let minimumHeight: CGFloat = 760
        static let minimumMainWidth: CGFloat = 680
    }

    enum Layout {
        static let contentMaxWidth: CGFloat = 1120
        static let contentWideMaxWidth: CGFloat = 1680
        static let contentReadableMaxWidth: CGFloat = 1040
        static let inspectorWidth: CGFloat = 360
        static let sectionSpacing: CGFloat = 16
        static let sectionInnerSpacing: CGFloat = 10
        static let pageTopSpacing: CGFloat = 24
        static let rowHeightCompact: CGFloat = 64
        static let rowHeightComfortable: CGFloat = 92
        static let shelfCardWidth: CGFloat = 188
        static let heroMinHeight: CGFloat = 420
        static let pageHorizontalPadding: CGFloat = 32
        static let compactPageHorizontalPadding: CGFloat = 20
        static let cardSpacing: CGFloat = 22
        static let secondarySidebarWidth: CGFloat = 212
        static let compactResultRowHeight: CGFloat = 68
        static let instanceCardHeight: CGFloat = 84
        static let controlMinSize: CGFloat = 36
        static let primaryButtonMinHeight: CGFloat = 44
        static let topNavigationHeight: CGFloat = 54

        static func contentWidth(for availableWidth: CGFloat) -> CGFloat {
            if availableWidth >= 2200 {
                return min(availableWidth - 220, 1880)
            }
            if availableWidth >= 1800 {
                return min(availableWidth - 160, contentWideMaxWidth)
            }
            if availableWidth >= 1440 {
                return min(availableWidth - 96, 1480)
            }
            if availableWidth >= 1280 {
                return 1120
            }
            return max(availableWidth - compactPageHorizontalPadding * 2, 680)
        }

        static func pagePadding(for availableWidth: CGFloat) -> CGFloat {
            availableWidth < 960 ? compactPageHorizontalPadding : pageHorizontalPadding
        }
    }

    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 8
        static let panel: CGFloat = 12
    }

    enum Shadow {
        static let panelOpacity: Double = 0.08
    }
}

enum PaninoLimits {
    static let memoryMb = 1024...16384
}

enum PaninoMotion {
    static let fast = Animation.interpolatingSpring(stiffness: 360, damping: 34)
    static let standard = Animation.interpolatingSpring(stiffness: 260, damping: 30)
    static let page = Animation.interpolatingSpring(stiffness: 220, damping: 32)

    static func noneWhenReduced(_ animation: Animation = standard, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

extension ThemeSettings {
    var semanticSelectionColor: Color {
        accentColor
    }
}

enum PaninoTextTruncation {
    case path
    case hash
    case title
    case summary(lines: Int = 2)
}

private struct PaninoTruncationModifier: ViewModifier {
    let style: PaninoTextTruncation

    func body(content: Content) -> some View {
        switch style {
        case .path, .hash:
            content
                .lineLimit(1)
                .truncationMode(.middle)
        case .title:
            content
                .lineLimit(1)
                .truncationMode(.tail)
        case .summary(let lines):
            content
                .lineLimit(lines)
                .truncationMode(.tail)
        }
    }
}

extension View {
    func paninoTruncation(_ style: PaninoTextTruncation) -> some View {
        modifier(PaninoTruncationModifier(style: style))
    }
}
