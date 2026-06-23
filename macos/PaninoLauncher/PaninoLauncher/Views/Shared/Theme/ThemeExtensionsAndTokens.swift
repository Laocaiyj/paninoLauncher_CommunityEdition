import SwiftUI

private struct PaninoGlassSurfaceModifier: ViewModifier {
    let tokens: ResolvedThemeTokens
    let level: PaninoSurfaceLevel
    let cornerRadius: CGFloat
    let interactive: Bool
    let tintOpacity: Double

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *), tokens.surfaceMaterial != nil {
            if interactive {
                content
                    .glassEffect(
                        .regular
                            .tint(tokens.selectionColor.opacity(tintOpacity))
                            .interactive(),
                        in: .rect(cornerRadius: cornerRadius)
                    )
            } else {
                content
                    .glassEffect(
                        .regular.tint(tokens.selectionColor.opacity(tintOpacity)),
                        in: .rect(cornerRadius: cornerRadius)
                    )
            }
        } else if let material = tokens.surfaceMaterial {
            content
                .background {
                    shape.fill(material)
                        .overlay(tokens.surfaceFill.opacity(tokens.surfaceVeilOpacity * level.veilMultiplier))
                }
        } else {
            content
                .background {
                    shape.fill(tokens.surfaceFill.opacity(tokens.surfaceFillOpacity * level.fillOpacityMultiplier))
                }
        }
    }
}

private struct PaninoDepthOverlayModifier: ViewModifier {
    let tokens: ResolvedThemeTokens
    let level: PaninoSurfaceLevel
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(tokens.depthHighlightOpacity * level.highlightMultiplier),
                                Color.white.opacity(0),
                                Color.black.opacity(tokens.depthShadeOpacity * level.shadeMultiplier)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                shape
                    .strokeBorder(
                        Color.white.opacity(tokens.depthRimOpacity * level.highlightMultiplier),
                        lineWidth: max(1, tokens.strokeWidth)
                    )
                    .allowsHitTesting(false)
            }
    }
}

enum PaninoTextTruncation {
    case path
    case hash
    case title
    case summary(lines: Int = 2)
}

private struct PaninoTruncationModifier: ViewModifier {
    let style: PaninoTextTruncation

    func body(content: Content) -> some View {
        switch style {
        case .path, .hash:
            content
                .lineLimit(1)
                .truncationMode(.middle)
        case .title:
            content
                .lineLimit(1)
                .truncationMode(.tail)
        case .summary(let lines):
            content
                .lineLimit(lines)
                .truncationMode(.tail)
        }
    }
}

extension View {
    func paninoTruncation(_ style: PaninoTextTruncation) -> some View {
        modifier(PaninoTruncationModifier(style: style))
    }

    func paninoGlassSurface(
        tokens: ResolvedThemeTokens,
        level: PaninoSurfaceLevel = .panel,
        cornerRadius: CGFloat? = nil,
        interactive: Bool = false,
        tintOpacity: Double? = nil
    ) -> some View {
        modifier(PaninoGlassSurfaceModifier(
            tokens: tokens,
            level: level,
            cornerRadius: cornerRadius ?? tokens.panelCornerRadius,
            interactive: interactive,
            tintOpacity: tintOpacity ?? level.tintOpacity
        ))
    }

    func paninoDepthOverlay(
        tokens: ResolvedThemeTokens,
        level: PaninoSurfaceLevel = .panel,
        cornerRadius: CGFloat? = nil
    ) -> some View {
        modifier(PaninoDepthOverlayModifier(
            tokens: tokens,
            level: level,
            cornerRadius: cornerRadius ?? tokens.panelCornerRadius
        ))
    }
}
