import AppKit
import SwiftUI

struct PaninoAboutView: View {
    private let icon: NSImage?
    private let versionText: String

    init() {
        icon = PaninoAboutResources.appIcon
        versionText = PaninoAboutResources.alphaVersionText
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 18)

            PaninoAboutAppIcon(icon: icon)

            VStack(spacing: 7) {
                Text("Panino Launcher")
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(versionText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("A native macOS Minecraft launcher.")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.top, 8)
            }

            AboutBuiltWithLine()
            .padding(.top, 2)

            Spacer(minLength: 18)
        }
        .frame(width: 560, height: 390)
        .padding(.horizontal, 36)
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                RadialGradient(
                    colors: [
                        Color(red: 1.0, green: 0.31, blue: 0.36).opacity(0.18),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 40,
                    endRadius: 310
                )
            }
            .ignoresSafeArea()
        }
    }
}

private struct AboutBuiltWithLine: View {
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

private struct PaninoAboutAppIcon: View {
    let icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 14, x: 0, y: 8)
        .accessibilityLabel("Panino Launcher")
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

@MainActor
private enum PaninoAboutResources {
    static let appIcon: NSImage? = loadAppIcon()

    static let hasSwiftSymbol: Bool = NSImage(
        systemSymbolName: "swift",
        accessibilityDescription: nil
    ) != nil

    static var alphaVersionText: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let marketingVersion = nonEmpty(info["CFBundleShortVersionString"] as? String) ?? "0.1"
        let buildNumber = nonEmpty(info["CFBundleVersion"] as? String)

        if let buildNumber {
            return "Alpha \(marketingVersion) · Development Build \(buildNumber)"
        }
        return "Alpha \(marketingVersion) · Development"
    }

    private static func loadAppIcon() -> NSImage? {
        if let image = NSImage(named: "PaninoAppIcon") {
            return image
        }
        if let image = NSImage(named: "AppIcon") {
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

        return NSApplication.shared.applicationIconImage
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static var resourceBundles: [Bundle] {
        #if SWIFT_PACKAGE
        [Bundle.module, Bundle.main]
        #else
        [Bundle.main]
        #endif
    }
}
