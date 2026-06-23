import SwiftUI

struct GlassPanel<Content: View>: View {
    var showsShadow = true
    var surfaceLevel: PaninoSurfaceLevel = .panel
    @ViewBuilder let content: Content

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    init(
        showsShadow: Bool = true,
        surfaceLevel: PaninoSurfaceLevel = .panel,
        @ViewBuilder content: () -> Content
    ) {
        self.showsShadow = showsShadow
        self.surfaceLevel = surfaceLevel
        self.content = content()
    }

    var body: some View {
        let tokens = theme.resolvedTokens(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion
        )
        content
            .padding(theme.fontDensity.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: tokens.panelCornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .paninoGlassSurface(
                        tokens: tokens,
                        level: surfaceLevel,
                        cornerRadius: tokens.panelCornerRadius
                    )
                    .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * surfaceLevel.veilMultiplier))
                    .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * surfaceLevel.accentMultiplier))
                    .paninoDepthOverlay(tokens: tokens, level: surfaceLevel, cornerRadius: tokens.panelCornerRadius)
            }
            .clipShape(RoundedRectangle(cornerRadius: tokens.panelCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: tokens.panelCornerRadius, style: .continuous)
                    .strokeBorder(
                        tokens.strokeColor.opacity(min(1, tokens.strokeOpacity * surfaceLevel.strokeMultiplier)),
                        lineWidth: tokens.strokeWidth
                    )
            }
            .shadow(
                color: Color.black.opacity(showsShadow ? tokens.shadowOpacity * surfaceLevel.shadowMultiplier : 0),
                radius: showsShadow ? tokens.shadowRadius * surfaceLevel.shadowRadiusMultiplier : 0,
                x: 0,
                y: showsShadow ? tokens.shadowYOffset * surfaceLevel.shadowYOffsetMultiplier : 0
            )
    }
}
