import SwiftUI

struct LaunchHeroTextButton: View {
    let title: String
    var prominent = false
    var minWidth: CGFloat = 112
    var minHeight: CGFloat = 52
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, prominent ? 30 : 26)
                .frame(minWidth: minWidth, minHeight: minHeight)
        }
        .buttonStyle(
            LaunchHeroTextButtonStyle(
                prominent: prominent,
                accentColor: theme.semanticSelectionColor,
                material: reduceTransparency ? nil : theme.effectiveMaterialStrength.material,
                reduceMotion: reduceMotion || theme.reducesInterfaceMotion
            )
        )
        .opacity(isEnabled ? 1 : 0.56)
        .accessibilityLabel(title)
    }
}

private struct LaunchHeroTextButtonStyle: ButtonStyle {
    let prominent: Bool
    let accentColor: Color
    let material: Material?
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? .white : .primary)
            .background {
                background(isPressed: configuration.isPressed)
            }
            .clipShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: reduceMotion), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: PaninoTokens.Radius.control, style: .continuous)
        if prominent {
            shape.fill(accentColor.opacity(isPressed ? 0.82 : 0.96))
        } else if let material {
            shape.fill(material)
            shape.strokeBorder(Color(nsColor: .separatorColor).opacity(0.48))
        } else {
            shape.fill(Color(nsColor: .controlBackgroundColor).opacity(isPressed ? 0.82 : 1))
            shape.strokeBorder(Color(nsColor: .separatorColor).opacity(0.7))
        }
    }
}
