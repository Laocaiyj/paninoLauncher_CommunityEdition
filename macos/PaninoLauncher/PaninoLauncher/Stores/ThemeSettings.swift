import Foundation
import AppKit
import Combine

@MainActor
final class ThemeSettings: ObservableObject {
    @Published var language: AppLanguage = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.language,
        defaultValue: .english
    ) {
        didSet { SettingsStore.set(language.rawValue, forKey: ThemeSettingsKey.language) }
    }

    @Published var currentPreset: ThemePreset = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.currentPreset,
        defaultValue: .vanilla
    ) {
        didSet { SettingsStore.set(currentPreset.rawValue, forKey: ThemeSettingsKey.currentPreset) }
    }

    @Published var appearance: ThemeAppearanceMode = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.appearance,
        defaultValue: .system
    ) {
        didSet {
            SettingsStore.set(appearance.rawValue, forKey: ThemeSettingsKey.appearance)
            applyAppAppearance()
        }
    }

    @Published var accent: ThemeAccentColor = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.accent,
        defaultValue: .system
    ) {
        didSet { SettingsStore.set(accent.rawValue, forKey: ThemeSettingsKey.accent) }
    }

    @Published var materialStrength: MaterialStrength = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.materialStrength,
        defaultValue: .medium
    ) {
        didSet { SettingsStore.set(materialStrength.rawValue, forKey: ThemeSettingsKey.materialStrength) }
    }

    @Published var backgroundMode: ThemeBackgroundMode = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.backgroundMode,
        defaultValue: .default
    ) {
        didSet { SettingsStore.set(backgroundMode.rawValue, forKey: ThemeSettingsKey.backgroundMode) }
    }

    @Published var fontDensity: FontDensity = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.fontDensity,
        defaultValue: .standard
    ) {
        didSet { SettingsStore.set(fontDensity.rawValue, forKey: ThemeSettingsKey.fontDensity) }
    }

    @Published var glassStyle: ThemeGlassStyle = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.glassStyle,
        defaultValue: .automatic
    ) {
        didSet { SettingsStore.set(glassStyle.rawValue, forKey: ThemeSettingsKey.glassStyle) }
    }

    @Published var chromeStyle: ThemeChromeStyle = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.chromeStyle,
        defaultValue: .floatingToolbar
    ) {
        didSet { SettingsStore.set(chromeStyle.rawValue, forKey: ThemeSettingsKey.chromeStyle) }
    }

    @Published var depthStyle: ThemeDepthStyle = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.depthStyle,
        defaultValue: .soft
    ) {
        didSet { SettingsStore.set(depthStyle.rawValue, forKey: ThemeSettingsKey.depthStyle) }
    }

    @Published var controlShape: ThemeControlShape = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.controlShape,
        defaultValue: .roundedRect
    ) {
        didSet { SettingsStore.set(controlShape.rawValue, forKey: ThemeSettingsKey.controlShape) }
    }

    @Published var motionStyle: ThemeMotionStyle = ThemeSettings.loadEnum(
        key: ThemeSettingsKey.motionStyle,
        defaultValue: .system
    ) {
        didSet { SettingsStore.set(motionStyle.rawValue, forKey: ThemeSettingsKey.motionStyle) }
    }

    @Published var customAccentHex: String = SettingsStore.string(
        forKey: ThemeSettingsKey.customAccentHex,
        default: "#FF4F5E"
    ) {
        didSet {
            SettingsStore.set(Self.normalizedCustomAccentHex(customAccentHex), forKey: ThemeSettingsKey.customAccentHex)
        }
    }

    @Published var glassFrosting: Double = SettingsStore.double(
        forKey: ThemeSettingsKey.glassFrosting,
        default: 0.58
    ) {
        didSet {
            SettingsStore.set(Self.clampedUnit(glassFrosting), forKey: ThemeSettingsKey.glassFrosting)
        }
    }

    @Published var backgroundBlur: Double = SettingsStore.double(
        forKey: ThemeSettingsKey.backgroundBlur,
        default: 0.46
    ) {
        didSet {
            SettingsStore.set(Self.clampedUnit(backgroundBlur), forKey: ThemeSettingsKey.backgroundBlur)
        }
    }

    @Published var backgroundDim: Double = SettingsStore.double(
        forKey: ThemeSettingsKey.backgroundDim,
        default: 0.54
    ) {
        didSet {
            SettingsStore.set(Self.clampedUnit(backgroundDim), forKey: ThemeSettingsKey.backgroundDim)
        }
    }

    @Published var surfaceContrast: Double = SettingsStore.double(
        forKey: ThemeSettingsKey.surfaceContrast,
        default: 0.46
    ) {
        didSet {
            SettingsStore.set(Self.clampedUnit(surfaceContrast), forKey: ThemeSettingsKey.surfaceContrast)
        }
    }

    @Published var customImagePath: String = SettingsStore.string(forKey: ThemeSettingsKey.customImagePath, default: "") {
        didSet {
            SettingsStore.set(customImagePath, forKey: ThemeSettingsKey.customImagePath)
            loadCustomBackgroundImage()
        }
    }

    @Published var customImageBookmark: Data? = SettingsStore.data(forKey: ThemeSettingsKey.customImageBookmark) {
        didSet {
            SettingsStore.set(customImageBookmark, forKey: ThemeSettingsKey.customImageBookmark)
            loadCustomBackgroundImage()
        }
    }

    @Published private(set) var cachedBackgroundImage: NSImage?

    init() {
        applyAppAppearance()
        loadCustomBackgroundImage()
    }

    @Published var softBackgroundEnabled: Bool = SettingsStore.bool(
        forKey: ThemeSettingsKey.softBackgroundEnabled,
        default: true
    ) {
        didSet { SettingsStore.set(softBackgroundEnabled, forKey: ThemeSettingsKey.softBackgroundEnabled) }
    }

    @Published var quietModeEnabled: Bool = SettingsStore.bool(
        forKey: ThemeSettingsKey.quietModeEnabled,
        default: false
    ) {
        didSet { SettingsStore.set(quietModeEnabled, forKey: ThemeSettingsKey.quietModeEnabled) }
    }

    @Published var visualNoiseReductionEnabled: Bool = SettingsStore.bool(
        forKey: ThemeSettingsKey.visualNoiseReductionEnabled,
        default: false
    ) {
        didSet { SettingsStore.set(visualNoiseReductionEnabled, forKey: ThemeSettingsKey.visualNoiseReductionEnabled) }
    }

    func loadCustomBackgroundImage() {
        cachedBackgroundImage = ThemeBackgroundImageLoader.image(
            bookmark: customImageBookmark,
            path: customImagePath
        )
    }

}
