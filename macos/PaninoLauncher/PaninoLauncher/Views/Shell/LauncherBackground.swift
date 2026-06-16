import AppKit
import SwiftUI

struct LauncherBackground: View {
    let version: String
    let isImmersiveEnabled: Bool

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private let customImageScale: CGFloat = 1.06

    var body: some View {
        GeometryReader { proxy in
            let tokens = theme.resolvedTokens(
                reduceTransparency: reduceTransparency,
                increasedContrast: colorSchemeContrast == .increased,
                reduceMotion: reduceMotion
            )
            ZStack {
                baseBackground(size: proxy.size, tokens: tokens)

                if isImmersiveEnabled,
                   theme.effectiveSoftBackgroundEnabled,
                   !reduceTransparency,
                   !reduceMotion,
                   colorSchemeContrast != .increased {
                    Canvas { context, size in
                        let cellSize: CGFloat = 196
                        for row in 0...Int(size.height / cellSize) {
                            for column in 0...Int(size.width / cellSize) {
                                guard (row + column) % 4 == 0 else { continue }
                                let rect = CGRect(
                                    x: CGFloat(column) * cellSize,
                                    y: CGFloat(row) * cellSize,
                                    width: cellSize,
                                    height: cellSize
                                )
                                context.fill(
                                    Path(roundedRect: rect.insetBy(dx: 66, dy: 66), cornerRadius: 8),
                                    with: .color(tokens.selectionColor.opacity(tokens.textureOpacity))
                                )
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func baseBackground(size: CGSize, tokens: ResolvedThemeTokens) -> some View {
        if theme.quietModeEnabled || reduceTransparency || colorSchemeContrast == .increased {
            Color(nsColor: .windowBackgroundColor)
                .frame(width: size.width, height: size.height)
        } else if isImmersiveEnabled {
            immersiveBackground(size: size, tokens: tokens)
        } else if case .customImage = theme.effectiveBackgroundMode,
                  let image = theme.cachedBackgroundImage {
            workbenchImageBackground(image: image, size: size, tokens: tokens)
        } else {
            quietBackground(size: size, tokens: tokens)
        }
    }

    @ViewBuilder
    private func immersiveBackground(size: CGSize, tokens: ResolvedThemeTokens) -> some View {
        switch theme.effectiveBackgroundMode {
        case .default:
            quietBackground(size: size, tokens: tokens)
        case .currentInstance:
            ZStack {
                LinearGradient(
                    colors: [
                        tokens.selectionColor.opacity(colorSchemeContrast == .increased ? 0.06 : tokens.accentBackgroundOpacity),
                        Color(nsColor: .controlBackgroundColor).opacity(0.30),
                        Color(nsColor: .windowBackgroundColor)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minecraft \(version)")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(tokens.selectionColor.opacity(colorSchemeContrast == .increased ? 0.08 : 0.10))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer()
                }
                .padding(44)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        case .customImage:
            if let image = theme.cachedBackgroundImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(customImageScale)
                    .clipped()
                    .blur(radius: tokens.backgroundBlurRadius, opaque: true)
                    .overlay(Color(nsColor: .windowBackgroundColor).opacity(colorSchemeContrast == .increased ? 0.72 : tokens.backgroundDimOpacity))
                    .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.55))
            } else {
                Color(nsColor: .windowBackgroundColor)
                    .frame(width: size.width, height: size.height)
            }
        case .solidColor:
            tokens.selectionColor.opacity(theme.appearance == .highContrast ? 0.18 : tokens.accentBackgroundOpacity)
                .overlay(Color(nsColor: .windowBackgroundColor).opacity(tokens.backgroundDimOpacity))
                .frame(width: size.width, height: size.height)
        }
    }

    private func workbenchImageBackground(image: NSImage, size: CGSize, tokens: ResolvedThemeTokens) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(customImageScale)
            .blur(radius: reduceMotion ? 10 : tokens.backgroundBlurRadius, opaque: true)
            .saturation(theme.visualNoiseReductionEnabled ? 0.48 : 0.66)
            .brightness(-0.06)
            .overlay(Color(nsColor: .windowBackgroundColor).opacity(tokens.backgroundDimOpacity))
            .overlay(tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.65))
            .clipped()
    }

    @ViewBuilder
    private func quietBackground(size: CGSize, tokens: ResolvedThemeTokens) -> some View {
        if theme.quietModeEnabled || reduceTransparency || colorSchemeContrast == .increased {
            Color(nsColor: .windowBackgroundColor)
                .frame(width: size.width, height: size.height)
        } else {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor),
                    tokens.selectionColor.opacity(tokens.accentBackgroundOpacity * 0.65)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size.width, height: size.height)
        }
    }

}
