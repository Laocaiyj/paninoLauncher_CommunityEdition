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

}
