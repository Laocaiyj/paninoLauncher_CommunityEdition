import AppKit
import SwiftUI

struct TopNavigationBar: View {
    @Binding var selection: LauncherSection?
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

        GeometryReader { proxy in
            let horizontalPadding = PaninoTokens.Layout.pagePadding(for: proxy.size.width)
            let navigationCornerRadius = navigationContainerCornerRadius(tokens: tokens)
            let leadingPadding = max(horizontalPadding, titlebarControlReserve(for: proxy.size.width))

            HStack(spacing: 16) {
                HStack(spacing: 10) {
                    PaninoBrandMark(size: 32, cornerRadius: PaninoTokens.Radius.control)

                    if proxy.size.width >= 720 {
                        Text("Panino")
                            .font(.headline.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, proxy.size.width >= 720 ? 10 : 6)
                .frame(minHeight: 46)
                .background {
                    if theme.chromeStyle == .floatingToolbar {
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
                .shadow(
                    color: Color.black.opacity(theme.chromeStyle == .floatingToolbar ? tokens.shadowOpacity * 0.35 : 0),
                    radius: theme.chromeStyle == .floatingToolbar ? tokens.shadowRadius * 0.38 : 0,
                    x: 0,
                    y: theme.chromeStyle == .floatingToolbar ? tokens.shadowYOffset * 0.28 : 0
                )

                HStack(spacing: 4) {
                    ForEach(LauncherSection.primaryCases) { section in
                        TopNavigationItem(
                            title: section.title(language: theme.language),
                            isSelected: (selection ?? .launch).primaryParent == section,
                            tokens: tokens,
                            chromeStyle: theme.chromeStyle
                        ) {
                            selection = section
                        }
                    }
                }
                .padding(theme.chromeStyle == .integrated ? 2 : 4)
                .background {
                    navigationContainerBackground(tokens: tokens, cornerRadius: navigationCornerRadius)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: navigationCornerRadius, style: .continuous)
                        .strokeBorder(
                            tokens.strokeColor.opacity(navigationStrokeOpacity(tokens: tokens)),
                            lineWidth: tokens.strokeWidth
                        )
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: navigationCornerRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(tokens.depthHighlightOpacity * 1.65), lineWidth: 1)
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(Color.black.opacity(tokens.depthShadeOpacity * 1.15))
                        .frame(height: 1)
                        .padding(.horizontal, navigationCornerRadius * 0.55)
                        .allowsHitTesting(false)
                }
                .shadow(
                    color: Color.black.opacity(navigationShadowOpacity(tokens: tokens)),
                    radius: navigationShadowRadius(tokens: tokens),
                    x: 0,
                    y: navigationShadowYOffset(tokens: tokens)
                )

                Spacer(minLength: 16)
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, horizontalPadding)
            .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.topNavigationHeight, maxHeight: PaninoTokens.Layout.topNavigationHeight)
        }
        .frame(height: PaninoTokens.Layout.topNavigationHeight)
        .background {
            topChromeBackground(tokens: tokens)
        }
    }

    private func titlebarControlReserve(for width: CGFloat) -> CGFloat {
        width >= 720 ? 118 : 96
    }

    @ViewBuilder
    private func topChromeBackground(tokens: ResolvedThemeTokens) -> some View {
        if reduceTransparency || colorSchemeContrast == .increased {
            Color(nsColor: .windowBackgroundColor)
                .opacity(colorSchemeContrast == .increased ? 1.0 : 0.96)
                .overlay(theme.semanticSelectionColor.opacity(colorSchemeContrast == .increased ? 0.03 : 0.06))
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

                if theme.chromeStyle == .edgeToEdgeSidebar {
                    Rectangle()
                        .fill(theme.semanticSelectionColor.opacity(0.07))
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

    private func navigationContainerCornerRadius(tokens: ResolvedThemeTokens) -> CGFloat {
        switch theme.chromeStyle {
        case .integrated:
            return min(tokens.navigationCornerRadius, 14)
        case .floatingToolbar:
            return tokens.navigationCornerRadius
        case .edgeToEdgeSidebar:
            return min(tokens.navigationCornerRadius, 12)
        }
    }

    private func navigationStrokeOpacity(tokens: ResolvedThemeTokens) -> Double {
        switch theme.chromeStyle {
        case .integrated:
            return 0
        case .floatingToolbar:
            return tokens.strokeOpacity * 0.78
        case .edgeToEdgeSidebar:
            return tokens.strokeOpacity * 0.46
        }
    }

    private func navigationShadowOpacity(tokens: ResolvedThemeTokens) -> Double {
        switch theme.chromeStyle {
        case .integrated:
            return tokens.shadowOpacity * 0.28
        case .floatingToolbar:
            return tokens.shadowOpacity * PaninoSurfaceLevel.floatingChrome.shadowMultiplier
        case .edgeToEdgeSidebar:
            return tokens.shadowOpacity * 0.35
        }
    }

    private func navigationShadowRadius(tokens: ResolvedThemeTokens) -> CGFloat {
        theme.chromeStyle == .floatingToolbar ? tokens.shadowRadius * 0.92 : tokens.shadowRadius * 0.35
    }

    private func navigationShadowYOffset(tokens: ResolvedThemeTokens) -> CGFloat {
        theme.chromeStyle == .floatingToolbar ? tokens.shadowYOffset * 0.72 : tokens.shadowYOffset * 0.26
    }

    @ViewBuilder
    private func navigationContainerBackground(tokens: ResolvedThemeTokens, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        switch theme.chromeStyle {
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

struct PaninoBrandMark: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image = PaninoBrandAsset.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: size * 0.58, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

enum PaninoBrandAsset {
    static let image: NSImage? = loadImage()

    private static func loadImage() -> NSImage? {
        if let image = NSImage(named: "PaninoAppIcon") {
            return image
        }

        for bundle in resourceBundles {
            if let url = bundle.url(
                forResource: "panino-app-icon",
                withExtension: "png",
                subdirectory: "Assets.xcassets/PaninoAppIcon.imageset"
            ),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        return nil
    }

    private static var resourceBundles: [Bundle] {
        #if SWIFT_PACKAGE
        [Bundle.module, Bundle.main]
        #else
        [Bundle.main]
        #endif
    }
}

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
