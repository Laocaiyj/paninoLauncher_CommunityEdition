import SwiftUI

extension ResolvedThemeTokens {
    static func materialWeight(for strength: MaterialStrength) -> Double {
        switch strength {
        case .off: return 0
        case .low: return 0.30
        case .medium: return 0.58
        case .high: return 0.86
        }
    }

    static func styleWeight(for style: ThemeGlassStyle, materialWeight: Double) -> Double {
        switch style {
        case .clear: return 0.14
        case .automatic: return materialWeight
        case .frosted: return 0.74
        case .solid: return 1
        }
    }

    static func shapeTokens(
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

    static func depthTokens(
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

    static func surfaceMaterial(
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

    static func animation(
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
}
