import SwiftUI

private struct PaninoGlassCardModifier: ViewModifier {
    var isSelected = false
    var level: PaninoSurfaceLevel = .panel
    var cornerRadius: CGFloat = PaninoTokens.Radius.card
    var tint: Color?
    var showsShadow = false

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        let tokens = theme.resolvedTokens(
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased,
            reduceMotion: reduceMotion
        )
        let accent = tint ?? tokens.selectionColor
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape
                    .fill(Color.clear)
                    .paninoGlassSurface(tokens: tokens, level: level, cornerRadius: cornerRadius)
                    .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * level.veilMultiplier * 0.72))
                    .overlay(accent.opacity(isSelected ? max(tokens.accentBackgroundOpacity * 1.05, 0.12) : tokens.accentBackgroundOpacity * 0.25))
                    .paninoDepthOverlay(tokens: tokens, level: level, cornerRadius: cornerRadius)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(
                    (isSelected ? accent : tokens.strokeColor)
                        .opacity(isSelected ? min(0.82, tokens.strokeOpacity * 2.2) : min(0.72, tokens.strokeOpacity * level.strokeMultiplier)),
                    lineWidth: tokens.strokeWidth
                )
            }
            .shadow(
                color: Color.black.opacity(showsShadow ? tokens.shadowOpacity * level.shadowMultiplier * 0.72 : 0),
                radius: showsShadow ? tokens.shadowRadius * level.shadowRadiusMultiplier * 0.72 : 0,
                x: 0,
                y: showsShadow ? tokens.shadowYOffset * level.shadowYOffsetMultiplier : 0
            )
    }
}

extension View {
    func paninoGlassCard(
        isSelected: Bool = false,
        level: PaninoSurfaceLevel = .panel,
        cornerRadius: CGFloat = PaninoTokens.Radius.card,
        tint: Color? = nil,
        showsShadow: Bool = false
    ) -> some View {
        modifier(PaninoGlassCardModifier(
            isSelected: isSelected,
            level: level,
            cornerRadius: cornerRadius,
            tint: tint,
            showsShadow: showsShadow
        ))
    }
}
