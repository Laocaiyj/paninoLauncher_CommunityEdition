import SwiftUI

struct TopNavigationItem: View {
    let title: String
    let isSelected: Bool
    let tokens: ResolvedThemeTokens
    let chromeStyle: ThemeChromeStyle
    let action: () -> Void

    @EnvironmentObject private var theme: ThemeSettings
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minWidth: 144, minHeight: PaninoTokens.Layout.controlMinSize)
                .contentShape(RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background {
            let shape = RoundedRectangle(cornerRadius: tokens.controlCornerRadius, style: .continuous)
            if isSelected {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                tokens.selectionColor.opacity(0.96),
                                tokens.selectionColor.opacity(0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        shape
                            .strokeBorder(Color.white.opacity(0.30), lineWidth: 1)
                    }
                    .overlay(alignment: .top) {
                        shape
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            .blendMode(.plusLighter)
                    }
                    .shadow(
                        color: tokens.selectionColor.opacity(chromeStyle == .floatingToolbar ? 0.34 : 0.18),
                        radius: chromeStyle == .floatingToolbar ? 12 : 6,
                        x: 0,
                        y: chromeStyle == .floatingToolbar ? 4 : 2
                    )
            } else {
                shape
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.24 : 0))
                    .overlay {
                        shape
                            .strokeBorder(Color.white.opacity(isHovering ? tokens.depthRimOpacity * 0.90 : 0), lineWidth: 1)
                    }
            }
        }
        .onHover { hovering in
            withAnimation(PaninoMotion.noneWhenReduced(PaninoMotion.fast, reduceMotion: theme.reducesInterfaceMotion)) {
                isHovering = hovering
            }
        }
        .accessibilityLabel(title)
        .help(title)
    }
}

struct LauncherHorizontalDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.45))
            .frame(height: 1)
    }
}
