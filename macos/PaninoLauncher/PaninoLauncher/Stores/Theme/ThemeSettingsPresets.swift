import Foundation

extension ThemeSettings {
    func applyPreset(_ preset: ThemePreset) {
        currentPreset = preset
        switch preset {
        case .vanilla:
            accent = .emerald
            materialStrength = .medium
            backgroundMode = .default
            fontDensity = .standard
            glassStyle = .automatic
            chromeStyle = .floatingToolbar
            depthStyle = .soft
            controlShape = .roundedRect
            motionStyle = .system
            glassFrosting = 0.52
            backgroundBlur = 0.36
            backgroundDim = 0.48
            surfaceContrast = 0.42
            visualNoiseReductionEnabled = false
        case .nether:
            accent = .red
            materialStrength = .low
            backgroundMode = .solidColor
            fontDensity = .standard
            glassStyle = .frosted
            chromeStyle = .floatingToolbar
            depthStyle = .soft
            controlShape = .roundedRect
            motionStyle = .system
            glassFrosting = 0.66
            backgroundBlur = 0.40
            backgroundDim = 0.62
            surfaceContrast = 0.52
            visualNoiseReductionEnabled = false
        case .deepDark:
            appearance = .dark
            accent = .purple
            materialStrength = .high
            backgroundMode = .currentInstance
            fontDensity = .compact
            glassStyle = .frosted
            chromeStyle = .integrated
            depthStyle = .layered
            controlShape = .roundedRect
            motionStyle = .system
            glassFrosting = 0.72
            backgroundBlur = 0.58
            backgroundDim = 0.68
            surfaceContrast = 0.60
            visualNoiseReductionEnabled = false
        case .liquidGlass:
            appearance = .system
            accent = .red
            materialStrength = .medium
            backgroundMode = .currentInstance
            fontDensity = .standard
            glassStyle = .clear
            chromeStyle = .floatingToolbar
            depthStyle = .layered
            controlShape = .concentric
            motionStyle = .expressive
            glassFrosting = 0.42
            backgroundBlur = 0.44
            backgroundDim = 0.50
            surfaceContrast = 0.44
            visualNoiseReductionEnabled = false
        case .frostedGraphite:
            appearance = .system
            accent = .slate
            materialStrength = .high
            backgroundMode = .default
            fontDensity = .standard
            glassStyle = .frosted
            chromeStyle = .floatingToolbar
            depthStyle = .soft
            controlShape = .roundedRect
            motionStyle = .system
            glassFrosting = 0.82
            backgroundBlur = 0.62
            backgroundDim = 0.58
            surfaceContrast = 0.56
            visualNoiseReductionEnabled = true
        case .minecraftAmbient:
            appearance = .system
            accent = .emerald
            materialStrength = .medium
            backgroundMode = .currentInstance
            fontDensity = .comfortable
            glassStyle = .frosted
            chromeStyle = .floatingToolbar
            depthStyle = .layered
            controlShape = .roundedRect
            motionStyle = .expressive
            glassFrosting = 0.56
            backgroundBlur = 0.50
            backgroundDim = 0.52
            surfaceContrast = 0.46
            visualNoiseReductionEnabled = false
        case .focusSolid:
            appearance = .system
            accent = .blue
            materialStrength = .off
            backgroundMode = .solidColor
            fontDensity = .compact
            glassStyle = .solid
            chromeStyle = .integrated
            depthStyle = .flat
            controlShape = .roundedRect
            motionStyle = .reduced
            glassFrosting = 1
            backgroundBlur = 0
            backgroundDim = 0.74
            surfaceContrast = 0.70
            visualNoiseReductionEnabled = true
        case .highLegibility:
            appearance = .highContrast
            accent = .amber
            materialStrength = .off
            backgroundMode = .solidColor
            fontDensity = .comfortable
            glassStyle = .solid
            chromeStyle = .integrated
            depthStyle = .flat
            controlShape = .roundedRect
            motionStyle = .reduced
            glassFrosting = 1
            backgroundBlur = 0
            backgroundDim = 0.80
            surfaceContrast = 0.86
            visualNoiseReductionEnabled = true
        }
    }
}
