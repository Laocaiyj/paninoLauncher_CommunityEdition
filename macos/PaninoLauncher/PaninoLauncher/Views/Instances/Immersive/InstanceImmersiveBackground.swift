import AppKit
import SwiftUI

struct InstanceImmersiveBackground: View {
    let instance: GameInstance?

    @EnvironmentObject private var theme: ThemeSettings
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [
                            tint.opacity(0.68),
                            theme.semanticSelectionColor.opacity(0.30),
                            Color(nsColor: .windowBackgroundColor).opacity(0.74)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: instance?.resolvedIconName ?? "square.stack.3d.up")
                        .font(.system(size: 190, weight: .bold))
                        .foregroundStyle(tint.opacity(0.22))
                        .offset(x: proxy.size.width * 0.25, y: -proxy.size.height * 0.12)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task(id: instance?.coverPath ?? "") {
            guard let instance, !instance.coverPath.isEmpty else {
                image = nil
                return
            }
            image = await ThumbnailCache.shared.image(path: instance.coverPath, size: CGSize(width: 1280, height: 720))
        }
    }

    private var tint: Color {
        instance?.coverTintColor ?? theme.semanticSelectionColor
    }
}
