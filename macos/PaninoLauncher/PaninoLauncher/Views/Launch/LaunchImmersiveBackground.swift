import SwiftUI

struct LaunchImmersiveBackground: View {
    let instance: GameInstance
    let hasInstalledInstances: Bool

    @EnvironmentObject private var theme: ThemeSettings
    @State private var image: NSImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if hasInstalledInstances, let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: [
                            instance.coverTintColor.opacity(hasInstalledInstances ? 0.70 : 0.38),
                            theme.semanticSelectionColor.opacity(0.34),
                            Color(nsColor: .windowBackgroundColor).opacity(0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    if hasInstalledInstances {
                        Image(systemName: instance.resolvedIconName)
                            .font(.system(size: 180, weight: .bold))
                            .foregroundStyle(instance.coverTintColor.opacity(0.24))
                            .offset(x: proxy.size.width * 0.26, y: -proxy.size.height * 0.10)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task(id: instance.coverPath) {
            guard hasInstalledInstances, !instance.coverPath.isEmpty else {
                image = nil
                return
            }
            image = await ThumbnailCache.shared.image(path: instance.coverPath, size: CGSize(width: 1280, height: 720))
        }
    }
}
