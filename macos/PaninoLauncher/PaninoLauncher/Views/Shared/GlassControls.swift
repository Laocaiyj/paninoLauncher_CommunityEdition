import SwiftUI

struct GlassButton: View {
    var systemImage: String? = nil
    let title: String
    var prominent = false
    let action: () -> Void

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
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .lineLimit(1)
                    .labelStyle(.titleAndIcon)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                Text(title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .buttonStyle(
            GlassControlButtonStyle(
                prominent: prominent,
                tokens: tokens,
                density: theme.fontDensity,
                reduceMotion: reduceMotion || theme.reducesInterfaceMotion
            )
        )
        .accessibilityLabel(title)
        .help(title)
    }
}

private struct GlassControlButtonStyle: ButtonStyle {
    let prominent: Bool
    let tokens: ResolvedThemeTokens
    let density: FontDensity
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .padding(.horizontal, density.buttonHorizontalPadding)
            .frame(minHeight: tokens.buttonMinHeight)
            .foregroundStyle(prominent ? .white : .primary)
            .background {
                buttonBackground(isPressed: configuration.isPressed)
            }
            .clipShape(RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous))
            .overlay {
                if !prominent {
                    RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
                        .strokeBorder(tokens.strokeColor.opacity(tokens.strokeOpacity * 0.75), lineWidth: tokens.strokeWidth)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(PaninoMotion.noneWhenReduced(tokens.animation ?? PaninoMotion.fast, reduceMotion: reduceMotion), value: configuration.isPressed)
    }

    @ViewBuilder
    private func buttonBackground(isPressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
        if prominent {
            shape.fill(tokens.selectionColor.opacity(isPressed ? 0.82 : 0.94))
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                }
        } else if let material = tokens.surfaceMaterial {
            shape.fill(material)
                .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.72))
                .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.65))
        } else {
            shape.fill(tokens.surfaceFill.opacity(tokens.surfaceFillOpacity))
                .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.45))
        }
    }
}

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
