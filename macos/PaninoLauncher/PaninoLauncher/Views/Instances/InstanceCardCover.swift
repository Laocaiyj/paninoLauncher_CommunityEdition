import AppKit
import SwiftUI

struct InstanceCardCover: View {
    let instance: GameInstance
    @State private var image: NSImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(instance.coverTintColor.opacity(0.14))
                Image(systemName: instance.resolvedIconName)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(instance.coverTintColor)
                    .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: instance.coverPath) {
            guard !instance.coverPath.isEmpty else {
                image = nil
                return
            }
            image = await ThumbnailCache.shared.image(path: instance.coverPath, size: CGSize(width: 560, height: 260))
        }
    }
}
