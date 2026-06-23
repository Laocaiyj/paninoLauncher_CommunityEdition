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
            let navigationCornerRadius = TopNavigationChrome.containerCornerRadius(tokens: tokens, chromeStyle: theme.chromeStyle)
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
                    TopNavigationBrandBackground(tokens: tokens, chromeStyle: theme.chromeStyle)
                }
                .shadow(
                    color: Color.black.opacity(TopNavigationChrome.brandShadowOpacity(tokens: tokens, chromeStyle: theme.chromeStyle)),
                    radius: TopNavigationChrome.brandShadowRadius(tokens: tokens, chromeStyle: theme.chromeStyle),
                    x: 0,
                    y: TopNavigationChrome.brandShadowYOffset(tokens: tokens, chromeStyle: theme.chromeStyle)
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
                    TopNavigationContainerBackground(
                        tokens: tokens,
                        chromeStyle: theme.chromeStyle,
                        cornerRadius: navigationCornerRadius
                    )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: navigationCornerRadius, style: .continuous)
                        .strokeBorder(
                            tokens.strokeColor.opacity(TopNavigationChrome.containerStrokeOpacity(tokens: tokens, chromeStyle: theme.chromeStyle)),
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
                    color: Color.black.opacity(TopNavigationChrome.containerShadowOpacity(tokens: tokens, chromeStyle: theme.chromeStyle)),
                    radius: TopNavigationChrome.containerShadowRadius(tokens: tokens, chromeStyle: theme.chromeStyle),
                    x: 0,
                    y: TopNavigationChrome.containerShadowYOffset(tokens: tokens, chromeStyle: theme.chromeStyle)
                )

                Spacer(minLength: 16)
            }
            .padding(.leading, leadingPadding)
            .padding(.trailing, horizontalPadding)
            .frame(maxWidth: .infinity, minHeight: PaninoTokens.Layout.topNavigationHeight, maxHeight: PaninoTokens.Layout.topNavigationHeight)
        }
        .frame(height: PaninoTokens.Layout.topNavigationHeight)
        .background {
            TopChromeBackground(
                tokens: tokens,
                chromeStyle: theme.chromeStyle,
                semanticSelectionColor: theme.semanticSelectionColor,
                reduceTransparency: reduceTransparency,
                increasedContrast: colorSchemeContrast == .increased
            )
        }
    }

    private func titlebarControlReserve(for width: CGFloat) -> CGFloat {
        width >= 720 ? 118 : 96
    }
}
