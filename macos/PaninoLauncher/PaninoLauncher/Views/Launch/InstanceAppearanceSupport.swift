import SwiftUI

struct InstanceAppearancePreview: View {
    let instance: GameInstance
    let values: InstanceAppearanceValues

    @EnvironmentObject private var theme: ThemeSettings
    @State private var image: NSImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.08, anchor: UnitPoint(x: CGFloat(values.coverFocusX), y: CGFloat(values.coverFocusY)))
                    .blur(radius: values.coverBlur * 14, opaque: true)
            } else {
                LinearGradient(
                    colors: [
                        Color.paninoHex(values.coverColorHex, fallback: theme.semanticSelectionColor).opacity(0.72),
                        Color(nsColor: .controlBackgroundColor).opacity(0.78)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            LinearGradient(
                colors: [.black.opacity(0.02), .black.opacity(0.22 + values.coverDim * 0.58)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: values.normalized.iconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.paninoHex(values.coverColorHex, fallback: theme.semanticSelectionColor))
                    .frame(width: 54, height: 54)
                    .background(iconBackdrop, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(instance.name)
                    .font(.title3.bold())
                    .lineLimit(1)
                Text("Minecraft \(instance.minecraftVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .task(id: values.coverPath) {
            let path = values.coverPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                image = nil
                return
            }
            image = await ThumbnailCache.shared.image(path: path, size: CGSize(width: 640, height: 360))
        }
    }

    private var iconBackdrop: Color {
        switch values.iconBackdropStyle {
        case .automatic:
            Color.black.opacity(values.coverPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 0.24)
        case .none:
            Color.clear
        case .plate:
            Color.black.opacity(0.34)
        case .glass:
            Color.white.opacity(0.18)
        }
    }
}

struct InstanceAppearanceSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
    }
}

struct InstanceAppearanceSlider: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Slider(value: $value, in: 0...1, step: 0.01)
            Text("\(Int((value * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}
