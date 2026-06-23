import SwiftUI

struct AboutBuiltWithLine: View {
    var body: some View {
        HStack(spacing: 7) {
            Text("Built with")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            AboutInlineTechnologyMark(mark: .swift)

            Text("SwiftUI")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("+")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)

            AboutInlineTechnologyMark(mark: .haskell)

            Text("Haskell")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Built with SwiftUI and Haskell")
    }
}

private struct AboutInlineTechnologyMark: View {
    let mark: AboutTechnologyMark

    var body: some View {
        AboutTechnologyMarkView(mark: mark)
            .padding(mark.inlinePadding)
            .frame(width: mark.inlineSize.width, height: mark.inlineSize.height)
            .background {
                RoundedRectangle(cornerRadius: mark.inlineCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: mark.backgroundColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: mark.inlineCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

private enum AboutTechnologyMark {
    case swift
    case haskell

    var backgroundColors: [Color] {
        switch self {
        case .swift:
            return [
                Color(red: 0.95, green: 0.31, blue: 0.23),
                Color(red: 0.98, green: 0.62, blue: 0.18)
            ]
        case .haskell:
            return [
                Color(red: 0.97, green: 0.96, blue: 0.99),
                Color(red: 0.90, green: 0.88, blue: 0.95)
            ]
        }
    }

    var inlineSize: CGSize {
        switch self {
        case .swift: return CGSize(width: 25, height: 25)
        case .haskell: return CGSize(width: 34, height: 25)
        }
    }

    var inlineCornerRadius: CGFloat {
        switch self {
        case .swift: return 8
        case .haskell: return 7
        }
    }

    var inlinePadding: CGFloat {
        switch self {
        case .swift: return 4
        case .haskell: return 4
        }
    }
}

private struct AboutTechnologyMarkView: View {
    let mark: AboutTechnologyMark

    var body: some View {
        switch mark {
        case .swift:
            if PaninoAboutResources.hasSwiftSymbol {
                Image(systemName: "swift")
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
            } else {
                Text("S")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
        case .haskell:
            HaskellLogoMark()
        }
    }
}

private struct HaskellLogoMark: View {
    var body: some View {
        ZStack {
            HaskellLogoPolygon(points: [
                CGPoint(x: 0.0, y: 0.0),
                CGPoint(x: 33.7, y: 0.0),
                CGPoint(x: 78.6, y: 67.4),
                CGPoint(x: 33.7, y: 134.8),
                CGPoint(x: 0.0, y: 134.8),
                CGPoint(x: 44.9, y: 67.4)
            ])
            .fill(Color(red: 0.27, green: 0.23, blue: 0.38))

            HaskellLogoPolygon(points: [
                CGPoint(x: 44.9, y: 134.8),
                CGPoint(x: 89.8, y: 67.4),
                CGPoint(x: 44.9, y: 0.0),
                CGPoint(x: 78.6, y: 0.0),
                CGPoint(x: 168.4, y: 134.8),
                CGPoint(x: 134.7, y: 134.8),
                CGPoint(x: 106.1, y: 91.9),
                CGPoint(x: 77.6, y: 134.8)
            ])
            .fill(Color(red: 0.37, green: 0.31, blue: 0.53))

            HaskellLogoPolygon(points: [
                CGPoint(x: 116.1, y: 39.3),
                CGPoint(x: 218.0, y: 39.3),
                CGPoint(x: 218.0, y: 61.8),
                CGPoint(x: 131.1, y: 61.8)
            ])
            .fill(Color(red: 0.56, green: 0.31, blue: 0.55))

            HaskellLogoPolygon(points: [
                CGPoint(x: 138.6, y: 73.0),
                CGPoint(x: 210.0, y: 73.0),
                CGPoint(x: 210.0, y: 95.5),
                CGPoint(x: 153.6, y: 95.5)
            ])
            .fill(Color(red: 0.56, green: 0.31, blue: 0.55))
        }
        .aspectRatio(256.0 / 134.8, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct HaskellLogoPolygon: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        let viewBox = CGSize(width: 256.0, height: 134.8)
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let xOffset = rect.midX - (viewBox.width * scale / 2)
        let yOffset = rect.midY - (viewBox.height * scale / 2)

        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: xOffset + point.x * scale,
                y: yOffset + point.y * scale
            )
        }

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: map(first))
        for point in points.dropFirst() {
            path.addLine(to: map(point))
        }
        path.closeSubpath()
        return path
    }
}
