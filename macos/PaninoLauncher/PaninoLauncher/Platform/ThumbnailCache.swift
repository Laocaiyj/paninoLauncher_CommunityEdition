import AppKit
import Foundation
import ImageIO

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 128
    }

    func image(path: String, size: CGSize = CGSize(width: 96, height: 96)) async -> NSImage? {
        let key = "\(path)#\(Int(size.width))x\(Int(size.height))" as NSString
        if let image = cache.object(forKey: key) {
            return image
        }

        let scale = max(NSScreen.main?.backingScaleFactor ?? 2, 1)
        let image = await Task.detached(priority: .utility) {
            Self.downsampledImage(path: path, size: size, scale: scale)
        }.value

        if let image {
            cache.setObject(image, forKey: key, cost: Self.cacheCost(for: size))
        }
        return image
    }

    nonisolated private static func downsampledImage(path: String, size: CGSize, scale: CGFloat) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else {
            return nil
        }

        let maxPixelSize = max(1, Int(max(size.width, size.height) * scale))
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: size)
    }

    nonisolated private static func cacheCost(for size: CGSize) -> Int {
        max(1, Int(size.width * size.height * 4))
    }
}
