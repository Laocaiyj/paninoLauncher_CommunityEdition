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
            PaninoAboutTitleBlock(versionText: versionText)

            AboutBuiltWithLine()
                .padding(.top, 2)

            Spacer(minLength: 18)
        }
        .frame(width: 560, height: 390)
        .padding(.horizontal, 36)
        .background {
            PaninoAboutBackground()
        }
    }
}

private struct PaninoAboutTitleBlock: View {
    let versionText: String

    var body: some View {
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
    }
}

private struct PaninoAboutBackground: View {
    var body: some View {
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
