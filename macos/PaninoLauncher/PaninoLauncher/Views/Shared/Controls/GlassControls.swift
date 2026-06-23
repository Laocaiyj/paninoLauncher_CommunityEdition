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
