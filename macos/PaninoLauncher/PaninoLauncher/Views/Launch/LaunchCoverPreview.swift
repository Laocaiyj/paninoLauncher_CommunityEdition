import SwiftUI

struct LaunchCoverPreview: View {
    let instance: GameInstance

    @State private var image: NSImage?
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1.08, anchor: UnitPoint(x: CGFloat(instance.coverFocusX), y: CGFloat(instance.coverFocusY)))
                        .blur(radius: instance.coverBlur * 14, opaque: true)
                        .clipped()
                } else {
                    LaunchCoverPlaceholder(instance: instance, size: proxy.size)
                }
                LinearGradient(
                    colors: [.clear, .black.opacity(0.16 + instance.coverDim * 0.52)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .task(id: instance.coverPath) {
            await loadCoverImage()
        }
    }

    private func loadCoverImage() async {
        guard !instance.coverPath.isEmpty else {
            image = nil
            return
        }
        image = await ThumbnailCache.shared.image(path: instance.coverPath, size: CGSize(width: 420, height: 300))
    }
}

private struct LaunchCoverPlaceholder: View {
    let instance: GameInstance
    let size: CGSize

    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    instance.coverTintColor.opacity(0.42),
                    Color(nsColor: .controlBackgroundColor).opacity(0.58)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: instance.resolvedIconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(instance.coverTintColor)
                    .frame(width: 54, height: 54)
                    .background(iconBackdrop, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("Minecraft \(instance.minecraftVersion)")
                    .font(.headline)
                    .lineLimit(1)
                Text(instance.loaderTitle(language: theme.language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(16)
        }
        .frame(width: size.width, height: size.height, alignment: .bottomLeading)
    }

    private var iconBackdrop: Color {
        switch instance.iconBackdropStyle {
        case .automatic:
            return instance.coverPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.clear : Color.black.opacity(0.24)
        case .none:
            return Color.clear
        case .plate:
            return Color.black.opacity(0.34)
        case .glass:
            return Color.white.opacity(0.18)
        }
    }
}
