import Foundation
import AppKit
import SwiftUI

enum ThemeAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case highContrast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "Follow System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .highContrast:
            return "High Contrast"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark, .highContrast:
            return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .highContrast:
            return NSAppearance(named: .accessibilityHighContrastDarkAqua)
                ?? NSAppearance(named: .darkAqua)
        }
    }
}

enum ThemeAccentColor: String, CaseIterable, Identifiable {
    case system
    case blue
    case emerald
    case amber
    case red
    case purple
    case graphite
    case teal
    case mint
    case pink
    case indigo
    case slate
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .blue:
            return "Blue"
        case .emerald:
            return "Emerald"
        case .amber:
            return "Amber"
        case .red:
            return "Red"
        case .purple:
            return "Purple"
        case .graphite:
            return "Graphite"
        case .teal:
            return "Teal"
        case .mint:
            return "Mint"
        case .pink:
            return "Pink"
        case .indigo:
            return "Indigo"
        case .slate:
            return "Slate"
        case .custom:
            return "Custom"
        }
    }

    var color: Color? {
        switch self {
        case .system:
            return nil
        case .blue:
            return .blue
        case .emerald:
            return .green
        case .amber:
            return .orange
        case .red:
            return .red
        case .purple:
            return .purple
        case .graphite:
            return .gray
        case .teal:
            return Color(red: 0.05, green: 0.58, blue: 0.62)
        case .mint:
            return Color(red: 0.20, green: 0.78, blue: 0.58)
        case .pink:
            return Color(red: 0.93, green: 0.20, blue: 0.55)
        case .indigo:
            return Color(red: 0.32, green: 0.36, blue: 0.93)
        case .slate:
            return Color(red: 0.38, green: 0.43, blue: 0.50)
        case .custom:
            return nil
        }
    }
}

enum ThemePreset: String, CaseIterable, Identifiable {
    case vanilla
    case nether
    case deepDark
    case liquidGlass
    case frostedGraphite
    case minecraftAmbient
    case focusSolid
    case highLegibility

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vanilla:
            return "Vanilla"
        case .nether:
            return "Nether"
        case .deepDark:
            return "Deep Dark"
        case .liquidGlass:
            return "Liquid Glass"
        case .frostedGraphite:
            return "Frosted Graphite"
        case .minecraftAmbient:
            return "Minecraft Ambient"
        case .focusSolid:
            return "Focus Solid"
        case .highLegibility:
            return "High Legibility"
        }
    }
}

enum ThemeGlassStyle: String, CaseIterable, Identifiable {
    case automatic
    case clear
    case frosted
    case solid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .clear: return "Clear"
        case .frosted: return "Frosted"
        case .solid: return "Solid"
        }
    }
}

enum ThemeChromeStyle: String, CaseIterable, Identifiable {
    case integrated
    case floatingToolbar
    case edgeToEdgeSidebar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .integrated: return "Integrated"
        case .floatingToolbar: return "Floating Toolbar"
        case .edgeToEdgeSidebar: return "Edge-to-edge Sidebar"
        }
    }
}

enum ThemeDepthStyle: String, CaseIterable, Identifiable {
    case flat
    case soft
    case layered
    case retro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flat: return "Minimal"
        case .soft: return "Spatial"
        case .layered: return "Liquid"
        case .retro: return "Retro"
        }
    }
}

enum ThemeControlShape: String, CaseIterable, Identifiable {
    case roundedRect
    case capsule
    case concentric

    var id: String { rawValue }

    var title: String {
        switch self {
        case .roundedRect: return "Rounded Rect"
        case .capsule: return "Capsule"
        case .concentric: return "Concentric"
        }
    }
}

enum ThemeMotionStyle: String, CaseIterable, Identifiable {
    case system
    case reduced
    case expressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .reduced: return "Reduced"
        case .expressive: return "Expressive"
        }
    }
}

enum MaterialStrength: String, CaseIterable, Identifiable {
    case off
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }

    var material: Material? {
        switch self {
        case .off:
            return nil
        case .low:
            return .ultraThinMaterial
        case .medium:
            return .regularMaterial
        case .high:
            return .thickMaterial
        }
    }
}

enum ThemeBackgroundMode: String, CaseIterable, Identifiable {
    case `default`
    case currentInstance
    case customImage
    case solidColor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .default:
            return "Default"
        case .currentInstance:
            return "Current Configuration"
        case .customImage:
            return "Custom Image"
        case .solidColor:
            return "Solid Color"
        }
    }
}

