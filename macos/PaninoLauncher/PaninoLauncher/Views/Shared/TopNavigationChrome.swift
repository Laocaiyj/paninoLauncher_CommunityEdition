import SwiftUI

struct TopChromeBackground: View {
    let tokens: ResolvedThemeTokens
    let chromeStyle: ThemeChromeStyle
    let semanticSelectionColor: Color
    let reduceTransparency: Bool
    let increasedContrast: Bool

    var body: some View {
        if reduceTransparency || increasedContrast {
            Color(nsColor: .windowBackgroundColor)
                .opacity(increasedContrast ? 1.0 : 0.96)
                .overlay(semanticSelectionColor.opacity(increasedContrast ? 0.03 : 0.06))
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(tokens.strokeColor.opacity(max(0.44, tokens.strokeOpacity)))
                        .frame(height: tokens.strokeWidth)
                }
        } else {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.12)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.12),
                        tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.18),
                        Color.black.opacity(0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if chromeStyle == .edgeToEdgeSidebar {
                    Rectangle()
                        .fill(semanticSelectionColor.opacity(0.07))
                        .frame(width: 184)
                }
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(tokens.depthHighlightOpacity * 0.36))
                    .blendMode(.plusLighter)
                    .frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(tokens.strokeColor.opacity(max(0.28, tokens.strokeOpacity * 0.58)))
                    .frame(height: tokens.strokeWidth)
            }
        }
    }
}

struct TopNavigationBrandBackground: View {
    let tokens: ResolvedThemeTokens
    let chromeStyle: ThemeChromeStyle

    var body: some View {
        if chromeStyle == .floatingToolbar {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.clear)
                .paninoGlassSurface(
                    tokens: tokens,
                    level: .floatingChrome,
                    cornerRadius: 18,
                    interactive: true
                )
                .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.30))
                .paninoDepthOverlay(tokens: tokens, level: .floatingChrome, cornerRadius: 18)
        }
    }
}

struct TopNavigationContainerBackground: View {
    let tokens: ResolvedThemeTokens
    let chromeStyle: ThemeChromeStyle
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch chromeStyle {
        case .integrated:
            shape
                .fill(Color.clear)
                .paninoGlassSurface(
                    tokens: tokens,
                    level: .elevatedPanel,
                    cornerRadius: cornerRadius,
                    interactive: true
                )
                .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.38))
                .paninoDepthOverlay(tokens: tokens, level: .elevatedPanel, cornerRadius: cornerRadius)
                .clipShape(shape)
        case .floatingToolbar:
            shape
                .fill(Color.clear)
                .paninoGlassSurface(
                    tokens: tokens,
                    level: .floatingChrome,
                    cornerRadius: cornerRadius,
                    interactive: true
                )
                .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * 0.36))
                .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.54))
                .paninoDepthOverlay(tokens: tokens, level: .floatingChrome, cornerRadius: cornerRadius)
                .clipShape(shape)
        case .edgeToEdgeSidebar:
            shape
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.20))
                .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.28))
                .paninoDepthOverlay(tokens: tokens, level: .elevatedPanel, cornerRadius: cornerRadius)
                .clipShape(shape)
        }
    }
}

enum TopNavigationChrome {
    static func containerCornerRadius(tokens: ResolvedThemeTokens, chromeStyle: ThemeChromeStyle) -> CGFloat {
        switch chromeStyle {
        case .integrated:
            return min(tokens.navigationCornerRadius, 14)
        case .floatingToolbar:
            return tokens.navigationCornerRadius
        case .edgeToEdgeSidebar:
            return min(tokens.navigationCornerRadius, 12)
        }
    }

    static func containerStrokeOpacity(tokens: ResolvedThemeTokens, chromeStyle: ThemeChromeStyle) -> Double {
        switch chromeStyle {
        case .integrated:
            return 0
        case .floatingToolbar:
            return tokens.strokeOpacity * 0.78
        case .edgeToEdgeSidebar:
            return tokens.strokeOpacity * 0.46
        }
    }

    static func containerShadowOpacity(tokens: ResolvedThemeTokens, chromeStyle: ThemeChromeStyle) -> Double {
        switch chromeStyle {
        case .integrated:
            return tokens.shadowOpacity * 0.28
        case .floatingToolbar:
            return tokens.shadowOpacity * PaninoSurfaceLevel.floatingChrome.shadowMultiplier
        case .edgeToEdgeSidebar:
            return tokens.shadowOpacity * 0.35
        }
    }

    static func containerShadowRadius(tokens: ResolvedThemeTokens, chromeStyle: ThemeChromeStyle) -> CGFloat {
        chromeStyle == .floatingToolbar ? tokens.shadowRadius * 0.92 : tokens.shadowRadius * 0.35
    }

    static func containerShadowYOffset(tokens: ResolvedThemeTokens, chromeStyle: ThemeChromeStyle) -> CGFloat {
        chromeStyle == .floatingToolbar ? tokens.shadowYOffset * 0.72 : tokens.shadowYOffset * 0.26
    }

    static func brandShadowOpacity(tokens: ResolvedThemeTokens, chromeStyle: ThemeChromeStyle) -> Double {
        chromeStyle == .floatingToolbar ? tokens.shadowOpacity * 0.35 : 0
    }

    static func brandShadowRadius(tokens: ResolvedThemeTokens, chromeStyle: ThemeChromeStyle) -> CGFloat {
        chromeStyle == .floatingToolbar ? tokens.shadowRadius * 0.38 : 0
    }

    static func brandShadowYOffset(tokens: ResolvedThemeTokens, chromeStyle: ThemeChromeStyle) -> CGFloat {
        chromeStyle == .floatingToolbar ? tokens.shadowYOffset * 0.28 : 0
    }
}
