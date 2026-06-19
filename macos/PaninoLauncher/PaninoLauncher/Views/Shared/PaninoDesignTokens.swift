import SwiftUI

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
        let highContrast = theme.appearance == .highContrast || increasedContrast
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
        selectionColor = theme.semanticSelectionColor
        surfaceFill = highContrast ? Color(nsColor: .textBackgroundColor) : Color(nsColor: .windowBackgroundColor)
        surfaceFillOpacity = highContrast
            ? 0.94
            : min(0.99, 0.34 + styleWeight * 0.34 + frosting * 0.20 + contrast * 0.16 + (quiet ? 0.12 : 0))
        surfaceVeilOpacity = highContrast
            ? 0.82
            : min(0.78, 0.03 + styleWeight * 0.22 + frosting * 0.34 + contrast * 0.12 + (quiet ? 0.16 : 0))
        strokeColor = highContrast ? Color.primary : Color(nsColor: .separatorColor)
        strokeOpacity = highContrast ? 0.98 : 0.16 + contrast * 0.72
        strokeWidth = highContrast ? 1.8 : 0.75 + CGFloat(contrast) * 0.9
        panelCornerRadius = PaninoTokens.Radius.panel
        cardCornerRadius = PaninoTokens.Radius.card
        buttonMinHeight = theme.fontDensity.buttonMinHeight
        backgroundBlurRadius = theme.visualNoiseReductionEnabled ? 0 : 8 + CGFloat(theme.backgroundBlur) * 24
        backgroundDimOpacity = highContrast ? 0.92 : min(0.86, 0.34 + theme.backgroundDim * 0.44 + (quiet ? 0.08 : 0))
        accentBackgroundOpacity = highContrast ? 0.30 : 0.035 + contrast * 0.18
        textureOpacity = quiet || reduceTransparency || highContrast ? 0 : 0.008 + (1 - contrast) * 0.012

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
            shadowOpacity = quiet ? 0.015 : 0.055
            shadowRadius = 14
            shadowYOffset = 5
            depthHighlightOpacity = quiet ? 0.015 : 0.035
            depthShadeOpacity = quiet ? 0.010 : 0.026
            depthRimOpacity = quiet ? 0.012 : 0.030
        case .layered:
            shadowOpacity = quiet ? 0.030 : 0.095
            shadowRadius = 24
            shadowYOffset = 10
            depthHighlightOpacity = quiet ? 0.025 : 0.060
            depthShadeOpacity = quiet ? 0.018 : 0.050
            depthRimOpacity = quiet ? 0.020 : 0.048
        case .retro:
            shadowOpacity = quiet ? 0.045 : 0.13
            shadowRadius = 26
            shadowYOffset = 12
            depthHighlightOpacity = quiet ? 0.035 : 0.08
            depthShadeOpacity = quiet ? 0.025 : 0.07
            depthRimOpacity = quiet ? 0.025 : 0.06
        }

        if highContrast || reduceTransparency || quiet || theme.glassStyle == .solid || theme.materialStrength == .off {
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

enum PaninoSurfaceLevel {
    case background
    case panel
    case elevatedPanel
    case floatingChrome
    case popover

    var veilMultiplier: Double {
        switch self {
        case .background: return 0.52
        case .panel: return 1.00
        case .elevatedPanel: return 0.82
        case .floatingChrome: return 0.64
        case .popover: return 0.72
        }
    }

    var fillOpacityMultiplier: Double {
        switch self {
        case .background: return 0.58
        case .panel: return 1.00
        case .elevatedPanel: return 0.88
        case .floatingChrome: return 0.74
        case .popover: return 0.92
        }
    }

    var accentMultiplier: Double {
        switch self {
        case .background: return 0.34
        case .panel: return 0.55
        case .elevatedPanel: return 0.70
        case .floatingChrome: return 0.86
        case .popover: return 0.76
        }
    }

    var tintOpacity: Double {
        switch self {
        case .background: return 0.025
        case .panel: return 0.070
        case .elevatedPanel: return 0.095
        case .floatingChrome: return 0.120
        case .popover: return 0.105
        }
    }

    var strokeMultiplier: Double {
        switch self {
        case .background: return 0.42
        case .panel: return 1.00
        case .elevatedPanel: return 1.12
        case .floatingChrome: return 1.24
        case .popover: return 1.18
        }
    }

    var shadowMultiplier: Double {
        switch self {
        case .background: return 0.20
        case .panel: return 1.00
        case .elevatedPanel: return 1.18
        case .floatingChrome: return 1.42
        case .popover: return 1.30
        }
    }

    var shadowRadiusMultiplier: CGFloat {
        switch self {
        case .background: return 0.40
        case .panel: return 1.00
        case .elevatedPanel: return 1.12
        case .floatingChrome: return 1.28
        case .popover: return 1.22
        }
    }

    var shadowYOffsetMultiplier: CGFloat {
        switch self {
        case .background: return 0.35
        case .panel: return 1.00
        case .elevatedPanel: return 1.14
        case .floatingChrome: return 1.30
        case .popover: return 1.22
        }
    }

    var highlightMultiplier: Double {
        switch self {
        case .background: return 0.42
        case .panel: return 1.00
        case .elevatedPanel: return 1.22
        case .floatingChrome: return 1.45
        case .popover: return 1.32
        }
    }

    var shadeMultiplier: Double {
        switch self {
        case .background: return 0.42
        case .panel: return 1.00
        case .elevatedPanel: return 1.16
        case .floatingChrome: return 1.34
        case .popover: return 1.24
        }
    }
}

extension ThemeSettings {
    var semanticSelectionColor: Color {
        if appearance == .highContrast {
            return Color.paninoHex("FFD43B", fallback: .yellow)
        }
        return accentColor
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