enum FontDensity: String, CaseIterable, Identifiable {
    case compact
    case standard
    case comfortable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact:
            return "Compact"
        case .standard:
            return "Standard"
        case .comfortable:
            return "Comfortable"
        }
    }

    var spacing: CGFloat {
        switch self {
        case .compact:
            return 8
        case .standard:
            return 12
        case .comfortable:
            return 16
        }
    }

    var controlHeight: CGFloat {
        switch self {
        case .compact:
            return 28
        case .standard:
            return 32
        case .comfortable:
            return 36
        }
    }

    var controlSize: ControlSize {
        switch self {
        case .compact:
            return .small
        case .standard:
            return .regular
        case .comfortable:
            return .large
        }
    }

    var panelPadding: CGFloat {
        switch self {
        case .compact:
            return 12
        case .standard:
            return 16
        case .comfortable:
            return 22
        }
    }

    var buttonHorizontalPadding: CGFloat {
        switch self {
        case .compact:
            return 10
        case .standard:
            return 12
        case .comfortable:
            return 16
        }
    }

    var buttonMinHeight: CGFloat {
        switch self {
        case .compact:
            return 32
        case .standard:
            return 36
        case .comfortable:
            return 44
        }
    }

    var settingsRowVerticalPadding: CGFloat {
        switch self {
        case .compact:
            return 0
        case .standard:
            return 3
        case .comfortable:
            return 7
        }
    }
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case chineseSimplified = "zh-Hans"
    case english = "en"
    case italian = "it"
    case french = "fr"
    case spanish = "es"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chineseSimplified:
            return "中文"
        case .english:
            return "English"
        case .italian:
            return "Italiano"
        case .french:
            return "Français"
        case .spanish:
            return "Español"
        }
    }
}

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

    func applyPreset(_ preset: ThemePreset) {
        currentPreset = preset
        switch preset {
        case .vanilla:
            accent = .emerald
            materialStrength = .medium
            backgroundMode = .default
            fontDensity = .standard
            glassStyle = .automatic
            chromeStyle = .floatingToolbar
            depthStyle = .soft
            controlShape = .roundedRect
            motionStyle = .system
            glassFrosting = 0.52
            backgroundBlur = 0.36
            backgroundDim = 0.48
            surfaceContrast = 0.42
            visualNoiseReductionEnabled = false
        case .nether:
            accent = .red
            materialStrength = .low
            backgroundMode = .solidColor
            fontDensity = .standard
            glassStyle = .frosted
            chromeStyle = .floatingToolbar
            depthStyle = .soft
            controlShape = .roundedRect
            motionStyle = .system
            glassFrosting = 0.66
            backgroundBlur = 0.40
            backgroundDim = 0.62
            surfaceContrast = 0.52
            visualNoiseReductionEnabled = false
        case .deepDark:
            appearance = .dark
            accent = .purple
            materialStrength = .high
            backgroundMode = .currentInstance
            fontDensity = .compact
            glassStyle = .frosted
            chromeStyle = .integrated
            depthStyle = .layered
            controlShape = .roundedRect
            motionStyle = .system
            glassFrosting = 0.72
            backgroundBlur = 0.58
            backgroundDim = 0.68
            surfaceContrast = 0.60
            visualNoiseReductionEnabled = false
        case .liquidGlass:
            appearance = .system
            accent = .red
            materialStrength = .medium
            backgroundMode = .currentInstance
            fontDensity = .standard
            glassStyle = .clear
            chromeStyle = .floatingToolbar
            depthStyle = .layered
            controlShape = .concentric
            motionStyle = .expressive
            glassFrosting = 0.42
            backgroundBlur = 0.44
            backgroundDim = 0.50
            surfaceContrast = 0.44
            visualNoiseReductionEnabled = false
        case .frostedGraphite:
            appearance = .system
            accent = .slate
            materialStrength = .high
            backgroundMode = .default
            fontDensity = .standard
            glassStyle = .frosted
            chromeStyle = .floatingToolbar
            depthStyle = .soft
            controlShape = .roundedRect
            motionStyle = .system
            glassFrosting = 0.82
            backgroundBlur = 0.62
            backgroundDim = 0.58
            surfaceContrast = 0.56
            visualNoiseReductionEnabled = true
        case .minecraftAmbient:
            appearance = .system
            accent = .emerald
            materialStrength = .medium
            backgroundMode = .currentInstance
            fontDensity = .comfortable
            glassStyle = .frosted
            chromeStyle = .floatingToolbar
            depthStyle = .layered
            controlShape = .roundedRect
            motionStyle = .expressive
            glassFrosting = 0.56
            backgroundBlur = 0.50
            backgroundDim = 0.52
            surfaceContrast = 0.46
            visualNoiseReductionEnabled = false
        case .focusSolid:
            appearance = .system
            accent = .blue
            materialStrength = .off
            backgroundMode = .solidColor
            fontDensity = .compact
            glassStyle = .solid
            chromeStyle = .integrated
            depthStyle = .flat
            controlShape = .roundedRect
            motionStyle = .reduced
            glassFrosting = 1
            backgroundBlur = 0
            backgroundDim = 0.74
            surfaceContrast = 0.70
            visualNoiseReductionEnabled = true
        case .highLegibility:
            appearance = .highContrast
            accent = .amber
            materialStrength = .off
            backgroundMode = .solidColor
            fontDensity = .comfortable
            glassStyle = .solid
            chromeStyle = .integrated
            depthStyle = .flat
            controlShape = .roundedRect
            motionStyle = .reduced
            glassFrosting = 1
            backgroundBlur = 0
            backgroundDim = 0.80
            surfaceContrast = 0.86
            visualNoiseReductionEnabled = true
        }
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
