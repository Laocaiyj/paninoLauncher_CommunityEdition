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

struct ResolvedThemeTokens {
    let selectionColor: Color
    let surfaceMaterial: Material?
    let surfaceFill: Color
    let surfaceFillOpacity: Double
    let surfaceVeilOpacity: Double
    let strokeColor: Color
    let strokeOpacity: Double
    let strokeWidth: CGFloat
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat
    let depthHighlightOpacity: Double
    let depthShadeOpacity: Double
    let depthRimOpacity: Double
    let panelCornerRadius: CGFloat
    let cardCornerRadius: CGFloat
    let controlCornerRadius: CGFloat
    let navigationCornerRadius: CGFloat
    let buttonMinHeight: CGFloat
    let backgroundBlurRadius: CGFloat
    let backgroundDimOpacity: Double
    let accentBackgroundOpacity: Double
    let textureOpacity: Double
    let animation: Animation?

    @MainActor
    init(
        theme: ThemeSettings,
        reduceTransparency: Bool = false,
        increasedContrast: Bool = false,
        reduceMotion: Bool = false
    ) {
        let contrast = min(max(theme.surfaceContrast, 0), 1)
        let frosting = min(max(theme.glassFrosting, 0), 1)
        let quiet = theme.quietModeEnabled || theme.visualNoiseReductionEnabled
        let materialWeight: Double
        switch theme.materialStrength {
        case .off:
            materialWeight = 0
        case .low:
            materialWeight = 0.30
        case .medium:
            materialWeight = 0.58
        case .high:
            materialWeight = 0.86
        }
        let styleWeight: Double
        switch theme.glassStyle {
        case .clear:
            styleWeight = 0.14
        case .automatic:
            styleWeight = materialWeight
        case .frosted:
            styleWeight = 0.74
        case .solid:
            styleWeight = 1
        }
        selectionColor = theme.accentColor
        surfaceFill = Color(nsColor: .windowBackgroundColor)
        surfaceFillOpacity = min(0.99, 0.34 + styleWeight * 0.34 + frosting * 0.20 + contrast * 0.16 + (quiet ? 0.12 : 0))
        surfaceVeilOpacity = min(0.78, 0.03 + styleWeight * 0.22 + frosting * 0.34 + contrast * 0.12 + (quiet ? 0.16 : 0))
        strokeColor = increasedContrast ? Color.primary : Color(nsColor: .separatorColor)
        strokeOpacity = increasedContrast ? 0.92 : 0.16 + contrast * 0.72
        strokeWidth = increasedContrast ? 1.5 : 0.75 + CGFloat(contrast) * 0.9
        panelCornerRadius = PaninoTokens.Radius.panel
        cardCornerRadius = PaninoTokens.Radius.card
        buttonMinHeight = theme.fontDensity.buttonMinHeight
        backgroundBlurRadius = theme.visualNoiseReductionEnabled ? 0 : 8 + CGFloat(theme.backgroundBlur) * 24
        backgroundDimOpacity = min(0.86, 0.34 + theme.backgroundDim * 0.44 + (quiet ? 0.08 : 0))
        accentBackgroundOpacity = increasedContrast ? 0.22 : 0.035 + contrast * 0.18
        textureOpacity = quiet || reduceTransparency || increasedContrast ? 0 : 0.008 + (1 - contrast) * 0.012

        switch theme.controlShape {
        case .roundedRect:
            controlCornerRadius = PaninoTokens.Radius.control
            navigationCornerRadius = 14
        case .capsule:
            controlCornerRadius = 999
            navigationCornerRadius = 999
        case .concentric:
            controlCornerRadius = 10
            navigationCornerRadius = 18
        }

        switch theme.depthStyle {
        case .flat:
            shadowOpacity = 0
            shadowRadius = 0
            shadowYOffset = 0
            depthHighlightOpacity = 0
            depthShadeOpacity = 0
            depthRimOpacity = 0
        case .soft:
            shadowOpacity = quiet ? 0.015 : 0.045
            shadowRadius = 12
            shadowYOffset = 5
            depthHighlightOpacity = 0
            depthShadeOpacity = 0
            depthRimOpacity = 0
        case .layered:
            shadowOpacity = quiet ? 0.025 : 0.07
            shadowRadius = 22
            shadowYOffset = 9
            depthHighlightOpacity = 0
            depthShadeOpacity = 0
            depthRimOpacity = 0
        case .retro:
            shadowOpacity = quiet ? 0.045 : 0.13
            shadowRadius = 26
            shadowYOffset = 12
            depthHighlightOpacity = quiet ? 0.035 : 0.08
            depthShadeOpacity = quiet ? 0.025 : 0.07
            depthRimOpacity = quiet ? 0.025 : 0.06
        }

        if reduceTransparency || quiet || theme.glassStyle == .solid || theme.materialStrength == .off {
            surfaceMaterial = nil
        } else {
            switch theme.glassStyle {
            case .automatic:
                surfaceMaterial = theme.effectiveMaterialStrength.material
            case .clear:
                switch theme.materialStrength {
                case .off:
                    surfaceMaterial = nil
                case .low:
                    surfaceMaterial = .ultraThinMaterial
                case .medium:
                    surfaceMaterial = .thinMaterial
                case .high:
                    surfaceMaterial = .regularMaterial
                }
            case .frosted:
                switch theme.materialStrength {
                case .off:
                    surfaceMaterial = nil
                case .low:
                    surfaceMaterial = .regularMaterial
                case .medium:
                    surfaceMaterial = .thickMaterial
                case .high:
                    surfaceMaterial = .ultraThickMaterial
                }
            case .solid:
                surfaceMaterial = nil
            }
        }

        if reduceMotion || theme.reducesInterfaceMotion {
            animation = nil
        } else if theme.motionStyle == .expressive {
            animation = PaninoMotion.page
        } else {
            animation = PaninoMotion.standard
        }
    }
}

