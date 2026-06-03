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
        }
    }
}

enum ThemePreset: String, CaseIterable, Identifiable {
    case vanilla
    case nether
    case deepDark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vanilla:
            return "Vanilla"
        case .nether:
            return "Nether"
        case .deepDark:
            return "Deep Dark"
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

    var accentColor: Color {
        accent.color ?? Color.accentColor
    }

    var effectiveMaterialStrength: MaterialStrength {
        quietModeEnabled ? .off : materialStrength
    }

    var effectiveBackgroundMode: ThemeBackgroundMode {
        quietModeEnabled ? .solidColor : backgroundMode
    }

    var effectiveSoftBackgroundEnabled: Bool {
        !quietModeEnabled && softBackgroundEnabled
    }

    var reducesInterfaceMotion: Bool {
        quietModeEnabled
    }

    func applyPreset(_ preset: ThemePreset) {
        currentPreset = preset
        switch preset {
        case .vanilla:
            accent = .emerald
            materialStrength = .medium
            backgroundMode = .default
            fontDensity = .standard
        case .nether:
            accent = .red
            materialStrength = .low
            backgroundMode = .solidColor
            fontDensity = .standard
        case .deepDark:
            appearance = .dark
            accent = .purple
            materialStrength = .high
            backgroundMode = .currentInstance
            fontDensity = .compact
        }
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

    private func applyAppAppearance() {
        NSApplication.shared.appearance = appearance.nsAppearance
    }
}
