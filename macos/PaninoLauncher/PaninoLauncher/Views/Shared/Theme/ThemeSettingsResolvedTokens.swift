import SwiftUI

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
