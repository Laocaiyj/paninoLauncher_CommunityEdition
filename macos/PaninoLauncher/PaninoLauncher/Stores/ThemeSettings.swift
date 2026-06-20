import Foundation
import AppKit
import SwiftUI

@MainActor
final class ThemeSettings: ObservableObject {
    private enum Key {
        static let language = "App.Language"
        static let currentPreset = "Theme.CurrentPreset"
        static let appearance = "Theme.Appearance"
        static let accent = "Theme.Accent"
        static let materialStrength = "Theme.MaterialStrength"
        static let backgroundMode = "Theme.BackgroundMode"
        static let fontDensity = "Theme.FontDensity"
        static let customImagePath = "Theme.CustomImagePath"
        static let customImageBookmark = "Theme.CustomImageBookmark"
        static let softBackgroundEnabled = "Theme.SoftBackgroundEnabled"
        static let quietModeEnabled = "Theme.QuietModeEnabled"
        static let glassStyle = "Theme.GlassStyle"
        static let chromeStyle = "Theme.ChromeStyle"
        static let depthStyle = "Theme.DepthStyle"
        static let controlShape = "Theme.ControlShape"
        static let motionStyle = "Theme.MotionStyle"
        static let customAccentHex = "Theme.CustomAccentHex"
        static let glassFrosting = "Theme.GlassFrosting"
        static let backgroundBlur = "Theme.BackgroundBlur"
        static let backgroundDim = "Theme.BackgroundDim"
        static let surfaceContrast = "Theme.SurfaceContrast"
        static let visualNoiseReductionEnabled = "Theme.VisualNoiseReductionEnabled"
    }

    @Published var language: AppLanguage = ThemeSettings.loadEnum(
        key: Key.language,
        defaultValue: .english
    ) {
        didSet { SettingsStore.set(language.rawValue, forKey: Key.language) }
    }

    @Published var currentPreset: ThemePreset = ThemeSettings.loadEnum(
        key: Key.currentPreset,
        defaultValue: .vanilla
    ) {
        didSet { SettingsStore.set(currentPreset.rawValue, forKey: Key.currentPreset) }
    }

    @Published var appearance: ThemeAppearanceMode = ThemeSettings.loadEnum(
        key: Key.appearance,
        defaultValue: .system
    ) {
        didSet {
            SettingsStore.set(appearance.rawValue, forKey: Key.appearance)
            applyAppAppearance()
        }
    }

    @Published var accent: ThemeAccentColor = ThemeSettings.loadEnum(
        key: Key.accent,
        defaultValue: .system
    ) {
        didSet { SettingsStore.set(accent.rawValue, forKey: Key.accent) }
    }

    @Published var materialStrength: MaterialStrength = ThemeSettings.loadEnum(
        key: Key.materialStrength,
        defaultValue: .medium
    ) {
        didSet { SettingsStore.set(materialStrength.rawValue, forKey: Key.materialStrength) }
    }

    @Published var backgroundMode: ThemeBackgroundMode = ThemeSettings.loadEnum(
        key: Key.backgroundMode,
        defaultValue: .default
    ) {
        didSet { SettingsStore.set(backgroundMode.rawValue, forKey: Key.backgroundMode) }
    }

    @Published var fontDensity: FontDensity = ThemeSettings.loadEnum(
        key: Key.fontDensity,
        defaultValue: .standard
    ) {
        didSet { SettingsStore.set(fontDensity.rawValue, forKey: Key.fontDensity) }
    }

    @Published var glassStyle: ThemeGlassStyle = ThemeSettings.loadEnum(
        key: Key.glassStyle,
        defaultValue: .automatic
    ) {
        didSet { SettingsStore.set(glassStyle.rawValue, forKey: Key.glassStyle) }
    }

    @Published var chromeStyle: ThemeChromeStyle = ThemeSettings.loadEnum(
        key: Key.chromeStyle,
        defaultValue: .floatingToolbar
    ) {
        didSet { SettingsStore.set(chromeStyle.rawValue, forKey: Key.chromeStyle) }
    }

    @Published var depthStyle: ThemeDepthStyle = ThemeSettings.loadEnum(
        key: Key.depthStyle,
        defaultValue: .soft
    ) {
        didSet { SettingsStore.set(depthStyle.rawValue, forKey: Key.depthStyle) }
    }

    @Published var controlShape: ThemeControlShape = ThemeSettings.loadEnum(
        key: Key.controlShape,
        defaultValue: .roundedRect
    ) {
        didSet { SettingsStore.set(controlShape.rawValue, forKey: Key.controlShape) }
    }

    @Published var motionStyle: ThemeMotionStyle = ThemeSettings.loadEnum(
        key: Key.motionStyle,
        defaultValue: .system
    ) {
        didSet { SettingsStore.set(motionStyle.rawValue, forKey: Key.motionStyle) }
    }

