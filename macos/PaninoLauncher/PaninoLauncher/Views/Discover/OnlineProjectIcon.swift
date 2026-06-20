import AppKit
import Foundation
import SwiftUI

struct OnlineProjectIcon: View {
    let url: URL?
    @State private var image: NSImage?
    @State private var failed = false

    private static let cache = NSCache<NSURL, NSImage>()

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if failed || url == nil {
                Image(systemName: "shippingbox.fill").font(.title3).foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: 42, height: 42)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: url) {
            await loadIcon()
        }
    }

    @MainActor
    private func loadIcon() async {
        image = nil
        failed = false
        guard let url else {
            failed = true
            return
        }
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled, let loaded = NSImage(data: data) else { return }
            Self.cache.setObject(loaded, forKey: url as NSURL)
            image = loaded
        } catch {
            if !Task.isCancelled {
                failed = true
            }
        }
    }
}
