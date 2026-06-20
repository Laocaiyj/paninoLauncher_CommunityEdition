import AppKit
import Foundation

enum ThemeBackgroundImageLoader {
    static func image(bookmark: Data?, path: String) -> NSImage? {
        if let bookmark {
            return image(fromBookmark: bookmark)
        }

        guard !path.isEmpty else { return nil }
        return downsampledImage(NSImage(contentsOfFile: path))
    }

    private static func image(fromBookmark bookmark: Data) -> NSImage? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let data = try Data(contentsOf: url)
            return downsampledImage(NSImage(data: data))
        } catch {
            return nil
        }
    }

    private static func downsampledImage(_ image: NSImage?) -> NSImage? {
        guard let image else { return nil }
        let maxEdge: CGFloat = 2560
        let size = image.size
        guard size.width > maxEdge || size.height > maxEdge else { return image }
        let scale = min(maxEdge / max(size.width, 1), maxEdge / max(size.height, 1))
        let targetSize = NSSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1)
        resized.unlockFocus()
        return resized
    }
}