    @Published var customAccentHex: String = SettingsStore.string(
        forKey: Key.customAccentHex,
        default: "#FF4F5E"
    ) {
        didSet {
            SettingsStore.set(Self.normalizedCustomAccentHex(customAccentHex), forKey: Key.customAccentHex)
        }
    }

    @Published var glassFrosting: Double = SettingsStore.double(
        forKey: Key.glassFrosting,
        default: 0.58
    ) {
        didSet {
            SettingsStore.set(Self.clampedUnit(glassFrosting), forKey: Key.glassFrosting)
        }
    }

    @Published var backgroundBlur: Double = SettingsStore.double(
        forKey: Key.backgroundBlur,
        default: 0.46
    ) {
        didSet {
            SettingsStore.set(Self.clampedUnit(backgroundBlur), forKey: Key.backgroundBlur)
        }
    }

    @Published var backgroundDim: Double = SettingsStore.double(
        forKey: Key.backgroundDim,
        default: 0.54
    ) {
        didSet {
            SettingsStore.set(Self.clampedUnit(backgroundDim), forKey: Key.backgroundDim)
        }
    }

    @Published var surfaceContrast: Double = SettingsStore.double(
        forKey: Key.surfaceContrast,
        default: 0.46
    ) {
        didSet {
            SettingsStore.set(Self.clampedUnit(surfaceContrast), forKey: Key.surfaceContrast)
        }
    }

    @Published var customImagePath: String = SettingsStore.string(forKey: Key.customImagePath, default: "") {
        didSet {
            SettingsStore.set(customImagePath, forKey: Key.customImagePath)
            loadCustomBackgroundImage()
        }
    }

    @Published var customImageBookmark: Data? = SettingsStore.data(forKey: Key.customImageBookmark) {
        didSet {
            SettingsStore.set(customImageBookmark, forKey: Key.customImageBookmark)
            loadCustomBackgroundImage()
        }
    }

    @Published private(set) var cachedBackgroundImage: NSImage?

    init() {
        applyAppAppearance()
        loadCustomBackgroundImage()
    }

    @Published var softBackgroundEnabled: Bool = SettingsStore.bool(
        forKey: Key.softBackgroundEnabled,
        default: true
    ) {
        didSet { SettingsStore.set(softBackgroundEnabled, forKey: Key.softBackgroundEnabled) }
    }

    @Published var quietModeEnabled: Bool = SettingsStore.bool(
        forKey: Key.quietModeEnabled,
        default: false
    ) {
        didSet { SettingsStore.set(quietModeEnabled, forKey: Key.quietModeEnabled) }
    }

    @Published var visualNoiseReductionEnabled: Bool = SettingsStore.bool(
        forKey: Key.visualNoiseReductionEnabled,
        default: false
    ) {
        didSet { SettingsStore.set(visualNoiseReductionEnabled, forKey: Key.visualNoiseReductionEnabled) }
    }

    var accentColor: Color {
        if accent == .custom {
            return Color.paninoHex(customAccentHex, fallback: .red)
        }
        return accent.color ?? Color.accentColor
    }

    var effectiveMaterialStrength: MaterialStrength {
        quietModeEnabled ? .off : materialStrength
    }

    var effectiveBackgroundMode: ThemeBackgroundMode {
        quietModeEnabled ? .solidColor : backgroundMode
    }

    var effectiveSoftBackgroundEnabled: Bool {
        !quietModeEnabled && !visualNoiseReductionEnabled && softBackgroundEnabled
    }

    var reducesInterfaceMotion: Bool {
        quietModeEnabled || motionStyle == .reduced
    }

    static func normalizedCustomAccentHex(_ value: String) -> String {
        let normalized = value.normalizedHex
        return normalized.isEmpty ? "#FF4F5E" : normalized
    }

    func loadCustomBackgroundImage() {
        cachedBackgroundImage = Self.loadCustomBackgroundImage(
            bookmark: customImageBookmark,
            path: customImagePath
        )
    }

    private static func loadCustomBackgroundImage(bookmark: Data?, path: String) -> NSImage? {
        if let bookmark {
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

        guard !path.isEmpty else { return nil }
        return downsampledImage(NSImage(contentsOfFile: path))
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

    private static func loadEnum<Value: RawRepresentable>(
        key: String,
        defaultValue: Value
    ) -> Value where Value.RawValue == String {
        let rawValue = SettingsStore.string(forKey: key, default: defaultValue.rawValue)
        return Value(rawValue: rawValue) ?? defaultValue
    }

    private static func clampedUnit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func applyAppAppearance() {
        NSApplication.shared.appearance = appearance.nsAppearance
    }
}