extension ThemeSettings {
    var semanticSelectionColor: Color {
        accentColor
    }

    func resolvedTokens(
        reduceTransparency: Bool = false,
        increasedContrast: Bool = false,
        reduceMotion: Bool = false
    ) -> ResolvedThemeTokens {
        ResolvedThemeTokens(
            theme: self,
            reduceTransparency: reduceTransparency,
            increasedContrast: increasedContrast,
            reduceMotion: reduceMotion
        )
    }
}

private struct PaninoGlassSurfaceModifier: ViewModifier {
    let tokens: ResolvedThemeTokens
    let cornerRadius: CGFloat
    let interactive: Bool
    let tintOpacity: Double

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *), tokens.surfaceMaterial != nil {
            if interactive {
                content
                    .glassEffect(
                        .regular
                            .tint(tokens.selectionColor.opacity(tintOpacity))
                            .interactive(),
                        in: .rect(cornerRadius: cornerRadius)
                    )
            } else {
                content
                    .glassEffect(
                        .regular.tint(tokens.selectionColor.opacity(tintOpacity)),
                        in: .rect(cornerRadius: cornerRadius)
                    )
            }
        } else if let material = tokens.surfaceMaterial {
            content
                .background {
                    shape.fill(material)
                }
        } else {
            content
                .background {
                    shape.fill(tokens.surfaceFill.opacity(tokens.surfaceFillOpacity))
                }
        }
    }
}

private struct PaninoDepthOverlayModifier: ViewModifier {
    let tokens: ResolvedThemeTokens
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(tokens.depthHighlightOpacity),
                                Color.white.opacity(0),
                                Color.black.opacity(tokens.depthShadeOpacity)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .strokeBorder(Color.white.opacity(tokens.depthRimOpacity), lineWidth: max(1, tokens.strokeWidth))
                    .allowsHitTesting(false)
            }
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

    func paninoGlassSurface(
        tokens: ResolvedThemeTokens,
        cornerRadius: CGFloat? = nil,
        interactive: Bool = false,
        tintOpacity: Double = 0.08
    ) -> some View {
        modifier(PaninoGlassSurfaceModifier(
            tokens: tokens,
            cornerRadius: cornerRadius ?? tokens.panelCornerRadius,
            interactive: interactive,
            tintOpacity: tintOpacity
        ))
    }

    func paninoDepthOverlay(tokens: ResolvedThemeTokens, cornerRadius: CGFloat? = nil) -> some View {
        modifier(PaninoDepthOverlayModifier(
            tokens: tokens,
            cornerRadius: cornerRadius ?? tokens.panelCornerRadius
        ))
    }
}
