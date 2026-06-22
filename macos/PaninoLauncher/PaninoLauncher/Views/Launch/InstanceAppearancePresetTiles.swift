import SwiftUI

struct InstanceAppearanceColorPresetTile: View {
    let preset: InstanceAppearanceColorPreset
    let isSelected: Bool

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.paninoHex(preset.hex, fallback: theme.semanticSelectionColor))
                .frame(width: 28, height: 28)
            Text(preset.title(language: theme.language))
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tileBorder, lineWidth: 1)
        }
    }

    private var tileBackground: Color {
        isSelected ? theme.semanticSelectionColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.32)
    }

    private var tileBorder: Color {
        isSelected ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.35)
    }
}

struct InstanceAppearanceIconPresetTile: View {
    let preset: InstanceAppearanceIconPreset
    let isSelected: Bool
    let tint: Color

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: preset.systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
            Text(preset.title(language: theme.language))
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 66)
        .background(tileBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tileBorder, lineWidth: 1)
        }
    }

    private var tileBackground: Color {
        isSelected ? theme.semanticSelectionColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.32)
    }

    private var tileBorder: Color {
        isSelected ? theme.semanticSelectionColor.opacity(0.75) : Color(nsColor: .separatorColor).opacity(0.35)
    }
}
