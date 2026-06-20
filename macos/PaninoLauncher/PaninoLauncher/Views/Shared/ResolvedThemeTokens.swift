import SwiftUI

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
        let glassStyle = theme.glassStyle
        let materialStrength = theme.materialStrength
        let effectiveMaterialStrength = theme.effectiveMaterialStrength
        let reducesInterfaceMotion = theme.reducesInterfaceMotion
        let motionStyle = theme.motionStyle
        let materialWeight = Self.materialWeight(for: materialStrength)
        let styleWeight = Self.styleWeight(for: glassStyle, materialWeight: materialWeight)

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

        let shapeTokens = Self.shapeTokens(for: theme.controlShape)
        controlCornerRadius = shapeTokens.controlCornerRadius
        navigationCornerRadius = shapeTokens.navigationCornerRadius

        let depthTokens = Self.depthTokens(for: theme.depthStyle, quiet: quiet)
        shadowOpacity = depthTokens.shadowOpacity
        shadowRadius = depthTokens.shadowRadius
        shadowYOffset = depthTokens.shadowYOffset
        depthHighlightOpacity = depthTokens.highlightOpacity
        depthShadeOpacity = depthTokens.shadeOpacity
        depthRimOpacity = depthTokens.rimOpacity

        surfaceMaterial = Self.surfaceMaterial(
            glassStyle: glassStyle,
            materialStrength: materialStrength,
            effectiveMaterialStrength: effectiveMaterialStrength,
            highContrast: highContrast,
            reduceTransparency: reduceTransparency,
            quiet: quiet
        )
        animation = Self.animation(
            reduceMotion: reduceMotion,
            reducesInterfaceMotion: reducesInterfaceMotion,
            motionStyle: motionStyle
        )
    }

    private static func materialWeight(for strength: MaterialStrength) -> Double {
        switch strength {
        case .off: return 0
        case .low: return 0.30
        case .medium: return 0.58
        case .high: return 0.86
        }
    }

    private static func styleWeight(for style: ThemeGlassStyle, materialWeight: Double) -> Double {
        switch style {
        case .clear: return 0.14
        case .automatic: return materialWeight
        case .frosted: return 0.74
        case .solid: return 1
        }
    }

    private static func shapeTokens(
        for shape: ThemeControlShape
    ) -> (controlCornerRadius: CGFloat, navigationCornerRadius: CGFloat) {
        switch shape {
        case .roundedRect:
            return (PaninoTokens.Radius.control, 14)
        case .capsule:
            return (999, 999)
        case .concentric:
            return (10, 18)
        }
    }

    private static func depthTokens(
        for depthStyle: ThemeDepthStyle,
        quiet: Bool
    ) -> (
        shadowOpacity: Double,
        shadowRadius: CGFloat,
        shadowYOffset: CGFloat,
        highlightOpacity: Double,
        shadeOpacity: Double,
        rimOpacity: Double
    ) {
        switch depthStyle {
        case .flat:
            return (0, 0, 0, 0, 0, 0)
        case .soft:
            return (
                quiet ? 0.015 : 0.055,
                14,
                5,
                quiet ? 0.015 : 0.035,
                quiet ? 0.010 : 0.026,
                quiet ? 0.012 : 0.030
            )
        case .layered:
            return (
                quiet ? 0.030 : 0.095,
                24,
                10,
                quiet ? 0.025 : 0.060,
                quiet ? 0.018 : 0.050,
                quiet ? 0.020 : 0.048
            )
        case .retro:
            return (
                quiet ? 0.045 : 0.13,
                26,
                12,
                quiet ? 0.035 : 0.08,
                quiet ? 0.025 : 0.07,
                quiet ? 0.025 : 0.06
            )
        }
    }

    private static func surfaceMaterial(
        glassStyle: ThemeGlassStyle,
        materialStrength: MaterialStrength,
        effectiveMaterialStrength: MaterialStrength,
        highContrast: Bool,
        reduceTransparency: Bool,
        quiet: Bool
    ) -> Material? {
        if highContrast || reduceTransparency || quiet || glassStyle == .solid || materialStrength == .off {
            return nil
        }

        switch glassStyle {
        case .automatic:
            return effectiveMaterialStrength.material
        case .clear:
            return clearMaterial(for: materialStrength)
        case .frosted:
            return frostedMaterial(for: materialStrength)
        case .solid:
            return nil
        }
    }

    private static func clearMaterial(for strength: MaterialStrength) -> Material? {
        switch strength {
        case .off: return nil
        case .low: return .ultraThinMaterial
        case .medium: return .thinMaterial
        case .high: return .regularMaterial
        }
    }

    private static func frostedMaterial(for strength: MaterialStrength) -> Material? {
        switch strength {
        case .off: return nil
        case .low: return .regularMaterial
        case .medium: return .thickMaterial
        case .high: return .ultraThickMaterial
        }
    }

    private static func animation(
        reduceMotion: Bool,
        reducesInterfaceMotion: Bool,
        motionStyle: ThemeMotionStyle
    ) -> Animation? {
        if reduceMotion || reducesInterfaceMotion {
            return nil
        }
        if motionStyle == .expressive {
            return PaninoMotion.page
        }
        return PaninoMotion.standard
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
