import AppKit
import SwiftUI

struct PaninoBrandMark: View {
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let image = PaninoBrandAsset.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: size * 0.58, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }
}

enum PaninoBrandAsset {
    static let image: NSImage? = loadImage()

    private static func loadImage() -> NSImage? {
        if let image = NSImage(named: "PaninoAppIcon") {
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

        return nil
    }

    private static var resourceBundles: [Bundle] {
        #if SWIFT_PACKAGE
        [Bundle.module, Bundle.main]
        #else
        [Bundle.main]
        #endif
    }
}
