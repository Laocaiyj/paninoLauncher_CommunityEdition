import SwiftUI

struct AppearanceSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(alignment: .leading, spacing: theme.fontDensity.spacing) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)
            content
        }
        .padding(.top, 2)
    }
}

struct ThemeSliderRow: View {
    let title: String
    let systemImage: String
    @Binding var value: Double
    var disabled = false

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        SettingsRow(title: title, systemImage: systemImage) {
            HStack(spacing: 10) {
                Slider(value: $value, in: 0...1, step: 0.01)
                    .frame(minWidth: 240, maxWidth: 420)
                Text("\(Int((value * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .disabled(disabled)
            .opacity(disabled ? 0.45 : 1)
        }
    }
}

struct AccentSwatchButton: View {
    let accent: ThemeAccentColor
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        let tokens = theme.resolvedTokens()
        Button(action: action) {
            HStack(spacing: 8) {
                swatch
                Text(accent.title(language: theme.language))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.semanticSelectionColor)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(buttonBackground, in: RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
                    .stroke(isSelected ? theme.semanticSelectionColor.opacity(0.82) : Color(nsColor: .separatorColor).opacity(0.5), lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accent.title(language: theme.language))
    }

    @ViewBuilder
    private var swatch: some View {
        if accent == .custom {
            Circle()
                .fill(Color.paninoHex(theme.customAccentHex, fallback: .red))
                .frame(width: 16, height: 16)
        } else if let color = accent.color {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
        } else {
            Circle()
                .fill(
                    AngularGradient(
                        colors: [.blue, .purple, .red, .orange, .green, .blue],
                        center: .center
                    )
                )
                .frame(width: 16, height: 16)
        }
    }

    private var buttonBackground: Color {
        if isSelected {
            return theme.semanticSelectionColor.opacity(0.14)
        }
        return Color(nsColor: .controlBackgroundColor).opacity(0.35)
    }
}
