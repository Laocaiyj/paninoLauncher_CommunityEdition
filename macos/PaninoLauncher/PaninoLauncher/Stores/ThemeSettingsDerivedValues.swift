import SwiftUI

extension ThemeSettings {
    var accentColor: Color {
        if accent == .custom {
            return Color.paninoHex(customAccentHex, fallback: .red)
        }
        return accent.color ?? Color.accentColor
    }

    var effectiveMaterialStrength: MaterialStrength {
        quietModeEnabled ? .off : materialStrength
    }

    var effectiveBackgroundMode: ThemeBackgroundMode {
        quietModeEnabled ? .solidColor : backgroundMode
    }

    var effectiveSoftBackgroundEnabled: Bool {
        !quietModeEnabled && !visualNoiseReductionEnabled && softBackgroundEnabled
    }

    var reducesInterfaceMotion: Bool {
        quietModeEnabled || motionStyle == .reduced
    }

    static func normalizedCustomAccentHex(_ value: String) -> String {
        let normalized = value.normalizedHex
        return normalized.isEmpty ? "#FF4F5E" : normalized
    }
}
