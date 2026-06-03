import AppKit
import SwiftUI

struct LauncherBackground: View {
    let version: String
    let isImmersiveEnabled: Bool

    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                baseBackground(size: proxy.size)

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
                                    with: .color(theme.semanticSelectionColor.opacity(0.012))
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
    private func baseBackground(size: CGSize) -> some View {
        if theme.quietModeEnabled || reduceTransparency || colorSchemeContrast == .increased {
            Color(nsColor: .windowBackgroundColor)
                .frame(width: size.width, height: size.height)
        } else if isImmersiveEnabled {
            immersiveBackground(size: size)
        } else if case .customImage = theme.effectiveBackgroundMode,
                  let image = theme.cachedBackgroundImage {
            workbenchImageBackground(image: image, size: size)
        } else {
            quietBackground(size: size)
        }
    }

    @ViewBuilder
    private func immersiveBackground(size: CGSize) -> some View {
        switch theme.effectiveBackgroundMode {
        case .default:
            quietBackground(size: size)
        case .currentInstance:
            ZStack {
                LinearGradient(
                    colors: [
                        theme.semanticSelectionColor.opacity(colorSchemeContrast == .increased ? 0.06 : 0.12),
                        Color(nsColor: .controlBackgroundColor).opacity(0.36),
                        Color(nsColor: .windowBackgroundColor)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(alignment: .leading, spacing: 8) {
                    Text("Minecraft \(version)")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.semanticSelectionColor.opacity(colorSchemeContrast == .increased ? 0.08 : 0.11))
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
                    .clipped()
                    .overlay(Color(nsColor: .windowBackgroundColor).opacity(colorSchemeContrast == .increased ? 0.72 : 0.50))
            } else {
                Color(nsColor: .windowBackgroundColor)
                    .frame(width: size.width, height: size.height)
            }
        case .solidColor:
            theme.semanticSelectionColor.opacity(theme.appearance == .highContrast ? 0.24 : 0.14)
                .overlay(Color(nsColor: .windowBackgroundColor).opacity(0.68))
                .frame(width: size.width, height: size.height)
        }
    }

    private func workbenchImageBackground(image: NSImage, size: CGSize) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(1.06)
            .blur(radius: reduceMotion ? 16 : 22, opaque: true)
            .saturation(0.62)
            .brightness(-0.08)
            .overlay(Color(nsColor: .windowBackgroundColor).opacity(theme.appearance == .dark ? 0.66 : 0.74))
            .overlay(theme.semanticSelectionColor.opacity(0.05))
            .clipped()
    }

    @ViewBuilder
    private func quietBackground(size: CGSize) -> some View {
        if theme.quietModeEnabled || reduceTransparency || colorSchemeContrast == .increased {
            Color(nsColor: .windowBackgroundColor)
                .frame(width: size.width, height: size.height)
        } else {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor),
                    theme.semanticSelectionColor.opacity(0.045)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: size.width, height: size.height)
        }
    }

}
