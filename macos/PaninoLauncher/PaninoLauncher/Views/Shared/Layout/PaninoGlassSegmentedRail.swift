import SwiftUI

struct PaninoGlassSegmentedRail<Content: View>: View {
    var level: PaninoSurfaceLevel = .floatingChrome
    var cornerRadius: CGFloat = PaninoTokens.Radius.control + 6
    @ViewBuilder let content: Content

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        let tokens = theme.resolvedTokens(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion
        )
        content
            .padding(4)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .paninoGlassSurface(tokens: tokens, level: level, cornerRadius: cornerRadius)
                    .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * level.veilMultiplier * 0.55))
                    .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.18))
                    .paninoDepthOverlay(tokens: tokens, level: level, cornerRadius: cornerRadius)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(tokens.strokeColor.opacity(min(0.65, tokens.strokeOpacity * level.strokeMultiplier)), lineWidth: tokens.strokeWidth)
            }
    }
}
