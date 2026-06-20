import AppKit

@MainActor
enum PaninoAboutResources {
    static let appIcon: NSImage? = loadAppIcon()

    static let hasSwiftSymbol: Bool = NSImage(
        systemSymbolName: "swift",
        accessibilityDescription: nil
    ) != nil

    static var alphaVersionText: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let marketingVersion = nonEmpty(info["CFBundleShortVersionString"] as? String) ?? "0.1"
        let buildNumber = nonEmpty(info["CFBundleVersion"] as? String)

        if let buildNumber {
            return "Alpha \(marketingVersion) · Development Build \(buildNumber)"
        }
        return "Alpha \(marketingVersion) · Development"
    }

    private static func loadAppIcon() -> NSImage? {
        if let image = NSImage(named: "PaninoAppIcon") {
            return image
        }
        if let image = NSImage(named: "AppIcon") {
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

        return NSApplication.shared.applicationIconImage
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static var resourceBundles: [Bundle] {
        #if SWIFT_PACKAGE
        [Bundle.module, Bundle.main]
        #else
        [Bundle.main]
        #endif
    }
}
